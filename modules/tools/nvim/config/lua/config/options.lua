-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua

vim.o.shell = "fish"
vim.o.shellcmdflag = "-c"
vim.o.termguicolors = true
vim.o.winborder = "rounded"
vim.o.scrolloff = 8
vim.o.updatetime = 100
vim.o.swapfile = false

-- Prepend Mason bin to PATH so linters/formatters resolve cleanly
vim.env.PATH = vim.fn.stdpath("data") .. "/mason/bin:" .. vim.env.PATH
