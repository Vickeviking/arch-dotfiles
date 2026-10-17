return {
	-- Replaces rust-tools.nvim
	"mrcjkb/rustaceanvim",
	version = "^6", -- recommended to pin major
	ft = { "rust" }, -- lazy load on rust filetype
	priority = 1000, -- Load before other LSP plugins
	dependencies = {
		"saghen/blink.cmp",
		"mason-org/mason.nvim", -- Need mason-registry for rust-analyzer path
		-- rustaceanvim does NOT require nvim-lspconfig or mason,
		-- but your setup uses them for other langs which is fine.
	},
	init = function()
		-- CRITICAL: Disable built-in rust-analyzer BEFORE anything else
		-- Neovim 0.11+ has rust-analyzer in its default configs
		-- Only if lspconfig is already loaded: requiring it here pulled lspconfig
		-- (and its dependencies) into every startup for ~20 ms. core/init.lua
		-- already disables rust_analyzer through vim.lsp.config.
		local configs = package.loaded["lspconfig.configs"]
		if configs and configs.rust_analyzer then
			configs.rust_analyzer = nil
		end
		
		-- Also prevent vim.lsp auto-start
		vim.api.nvim_create_autocmd("FileType", {
			pattern = "rust",
			callback = function(args)
				-- Kill any rust-analyzer client with only lens settings (the built-in one)
				vim.defer_fn(function()
					for _, client in ipairs(vim.lsp.get_clients({ bufnr = args.buf })) do
						if client.name == "rust_analyzer" or client.name == "rust-analyzer" then
							local has_inlay = client.config.settings
								and client.config.settings["rust-analyzer"]
								and client.config.settings["rust-analyzer"].inlayHints
							-- If it doesn't have our inlay hints config, it's the wrong one
							if not has_inlay then
								vim.lsp.stop_client(client.id, true)
							end
						end
					end
				end, 100)
			end,
		})
		
		-- Configure rust-analyzer via rustaceanvim
		vim.g.rustaceanvim = {
			-- Debugging goes through xray-dap (genomlysning): it passes everything
			-- between nvim-dap and codelldb through and records a memory snapshot at
			-- every stop. Without xray-dap installed it's plain codelldb.
			dap = {
				adapter = function()
					local ext = vim.fn.stdpath("data") .. "/mason/packages/codelldb/extension"
					local codelldb, liblldb = ext .. "/adapter/codelldb", ext .. "/lldb/lib/liblldb.so"
					local cmd = vim.fn.exepath("xray-dap") ~= "" and vim.fn.exepath("xray-dap") or nil
					return {
						type = "server",
						port = "${port}",
						host = "127.0.0.1",
						executable = {
							command = cmd or codelldb,
							args = cmd and { "--codelldb", codelldb, "--liblldb", liblldb, "--port", "${port}" }
								or { "--liblldb", liblldb, "--port", "${port}" },
						},
					}
				end,
			},
			server = {
				-- rustup's rust-analyzer: it matches the installed rustc, so it can compute
				-- memory layouts (size/align on K, and the lens). Mason's standalone build
				-- (0.3.2854) couldn't (checked 2026-10-17). Mason's stays as a fallback.
				cmd = {
					vim.fn.exepath("rust-analyzer") ~= "" and vim.fn.exepath("rust-analyzer")
						or (vim.fn.stdpath("data") .. "/mason/bin/rust-analyzer"),
				},
				settings = {
					["rust-analyzer"] = {
						check = {
							command = "clippy",
							extraArgs = { "--no-deps" },
						},
						checkOnSave = true,
						cargo = {
							allFeatures = true,
						},
						inlayHints = {
							bindingModeHints = { enable = true },
							chainingHints = { enable = true },
							closingBraceHints = { enable = true, minLines = 25 },
							closureReturnTypeHints = { enable = "always" },
							lifetimeElisionHints = { enable = "always", useParameterNames = true },
							maxLength = 25,
							parameterHints = { enable = true },
							reborrowHints = { enable = "always" },
							renderColons = true,
							typeHints = {
								enable = true,
								hideClosureInitialization = false,
								hideNamedConstructor = false,
							},
						},
					},
				},
			},
		}
	end,
	config = function()
		----------------------------------------------------------------------
		-- Toggle "expand macro" in the same window.
		----------------------------------------------------------------------
		local function macro_expansion_lines(result)
			local name = result.name or "selected"
			local title = "// Recursive expansion of the " .. name .. " macro"
			local lines = {
				"// " .. string.rep("=", #title - 3),
				title,
				"// " .. string.rep("=", #title - 3),
				"",
			}

			for _, line in ipairs(vim.split(result.expansion or "", "\n", { plain = true })) do
				table.insert(lines, line)
			end

			return lines
		end

		local function expand_macro_toggle_same_win()
			if vim.w._rt_expanded_buf and vim.api.nvim_get_current_buf() == vim.w._rt_expanded_buf then
				local expanded_buf = vim.api.nvim_get_current_buf()
				vim.api.nvim_win_set_buf(0, vim.w._rt_prev_buf)
				if vim.w._rt_prev_view then
					pcall(vim.fn.winrestview, vim.w._rt_prev_view)
				end
				pcall(vim.api.nvim_buf_delete, expanded_buf, { force = true })
				vim.w._rt_expanded_buf, vim.w._rt_prev_buf, vim.w._rt_prev_view = nil, nil, nil
				return
			end

			local prev_buf = vim.api.nvim_get_current_buf()
			local client = vim.lsp.get_clients({ bufnr = prev_buf, name = "rust-analyzer" })[1]
			if not client then
				vim.notify("No rust-analyzer client", vim.log.levels.WARN)
				return
			end

			local params = vim.lsp.util.make_position_params(0, client.offset_encoding or "utf-8")
			local prev_view = vim.fn.winsaveview()
			client.request("rust-analyzer/expandMacro", params, function(err, result)
				if err or not result or not result.expansion then
					vim.notify("No macro expansion available", vim.log.levels.INFO)
					return
				end

				vim.schedule(function()
					if not vim.api.nvim_buf_is_valid(prev_buf) then
						return
					end

					local exp_buf = vim.api.nvim_create_buf(false, true)
					vim.bo[exp_buf].filetype = "rust"
					vim.bo[exp_buf].buftype = "nofile"
					vim.bo[exp_buf].bufhidden = "wipe"
					vim.bo[exp_buf].swapfile = false
					vim.bo[exp_buf].modifiable = true
					vim.api.nvim_buf_set_lines(exp_buf, 0, -1, false, macro_expansion_lines(result))
					vim.bo[exp_buf].modifiable = false
					vim.bo[exp_buf].readonly = true

					vim.api.nvim_win_set_buf(0, exp_buf)
					vim.w._rt_prev_buf = prev_buf
					vim.w._rt_prev_view = prev_view
					vim.w._rt_expanded_buf = exp_buf

					local opts = { buffer = exp_buf, silent = true, nowait = true }
					vim.keymap.set("n", "<leader>Rm", expand_macro_toggle_same_win, vim.tbl_extend("force", opts, {
						desc = "Rust: return from macro expansion",
					}))
					vim.keymap.set("n", "q", expand_macro_toggle_same_win, vim.tbl_extend("force", opts, {
						desc = "Rust: close macro expansion",
					}))
				end)
			end, prev_buf)
		end

		----------------------------------------------------------------------
		-- Rust-only keymaps (use :RustLsp … and replace K hover)
		----------------------------------------------------------------------
		local function set_rust_keymaps(bufnr)
			local map = function(lhs, rhs, desc)
				vim.keymap.set("n", lhs, rhs, { buffer = bufnr, silent = true, desc = desc })
			end

			-- Hover documentation
			-- K: hover (with size/align); K again while it shows: the Rust lens
			-- (layout, methods, traits, calls, tests). See the deck, Types & layout.
			map("K", function()
				require("vango.lens").K()
			end, "Rust: hover, K again for the lens")

			-- Full docs (parallell till gK→man i C): K är snabb hover,
			-- gK öppnar den KOMPLETTA dokumentationen för symbolen under
			-- markören — std/docs.rs i webbläsaren via rustaceanvim.
			map("gK", function()
				vim.cmd.RustLsp("openDocs")
			end, "Rust: öppna std/docs.rs-dokumentationen")

			-- Code actions
			map("<leader>ca", vim.lsp.buf.code_action, "Rust: code actions")

			-- Rust group, Space R (2026-10-17; was <leader>mx / rr / rt). Listed in the deck.
			map("<leader>Rm", expand_macro_toggle_same_win, "Rust: macro expand (toggle in place)")
			map("<leader>Rr", function()
				vim.cmd.RustLsp("runnables")
			end, "Rust: runnables (pick something to run)")
			map("<leader>Rt", function()
				vim.cmd.RustLsp("testables")
			end, "Rust: testables (pick a test to run)")
			map("<leader>Re", function()
				vim.cmd.RustLsp("explainError")
			end, "Rust: explain the error code here")
			map("<leader>Rd", function()
				vim.cmd.RustLsp("renderDiagnostic")
			end, "Rust: full compiler diagnostic, as cargo prints it")
			map("<leader>Rp", function()
				vim.cmd.RustLsp("parentModule")
			end, "Rust: go to parent module")
			map("<leader>Rc", function()
				vim.cmd.RustLsp("openCargo")
			end, "Rust: open Cargo.toml")
		end

		-- lens: keep recorded layouts fresh on save (only crates that have them)
		require("vango.lens").setup()

		-- Apply the keymaps on LSP attach for Rust buffers only.
		vim.api.nvim_create_autocmd("LspAttach", {
			group = vim.api.nvim_create_augroup("RustaceanKeymaps", { clear = true }),
			callback = function(args)
				local client = vim.lsp.get_clients({ id = args.data.client_id })[1]
				-- Client name is "rust-analyzer" (hyphen, not underscore)
				if client and client.name == "rust-analyzer" then
					set_rust_keymaps(args.buf)
					-- Enable inlay hints for this buffer
					vim.lsp.inlay_hint.enable(true, { bufnr = args.buf })
				end
			end,
		})
	end,
}
