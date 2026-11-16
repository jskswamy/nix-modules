-- Reader-first Markdown configuration:
-- 1. Replaces render-markdown.nvim with markview.nvim for rich tables, callouts,
--    code blocks, and LaTeX/Typst rendering.
-- 2. Applies distraction-free reader options (word wrap, breakindent, hidden
--    line numbers/signcolumn, visual-line j/k, quieted lint diagnostics).
-- 3. Configures snacks.zen (and snacks.image) for a centered reading column
--    that keeps Rex's background color.

vim.api.nvim_create_autocmd("FileType", {
	pattern = { "markdown", "markdown.mdx", "quarto", "rmd" },
	callback = function(ev)
		vim.opt_local.wrap = true
		vim.opt_local.linebreak = true
		vim.opt_local.breakindent = true
		vim.opt_local.number = false
		vim.opt_local.relativenumber = false
		vim.opt_local.signcolumn = "no"
		vim.opt_local.cursorline = false
		vim.opt_local.conceallevel = 2
		vim.opt_local.concealcursor = "nc"
		vim.opt_local.spell = false

		-- Quiet markdownlint squiggles while reading; toggle back with <leader>ud
		vim.diagnostic.enable(false, { bufnr = ev.buf })

		-- Move by visual wrapped lines when no count is given
		local opts = { buffer = ev.buf, silent = true, expr = true }
		vim.keymap.set({ "n", "x" }, "j", "v:count == 0 ? 'gj' : 'j'", opts)
		vim.keymap.set({ "n", "x" }, "k", "v:count == 0 ? 'gk' : 'k'", opts)
	end,
})

return {
	-- Disable LazyVim's default markdown renderer so markview owns rendering
	{ "MeanderingProgrammer/render-markdown.nvim", enabled = false },

	{
		"OXY2DEV/markview.nvim",
		lazy = false,
		dependencies = {
			"nvim-treesitter/nvim-treesitter",
			"nvim-mini/mini.icons",
		},
		opts = {
			preview = {
				icon_provider = "mini",
				filetypes = { "markdown", "quarto", "rmd", "typst" },
				modes = { "n", "no", "c" },
				hybrid_modes = {},
			},
			markdown = {
				code_blocks = {
					style = "block",
					min_width = 70,
					pad_amount = 2,
				},
			},
		},
		keys = {
			{ "<leader>um", "<cmd>Markview toggle<cr>", desc = "Toggle Markview" },
			{ "<leader>uM", "<cmd>Markview splitToggle<cr>", desc = "Toggle Markview Split" },
		},
	},

	{
		"folke/snacks.nvim",
		opts = {
			statuscolumn = { enabled = true },
			zen = {
				toggles = {
					dim = false,
					git_signs = false,
					mini_diff_signs = false,
					diagnostics = false,
				},
				win = {
					width = 100,
					backdrop = { transparent = true, blend = 0 },
				},
			},
		},
	},
}
