-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local map = vim.keymap.set

-- ========================================
-- TERMINAL MODE KEYBINDINGS
-- ========================================

-- Quick escape from terminal mode (double ESC)
map("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

-- Window navigation from terminal mode (seamless switching)
map("t", "<C-h>", "<C-\\><C-n><C-w>h", { desc = "Go to left window" })
map("t", "<C-j>", "<C-\\><C-n><C-w>j", { desc = "Go to lower window" })
map("t", "<C-k>", "<C-\\><C-n><C-w>k", { desc = "Go to upper window" })
map("t", "<C-l>", "<C-\\><C-n><C-w>l", { desc = "Go to right window" })

-- Zoom window from terminal mode (maximize current window)
map("t", "<leader>uZ", function()
	vim.cmd("stopinsert")
	require("snacks").toggle.zoom()
end, { desc = "Zoom window" })

-- Quick quit from terminal
map("t", "<C-q>", "<C-\\><C-n>:q<cr>", { desc = "Quit window" })

-- ========================================
-- NUMBERED TERMINAL QUICK ACCESS
-- LazyVim default: <C-/> or <C-_> (supports count: 2<C-/>, 3<C-/>, etc.)
-- ========================================

-- Quick access to specific numbered terminals
map({ "n", "t" }, "<leader>t1", function()
	vim.api.nvim_feedkeys("1", "n", false)
	vim.cmd("normal \x0f") -- Ctrl+/
end, { desc = "Terminal #1" })

map({ "n", "t" }, "<leader>t2", function()
	vim.api.nvim_feedkeys("2", "n", false)
	vim.cmd("normal \x0f") -- Ctrl+/
end, { desc = "Terminal #2" })

map({ "n", "t" }, "<leader>t3", function()
	vim.api.nvim_feedkeys("3", "n", false)
	vim.cmd("normal \x0f") -- Ctrl+/
end, { desc = "Terminal #3" })

-- ========================================
-- SPECIALIZED TERMINALS
-- ========================================

-- Terminal in current file's directory
map({ "n", "t" }, "<leader>t.", function()
	require("snacks").terminal(nil, { cwd = vim.fn.expand("%:p:h") })
end, { desc = "Terminal (current file dir)" })

-- Terminal in project root
map({ "n", "t" }, "<leader>tr", function()
	require("snacks").terminal(nil, { cwd = vim.fn.getcwd() })
end, { desc = "Terminal (project root)" })

-- List all open terminals
map("n", "<leader>tl", function()
	local terminals = require("snacks.terminal").list()
	if #terminals == 0 then
		vim.notify("No terminals open", vim.log.levels.INFO)
	else
		print("Open terminals:")
		for i, term in ipairs(terminals) do
			print(string.format("  %d: %s", i, term.cmd or "shell"))
		end
	end
end, { desc = "List terminals" })
