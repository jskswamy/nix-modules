-- High-value editor enhancements & Agent/LLM Review Workflow:
-- 1. oil.nvim: Edit filesystem directories like a normal Neovim buffer (- or <leader>fo).
-- 2. treesj: Structural split/join for Lua tables, Nix attrsets, JSON, Go structs, and args (<leader>cj / gS).
-- 3. quicker.nvim: Editable, context-expandable quickfix list (> / < to expand/collapse context).
-- 4. gitsigns.nvim: Toggle inline current-line git blame (<leader>uB) and word diff (<leader>gW).
-- 5. Agent-Modified & Recently Modified Files Pickers (<leader>fm, <leader>fM):
--    - Lists uncommitted modified/untracked files + latest commit files sorted by mtime (newest first).
--    - Inside the picker: <CR> opens file, <C-d> opens Full-File Inline Diff Review, <C-l> opens in `leaf`.
-- 6. Multi-Comment LLM Review Queue & Rex Bridge (<leader>ac, <leader>af, <leader>al, <leader>aC, <leader>as, <leader>aS):
--    - <leader>ac: Add inline review comment badge (virtual text) on current line or visual selection.
--    - <leader>af: Compile all queued review comments into a structured Markdown prompt, send to sibling Rex pane + clipboard, and clear badges.
--    - <leader>al: Inspect queued review comments in a picker (jump to item or delete).
--    - <leader>aC: Clear all queued review comments and badges.
--    - <leader>as: Send current selection/line + diagnostics directly to sibling Rex pane.
--    - <leader>aS: Prompt for a one-off instruction and send selection/line + instruction + diagnostics to Rex pane.
-- 7. Leaf TUI Markdown Reader (<leader>ml, <leader>mL):
--    - <leader>ml: Open current file in `leaf` inside a full-size rounded floating terminal (like lazygit).
--    - <leader>mL: Pick a Markdown file in the repository (sorted by recent modification) and open it in `leaf`.

local review_ns = vim.api.nvim_create_namespace("agent_review_comments")
local uv = vim.uv or vim.loop

local review_queue = {} -- list of { id, buf, file, relpath, start_line, end_line, ft, code, comment, extmark_id }
local next_comment_id = 1

local function rex_bin()
	local home = vim.env.HOME or ""
	local local_rex = home .. "/.local/bin/rex"
	if vim.fn.executable(local_rex) == 1 then
		return local_rex
	end
	if vim.fn.executable("rex") == 1 then
		return "rex"
	end
	return nil
end

local function find_sibling_rex_block(bin, session_id, current_block)
	local ok, res = pcall(function()
		return vim.system({ bin, "session", "inspect", session_id, "--json" }, { text = true }):wait(1500)
	end)
	if not ok or not res or res.code ~= 0 or not res.stdout then
		return nil
	end
	local decoded_ok, data = pcall(vim.json.decode, res.stdout)
	if not decoded_ok or type(data) ~= "table" or type(data.windows) ~= "table" then
		return nil
	end
	for _, w in ipairs(data.windows) do
		local blocks = w.blocks or w.panes or {}
		local has_current = false
		local candidate = nil
		for _, b in ipairs(blocks) do
			local bid = type(b) == "table" and (b.block_id or b.id) or b
			if bid == current_block then
				has_current = true
			elseif type(bid) == "string" and not candidate then
				candidate = bid
			end
		end
		if has_current and candidate then
			return candidate
		end
	end
	return nil
end

local function deliver_payload_to_llm(payload, summary_label)
	pcall(vim.fn.setreg, "+", payload)
	pcall(vim.fn.setreg, '"', payload)
	local bin = rex_bin()
	local session_id = vim.env.REX_SESSION or ""
	local current_block = vim.env.REX_BLOCK or ""
	if bin and session_id ~= "" and current_block ~= "" then
		local target = find_sibling_rex_block(bin, session_id, current_block)
		if target then
			pcall(vim.system, { bin, "send", "-s", session_id, target, payload }, { text = true })
			vim.notify(string.format("Sent %s to Rex pane %s (and copied to clipboard)", summary_label, target), vim.log.levels.INFO)
			return true, target
		end
	end
	vim.notify(string.format("Copied %s to clipboard", summary_label), vim.log.levels.INFO)
	return false, nil
end

local function capture_selection_context(mode)
	local buf = vim.api.nvim_get_current_buf()
	local file = vim.api.nvim_buf_get_name(buf)
	local rel = file ~= "" and vim.fn.fnamemodify(file, ":.") or "[No Name]"
	local start_line, end_line
	if mode == "v" or mode == "V" or mode == "\22" then
		local vstart = vim.fn.getpos("v")[2]
		local vend = vim.fn.getpos(".")[2]
		start_line = math.min(vstart, vend)
		end_line = math.max(vstart, vend)
	else
		local cur = vim.api.nvim_win_get_cursor(0)[1]
		start_line, end_line = cur, cur
	end
	local lines = vim.api.nvim_buf_get_lines(buf, start_line - 1, end_line, false)
	local diags = vim.diagnostic.get(buf)
	local diag_lines = {}
	for _, d in ipairs(diags) do
		local lnum = (d.lnum or 0) + 1
		if lnum >= start_line and lnum <= end_line then
			diag_lines[#diag_lines + 1] = string.format("  - line %d: %s", lnum, d.message or "")
		end
	end
	local header = start_line == end_line and string.format("%s:%d", rel, start_line)
		or string.format("%s:%d-%d", rel, start_line, end_line)
	return {
		buf = buf,
		file = file,
		relpath = rel,
		ft = vim.bo[buf].filetype or "",
		start_line = start_line,
		end_line = end_line,
		header = header,
		code = table.concat(lines, "\n"),
		diag_lines = diag_lines,
	}
end

local function send_to_rex_pane(mode, instruction)
	local ctx = capture_selection_context(mode)
	local payload = ctx.header .. "\n```" .. ctx.ft .. "\n" .. ctx.code .. "\n```"
	if #ctx.diag_lines > 0 then
		payload = payload .. "\nDiagnostics:\n" .. table.concat(ctx.diag_lines, "\n")
	end
	if instruction and vim.trim(instruction) ~= "" then
		payload = payload .. "\n\nInstruction: " .. vim.trim(instruction)
	end
	deliver_payload_to_llm(payload, ctx.header)
end

local function prompt_and_send_to_rex_pane(mode)
	local ctx = capture_selection_context(mode)
	if mode == "v" or mode == "V" or mode == "\22" then
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)
	end
	vim.ui.input({
		prompt = string.format("LLM Instruction for %s: ", ctx.header),
	}, function(input)
		if not input or vim.trim(input) == "" then
			return
		end
		local payload = ctx.header .. "\n```" .. ctx.ft .. "\n" .. ctx.code .. "\n```"
		if #ctx.diag_lines > 0 then
			payload = payload .. "\nDiagnostics:\n" .. table.concat(ctx.diag_lines, "\n")
		end
		payload = payload .. "\n\nInstruction: " .. vim.trim(input)
		deliver_payload_to_llm(payload, ctx.header)
	end)
end

local function place_comment_badge(entry)
	if not entry.buf or not vim.api.nvim_buf_is_valid(entry.buf) then
		return
	end
	local line_count = vim.api.nvim_buf_line_count(entry.buf)
	local target_row = math.min(math.max(0, line_count - 1), math.max(0, entry.start_line - 1))
	local label = entry.start_line == entry.end_line and string.format("L%d", entry.start_line)
		or string.format("L%d-%d", entry.start_line, entry.end_line)
	entry.extmark_id = vim.api.nvim_buf_set_extmark(entry.buf, review_ns, target_row, 0, {
		virt_lines = {
			{
				{ string.format(" 💬 [Review #%d %s] ", entry.id, label), "DiagnosticInfo" },
				{ entry.comment, "Comment" },
			},
		},
		virt_lines_above = true,
		priority = 300,
	})
end

local function add_review_comment_entry(ctx, comment_text)
	local text = vim.trim(comment_text or "")
	if text == "" then
		return nil
	end
	local entry = {
		id = next_comment_id,
		buf = ctx.buf,
		file = ctx.file,
		relpath = ctx.relpath,
		ft = ctx.ft,
		start_line = ctx.start_line,
		end_line = ctx.end_line,
		header = ctx.header,
		code = ctx.code,
		comment = text,
	}
	next_comment_id = next_comment_id + 1
	review_queue[#review_queue + 1] = entry
	place_comment_badge(entry)
	vim.notify(
		string.format("Added review comment #%d on %s (%d queued — <leader>af to send)", entry.id, ctx.header, #review_queue),
		vim.log.levels.INFO
	)
	return entry
end

local function prompt_add_review_comment(mode)
	local ctx = capture_selection_context(mode)
	if mode == "v" or mode == "V" or mode == "\22" then
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)
	end
	vim.ui.input({
		prompt = string.format("Review comment for %s: ", ctx.header),
	}, function(input)
		if input and vim.trim(input) ~= "" then
			add_review_comment_entry(ctx, input)
		end
	end)
end

local function clear_review_comments()
	for _, b in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_valid(b) then
			vim.api.nvim_buf_clear_namespace(b, review_ns, 0, -1)
		end
	end
	review_queue = {}
	next_comment_id = 1
end

local function format_review_queue_prompt()
	if #review_queue == 0 then
		return nil
	end
	local parts = { "Please address the following review feedback:" }
	for idx, item in ipairs(review_queue) do
		parts[#parts + 1] = ""
		parts[#parts + 1] = string.format("%d. `%s`", idx, item.header)
		parts[#parts + 1] = "```" .. (item.ft or "")
		parts[#parts + 1] = item.code
		parts[#parts + 1] = "```"
		parts[#parts + 1] = "> Feedback: " .. item.comment
	end
	return table.concat(parts, "\n")
end

local function flush_review_comments()
	local prompt = format_review_queue_prompt()
	if not prompt then
		vim.notify("No queued review comments (use <leader>ac to add comments first)", vim.log.levels.WARN)
		return nil
	end
	local count = #review_queue
	deliver_payload_to_llm(prompt, string.format("%d review comment(s)", count))
	clear_review_comments()
	return prompt
end

local function list_review_comments()
	if #review_queue == 0 then
		vim.notify("No queued review comments", vim.log.levels.INFO)
		return
	end
	local items = {}
	for _, entry in ipairs(review_queue) do
		items[#items + 1] = string.format("#%d %s — %s", entry.id, entry.header, entry.comment)
	end
	vim.ui.select(items, {
		prompt = string.format("Queued Review Comments (%d) — Select to jump:", #review_queue),
	}, function(_, idx)
		local entry = idx and review_queue[idx]
		if not entry then
			return
		end
		if entry.buf and vim.api.nvim_buf_is_valid(entry.buf) then
			vim.api.nvim_set_current_buf(entry.buf)
		elseif entry.file and entry.file ~= "" and vim.fn.filereadable(entry.file) == 1 then
			vim.cmd.edit(vim.fn.fnameescape(entry.file))
		end
		pcall(vim.api.nvim_win_set_cursor, 0, { entry.start_line, 0 })
	end)
end

-- Leaf floating TUI & Live Watch Split integration (with Ctrl+E host-Neovim RPC bridge)
local leaf_state = {
	float_term = nil,
	split_term = nil,
	last_edit_win = nil,
	autosave_group = nil,
}

local function leaf_editor_env()
	local script = vim.fn.stdpath("config") .. "/scripts/leaf-nvim-edit"
	if vim.fn.executable(script) ~= 1 then
		local repo_script = vim.fn.getcwd() .. "/modules/tools/nvim/config/scripts/leaf-nvim-edit"
		if vim.fn.executable(repo_script) == 1 then
			script = repo_script
		end
	end
	return {
		LEAF_EDITOR = string.format('%s {$line} "{$path}"', script),
	}
end

local function save_if_modified(buf)
	buf = buf or vim.api.nvim_get_current_buf()
	if
		vim.api.nvim_buf_is_valid(buf)
		and vim.bo[buf].modifiable
		and vim.bo[buf].buftype == ""
		and vim.bo[buf].modified
		and vim.api.nvim_buf_get_name(buf) ~= ""
	then
		pcall(vim.api.nvim_buf_call, buf, function()
			vim.cmd("silent! update")
		end)
	end
end

local function ensure_leaf_autosave()
	if leaf_state.autosave_group then
		return
	end
	leaf_state.autosave_group = vim.api.nvim_create_augroup("leaf_live_watch_autosave", { clear = true })
	vim.api.nvim_create_autocmd({ "InsertLeave", "TextChanged" }, {
		group = leaf_state.autosave_group,
		pattern = { "*.md", "*.markdown", "*.mdx", "*.rmd", "*.quarto" },
		callback = function(ev)
			save_if_modified(ev.buf)
		end,
	})
end

local function resolve_leaf_target(filepath)
	local target = filepath
	if not target or target == "" then
		target = vim.api.nvim_buf_get_name(0)
	end
	if not target or target == "" then
		vim.notify("No file to open in leaf", vim.log.levels.WARN)
		return nil
	end
	target = target:gsub("#page=%d+$", "")
	if vim.fn.executable("leaf") ~= 1 then
		vim.notify("leaf CLI is not installed on PATH", vim.log.levels.WARN)
		return nil
	end
	save_if_modified(vim.api.nvim_get_current_buf())
	ensure_leaf_autosave()
	return target
end

local function open_in_leaf(filepath)
	local cur_win = vim.api.nvim_get_current_win()
	local cur_buf = vim.api.nvim_get_current_buf()
	if vim.bo[cur_buf].buftype ~= "terminal" then
		leaf_state.last_edit_win = cur_win
	end
	local target = resolve_leaf_target(filepath)
	if not target then
		return false
	end
	if _G.Snacks and Snacks.terminal then
		leaf_state.float_term = Snacks.terminal({ "leaf", "--watch", target }, {
			cwd = vim.fn.fnamemodify(target, ":h"),
			env = leaf_editor_env(),
			win = {
				position = "float",
				border = "rounded",
				width = 0.92,
				height = 0.92,
			},
		})
		return true
	end
	vim.cmd("tabnew | terminal leaf --watch " .. vim.fn.shellescape(target))
	return true
end

local function toggle_leaf_split(filepath)
	if leaf_state.split_term and type(leaf_state.split_term.close) == "function" then
		local valid = type(leaf_state.split_term.valid) == "function" and leaf_state.split_term:valid()
		if valid then
			pcall(function()
				leaf_state.split_term:close()
			end)
			leaf_state.split_term = nil
			return true
		end
	end
	local edit_win = vim.api.nvim_get_current_win()
	leaf_state.last_edit_win = edit_win
	local target = resolve_leaf_target(filepath)
	if not target then
		return false
	end
	if _G.Snacks and Snacks.terminal then
		local term_fn = (type(Snacks.terminal) == "table" and type(Snacks.terminal.open) == "function")
			and Snacks.terminal.open
			or Snacks.terminal
		leaf_state.split_term = term_fn({ "leaf", "--watch", target }, {
			cwd = vim.fn.fnamemodify(target, ":h"),
			env = leaf_editor_env(),
			auto_insert = false,
			start_insert = false,
			win = {
				position = "right",
				width = 0.5,
			},
		})
		vim.schedule(function()
			if vim.api.nvim_win_is_valid(edit_win) then
				vim.api.nvim_set_current_win(edit_win)
				vim.cmd("stopinsert")
			end
		end)
		return true
	end
	vim.cmd("vertical botright split | terminal leaf --watch " .. vim.fn.shellescape(target))
	if vim.api.nvim_win_is_valid(edit_win) then
		vim.api.nvim_set_current_win(edit_win)
	end
	return true
end

-- Invoked via RPC when pressing Ctrl+E inside `leaf`:
-- Hides the floating leaf overlay (or leaves the side split visible), focuses
-- the Markdown editor window, jumps to `line`, centers (`zz`), and enters Insert mode.
local function leaf_edit_from_rpc(file, line)
	line = tonumber(line) or 1
	vim.schedule(function()
		-- Hide/close any floating leaf terminal window
		if leaf_state.float_term and type(leaf_state.float_term.hide) == "function" then
			pcall(function()
				leaf_state.float_term:hide()
			end)
		else
			for _, win in ipairs(vim.api.nvim_list_wins()) do
				if vim.api.nvim_win_is_valid(win) then
					local cfg = vim.api.nvim_win_get_config(win)
					local buf = vim.api.nvim_win_get_buf(win)
					if cfg and cfg.relative and cfg.relative ~= "" and vim.bo[buf].buftype == "terminal" then
						pcall(vim.api.nvim_win_close, win, false)
					end
				end
			end
		end

		-- Focus a non-terminal editor window
		local target_win = leaf_state.last_edit_win
		if not (target_win and vim.api.nvim_win_is_valid(target_win) and vim.bo[vim.api.nvim_win_get_buf(target_win)].buftype ~= "terminal") then
			target_win = nil
			for _, win in ipairs(vim.api.nvim_list_wins()) do
				if vim.api.nvim_win_is_valid(win) then
					local b = vim.api.nvim_win_get_buf(win)
					local cfg = vim.api.nvim_win_get_config(win)
					if vim.bo[b].buftype ~= "terminal" and (not cfg or not cfg.relative or cfg.relative == "") then
						target_win = win
						break
					end
				end
			end
		end
		if target_win and vim.api.nvim_win_is_valid(target_win) then
			vim.api.nvim_set_current_win(target_win)
		end

		if file and file ~= "" then
			local cur_name = vim.api.nvim_buf_get_name(0)
			if vim.fn.fnamemodify(cur_name, ":p") ~= vim.fn.fnamemodify(file, ":p") and vim.fn.filereadable(file) == 1 then
				vim.cmd.edit(vim.fn.fnameescape(file))
			end
		end

		local total = vim.api.nvim_buf_line_count(0)
		local target_line = math.max(1, math.min(total, line))
		pcall(vim.api.nvim_win_set_cursor, 0, { target_line, 0 })
		vim.cmd("normal! zz")
		vim.cmd("startinsert")
	end)
	return true
end

-- Modified / Agent-touched files discovery (sorted by filesystem mtime descending)
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
	local dir
	if path and path ~= "" then
		dir = vim.fn.fnamemodify(path, ":p:h")
	else
		dir = vim.fn.getcwd()
	end
	if not uv or not uv.fs_stat(dir) then
		dir = vim.fn.getcwd()
	end
	local lines = git_lines(dir, { "rev-parse", "--show-toplevel" })
	return lines and lines[1] or vim.fn.getcwd()
end

local function collect_modified_files(opts)
	opts = opts or {}
	local cwd = opts.cwd or git_root(vim.api.nvim_buf_get_name(0))
	local seen = {}
	local entries = {}

	local function add_file(relpath, status_badge, git_xy, priority_tier)
		if not relpath or relpath == "" or seen[relpath] then
			return
		end
		if opts.markdown_only and not relpath:lower():match("%.mdx?$") and not relpath:lower():match("%.markdown$") then
			return
		end
		local abs = cwd .. "/" .. relpath
		local stat = uv and uv.fs_stat(abs) or nil
		if not stat then
			return
		end
		seen[relpath] = true
		local mtime = (stat.mtime and stat.mtime.sec) or 0
		entries[#entries + 1] = {
			file = abs,
			relpath = relpath,
			badge = status_badge,
			git_xy = git_xy,
			tier = priority_tier,
			mtime = mtime,
		}
	end

	-- 1. Working tree modified, staged, or newly created (untracked) files
	local status_lines = git_lines(cwd, { "status", "--porcelain=v1", "-uall" }) or {}
	for _, line in ipairs(status_lines) do
		if #line >= 4 then
			local xy = line:sub(1, 2)
			local path = line:sub(4)
			local arrow = path:find(" -> ", 1, true)
			if arrow then
				path = path:sub(arrow + 4)
			end
			path = path:gsub('^"(.*)"$', "%1")
			local badge = xy == "??" and "NEW" or vim.trim(xy)
			add_file(path, badge, xy, 1)
		end
	end

	-- 2. Files touched in the most recent commit (HEAD) so agent-committed files are immediately accessible
	local head_files = git_lines(cwd, { "diff-tree", "--no-commit-id", "--name-only", "-r", "HEAD" }) or {}
	for _, path in ipairs(head_files) do
		add_file(path, "HEAD", nil, 2)
	end

	-- 3. If requested (or if markdown_only / recent_on_disk), also include recent tracked files by mtime
	if opts.include_recent_tracked or opts.markdown_only or #entries == 0 then
		local tracked = git_lines(cwd, { "ls-files" }) or {}
		for _, path in ipairs(tracked) do
			add_file(path, "REPO", nil, 3)
		end
	end

	table.sort(entries, function(a, b)
		if not opts.strict_mtime and a.tier ~= b.tier then
			return a.tier < b.tier
		end
		if a.mtime ~= b.mtime then
			return a.mtime > b.mtime
		end
		return a.relpath < b.relpath
	end)

	if opts.limit and #entries > opts.limit then
		local sliced = {}
		for i = 1, opts.limit do
			sliced[i] = entries[i]
		end
		entries = sliced
	end
	return entries, cwd
end

local function format_age(mtime)
	local now = os.time()
	local diff = math.max(0, now - (mtime or now))
	if diff < 60 then
		return string.format("%ds ago", diff)
	elseif diff < 3600 then
		return string.format("%dm ago", math.floor(diff / 60))
	elseif diff < 86400 then
		return string.format("%dh ago", math.floor(diff / 3600))
	else
		return string.format("%dd ago", math.floor(diff / 86400))
	end
end

local function open_modified_files_picker(opts)
	opts = opts or {}
	local entries, cwd = collect_modified_files(opts)
	if #entries == 0 then
		vim.notify("No matching modified files found in repository", vim.log.levels.INFO)
		return
	end

	local title = opts.title or "Agent / Recently Modified Files (<CR>: open, <C-d>: inline diff, <C-l>: leaf)"
	if _G.Snacks and Snacks.picker and type(Snacks.picker.pick) == "function" then
		local picker_items = {}
		for idx, e in ipairs(entries) do
			local age = format_age(e.mtime)
			picker_items[#picker_items + 1] = {
				idx = idx,
				file = e.relpath,
				abs_file = e.file,
				cwd = cwd,
				text = string.format("[%s] %s (%s)", e.badge, e.relpath, age),
				label = string.format("%-4s", e.badge),
				comment = string.format("(%s)", age),
				status = e.git_xy,
				relpath = e.relpath,
				badge = e.badge,
				age = age,
			}
		end
		local function item_abs_path(item)
			if not item then
				return nil
			end
			if item.abs_file and item.abs_file ~= "" then
				return item.abs_file
			end
			if _G.Snacks and Snacks.picker and Snacks.picker.util and type(Snacks.picker.util.path) == "function" then
				local p = Snacks.picker.util.path(item)
				if p and p ~= "" then
					return p
				end
			end
			return item.cwd and (item.cwd .. "/" .. item.file) or item.file
		end
		Snacks.picker.pick({
			title = title,
			cwd = cwd,
			items = picker_items,
			format = "file",
			confirm = function(picker, item)
				picker:close()
				local target = item_abs_path(item)
				if not target then
					return
				end
				vim.schedule(function()
					if opts.open_with_leaf then
						open_in_leaf(target)
					else
						vim.cmd.edit(vim.fn.fnameescape(target))
					end
				end)
			end,
			actions = {
				inline_diff = function(picker, item)
					picker:close()
					local target = item_abs_path(item)
					if not target then
						return
					end
					vim.schedule(function()
						vim.cmd.edit(vim.fn.fnameescape(target))
						if _G.GitReview and type(_G.GitReview.toggle_current_file) == "function" then
							_G.GitReview.toggle_current_file()
						end
					end)
				end,
				open_leaf = function(picker, item)
					picker:close()
					local target = item_abs_path(item)
					if not target then
						return
					end
					vim.schedule(function()
						open_in_leaf(target)
					end)
				end,
			},
			win = {
				input = {
					keys = {
						["<c-d>"] = { "inline_diff", mode = { "i", "n" }, desc = "Open in Full-File Inline Diff Review" },
						["<c-l>"] = { "open_leaf", mode = { "i", "n" }, desc = "Open in Leaf Markdown Reader" },
					},
				},
			},
		})
		return
	end

	local labels = {}
	for _, e in ipairs(entries) do
		labels[#labels + 1] = string.format("[%s] %s (%s)", e.badge, e.relpath, format_age(e.mtime))
	end
	vim.ui.select(labels, { prompt = title }, function(_, idx)
		local chosen = idx and entries[idx]
		if chosen then
			if opts.open_with_leaf then
				open_in_leaf(chosen.file)
			else
				vim.cmd.edit(vim.fn.fnameescape(chosen.file))
			end
		end
	end)
end

local function pick_markdown_for_leaf()
	open_modified_files_picker({
		markdown_only = true,
		include_recent_tracked = true,
		open_with_leaf = true,
		limit = 100,
		title = "Open Markdown File in Leaf (<CR>: leaf)",
	})
end

_G.EditorEnhancements = {
	review_ns = review_ns,
	send_to_rex_pane = send_to_rex_pane,
	prompt_and_send_to_rex_pane = prompt_and_send_to_rex_pane,
	add_review_comment = function(buf_or_ctx, comment_text)
		local ctx = type(buf_or_ctx) == "table" and buf_or_ctx or capture_selection_context("n")
		return add_review_comment_entry(ctx, comment_text)
	end,
	prompt_add_review_comment = prompt_add_review_comment,
	get_review_queue = function()
		return review_queue
	end,
	format_review_queue_prompt = format_review_queue_prompt,
	flush_review_comments = flush_review_comments,
	clear_review_comments = clear_review_comments,
	list_review_comments = list_review_comments,
	collect_modified_files = collect_modified_files,
	open_modified_files_picker = open_modified_files_picker,
	open_in_leaf = open_in_leaf,
	toggle_leaf_split = toggle_leaf_split,
	leaf_edit_from_rpc = leaf_edit_from_rpc,
	pick_markdown_for_leaf = pick_markdown_for_leaf,
}

return {
	-- Edit filesystem directories like a regular Neovim buffer
	{
		"stevearc/oil.nvim",
		cmd = "Oil",
		dependencies = { "nvim-mini/mini.icons" },
		keys = {
			{ "-", "<cmd>Oil<cr>", desc = "Open Parent Directory (Oil)" },
			{ "<leader>fo", "<cmd>Oil --float<cr>", desc = "Open Parent Directory Float (Oil)" },
		},
		opts = {
			default_file_explorer = false,
			delete_to_trash = true,
			skip_confirm_for_simple_edits = true,
			view_options = {
				show_hidden = true,
			},
			float = {
				padding = 2,
				max_width = 110,
				max_height = 35,
				border = "rounded",
			},
			keymaps = {
				["q"] = "actions.close",
				["<Esc>"] = "actions.close",
			},
		},
	},

	-- Structural split/join for code blocks using Treesitter
	{
		"Wansmer/treesj",
		keys = {
			{
				"<leader>cj",
				function()
					require("treesj").toggle()
				end,
				desc = "Split / Join Code Block (TreeSJ)",
			},
			{
				"gS",
				function()
					require("treesj").toggle()
				end,
				desc = "Split / Join Code Block (TreeSJ)",
			},
		},
		dependencies = { "nvim-treesitter/nvim-treesitter" },
		opts = {
			use_default_keymaps = false,
			max_join_length = 140,
		},
	},

	-- Editable, context-expandable quickfix list
	{
		"stevearc/quicker.nvim",
		ft = "qf",
		opts = {
			keys = {
				{
					">",
					function()
						require("quicker").expand({ before = 2, after = 2, add_to_existing = true })
					end,
					desc = "Expand quickfix context",
				},
				{
					"<",
					function()
						require("quicker").collapse()
					end,
					desc = "Collapse quickfix context",
				},
			},
		},
	},

	-- Gitsigns inline blame and word-diff toggles
	{
		"lewis6991/gitsigns.nvim",
		opts = {
			current_line_blame = false,
			current_line_blame_opts = {
				delay = 250,
				virt_text_pos = "eol",
			},
			trouble = true,
		},
		keys = {
			{ "<leader>uB", "<cmd>Gitsigns toggle_current_line_blame<cr>", desc = "Toggle Inline Git Blame" },
			{ "<leader>gW", "<cmd>Gitsigns toggle_word_diff<cr>", desc = "Toggle Git Word Diff" },
		},
	},

	-- Agent Modified Files Pickers, Review Comment Queue, Rex Bridge, and Leaf Reader
	{
		"folke/snacks.nvim",
		keys = {
			{
				"<leader>fm",
				function()
					open_modified_files_picker({ include_recent_tracked = false })
				end,
				desc = "Agent / Modified Files (Uncommitted + HEAD)",
			},
			{
				"<leader>fM",
				function()
					open_modified_files_picker({ include_recent_tracked = true, strict_mtime = true, limit = 150 })
				end,
				desc = "Recently Modified Files on Disk (by mtime)",
			},
			{
				"<leader>f?",
				function()
					vim.cmd.edit(vim.fn.stdpath("config") .. "/cheatsheet.pdf")
				end,
				desc = "Open Neovim Keybindings Cheat Sheet",
			},
			{
				"<leader>ml",
				function()
					open_in_leaf()
				end,
				desc = "Open Current File in Leaf (Float TUI, Ctrl+E -> Insert)",
			},
			{
				"<leader>mS",
				function()
					toggle_leaf_split()
				end,
				desc = "Toggle Leaf Live Watch Side Split (Auto-Save)",
			},
			{
				"<leader>mL",
				pick_markdown_for_leaf,
				desc = "Pick Markdown File & Open in Leaf (TUI)",
			},
			{
				"<leader>ac",
				function()
					prompt_add_review_comment(vim.fn.mode())
				end,
				mode = { "n", "x" },
				desc = "Add Review Comment Badge",
			},
			{
				"<leader>af",
				flush_review_comments,
				desc = "Finish & Send Review Comments to LLM",
			},
			{
				"<leader>al",
				list_review_comments,
				desc = "List Queued Review Comments",
			},
			{
				"<leader>aC",
				function()
					clear_review_comments()
					vim.notify("Cleared all queued review comments", vim.log.levels.INFO)
				end,
				desc = "Clear Queued Review Comments",
			},
			{
				"<leader>as",
				function()
					send_to_rex_pane(vim.fn.mode())
				end,
				mode = { "n", "x" },
				desc = "Send Selection/Line + Diagnostics to Rex Pane",
			},
			{
				"<leader>aS",
				function()
					prompt_and_send_to_rex_pane(vim.fn.mode())
				end,
				mode = { "n", "x" },
				desc = "Send Selection/Line + Prompt to Rex Pane",
			},
		},
	},

	{
		"folke/which-key.nvim",
		optional = true,
		opts = {
			spec = {
				{ "<leader>a", group = "ai / agent review", icon = { icon = "🤖", color = "purple" } },
				{ "<leader>m", group = "markdown / leaf", icon = { icon = "🍃", color = "green" } },
			},
		},
	},
}
