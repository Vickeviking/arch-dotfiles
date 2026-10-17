-- The X-ray window (xray-window, GTK): the memory map on a second screen.
-- At the first stop of a session it opens by itself when a second monitor is
-- connected, placed there without taking focus. Space dW opens or closes it;
-- Space dX (X-ray off) keeps it from opening.

local M = {}

local job -- the window we started, if any

local function monitor_list()
  if vim.fn.executable("hyprctl") ~= 1 then
    return {}
  end
  local ok, out = pcall(vim.fn.system, { "hyprctl", "monitors", "-j" })
  if not ok or vim.v.shell_error ~= 0 then
    return {}
  end
  local ok2, list = pcall(vim.json.decode, out)
  return (ok2 and type(list) == "table") and list or {}
end

local function monitors()
  return math.max(1, #monitor_list())
end

-- a runtime Hyprland rule (nothing in your config files): the window goes to
-- the monitor nvim isn't on, and doesn't take focus
local function place_on_other_monitor()
  for _, m in ipairs(monitor_list()) do
    if not m.focused then
      local lua = ('hl.window_rule({ name = "xray-window", match = { class = "^dev\\.vango\\.xray$" }, monitor = %q, no_initial_focus = true })'):format(m.name)
      vim.fn.system({ "hyprctl", "eval", lua })
      return true
    end
  end
  return false
end

function M.running()
  return job ~= nil and vim.fn.jobwait({ job }, 0)[1] == -1
end

function M.open(second_screen)
  if vim.fn.executable("xray-window") ~= 1 then
    vim.notify("X-ray window: xray-window isn't installed (cargo install --path crates/xray-window)", vim.log.levels.WARN)
    return
  end
  if M.running() then
    return
  end
  if second_screen then
    place_on_other_monitor()
  end
  job = vim.fn.jobstart({ "xray-window" }, { detach = false })
end

function M.close()
  if M.running() then
    vim.fn.jobstop(job)
  end
  job = nil
end

function M.toggle()
  if M.running() then
    M.dismissed = true
    M.close()
  else
    M.dismissed = false
    M.open(monitors() >= 2)
  end
end

-- the first stop of a session: open on the second screen if there is one
function M.auto()
  if vim.g.xray_window == false or M.dismissed then
    return
  end
  if monitors() >= 2 and not M.running() and vim.fn.system({ "pgrep", "-x", "xray-window" }) == "" then
    M.open(true)
  end
end

vim.api.nvim_create_autocmd("VimLeavePre", {
  callback = function()
    if M.running() then
      vim.fn.jobstop(job)
    end
  end,
})

return M
