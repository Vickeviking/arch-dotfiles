-- lua/plugins/folds.lua
return {
	"kevinhwang91/nvim-ufo",
	dependencies = { "kevinhwang91/promise-async" },
	event = "VeryLazy",
	config = function()
		vim.o.foldcolumn = "1"
		vim.o.foldlevel = 99
		vim.o.foldlevelstart = 99
		vim.o.foldenable = true
		require("ufo").setup({
			provider_selector = function()
				return { "treesitter", "indent" }
			end,
		})
		-- Keys you’ll actually remember:
		vim.keymap.set("n", "<leader>f", "za", { desc = "Toggle fold" })
		vim.keymap.set("n", "<leader>fo", "zr", { desc = "Open all folds" })
		vim.keymap.set("n", "<leader>fc", "zm", { desc = "Close all folds" })
	end,
}
