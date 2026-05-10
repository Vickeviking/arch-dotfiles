-- lua/plugins/overseer.lua
return {
	"stevearc/overseer.nvim",
	version = "v1.6.0", -- undvik breaking changes
	cmd = { "OverseerRun", "OverseerToggle", "OverseerOpen", "OverseerClose" },
	opts = {
		task_list = {
			direction = "bottom",
			min_height = 10,
			max_height = 20,
			default_detail = 1,
		},
		strategy = {
			"terminal",
			direction = "horizontal",
			open_on_start = true,
			close_on_exit = "success", -- lämna öppen vid fel
		},
		log = { level = vim.log.levels.WARN },
	},
	keys = {
		{
			"<leader>oo",
			function()
				require("overseer").toggle({ direction = "bottom" })
			end,
			desc = "Toggle Overseer panel",
		},

		-- cargo build
		{
			"<leader>ob",
			function()
				local overseer = require("overseer")
				local task = overseer.new_task({
					cmd = { "cargo", "build" },
					components = { "default" },
					strategy = { "terminal", direction = "horizontal" },
				})
				task:start()
				overseer.open({ direction = "bottom", enter = false })
			end,
			desc = "Cargo build",
		},

		-- cargo run
		{
			"<leader>or",
			function()
				local overseer = require("overseer")
				local task = overseer.new_task({
					cmd = { "cargo", "run" },
					components = { "default" },
					strategy = { "terminal", direction = "horizontal" },
				})
				task:start()
				overseer.open({ direction = "bottom", enter = false })
			end,
			desc = "Cargo run",
		},

		-- cargo test
		{
			"<leader>ot",
			function()
				local overseer = require("overseer")
				local task = overseer.new_task({
					cmd = { "cargo", "test", "--", "--nocapture" },
					components = { "default" },
					strategy = { "terminal", direction = "horizontal" },
				})
				task:start()
				overseer.open({ direction = "bottom", enter = false })
			end,
			desc = "Cargo test",
		},
	},
}
