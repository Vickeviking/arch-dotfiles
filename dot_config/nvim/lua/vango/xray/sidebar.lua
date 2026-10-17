-- The X-ray sidebar: the memory map in a split on the right while you debug.
-- It opens by itself at the first stop (when the screen is wide enough),
-- follows every step without taking focus, and closes when the session ends.
-- Space dm shows/hides it; Space dX turns all of X-ray off for this nvim.

local map = require("vango.xray.map")

local M = {}

local ns = vim.api.nvim_create_namespace("vango_xray_sidebar")
local buf, win
M.dismissed = false -- closed by hand: stay closed for the rest of the session

local function width()
  return math.max(52, math.min(74, math.floor(vim.o.columns * 0.33)))
end

function M.is_open()
  return win ~= nil and vim.api.nvim_win_is_valid(win)
end

local function ensure_buf()
  if buf and vim.api.nvim_buf_is_valid(buf) then
    return buf
  end
  buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].filetype = "xray"
  pcall(vim.api.nvim_buf_set_name, buf, "X-ray")
  vim.keymap.set("n", "q", function()
    M.dismissed = true
    M.close()
  end, { buffer = buf, nowait = true, desc = "X-ray: close the sidebar" })
  vim.keymap.set("n", "<CR>", function()
    require("vango.xray").toggle_panel()
  end, { buffer = buf, nowait = true, desc = "X-ray: the full panel" })
  return buf
end

function M.open()
  if M.is_open() then
    return
  end
  ensure_buf()
  win = vim.api.nvim_open_win(buf, false, { split = "right", win = -1, width = width() })
  local wo = vim.wo[win]
  wo.number, wo.relativenumber, wo.signcolumn, wo.foldcolumn = false, false, "no", "0"
  wo.wrap, wo.cursorline, wo.list, wo.spell = false, false, false, false
  wo.winfixwidth = true
  wo.statuscolumn = ""
  wo.fillchars = "eob: "
  wo.winhighlight = "Normal:DeckNormal,EndOfBuffer:DeckNormal"
  wo.winbar = "%#XrayHead# 󰈈 X-ray %#XrayFaint# q hide · Enter full view · Space dX off"
end

function M.close()
  if M.is_open() then
    pcall(vim.api.nvim_win_close, win, true)
  end
  win = nil
end

function M.render(g)
  if not M.is_open() or not g then
    return
  end
  local w = vim.api.nvim_win_get_width(win) - 1
  local lines, hls = map.render_compact(g, { width = w })
  table.insert(lines, 1, "")
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for _, h in ipairs(hls) do
    pcall(vim.api.nvim_buf_set_extmark, buf, ns, h[1] + 1, h[2], { end_col = h[3], hl_group = h[4] })
  end
end

-- open it for a new stop if it should be up
function M.auto(g)
  if not M.dismissed and vim.o.columns >= 150 and vim.g.xray_sidebar ~= false then
    M.open()
  end
  M.render(g)
end

function M.toggle(g)
  if M.is_open() then
    M.dismissed = true
    M.close()
  else
    M.dismissed = false
    M.open()
    M.render(g)
  end
end

return M
