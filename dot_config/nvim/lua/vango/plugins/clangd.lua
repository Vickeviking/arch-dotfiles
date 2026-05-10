return {
	"p00f/clangd_extensions.nvim",
	config = function()
		local clangd_ext = require("clangd_extensions")

		clangd_ext.setup({
			server = {
				-- This part plugs into your mason-lspconfig setup_handlers
				capabilities = require("cmp_nvim_lsp").default_capabilities(),
			},
			extensions = {
				autoSetHints = true,
				inlay_hints = {
					inline = false,
					parameter_hints_prefix = "<- ",
					other_hints_prefix = "=> ",
				},
			},
		})
	end,
}
