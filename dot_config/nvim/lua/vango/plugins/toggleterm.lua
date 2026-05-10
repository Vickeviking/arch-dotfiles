return {
	"akinsho/toggleterm.nvim",
	version = "*",
	config = function()
		require("toggleterm").setup({
			size = function(term)
				if term.direction == "horizontal" then
					return 15
				elseif term.direction == "vertical" then
					return vim.o.columns * 0.4
				end
			end,
			hide_numbers = true,
			shade_terminals = true,
			shading_factor = 2,
			start_in_insert = true,
			persist_size = true,
			direction = "float",
			close_on_exit = true,
			float_opts = {
				border = "curved",
				width = math.floor(vim.o.columns * 0.9),
				height = math.floor(vim.o.lines * 0.9),
				winblend = 2,
			},
		})

		----------------------------------------------------------------------
		--  Floating terminal toggles
		----------------------------------------------------------------------
		local Terminal = require("toggleterm.terminal").Terminal

		-- Reusable floating terminal (count = 1 keeps it persistent)
		local float = Terminal:new({ direction = "float", hidden = true, count = 1 })
		vim.keymap.set({ "n", "t" }, "<leader>z", function()
			float:toggle()
		end, { desc = "Toggle floating terminal" })

		-- System monitor
		local htop = Terminal:new({ cmd = "htop", hidden = true, direction = "float" })
		vim.keymap.set("n", "<leader>ht", function()
			htop:toggle()
		end, { desc = "Open Htop (float)" })

		-- Quick exit from terminal mode
		vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]], { desc = "Exit terminal mode" })
	end,
}
