return {
	"folke/flash.nvim",
	event = "VeryLazy",
	opts = {},
	keys = {
		-- replaces hop's gw: type chars, labels appear, jump anywhere in view
		{
			"gw",
			mode = { "n", "x", "o" },
			function()
				require("flash").jump()
			end,
			desc = "Flash jump",
		},
		-- replaces hop's gW pattern jump
		{
			"gW",
			mode = { "n", "x", "o" },
			function()
				require("flash").treesitter_search()
			end,
			desc = "Flash treesitter search",
		},
		-- replaces nvim-treesitter master's incremental selection:
		-- press again / use ; and , to grow or shrink the selection
		{
			"<C-space>",
			mode = { "n", "x", "o" },
			function()
				require("flash").treesitter()
			end,
			desc = "Treesitter selection",
		},
	},
}
