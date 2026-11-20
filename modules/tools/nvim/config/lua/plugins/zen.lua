-- Distraction-free Zen Reader (<leader>zz) and IntelliJ-style Presentation Mode (<leader>zp).
--
-- - <leader>z is a dedicated which-key group ("+zen"):
--   - Always shown: <leader>zz (Zen Reader Mode), <leader>zp (Presentation Mode).
--   - Shown only while Zen/Presentation is open (staying in which-key loop mode):
--     - Width: <leader>z. / <leader>z<Right> (widen +10),
--              <leader>z, / <leader>z<Left> (narrow -10),
--              <leader>zf (full 100% width)
--     - Font:  <leader>z+ / <leader>z= (increase font), <leader>z- (decrease font)
--     - Exit:  <leader>zq (quit Zen)
-- - Both modes use a borderless, wide reading canvas with the pure Merino
--   background (Normal:Normal) and soft shaded side margins (SnacksZenBackdrop)
--   that follow macOS Light/Dark appearance automatically.
-- - Zen Reader (<leader>zz) keeps your normal font size and defaults to 85% width
--   (at least 120 columns).
-- - Presentation Mode (<leader>zp) defaults to 92% width, zooms the active Rex
--   pane if it is in a split, and increases Rex's font size by 4 steps. On exit
--   (via <leader>zp, <leader>zz, <leader>zq, q, :q, or quitting Neovim), it
--   automatically resets the font size and restores the Rex pane zoom state.

local state = {
	presentation = false,
	did_zoom_pane = false,
	app_client_id = nil,
	saved_laststatus = nil,
	saved_showtabline = nil,
	custom_width = nil,
	full_width = false,
	pending_procs = {},
}

local PRESENTATION_FONT_STEPS = 4

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

local function in_rex()
	return (vim.env.REX_SESSION or "") ~= "" and (vim.env.REX_BLOCK or "") ~= "" and rex_bin() ~= nil
end

local function resolve_rex_app_client(bin, session_id)
	local ok, res = pcall(function()
		return vim.system({ bin, "client", "ls", "-s", session_id, "--json" }, { text = true }):wait(1500)
	end)
	if not ok or not res or res.code ~= 0 or not res.stdout then
		return nil
	end
	local decoded_ok, data = pcall(vim.json.decode, res.stdout)
	if not decoded_ok or type(data) ~= "table" or type(data.clients) ~= "table" then
		return nil
	end
	for _, c in ipairs(data.clients) do
		if c.info and c.info.kind == "app" and c.client_id then
			return c.client_id
		end
	end
	return nil
end

local function rex_pane_is_zoomed(bin, session_id, block_id)
	local ok, res = pcall(function()
		return vim.system({ bin, "session", "inspect", session_id, "--json" }, { text = true }):wait(1500)
	end)
	if not ok or not res or res.code ~= 0 or not res.stdout then
		return false
	end
	local decoded_ok, data = pcall(vim.json.decode, res.stdout)
	if not decoded_ok or type(data) ~= "table" or type(data.windows) ~= "table" then
		return false
	end
	for _, w in ipairs(data.windows) do
		if w.zoomed_block_id == block_id then
			return true
		end
	end
	return false
end

local function rex_client_do(bin, client_id, action)
	local cmd = { bin }
	if client_id then
		vim.list_extend(cmd, { "-C", client_id })
	end
	vim.list_extend(cmd, { "do", action })
	pcall(vim.system, cmd, { text = true })
end

local function adjust_rex_font(direction, steps)
	if not in_rex() then
		return
	end
	local bin = rex_bin()
	local session_id = vim.env.REX_SESSION
	local client_id = state.app_client_id or resolve_rex_app_client(bin, session_id)
	state.app_client_id = client_id
	local action = direction > 0 and "client.font.increase" or "client.font.decrease"
	for _ = 1, (steps or 1) do
		rex_client_do(bin, client_id, action)
	end
end

local function enter_presentation_rex()
	if not in_rex() then
		return
	end
	local bin = rex_bin()
	local session_id = vim.env.REX_SESSION
	local block_id = vim.env.REX_BLOCK
	state.app_client_id = resolve_rex_app_client(bin, session_id)
	if not rex_pane_is_zoomed(bin, session_id, block_id) then
		state.did_zoom_pane = true
		pcall(vim.system, { bin, "zoom", "-s", session_id, block_id, "--on" }, { text = true })
	else
		state.did_zoom_pane = false
	end
	adjust_rex_font(1, PRESENTATION_FONT_STEPS)
end

local function wait_pending_procs()
	for _, proc in ipairs(state.pending_procs) do
		pcall(function()
			proc:wait(1500)
		end)
	end
	state.pending_procs = {}
end

local function restore_presentation_rex(sync)
	if not state.presentation then
		if sync then
			wait_pending_procs()
		end
		return
	end
	state.presentation = false
	if not in_rex() then
		state.did_zoom_pane = false
		return
	end
	local bin = rex_bin()
	local session_id = vim.env.REX_SESSION
	local block_id = vim.env.REX_BLOCK
	local client_id = state.app_client_id or resolve_rex_app_client(bin, session_id)
	local reset_cmd = { bin }
	if client_id then
		vim.list_extend(reset_cmd, { "-C", client_id })
	end
	vim.list_extend(reset_cmd, { "do", "client.font.reset" })
	if sync then
		pcall(function()
			vim.system(reset_cmd, { text = true }):wait(1500)
		end)
	else
		local ok, proc = pcall(vim.system, reset_cmd, { text = true })
		if ok and proc then
			table.insert(state.pending_procs, proc)
		end
	end
	if state.did_zoom_pane then
		state.did_zoom_pane = false
		local unzoom_cmd = { bin, "zoom", "-s", session_id, block_id, "--off" }
		if sync then
			pcall(function()
				vim.system(unzoom_cmd, { text = true }):wait(1500)
			end)
		else
			local ok, proc = pcall(vim.system, unzoom_cmd, { text = true })
			if ok and proc then
				table.insert(state.pending_procs, proc)
			end
		end
	end
end

local function default_zen_width()
	local cols = vim.o.columns
	if state.full_width then
		return cols
	end
	if state.custom_width then
		return math.max(60, math.min(cols, state.custom_width))
	end
	if state.presentation then
		return math.min(cols, math.max(100, math.floor(cols * 0.92)))
	end
	return math.min(cols, math.max(120, math.floor(cols * 0.85)))
end

local function active_zen_win()
	if _G.Snacks and Snacks.zen and Snacks.zen.win and Snacks.zen.win.valid and Snacks.zen.win:valid() then
		return Snacks.zen.win
	end
	return nil
end

local function refresh_zen_width()
	local win = active_zen_win()
	if not win then
		return
	end
	win.opts.width = default_zen_width()
	pcall(function()
		win:update()
	end)
end

local function step_zen_width(delta)
	local win = active_zen_win()
	if not win then
		return
	end
	state.full_width = false
	local current = state.custom_width or default_zen_width()
	state.custom_width = math.max(60, math.min(vim.o.columns, current + delta))
	refresh_zen_width()
end

local function toggle_zen_full_width()
	local win = active_zen_win()
	if not win then
		return
	end
	state.full_width = not state.full_width
	refresh_zen_width()
end

local function close_active_zen()
	if active_zen_win() then
		Snacks.zen.zen()
	end
end

local function keep_zen_menu()
	local ok, wk = pcall(require, "which-key")
	if ok and wk and type(wk.show) == "function" then
		pcall(wk.show, { keys = "<leader>z", loop = true })
	end
end

local active_zen_keymaps = {
	{
		"<leader>z.",
		function()
			step_zen_width(10)
			keep_zen_menu()
		end,
		"Zen: Widen Column (+10)",
	},
	{
		"<leader>z<Right>",
		function()
			step_zen_width(10)
			keep_zen_menu()
		end,
		"Zen: Widen Column (+10)",
	},
	{
		"<leader>z,",
		function()
			step_zen_width(-10)
			keep_zen_menu()
		end,
		"Zen: Narrow Column (-10)",
	},
	{
		"<leader>z<Left>",
		function()
			step_zen_width(-10)
			keep_zen_menu()
		end,
		"Zen: Narrow Column (-10)",
	},
	{
		"<leader>zf",
		function()
			toggle_zen_full_width()
			keep_zen_menu()
		end,
		"Zen: Toggle Full Width (100%)",
	},
	{
		"<leader>z+",
		function()
			adjust_rex_font(1, 1)
			keep_zen_menu()
		end,
		"Zen: Increase Font Size",
	},
	{
		"<leader>z=",
		function()
			adjust_rex_font(1, 1)
			keep_zen_menu()
		end,
		"Zen: Increase Font Size",
	},
	{
		"<leader>z-",
		function()
			adjust_rex_font(-1, 1)
			keep_zen_menu()
		end,
		"Zen: Decrease Font Size",
	},
	{ "<leader>zq", close_active_zen, "Zen: Exit" },
}

local function register_active_zen_keymaps()
	for _, km in ipairs(active_zen_keymaps) do
		vim.keymap.set("n", km[1], km[2], { silent = true, desc = km[3] })
	end
end

local function unregister_active_zen_keymaps()
	for _, km in ipairs(active_zen_keymaps) do
		pcall(vim.keymap.del, "n", km[1])
	end
end

local function toggle_zen_reader()
	local win = active_zen_win()
	if win then
		if state.presentation then
			-- Switching from Presentation Mode to Zen Reader restores Rex font/zoom
			-- and narrows to reader width without closing Zen.
			restore_presentation_rex(false)
			state.custom_width = nil
			state.full_width = false
			refresh_zen_width()
			return
		end
		Snacks.zen.zen()
		return
	end
	state.presentation = false
	state.custom_width = nil
	state.full_width = false
	Snacks.zen.zen()
end

local function toggle_presentation_mode()
	local win = active_zen_win()
	if win then
		if not state.presentation then
			-- Upgrade active Zen Reader window into Presentation Mode
			state.presentation = true
			state.custom_width = nil
			state.full_width = false
			enter_presentation_rex()
			refresh_zen_width()
			return
		end
		Snacks.zen.zen()
		return
	end
	state.presentation = true
	state.custom_width = nil
	state.full_width = false
	enter_presentation_rex()
	Snacks.zen.zen()
end

vim.api.nvim_create_autocmd("VimLeavePre", {
	callback = function()
		restore_presentation_rex(true)
	end,
})

return {
	{
		"folke/snacks.nvim",
		opts = {
			statuscolumn = { enabled = true },
			terminal = { shell = "fish" },
			zen = {
				toggles = {
					dim = false,
					git_signs = false,
					mini_diff_signs = false,
					diagnostics = false,
					inlay_hints = false,
				},
				show = {
					statusline = false,
					tabline = false,
				},
				win = {
					border = "none",
					width = default_zen_width,
					wo = {
						number = false,
						relativenumber = false,
						signcolumn = "no",
						foldcolumn = "0",
						winhighlight = "Normal:Normal,NormalNC:Normal,FloatBorder:SnacksZenBackdrop",
					},
					backdrop = {
						transparent = false,
						win = {
							wo = {
								winhighlight = "Normal:SnacksZenBackdrop,NormalFloat:SnacksZenBackdrop",
							},
						},
					},
				},
				on_open = function()
					if state.saved_laststatus == nil then
						state.saved_laststatus = vim.o.laststatus
					end
					if state.saved_showtabline == nil then
						state.saved_showtabline = vim.o.showtabline
					end
					vim.o.laststatus = 0
					vim.o.showtabline = 0
					register_active_zen_keymaps()
				end,
				on_close = function()
					unregister_active_zen_keymaps()
					if state.saved_laststatus ~= nil then
						vim.o.laststatus = state.saved_laststatus
						state.saved_laststatus = nil
					end
					if state.saved_showtabline ~= nil then
						vim.o.showtabline = state.saved_showtabline
						state.saved_showtabline = nil
					end
					state.custom_width = nil
					state.full_width = false
					restore_presentation_rex(false)
				end,
			},
		},
		keys = {
			-- Disable LazyVim's default <leader>z single-key mapping if any so <leader>z
			-- acts purely as the "+zen" prefix group without timeout delay.
			{ "<leader>z", false },
			{ "<leader>Z", false },
			{ "<leader>zz", toggle_zen_reader, desc = "Zen Reader Mode" },
			{ "<leader>zp", toggle_presentation_mode, desc = "Presentation Mode" },
		},
	},
	{
		"folke/which-key.nvim",
		optional = true,
		opts = {
			spec = {
				{ "<leader>z", group = "zen", icon = { icon = "🧘", color = "cyan" } },
			},
		},
	},
}
