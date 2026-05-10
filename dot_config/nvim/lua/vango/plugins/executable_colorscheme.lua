return {
	"morhetz/gruvbox",
	priority = 1000,
	config = function()
		local function apply_surface_highlights()
			local set_hl = vim.api.nvim_set_hl

			set_hl(0, "NormalFloat", { fg = "#ebdbb2", bg = "#282828" })
			set_hl(0, "FloatBorder", { fg = "#928374", bg = "#282828" })
			set_hl(0, "Pmenu", { fg = "#ebdbb2", bg = "#282828" })
			set_hl(0, "PmenuSel", { fg = "#282828", bg = "#fabd2f", bold = true })
		end

		vim.g.gruvbox_contrast_dark = "hard"
		vim.cmd("colorscheme gruvbox")

		vim.opt.winblend = 0
		vim.opt.pumblend = 0

		vim.api.nvim_create_autocmd("ColorScheme", {
			group = vim.api.nvim_create_augroup("VangoGruvboxSurface", { clear = true }),
			pattern = "gruvbox",
			callback = apply_surface_highlights,
		})

		apply_surface_highlights()
	end,
}
