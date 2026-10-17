-- Disable Neovim's built-in LSP auto-start for rust-analyzer
-- rustaceanvim plugin will handle it exclusively
vim.g.lsp_auto_start = vim.g.lsp_auto_start or {}
pcall(function()
	vim.lsp.config("rust_analyzer", { enabled = false, autostart = false })
	vim.lsp.config("rust-analyzer", { enabled = false, autostart = false })
end)

require("vango.core.options")
require("vango.core.keymaps")

require("vango.core.cf_live")

-- Ask (Space aq): Claude Haiku in a float, loaded on first use
local function ask(fn)
	return function()
		local a = require("vango.ask")
		if not vim.g.vango_ask_ready then
			a.setup()
			vim.g.vango_ask_ready = true
		end
		if fn ~= "setup" then
			a[fn]()
		end
	end
end
vim.keymap.set("n", "<leader>aq", ask("open"), { desc = "Ask Claude (chat)" })
vim.keymap.set("x", "<leader>aq", ask("visual"), { desc = "Ask Claude about the selection" })
vim.keymap.set("n", "<leader>ae", ask("explain"), { desc = "Ask: explain this diagnostic" })
vim.api.nvim_create_user_command("Ask", function(a)
	ask("setup")() -- defines the real :Ask, then forwards
	vim.cmd((a.range > 0 and (a.line1 .. "," .. a.line2) or "") .. "Ask " .. a.args)
end, { nargs = "*", range = true, desc = "Ask Claude about the code" })

-- Run this file in any language (Space cr)
vim.keymap.set("n", "<leader>cr", function()
	require("vango.run").run()
end, { desc = "Run this file" })
