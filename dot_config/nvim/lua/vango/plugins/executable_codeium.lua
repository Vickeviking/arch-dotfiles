-- ~/.config/nvim/lua/vango/plugins/codeium.lua
return {
	"Exafunction/codeium.nvim",
	dependencies = "nvim-lua/plenary.nvim",
	event = "InsertEnter",

	--------------------------------------------------------------------
	-- defaults: start in MULTI‑LINE (ghost text on, cmp popup off)
	--------------------------------------------------------------------
	opts = {
		enable_cmp_source = false,
		virtual_text = {
			enabled = true,
			idle_delay = 75,
			key_bindings = { accept = "<S-Tab>", next = "<C-n>", prev = "<C-p>" },
		},
		suggestion = { accept_word = false, accept_line = false },
	},

	config = function(_, opts)
		local codeium = require("codeium")
		local cmp = require("cmp")
		codeium.setup(opts) -- initial multi‑line
		cmp.setup({ completion = { autocomplete = false } })

		-- keep the original virtual‑text settings handy for re‑use
		local vt_cfg = opts.virtual_text

		----------------------------------------------------------------
		-- state machine
		----------------------------------------------------------------
		local mode = "multi" -- current mode, keep track to toggle

		local function apply_mode(new_mode)
			mode = new_mode
			local new_opts = { enable_cmp_source = false }

			if mode == "multi" then
				new_opts.virtual_text = vim.tbl_extend("force", vt_cfg, { enabled = true })
				new_opts.suggestion = { accept_word = false, accept_line = false }
				cmp.setup({ completion = { autocomplete = false } })
				vim.notify("Codeium → Multi‑line · ghost ON · popup OFF")
			else -- "line"
				new_opts.virtual_text = vim.tbl_extend("force", vt_cfg, { enabled = false })
				new_opts.suggestion = { accept_word = false, accept_line = true }
				cmp.setup({ completion = { autocomplete = { cmp.TriggerEvent.TextChanged } } })
				vim.notify("Codeium → Single‑line · ghost OFF · popup ON")
			end

			codeium.setup(new_opts)
		end

		----------------------------------------------------------------
		-- Toggle key: <Space> w n   (normal mode)
		----------------------------------------------------------------
		vim.keymap.set("n", "<leader>wn", function()
			apply_mode(mode == "multi" and "line" or "multi")
		end, { desc = "Toggle Codeium line ↔ multi‑line", silent = true })
	end,
}
