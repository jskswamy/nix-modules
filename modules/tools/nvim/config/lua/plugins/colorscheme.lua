-- Match Rex's Merino theme (GitHub Primer Default with softer yellows from
-- modules/theme/merino.nix) in truecolor, switching live with macOS appearance.

local function current_scheme()
	return vim.o.background == "light" and "github_light_default" or "github_dark_default"
end

local function apply_scheme(bg)
	if vim.o.background ~= bg then
		vim.o.background = bg
	end
	local target = current_scheme()
	if vim.g.colors_name ~= target then
		pcall(vim.cmd.colorscheme, target)
	end
end

if vim.fn.has("mac") == 1 then
	local busy = false
	local function sync()
		if busy then
			return
		end
		busy = true
		vim.system({ "defaults", "read", "-g", "AppleInterfaceStyle" }, { text = true }, function(r)
			busy = false
			-- Light mode removes the key ("does not exist"); any other
			-- failure leaves 'background' alone rather than guessing.
			local bg = r.code == 0 and (r.stdout or ""):match("Dark") and "dark"
				or (r.stderr or ""):match("does not exist") and "light"
			if not bg then
				return
			end
			vim.schedule(function()
				apply_scheme(bg)
			end)
		end)
	end
	vim.api.nvim_create_autocmd({ "VimEnter", "FocusGained" }, { callback = sync })
	local timer = (vim.uv or vim.loop).new_timer()
	if timer then
		timer:start(3000, 3000, vim.schedule_wrap(sync))
	end
	sync()
end

local float_links = {
	SnacksPicker = { link = "NormalFloat" },
	SnacksPickerNormal = { link = "NormalFloat" },
	SnacksPickerBorder = { link = "FloatBorder" },
	SnacksPickerTitle = { link = "FloatTitle" },
	SnacksInputNormal = { link = "NormalFloat" },
	SnacksInputBorder = { link = "FloatBorder" },
	SnacksInputTitle = { link = "FloatTitle" },
	BlinkCmpMenu = { link = "NormalFloat" },
	BlinkCmpMenuBorder = { link = "FloatBorder" },
	BlinkCmpDoc = { link = "NormalFloat" },
	BlinkCmpDocBorder = { link = "FloatBorder" },
	WhichKeyNormal = { link = "NormalFloat" },
	WhichKeyBorder = { link = "FloatBorder" },
}

return {
	{
		"projekt0n/github-nvim-theme",
		lazy = false,
		priority = 1000,
		config = function()
			require("github-theme").setup({
				options = {
					styles = {
						comments = "italic",
					},
				},
				palettes = {
					-- Merino dark/light yellow overrides (modules/theme/merino.nix)
					github_dark_default = {
						bg0 = "#0d1117",
						fg0 = "#e6edf3",
						yellow = { base = "#d29922", bright = "#e3b341" },
					},
					github_light_default = {
						bg0 = "#ffffff",
						fg0 = "#1f2328",
						yellow = { base = "#9d5c00", bright = "#c47a00" },
					},
				},
				groups = {
					-- Distinct elevated surface + visible border for floating/popup windows,
					-- plus soft shaded backdrop margins for Zen / Presentation mode.
					github_dark_default = vim.tbl_extend("force", float_links, {
						NormalFloat = { bg = "#161b22", fg = "#e6edf3" },
						FloatBorder = { bg = "#161b22", fg = "#388bfd" },
						FloatTitle = { bg = "#161b22", fg = "#58a6ff", style = "bold" },
						Pmenu = { bg = "#161b22", fg = "#e6edf3" },
						PmenuSel = { bg = "#1f2937", style = "bold" },
						SnacksZenBackdrop = { bg = "#161b22" },
						GitSignsAddLn = { bg = "#12261e" },
						GitSignsAddInline = { bg = "#1f4429", fg = "#56d364", style = "bold" },
						GitSignsChangeLn = { bg = "#272115" },
						GitSignsChangeInline = { bg = "#4b3912", fg = "#e3b341", style = "bold" },
						GitSignsDeleteVirtLn = { bg = "#2d1619", fg = "#ffa198" },
						GitSignsDeleteInline = { bg = "#541b21", fg = "#ffa198", style = "strikethrough" },
					}),
					github_light_default = vim.tbl_extend("force", float_links, {
						NormalFloat = { bg = "#f6f8fa", fg = "#1f2328" },
						FloatBorder = { bg = "#f6f8fa", fg = "#0969da" },
						FloatTitle = { bg = "#f6f8fa", fg = "#0969da", style = "bold" },
						Pmenu = { bg = "#f6f8fa", fg = "#1f2328" },
						PmenuSel = { bg = "#dbeafe", style = "bold" },
						SnacksZenBackdrop = { bg = "#f6f8fa" },
						GitSignsAddLn = { bg = "#e6ffec" },
						GitSignsAddInline = { bg = "#aceebb", fg = "#116329", style = "bold" },
						GitSignsChangeLn = { bg = "#fff8c5" },
						GitSignsChangeInline = { bg = "#fae17d", fg = "#7d4e00", style = "bold" },
						GitSignsDeleteVirtLn = { bg = "#ffebe9", fg = "#cf222e" },
						GitSignsDeleteInline = { bg = "#ffcecb", fg = "#a40e26", style = "strikethrough" },
					}),
				},
			})
			apply_scheme(vim.o.background)
		end,
	},

	{
		"LazyVim/LazyVim",
		opts = {
			colorscheme = current_scheme,
		},
	},

	-- Skip installing LazyVim's bundled colorschemes; none are used.
	{ "folke/tokyonight.nvim", enabled = false },
	{ "catppuccin/nvim", enabled = false },
}
