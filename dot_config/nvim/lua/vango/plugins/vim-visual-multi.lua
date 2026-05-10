return {
	"mg979/vim-visual-multi",
	event = "VeryLazy",
	init = function()
		vim.g.VM_maps = {
			["Find Under"] = "<C-n>", -- Start selecting matches
			["Find Subword Under"] = "<C-n>",
			["Skip Region"] = "<C-x>", -- Skip current and go to next
			["Remove Region"] = "<C-p>", -- Go back to previous
		}
	end,
}
