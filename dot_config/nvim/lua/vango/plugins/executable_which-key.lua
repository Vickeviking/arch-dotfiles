-- which-key: press Space and wait ~0.3 s to see every group and key.
-- Group names come from vango.core.groups, shared with the deck's Keys tab.
-- The deck itself (Space r, Space ?) is mapped here because it is the
-- "help with keys" layer on top of which-key.
return {
	"folke/which-key.nvim",
	event = "VeryLazy",
	init = function()
		vim.o.timeout = true
		vim.o.timeoutlen = 650
		vim.o.ttimeoutlen = 10
	end,
	opts = function()
		local spec = {
			{ "<leader>r", function() require("vango.deck").toggle() end, desc = "Deck (cheat sheet)", icon = "󰘦" },
			{ "<leader>?", function() require("vango.deck").keys() end, desc = "All keys (deck)", icon = "" },
		}
		for _, g in ipairs(require("vango.core.groups")) do
			table.insert(spec, { "<leader>" .. g[1], group = g[2], icon = { icon = g[3], hl = "WhichKeyGroup" } })
		end
		return {
			preset = "helix",
			delay = 300,
			spec = spec,
			win = { border = "rounded", title = true, title_pos = "center" },
			icons = { group = "", separator = "→" },
		}
	end,
	config = function(_, opts)
		require("which-key").setup(opts)
		-- colors from the desk palette, refreshed when desk-theme switches
		local function colors()
			local p = require("vango.deck.theme").palette()
			local set = vim.api.nvim_set_hl
			set(0, "WhichKey", { fg = p.accent, bold = true })
			set(0, "WhichKeyGroup", { fg = p.accent2, bold = true })
			set(0, "WhichKeyDesc", { fg = p.text })
			set(0, "WhichKeySeparator", { fg = p.border })
			set(0, "WhichKeyNormal", { bg = p.panel })
			set(0, "WhichKeyBorder", { fg = p.border, bg = p.panel })
			set(0, "WhichKeyTitle", { fg = p.accent, bg = p.panel, bold = true })
			set(0, "WhichKeyIcon", { fg = p.accent })
		end
		colors()
		vim.api.nvim_create_autocmd("ColorScheme", { callback = colors })
	end,
}
