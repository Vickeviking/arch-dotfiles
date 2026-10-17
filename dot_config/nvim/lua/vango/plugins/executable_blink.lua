-- Completion: blink.cmp (replaced nvim-cmp 2026-10-17, same keys and feel).
-- The popup follows codeium's mode (codeium.lua, Space wn): in multi-line mode
-- (the default) it stays hidden and codeium's ghost text leads; C-Space shows
-- it. In single-line mode it pops up as you type.
return {
	{
		"saghen/blink.cmp",
		version = "1.*", -- prebuilt fuzzy matcher
		event = { "InsertEnter", "CmdlineEnter" },
		-- LuaSnip loads on its first require (blink's snippet source), not with blink
		dependencies = {},
		opts = {
			snippets = { preset = "luasnip" },
			keymap = {
				preset = "none",
				["<C-k>"] = { "select_prev", "fallback" },
				["<C-j>"] = { "select_next", "fallback" },
				["<C-b>"] = { "scroll_documentation_up", "fallback" },
				["<C-f>"] = { "scroll_documentation_down", "fallback" },
				-- scroll the doc panel with C-l / C-h while the menu is open
				-- (Viktor 2026-10-11); otherwise they keep their normal meaning
				["<C-l>"] = { "scroll_documentation_down", "fallback" },
				["<C-h>"] = { "scroll_documentation_up", "fallback" },
				["<C-Space>"] = { "show", "show_documentation", "hide_documentation" },
				["<C-e>"] = { "hide", "fallback" },
				["<Tab>"] = { "accept", "snippet_forward", "fallback" },
				-- with the menu closed, S-Tab falls through to codeium's ghost-text accept
				["<S-Tab>"] = { "select_next", "snippet_backward", "fallback" },
			},
			completion = {
				list = { max_items = 50, selection = { preselect = false, auto_insert = false } },
				menu = {
					border = "rounded",
					auto_show = function()
						return vim.g.vango_completion_popup == true
					end,
					draw = { columns = { { "kind_icon" }, { "label", "label_description", gap = 1 }, { "kind" } } },
				},
				-- framed doc panel with a max size: it used to sprawl edge to edge (Viktor 2026-10-11)
				documentation = {
					auto_show = true,
					auto_show_delay_ms = 150,
					window = { border = "rounded", max_width = 80, max_height = 20 },
				},
				accept = { auto_brackets = { enabled = true } },
				ghost_text = { enabled = false }, -- codeium owns ghost text
			},
			signature = { enabled = true, window = { border = "rounded" } },
			sources = {
				default = { "lazydev", "lsp", "snippets", "buffer", "path" },
				providers = {
					lsp = { max_items = 40 },
					lazydev = { name = "LazyDev", module = "lazydev.integrations.blink", score_offset = 100 },
				},
			},
			cmdline = { enabled = true, completion = { menu = { auto_show = true } } },
			fuzzy = { implementation = "prefer_rust_with_warning" },
		},
		config = function(_, opts)
			require("blink.cmp").setup(opts)
			local function colors()
				local p = require("vango.deck.theme").palette()
				local mix = require("vango.deck.theme").mix
				local set = vim.api.nvim_set_hl
				set(0, "BlinkCmpMenu", { fg = p.text, bg = p.panel })
				set(0, "BlinkCmpMenuBorder", { fg = p.border, bg = p.panel })
				set(0, "BlinkCmpMenuSelection", { bg = mix(p.accent, p.panel, 0.2), bold = true })
				set(0, "BlinkCmpDoc", { fg = p.text, bg = p.panel })
				set(0, "BlinkCmpDocBorder", { fg = p.border, bg = p.panel })
				set(0, "BlinkCmpSignatureHelp", { fg = p.text, bg = p.panel })
				set(0, "BlinkCmpSignatureHelpBorder", { fg = p.border, bg = p.panel })
				set(0, "BlinkCmpLabelMatch", { fg = p.accent, bold = true })
				set(0, "BlinkCmpKind", { fg = p.accent2 })
			end
			colors()
			vim.api.nvim_create_autocmd("ColorScheme", { callback = colors })
		end,
	},
	{
		"L3MON4D3/LuaSnip",
		version = "v2.*",
		lazy = true,
		build = "make install_jsregexp",
		dependencies = { "rafamadriz/friendly-snippets" },
		config = function()
			require("luasnip.loaders.from_vscode").lazy_load()
		end,
	},
}
