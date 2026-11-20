-- Run from the repository root: nvim --headless -u NONE -i NONE -l tests/nvim-config.lua
local specs = dofile("modules/tools/nvim/config/lua/plugins/languages.lua")
local mason, biome, conform_ft
for _, spec in ipairs(specs) do
	if spec[1] == "mason-org/mason.nvim" then
		mason = spec
	elseif spec.opts and spec.opts.formatters and spec.opts.formatters.biome then
		biome = spec.opts.formatters.biome.condition
		conform_ft = spec.opts.formatters_by_ft
	end
end

local failures = {}
local function check(name, condition)
	print((condition and "PASS " or "FAIL ") .. name)
	if not condition then
		table.insert(failures, name)
	end
end

-- Lazy merges this spec over LazyVim's. A custom config replaces its installer.
local inherited = function() end
local inherited_opts = { ensure_installed = { "stylua", "shfmt", "goimports", "gofumpt" } }
local merged = vim.tbl_deep_extend("force", { config = inherited }, mason)
if type(mason.opts) == "function" then
	mason.opts({}, inherited_opts)
	merged.opts = inherited_opts
else
	merged.opts = vim.tbl_deep_extend("force", {}, inherited_opts, mason.opts)
	-- LazyVim opts_extend appends these lists rather than replacing them.
	merged.opts.ensure_installed = vim.list_extend(inherited_opts.ensure_installed, mason.opts.ensure_installed)
end
check(
	"Mason tools are unique after inherited options merge",
	#vim.list.unique(vim.deepcopy(merged.opts.ensure_installed)) == #merged.opts.ensure_installed
)
check("Mason retains LazyVim's installer", merged.config == inherited)
check("Mason appends its tools to PATH", merged.opts.PATH == "append")
check(
	"Mason retains its writable install directory",
	merged.opts.install_root_dir == vim.fn.stdpath("data") .. "/mason"
)
check(
	"Mason retains declared tools",
	vim.tbl_contains(merged.opts.ensure_installed, "stylua")
		and vim.tbl_contains(merged.opts.ensure_installed, "prettier")
)

check(
	"Alejandra uses the Nix package instead of requiring Cargo",
	not vim.tbl_contains(merged.opts.ensure_installed, "alejandra")
)

local root = vim.fn.tempname()
local cwd = vim.fn.getcwd()
vim.fn.mkdir(root .. "/outside", "p")
vim.fn.mkdir(root .. "/project/src", "p")
vim.fn.chdir(root .. "/outside")
local filename = root .. "/project/src/example.ts"
vim.fn.writefile({ "const x = 1;" }, filename)
for _, config in ipairs({ "biome.json", "biome.jsonc" }) do
	vim.fn.writefile({ "{}" }, root .. "/project/" .. config)
	-- Conform calls condition(formatter_config, context), not condition(context).
	check("Biome finds " .. config .. " outside cwd", biome({}, { filename = filename }) ~= nil)
	vim.fn.delete(root .. "/project/" .. config)
end
check("Biome stays disabled without project config", not biome({}, { filename = filename }))
check(
	"JS/TS/JSON formatters fall back from biome to prettier with stop_after_first",
	conform_ft
		and conform_ft.typescript
		and conform_ft.typescript[1] == "biome"
		and conform_ft.typescript[2] == "prettier"
		and conform_ft.typescript.stop_after_first == true
		and conform_ft.json
		and conform_ft.json[1] == "biome"
		and conform_ft.json[2] == "prettier"
		and conform_ft.json.stop_after_first == true
)
vim.fn.chdir(cwd)
vim.fn.delete(root, "rf")

-- Colorscheme SnacksZenBackdrop tests (Light & Dark system theme)
local colorscheme_specs = dofile("modules/tools/nvim/config/lua/plugins/colorscheme.lua")
local gh_theme_setup = nil
package.preload["github-theme"] = function()
	return {
		setup = function(opts)
			gh_theme_setup = opts
		end,
	}
end
for _, spec in ipairs(colorscheme_specs) do
	if spec[1] == "projekt0n/github-nvim-theme" and type(spec.config) == "function" then
		spec.config()
	end
end
package.preload["github-theme"] = nil
package.loaded["github-theme"] = nil

check(
	"Dark theme defines SnacksZenBackdrop (#161b22)",
	gh_theme_setup
		and gh_theme_setup.groups
		and gh_theme_setup.groups.github_dark_default
		and gh_theme_setup.groups.github_dark_default.SnacksZenBackdrop
		and gh_theme_setup.groups.github_dark_default.SnacksZenBackdrop.bg == "#161b22"
)
check(
	"Light theme defines SnacksZenBackdrop (#f6f8fa)",
	gh_theme_setup
		and gh_theme_setup.groups
		and gh_theme_setup.groups.github_light_default
		and gh_theme_setup.groups.github_light_default.SnacksZenBackdrop
		and gh_theme_setup.groups.github_light_default.SnacksZenBackdrop.bg == "#f6f8fa"
)

-- Zen & Presentation Mode tests
local ok_zen, zen_specs = pcall(dofile, "modules/tools/nvim/config/lua/plugins/zen.lua")
check("zen.lua plugin spec loads", ok_zen and type(zen_specs) == "table")
local zen_spec = ok_zen and zen_specs[1] or {}
local zen_opts = zen_spec.opts and zen_spec.opts.zen or {}
local zen_win = zen_opts.win or {}

check("Zen window is borderless", zen_win.border == "none")
check(
	"Zen window hides gutter chrome (number, relativenumber, signcolumn, foldcolumn) across all files",
	zen_win.wo
		and zen_win.wo.number == false
		and zen_win.wo.relativenumber == false
		and zen_win.wo.signcolumn == "no"
		and zen_win.wo.foldcolumn == "0"
)
check(
	"Zen window preserves pure Normal background",
	zen_win.wo and type(zen_win.wo.winhighlight) == "string" and zen_win.wo.winhighlight:find("Normal:Normal", 1, true) ~= nil
)
check(
	"Zen backdrop uses shaded SnacksZenBackdrop surface",
	zen_win.backdrop
		and zen_win.backdrop.transparent == false
		and zen_win.backdrop.win
		and zen_win.backdrop.win.wo
		and zen_win.backdrop.win.wo.winhighlight:find("SnacksZenBackdrop", 1, true) ~= nil
)

local key_map = {}
for _, k in ipairs(zen_spec.keys or {}) do
	key_map[k[1]] = k[2]
end
check(
	"Only <leader>zz (Zen) and <leader>zp (Presentation) are permanently registered under <leader>z",
	type(key_map["<leader>zz"]) == "function"
		and type(key_map["<leader>zp"]) == "function"
		and key_map["<leader>z"] == false
		and key_map["<leader>Z"] == false
		and key_map["<leader>z+"] == nil
)

-- Dynamic adjustment keymaps appear only when Zen is open and are removed on close
vim.o.columns = 200
vim.o.laststatus = 3
vim.o.showtabline = 2
local reader_width = type(zen_win.width) == "function" and zen_win.width() or zen_win.width
check("Zen Reader default width is 85% (170 on 200 cols)", reader_width == 170)

check(
	"Adjustment keymaps are absent before Zen opens",
	vim.fn.maparg("<leader>z.", "n") == ""
		and vim.fn.maparg("<leader>z<Right>", "n") == ""
		and vim.fn.maparg("<leader>z+", "n") == ""
		and vim.fn.maparg("<leader>zf", "n") == ""
)

if type(zen_opts.on_open) == "function" and type(zen_opts.on_close) == "function" then
	zen_opts.on_open({ opts = zen_win })
	check("Zen hides statusline and tabline on open", vim.o.laststatus == 0 and vim.o.showtabline == 0)
	check(
		"Adjustment keymaps (., ,, <Left>, <Right> for width; +, =, - for font; f, q) appear while Zen is open",
		vim.fn.maparg("<leader>z.", "n") ~= ""
			and vim.fn.maparg("<leader>z,", "n") ~= ""
			and vim.fn.maparg("<leader>z<Right>", "n") ~= ""
			and vim.fn.maparg("<leader>z<Left>", "n") ~= ""
			and vim.fn.maparg("<leader>z+", "n") ~= ""
			and vim.fn.maparg("<leader>z=", "n") ~= ""
			and vim.fn.maparg("<leader>z-", "n") ~= ""
			and vim.fn.maparg("<leader>zf", "n") ~= ""
			and vim.fn.maparg("<leader>zq", "n") ~= ""
	)
	zen_opts.on_close()
	check("Zen restores statusline and tabline on close", vim.o.laststatus == 3 and vim.o.showtabline == 2)
	check(
		"Adjustment keymaps are removed when Zen closes",
		vim.fn.maparg("<leader>z.", "n") == ""
			and vim.fn.maparg("<leader>z<Right>", "n") == ""
			and vim.fn.maparg("<leader>z+", "n") == ""
			and vim.fn.maparg("<leader>zf", "n") == ""
	)
end

-- Presentation mode (<leader>zp) without REX_SESSION degrades gracefully and uses 92% width
vim.env.REX_SESSION = nil
vim.env.REX_BLOCK = nil
local opened_in_presentation = false
_G.Snacks = {
	zen = {
		win = nil,
		zen = function()
			opened_in_presentation = true
			zen_opts.on_open({ opts = zen_win })
		end,
	},
}
if type(key_map["<leader>zp"]) == "function" then
	key_map["<leader>zp"]()
	local pres_width = type(zen_win.width) == "function" and zen_win.width() or zen_win.width
	check("Presentation mode (<leader>zp) opens with 92% width (184 on 200 cols) without REX_SESSION", opened_in_presentation and pres_width == 184)
	zen_opts.on_close()
end

-- Switching from Presentation Mode (<leader>zp) to Zen Reader (<leader>zz) preserves saved chrome state
vim.o.laststatus = 3
vim.o.showtabline = 2
local fake_win = {
	opts = { width = 184 },
	valid = function()
		return true
	end,
	update = function() end,
}
_G.Snacks = {
	zen = {
		win = nil,
		zen = function()
			if _G.Snacks.zen.win then
				_G.Snacks.zen.win = nil
				zen_opts.on_close()
			else
				_G.Snacks.zen.win = fake_win
				zen_opts.on_open({ opts = zen_win })
			end
		end,
	},
}
key_map["<leader>zp"]() -- open Presentation Mode
key_map["<leader>zz"]() -- downgrade to Zen Reader while staying open
check("Downgrading Presentation (<leader>zp) to Zen Reader (<leader>zz) keeps Zen open at 85% width", _G.Snacks.zen.win ~= nil and fake_win.opts.width == 170)

-- Adjustment keys keep the <leader>z which-key popup open in hydra loop mode
local wk_shown = nil
package.preload["which-key"] = function()
	return {
		show = function(opts)
			wk_shown = opts
		end,
	}
end
vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<leader>z.", true, false, true), "x", false)
check(
	"Zen width key (<leader>z.) widens column and keeps which-key <leader>z popup open (loop = true)",
	fake_win.opts.width == 180 and wk_shown and wk_shown.keys == "<leader>z" and wk_shown.loop == true
)
wk_shown = nil
vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<leader>z<Left>", true, false, true), "x", false)
check(
	"Zen width key (<leader>z<Left>) narrows column and keeps which-key <leader>z popup open (loop = true)",
	fake_win.opts.width == 170 and wk_shown and wk_shown.keys == "<leader>z" and wk_shown.loop == true
)
package.preload["which-key"] = nil
package.loaded["which-key"] = nil

key_map["<leader>zz"]() -- close Zen Reader
check("Closing after mode switch restores original laststatus and showtabline", vim.o.laststatus == 3 and vim.o.showtabline == 2)

-- VimLeavePre waits on in-flight async Rex restore processes started by on_close
local waited_on_pending = 0
local orig_system = vim.system
local orig_executable = vim.fn.executable
vim.env.REX_SESSION = "session:test"
vim.env.REX_BLOCK = "block:test"
vim.fn.executable = function()
	return 1
end
vim.system = function(cmd, _)
	if cmd[2] == "client" and cmd[3] == "ls" then
		return {
			wait = function()
				return { code = 0, stdout = '{"clients":[{"client_id":"client:app1","info":{"kind":"app"}}]}' }
			end,
		}
	elseif cmd[2] == "session" and cmd[3] == "inspect" then
		return {
			wait = function()
				return { code = 0, stdout = '{"windows":[{"zoomed_block_id":null}]}' }
			end,
		}
	end
	return {
		wait = function()
			waited_on_pending = waited_on_pending + 1
			return { code = 0, stdout = "" }
		end,
	}
end

key_map["<leader>zp"]() -- enters Presentation Mode (zooms + increases font)
key_map["<leader>zp"]() -- triggers on_close -> async restore_presentation_rex(false)
vim.api.nvim_exec_autocmds("VimLeavePre", {})
check("VimLeavePre waits on in-flight async Rex font reset and unzoom processes", waited_on_pending == 2)

vim.system = orig_system
vim.fn.executable = orig_executable
vim.env.REX_SESSION = nil
vim.env.REX_BLOCK = nil

-- Inline Commit Review highlight groups (Dark & Light Merino themes)
local dark_groups = gh_theme_setup and gh_theme_setup.groups and gh_theme_setup.groups.github_dark_default or {}
local light_groups = gh_theme_setup and gh_theme_setup.groups and gh_theme_setup.groups.github_light_default or {}

check(
	"Dark theme defines full-file inline diff highlights (Add/Change/Delete line + word)",
	dark_groups.GitSignsAddLn
		and dark_groups.GitSignsAddInline
		and dark_groups.GitSignsChangeLn
		and dark_groups.GitSignsChangeInline
		and dark_groups.GitSignsDeleteVirtLn
		and dark_groups.GitSignsDeleteInline
)
check(
	"Light theme defines full-file inline diff highlights (Add/Change/Delete line + word)",
	light_groups.GitSignsAddLn
		and light_groups.GitSignsAddInline
		and light_groups.GitSignsChangeLn
		and light_groups.GitSignsChangeInline
		and light_groups.GitSignsDeleteVirtLn
		and light_groups.GitSignsDeleteInline
)

-- Git Commit Review module tests
local ok_gr, gr_specs = pcall(dofile, "modules/tools/nvim/config/lua/plugins/git-review.lua")
check("git-review.lua plugin spec loads", ok_gr and type(gr_specs) == "table" and type(_G.GitReview) == "table")
local gr_spec = ok_gr and gr_specs[1] or {}
local gr_keys = {}
for _, k in ipairs(gr_spec.keys or {}) do
	gr_keys[k[1]] = k[2]
end
check(
	"Git review entry keymaps (<leader>gr, <leader>gR, <leader>gd) are registered",
	type(gr_keys["<leader>gr"]) == "function"
		and type(gr_keys["<leader>gR"]) == "function"
		and type(gr_keys["<leader>gd"]) == "function"
)

if type(_G.GitReview) == "table" then
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_set_current_buf(buf)
	local old_lines = {
		"removed_header_line",
		"local a = 1",
		"local old_name = 'hello world'",
		"local middle_deleted = true",
		"return a",
	}
	local new_lines = {
		"local a = 1",
		"local new_name = 'hello universe'",
		"print(added_line)",
		"return a",
		"-- trailing added line",
	}
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, new_lines)
	_G.GitReview.render_buffer_diff(buf, old_lines, new_lines, { commit = "abc1234", file = "test.lua" })

	local ns = _G.GitReview.ns
	local marks = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })
	local has_add_ln, has_change_ln, has_delete_virt, has_change_word, has_above_top = false, false, false, false, false
	for _, m in ipairs(marks) do
		local row = m[2]
		local d = m[4] or {}
		if d.line_hl_group == "GitSignsAddLn" then
			has_add_ln = true
		end
		if d.line_hl_group == "GitSignsChangeLn" then
			has_change_ln = true
		end
		if d.hl_group == "GitSignsChangeInline" or d.hl_group == "GitSignsAddInline" then
			has_change_word = true
		end
		if d.virt_lines and #d.virt_lines > 0 then
			has_delete_virt = true
			if row == 0 and d.virt_lines_above then
				has_above_top = true
			end
		end
	end
	check("Inline review highlights added lines in green (GitSignsAddLn)", has_add_ln)
	check("Inline review highlights modified lines in yellow (GitSignsChangeLn)", has_change_ln)
	check("Inline review highlights changed words inline (GitSignsChangeInline)", has_change_word)
	check("Inline review renders deleted lines as red virtual lines (including before line 1)", has_delete_virt and has_above_top)
	check(
		"Active review registers <leader>gf and <leader>gq dynamically as buffer-local keymaps",
		vim.fn.maparg("<leader>gf", "n") ~= "" and vim.fn.maparg("<leader>gq", "n") ~= ""
	)
	local other_buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_set_current_buf(other_buf)
	check(
		"Non-review buffer does not inherit <leader>gf or <leader>gq",
		vim.fn.maparg("<leader>gf", "n") == "" and vim.fn.maparg("<leader>gq", "n") == ""
	)
	vim.api.nvim_set_current_buf(buf)
	vim.api.nvim_buf_delete(other_buf, { force = true })

	-- Hunk navigation moves cursor between hunks cleanly
	vim.api.nvim_win_set_cursor(0, { 1, 0 })
	_G.GitReview.next_hunk()
	local row_after_next = vim.api.nvim_win_get_cursor(0)[1]
	check("next_hunk() jumps to the next changed hunk", row_after_next >= 2)
	_G.GitReview.prev_hunk()
	local row_after_prev = vim.api.nvim_win_get_cursor(0)[1]
	check("prev_hunk() jumps back to the previous hunk", row_after_prev == 1)

	-- Clearing review removes extmarks and dynamic keymaps
	_G.GitReview.clear(buf)
	local remaining = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, {})
	check(
		"clear() removes all inline review extmarks and unregisters <leader>gf/<leader>gq",
		#remaining == 0 and vim.fn.maparg("<leader>gf", "n") == "" and vim.fn.maparg("<leader>gq", "n") == ""
	)

	-- Completely deleted file (new_lines = {}) still renders virtual red deleted lines on row 0
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "" })
	_G.GitReview.render_buffer_diff(buf, { "deleted line 1", "deleted line 2" }, {}, { commit = "abc1234", file = "deleted.lua" })
	local del_marks = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })
	check(
		"Deleted file (empty new_lines) still renders virtual red deleted lines on row 0",
		#del_marks == 1 and del_marks[1][4] and del_marks[1][4].virt_lines and #del_marks[1][4].virt_lines == 2
	)
	_G.GitReview.clear(buf)
	vim.api.nvim_buf_delete(buf, { force = true })
end

-- snacks.image & Multi-Page PDF Viewer tests (image.lua)
vim.env.TERM_PROGRAM = "rex"
vim.env.SNACKS_GHOSTTY = nil
local ok_img, img_specs = pcall(dofile, "modules/tools/nvim/config/lua/plugins/image.lua")
check("image.lua plugin spec loads", ok_img and type(img_specs) == "table" and type(_G.PdfViewer) == "table")
local img_spec = ok_img and img_specs[1] or {}
local img_opts = img_spec.opts and img_spec.opts.image or {}

check(
	"snacks.image is enabled with inline document rendering",
	img_opts.enabled == true and img_opts.doc and img_opts.doc.enabled == true and img_opts.doc.inline == true
)
check("image.lua sets SNACKS_GHOSTTY=1 when running inside Rex", vim.env.SNACKS_GHOSTTY == "1")

if type(_G.PdfViewer) == "table" then
	local pdf_buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_set_current_buf(pdf_buf)
	local attached_srcs = {}
	local yanked_cmd = nil
	local orig_sys = vim.system
	local orig_exec = vim.fn.executable
	vim.fn.executable = function()
		return 1
	end
	vim.system = function(cmd, _)
		if cmd[1] == "pdfinfo" then
			return {
				wait = function()
					return { code = 0, stdout = "Title: Demo\nPages:          5\nPage size: 612 x 792 pts\n" }
				end,
			}
		elseif cmd[1] == "pdftotext" then
			yanked_cmd = cmd
			return {
				wait = function()
					return { code = 0, stdout = "Extracted page text" }
				end,
			}
		end
		return {
			wait = function()
				return { code = 0, stdout = "" }
			end,
		}
	end
	_G.Snacks = {
		image = {
			buf = {
				attach = function(_, opts)
					table.insert(attached_srcs, opts and opts.src or "")
				end,
			},
		},
	}

	_G.PdfViewer.attach_pdf(pdf_buf, "/tmp/sample.pdf")
	check(
		"attach_pdf parses page count (5), attaches #page=1, and updates winbar",
		vim.b[pdf_buf].pdf_pages == 5
			and vim.b[pdf_buf].pdf_page == 1
			and attached_srcs[#attached_srcs] == "/tmp/sample.pdf#page=1"
			and (vim.wo.winbar or ""):find("Page 1 / 5", 1, true) ~= nil
	)
	check(
		"attach_pdf binds j, n, k, p, gg, G, y, Y, q on PDF buffer",
		vim.fn.maparg("j", "n") ~= ""
			and vim.fn.maparg("n", "n") ~= ""
			and vim.fn.maparg("k", "n") ~= ""
			and vim.fn.maparg("p", "n") ~= ""
			and vim.fn.maparg("y", "n") ~= ""
			and vim.fn.maparg("Y", "n") ~= ""
			and vim.fn.maparg("q", "n") ~= ""
	)

	_G.PdfViewer.next_page(pdf_buf)
	check(
		"next_page advances to page 2 and attaches #page=2",
		vim.b[pdf_buf].pdf_page == 2 and attached_srcs[#attached_srcs] == "/tmp/sample.pdf#page=2"
	)

	_G.PdfViewer.prev_page(pdf_buf)
	local count_before_clamp = #attached_srcs
	_G.PdfViewer.prev_page(pdf_buf) -- already on page 1; should clamp without re-attaching
	check(
		"prev_page returns to page 1 and clamps without redundant re-attach",
		vim.b[pdf_buf].pdf_page == 1 and #attached_srcs == count_before_clamp
	)

	_G.PdfViewer.goto_page(pdf_buf, 99)
	check(
		"goto_page clamps to last page (5)",
		vim.b[pdf_buf].pdf_page == 5 and attached_srcs[#attached_srcs] == "/tmp/sample.pdf#page=5"
	)

	_G.PdfViewer.yank_page(pdf_buf)
	check(
		"yank_page runs pdftotext for the current page (-f 5 -l 5)",
		yanked_cmd and yanked_cmd[1] == "pdftotext" and yanked_cmd[3] == "5" and yanked_cmd[5] == "5"
	)

	-- Opening a .pdf buffer via snacks.image (which sets filetype=image) initializes PDF controls without duplicate page-1 attach
	local ft_buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_name(ft_buf, "/tmp/auto.pdf")
	vim.api.nvim_set_current_buf(ft_buf)
	local count_before_ft = #attached_srcs
	vim.bo[ft_buf].filetype = "image"
	check(
		"FileType=image on .pdf initializes pdf_pages and winbar without duplicate page-1 attach",
		vim.b[ft_buf].pdf_pages == 5
			and vim.b[ft_buf].pdf_page == 1
			and #attached_srcs == count_before_ft
	)
	_G.PdfViewer.next_page(ft_buf)
	check(
		"next_page after FileType=image attaches #page=2",
		vim.b[ft_buf].pdf_page == 2 and (attached_srcs[#attached_srcs] or ""):find("auto%.pdf#page=2") ~= nil
	)

	vim.system = orig_sys
	vim.fn.executable = orig_exec
	vim.api.nvim_buf_delete(ft_buf, { force = true })
	vim.api.nvim_buf_delete(pdf_buf, { force = true })
end

-- smart-cat router script tests
local smart_cat = vim.fn.getcwd() .. "/modules/tools/bat/scripts/smart-cat"
check("smart-cat script exists and is executable", vim.fn.executable(smart_cat) == 1)

if vim.fn.executable(smart_cat) == 1 then
	local sc_tmp = vim.fn.tempname()
	vim.fn.mkdir(sc_tmp .. "/bin", "p")
	for _, tool in ipairs({ "bat", "leaf", "nvim" }) do
		local p = sc_tmp .. "/bin/" .. tool
		vim.fn.writefile({
			"#!/usr/bin/env sh",
			'printf "%s:%s\\n" "' .. tool .. '" "$*"',
		}, p)
		vim.fn.setfperm(p, "rwxr-xr-x")
	end
	local md_file = sc_tmp .. "/readme.md"
	local pdf_file = sc_tmp .. "/paper.pdf"
	local png_file = sc_tmp .. "/diagram.png"
	local txt_file = sc_tmp .. "/notes.txt"
	vim.fn.writefile({ "# hello" }, md_file)
	vim.fn.writefile({ "%PDF-1.7" }, pdf_file)
	vim.fn.writefile({ "PNG" }, png_file)
	vim.fn.writefile({ "hello" }, txt_file)

	local function run_sc(args, force_tty)
		local env = {
			PATH = sc_tmp .. "/bin:/usr/bin:/bin",
			SMART_CAT_FORCE_TTY = force_tty and "1" or "0",
		}
		local res = vim.system(vim.list_extend({ smart_cat }, args), { text = true, env = env }):wait(2000)
		return vim.trim(res.stdout or "")
	end

	check("smart-cat routes piped .md to bat", run_sc({ md_file }, false) == "bat:" .. md_file)
	check("smart-cat routes piped .pdf (e.g. cat foo.pdf | pbcopy) to bat", run_sc({ pdf_file }, false) == "bat:" .. pdf_file)
	check("smart-cat routes interactive .md to leaf", run_sc({ md_file }, true) == "leaf:" .. md_file)
	check("smart-cat routes interactive .pdf to nvim", run_sc({ pdf_file }, true) == "nvim:" .. pdf_file)
	check("smart-cat routes interactive .png to nvim", run_sc({ png_file }, true) == "nvim:" .. png_file)
	check("smart-cat routes interactive .txt to bat", run_sc({ txt_file }, true) == "bat:" .. txt_file)
	check("smart-cat routes flags (-n) on .md to bat", run_sc({ "-n", md_file }, true) == "bat:-n " .. md_file)
	check("smart-cat routes multiple files to bat", run_sc({ md_file, txt_file }, true) == "bat:" .. md_file .. " " .. txt_file)
	vim.fn.delete(sc_tmp, "rf")
end

-- Editor enhancements, QoL options, blink signature help, markview hybrid mode, and lockfile pins
dofile("modules/tools/nvim/config/lua/config/options.lua")
check(
	"options.lua configures histogram diff algorithm and linematch:60",
	vim.o.diffopt:find("algorithm:histogram", 1, true) ~= nil
		and vim.o.diffopt:find("linematch:60", 1, true) ~= nil
)

local ok_blink, blink_specs = pcall(dofile, "modules/tools/nvim/config/lua/plugins/blink.lua")
local blink_opts = ok_blink and blink_specs[1] and blink_specs[1].opts or {}
check(
	"blink.lua enables signature help and auto-show documentation with rounded borders",
	blink_opts.signature
		and blink_opts.signature.enabled == true
		and blink_opts.signature.window
		and blink_opts.signature.window.border == "rounded"
		and blink_opts.completion
		and blink_opts.completion.documentation
		and blink_opts.completion.documentation.auto_show == true
)

local ok_md, md_specs = pcall(dofile, "modules/tools/nvim/config/lua/plugins/markdown.lua")
local markview_opts = nil
for _, s in ipairs(ok_md and md_specs or {}) do
	if s[1] == "OXY2DEV/markview.nvim" then
		markview_opts = s.opts
	end
end
check(
	"markdown.lua enables Insert-mode hybrid unconcealing (hybrid_modes = { 'i' })",
	markview_opts
		and markview_opts.preview
		and type(markview_opts.preview.hybrid_modes) == "table"
		and vim.tbl_contains(markview_opts.preview.hybrid_modes, "i")
)

local ok_ed, ed_specs = pcall(dofile, "modules/tools/nvim/config/lua/plugins/editor.lua")
check("editor.lua plugin spec loads", ok_ed and type(ed_specs) == "table" and type(_G.EditorEnhancements) == "table")
local ed_by_name = {}
for _, s in ipairs(ok_ed and ed_specs or {}) do
	ed_by_name[s[1]] = s
end
check(
	"editor.lua configures oil.nvim, treesj, quicker.nvim, gitsigns.nvim, and Rex pane sender",
	ed_by_name["stevearc/oil.nvim"] ~= nil
		and ed_by_name["Wansmer/treesj"] ~= nil
		and ed_by_name["stevearc/quicker.nvim"] ~= nil
		and ed_by_name["lewis6991/gitsigns.nvim"] ~= nil
		and ed_by_name["folke/snacks.nvim"] ~= nil
)

if type(_G.EditorEnhancements) == "table" then
	local rev_buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_set_current_buf(rev_buf)
	vim.bo[rev_buf].filetype = "lua"
	vim.api.nvim_buf_set_lines(rev_buf, 0, -1, false, {
		"local x = 1",
		"local y = 2",
	})
	_G.EditorEnhancements.add_review_comment({
		buf = rev_buf,
		file = "/tmp/demo.lua",
		relpath = "demo.lua",
		ft = "lua",
		start_line = 2,
		end_line = 2,
		header = "demo.lua:2",
		code = "local y = 2",
	}, "Rename y to count")

	local rmarks = vim.api.nvim_buf_get_extmarks(rev_buf, _G.EditorEnhancements.review_ns, 0, -1, { details = true })
	check("add_review_comment places virtual comment badge on buffer line", #rmarks == 1 and rmarks[1][4] and rmarks[1][4].virt_lines ~= nil)
	local formatted = _G.EditorEnhancements.format_review_queue_prompt()
	check(
		"format_review_queue_prompt builds structured markdown with code snippet and feedback",
		type(formatted) == "string"
			and formatted:find("demo.lua:2", 1, true) ~= nil
			and formatted:find("Rename y to count", 1, true) ~= nil
	)
	local flushed = _G.EditorEnhancements.flush_review_comments()
	local rmarks_after = vim.api.nvim_buf_get_extmarks(rev_buf, _G.EditorEnhancements.review_ns, 0, -1, {})
	check(
		"flush_review_comments delivers prompt and clears virtual comment badges",
		flushed == formatted and #rmarks_after == 0 and #_G.EditorEnhancements.get_review_queue() == 0
	)
	vim.api.nvim_buf_delete(rev_buf, { force = true })

	-- open_in_leaf launches Snacks.terminal floating overlay with leaf
	local leaf_launched = nil
	local orig_exec2 = vim.fn.executable
	vim.fn.executable = function(bin)
		if bin == "leaf" then
			return 1
		end
		return orig_exec2(bin)
	end
	_G.Snacks = _G.Snacks or {}
	_G.Snacks.terminal = function(cmd, opts)
		leaf_launched = { cmd = cmd, opts = opts }
	end
	local leaf_ok = _G.EditorEnhancements.open_in_leaf("/tmp/notes.md")
	check(
		"open_in_leaf launches Snacks.terminal floating window with leaf --watch, LEAF_EDITOR bridge, and target file",
		leaf_ok
			and leaf_launched
			and leaf_launched.cmd[1] == "leaf"
			and leaf_launched.cmd[2] == "--watch"
			and leaf_launched.cmd[3] == "/tmp/notes.md"
			and leaf_launched.opts.win.position == "float"
			and leaf_launched.opts.env
			and type(leaf_launched.opts.env.LEAF_EDITOR) == "string"
			and leaf_launched.opts.env.LEAF_EDITOR:find("leaf-nvim-edit", 1, true) ~= nil
	)

	-- toggle_leaf_split opens leaf --watch in a right split and keeps focus in the editor window
	leaf_launched = nil
	local split_ok = _G.EditorEnhancements.toggle_leaf_split("/tmp/notes.md")
	check(
		"toggle_leaf_split launches leaf --watch in a right split with auto_insert=false",
		split_ok
			and leaf_launched
			and leaf_launched.cmd[1] == "leaf"
			and leaf_launched.cmd[2] == "--watch"
			and leaf_launched.cmd[3] == "/tmp/notes.md"
			and leaf_launched.opts.win.position == "right"
			and leaf_launched.opts.auto_insert == false
	)
	vim.fn.executable = orig_exec2

	-- leaf_edit_from_rpc jumps host Neovim buffer to the requested line
	local md_buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_set_current_buf(md_buf)
	vim.api.nvim_buf_set_lines(md_buf, 0, -1, false, { "line 1", "line 2", "line 3", "line 4", "line 5" })
	_G.EditorEnhancements.leaf_edit_from_rpc("", 4)
	vim.wait(100, function()
		return vim.api.nvim_win_get_cursor(0)[1] == 4
	end, 10)
	check("leaf_edit_from_rpc jumps host Neovim cursor to line sent by Ctrl+E in leaf", vim.api.nvim_win_get_cursor(0)[1] == 4)
	vim.cmd("stopinsert")
	vim.api.nvim_buf_delete(md_buf, { force = true })

	-- Verify open_modified_files_picker passes raw 2-char git porcelain status (or nil) so Snacks.picker.format.file_git_status never errors on 'NEW'/'HEAD'/'REPO'
	local picked_spec = nil
	_G.Snacks.picker = {
		pick = function(spec)
			picked_spec = spec
		end,
	}
	local valid_snacks_git_xy = function(xy)
		if xy == nil then
			return true
		end
		if type(xy) ~= "string" or #xy ~= 2 then
			return false
		end
		local s = xy:gsub("T", "M")
		if s:match("%?%?") or s:match("!!") or s:match("UU") or s:match("DD") or s:match("AA") or s:match("U") then
			return true
		end
		if s:match("^[MADRC]") or s:match("[MADRC]$") then
			return true
		end
		return false
	end

	_G.EditorEnhancements.open_modified_files_picker({ include_recent_tracked = true })
	local all_valid_status = picked_spec and type(picked_spec.items) == "table" and #picked_spec.items > 0
	local all_relative_file = picked_spec and type(picked_spec.items) == "table" and #picked_spec.items > 0
	for _, it in ipairs((picked_spec and picked_spec.items) or {}) do
		if not valid_snacks_git_xy(it.status) then
			all_valid_status = false
		end
		-- Snacks.picker.util.path concatenates item.cwd .. "/" .. item.file, so item.file must be relative when item.cwd is set
		if type(it.file) ~= "string" or it.file:sub(1, 1) == "/" or not it.cwd then
			all_relative_file = false
		end
		local joined = it.cwd .. "/" .. it.file
		if vim.fn.filereadable(joined) ~= 1 then
			all_relative_file = false
		end
	end
	check(
		"open_modified_files_picker items only pass valid 2-char git porcelain xy or nil in item.status (no 'unknown status: NEW')",
		all_valid_status == true
	)
	check(
		"open_modified_files_picker sets relative item.file with item.cwd so Snacks.picker.util.path resolves without double-prefixing",
		all_relative_file == true
	)
end

local lock_json = table.concat(vim.fn.readfile("modules/tools/nvim/config/lazy-lock.json"), "\n")
local lock_ok, lock_data = pcall(vim.json.decode, lock_json)
check(
	"lazy-lock.json pins mini.surround, yanky.nvim, dial.nvim, inc-rename.nvim, oil.nvim, treesj, and quicker.nvim",
	lock_ok
		and type(lock_data) == "table"
		and lock_data["mini.surround"] ~= nil
		and lock_data["yanky.nvim"] ~= nil
		and lock_data["dial.nvim"] ~= nil
		and lock_data["inc-rename.nvim"] ~= nil
		and lock_data["oil.nvim"] ~= nil
		and lock_data["treesj"] ~= nil
		and lock_data["quicker.nvim"] ~= nil
)

assert(#failures == 0, table.concat(failures, "; "))
