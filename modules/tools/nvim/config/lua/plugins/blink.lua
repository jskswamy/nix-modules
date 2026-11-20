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
				documentation = {
					auto_show = true,
					auto_show_delay_ms = 150,
					window = { border = "rounded" },
				},
			},
			signature = {
				enabled = true,
				window = { border = "rounded" },
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
