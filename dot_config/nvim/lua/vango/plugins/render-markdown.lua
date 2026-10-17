return {
	"MeanderingProgrammer/render-markdown.nvim",
	dependencies = {
		"nvim-treesitter/nvim-treesitter",
		"nvim-tree/nvim-web-devicons",
	},
	-- "deck" is the cheat-sheet float (Space r): markdown parsed, always fully rendered
	ft = { "markdown", "deck" },
	init = function()
		vim.treesitter.language.register("markdown", "deck")
	end,
	opts = {
		file_types = { "markdown", "deck" },
		overrides = {
			filetype = {
				deck = {
					render_modes = true,
					anti_conceal = { enabled = false },
					heading = { width = "block", left_pad = 1, right_pad = 3, border = false },
					code = { width = "block", min_width = 60 },
				},
			},
		},
		-- Render everything except the line the cursor is on, so the raw
		-- markdown is always editable where you actually are.
		render_modes = { "n", "c", "t" },

		heading = {
			sign = false,
			icons = { "󰲡 ", "󰲣 ", "󰲥 ", "󰲧 ", "󰲩 ", "󰲫 " },
		},

		code = {
			sign = false,
			-- language name in a small label above the block, plus a background
			style = "full",
			width = "block",
			min_width = 45,
			left_pad = 2,
			right_pad = 2,
			border = "thin",
		},

		bullet = {
			icons = { "●", "○", "◆", "◇" },
		},

		checkbox = {
			unchecked = { icon = "󰄱 " },
			checked = { icon = "󰱒 " },
		},

		-- Keep tables aligned and boxed
		pipe_table = {
			preset = "round",
		},
	},
}
