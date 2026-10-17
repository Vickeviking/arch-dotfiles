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
		-- Hovern (K) lämnas åt nvims INBYGGDA float (Viktor 2026-09-01):
		-- noice-hovern är inte fokuserbar, så <C-h>-hoppet in i rutan
		-- (tmux-navigator.lua) studsade. Den inbyggda är enterbar — både
		-- via <C-h> och genom att trycka K två gånger.
		lsp = { hover = { enabled = false } },
		presets = { bottom_search = false, command_palette = true },
	},
}
