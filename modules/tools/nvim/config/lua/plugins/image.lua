-- Rich image and multi-page PDF viewer powered by snacks.image (Kitty Graphics Protocol).
--
-- - Works in both Ghostty and Rex (both use libghostty-vt). Setting
--   SNACKS_GHOSTTY=1 when TERM_PROGRAM is "rex" or "ghostty" lets snacks.image
--   enable Kitty graphics + Unicode placeholders immediately without waiting on
--   or failing XTVERSION TermResponse in Rex's PTY.
-- - Adds a multi-page PDF controller whenever a *.pdf buffer is opened:
--   - Queries page count via `pdfinfo` and renders only the active page on
--     demand (`file.pdf#page=N`), keeping 100+ page PDFs instantaneous.
--   - Binds j / n / <Down> / <PageDown> / ]p (next page),
--           k / p / <Up> / <PageUp> / [p (previous page),
--           gg / G (first / last page),
--           y (copy current page's text to clipboard),
--           Y (copy entire PDF's text to clipboard), and
--           q (quit viewer cleanly).

local term_prog = (vim.env.TERM_PROGRAM or ""):lower()
if term_prog == "rex" or term_prog == "ghostty" then
	vim.env.SNACKS_GHOSTTY = "1"
end

local function query_pdf_pages(file)
	if vim.fn.executable("pdfinfo") ~= 1 then
		return 1
	end
	local ok, res = pcall(function()
		return vim.system({ "pdfinfo", file }, { text = true }):wait(2000)
	end)
	if not ok or not res or res.code ~= 0 or not res.stdout then
		return 1
	end
	local pages = res.stdout:match("Pages:%s*(%d+)")
	return math.max(1, tonumber(pages) or 1)
end

local function update_pdf_winbar(buf)
	if not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	local file = vim.b[buf].pdf_file or vim.api.nvim_buf_get_name(buf)
	local name = vim.fn.fnamemodify(file, ":t")
	local page = vim.b[buf].pdf_page or 1
	local pages = vim.b[buf].pdf_pages or 1
	local bar = string.format(
		" 📄 %s — Page %d / %d   [j/n: next, k/p: prev, gg/G: first/last, y/Y: yank text, q: quit]",
		name,
		page,
		pages
	)
	for _, win in ipairs(vim.fn.win_findbuf(buf)) do
		if vim.api.nvim_win_is_valid(win) then
			vim.wo[win].winbar = bar
		end
	end
	if vim.api.nvim_get_current_buf() == buf then
		vim.wo.winbar = bar
	end
end

local function render_pdf_page(buf)
	local file = vim.b[buf].pdf_file
	local page = vim.b[buf].pdf_page or 1
	if not file or file == "" then
		return
	end
	update_pdf_winbar(buf)
	if _G.Snacks and Snacks.image and Snacks.image.buf and type(Snacks.image.buf.attach) == "function" then
		Snacks.image.buf.attach(buf, { src = string.format("%s#page=%d", file, page) })
	end
end

local function goto_page(buf, target)
	buf = buf or vim.api.nvim_get_current_buf()
	if not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	local pages = vim.b[buf].pdf_pages or 1
	local current = vim.b[buf].pdf_page or 1
	local clamped = math.max(1, math.min(pages, target))
	if clamped == current then
		return
	end
	vim.b[buf].pdf_page = clamped
	render_pdf_page(buf)
end

local function next_page(buf)
	buf = buf or vim.api.nvim_get_current_buf()
	local step = math.max(1, vim.v.count1 or 1)
	goto_page(buf, (vim.b[buf].pdf_page or 1) + step)
end

local function prev_page(buf)
	buf = buf or vim.api.nvim_get_current_buf()
	local step = math.max(1, vim.v.count1 or 1)
	goto_page(buf, (vim.b[buf].pdf_page or 1) - step)
end

local function yank_pdf_text(buf, all_pages)
	buf = buf or vim.api.nvim_get_current_buf()
	local file = vim.b[buf].pdf_file or vim.api.nvim_buf_get_name(buf)
	if file == "" or vim.fn.executable("pdftotext") ~= 1 then
		vim.notify("pdftotext is not available", vim.log.levels.WARN)
		return
	end
	local page = tostring(vim.b[buf].pdf_page or 1)
	local cmd = all_pages and { "pdftotext", file, "-" } or { "pdftotext", "-f", page, "-l", page, file, "-" }
	local ok, res = pcall(function()
		return vim.system(cmd, { text = true }):wait(5000)
	end)
	if not ok or not res or res.code ~= 0 then
		vim.notify("Failed to extract PDF text", vim.log.levels.ERROR)
		return
	end
	local text = res.stdout or ""
	pcall(vim.fn.setreg, "+", text)
	pcall(vim.fn.setreg, '"', text)
	local label = all_pages and "all pages" or ("page " .. page)
	vim.notify(string.format("Copied %s (%d chars) to clipboard", label, #text), vim.log.levels.INFO)
end

local function quit_viewer(buf)
	buf = buf or vim.api.nvim_get_current_buf()
	local listed = vim.fn.getbufinfo({ buflisted = 1 })
	local wins = vim.api.nvim_tabpage_list_wins(0)
	local has_other_modified = false
	for _, b in ipairs(listed) do
		if b.bufnr ~= buf and b.changed == 1 then
			has_other_modified = true
			break
		end
	end
	if #listed <= 1 and #wins <= 1 and not has_other_modified then
		vim.cmd("qa!")
	else
		pcall(vim.api.nvim_buf_delete, buf, { force = true })
	end
end

local function bind_viewer_quit(buf)
	vim.keymap.set("n", "q", function()
		quit_viewer(buf)
	end, { buffer = buf, silent = true, nowait = true, desc = "Quit Media Viewer" })
end

local function attach_pdf(buf, file, opts)
	buf = buf or vim.api.nvim_get_current_buf()
	file = (file and file ~= "") and file or vim.api.nvim_buf_get_name(buf)
	file = file:gsub("#page=%d+$", "")
	if file == "" then
		return
	end
	vim.b[buf].pdf_file = file
	vim.b[buf].pdf_pages = query_pdf_pages(file)
	vim.b[buf].pdf_page = vim.b[buf].pdf_page or 1

	local kopts = { buffer = buf, silent = true, nowait = true }
	for _, lhs in ipairs({ "j", "n", "<Down>", "<PageDown>", "<C-f>", "<C-d>", "]p" }) do
		vim.keymap.set("n", lhs, function()
			next_page(buf)
		end, vim.tbl_extend("force", kopts, { desc = "PDF: Next Page" }))
	end
	for _, lhs in ipairs({ "k", "p", "<Up>", "<PageUp>", "<C-b>", "<C-u>", "[p" }) do
		vim.keymap.set("n", lhs, function()
			prev_page(buf)
		end, vim.tbl_extend("force", kopts, { desc = "PDF: Previous Page" }))
	end
	vim.keymap.set("n", "gg", function()
		if vim.v.count > 0 then
			goto_page(buf, vim.v.count)
		else
			goto_page(buf, 1)
		end
	end, vim.tbl_extend("force", kopts, { desc = "PDF: First / Nth Page" }))
	vim.keymap.set("n", "G", function()
		if vim.v.count > 0 then
			goto_page(buf, vim.v.count)
		else
			goto_page(buf, vim.b[buf].pdf_pages or 1)
		end
	end, vim.tbl_extend("force", kopts, { desc = "PDF: Last / Nth Page" }))
	vim.keymap.set("n", "y", function()
		yank_pdf_text(buf, false)
	end, vim.tbl_extend("force", kopts, { desc = "PDF: Yank Current Page Text" }))
	vim.keymap.set("n", "Y", function()
		yank_pdf_text(buf, true)
	end, vim.tbl_extend("force", kopts, { desc = "PDF: Yank All Pages Text" }))
	bind_viewer_quit(buf)

	if opts and opts.skip_initial_render then
		update_pdf_winbar(buf)
	else
		render_pdf_page(buf)
	end
end

vim.api.nvim_create_autocmd("FileType", {
	pattern = "image",
	callback = function(ev)
		local name = vim.api.nvim_buf_get_name(ev.buf):gsub("#page=%d+$", "")
		if name:lower():match("%.pdf$") then
			if not vim.b[ev.buf].pdf_file then
				attach_pdf(ev.buf, name, { skip_initial_render = true })
			else
				update_pdf_winbar(ev.buf)
			end
		else
			bind_viewer_quit(ev.buf)
		end
	end,
})

_G.PdfViewer = {
	attach_pdf = attach_pdf,
	goto_page = goto_page,
	next_page = next_page,
	prev_page = prev_page,
	yank_page = function(buf)
		yank_pdf_text(buf, false)
	end,
	yank_all = function(buf)
		yank_pdf_text(buf, true)
	end,
	quit = quit_viewer,
}

return {
	{
		"folke/snacks.nvim",
		opts = {
			image = {
				enabled = true,
				doc = {
					enabled = true,
					inline = true,
					float = true,
					max_width = 100,
					max_height = 50,
				},
			},
		},
	},
}
