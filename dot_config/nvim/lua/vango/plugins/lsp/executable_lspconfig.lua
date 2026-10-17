-- Neovim 0.11+ native LSP (no deprecated lspconfig "framework")
return {
	"neovim/nvim-lspconfig",
	event = { "BufReadPre", "BufNewFile" },
	dependencies = {
		-- Use the same repo names in ALL specs (pick one: mason-org/* or williamboman/*)
		-- Prefer the new org:
		"mason-org/mason.nvim",
		"mason-org/mason-lspconfig.nvim",
		"saghen/blink.cmp",
		{ "antosha417/nvim-lsp-file-operations", config = true },
	},
	config = function()
		local mason_lsp = require("mason-lspconfig")
		local caps = require("blink.cmp").get_lsp_capabilities()
		local eslint_on_attach = vim.lsp.config.eslint and vim.lsp.config.eslint.on_attach

		-- Diagnostics UI
		vim.diagnostic.config({
			virtual_text = {
				spacing = 4,
				prefix = "●",
				severity = { min = vim.diagnostic.severity.ERROR },
			},
			signs = true,
			underline = true,
			update_in_insert = false,
			severity_sort = true,
		})
		vim.o.updatetime = 500

		vim.api.nvim_create_autocmd("LspAttach", {
			group = vim.api.nvim_create_augroup("UserClangdInlayHints", {}),
			callback = function(ev)
				local client = vim.lsp.get_client_by_id(ev.data.client_id)
				if client and client.name == "clangd" then
					pcall(vim.lsp.inlay_hint.enable, true, { bufnr = ev.buf })
				end
			end,
		})

		-- Buffer-local maps on attach
		vim.api.nvim_create_autocmd("LspAttach", {
			group = vim.api.nvim_create_augroup("UserLspConfig", {}),
			callback = function(ev)
				local buf = ev.buf

				vim.api.nvim_create_autocmd({ "CursorMoved", "InsertEnter", "BufLeave" }, {
					buffer = buf,
					callback = function()
						pcall(vim.lsp.buf.clear_references)
					end,
				})

				for _, client in ipairs(vim.lsp.get_clients({ bufnr = buf })) do
					client.server_capabilities.documentHighlightProvider = false
				end

				local function map(lhs, rhs, desc, opts)
					vim.keymap.set(
						"n",
						lhs,
						rhs,
						vim.tbl_extend("force", { buffer = buf, silent = true, desc = desc }, opts or {})
					)
				end

				local diag_winid
				local function open_diagnostic_float()
					vim.schedule(function()
						vim.diagnostic.open_float(nil, { focus = false })
						for _, win in ipairs(vim.api.nvim_list_wins()) do
							local cfg = vim.api.nvim_win_get_config(win)
							if cfg.zindex and cfg.relative ~= "" then
								diag_winid = win
							end
						end
					end)
				end

				vim.keymap.set("n", "<M-o>", function()
					local lnum = vim.api.nvim_win_get_cursor(0)[1] - 1
					if #vim.diagnostic.get(0, { lnum = lnum }) > 0 then
						open_diagnostic_float()
					end
				end, { buffer = buf, silent = true, desc = "Diagnostic popup" })

				vim.api.nvim_create_autocmd({ "CursorMoved", "InsertEnter", "BufLeave" }, {
					buffer = buf,
					callback = function()
						if diag_winid and vim.api.nvim_win_is_valid(diag_winid) then
							pcall(vim.api.nvim_win_close, diag_winid, false)
							diag_winid = nil
						end
					end,
				})

				map("gd", "<cmd>Telescope lsp_definitions<cr>", "Go to definition")
				map("gr", "<cmd>Telescope lsp_references<cr>", "References")
				map("gi", "<cmd>Telescope lsp_implementations<cr>", "Go to implementation")
				map("<leader>rn", vim.lsp.buf.rename, "Rename symbol")
				map("<leader>ca", vim.lsp.buf.code_action, "Code actions")
				map("<C-j>", vim.diagnostic.goto_next, "Next diagnostic")
				map("<C-k>", vim.diagnostic.goto_prev, "Prev diagnostic")

				-- every language gets what Rust has: inlay hints (types, parameter
				-- names) on by default, a toggle, and a bordered K hover
				local client = vim.lsp.get_client_by_id(ev.data.client_id)
				if client and client:supports_method("textDocument/inlayHint") and vim.g.vango_inlay ~= false then
					pcall(vim.lsp.inlay_hint.enable, true, { bufnr = buf })
				end
				map("<leader>ci", function()
					local on = not vim.lsp.inlay_hint.is_enabled({ bufnr = buf })
					vim.lsp.inlay_hint.enable(on, { bufnr = buf })
					vim.notify("Inlay hints " .. (on and "on" or "off"))
				end, "Toggle inlay hints")
				if vim.bo[buf].filetype ~= "rust" then -- Rust's K is the lens (rust.lua)
					map("K", function()
						vim.lsp.buf.hover({ border = "rounded", max_width = 90 })
					end, "Docs for the symbol")
				end
			end,
		})

		-- Helper: register + enable by NAME (correct 0.11 flow)
		local function setup_server(server, opts)
			vim.lsp.config(server, opts or {}) -- register/extend config
			vim.lsp.enable(server) -- enable by name (not a table)
		end

		-- Servers list
		local servers = {
			"clangd",
			-- "rust_analyzer", -- Handled by rustaceanvim plugin
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
			"lua_ls", -- this config (lazydev adds the nvim API types)
			"gopls",
			"bashls", -- sh/bash/zsh, with shellcheck diagnostics
			"taplo", -- TOML: Cargo.toml, pyproject.toml
			"dockerls",
		}

		-- Per-server handlers
		local handlers = {}

		handlers["clangd"] = function()
			local clang_caps = require("blink.cmp").get_lsp_capabilities()
			clang_caps.offsetEncoding = { "utf-16" }
			setup_server("clangd", {
				capabilities = clang_caps,
				cmd = {
					"clangd",
					"--enable-config",
					"--log=error",
					"--background-index",
					"--background-index-priority=low",
					"--clang-tidy",
					"--header-insertion=iwyu",
					"--completion-style=bundled",
					"--function-arg-placeholders=1",
					"--pch-storage=disk",
					"--query-driver=/usr/bin/g++,/usr/bin/gcc,/usr/bin/clang++,/usr/bin/clang",
					"--malloc-trim",
					"-j=8",
					"--limit-results=50",
				},
				init_options = {
					-- single files without compile_commands.json still get warnings
					fallbackFlags = { "-Wall", "-Wextra" },
					clangdFileStatus = true,
					usePlaceholders = true,
					completeUnimported = false,
					semanticHighlighting = true,
				},
			})
		end

		-- rust_analyzer handler removed - rustaceanvim plugin handles rust-analyzer configuration

		-- jdtls 1.57 can't run on Java 27 (its bytecode weaver stops at class
		-- version 70), so it runs on an older JDK when one is installed next to
		-- the default: `sudo pacman -S jdk25-openjdk` (the default stays 27)
		handlers["jdtls"] = function()
			local opts = { capabilities = caps }
			for _, v in ipairs({ "25", "21" }) do
				local home = "/usr/lib/jvm/java-" .. v .. "-openjdk"
				if vim.uv.fs_stat(home .. "/bin/java") then
					opts.cmd_env = { JAVA_HOME = home }
					break
				end
			end
			setup_server("jdtls", opts)
		end

		handlers["basedpyright"] = function()
			setup_server("basedpyright", {
				capabilities = caps,
				basedpyright = {
					analysis = {
						typeCheckingMode = "standard",
						diagnosticMode = "openFilesOnly",
					},
				},
			})
		end

		handlers["ruff"] = function()
			setup_server("ruff", {
				capabilities = caps,
				on_attach = function(client)
					client.server_capabilities.hoverProvider = false
				end,
			})
		end

		handlers["sqls"] = function()
			setup_server("sqls", {
				capabilities = caps,
				on_attach = function(client)
					client.server_capabilities.documentFormattingProvider = false
					client.server_capabilities.documentRangeFormattingProvider = false
				end,
				single_file_support = true,
			})
		end

		handlers["vue_ls"] = function()
			setup_server("vue_ls", {
				capabilities = caps,
				filetypes = { "vue" },
				init_options = { vue = { hybridMode = false } },
			})
		end

		handlers["ts_ls"] = function()
			-- inlay hints like Rust's: parameter names, inferred types, return types
			local hints = {
				includeInlayParameterNameHints = "literals",
				includeInlayFunctionParameterTypeHints = true,
				includeInlayVariableTypeHints = true,
				includeInlayVariableTypeHintsWhenTypeMatchesName = false,
				includeInlayPropertyDeclarationTypeHints = true,
				includeInlayFunctionLikeReturnTypeHints = true,
				includeInlayEnumMemberValueHints = true,
			}
			setup_server("ts_ls", {
				capabilities = caps,
				settings = {
					typescript = { inlayHints = hints },
					javascript = { inlayHints = hints },
				},
			})
		end

		handlers["gopls"] = function()
			setup_server("gopls", {
				capabilities = caps,
				settings = {
					gopls = {
						hints = {
							assignVariableTypes = true,
							compositeLiteralFields = true,
							constantValues = true,
							functionTypeParameters = true,
							parameterNames = true,
							rangeVariableTypes = true,
						},
						staticcheck = true,
					},
				},
			})
		end

		handlers["taplo"] = function()
			-- taplo's schema catalog download is broken upstream; Cargo.toml's
			-- schema is given directly, so K and completion know its keys
			setup_server("taplo", {
				capabilities = caps,
				settings = {
					evenBetterToml = {
						schema = {
							enabled = true,
							associations = {
								[".*/Cargo\\.toml$"] = "https://json.schemastore.org/cargo.json",
								[".*/pyproject\\.toml$"] = "https://json.schemastore.org/pyproject.json",
							},
						},
					},
				},
			})
		end

		handlers["eslint"] = function()
			setup_server("eslint", {
				capabilities = caps,
				on_attach = function(client, bufnr)
					if eslint_on_attach then
						eslint_on_attach(client, bufnr)
					end
					client.server_capabilities.documentFormattingProvider = false
					client.server_capabilities.documentRangeFormattingProvider = false
				end,
				settings = { workingDirectory = { mode = "auto" }, format = false },
			})
		end

		handlers["prismals"] = function()
			setup_server("prismals", { capabilities = caps })
		end

		handlers["tailwindcss"] = function()
			setup_server("tailwindcss", {
				capabilities = caps,
				filetypes = {
					"html",
					"css",
					"scss",
					"sass",
					"javascript",
					"javascriptreact",
					"typescript",
					"typescriptreact",
					"vue",
				},
				root_dir = require("lspconfig.util").root_pattern(
					"tailwind.config.js",
					"tailwind.config.cjs",
					"tailwind.config.ts",
					"postcss.config.js",
					"package.json",
					".git"
				),
			})
		end

		handlers["html"] = function()
			setup_server("html", { capabilities = caps })
		end
		handlers["cssls"] = function()
			setup_server("cssls", { capabilities = caps })
		end
		handlers["jsonls"] = function()
			setup_server("jsonls", { capabilities = caps })
		end
		handlers["yamlls"] = function()
			setup_server("yamlls", { capabilities = caps })
		end
		handlers["emmet_language_server"] = function()
			setup_server("emmet_language_server", {
				capabilities = caps,
				filetypes = { "html", "css", "scss", "sass", "javascriptreact", "typescriptreact", "vue" },
			})
		end

		-- If mason-lspconfig exposes setup_handlers, reuse it to drive our setup
		if type(mason_lsp.setup_handlers) == "function" then
			mason_lsp.setup_handlers({
				function(server)
					-- Skip rust_analyzer - rustaceanvim handles it
					if server == "rust_analyzer" then
						return
					end
					if handlers[server] then
						return handlers[server]()
					end
					setup_server(server, { capabilities = caps })
				end,
			})
		else
			for _, server in ipairs(servers) do
				-- Skip rust_analyzer - rustaceanvim handles it
				if server == "rust_analyzer" then
					goto continue
				end
				if handlers[server] then
					handlers[server]()
				else
					setup_server(server, { capabilities = caps })
				end
				::continue::
			end
		end
	end,
}
