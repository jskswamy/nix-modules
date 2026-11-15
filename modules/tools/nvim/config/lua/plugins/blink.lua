return {
	{
		"saghen/blink.cmp",
		opts = {
			keymap = {
				preset = "default",
				["<Tab>"] = { "accept", "fallback" },
				["<CR>"] = { "accept", "fallback" },
				["<Up>"] = { "select_prev", "fallback" },
				["<Down>"] = { "select_next", "fallback" },
			},
			completion = {
				menu = { border = "rounded" },
				documentation = { window = { border = "rounded" } },
			},
			cmdline = {
				keymap = {
					preset = "default",
					["<Tab>"] = { "accept", "fallback" },
					["<CR>"] = { "accept", "fallback" },
					["<Up>"] = { "select_prev", "fallback" },
					["<Down>"] = { "select_next", "fallback" },
				},
			},
		},
	},
}
