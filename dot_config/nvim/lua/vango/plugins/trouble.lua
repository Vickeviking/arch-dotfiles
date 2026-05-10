-- lua/plugins/trouble.lua
return {
	"folke/trouble.nvim",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	cmd = { "Trouble" },
	opts = { use_diagnostic_signs = true },
	config = function(_, opts)
		require("trouble").setup(opts)
		local map = vim.keymap.set
		map("n", "<leader>xx", "<cmd>Trouble diagnostics toggle<CR>", { desc = "Diagnostics panel" })
		map("n", "<leader>xq", "<cmd>Trouble qflist toggle<CR>", { desc = "Quickfix panel" })
		map("n", "<leader>xr", "<cmd>Trouble lsp toggle<CR>", { desc = "LSP symbols panel" })
	end,
}
