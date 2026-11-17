-- Run from the repository root: nvim --headless -u NONE -i NONE -l tests/nvim-config.lua
local specs = dofile("modules/tools/nvim/config/lua/plugins/languages.lua")
local mason, biome
for _, spec in ipairs(specs) do
	if spec[1] == "mason-org/mason.nvim" then
		mason = spec
	elseif spec.opts and spec.opts.formatters and spec.opts.formatters.biome then
		biome = spec.opts.formatters.biome.condition
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
		"Active review registers <leader>gf and <leader>gq dynamically",
		vim.fn.maparg("<leader>gf", "n") ~= "" and vim.fn.maparg("<leader>gq", "n") ~= ""
	)

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

assert(#failures == 0, table.concat(failures, "; "))
