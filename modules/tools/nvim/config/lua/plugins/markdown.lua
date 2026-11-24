-- Reader-first Markdown configuration:
-- 1. Replaces render-markdown.nvim with markview.nvim for rich tables, callouts,
--    code blocks, and LaTeX/Typst rendering.
-- 2. Applies distraction-free reader options (word wrap, breakindent, hidden
--    line numbers/signcolumn, visual-line j/k, quieted lint diagnostics).
--    Zen & Presentation modes live in lua/plugins/zen.lua.

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
				hybrid_modes = { "i" },
			},
			markdown = {
				code_blocks = {
					-- "block" pads every line to the longest one, which wraps into
					-- blank rows because these buffers set 'wrap' (autocmd above).
					style = "simple",
				},
			},
		},
		keys = {
			{ "<leader>um", "<cmd>Markview toggle<cr>", desc = "Toggle Markview" },
			{ "<leader>uM", "<cmd>Markview splitToggle<cr>", desc = "Toggle Markview Split" },
		},
	},
}
