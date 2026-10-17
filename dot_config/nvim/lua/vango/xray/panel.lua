-- The X-ray panel (Space dx): the deck's panel with four tabs.
--   Memory   the memory map: stack cards, heap boxes, arrows
--   Frames   every thread and frame, your code bright and std dim
--   Heap     each block: address, size, contents, who points at it
--   Changes  what this step did, and why it matters
-- It follows the debugger: every stop refreshes the open tab.

local map = require("vango.xray.map")
local source = require("vango.xray.source")
local theme = require("vango.xray.theme")

local M = {}

local panel
local get = function() end -- set by init: returns graph, info

-- a small builder: rows of segments → lines, highlights, targets
local function builder()
  local b = { lines = {}, hls = {}, targets = {} }
  function b.add(segs, target)
    local row = #b.lines
    local parts, byte = {}, 0
    for _, s in ipairs(segs or {}) do
      local text = s[1] or ""
      if s[2] and #text > 0 then
        b.hls[#b.hls + 1] = { row, byte, byte + #text, s[2] }
      end
      parts[#parts + 1] = text
      byte = byte + #text
    end
    b.lines[#b.lines + 1] = table.concat(parts)
    if target then
      b.targets[row] = target
    end
  end
  function b.blank()
    b.add({})
  end
  function b.done()
    return b.lines, { hls = b.hls, targets = b.targets }
  end
  return b
end

local function loc(file, row)
  if not file then
    return nil
  end
  return { uri = vim.uri_from_fname(file), range = { start = { line = row, character = 0 }, ["end"] = { line = row, character = 0 } } }
end

local function short(p)
  return p and p:match("[^/]+$") or "?"
end

local function empty(b, info)
  b.add({ { "X-ray shows your program's memory while you debug Rust.", "XrayName" } })
  b.blank()
  if info and info.ended then
    b.add({ { "The debug session ended. Start another one to see memory again.", "XrayDim" } })
    b.blank()
  end
  b.add({ { "  1  ", "XrayLabel" }, { "  set a breakpoint      ", "XrayValue" }, { "Space db", "DeckKbd" } })
  b.add({ { "  2  ", "XrayLabel" }, { "  start debugging       ", "XrayValue" }, { "Space dd", "DeckKbd" }, { "  (pick a target)", "XrayDim" } })
  b.add({ { "  3  ", "XrayLabel" }, { "  step                  ", "XrayValue" }, { "Space dn / di / do", "DeckKbd" } })
  b.blank()
  b.add({ { "Every stop fills this view in. Each let line also gets a short note", "XrayDim" } })
  b.add({ { "about what it holds and where it points (", "XrayDim" }, { "Space dX", "DeckKbd" }, { " turns those off).", "XrayDim" } })
  b.blank()
  b.add(map.legend())
end

-- where the stopped frame's locals are declared, for jumps and moved-from marks
local function frame_info(g)
  local cards = map.frames(g)
  local out = { decls = {}, moved = {}, file = {} }
  for _, c in ipairs(cards) do
    local buf = source.buf_for(c.frame.file)
    if buf then
      local d = source.decls(buf, c.frame.line)
      for _, id in ipairs(c.frame.slots) do
        local s = g.slots[id + 1]
        out.decls[s.id] = d[s.name]
        out.file[s.id] = c.frame.file
      end
      for id, into in pairs(source.moved(g, buf, d)) do
        out.moved[id] = into
      end
    end
  end
  return out
end

-- Memory --------------------------------------------------------------------

local function tab_memory()
  local g, info = get()
  local b = builder()
  if not g then
    empty(b, info)
    return b.done()
  end
  local fi = frame_info(g)
  if info and info.count and info.count > 1 then
    -- the session's stops: [ / ] steps through them, the current one boxed
    local segs = { { "TIMELINE  ", "XrayHead" } }
    local first = math.max(1, info.index - 12)
    if first > 1 then
      segs[#segs + 1] = { "… ", "XrayFaint" }
    end
    for i = first, math.min(info.count, first + 24) do
      local h = info.history[i]
      local hot = false
      for _, n in ipairs(h.notes or {}) do
        hot = hot or n.kind == "realloc"
      end
      local label = tostring(h.stop)
      if i == info.index then
        segs[#segs + 1] = { " " .. label .. " ", "XrayLabel" }
      else
        segs[#segs + 1] = { " " .. label .. " ", hot and "XrayWarn" or "XrayDim" }
      end
    end
    segs[#segs + 1] = { info.live and "   live" or "   looking back", info.live and "XrayOk" or "XrayWarn" }
    segs[#segs + 1] = { "   [ ] step through stops", "XrayFaint" }
    b.add(segs)
    b.blank()
  end
  b.add(map.legend())
  b.blank()
  local lines, hls, rows = map.render(g, { width = panel.width or 110, moved = fi.moved })
  local base = #b.lines
  for i, l in ipairs(lines) do
    local r = rows[i - 1]
    local target
    if r and r.slot and fi.decls[r.slot] then
      target = loc(fi.file[r.slot], fi.decls[r.slot])
    elseif r and r.frame then
      target = loc(r.frame.file, math.max(r.frame.line - 1, 0))
    end
    b.lines[#b.lines + 1] = l
    if target then
      b.targets[base + i - 1] = target
    end
  end
  for _, h in ipairs(hls) do
    b.hls[#b.hls + 1] = { h[1] + base, h[2], h[3], h[4] }
  end
  return b.done()
end

-- Frames --------------------------------------------------------------------

local WAITS = {
  { "futex_wait", "waiting on a lock or condvar" },
  { "Condvar", "waiting on a condvar" },
  { "Mutex", "waiting for a Mutex" },
  { "park", "parked" },
  { "sleep", "sleeping" },
  { "join", "joining a thread" },
  { "read", "blocked in read" },
}

local function waiting(t)
  for _, f in ipairs(t.frames) do
    for _, w in ipairs(WAITS) do
      if f.full:find(w[1], 1, true) then
        return w[2]
      end
    end
  end
end

local function slot_line(g, s, indent)
  local segs = { { indent, nil }, { map.pad(s.name, 10) .. " ", "XrayName" }, { map.pad(s.ty, 22) .. " ", "XrayType" } }
  local changed = s.change and s.change.kind == "changed"
  segs[#segs + 1] = { map.clip(s.summary, 36), changed and "XrayChanged" or "XrayValue" }
  for i, e in ipairs(s.edges or {}) do
    if i > 2 then
      break
    end
    local edge = g.edges[e + 1]
    segs[#segs + 1] = { "  " .. theme.ARROW[edge.kind] .. " " .. map.name_of(g, edge, edge.kind == "owns" or edge.kind == "shared"), theme.KIND_HL[edge.kind] }
  end
  return segs
end

local function tab_frames()
  local g, info = get()
  local b = builder()
  if not g then
    empty(b, info)
    return b.done()
  end
  local fi = frame_info(g)
  b.add({ { "THREADS", "XrayHead" }, { "  " .. #g.threads .. " · stop " .. g.stop .. " · " .. g.reason, "XrayDim" } })
  b.blank()
  for _, t in ipairs(g.threads) do
    local head = { { t.stopped and "● " or "○ ", t.stopped and "XrayChanged" or "XrayDim" }, { t.name, "XrayName" } }
    if t.stopped then
      head[#head + 1] = { "  stopped here", "XrayChanged" }
    else
      local w = waiting(t)
      head[#head + 1] = { "  " .. (w or "running elsewhere"), "XrayWarn" }
    end
    b.add(head)
    local lib_run = 0
    local function flush()
      if lib_run > 0 then
        b.add({ { "      ┆ " .. lib_run .. " frame" .. (lib_run == 1 and "" or "s") .. " in std / dependencies", "XrayFaint" } })
        lib_run = 0
      end
    end
    for i, f in ipairs(t.frames) do
      local show = f.user or i == 1
      if show then
        flush()
        local target = loc(f.file, math.max(f.line - 1, 0))
        b.add({
          { "    ▸ ", f.user and "XrayCardTitle" or "XrayDim" },
          { map.pad(f.name, 34) .. " ", f.user and "XrayName" or "XrayDim" },
          { short(f.file) .. ":" .. f.line, "XrayDim" },
        }, target)
        for _, id in ipairs(f.slots or {}) do
          local s = g.slots[id + 1]
          local d = fi.decls[s.id]
          b.add(slot_line(g, s, "        "), d and loc(fi.file[s.id], d) or target)
        end
      else
        lib_run = lib_run + 1
      end
    end
    flush()
    b.blank()
  end
  return b.done()
end

-- Heap ----------------------------------------------------------------------

function M._tab_heap()
  local g, info = get()
  local b = builder()
  if not g then
    empty(b, info)
    return b.done()
  end
  local _, _, _, labels = map.render(g, { width = panel.width or 110 })
  local new, heap = 0, 0
  for _, bl in ipairs(g.blocks) do
    if bl.place.kind ~= "static" then
      heap = heap + 1
      if bl.change and (bl.change.kind == "new" or bl.change.kind == "realloc") then
        new = new + 1
      end
    end
  end
  b.add({ { "HEAP", "XrayHead" }, { "  " .. heap .. " blocks · " .. new .. " new · " .. #(g.freed or {}) .. " freed since the last stop", "XrayDim" } })
  b.blank()
  local order = {}
  for _, bl in ipairs(g.blocks) do
    order[#order + 1] = bl
  end
  table.sort(order, function(x, y)
    local lx, ly = labels[x.id] or "~", labels[y.id] or "~"
    return lx < ly or (lx == ly and x.id < y.id)
  end)
  for _, bl in ipairs(order) do
    local label = labels[bl.id]
    local place = bl.place.kind == "stack" and "stack" or bl.place.kind
    local head = {
      { label and (" " .. label .. " ") or " · ", label and "XrayLabel" or "XrayDim" },
      { "  " .. bl.ty, "XrayType" },
      { bl.size and ("  " .. bl.size .. " B") or "", "XrayDim" },
      { string.format("  %s 0x%x", place, bl.addr), "XrayFaint" },
    }
    local badge = bl.change and ({ new = " new ", realloc = " moved ", changed = " changed " })[bl.change.kind]
    if badge then
      head[#head + 1] = { "  ", nil }
      head[#head + 1] = { badge, bl.change.kind == "new" and "XrayBadgeNew" or (bl.change.kind == "realloc" and "XrayBadgeMoved" or "XrayBadgeChanged") }
    end
    b.add(head)
    local facts = {}
    if bl.len then
      facts[#facts + 1] = { "len " .. bl.len .. (bl.cap and (" · cap " .. bl.cap) or ""), "XrayDim" }
    end
    for _, f in ipairs(bl.facts or {}) do
      facts[#facts + 1] = { (#facts > 0 and " · " or "") .. f.key .. " " .. f.value, theme.TONE_HL[f.tone] or "XrayDim" }
    end
    if #facts > 0 then
      table.insert(facts, 1, { "     ", nil })
      b.add(facts)
    end
    if bl.change and bl.change.kind == "realloc" then
      b.add({ { "     moved here from ", "XrayDim" }, { string.format("0x%x", bl.change.from), "XrayWarn" }, { ": the old buffer was freed", "XrayDim" } })
    end
    local items = {}
    for i, it in ipairs(bl.items or {}) do
      if i > 8 then
        items[#items + 1] = { "  …", "XrayDim" }
        break
      end
      items[#items + 1] = { "  " .. it.name .. " ", "XrayDim" }
      items[#items + 1] = { map.clip(it.value, 18), "XrayValue" }
    end
    if #items > 0 then
      table.insert(items, 1, { "   ", nil })
      b.add(items)
    end
    local inc = { { "     ← ", "XrayDim" } }
    for i, e in ipairs(bl.incoming or {}) do
      local edge = g.edges[e + 1]
      local from = edge.from.node == "slot" and (g.slots[edge.from.id + 1].name .. (edge.from.path or "")) or (map.describe(g, edge.from, labels))
      local into = (edge.to.path or "") ~= "" and (" " .. edge.to.path) or ""
      inc[#inc + 1] = { (i > 1 and " · " or "") .. from .. " " .. theme.WORD[edge.kind] .. into, theme.KIND_HL[edge.kind] }
    end
    if #inc > 1 then
      b.add(inc)
    end
    b.blank()
  end
  if #(g.freed or {}) > 0 then
    b.add({ { "FREED SINCE THE LAST STOP", "XrayAlert" } })
    for _, bl in ipairs(g.freed) do
      b.add({ { "  ✕ ", "XrayAlert" }, { bl.ty .. "  ", "XrayType" }, { map.clip(bl.summary, 40), "XrayFaint" } })
    end
  end
  return b.done()
end

-- Changes -------------------------------------------------------------------

local WHY = {
  realloc = "A Vec that runs out of capacity moves to a bigger buffer and frees the old one. A reference into the old buffer would dangle, which is why the borrow checker won't let you keep `&v[i]` across `v.push(…)`.",
  ["two-owners"] = "After a move both names still hold the same bits, but only the new owner counts: the old one is never used or dropped again, so the buffer is freed exactly once.",
}

local function insights(g)
  local out = {}
  for _, bl in ipairs(g.blocks) do
    for _, f in ipairs(bl.facts or {}) do
      if f.key == "borrow" and f.value == "borrowed mut" then
        out[#out + 1] = { "RefCell is borrowed mutably right now", "Any other borrow() or borrow_mut() on it panics with BorrowError until the RefMut is dropped. The borrow checker's rules, checked at run time." }
      elseif f.key == "borrow" and f.value:match("shared borrow") then
        out[#out + 1] = { "RefCell has " .. f.value, "More borrow() calls are fine; a borrow_mut() now would panic." }
      elseif f.key == "lock" and f.value:match("waiting") then
        out[#out + 1] = { "A Mutex is held and other threads wait for it", "They're parked in the kernel (futex) until the guard is dropped. Hold locks briefly." }
      elseif f.key == "strong" and tonumber(f.value) and tonumber(f.value) > 1 then
        out[#out + 1] = { (bl.ty:match("^%w+Inner<(.*)>$") or bl.ty) .. " has " .. f.value .. " strong owners", "It's dropped when the last one goes. Weak pointers don't keep it alive." }
      end
    end
  end
  return out
end

function M._tab_changes()
  local g, info = get()
  local b = builder()
  if not g then
    empty(b, info)
    return b.done()
  end
  local fi = frame_info(g)
  local w = math.max(40, (panel.width or 100) - 6)
  b.add({ { "CHANGES", "XrayHead" }, { "  stop " .. g.stop .. " · " .. g.reason, "XrayDim" } })
  b.blank()
  local any = false
  for _, n in ipairs(g.notes or {}) do
    any = true
    local icon = n.kind == "realloc" and "⚠ " or "↷ "
    local hl = n.kind == "realloc" and "XrayWarn" or "XrayAlert"
    for i, part in ipairs(map.wrap(n.text:gsub("`", ""), w)) do
      b.add({ { i == 1 and icon or "  ", hl }, { part, hl } })
    end
    if WHY[n.kind] then
      for _, part in ipairs(map.wrap(WHY[n.kind], w - 2)) do
        b.add({ { "    ", nil }, { part, "XrayDim" } })
      end
    end
    b.blank()
  end
  for id, into in pairs(fi.moved) do
    any = true
    b.add({ { "↷ ", "XrayAlert" }, { g.slots[id + 1].name, "XrayMoved" }, { " was moved into " .. into, "XrayDim" } })
  end
  local changed, new = {}, {}
  for _, s in ipairs(g.slots) do
    if s.change and s.change.kind == "changed" then
      changed[#changed + 1] = s
    elseif s.change and s.change.kind == "new" then
      new[#new + 1] = s
    end
  end
  if #changed > 0 then
    any = true
    b.add({ { "VALUES", "XrayHead" } })
    for _, s in ipairs(changed) do
      local d = fi.decls[s.id]
      b.add({ { "  ✱ ", "XrayChanged" }, { map.pad(s.name, 10) .. " ", "XrayName" }, { map.clip(s.change.before, 30), "XrayFaint" }, { "  →  ", "XrayDim" }, { map.clip(s.summary, 36), "XrayChanged" } }, d and loc(fi.file[s.id], d))
    end
    b.blank()
  end
  if #new > 0 then
    any = true
    local names = {}
    for _, s in ipairs(new) do
      names[#names + 1] = s.name
    end
    b.add({ { "  + ", "XrayChanged" }, { "new in scope: ", "XrayDim" }, { map.clip(table.concat(names, ", "), w - 16), "XrayName" } })
    b.blank()
  end
  local nb, fb = 0, #(g.freed or {})
  for _, bl in ipairs(g.blocks) do
    if bl.change and (bl.change.kind == "new" or bl.change.kind == "realloc") and bl.place.kind ~= "static" then
      nb = nb + 1
    end
  end
  if nb + fb > 0 then
    any = true
    b.add({ { "HEAP", "XrayHead" }, { "  " .. nb .. " allocated · " .. fb .. " freed", "XrayDim" } })
    b.blank()
  end
  local ins = insights(g)
  if #ins > 0 then
    b.add({ { "RIGHT NOW", "XrayHead" } })
    for _, it in ipairs(ins) do
      b.add({ { "  • ", "XrayCardTitle" }, { it[1], "XrayName" } })
      for _, part in ipairs(map.wrap(it[2], w - 4)) do
        b.add({ { "    ", nil }, { part, "XrayDim" } })
      end
    end
    any = true
  end
  if not any then
    b.add({ { "Nothing changed since the last stop.", "XrayDim" } })
  end
  return b.done()
end

-- the panel -------------------------------------------------------------------

local HELP = {
  "X-ray: your program's memory at this stop",
  "",
  "  j/k        tabs (in the rail) or scroll (in the content)",
  "  C-l / C-h  into the content / back to the rail",
  "  Enter      jump to the declaration, frame or line",
  "  [ / ]      step back / forward through this session's stops",
  "  Space dx   close",
  "",
  "  ─▶ owns   ═▶ shares (Rc/Arc)   ┄▶ weak   ─▷ borrows   ━▶ borrows mut",
  "  ✱ changed since the last stop   + new   ↷ moved from   ░ spare capacity",
  "",
  "Borrows don't exist at run time: references are plain pointers. X-ray",
  "shows who points where; why the compiler says no is Space Rw (soon).",
}

local function tabs()
  return {
    { name = "Memory", lines = tab_memory, raw = true, ft = "xray" },
    { name = "Frames", lines = tab_frames, raw = true, ft = "xray" },
    { name = "Heap", lines = M._tab_heap, raw = true, ft = "xray" },
    { name = "Changes", lines = M._tab_changes, raw = true, ft = "xray" },
  }
end

local function title()
  local g, info = get()
  if not g then
    return "X-ray"
  end
  local where = (info and not info.live) and (" · looking back (" .. info.index .. " of " .. info.count .. ")") or ""
  return "X-ray · stop " .. g.stop .. " · " .. g.reason .. where .. ((info and info.ended) and " · session ended" or "")
end

local function ensure()
  if not panel then
    panel = require("vango.deck.ui").new({
      id = "xray",
      title = "X-ray",
      icon = "󰈈",
      tabs = tabs(),
      help_lines = HELP,
      keys = {
        { "[", function() require("vango.xray").scrub(-1) end, "X-ray: the stop before" },
        { "]", function() require("vango.xray").scrub(1) end, "X-ray: the stop after" },
      },
    })
  end
  return panel
end

function M.setup(getter)
  get = getter
end

-- the frame's title says which stop this is; the rail keeps the short name
local function retitle()
  pcall(vim.api.nvim_win_set_config, panel.wins.frame, { title = { { " " .. panel.icon .. " " .. title() .. " ", "DeckTitle" } }, title_pos = "left" })
end

function M.toggle()
  local p = ensure()
  if p:is_open() then
    p:hide()
  else
    p:show({ focus = "content" })
    retitle()
  end
end

function M.refresh()
  if panel and panel:is_open() then
    retitle()
    panel:refresh()
  end
end

function M.is_open()
  return panel ~= nil and panel:is_open()
end

return M
