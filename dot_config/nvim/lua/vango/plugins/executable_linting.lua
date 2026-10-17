return {
	"mfussenegger/nvim-lint",
	event = { "BufReadPre", "BufNewFile" },
	config = function()
		local lint = require("lint")

		-- Configure linters for specific file types
		lint.linters_by_ft = {
			-- rust = { "clippy" }, -- Disabled: rust-analyzer already runs clippy on save
			c = { "cpplint" }, -- C linter
			cpp = { "cpplint" }, -- C++ linter (samma verktyg; clangd står för LSP-diagnostiken)
			python = { "ruff" },
			markdown = { "markdownlint-cli2" },
			css = { "stylelint" },
			scss = { "stylelint" },
			sass = { "stylelint" },
		}

		-- cpplint kör Googles stilguide rakt av och gnäller om copyright-header
		-- på rad 1 i varje C/C++-fil. Filtrera bort det bruset; clangd + clang-tidy
		-- står ändå för den riktiga diagnostiken.
		-- Ett projekt kan överstyra via egen CPPLINT.cfg i repo-roten.
		lint.linters.cpplint.args = {
			"--filter=-legal/copyright,-build/include_subdir,-build/c++11,-whitespace/indent_namespace",
			"--linelength=120",
		}

		local lint_augroup = vim.api.nvim_create_augroup("lint", { clear = true })

		vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "InsertLeave" }, {
			group = lint_augroup,
			callback = function()
				lint.try_lint()
			end,
		})

		vim.keymap.set("n", "<leader>l", function()
			lint.try_lint()
		end, { desc = "Trigger linting for current file" })
	end,
}
