return {
	-- Gruvbox — matches Ghostty/herdr/hunk theme across the stack
	{
		"ellisonleao/gruvbox.nvim",
		lazy = false,
		priority = 1000,
		opts = {
			contrast = "",
		},
		config = function(_, opts)
			require("gruvbox").setup(opts)
			-- Neovim auto-detects the terminal background via OSC 11 and
			-- flips vim.o.background, but gruvbox doesn't re-apply itself
			-- on that change, so do it manually.
			vim.api.nvim_create_autocmd("OptionSet", {
				pattern = "background",
				callback = function()
					vim.cmd.colorscheme("gruvbox")
				end,
			})
			vim.cmd.colorscheme("gruvbox")
		end,
	},

	-- Tell LazyVim to use gruvbox as the colorscheme
	{
		"LazyVim/LazyVim",
		opts = {
			colorscheme = "gruvbox",
		},
	},

	-- Skip installing LazyVim's default colorschemes — gruvbox is the
	-- only one actually used.
	{ "folke/tokyonight.nvim", enabled = false },
	{ "catppuccin/nvim", enabled = false },
}
