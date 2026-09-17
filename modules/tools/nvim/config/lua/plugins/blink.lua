return {
	-- Configure blink.cmp for IntelliJ-style Tab completion
	{
		"saghen/blink.cmp",
		opts = function(_, opts)
			-- Ensure we override LazyVim's keymap preset
			opts.keymap = opts.keymap or {}
			opts.keymap.preset = "default"

			-- Override/add our custom keymaps
			local custom_keymaps = {
				-- IntelliJ-style Tab to accept completion
				["<Tab>"] = { "accept", "fallback" },

				-- Arrow keys for navigation
				["<Up>"] = { "select_prev", "fallback" },
				["<Down>"] = { "select_next", "fallback" },

				-- Additional navigation
				["<C-p>"] = { "select_prev", "fallback" },
				["<C-n>"] = { "select_next", "fallback" },

				-- Manual completion trigger
				["<C-Space>"] = { "show", "show_documentation", "hide_documentation" },

				-- Documentation scrolling
				["<C-b>"] = { "scroll_documentation_up", "fallback" },
				["<C-f>"] = { "scroll_documentation_down", "fallback" },

				-- Hide completion
				["<C-e>"] = { "hide", "fallback" },

				-- Enter only confirms if explicitly selected
				["<CR>"] = { "accept", "fallback" },
			}

			-- Merge custom keymaps, ensuring they take precedence
			for key, value in pairs(custom_keymaps) do
				opts.keymap[key] = value
			end

			-- Ensure completion settings
			opts.completion = opts.completion or {}
			opts.completion.accept = opts.completion.accept or {}
			opts.completion.accept.auto_brackets = { enabled = true }

			opts.completion.menu = opts.completion.menu or {}
			opts.completion.menu.auto_show = true
			opts.completion.menu.draw = {
				columns = { { "label", "label_description", gap = 1 }, { "kind_icon", "kind" } },
			}

			opts.completion.documentation = opts.completion.documentation or {}
			opts.completion.documentation.auto_show = true
			opts.completion.documentation.auto_show_delay_ms = 200

			opts.completion.trigger = opts.completion.trigger or {}
			opts.completion.trigger.show_on_insert_on_trigger_character = true

			-- Fix cmdline completion to use arrow keys
			opts.cmdline = opts.cmdline or {}
			opts.cmdline.keymap = {
				preset = "default", -- Use default instead of cmdline to get arrow keys
				["<Up>"] = { "select_prev", "fallback" },
				["<Down>"] = { "select_next", "fallback" },
				["<Tab>"] = { "accept", "fallback" },
				["<CR>"] = { "accept", "fallback" },
			}

			return opts
		end,
	},
}
