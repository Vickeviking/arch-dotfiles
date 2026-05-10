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
		-- Toggle "expand macro" in the same window (preserves your UX)
		----------------------------------------------------------------------
		local function expand_macro_toggle_same_win()
			-- If we previously toggled, restore
			if vim.w._rt_expanded and vim.w._rt_prev_buf and vim.api.nvim_buf_is_valid(vim.w._rt_prev_buf) then
				local expanded_buf = vim.api.nvim_get_current_buf()
				vim.api.nvim_win_set_buf(0, vim.w._rt_prev_buf)
				pcall(vim.api.nvim_buf_delete, expanded_buf, { force = true })
				vim.w._rt_expanded, vim.w._rt_prev_buf = false, nil
				return
			end

			local curwin, prev_buf = vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf()
			local wins_before = vim.api.nvim_list_wins()

			-- Preferred path: rustaceanvim command
			local ok_cmd = pcall(function()
				vim.cmd.RustLsp({ "expandMacro" })
			end)

			-- Fallback: call rust-analyzer request directly
			if not ok_cmd then
				local params = vim.lsp.util.make_position_params(0, "utf-16")
				local client = vim.lsp.get_clients({ bufnr = 0, name = "rust-analyzer" })[1]
				if not client then
					vim.notify("No rust-analyzer client", vim.log.levels.WARN)
					return
				end
				client.request("rust-analyzer/expandMacro", params, function(err, result)
					if err or not result or not result.expansion or not result.expansion.text then
						vim.notify("expandMacro failed", vim.log.levels.WARN)
						return
					end
					local lines = vim.split(result.expansion.text, "\n", { plain = true })
					local buf = vim.api.nvim_create_buf(false, true)
					vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
					vim.bo[buf].filetype = "rust"
					vim.bo[buf].buftype = "nofile"
					vim.bo[buf].bufhidden = "wipe"
					vim.bo[buf].swapfile = false
					vim.api.nvim_set_current_buf(buf)
				end, 0)
			end

			-- Move expanded view into the same window & mark for toggle
			vim.schedule(function()
				local wins_after = vim.api.nvim_list_wins()
				local newwin
				for _, w in ipairs(wins_after) do
					local is_new = true
					for _, bw in ipairs(wins_before) do
						if w == bw then
							is_new = false
							break
						end
					end
					if is_new then
						newwin = w
						break
					end
				end
				if newwin and vim.api.nvim_win_is_valid(newwin) then
					local exp_buf = vim.api.nvim_win_get_buf(newwin)
					vim.api.nvim_win_set_buf(curwin, exp_buf)
					pcall(vim.api.nvim_win_close, newwin, true)
					vim.w._rt_prev_buf, vim.w._rt_expanded = prev_buf, true
					pcall(function()
						vim.bo[exp_buf].buftype = "nofile"
						vim.bo[exp_buf].bufhidden = "wipe"
						vim.bo[exp_buf].swapfile = false
					end)
				end
			end)
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
