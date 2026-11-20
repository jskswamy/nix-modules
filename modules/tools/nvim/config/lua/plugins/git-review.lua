-- Full-file inline commit review (<leader>gr, <leader>gR, <leader>gd).
--
-- Read the entire file from a commit in a single buffer (works seamlessly
-- inside Zen Reader <leader>zz and Presentation Mode <leader>zp):
-- - Added lines: soft green background (GitSignsAddLn) + green word highlights (GitSignsAddInline)
-- - Modified lines: soft yellow/amber background (GitSignsChangeLn) + yellow word highlights (GitSignsChangeInline)
-- - Deleted lines: inline red virtual lines (GitSignsDeleteVirtLn) + strikethrough red deleted words (GitSignsDeleteInline)
--
-- Entry keys:
--   <leader>gr - Pick a commit -> pick a changed file -> read full file with inline diff
--   <leader>gR - Pick a commit from current file's history -> read full file with inline diff
--   <leader>gd - Toggle full-file inline diff on current file (uncommitted changes, or HEAD~1..HEAD if clean)
--
-- Active review keys (registered dynamically while a buffer is in review mode):
--   <leader>gf - Re-open the changed files picker for the active commit
--   <leader>gq - Exit commit review mode and clear inline highlights
--   ]h / [h    - Jump to next / previous changed hunk in the buffer

local ns = vim.api.nvim_create_namespace("git_full_file_review")

local state = {
	active_commit = nil,
	active_root = nil,
	buf_hunks = {}, -- bufnr -> sorted list of 1-based line numbers
	scratch_parent = {}, -- scratch_bufnr -> original_bufnr
}

local function tokenize_line(line)
	local tokens = {}
	local spans = {}
	local idx = 1
	local len = #line
	while idx <= len do
		local s, e = line:find("%s+", idx)
		if s == idx then
			tokens[#tokens + 1] = line:sub(s, e)
			spans[#spans + 1] = { s - 1, e }
			idx = e + 1
		else
			local ws, we = line:find("[%w_]+", idx)
			if ws == idx then
				tokens[#tokens + 1] = line:sub(ws, we)
				spans[#spans + 1] = { ws - 1, we }
				idx = we + 1
			else
				tokens[#tokens + 1] = line:sub(idx, idx)
				spans[#spans + 1] = { idx - 1, idx }
				idx = idx + 1
			end
		end
	end
	return tokens, spans
end

local function compute_word_diff(old_line, new_line)
	local old_tokens, _ = tokenize_line(old_line)
	local new_tokens, new_spans = tokenize_line(new_line)
	if #old_tokens == 0 and #new_tokens == 0 then
		return { { "- ", "GitSignsDeleteInline" }, { old_line, "GitSignsDeleteVirtLn" } }, {}
	end
	local a_str = table.concat(old_tokens, "\n") .. (#old_tokens > 0 and "\n" or "")
	local b_str = table.concat(new_tokens, "\n") .. (#new_tokens > 0 and "\n" or "")
	local ok, hunks = pcall(vim.diff, a_str, b_str, {
		result_type = "indices",
		algorithm = "histogram",
	})
	if not ok or type(hunks) ~= "table" then
		return { { "- ", "GitSignsDeleteInline" }, { old_line, "GitSignsDeleteVirtLn" } }, {}
	end

	local old_deleted = {}
	local new_changed = {}
	for _, h in ipairs(hunks) do
		local sa, ca, sb, cb = h[1], h[2], h[3], h[4]
		for i = sa, sa + ca - 1 do
			if i >= 1 and i <= #old_tokens then
				old_deleted[i] = true
			end
		end
		local hl = (ca == 0) and "GitSignsAddInline" or "GitSignsChangeInline"
		for j = sb, sb + cb - 1 do
			if j >= 1 and j <= #new_spans then
				new_changed[#new_changed + 1] = {
					col_start = new_spans[j][1],
					col_end = new_spans[j][2],
					hl = hl,
				}
			end
		end
	end

	local shared_word = false
	for i, tok in ipairs(old_tokens) do
		if not old_deleted[i] and tok:find("%S") then
			shared_word = true
			break
		end
	end

	local virt_chunks = { { "- ", "GitSignsDeleteInline" } }
	for i, tok in ipairs(old_tokens) do
		local hl = (shared_word and old_deleted[i]) and "GitSignsDeleteInline" or "GitSignsDeleteVirtLn"
		virt_chunks[#virt_chunks + 1] = { tok, hl }
	end
	return virt_chunks, new_changed, shared_word
end

local register_active_review_keys
local unregister_active_review_keys

local function any_reviewed_buffer()
	for b, hunks in pairs(state.buf_hunks) do
		if hunks and vim.api.nvim_buf_is_valid(b) then
			return true
		end
	end
	return false
end

local function clear_review(buf)
	buf = buf or vim.api.nvim_get_current_buf()
	if vim.api.nvim_buf_is_valid(buf) then
		vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
		pcall(vim.keymap.del, "n", "]h", { buffer = buf })
		pcall(vim.keymap.del, "n", "[h", { buffer = buf })
		pcall(vim.keymap.del, "n", "<leader>gf", { buffer = buf })
		pcall(vim.keymap.del, "n", "<leader>gq", { buffer = buf })
	end
	state.buf_hunks[buf] = nil
	local parent = state.scratch_parent[buf]
	if parent and vim.api.nvim_buf_is_valid(parent) and vim.api.nvim_get_current_buf() == buf then
		vim.api.nvim_set_current_buf(parent)
		pcall(vim.api.nvim_buf_delete, buf, { force = true })
	end
	state.scratch_parent[buf] = nil
	if not any_reviewed_buffer() then
		state.active_commit = nil
		unregister_active_review_keys()
	end
end

local function clear_all_reviews()
	for b, _ in pairs(vim.deepcopy(state.buf_hunks)) do
		clear_review(b)
	end
	state.active_commit = nil
	unregister_active_review_keys()
end

local function next_hunk()
	local buf = vim.api.nvim_get_current_buf()
	local hunks = state.buf_hunks[buf]
	if not hunks or #hunks == 0 then
		return
	end
	local cur_line = vim.api.nvim_win_get_cursor(0)[1]
	for _, line in ipairs(hunks) do
		if line > cur_line then
			vim.api.nvim_win_set_cursor(0, { line, 0 })
			return
		end
	end
	vim.api.nvim_win_set_cursor(0, { hunks[1], 0 })
end

local function prev_hunk()
	local buf = vim.api.nvim_get_current_buf()
	local hunks = state.buf_hunks[buf]
	if not hunks or #hunks == 0 then
		return
	end
	local cur_line = vim.api.nvim_win_get_cursor(0)[1]
	for i = #hunks, 1, -1 do
		if hunks[i] < cur_line then
			vim.api.nvim_win_set_cursor(0, { hunks[i], 0 })
			return
		end
	end
	vim.api.nvim_win_set_cursor(0, { hunks[#hunks], 0 })
end

local function render_buffer_diff(buf, old_lines, new_lines, meta)
	old_lines = old_lines or {}
	new_lines = new_lines or {}
	vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

	local a_str = #old_lines > 0 and (table.concat(old_lines, "\n") .. "\n") or ""
	local b_str = #new_lines > 0 and (table.concat(new_lines, "\n") .. "\n") or ""

	local ok, hunks = pcall(vim.diff, a_str, b_str, {
		result_type = "indices",
		algorithm = "histogram",
		ctxlen = 0,
	})
	if not ok or type(hunks) ~= "table" then
		return
	end

	local total_new = math.max(1, #new_lines)
	local hunk_lines = {}

	for _, h in ipairs(hunks) do
		local start_a, count_a, start_b, count_b = h[1], h[2], h[3], h[4]

		if count_a == 0 and count_b > 0 then
			-- Pure addition: green line background
			hunk_lines[#hunk_lines + 1] = math.min(total_new, math.max(1, start_b))
			for row = start_b - 1, start_b + count_b - 2 do
				if row >= 0 and row < #new_lines then
					vim.api.nvim_buf_set_extmark(buf, ns, row, 0, {
						line_hl_group = "GitSignsAddLn",
						sign_text = "┃",
						sign_hl_group = "GitSignsAddInline",
						priority = 200,
					})
				end
			end
		elseif count_a > 0 and count_b == 0 then
			-- Pure deletion: red virtual lines at deletion boundary
			local virt_lines = {}
			for i = start_a, start_a + count_a - 1 do
				local del_text = old_lines[i] or ""
				virt_lines[#virt_lines + 1] = {
					{ "- ", "GitSignsDeleteInline" },
					{ del_text, "GitSignsDeleteVirtLn" },
				}
			end
			local buf_lines = vim.api.nvim_buf_line_count(buf)
			local target_row = math.min(math.max(0, buf_lines - 1), math.max(0, start_b))
			local above = (start_b == 0)
			hunk_lines[#hunk_lines + 1] = target_row + 1
			if buf_lines > 0 then
				vim.api.nvim_buf_set_extmark(buf, ns, target_row, 0, {
					virt_lines = virt_lines,
					virt_lines_above = above,
					priority = 200,
				})
			end
		else
			-- Modification: show deleted old lines as virtual red lines above the changed block,
			-- highlight modified new lines in yellow (or green for net-new lines), and highlight
			-- exact changed words on paired lines.
			local anchor_row = math.min(math.max(0, #new_lines - 1), math.max(0, start_b - 1))
			hunk_lines[#hunk_lines + 1] = anchor_row + 1
			local paired = math.min(count_a, count_b)
			local virt_lines = {}
			local row_is_modified = {}

			for k = 0, count_a - 1 do
				local old_l = old_lines[start_a + k] or ""
				if k < paired then
					local new_l = new_lines[start_b + k] or ""
					local virt_chunks, new_word_spans, shared_word = compute_word_diff(old_l, new_l)
					virt_lines[#virt_lines + 1] = virt_chunks
					local row = start_b - 1 + k
					row_is_modified[k] = shared_word
					if shared_word and row >= 0 and row < #new_lines then
						for _, span in ipairs(new_word_spans) do
							pcall(vim.api.nvim_buf_set_extmark, buf, ns, row, span.col_start, {
								end_row = row,
								end_col = span.col_end,
								hl_group = span.hl,
								priority = 250,
							})
						end
					end
				else
					virt_lines[#virt_lines + 1] = {
						{ "- ", "GitSignsDeleteInline" },
						{ old_l, "GitSignsDeleteVirtLn" },
					}
				end
			end

			if #virt_lines > 0 and #new_lines > 0 then
				vim.api.nvim_buf_set_extmark(buf, ns, anchor_row, 0, {
					virt_lines = virt_lines,
					virt_lines_above = true,
					priority = 200,
				})
			end

			for k = 0, count_b - 1 do
				local row = start_b - 1 + k
				if row >= 0 and row < #new_lines then
					local is_modified = row_is_modified[k] == true
					vim.api.nvim_buf_set_extmark(buf, ns, row, 0, {
						line_hl_group = is_modified and "GitSignsChangeLn" or "GitSignsAddLn",
						sign_text = "┃",
						sign_hl_group = is_modified and "GitSignsChangeInline" or "GitSignsAddInline",
						priority = 200,
					})
				end
			end
		end
	end

	table.sort(hunk_lines)
	state.buf_hunks[buf] = hunk_lines
	if meta and meta.commit then
		state.active_commit = meta.commit
	end
	if meta and meta.cwd then
		state.active_root = meta.cwd
	end

	vim.keymap.set("n", "]h", next_hunk, { buffer = buf, silent = true, desc = "Next Review Hunk" })
	vim.keymap.set("n", "[h", prev_hunk, { buffer = buf, silent = true, desc = "Prev Review Hunk" })
	register_active_review_keys(buf)
end

local function git_lines(cwd, args)
	local cmd = { "git" }
	if cwd and cwd ~= "" then
		vim.list_extend(cmd, { "-C", cwd })
	end
	vim.list_extend(cmd, args)
	local ok, res = pcall(function()
		return vim.system(cmd, { text = true }):wait(3000)
	end)
	if not ok or not res or res.code ~= 0 or not res.stdout then
		return nil
	end
	local lines = vim.split(res.stdout, "\n", { plain = true })
	if #lines > 0 and lines[#lines] == "" then
		table.remove(lines, #lines)
	end
	return lines
end

local function git_root(path)
	local dir = path and vim.fn.fnamemodify(path, ":h") or vim.fn.getcwd()
	local lines = git_lines(dir, { "rev-parse", "--show-toplevel" })
	return lines and lines[1] or vim.fn.getcwd()
end

local function review_commit_file(commit, relpath, cwd)
	cwd = cwd or state.active_root or git_root()
	if not commit or not relpath or relpath == "" then
		return
	end
	local old_lines = git_lines(cwd, { "show", commit .. "~1:" .. relpath }) or {}
	local new_lines = git_lines(cwd, { "show", commit .. ":" .. relpath }) or {}
	local abs_path = cwd .. "/" .. relpath

	local target_buf = nil
	if vim.fn.filereadable(abs_path) == 1 then
		local disk_lines = vim.fn.readfile(abs_path)
		if vim.deep_equal(disk_lines, new_lines) then
			vim.cmd.edit(vim.fn.fnameescape(abs_path))
			target_buf = vim.api.nvim_get_current_buf()
		end
	end

	if not target_buf then
		local prev_buf = vim.api.nvim_get_current_buf()
		target_buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_name(target_buf, string.format("review://%s/%s", commit:sub(1, 7), relpath))
		vim.api.nvim_buf_set_lines(target_buf, 0, -1, false, #new_lines > 0 and new_lines or { "" })
		local ft = vim.filetype.match({ filename = abs_path, buf = target_buf })
		if ft then
			vim.bo[target_buf].filetype = ft
		end
		vim.bo[target_buf].modifiable = false
		vim.bo[target_buf].buftype = "nofile"
		vim.bo[target_buf].bufhidden = "wipe"
		state.scratch_parent[target_buf] = prev_buf
		vim.api.nvim_set_current_buf(target_buf)
	end

	render_buffer_diff(target_buf, old_lines, new_lines, { commit = commit, file = relpath, cwd = cwd })
	local hunks = state.buf_hunks[target_buf]
	if hunks and hunks[1] then
		pcall(vim.api.nvim_win_set_cursor, 0, { hunks[1], 0 })
	end
end

local function pick_commit_files(commit, cwd)
	cwd = cwd or state.active_root or git_root()
	commit = commit or state.active_commit
	if not commit then
		vim.notify("No active review commit selected", vim.log.levels.WARN)
		return
	end
	state.active_commit = commit
	state.active_root = cwd
	local files = git_lines(cwd, { "diff-tree", "--no-commit-id", "--name-only", "-r", commit }) or {}
	if #files == 0 then
		vim.notify("No changed files in commit " .. commit, vim.log.levels.INFO)
		return
	end
	if #files == 1 then
		review_commit_file(commit, files[1], cwd)
		return
	end
	vim.ui.select(files, {
		prompt = string.format("Files in %s (Full-File Inline Review):", commit:sub(1, 7)),
	}, function(choice)
		if choice then
			review_commit_file(commit, choice, cwd)
		end
	end)
end

local function pick_commit()
	local cwd = git_root(vim.api.nvim_buf_get_name(0))
	if _G.Snacks and Snacks.picker and Snacks.picker.git_log then
		Snacks.picker.git_log({
			cwd = cwd,
			title = "Select Commit for Full-File Review",
			confirm = function(picker, item)
				picker:close()
				local commit = item and (item.commit or item.hash)
				if commit then
					vim.schedule(function()
						pick_commit_files(commit, cwd)
					end)
				end
			end,
		})
	end
end

local function pick_current_file_commit()
	local file = vim.api.nvim_buf_get_name(0)
	if file == "" then
		vim.notify("Current buffer has no file on disk", vim.log.levels.WARN)
		return
	end
	local cwd = git_root(file)
	local relpath = file:sub(1, #cwd + 1) == (cwd .. "/") and file:sub(#cwd + 2) or vim.fn.fnamemodify(file, ":.")
	if _G.Snacks and Snacks.picker and Snacks.picker.git_log_file then
		Snacks.picker.git_log_file({
			cwd = cwd,
			title = "Select Commit for Current File Review",
			confirm = function(picker, item)
				picker:close()
				local commit = item and (item.commit or item.hash)
				if commit then
					vim.schedule(function()
						review_commit_file(commit, relpath, cwd)
					end)
				end
			end,
		})
	end
end

local function toggle_current_file()
	local buf = vim.api.nvim_get_current_buf()
	if state.buf_hunks[buf] then
		clear_review(buf)
		return
	end
	local file = vim.api.nvim_buf_get_name(buf)
	if file == "" then
		vim.notify("Current buffer is not a file", vim.log.levels.WARN)
		return
	end
	local cwd = git_root(file)
	local relpath = file:sub(1, #cwd + 1) == (cwd .. "/") and file:sub(#cwd + 2) or vim.fn.fnamemodify(file, ":.")
	local new_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	local head_lines = git_lines(cwd, { "show", "HEAD:" .. relpath }) or {}
	local base_ref = "HEAD"
	local old_lines = head_lines
	if vim.deep_equal(new_lines, head_lines) then
		base_ref = "HEAD~1"
		old_lines = git_lines(cwd, { "show", "HEAD~1:" .. relpath }) or {}
	end
	render_buffer_diff(buf, old_lines, new_lines, { commit = base_ref == "HEAD~1" and "HEAD" or nil, file = relpath, cwd = cwd })
	local hunks = state.buf_hunks[buf]
	if hunks and hunks[1] then
		pcall(vim.api.nvim_win_set_cursor, 0, { hunks[1], 0 })
	end
end

register_active_review_keys = function(buf)
	vim.keymap.set("n", "<leader>gf", function()
		pick_commit_files(state.active_commit, state.active_root)
	end, { buffer = buf, silent = true, desc = "Git Review: Files in Active Commit" })
	vim.keymap.set("n", "<leader>gq", function()
		clear_all_reviews()
	end, { buffer = buf, silent = true, desc = "Git Review: Exit Inline Review" })
end

unregister_active_review_keys = function()
	pcall(vim.keymap.del, "n", "<leader>gf")
	pcall(vim.keymap.del, "n", "<leader>gq")
end

_G.GitReview = {
	ns = ns,
	render_buffer_diff = render_buffer_diff,
	clear = clear_review,
	clear_all = clear_all_reviews,
	next_hunk = next_hunk,
	prev_hunk = prev_hunk,
	review_commit_file = review_commit_file,
	pick_commit_files = pick_commit_files,
	pick_commit = pick_commit,
	pick_current_file_commit = pick_current_file_commit,
	toggle_current_file = toggle_current_file,
}

return {
	{
		"folke/snacks.nvim",
		keys = {
			{ "<leader>gr", pick_commit, desc = "Git Review Commit (Full-File)" },
			{ "<leader>gR", pick_current_file_commit, desc = "Git Review File History (Full-File)" },
			{ "<leader>gd", toggle_current_file, desc = "Git Toggle Inline Diff Review" },
		},
	},
}
