-- Follow the terminal's theme: with termguicolors off (config/options.lua),
-- Nvim's built-in "default" scheme draws only with ANSI colors 0-15 and the
-- terminal background, so Rex's (or any terminal's) palette shows through.
-- 'background' picks its light or dark variant.

-- Rex answers neither OSC 11 nor feeds its mode-2031 theme reports to Nvim, so
-- Nvim's own background detection never fires there. Rex picks its light/dark
-- theme from the macOS appearance, so follow that.
-- shortcut: re-checked on start and focus only, not mid-focus; add a timer if
-- appearance changes while Nvim is focused matter.
if vim.fn.has("mac") == 1 then
	local function sync()
		vim.system({ "defaults", "read", "-g", "AppleInterfaceStyle" }, { text = true }, function(r)
			-- Light mode removes the key ("does not exist"); any other
			-- failure leaves 'background' alone rather than guessing.
			local bg = r.code == 0 and (r.stdout or ""):match("Dark") and "dark"
				or (r.stderr or ""):match("does not exist") and "light"
			if not bg then
				return
			end
			vim.schedule(function()
				if vim.o.background ~= bg then
					vim.o.background = bg
				end
			end)
		end)
	end
	vim.api.nvim_create_autocmd({ "VimEnter", "FocusGained" }, { callback = sync })
	sync()
end

-- "default" leaves comments in the text color under ANSI-only colors; dim
-- them with bright black, which every terminal theme defines.
vim.api.nvim_create_autocmd("ColorScheme", {
	pattern = "default",
	callback = function()
		vim.api.nvim_set_hl(0, "Comment", { ctermfg = 8, italic = true })
	end,
})

return {
	{
		"LazyVim/LazyVim",
		opts = {
			colorscheme = "default",
		},
	},

	-- Skip installing LazyVim's bundled colorschemes; none are used.
	{ "folke/tokyonight.nvim", enabled = false },
	{ "catppuccin/nvim", enabled = false },
}
