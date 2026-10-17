-- Run this file (Space cr): one key for every language. Saves, then runs the
-- file in a terminal split at the bottom; running again reuses that split.
-- q in the split closes it. Rust has the richer Space Rr (runnables).

local M = {}

local function c_like(compiler, std)
  return function(f)
    local out = vim.fn.stdpath("cache") .. "/run-" .. vim.fn.fnamemodify(f, ":t:r")
    return ("%s %s -g -Wall -Wextra %s -o %s && %s"):format(compiler, std, vim.fn.shellescape(f), out, out)
  end
end

-- filetype → command for the file f (a function when it needs more than the path)
M.RUNNERS = {
  python = "python3 %s",
  javascript = "node %s",
  typescript = "node %s", -- node 23+ strips types itself
  go = "go run %s",
  lua = "nvim -l %s",
  sh = "bash %s",
  bash = "bash %s",
  zsh = "zsh %s",
  java = "java %s", -- single-file source launcher
  c = c_like("gcc", "-std=c17"),
  cpp = c_like("g++", "-std=c++20"),
  rust = function()
    return "cargo run -q"
  end,
  ruby = "ruby %s",
  perl = "perl %s",
  sql = function(f)
    return "sqlite3 :memory: < " .. vim.fn.shellescape(f)
  end,
}

function M.command(ft, file)
  local r = M.RUNNERS[ft]
  if not r then
    return nil
  end
  if type(r) == "function" then
    return r(file)
  end
  return r:format(vim.fn.shellescape(file))
end

local term = { buf = nil, win = nil }

function M.run()
  local file = vim.api.nvim_buf_get_name(0)
  local ft = vim.bo.filetype
  local cmd = file ~= "" and M.command(ft, file)
  if not cmd then
    vim.notify(("Run: no runner for %s files yet (add one in lua/vango/run.lua)"):format(ft ~= "" and ft or "these"),
      vim.log.levels.WARN)
    return
  end
  if vim.bo.modified then
    vim.cmd.write()
  end
  local dir = vim.fn.fnamemodify(file, ":h")
  local from = vim.api.nvim_get_current_win()

  if term.win and vim.api.nvim_win_is_valid(term.win) then
    vim.api.nvim_set_current_win(term.win)
  else
    vim.cmd("botright 14split")
    term.win = vim.api.nvim_get_current_win()
  end
  local old = term.buf
  term.buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(term.win, term.buf)
  if old and vim.api.nvim_buf_is_valid(old) then
    vim.api.nvim_buf_delete(old, { force = true })
  end
  local started = vim.uv.now()
  -- shown with the bare file name; the winbar reads % as a format item
  local shown = cmd:gsub(vim.pesc(vim.fn.shellescape(file)), vim.fn.fnamemodify(file, ":t")):gsub("%%", "%%%%")
  vim.fn.jobstart(cmd, {
    term = true,
    cwd = dir,
    on_exit = function(_, code)
      vim.schedule(function()
        if term.win and vim.api.nvim_win_is_valid(term.win) then
          local secs = (vim.uv.now() - started) / 1000
          vim.wo[term.win].winbar = ("%%#%s#  %s %%#Comment# %s · %.1fs · q closes"):format(
            code == 0 and "DiagnosticOk" or "DiagnosticError",
            code == 0 and "done" or ("exit " .. code), shown, secs)
        end
      end)
    end,
  })
  vim.wo[term.win].winbar = "%#DeckFooterKey#  running %#Comment# " .. shown
  vim.wo[term.win].number = false
  vim.wo[term.win].relativenumber = false
  vim.wo[term.win].signcolumn = "no"
  vim.keymap.set("n", "q", function()
    if vim.api.nvim_win_is_valid(term.win) then
      vim.api.nvim_win_close(term.win, true)
    end
  end, { buffer = term.buf, nowait = true, desc = "Close the run output" })
  vim.cmd.stopinsert()
  vim.api.nvim_set_current_win(from)
end

return M
