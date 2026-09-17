-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Use fish shell for Neovim terminals
vim.o.shell = "fish"
vim.o.shellcmdflag = "-c"

-- Use 24-bit colors for proper colorscheme rendering
vim.o.termguicolors = true

-- Add Mason bin to PATH so linters/formatters can be found
local mason_bin = vim.fn.stdpath("data") .. "/mason/bin"
vim.env.PATH = mason_bin .. ":" .. vim.env.PATH

-- ========================================
-- TERMINAL PERFORMANCE OPTIMIZATIONS
-- ========================================

-- Limit terminal scrollback to prevent lag
vim.o.scrollback = 3000 -- Further reduced for faster typing

-- DO NOT enable lazyredraw - it conflicts with Noice plugin
-- vim.opt.lazyredraw = false  -- Explicitly disabled

-- Faster terminal rendering
vim.o.ttyfast = true

-- Reduce redrawtime for better responsiveness
vim.o.redrawtime = 1500

-- Faster updatetime for terminal responsiveness
vim.o.updatetime = 100 -- Reduced from default 4000ms

-- Disable swap for terminal buffers (faster)
vim.o.swapfile = false

-- Consolidated terminal-specific optimizations
vim.api.nvim_create_autocmd("TermOpen", {
	pattern = "*",
	callback = function()
		local buf = vim.api.nvim_get_current_buf()

		-- Disable file operations for performance
		vim.opt_local.undofile = false
		vim.opt_local.swapfile = false

		-- Disable visual elements for performance
		vim.opt_local.cursorline = false
		vim.opt_local.number = false
		vim.opt_local.relativenumber = false
		vim.opt_local.signcolumn = "no"
		vim.opt_local.foldcolumn = "0"

		-- Set proper scrollback for this terminal buffer
		vim.bo[buf].scrollback = 3000

		-- Fix background color to match editor
		vim.opt_local.winhighlight = "Normal:Normal,NormalFloat:NormalFloat,FloatBorder:FloatBorder"

		-- Enter insert mode automatically
		vim.cmd("startinsert")
	end,
})
