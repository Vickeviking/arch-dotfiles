return {
	"nvim-tree/nvim-tree.lua",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	config = function()
		local nvimtree = require("nvim-tree")

		-- Disable netrw (built-in file explorer)
		vim.g.loaded_netrw = 1
		vim.g.loaded_netrwPlugin = 1

		-- Setup nvim-tree with custom options
		nvimtree.setup({
			view = {
				width = 35,
				relativenumber = true,
			},
			renderer = {
				indent_markers = {
					enable = true,
				},
				icons = {
					glyphs = {
						folder = {
							arrow_closed = "➔",
							arrow_open = "▼",
						},
					},
				},
			},
			actions = {
				open_file = {
					window_picker = {
						enable = false,
					},
				},
			},
			filters = {
				custom = { ".DS_Store" },
			},
			git = {
				ignore = false,
			},
		})

		-- Set keymaps for nvim-tree functionality
		local keymap = vim.keymap

		keymap.set("n", "<leader>ee", "<cmd>NvimTreeToggle<CR>", { desc = "Toggle file explorer" })
		keymap.set(
			"n",
			"<leader>ef",
			"<cmd>NvimTreeFindFileToggle<CR>",
			{ desc = "Toggle file explorer on current file" }
		)
		keymap.set("n", "<leader>ec", "<cmd>NvimTreeCollapse<CR>", { desc = "Collapse file explorer" })
		keymap.set("n", "<leader>er", "<cmd>NvimTreeRefresh<CR>", { desc = "Refresh file explorer" })

		-- Custom keybindings for opening files
		keymap.set("n", "<leader>et", function()
			local api = require("nvim-tree.api")
			api.node.open.tab() -- Open the selected file in a new tab
		end, { desc = "Open file in new tab" })

		keymap.set("n", "<leader>ev", function()
			local api = require("nvim-tree.api")
			api.node.open.vertical() -- Open the selected file in a new vertical split
		end, { desc = "Open file in new vertical split" })

		keymap.set("n", "<leader>es", function()
			local api = require("nvim-tree.api")
			api.node.open.horizontal() -- Open the selected file in a new horizontal split
		end, { desc = "Open file in new horizontal split" })
	end,
}
