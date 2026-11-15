return {
	-- Hide top bufferline tab bar for a cleaner reader view; use <leader>, or <leader><space>
	{ "akinsho/bufferline.nvim", enabled = false },

	{
		"folke/noice.nvim",
		opts = {
			cmdline = { view = "cmdline" },
			lsp = { progress = { view = "mini" } },
			presets = {
				bottom_search = true,
				command_palette = false,
				long_message_to_split = true,
				lsp_doc_border = true,
			},
			routes = {
				{
					filter = {
						event = "msg_show",
						any = { { find = "written" }, { find = "yanked" } },
					},
					view = "mini",
				},
			},
		},
	},
}
