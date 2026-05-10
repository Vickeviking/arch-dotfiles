-- lua/plugins/edgy.lua
return {
	"folke/edgy.nvim",
	event = "VeryLazy",
	opts = {
		right = {
			{ title = "Diagnostics", ft = "trouble", size = { width = 0.35 } },
			{ title = "Overseer", ft = "OverseerList", size = { width = 0.35 } },
			{ title = "Tests", ft = "neotest-summary", size = { width = 0.35 } },
		},
	},
}
