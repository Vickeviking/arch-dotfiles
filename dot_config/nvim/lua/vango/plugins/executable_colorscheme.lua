-- Colors follow desk-theme: `colors/desk.lua` reads ~/.config/themes/current/nvim.lua
-- (switch with `desk-theme <name>`, Super+Shift+T or /desk-theme; open nvims recolor live).
-- gruvbox stays installed as the fallback if the palette file is missing.
return {
	"morhetz/gruvbox",
	priority = 1000,
	config = function()
		vim.opt.winblend = 0
		vim.opt.pumblend = 0

		if vim.fn.filereadable(vim.fn.expand("~/.config/themes/current/nvim.lua")) == 1 then
			vim.cmd("colorscheme desk")
		else
			vim.g.gruvbox_contrast_dark = "hard"
			vim.cmd("colorscheme gruvbox")
		end
	end,
}
