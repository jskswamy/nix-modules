-- Runs only against isolated state created by nvim-smoke.sh.
local function run()
	local state = assert(os.getenv("NVIM_SMOKE_STATE"))
	require("lazy").load({ plugins = { "mason.nvim", "nvim-treesitter", "conform.nvim", "nvim-lint", "blink.cmp" } })
	for _, command in ipairs({
		"cc",
		"tree-sitter",
		"node",
		"npm",
		"python3",
		"go",
		"git",
		"curl",
		"tar",
		"gzip",
		"unzip",
		"rg",
		"fd",
		"nil",
		"alejandra",
		"statix",
		"deadnix",
		"pkl",
		"java",
	}) do
		assert(vim.fn.executable(command) == 1, "Missing executable inside Neovim: " .. command)
	end
	assert(vim.fn.executable(vim.o.shell) == 1, "Configured terminal shell is unavailable: " .. vim.o.shell)
	print("PASS runtime executables inside Neovim")

	local registry = require("mason-registry")
	local plugin = require("lazy.core.config").plugins["mason.nvim"]
	local opts = require("lazy.core.plugin").values(plugin, "opts", false)
	assert(debug.getinfo(plugin.config, "S").source:find("LazyVim", 1, true), "Mason installer is not inherited")
	local function missing_tools()
		local missing = {}
		for _, name in ipairs(opts.ensure_installed) do
			if not registry.has_package(name) or not registry.get_package(name):is_installed() then
				table.insert(missing, name)
			end
		end
		return missing
	end
	assert(
		vim.wait(600000, function()
			return #missing_tools() == 0
		end, 1000),
		"Mason tools missing: " .. table.concat(missing_tools(), ", ")
	)
	print("PASS Mason declared tools installed")

	local ts = require("nvim-treesitter")
	ts.install({ "lua", "python", "typescript", "bash", "go", "yaml", "toml", "markdown", "nix" }):wait(120000)
	for _, language in ipairs({ "lua", "python", "typescript", "bash", "go", "yaml", "toml", "markdown", "nix" }) do
		assert(vim.treesitter.language.add(language), "Cannot load parser: " .. language)
	end
	print("PASS representative Tree-sitter parsers load")

	local project = state .. "/fixture"
	vim.fn.mkdir(project, "p")
	vim.fn.writefile({ "{}" }, project .. "/biome.json")
	vim.fn.writefile({ "const x={a:1}" }, project .. "/example.ts")
	vim.cmd.edit(project .. "/example.ts")
	local conform = require("conform")
	local info = conform.get_formatter_info("biome", 0)
	assert(info.available, vim.inspect(info))
	conform.format({ async = false, lsp_format = "never", timeout_ms = 15000 })
	assert(vim.api.nvim_buf_get_lines(0, 0, 1, false)[1] ~= "const x={a:1}", "Biome did not format the fixture")
	vim.fn.delete(project .. "/biome.json")
	assert(not conform.get_formatter_info("biome", 0).available, "Biome enabled outside configured projects")
	print("PASS actual Biome formatting outside cwd and no-config rejection")

	vim.fn.writefile({ "#!/usr/bin/env bash", "echo $undefined" }, project .. "/example.sh")
	vim.cmd.edit(project .. "/example.sh")
	local bufnr = vim.api.nvim_get_current_buf()
	assert(
		vim.wait(60000, function()
			for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr })) do
				if client.name == "bashls" and client.initialized then
					return true
				end
			end
			return false
		end, 200),
		"Bash language server did not initialize"
	)
	print("PASS Bash LSP initialized")
	local lint = require("lint")
	lint.try_lint("shellcheck")
	assert(
		vim.wait(15000, function()
			return #vim.diagnostic.get(bufnr, { namespace = lint.get_namespace("shellcheck") }) > 0
		end, 100),
		"Shellcheck produced no diagnostics for the fixture"
	)
	print("PASS Shellcheck diagnostics")

	-- This forces the pinned completion plugin's native matcher to initialize.
	local fuzzy = require("blink.cmp.fuzzy")
	assert(
		vim.wait(30000, function()
			return fuzzy.implementation_type == "rust"
		end, 100),
		"Blink native matcher did not initialize"
	)
	assert(type(fuzzy.get_words({ "completion fixture" })) == "table", "Blink native word matching failed")
	print("PASS Blink native fuzzy matcher initialized")
	vim.fn.writefile(
		vim.split(vim.fn.execute("messages"), "\n"),
		state .. "/" .. os.getenv("NVIM_SMOKE_MODE") .. "-messages.txt"
	)
end

local ok, err = xpcall(run, debug.traceback)
if not ok then
	io.stderr:write(tostring(err) .. "\n")
	vim.cmd("cquit 1")
else
	vim.cmd("qa!")
end
