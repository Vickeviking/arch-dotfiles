vim.g.mapleader = " "
vim.opt.timeout = true

local keymap = vim.keymap --for conciseness

keymap.set("i", "jk", "<ESC>", { desc = "Exit insert mode with jk" })

keymap.set("n", "<leader>nh", ":nohl<CR>", { desc = "Clear search highlights" })

keymap.set("n", "<leader>ow", function()
	require("vango.core.open_web").open_current_file()
end, { desc = "Open current file in browser" })

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

-- Full manual for the word under the cursor (Viktor 2026-09-01): K is the
-- quick LSP hover (type + docstring); gK opens the COMPLETE man page —
-- man 3/2, same as `man pthread_create` — in a split with highlights and
-- jumpable links (K inside a man buffer follows a link, C-o goes back).
-- Needs the man-pages package (installed on both machines).
--
-- OpenMP has no man pages (Viktor 2026-09-28), so when `man` has nothing gK
-- falls back to GCC's libgomp info manual, which has one node per routine /
-- env var (omp_get_thread_num, OMP_NUM_THREADS, ...). q closes it.
vim.keymap.set("n", "gK", function()
  local word = vim.fn.expand("<cword>")
  vim.fn.system({ "man", "-w", word })
  if vim.v.shell_error == 0 then
    vim.cmd("Man " .. word)
    return
  end
  local lines = vim.fn.systemlist({ "info", "-f", "libgomp", "-n", word, "-o", "-" })
  if vim.v.shell_error ~= 0 then
    vim.notify("No man page or libgomp info for " .. word, vim.log.levels.WARN)
    return
  end
  vim.cmd("new")
  local buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].modifiable = false
  vim.bo[buf].filetype = "info"
  vim.api.nvim_buf_set_name(buf, "info://libgomp/" .. word)
  vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, silent = true })
end, { desc = "Full man page (or libgomp info) for word under cursor" })

-- Same jump keys inside man pages as in code (Viktor 2026-09-01): nvim's man
-- ftplugin navigates with C-] / C-t, but gd and <leader>jb are the muscle
-- memory. gd follows a `pthread_create(3)` reference through man's tagfunc;
-- <leader>jb pops the tag stack, falling back to the jumplist when the page
-- was opened with gK (nothing on the tag stack then).
vim.api.nvim_create_autocmd("FileType", {
  pattern = "man",
  desc = "gd/<leader>jb navigation in man buffers",
  callback = function(ev)
    vim.keymap.set("n", "gd", "<C-]>", {
      buffer = ev.buf,
      silent = true,
      desc = "Follow man reference",
    })
    vim.keymap.set("n", "<leader>jb", function()
      if not pcall(vim.cmd.pop) then
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-o>", true, false, true), "n", false)
      end
    end, {
      buffer = ev.buf,
      silent = true,
      desc = "Jump back",
    })
  end,
})
