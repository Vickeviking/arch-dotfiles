return {
	"stevearc/conform.nvim",
	event = { "BufReadPre", "BufNewFile" },
	config = function()
		local conform = require("conform")
		local prettier = { "prettierd", "prettier" }

		conform.setup({
			formatters_by_ft = {
				javascript = prettier,
				typescript = prettier,
				javascriptreact = prettier,
				typescriptreact = prettier,
				svelte = prettier,
				css = prettier,
				html = prettier,
				json = prettier,
				jsonc = prettier,
				yaml = prettier,
				markdown = prettier,
				graphql = prettier,
				liquid = prettier,
				lua = { "stylua" },
				python = { "black" },
				c = { "clang-format" },
				cpp = { "clang-format" },
				java = { "google-java-format" },
				rust = { "rustfmt" },
				go = { "gofmt" },
				sh = { "shfmt" },
				bash = { "shfmt" },
				toml = { "taplo" },
				vue = prettier,
			},
			format_after_save = function(bufnr)
				if vim.bo[bufnr].filetype == "sql" then
					return nil
				end

				return {
					lsp_fallback = true,
				}
			end,
		})

		vim.keymap.set({ "n", "v" }, "<leader>mp", function()
			if vim.bo.filetype == "sql" then
				return
			end

			conform.format({
				lsp_fallback = true,
				async = false,
				timeout_ms = 1000,
			})
		end, { desc = "Format file or range (in visual mode)" })
	end,
}
