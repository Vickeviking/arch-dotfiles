return {
	"hrsh7th/nvim-cmp",
	event = "InsertEnter",
	dependencies = {
		"hrsh7th/cmp-buffer", -- source for text in buffer
		"hrsh7th/cmp-path", -- source for file system paths
		{
			"L3MON4D3/LuaSnip",
			version = "v2.*", -- Use the latest major version
			build = "make install_jsregexp", -- Optional: install jsregexp
		},
		"saadparwaiz1/cmp_luasnip", -- for autocompletion
		"rafamadriz/friendly-snippets", -- useful snippets
		"onsails/lspkind.nvim", -- VS Code-like pictograms
	},
	config = function()
		local cmp = require("cmp")
		local luasnip = require("luasnip")
		local lspkind = require("lspkind")

		-- Load VSCode style snippets from friendly-snippets
		require("luasnip.loaders.from_vscode").lazy_load()

		cmp.setup({
			completion = {
				completeopt = "menu,menuone,preview,noselect",
			},
			-- Ramade fönster med maxbredd: doc-panelen sprawlade kant-till-kant
			-- till vänster (Viktor 2026-10-11). cmp väljer sida efter plats, men
			-- en gräns + ram gör den till en prydlig ruta i stället för hela
			-- vänsterkanten.
			window = {
				completion = cmp.config.window.bordered(),
				documentation = cmp.config.window.bordered({
					max_width = 80,
					max_height = 20,
				}),
			},
			performance = {
				debounce = 80,
				throttle = 40,
				fetching_timeout = 400,
				max_view_entries = 50,
			},
			snippet = {
				expand = function(args)
					luasnip.lsp_expand(args.body)
				end,
			},
			mapping = {
				["<C-k>"] = cmp.mapping.select_prev_item(), -- previous suggestion
				["<C-j>"] = cmp.mapping.select_next_item(), -- next suggestion
				["<C-b>"] = cmp.mapping.scroll_docs(-4),
				["<C-f>"] = cmp.mapping.scroll_docs(4),
				-- Scrolla i doc-panelen med C-l (längre in) / C-h (tillbaka),
				-- medan menyn är öppen (Viktor 2026-10-11). När menyn är stängd
				-- faller de tillbaka till normalt beteende (C-h = backspace).
				["<C-l>"] = cmp.mapping.scroll_docs(4),
				["<C-h>"] = cmp.mapping.scroll_docs(-4),
				["<C-Space>"] = cmp.mapping.complete(), -- show completion suggestions
				["<C-e>"] = cmp.mapping.abort(), -- close completion window
				["<Tab>"] = cmp.mapping.confirm({ select = false }), -- confirm selection
				["<S-Tab>"] = cmp.mapping.select_next_item(), -- Shift + Tab to cycle to the next suggestion
			},
			sources = cmp.config.sources({
				{ name = "nvim_lsp", max_item_count = 40 }, -- LSP-based autocompletion
				{ name = "luasnip" }, -- snippet autocompletion
				{ name = "buffer" }, -- current buffer content
				{ name = "path" }, -- filesystem paths
				{ name = "codeium" },
			}),
			formatting = {
				format = lspkind.cmp_format({
					maxwidth = 50,
					ellipsis_char = "...",
				}),
			},
		})
	end,
}
