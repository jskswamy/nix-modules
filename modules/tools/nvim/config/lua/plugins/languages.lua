return {
	-- Additional language server configurations
	{
		"neovim/nvim-lspconfig",
		opts = {
			servers = {
				-- Nix language server configuration
				nil_ls = {
					settings = {
						["nil"] = {
							formatting = {
								command = { "alejandra" }, -- Supplied by the Nix module
							},
						},
					},
				},
				-- Go language server with CodeLens enabled
				gopls = {
					settings = {
						gopls = {
							codelenses = {
								gc_details = true, -- Show GC optimization details
								generate = true, -- Show "Generate" CodeLens for interfaces
								regenerate_cgo = true, -- Regenerate cgo
								run_govulncheck = true, -- Run vulnerability check
								test = true, -- Show "Run test" / "Debug test" CodeLens
								tidy = true, -- Show "Tidy" CodeLens for go.mod
								upgrade_dependency = true, -- Show "Upgrade" CodeLens
								vendor = true, -- Show "Vendor" CodeLens
							},
							hints = {
								assignVariableTypes = true,
								compositeLiteralFields = true,
								compositeLiteralTypes = true,
								constantValues = true,
								functionTypeParameters = true,
								parameterNames = true,
								rangeVariableTypes = true,
							},
							analyses = {
								unusedparams = true,
								shadow = true,
							},
							staticcheck = true,
						},
					},
				},
				pkl_lsp = {},
				-- Additional language servers (Nix is handled by LazyVim extra)
				bashls = {}, -- Bash/shell scripting
				dockerls = {}, -- Docker
				html = {}, -- HTML
				cssls = {}, -- CSS
				sqls = {}, -- SQL language server
			},
		},
	},

	-- Enhanced treesitter support
	{
		"nvim-treesitter/nvim-treesitter",
		opts = {
			ensure_installed = {
				"bash",
				"css",
				"dockerfile",
				"go",
				"gomod",
				"gosum",
				"html",
				"javascript",
				"json",
				"latex",
				"lua",
				"markdown",
				"markdown_inline",
				"nix",
				"pkl",
				"python",
				"terraform",
				"typescript",
				"tsx",
				"vim",
				"yaml",
			},
		},
	},

	-- Mason tool installer for language servers and formatters
	{
		"mason-org/mason.nvim",
		opts = function(_, opts)
			opts.PATH = "append" -- Prefer Nix tools while keeping LazyVim's installer.
			opts.install_root_dir = vim.fn.stdpath("data") .. "/mason"
			-- Inherited extras repeat tools; Mason rejects concurrent duplicate installs.
			opts.ensure_installed = vim.list.unique(vim.list_extend(opts.ensure_installed or {}, {
				-- Language servers
				"typescript-language-server",
				"pyright",
				"gopls",
				"terraform-ls",
				"bash-language-server",
				"yaml-language-server",
				"dockerfile-language-server",
				"html-lsp",
				"css-lsp",
				"marksman", -- Markdown LSP
				"json-lsp",

				-- Best formatters for each language
				"biome", -- Modern JS/TS/JSON formatter (faster than prettier)
				"ruff", -- Python formatter + linter (replaces black, isort, flake8)
				"gofumpt", -- Go formatter (stricter than gofmt)
				"goimports", -- Go imports organizer
				"shfmt", -- Shell script formatter
				"stylua", -- Lua formatter
				"prettier", -- Fallback for YAML/Markdown

				-- Best linters for each language
				"eslint_d", -- JS/TS linter (fast daemon version)
				"golangci-lint", -- Go meta-linter (includes many linters)
				"tflint", -- Terraform linter
				"shellcheck", -- Shell script linter
				"markdownlint-cli2", -- Modern Markdown linter
				"yamllint", -- YAML linter
				"stylelint", -- CSS linter
				"htmlhint", -- HTML linter

				-- Additional tools
				"ast-grep", -- Structural search and replace (for grug-far)

				-- Nix supplies nil, alejandra, statix and deadnix; no Cargo build needed.
			}))
		end,
	},

	-- Configure auto-formatting on save with best tools
	{
		"stevearc/conform.nvim",
		opts = {
			formatters_by_ft = {
				-- JavaScript/TypeScript - use Biome (faster, modern alternative to Prettier)
				javascript = { "biome" },
				typescript = { "biome" },
				javascriptreact = { "biome" },
				typescriptreact = { "biome" },
				json = { "biome" },

				-- Python - use Ruff (does both formatting and import sorting)
				python = { "ruff_format", "ruff_organize_imports" },

				-- Go - use goimports + gofumpt for best formatting
				go = { "goimports", "gofumpt" },

				-- Web technologies
				html = { "prettier" },
				css = { "prettier" },

				-- Documentation - use prettier for consistency
				markdown = { "prettier" },
				yaml = { "prettier" },

				-- System languages
				nix = { "alejandra" },
				pkl = { "pkl_format" },
				terraform = { "terraform_fmt" },
				sh = { "shfmt" },
				bash = { "shfmt" },

				-- Lua
				lua = { "stylua" },
			},
			-- LazyVim handles format_on_save automatically, so we don't set it here
		},
	},

	-- Configure linting with nvim-lint
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

	-- Enhanced Nix support with custom commands
	{
		"LnL7/vim-nix",
		ft = "nix",
		config = function()
			-- Add custom Nix commands
			vim.api.nvim_create_user_command("NixCleanDeadCode", function()
				vim.cmd("!deadnix --edit %")
				vim.cmd("checktime")
			end, { desc = "Remove dead Nix code with deadnix" })

			vim.api.nvim_create_user_command("NixCheckStatix", function()
				vim.cmd("!statix check %")
			end, { desc = "Check Nix file with statix" })
		end,
	},

	-- Additional Nix formatting options
	{
		"stevearc/conform.nvim",
		opts = {
			formatters = {
				-- nixpkgs-fmt doesn't support --indent flag, remove invalid args
				nixpkgs_fmt = {},
			},
		},
	},

	-- Biome configuration for modern JS/TS formatting
	{
		"stevearc/conform.nvim",
		opts = {
			formatters = {
				biome = {
					condition = function(_, ctx)
						return vim.fs.find(
							{ "biome.json", "biome.jsonc" },
							{ path = vim.fs.dirname(ctx.filename), upward = true }
						)[1]
					end,
				},
			},
		},
	},

	-- Pkl formatter configuration
	{
		"stevearc/conform.nvim",
		opts = {
			formatters = {
				pkl_format = {
					command = "pkl",
					args = { "format", "$FILENAME" },
					stdin = false,
				},
			},
		},
	},
}
