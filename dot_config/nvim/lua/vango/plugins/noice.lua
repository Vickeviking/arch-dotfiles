-- lua/plugins/noice.lua
return {
	"folke/noice.nvim",
	event = "VeryLazy",
	dependencies = {
		"MunifTanjim/nui.nvim",
		"rcarriga/nvim-notify",
	},
	opts = {
		cmdline = {
			enabled = true,
			view = "cmdline_popup", -- floating command line!
		},
		messages = { view_search = false },
		presets = { bottom_search = false, command_palette = true },
	},
}
