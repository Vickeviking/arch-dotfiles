-- Disable Neovim's built-in LSP auto-start for rust-analyzer
-- rustaceanvim plugin will handle it exclusively
vim.g.lsp_auto_start = vim.g.lsp_auto_start or {}
pcall(function()
	vim.lsp.config("rust_analyzer", { enabled = false, autostart = false })
	vim.lsp.config("rust-analyzer", { enabled = false, autostart = false })
end)

require("vango.core.options")
require("vango.core.keymaps")
