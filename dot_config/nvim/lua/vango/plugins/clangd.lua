-- C/C++ extras ovanpå clangd-LSP:en (som konfigureras i lsp/lspconfig.lua).
--
-- OBS: clangd_extensions v2 tog bort `server`- och `extensions`-nycklarna.
-- Den gamla configen här skickade in dem ändå, vilket tyst ignorerades --
-- så `autoSetHints` slog aldrig på några inlay hints. Numera görs det med
-- Neovims inbyggda vim.lsp.inlay_hint (0.10+), som clangd stödjer
-- (inlayHintProvider = true).
return {
	"p00f/clangd_extensions.nvim",
	ft = { "c", "cpp", "objc", "objcpp", "cuda" },
	config = function()
		require("clangd_extensions").setup({
			ast = {
				role_icons = {
					type = "🄣",
					declaration = "🄓",
					expression = "🄔",
					statement = ";",
					specifier = "🄢",
					["template argument"] = "🆃",
				},
				highlights = { detail = "Comment" },
			},
			memory_usage = { border = "rounded" },
			symbol_info = { border = "rounded" },
		})

		vim.api.nvim_create_autocmd("LspAttach", {
			group = vim.api.nvim_create_augroup("vango.clangd", { clear = true }),
			callback = function(ev)
				local client = vim.lsp.get_client_by_id(ev.data.client_id)
				if not client or client.name ~= "clangd" then
					return
				end
				local buf = ev.buf

				-- Inlay hints (parametrar + härledda typer)
				if client:supports_method("textDocument/inlayHint") then
					vim.lsp.inlay_hint.enable(true, { bufnr = buf })
				end

				local function map(lhs, rhs, desc)
					vim.keymap.set("n", lhs, rhs, { buffer = buf, silent = true, desc = desc })
				end

				map("<leader>ch", "<cmd>ClangdSwitchSourceHeader<cr>", "Clangd: växla .cpp/.h")
				map("<leader>ci", function()
					vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = buf }), { bufnr = buf })
				end, "Clangd: toggla inlay hints")
				map("<leader>ct", "<cmd>ClangdTypeHierarchy<cr>", "Clangd: typhierarki")
				map("<leader>cs", "<cmd>ClangdSymbolInfo<cr>", "Clangd: symbolinfo")
				map("<leader>cA", "<cmd>ClangdAST<cr>", "Clangd: visa AST")
				map("<leader>cM", "<cmd>ClangdMemoryUsage<cr>", "Clangd: minnesanvändning")
			end,
		})
	end,
}
