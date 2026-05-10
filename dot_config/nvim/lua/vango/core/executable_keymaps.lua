vim.g.mapleader = " "
vim.opt.timeout = true

local keymap = vim.keymap --for conciseness

keymap.set("i", "jk", "<ESC>", { desc = "Exit insert mode with jk" })

keymap.set("n", "<leader>nh", ":nohl<CR>", { desc = "Clear search highlights" })

-- increment/decrement numbers
keymap.set("n", "<leader>+", "<C-a>", { desc = "Increment number" }) -- increment
keymap.set("n", "<leader>-", "<C-x>", { desc = "decrement number" }) -- decrement

-- window management
keymap.set("n", "<leader>sv", "<C-w>v", { desc = "Split window vertically" })
keymap.set("n", "<leader>sh", "<C-w>s", { desc = "Split window horizontally" })
keymap.set("n", "<leader>se", "<C-w>=", { desc = "Split window of equal size" })
keymap.set("n", "<leader>sx", "<cmd>close<CR>", { desc = "Close current window" })

-- tabs

keymap.set("n", "<leader>tt", "<cmd>tabnew<CR>", { desc = "Open new tab" })
keymap.set("n", "<leader>tx", "<cmd>tabclose<CR>", { desc = "Close tab" })
keymap.set("n", "<leader>tk", "<cmd>tabn<CR>", { desc = "Next tab" })
keymap.set("n", "<leader>tj", "<cmd>tabp<CR>", { desc = "Prev tab" })
keymap.set("n", "<leader>tb", "<cmd>tabnew %<CR>", { desc = "Open current buffer in new tab" })

-- go to definition (LSP)
keymap.set("n", "<leader>gd", vim.lsp.buf.definition, { desc = "Go to definition" })

-- jump back/forward in jump list
keymap.set("n", "<leader>jb", "<C-o>", { desc = "Jump back" })
keymap.set("n", "<leader>jf", "<C-i>", { desc = "Jump forward" })

-- list all buffers
keymap.set("n", "<leader>bl", "<cmd>ls<CR>", { desc = "List buffers" })
-- cycle next/prev
keymap.set("n", "<leader>bn", "<cmd>bnext<CR>", { desc = "Next buffer" })
keymap.set("n", "<leader>bp", "<cmd>bprevious<CR>", { desc = "Prev buffer" })
-- close buffer
keymap.set("n", "<leader>bd", "<cmd>bdelete<CR>", { desc = "Delete buffer" })

-- move lines up/down in visual mode
keymap.set("v", "<A-j>", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
keymap.set("v", "<A-k>", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })

-- trouble binds (exempel)
vim.keymap.set("n", "<leader>xx", "<cmd>Trouble diagnostics toggle<CR>", { desc = "Diagnostics panel" })
vim.keymap.set("n", "<leader>xq", "<cmd>Trouble qflist toggle<CR>", { desc = "Quickfix panel" })
vim.keymap.set("n", "<leader>xr", "<cmd>Trouble lsp toggle<CR>", { desc = "LSP symbols panel" })
