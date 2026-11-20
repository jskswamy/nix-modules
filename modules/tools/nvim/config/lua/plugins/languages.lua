return {
	-- Language servers not already covered by LazyVim extras
	{
		"neovim/nvim-lspconfig",
		opts = {
			servers = {
				nil_ls = {
					settings = {
						["nil"] = {
							formatting = { command = { "alejandra" } },
						},
					},
				},
				pkl_lsp = {},
				bashls = {},
				dockerls = {},
				html = {},
				cssls = {},
			},
		},
	},

	-- Extra treesitter parsers beyond LazyVim language extras
	{
		"nvim-treesitter/nvim-treesitter",
		opts = {
			ensure_installed = {
				"bash",
				"css",
				"dockerfile",
				"html",
				"latex",
				"pkl",
				"typst",
			},
		},
	},

	-- Mason tool installer for language servers, formatters, and linters
	{
		"mason-org/mason.nvim",
		opts = function(_, opts)
			opts.PATH = "append" -- Prefer Nix tools while keeping LazyVim's installer.
			opts.install_root_dir = vim.fn.stdpath("data") .. "/mason"
			-- Inherited extras repeat tools; Mason rejects concurrent duplicate installs.
			opts.ensure_installed = vim.list.unique(vim.list_extend(opts.ensure_installed or {}, {
				"typescript-language-server",
				"pyright",
				"gopls",
				"terraform-ls",
				"bash-language-server",
				"yaml-language-server",
				"dockerfile-language-server",
				"html-lsp",
				"css-lsp",
				"marksman",
				"json-lsp",
				"biome",
				"ruff",
				"gofumpt",
				"goimports",
				"shfmt",
				"stylua",
				"prettier",
				"eslint_d",
				"golangci-lint",
				"tflint",
				"shellcheck",
				"markdownlint-cli2",
				"yamllint",
				"stylelint",
				"htmlhint",
				"ast-grep",
			}))
		end,
	},

	-- Formatting overrides (LazyVim extras already configure python, go, terraform, lua, markdown, yaml)
	{
		"stevearc/conform.nvim",
		opts = {
			formatters_by_ft = {
				javascript = { "biome", "prettier", stop_after_first = true },
				typescript = { "biome", "prettier", stop_after_first = true },
				javascriptreact = { "biome", "prettier", stop_after_first = true },
				typescriptreact = { "biome", "prettier", stop_after_first = true },
				json = { "biome", "prettier", stop_after_first = true },
				html = { "prettier" },
				css = { "prettier" },
				nix = { "alejandra" },
				pkl = { "pkl_format" },
				sh = { "shfmt" },
				bash = { "shfmt" },
			},
			formatters = {
				nixpkgs_fmt = {},
				biome = {
					condition = function(_, ctx)
						return vim.fs.find(
							{ "biome.json", "biome.jsonc" },
							{ path = vim.fs.dirname(ctx.filename), upward = true }
						)[1]
					end,
				},
				pkl_format = {
					command = "pkl",
					args = { "format", "$FILENAME" },
					stdin = false,
				},
			},
		},
	},

	-- Linting overrides
	{
		"mfussenegger/nvim-lint",
		opts = {
			linters_by_ft = {
				javascript = { "eslint_d" },
				typescript = { "eslint_d" },
				javascriptreact = { "eslint_d" },
				typescriptreact = { "eslint_d" },
				python = { "ruff" },
				go = { "golangcilint" },
				terraform = { "tflint" },
				sh = { "shellcheck" },
				bash = { "shellcheck" },
				markdown = { "markdownlint-cli2" },
				yaml = { "yamllint" },
				css = { "stylelint" },
				html = { "htmlhint" },
				nix = { "statix" },
			},
		},
	},

	{
		"LnL7/vim-nix",
		ft = "nix",
	},
}
