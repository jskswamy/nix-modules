-- Run from the repository root: nvim --headless -u NONE -i NONE -l tests/nvim-config.lua
local specs = dofile("modules/tools/nvim/config/lua/plugins/languages.lua")
local mason, biome
for _, spec in ipairs(specs) do
	if spec[1] == "mason-org/mason.nvim" then
		mason = spec
	elseif spec.opts and spec.opts.formatters and spec.opts.formatters.biome then
		biome = spec.opts.formatters.biome.condition
	end
end

local failures = {}
local function check(name, condition)
	print((condition and "PASS " or "FAIL ") .. name)
	if not condition then
		table.insert(failures, name)
	end
end

-- Lazy merges this spec over LazyVim's. A custom config replaces its installer.
local inherited = function() end
local inherited_opts = { ensure_installed = { "stylua", "shfmt", "goimports", "gofumpt" } }
local merged = vim.tbl_deep_extend("force", { config = inherited }, mason)
if type(mason.opts) == "function" then
	mason.opts({}, inherited_opts)
	merged.opts = inherited_opts
else
	merged.opts = vim.tbl_deep_extend("force", {}, inherited_opts, mason.opts)
	-- LazyVim opts_extend appends these lists rather than replacing them.
	merged.opts.ensure_installed = vim.list_extend(inherited_opts.ensure_installed, mason.opts.ensure_installed)
end
check(
	"Mason tools are unique after inherited options merge",
	#vim.list.unique(vim.deepcopy(merged.opts.ensure_installed)) == #merged.opts.ensure_installed
)
check("Mason retains LazyVim's installer", merged.config == inherited)
check("Mason appends its tools to PATH", merged.opts.PATH == "append")
check(
	"Mason retains its writable install directory",
	merged.opts.install_root_dir == vim.fn.stdpath("data") .. "/mason"
)
check(
	"Mason retains declared tools",
	vim.tbl_contains(merged.opts.ensure_installed, "stylua")
		and vim.tbl_contains(merged.opts.ensure_installed, "prettier")
)

check(
	"Alejandra uses the Nix package instead of requiring Cargo",
	not vim.tbl_contains(merged.opts.ensure_installed, "alejandra")
)

local root = vim.fn.tempname()
local cwd = vim.fn.getcwd()
vim.fn.mkdir(root .. "/outside", "p")
vim.fn.mkdir(root .. "/project/src", "p")
vim.fn.chdir(root .. "/outside")
local filename = root .. "/project/src/example.ts"
vim.fn.writefile({ "const x = 1;" }, filename)
for _, config in ipairs({ "biome.json", "biome.jsonc" }) do
	vim.fn.writefile({ "{}" }, root .. "/project/" .. config)
	-- Conform calls condition(formatter_config, context), not condition(context).
	check("Biome finds " .. config .. " outside cwd", biome({}, { filename = filename }) ~= nil)
	vim.fn.delete(root .. "/project/" .. config)
end
check("Biome stays disabled without project config", not biome({}, { filename = filename }))
vim.fn.chdir(cwd)
vim.fn.delete(root, "rf")
assert(#failures == 0, table.concat(failures, "; "))
