-- lua/plugins/neotest_rust.lua
return {
	"nvim-neotest/neotest",
	dependencies = {
		"rouge8/neotest-rust",
		"nvim-lua/plenary.nvim",
		"nvim-treesitter/nvim-treesitter",
		"nvim-neotest/nvim-nio",
		-- Optional but recommended for CursorHold behavior with neotest:
		-- "antoinemadec/FixCursorHold.nvim",
	},
	keys = {
		{
			"<leader>tn",
			function()
				require("neotest").run.run()
			end,
			desc = "Run nearest test",
		},
		{
			"<leader>tf",
			function()
				require("neotest").run.run(vim.fn.expand("%"))
			end,
			desc = "Run file tests",
		},
		{
			"<leader>ts",
			function()
				require("neotest").summary.toggle()
			end,
			desc = "Toggle test summary",
		},
		{
			"<leader>to",
			function()
				require("neotest").output.open({ enter = true })
			end,
			desc = "Open test output",
		},
		{
			"<leader>tw",
			function()
				require("neotest").watch.toggle(vim.fn.expand("%"))
			end,
			desc = "Watch file tests",
		},
	},
	config = function()
		local ok, neotest = pcall(require, "neotest")
		if not ok then
			return
		end
		neotest.setup({
			adapters = {
				require("neotest-rust")({
					-- nextest args. Use "--no-capture" for nextest, not "--nocapture"
					args = { "--no-capture" },
				}),
			},
			quickfix = { enabled = true, open = false },
		})
	end,
}
