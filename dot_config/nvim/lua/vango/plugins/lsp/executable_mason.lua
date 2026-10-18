return {
	-- mason core
	{
		"mason-org/mason.nvim",
		tag = "v2.1.0",
		config = function()
			require("mason").setup({
				ui = {
					icons = {
						package_installed = "✓",
						package_pending = "➜",
						package_uninstalled = "✗",
					},
				},
			})
		end,
	},

	-- mason-lspconfig
	{
		"mason-org/mason-lspconfig.nvim",
		tag = "v2.1.0",
		dependencies = { "mason-org/mason.nvim" },
		config = function()
			require("mason-lspconfig").setup({
				ensure_installed = {
					"clangd",
					"rust_analyzer", -- Needed for rustaceanvim (uses standalone version)
					"jdtls",
					"basedpyright",
					"ruff",
					"sqls",
					"marksman",
					"prismals",
					"vue_ls",
					"ts_ls",
					"eslint",
					"tailwindcss",
					"html",
					"cssls",
					"emmet_language_server",
					"jsonls",
					"yamlls",
					"stylelint_lsp",
					"lua_ls",
					"gopls",
					"bashls",
					"taplo",
					"dockerls",
				},
				automatic_enable = false,
			})
		end,
	},

	-- optional: tools (formatters/linters)
	{
		"WhoIsSethDaniel/mason-tool-installer.nvim",
		dependencies = { "mason-org/mason.nvim" },
		config = function()
			require("mason-tool-installer").setup({
				ensure_installed = {
					"cpplint",
					"clang-format",
					"codelldb", -- the debugger for Rust, C and C++ (behind xray-dap)
					"debugpy", -- the Python debugger (nvim-dap-python)
					-- rustfmt: not a mason package; provided by rustup/system (/usr/bin/rustfmt)
					"protolint",
					"ruff",
					"black",
					"stylua",
					"prismals",
					"google-java-format",
					"prettierd",
					"prettier",
					"stylelint",
					"markdownlint-cli2",
					"shfmt",
					"shellcheck",
				},
				auto_update = false,
				run_on_start = true,
				start_delay = 3000,
				debounce_hours = 24,
			})
		end,
	},
}
