-- yazi inside nvim: a fast file manager with image previews (kitty graphics).
-- Space y opens it at the current file; Enter opens, q closes, ~ shows its keys.
return {
	"mikavilpas/yazi.nvim",
	cond = function()
		return vim.fn.executable("yazi") == 1
	end,
	dependencies = { "nvim-lua/plenary.nvim" },
	keys = {
		{ "<leader>y", "<cmd>Yazi<cr>", desc = "Yazi at this file" },
		{ "<leader>Y", "<cmd>Yazi cwd<cr>", desc = "Yazi in the working directory" },
	},
	opts = {
		open_for_directories = false,
		floating_window_scaling_factor = 0.85,
		yazi_floating_window_border = "rounded",
	},
}
