-- A Watchtower-style panel inside nvim: dimmed backdrop, a framed float with a
-- tab rail on the left and a scrollable content pane on the right.
--
--   local panel = require("vango.deck.ui").new({ title = "Deck", tabs = {...} })
--   panel:toggle()
--
-- A tab is { name = "Keys", lines = function(ctx) return {...} end, ft = "deck" }
-- or { name = "…", file = "/abs/path.md" }. Content buffers are kept between
-- opens, so hiding and showing is instant and remembers where you were.
--
-- The deck (Space r) uses it today; the Rust lens and the debugger views reuse it.

local theme = require("vango.deck.theme")
local keys = require("vango.deck.keys")

local Panel = {}
Panel.__index = Panel

local ns = vim.api.nvim_create_namespace("vango_panel")
local RAIL_W = 26

local M = {}

function M.new(opts)
  local self = setmetatable({}, Panel)
  self.title = opts.title or "Panel"
  self.icon = opts.icon or "󰘦"
  self.tabs = opts.tabs or {}
  self.on_search = opts.on_search -- function(panel) for `/` in the rail
  self.help_lines = opts.help_lines
  self.cur = 1
  self.focus = "rail"
  self.g_armed = false
  self.cursors = {} -- tab index -> {row, col}
  self.bufs = {} -- tab index -> bufnr
  self.mtimes = {} -- tab index -> file mtime when loaded
  self.wins = {}
  self.augroup = vim.api.nvim_create_augroup("vango_panel_" .. self.title, { clear = true })
  theme.apply()
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = self.augroup,
    callback = function()
      theme.apply()
      if self:is_open() then
        self:render_rail()
      end
    end,
  })
  vim.api.nvim_create_autocmd("VimResized", {
    group = self.augroup,
    callback = function()
      if self:is_open() then
        self:hide()
        self:show()
      end
    end,
  })
  return self
end

-- state -------------------------------------------------------------------

function Panel:is_open()
  return self.wins.frame ~= nil and vim.api.nvim_win_is_valid(self.wins.frame)
end

function Panel:owns(win)
  for _, w in pairs(self.wins) do
    if w == win then
      return true
    end
  end
  return self.help_win == win
end

-- buffers -----------------------------------------------------------------

local function scratch(ft)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].swapfile = false
  if ft then
    vim.bo[buf].filetype = ft
  end
  return buf
end

local function set_lines(buf, lines)
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].modified = false
end

local function file_lines(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then
    return { "# Missing", "", "Could not read `" .. path .. "`." }
  end
  return lines
end

-- Reflow prose to the pane width so the window can run with nowrap: tables
-- and code keep their shape (wide ones scroll sideways with zl / zh instead
-- of breaking apart), paragraphs and list items wrap with a hanging indent.
local function reflow(lines, width)
  if not width or width < 30 then
    return lines
  end
  -- first join each paragraph's source lines (markdown treats them as one)
  local joined, fence, para = {}, false, false
  for _, l in ipairs(lines) do
    local is_fence = l:match("^%s*```") ~= nil
    local block = is_fence or l:match("^%s*|") or l:match("^#") or l:match("^%s*$")
    local starts_item = l:match("^%s*[-*+] ") or l:match("^%s*%d+%. ") or l:match("^>")
    if is_fence then
      fence = not fence
    end
    if not fence and not is_fence and not block and not starts_item and para then
      joined[#joined] = joined[#joined] .. " " .. vim.trim(l)
    else
      table.insert(joined, l)
    end
    -- a paragraph or list item continues on the next plain line
    para = not fence and not is_fence and not block
  end

  local out = {}
  fence = false
  for _, l in ipairs(joined) do
    if l:match("^%s*```") then
      fence = not fence
      table.insert(out, l)
    elseif fence or l:match("^%s*|") or l:match("^#") or vim.fn.strdisplaywidth(l) <= width then
      table.insert(out, l)
    else
      local prefix = l:match("^> ") or l:match("^%s*[-*+] ") or l:match("^%s*%d+%. ") or l:match("^%s*")
      local cont = prefix == "> " and "> " or string.rep(" ", #prefix)
      local cur = prefix
      local fresh = true
      for word in l:sub(#prefix + 1):gmatch("%S+") do
        if not fresh and vim.fn.strdisplaywidth(cur .. " " .. word) > width then
          table.insert(out, cur)
          cur, fresh = cont .. word, false
        else
          cur = fresh and (cur .. word) or (cur .. " " .. word)
          fresh = false
        end
      end
      table.insert(out, cur)
    end
  end
  return out
end
M.reflow = reflow

-- (Re)fill a tab's buffer: generated tabs on every show, file tabs when the
-- file changed on disk (edit a deck/*.md and the next open shows it) or the
-- pane width changed.
function Panel:fill(i, ctx)
  local tab = self.tabs[i]
  local buf = self.bufs[i]
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    buf = scratch(tab.ft or "deck")
    -- markdown highlighting (and ```rust injections) for the deck filetype
    pcall(vim.treesitter.start, buf, "markdown")
    self.bufs[i] = buf
    self.mtimes[i] = nil
    self:map_content(buf)
  end
  if tab.lines then
    set_lines(buf, reflow(tab.lines(ctx), self.width))
  elseif tab.file then
    local stamp = vim.fn.getftime(tab.file) .. ":" .. tostring(self.width)
    if self.mtimes[i] ~= stamp then
      set_lines(buf, reflow(file_lines(tab.file), self.width))
      self.mtimes[i] = stamp
    end
  end
  return buf
end

-- every tab's lines, for searching across the whole panel
function Panel:all_lines(ctx)
  local out = {}
  for i, tab in ipairs(self.tabs) do
    local lines = tab.lines and tab.lines(ctx) or (tab.file and file_lines(tab.file)) or {}
    out[i] = reflow(lines, self.width) -- same line numbers as the buffers, so jumps land right
  end
  return out
end

-- geometry ----------------------------------------------------------------

function Panel:geometry()
  local cols, rows = vim.o.columns, vim.o.lines - vim.o.cmdheight - 1
  local w = math.min(math.max(math.floor(cols * 0.88), 60), 160)
  local h = math.min(math.max(math.floor(rows * 0.86), 16), 52)
  w = math.min(w, cols - 2)
  h = math.min(h, rows - 2)
  return {
    row = math.floor((rows - h) / 2),
    col = math.floor((cols - w) / 2),
    w = w,
    h = h,
  }
end

function Panel:footer()
  local k, t = "DeckFooterKey", "DeckFooter"
  if self.focus == "rail" then
    return {
      { " j/k ", k }, { "tab  ", t }, { "l ", k }, { "read  ", t }, { "/ ", k }, { "search all  ", t },
      { "? ", k }, { "keys  ", t }, { "q ", k }, { "close ", t },
    }
  end
  return {
    { " j/k ", k }, { "scroll  ", t }, { "C-h ", k }, { "tabs  ", t }, { "J/K ", k }, { "next/prev tab  ", t },
    { "/ ", k }, { "find in tab  ", t }, { "q ", k }, { "close ", t },
  }
end

-- windows -----------------------------------------------------------------

function Panel:show(opts)
  opts = opts or {}
  if self:is_open() then
    return
  end
  local origin = vim.api.nvim_get_current_buf()
  if not self:owns(vim.api.nvim_get_current_win()) then
    self.origin_buf = origin
    self.origin_win = vim.api.nvim_get_current_win()
  end
  if opts.tab then
    self.cur = opts.tab
  end
  self.focus = opts.focus or self.focus
  local g = self:geometry()
  local ctx = { origin_buf = self.origin_buf }

  -- backdrop: dims the editor behind the panel
  self.backdrop_buf = self.backdrop_buf and vim.api.nvim_buf_is_valid(self.backdrop_buf) and self.backdrop_buf
    or scratch()
  self.wins.backdrop = vim.api.nvim_open_win(self.backdrop_buf, false, {
    relative = "editor", row = 0, col = 0, width = vim.o.columns, height = vim.o.lines,
    style = "minimal", focusable = false, zindex = 58, border = "none",
  })
  vim.wo[self.wins.backdrop].winhighlight = "Normal:DeckBackdrop"
  vim.wo[self.wins.backdrop].winblend = 35

  -- frame: border, title and the key hints in the footer
  self.frame_buf = self.frame_buf and vim.api.nvim_buf_is_valid(self.frame_buf) and self.frame_buf or scratch()
  self.wins.frame = vim.api.nvim_open_win(self.frame_buf, false, {
    relative = "editor", row = g.row, col = g.col, width = g.w, height = g.h,
    style = "minimal", focusable = false, zindex = 60, border = "rounded",
    title = { { " " .. self.icon .. " " .. self.title .. " ", "DeckTitle" } }, title_pos = "left",
    footer = self:footer(), footer_pos = "right",
  })
  vim.wo[self.wins.frame].winhighlight = theme.frame_winhl

  -- rail: tab list with a separator on its right edge
  self.rail_buf = self.rail_buf and vim.api.nvim_buf_is_valid(self.rail_buf) and self.rail_buf or scratch()
  if not self.rail_mapped then
    self:map_rail(self.rail_buf)
    self.rail_mapped = true
  end
  self.wins.rail = vim.api.nvim_open_win(self.rail_buf, false, {
    relative = "editor", row = g.row + 1, col = g.col + 1, width = RAIL_W, height = g.h,
    style = "minimal", zindex = 61, border = { "", "", "", "│", "", "", "", "" },
  })
  vim.wo[self.wins.rail].winhighlight = theme.rail_winhl
  vim.wo[self.wins.rail].cursorline = false
  vim.wo[self.wins.rail].wrap = false

  -- content
  local cw = g.w - RAIL_W - 4
  self.width = cw - 2
  local buf = self:fill(self.cur, ctx)
  self.wins.content = vim.api.nvim_open_win(buf, false, {
    relative = "editor", row = g.row + 1, col = g.col + RAIL_W + 4, width = cw, height = g.h,
    style = "minimal", zindex = 61, border = "none",
  })
  self:content_opts(self.wins.content)
  self:restore_cursor()
  self:render_rail()

  -- leaving the panel for another window hides it
  vim.api.nvim_create_autocmd("WinEnter", {
    group = self.augroup,
    callback = function()
      vim.schedule(function()
        if self:is_open() and not self:owns(vim.api.nvim_get_current_win()) then
          self:hide()
        end
      end)
    end,
  })

  self:focus_to(self.focus)
end

function Panel:content_opts(win)
  local wo = vim.wo[win]
  wo.winhighlight = theme.content_winhl
  wo.wrap = false -- prose is reflowed by fill(); tables must never soft-wrap
  wo.sidescrolloff = 4
  wo.cursorline = true
  wo.number = false
  wo.relativenumber = false
  wo.signcolumn = "no"
  wo.foldenable = false
  wo.scrolloff = 4
  wo.conceallevel = 3
  wo.concealcursor = "nvc"
  wo.list = false
  wo.spell = false
end

function Panel:save_cursor()
  local w = self.wins.content
  if w and vim.api.nvim_win_is_valid(w) then
    self.cursors[self.cur] = vim.api.nvim_win_get_cursor(w)
  end
end

function Panel:restore_cursor()
  local w = self.wins.content
  local pos = self.cursors[self.cur] or { 1, 0 }
  local n = vim.api.nvim_buf_line_count(vim.api.nvim_win_get_buf(w))
  pcall(vim.api.nvim_win_set_cursor, w, { math.min(pos[1], n), pos[2] })
end

function Panel:hide()
  if not self:is_open() then
    return
  end
  self:save_cursor()
  self:close_help()
  vim.api.nvim_clear_autocmds({ group = self.augroup, event = "WinEnter" })
  for name, w in pairs(self.wins) do
    if vim.api.nvim_win_is_valid(w) then
      vim.api.nvim_win_close(w, true)
    end
    self.wins[name] = nil
  end
  if self.origin_win and vim.api.nvim_win_is_valid(self.origin_win) then
    vim.api.nvim_set_current_win(self.origin_win)
  end
end

function Panel:toggle(opts)
  if self:is_open() then
    self:hide()
  else
    self:show(opts)
  end
end

function Panel:focus_to(which)
  self.focus = which
  local w = which == "content" and self.wins.content or self.wins.rail
  if w and vim.api.nvim_win_is_valid(w) then
    vim.api.nvim_set_current_win(w)
  end
  if self:is_open() then
    vim.api.nvim_win_set_config(self.wins.frame, { footer = self:footer(), footer_pos = "right" })
    self:render_rail()
  end
end

-- tabs --------------------------------------------------------------------

function Panel:select(i)
  if i == self.cur and self.bufs[i] then
    return
  end
  self:save_cursor()
  self.cur = i
  local buf = self:fill(i, { origin_buf = self.origin_buf })
  vim.api.nvim_win_set_buf(self.wins.content, buf)
  self:content_opts(self.wins.content)
  self:restore_cursor()
  self:render_rail()
end

-- select a tab and put the content cursor on a line (used by search)
function Panel:jump(i, line)
  if not self:is_open() then
    self:show({ tab = i, focus = "content" })
  end
  self:select(i)
  pcall(vim.api.nvim_win_set_cursor, self.wins.content, { line, 0 })
  vim.api.nvim_win_call(self.wins.content, function()
    vim.cmd("normal! zz")
  end)
  self:focus_to("content")
end

function Panel:render_rail()
  local buf = self.rail_buf
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    return
  end
  local lines = { "", "  " .. self.title:upper(), "" }
  local first = #lines
  for i, tab in ipairs(self.tabs) do
    local num = i <= 9 and tostring(i) or (i == 10 and "0" or " ")
    table.insert(lines, ("   %s  %s"):format(num, tab.name))
  end
  local p = theme.palette()
  if p.name then
    local h = self.wins.rail and vim.api.nvim_win_is_valid(self.wins.rail) and vim.api.nvim_win_get_height(self.wins.rail)
      or #lines + 2
    while #lines < h - 1 do
      table.insert(lines, "")
    end
    table.insert(lines, "  󰏘 " .. p.name)
  end
  set_lines(buf, lines)
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  vim.api.nvim_buf_set_extmark(buf, ns, 1, 0, { end_col = #lines[2], hl_group = "DeckRailHead" })
  for i = 1, #self.tabs do
    local row = first + i - 1
    if i == self.cur then
      vim.api.nvim_buf_set_extmark(buf, ns, row, 0, { line_hl_group = "DeckRailSel" })
      vim.api.nvim_buf_set_extmark(buf, ns, row, 0, {
        virt_text = { { self.focus == "rail" and "▌" or "▏", "DeckRailStripe" } }, virt_text_pos = "overlay",
      })
      vim.api.nvim_buf_set_extmark(buf, ns, row, 3, { end_col = 4, hl_group = "DeckRailSelNum" })
    else
      vim.api.nvim_buf_set_extmark(buf, ns, row, 3, { end_col = 4, hl_group = "DeckRailNum" })
    end
  end
  if p.name then
    vim.api.nvim_buf_set_extmark(buf, ns, #lines - 1, 0, { end_col = #lines[#lines], hl_group = "DeckRailNum" })
  end
  if self.wins.rail and vim.api.nvim_win_is_valid(self.wins.rail) then
    pcall(vim.api.nvim_win_set_cursor, self.wins.rail, { first + self.cur, 0 })
  end
end

-- help --------------------------------------------------------------------

function Panel:close_help()
  if self.help_win and vim.api.nvim_win_is_valid(self.help_win) then
    vim.api.nvim_win_close(self.help_win, true)
  end
  self.help_win = nil
end

function Panel:toggle_help()
  if self.help_win then
    self:close_help()
    self:focus_to(self.focus)
    return
  end
  local lines = self.help_lines or {}
  local w = 0
  for _, l in ipairs(lines) do
    w = math.max(w, vim.fn.strdisplaywidth(l))
  end
  local buf = scratch()
  set_lines(buf, lines)
  local g = self:geometry()
  self.help_win = vim.api.nvim_open_win(buf, true, {
    relative = "editor", row = g.row + math.floor((g.h - #lines) / 2), col = g.col + math.floor((g.w - w - 4) / 2),
    width = w + 2, height = #lines, style = "minimal", zindex = 70, border = "rounded",
    title = { { " keys ", "DeckTitle" } }, title_pos = "center",
  })
  vim.wo[self.help_win].winhighlight = theme.frame_winhl
  -- "  keys    what" lines get the keys colored; other non-empty lines are headings
  for i, l in ipairs(lines) do
    if l:match("^  %S") then
      local ke = l:find("%s%s", 3)
      if ke then
        vim.api.nvim_buf_set_extmark(buf, ns, i - 1, 2, { end_col = ke - 1, hl_group = "DeckFooterKey" })
      end
    elseif l ~= "" then
      vim.api.nvim_buf_set_extmark(buf, ns, i - 1, 0, { end_col = #l, hl_group = "DeckRailHead" })
    end
  end
  for _, k in ipairs({ "q", "?", "<Esc>" }) do
    vim.keymap.set("n", k, function()
      self:toggle_help()
    end, { buffer = buf, nowait = true, silent = true })
  end
end

-- key maps ----------------------------------------------------------------

function Panel:rail_key(key)
  local act = keys.action(key, self.cur, #self.tabs, self.g_armed)
  self.g_armed = act.kind == "arm_g"
  if act.kind == "select" then
    self:select(act.index)
  elseif act.kind == "enter" then
    self:focus_to("content")
  elseif act.kind == "close" then
    self:hide()
  elseif act.kind == "help" then
    self:toggle_help()
  elseif act.kind == "search" and self.on_search then
    self.on_search(self)
  end
end

function Panel:map_rail(buf)
  for _, k in ipairs(keys.rail_keys) do
    vim.keymap.set("n", k, function()
      self:rail_key(k)
    end, { buffer = buf, nowait = true, silent = true, desc = "Deck: " .. k })
  end
  -- the rail is read-only and has no cursor to move: swallow h so it doesn't wander
  vim.keymap.set("n", "h", "<Nop>", { buffer = buf, nowait = true })
end

function Panel:map_content(buf)
  local o = { buffer = buf, nowait = true, silent = true }
  vim.keymap.set("n", "<C-h>", function()
    self:focus_to("rail")
  end, vim.tbl_extend("force", o, { desc = "Deck: back to tabs" }))
  vim.keymap.set("n", "<C-l>", "<Nop>", o)
  vim.keymap.set("n", "J", function()
    self:select(self.cur % #self.tabs + 1)
  end, vim.tbl_extend("force", o, { desc = "Deck: next tab" }))
  vim.keymap.set("n", "K", function()
    self:select((self.cur - 2) % #self.tabs + 1)
  end, vim.tbl_extend("force", o, { desc = "Deck: previous tab" }))
  for _, k in ipairs({ "q", "<Esc>" }) do
    vim.keymap.set("n", k, function()
      self:hide()
    end, vim.tbl_extend("force", o, { desc = "Deck: close" }))
  end
  vim.keymap.set("n", "?", function()
    self:toggle_help()
  end, vim.tbl_extend("force", o, { desc = "Deck: keys" }))
end

return M
