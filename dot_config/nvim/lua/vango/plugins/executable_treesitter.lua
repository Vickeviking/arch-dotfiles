return {
	"nvim-treesitter/nvim-treesitter",
	branch = "main",
	lazy = false,
	build = ":TSUpdate",
	dependencies = {
		"windwp/nvim-ts-autotag",
	},
	config = function()
		local ts = require("nvim-treesitter")

		-- parsers to keep installed (main branch installs to stdpath("data")/site)
		ts.install({
			"json",
			"javascript",
			"typescript",
			"tsx",
			"yaml",
			"html",
			"css",
			"prisma",
			"markdown",
			"markdown_inline",
			"graphql",
			"bash",
			"lua",
			"vim",
			"dockerfile",
			"gitignore",
			"query",
			"vimdoc",
			"c",
			"cpp",
			"cmake",
			"make",
			"rust",
			"python",
			"vue",
			"java",
			"proto",
			"go",
			"sql",
			"latex", -- snacks.image renders LaTeX math via this
			"regex",
			"toml",
			"scss",
		})

		vim.api.nvim_create_autocmd("FileType", {
			group = vim.api.nvim_create_augroup("vango.treesitter", { clear = true }),
			callback = function(ev)
				local lang = vim.treesitter.language.get_lang(ev.match)
				if not lang or not pcall(vim.treesitter.start, ev.buf, lang) then
					return
				end
				-- markdown stays on default indent: treesitter's markdown indent
				-- misbehaves with nested lists
				if lang ~= "markdown" then
					vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
				end
			end,
		})

		-- autotag runs standalone on the main branch (no module system)
		require("nvim-ts-autotag").setup({})

		-- incremental selection (<C-space>) from the master branch is gone;
		-- flash.nvim's treesitter selection replaces it, see flash.lua
	end,
}
