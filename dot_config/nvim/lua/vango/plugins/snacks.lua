return {
	"folke/snacks.nvim",
	priority = 1000,
	lazy = false,
	-- only the image module for now — notifications, dashboard etc. are
	-- already covered by nvim-notify/noice/alpha
	opts = {
		image = {
			enabled = true,
			doc = {
				-- render images inline in the buffer (markdown, html, css, ...)
				inline = true,
				-- and in hover floats where inline isn't possible
				float = true,
			},
		},
	},
}
