-- X-ray in nvim: memory snapshots from xray-dap, shown inline and in a panel.
--
-- xray-dap (between nvim-dap and codelldb) writes $XDG_RUNTIME_DIR/xray/
-- graph.json at every stop. This module watches that file during a debug
-- session and redraws: inline notes on let lines (Space dX toggles) and the
-- X-ray panel (Space dx). While the inline notes are on, dap-view's own
-- virtual text steps aside so the two don't stack up.

local inline = require("vango.xray.inline")
local panel = require("vango.xray.panel")
local theme = require("vango.xray.theme")

local M = {}

local dir = (vim.env.XDG_RUNTIME_DIR or "/tmp") .. "/xray"
local state = {
  graph = nil, -- the latest stop's graph in this session
  inline = true,
  started = math.huge, -- graphs older than the session start are someone else's
  mtime = 0,
  ended = false,
  watcher = nil,
  history = {}, -- every stop's graph this session, oldest first
  view = nil, -- index into history while scrubbing; nil = the live stop
}

local function dap_view_text(on)
  local ok, dv = pcall(require, "dap-view")
  if ok then
    pcall(on and dv.virtual_text_enable or dv.virtual_text_disable)
  end
end

local function redraw()
  if state.inline and state.graph and not state.ended then
    inline.render(state.graph)
    dap_view_text(false)
  else
    inline.clear()
  end
  panel.refresh()
end

local function read_graph()
  local path = dir .. "/graph.json"
  local st = vim.uv.fs_stat(path)
  if not st then
    return
  end
  local mt = st.mtime.sec + st.mtime.nsec / 1e9
  if mt < state.started or mt == state.mtime then
    return
  end
  local f = io.open(path, "r")
  if not f then
    return
  end
  local text = f:read("*a")
  f:close()
  local ok, g = pcall(vim.json.decode, text, { luanil = { object = true, array = true } })
  if ok and type(g) == "table" and g.slots then
    state.mtime, state.graph = mt, g
    local last = state.history[#state.history]
    if not last or last.stop ~= g.stop then
      table.insert(state.history, g)
    end
    state.view = nil -- a new stop: back to live
    redraw()
  end
end

-- many file events per write (tmp + rename): read once they settle
local timer
local function soon(ms)
  if timer then
    timer:stop()
  else
    timer = vim.uv.new_timer()
  end
  timer:start(ms or 30, 0, vim.schedule_wrap(read_graph))
end

local function watch()
  if state.watcher then
    return
  end
  vim.fn.mkdir(dir, "p")
  local w = vim.uv.new_fs_event()
  if not w then
    return
  end
  local ok = w:start(dir, {}, function(err, fname)
    if not err and fname == "graph.json" then
      soon(30)
    end
  end)
  if ok then
    state.watcher = w
  end
end

-- what the panel shows: the live stop, or an earlier one while scrubbing
function M.graph()
  local n = #state.history
  local g = state.view and state.history[state.view] or state.graph
  return g, { ended = state.ended, index = state.view or n, count = n, history = state.history, live = state.view == nil }
end

-- step through the session's stops in the panel (inline notes stay live)
function M.scrub(delta)
  local n = #state.history
  if n == 0 then
    return
  end
  local i = math.max(1, math.min(n, (state.view or n) + delta))
  -- (not `i == n and nil or i`: that can never be nil)
  if i == n then
    state.view = nil
  else
    state.view = i
  end
  panel.refresh()
end

function M.toggle_inline()
  state.inline = not state.inline
  if not state.inline then
    inline.clear()
    dap_view_text(true)
  end
  redraw()
  vim.notify("X-ray inline notes " .. (state.inline and "on" or "off"), vim.log.levels.INFO)
end

function M.toggle_panel()
  panel.toggle()
end

function M.setup()
  theme.apply()
  vim.api.nvim_create_autocmd("ColorScheme", { callback = theme.apply })
  panel.setup(M.graph)

  local ok, dap = pcall(require, "dap")
  if not ok then
    return
  end
  local L = dap.listeners
  L.after.event_initialized["xray"] = function()
    state.started = os.time() - 1
    state.graph, state.mtime, state.ended = nil, 0, false
    state.history, state.view = {}, nil
    watch()
  end
  L.after.event_stopped["xray"] = function()
    -- the file watcher normally brings it; this catches a missed event
    for _, ms in ipairs({ 120, 400, 1200 }) do
      vim.defer_fn(read_graph, ms)
    end
  end
  local function finished()
    state.ended = true
    inline.clear()
    dap_view_text(true)
    panel.refresh()
  end
  L.after.event_terminated["xray"] = finished
  L.after.event_exited["xray"] = finished
  L.after.disconnect["xray"] = finished

  vim.api.nvim_create_user_command("Xray", M.toggle_panel, { desc = "X-ray: memory panel" })
  vim.api.nvim_create_user_command("XrayInline", M.toggle_inline, { desc = "X-ray: inline notes on/off" })
end

-- tests and demos: show a graph without a debug session
function M._show(g)
  state.graph, state.ended, state.started = g, false, 0
  local last = state.history[#state.history]
  if not last or last.stop ~= g.stop then
    table.insert(state.history, g)
  end
  state.view = nil
  redraw()
end

return M
