return {
	"alexghergh/nvim-tmux-navigation",
	config = function()
		local n = require("nvim-tmux-navigation")
		n.setup({ disable_when_zoomed = true }) -- keeps behavior sane when a tmux pane is zoomed
		vim.keymap.set("n", "<C-h>", n.NvimTmuxNavigateLeft, { silent = true })
		vim.keymap.set("n", "<C-j>", n.NvimTmuxNavigateDown, { silent = true })
		vim.keymap.set("n", "<C-k>", n.NvimTmuxNavigateUp, { silent = true })
		vim.keymap.set("n", "<C-l>", n.NvimTmuxNavigateRight, { silent = true })
		vim.keymap.set("n", "<C-\\>", n.NvimTmuxNavigateLastActive, { silent = true })
	end,
}
