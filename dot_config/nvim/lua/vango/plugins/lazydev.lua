-- Lua completion and types for the nvim API while editing this config
-- (replaced the archived neodev.nvim 2026-10-17). Feeds blink via its source.
return {
	"folke/lazydev.nvim",
	ft = "lua",
	opts = {
		library = {
			{ path = "${3rd}/luv/library", words = { "vim%.uv" } },
		},
	},
}
