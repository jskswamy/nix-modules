return {
	-- Noice UI enhancements
	-- Configure to work better with terminals
	{
		"folke/noice.nvim",
		opts = {
			-- Disable cmdline popup in terminal buffers for better performance
			cmdline = {
				enabled = true,
				view = "cmdline", -- Use classic cmdline for better terminal compatibility
			},
			-- Reduce message handling in terminal mode
			messages = {
				enabled = true,
				view = "notify",
				view_error = "notify",
				view_warn = "notify",
			},
			-- Don't show search count in terminal
			lsp = {
				progress = {
					enabled = true,
					view = "mini", -- Use mini view for less intrusion
				},
			},
			-- Presets for better terminal experience
			presets = {
				bottom_search = true, -- Use classic bottom search
				command_palette = false, -- Disable command palette in terminal
				long_message_to_split = true, -- Long messages go to split
				inc_rename = false, -- Disable inc_rename in terminal
				lsp_doc_border = true, -- Add border to LSP docs
			},
			-- Reduce visual noise in terminal mode
			routes = {
				{
					-- Skip displaying certain messages in terminal buffers
					filter = {
						event = "msg_show",
						any = {
							{ find = "written" },
							{ find = "yanked" },
						},
					},
					view = "mini",
				},
			},
		},
	},
}
