return {
	"phaazon/hop.nvim",
	branch = "v2",
	dependencies = { "nvim-treesitter/nvim-treesitter" },
	event = { "BufReadPre", "BufNewFile" },
	config = function()
		local hop = require("hop")
		hop.setup({ keys = "etovxqpdygfblzhckisuran" }) -- a home-row label set

		-- two-char jump to any character sequence in view:
		vim.keymap.set({ "n", "v", "o" }, "gw", function()
			hop.hint_char2() -- prompt for two chars
		end, { remap = true, desc = "Hop two-char" })

		-- two-char jump to any **pattern** (regex) in view:
		vim.keymap.set({ "n", "v", "o" }, "gW", function()
			hop.hint_patterns() -- type a Lua pattern
		end, { remap = true, desc = "Hop two-char pattern" })
	end,
}
