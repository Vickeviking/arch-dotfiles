return {
	-- Replaces rust-tools.nvim
	"mrcjkb/rustaceanvim",
	version = "^6", -- recommended to pin major
	ft = { "rust" }, -- lazy load on rust filetype
	priority = 1000, -- Load before other LSP plugins
	dependencies = {
		"hrsh7th/cmp-nvim-lsp",
		"mason-org/mason.nvim", -- Need mason-registry for rust-analyzer path
		-- rustaceanvim does NOT require nvim-lspconfig or mason,
		-- but your setup uses them for other langs which is fine.
	},
	init = function()
		-- CRITICAL: Disable built-in rust-analyzer BEFORE anything else
		-- Neovim 0.11+ has rust-analyzer in its default configs
		local ok, configs = pcall(require, "lspconfig.configs")
		if ok and configs.rust_analyzer then
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
			server = {
				-- Use Mason's standalone rust-analyzer (newer version with better inlay hints)
				cmd = { vim.fn.stdpath("data") .. "/mason/bin/rust-analyzer" },
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
					vim.keymap.set("n", "<leader>mx", expand_macro_toggle_same_win, vim.tbl_extend("force", opts, {
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
			map("K", vim.lsp.buf.hover, "Rust: hover documentation")

			-- Full docs (parallell till gK→man i C): K är snabb hover,
			-- gK öppnar den KOMPLETTA dokumentationen för symbolen under
			-- markören — std/docs.rs i webbläsaren via rustaceanvim.
			map("gK", function()
				vim.cmd.RustLsp("openDocs")
			end, "Rust: öppna std/docs.rs-dokumentationen")

			-- Code actions
			map("<leader>ca", vim.lsp.buf.code_action, "Rust: code actions")

			-- Macro expand toggle (your old <leader>mx)
			map("<leader>mx", expand_macro_toggle_same_win, "Rust: macro expand (toggle in-place)")

			-- Runnables / Testables (nice extras)
			map("<leader>rr", function()
				vim.cmd.RustLsp("runnables")
			end, "Rust: runnables")
			map("<leader>rt", function()
				vim.cmd.RustLsp("testables")
			end, "Rust: testables")
		end

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
