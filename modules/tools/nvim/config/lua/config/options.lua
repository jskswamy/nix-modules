-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua

vim.o.termguicolors = true
vim.o.winborder = "rounded"
vim.o.scrolloff = 8
vim.o.updatetime = 100
vim.o.swapfile = false

-- Append Mason bin to PATH so Nix tools take precedence while Mason tools resolve cleanly
vim.env.PATH = vim.env.PATH .. ":" .. vim.fn.stdpath("data") .. "/mason/bin"
