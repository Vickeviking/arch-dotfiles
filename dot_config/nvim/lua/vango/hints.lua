-- Context key hints in the statusline: the few keys that matter right now,
-- so nobody has to remember all of them.
--
--   stepping in the debugger   F10 over · F11 into · F12 out · F5 continue · Space dx memory
--   on a borrow error          Space Rw why not? · Space ca fixes · ]d next error
--   on a Rust symbol           K K lens · gd definition · Space dd debug
--   anywhere else              Space r cheat sheet · Space ? every key
--
-- `:Hints` turns it off and on (vim.g.vango_hints).

local M = {}

local function stopped()
  local dap = package.loaded["dap"]
  local s = dap and dap.session()
  if not s then
    return nil
  end
  return s.stopped_thread_id ~= nil
end

local BORROW = { E0382 = true, E0499 = true, E0502 = true, E0505 = true, E0506 = true, E0597 = true, E0716 = true, E0373 = true }

-- the hints for this moment: { {keys, what}, … }
function M.items()
  local dbg = stopped()
  if dbg == true then
    return { { "F10", "over" }, { "F11", "into" }, { "F12", "out" }, { "F5", "continue" }, { "Space dx", "memory" }, { "Space dq", "stop" } }
  elseif dbg == false then
    return { { "", "running…" }, { "Space db", "breakpoint" }, { "Space dq", "stop" } }
  end
  local buf = vim.api.nvim_get_current_buf()
  if vim.bo[buf].buftype ~= "" then
    return {}
  end
  local lnum = vim.api.nvim_win_get_cursor(0)[1] - 1
  local here = vim.diagnostic.get(buf, { lnum = lnum })
  local ft = vim.bo[buf].filetype
  local worst
  for _, d in ipairs(here) do
    if BORROW[d.code] then
      return { { "Space Rw", "why not?" }, { "Space ca", "fixes" }, { "]d", "next error" } }
    end
    worst = (not worst or d.severity < worst) and d.severity or worst
  end
  if worst then
    local out = { { "Space ca", "fixes" }, { "]d", "next" } }
    if ft == "rust" then
      table.insert(out, 2, { "Space Rd", "full message" })
    end
    return out
  end
  if ft == "rust" then
    local word = vim.fn.expand("<cword>")
    local pos = vim.api.nvim_win_get_cursor(0)
    local in_comment = false
    for _, c in ipairs(vim.treesitter.get_captures_at_pos(buf, pos[1] - 1, pos[2])) do
      in_comment = in_comment or c.capture:find("comment") ~= nil
    end
    if word:match("^[%a_][%w_]*$") and not in_comment then
      return { { "K K", "lens" }, { "gd", "definition" }, { "Space dd", "debug" }, { "Space r", "cheat sheet" } }
    end
    return { { "Space Rr", "run" }, { "Space dd", "debug" }, { "Space r", "cheat sheet" } }
  end
  return { { "Space r", "cheat sheet" }, { "Space ?", "every key" } }
end

-- a statusline string: keys in the accent, words dim
function M.statusline()
  if vim.g.vango_hints == false then
    return ""
  end
  local parts = {}
  for _, it in ipairs(M.items()) do
    if it[1] == "" then
      parts[#parts + 1] = "%#VangoHintText#" .. it[2]
    else
      parts[#parts + 1] = "%#VangoHintKey#" .. it[1] .. "%#VangoHintText# " .. it[2]
    end
  end
  return table.concat(parts, "%#VangoHintSep# · ")
end

function M.colors()
  local p = require("vango.deck.theme").palette()
  vim.api.nvim_set_hl(0, "VangoHintKey", { fg = p.accent, bg = p.panel, bold = true })
  vim.api.nvim_set_hl(0, "VangoHintText", { fg = p.muted, bg = p.panel })
  vim.api.nvim_set_hl(0, "VangoHintSep", { fg = p.border, bg = p.panel })
end

function M.setup()
  M.colors()
  vim.api.nvim_create_autocmd("ColorScheme", { callback = M.colors })
  vim.api.nvim_create_user_command("Hints", function()
    vim.g.vango_hints = vim.g.vango_hints == false
    vim.cmd.redrawstatus()
  end, { desc = "Key hints in the statusline on/off" })
end

return M
