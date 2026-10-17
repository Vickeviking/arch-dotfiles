-- The memory map: the stopped thread's frames as cards on the left, heap
-- blocks as boxes on the right, and box-drawn arrows between them, routed
-- through lanes in the gutter. Pure: graph in, lines + highlights out.
--
--   ╭─ basics · main.rs:38 ─────────╮       ╭─ A  [u32; 3] · 12 B ──╮
--   │ v     Vec<u32>  [7, 8, 9]     ●──────▶│ 7 │ 8 │ 9 │            │
--   │ r     &Vec<u32> ─▷ v          │       ╰───────────────────────╯
--
-- Arrows go only to heap blocks; borrows of other locals and of static data
-- are written inline (`─▷ v`), which keeps the picture readable. Heap blocks
-- that point at each other name their targets by letter (`next ─▶ B`).

local theme = require("vango.xray.theme")

local M = {}

-- text helpers -------------------------------------------------------------

local function chars(s)
  local out = {}
  for c in tostring(s):gmatch("[%z\1-\127\194-\244][\128-\191]*") do
    out[#out + 1] = c
  end
  return out
end

local function len(s)
  return #chars(s)
end

local function clip(s, n)
  local c = chars(s)
  if #c <= n then
    return s
  end
  if n <= 1 then
    return "…"
  end
  return table.concat(c, "", 1, n - 1) .. "…"
end

local function pad(s, n)
  s = clip(s, n)
  return s .. string.rep(" ", n - len(s))
end

-- words into lines of at most n characters
local function wrap(text, n)
  local out, cur = {}, ""
  for word in text:gmatch("%S+") do
    if cur == "" then
      cur = word
    elseif len(cur) + 1 + len(word) <= n then
      cur = cur .. " " .. word
    else
      out[#out + 1] = cur
      cur = word
    end
  end
  if cur ~= "" then
    out[#out + 1] = cur
  end
  return out
end

M.clip, M.len, M.pad, M.wrap = clip, len, pad, wrap

-- canvas -------------------------------------------------------------------

local Canvas = {}
Canvas.__index = Canvas

local function canvas(w)
  return setmetatable({ w = w, rows = {} }, Canvas)
end

function Canvas:row(y)
  local r = self.rows[y]
  if not r then
    r = {}
    for x = 1, self.w do
      r[x] = { " ", nil }
    end
    self.rows[y] = r
  end
  return r
end

-- write text at (x, y), 1-based; returns the x after it
function Canvas:put(x, y, text, hl)
  local r = self:row(y)
  for _, c in ipairs(chars(text)) do
    if x >= 1 and x <= self.w then
      r[x] = { c, hl }
    end
    x = x + 1
  end
  return x
end

-- a run of segments { {text, hl}, ... }
function Canvas:segs(x, y, segs)
  for _, s in ipairs(segs) do
    x = self:put(x, y, s[1], s[2])
  end
  return x
end

function Canvas:height()
  local h = 0
  for y in pairs(self.rows) do
    h = math.max(h, y)
  end
  return h
end

-- lines plus highlight runs with byte columns, rows 0-based
function Canvas:render(row0)
  local lines, hls = {}, {}
  for y = 1, self:height() do
    local r = self:row(y)
    local last = 0
    for x = self.w, 1, -1 do
      if r[x][1] ~= " " or r[x][2] then
        last = x
        break
      end
    end
    local parts, byte, run_hl, run_start = {}, 0, nil, 0
    for x = 1, last do
      local c, hl = r[x][1], r[x][2]
      if hl ~= run_hl then
        if run_hl then
          hls[#hls + 1] = { row0 + y - 1, run_start, byte, run_hl }
        end
        run_hl, run_start = hl, byte
      end
      parts[#parts + 1] = c
      byte = byte + #c
    end
    if run_hl then
      hls[#hls + 1] = { row0 + y - 1, run_start, byte, run_hl }
    end
    lines[#lines + 1] = table.concat(parts)
  end
  return lines, hls
end

-- the gutter: arrows as connectivity bits, drawn as box characters ----------

local BOX = {
  lr = "─", l = "─", r = "─", ud = "│", u = "│", d = "│",
  dr = "╭", dl = "╮", ur = "╰", ul = "╯",
  udr = "├", udl = "┤", dlr = "┬", ulr = "┴", udlr = "┼",
}
local DASH = { lr = "┄", l = "┄", r = "┄", ud = "┆", u = "┆", d = "┆" }

local Gutter = {}
Gutter.__index = Gutter

local function gutter()
  return setmetatable({ cells = {} }, Gutter)
end

function Gutter:cell(x, y)
  local key = y * 4096 + x
  local c = self.cells[key]
  if not c then
    c = { x = x, y = y, rank = 0, kinds = {} }
    self.cells[key] = c
  end
  return c
end

function Gutter:mark(x, y, dir, kind)
  local c = self:cell(x, y)
  c[dir] = true
  c.kinds[kind] = true
  local r = theme.RANK[kind] or 0
  if r > c.rank then
    c.rank, c.kind = r, kind
  end
end

-- a path through points, each step one straight segment
function Gutter:path(points, kind)
  for i = 1, #points - 1 do
    local a, b = points[i], points[i + 1]
    local dx = b[1] > a[1] and 1 or (b[1] < a[1] and -1 or 0)
    local dy = b[2] > a[2] and 1 or (b[2] < a[2] and -1 or 0)
    local x, y = a[1], a[2]
    while x ~= b[1] or y ~= b[2] do
      local nx, ny = x + dx, y + dy
      if dx == 1 then
        self:mark(x, y, "r", kind)
        self:mark(nx, ny, "l", kind)
      elseif dx == -1 then
        self:mark(x, y, "l", kind)
        self:mark(nx, ny, "r", kind)
      elseif dy == 1 then
        self:mark(x, y, "d", kind)
        self:mark(nx, ny, "u", kind)
      else
        self:mark(x, y, "u", kind)
        self:mark(nx, ny, "d", kind)
      end
      x, y = nx, ny
    end
  end
end

function Gutter:draw(cv)
  for _, c in pairs(self.cells) do
    local key = (c.u and "u" or "") .. (c.d and "d" or "") .. (c.l and "l" or "") .. (c.r and "r" or "")
    local only_weak = c.kinds.weak and vim.tbl_count(c.kinds) == 1
    local ch = (only_weak and DASH[key]) or BOX[key] or "·"
    if c.head then
      ch = "▶"
    end
    cv:put(c.x, c.y, ch, theme.KIND_HL[c.kind] or "XrayDim")
  end
end

-- graph helpers ------------------------------------------------------------

local function short_file(p)
  return p and p:match("[^/]+$") or "?"
end

local function edges_from_slot(g, s)
  local out = {}
  for _, e in ipairs(s.edges or {}) do
    out[#out + 1] = g.edges[e + 1]
  end
  return out
end

local function block_of(g, e_end)
  if e_end.node == "block" then
    return g.blocks[e_end.id + 1]
  end
end

local function is_heap(b)
  return b and b.place and b.place.kind ~= "static"
end

-- Rust-ish name for where an edge ends; heap blocks by their letter
local function describe(g, e_end, labels)
  if e_end.node == "slot" then
    return g.slots[e_end.id + 1].name .. (e_end.path or "")
  end
  local b = g.blocks[e_end.id + 1]
  if b.place.kind == "static" then
    return b.ty
  end
  local l = labels[b.id]
  return (l and l or ("heap " .. b.ty)) .. (e_end.path or "")
end
M.describe = describe

-- The owner chain to a heap spot, without letters: `*v[2]`,
-- `*parent.children[0]`; nil when nothing owns it.
local function path_to(g, e_end, depth)
  depth = depth or 0
  if e_end.node == "slot" then
    return g.slots[e_end.id + 1].name .. (e_end.path or "")
  end
  if depth > 8 then
    return nil
  end
  local b = g.blocks[e_end.id + 1]
  for _, i in ipairs(b.incoming or {}) do
    local e = g.edges[i + 1]
    if e.kind == "owns" or e.kind == "shared" then
      local up = path_to(g, e.from, depth + 1)
      return up and (up .. (e_end.path or "")) or nil
    end
  end
end

-- Words for where an edge ends, for inline text: locals by name, heap by
-- owner chain (`*v[2]`), and your own heap block by what it is.
function M.name_of(g, e, own)
  local to = e.to
  if to.node == "slot" then
    return g.slots[to.id + 1].name .. (to.path or "")
  end
  local b = g.blocks[to.id + 1]
  if b.place.kind == "static" then
    return b.ty
  end
  -- a second Rc to the same box: name the box by its first owner
  if own and e.kind == "shared" then
    for _, i in ipairs(b.incoming or {}) do
      local first = g.edges[i + 1]
      if first.kind == "shared" then
        if first.id ~= e.id then
          own = false
        end
        break
      end
    end
  end
  if not own then
    local p = path_to(g, to)
    if p then
      return "*" .. p
    end
  end
  return "heap " .. clip(b.ty, 30) .. (b.size and (" · " .. b.size .. " B") or "")
end

local function fact(list, key)
  for _, f in ipairs(list or {}) do
    if f.key == key then
      return f
    end
  end
end

local function change_badge(c)
  if not c then
    return nil
  end
  if c.kind == "new" then
    return " new ", "XrayBadgeNew"
  elseif c.kind == "realloc" then
    return " moved ", "XrayBadgeMoved"
  elseif c.kind == "changed" then
    return " changed ", "XrayBadgeChanged"
  end
end

-- the frames worth drawing: the stopped thread's frames that have locals
-- and are your code (or the innermost frame, whatever it is)
function M.frames(g)
  local out = {}
  for _, t in ipairs(g.threads) do
    if t.stopped then
      for i, f in ipairs(t.frames) do
        if f.slots and #f.slots > 0 and (f.user or i == 1) then
          out[#out + 1] = { thread = t, frame = f, index = i - 1 }
        end
      end
    end
  end
  return out
end

-- heap boxes ---------------------------------------------------------------

-- edges leaving a block, by the item path they start at
local function block_out(g, b)
  local out = {}
  for _, e in ipairs(b.edges or {}) do
    local edge = g.edges[e + 1]
    out[#out + 1] = edge
  end
  return out
end

-- one element, short: Rcs as `Rc`, nested Vecs by length
local function elem(v)
  if v:match("^strong=") then
    return "Rc"
  end
  local n = v:match("^size=(%d+)")
  return n and ("len " .. n) or v
end

local function strip(b, w)
  -- the elements as filled cells, spare capacity hatched:  7 │ 8 │ 9 │ ░
  local vals = {}
  for _, it in ipairs(b.items or {}) do
    if it.name:match("^%[") then
      vals[#vals + 1] = elem(it.value)
    end
  end
  local n, cap = b.len or #vals, b.cap or b.len or #vals
  local cw = 1
  for _, v in ipairs(vals) do
    cw = math.max(cw, math.min(len(v), 6))
  end
  local segs, used = {}, 0
  local total = math.max(cap, n)
  for i = 1, total do
    if used + cw + 3 > w - 8 and i < total then
      segs[#segs + 1] = { " +" .. (total - i + 1), "XrayDim" }
      break
    end
    if i > 1 then
      segs[#segs + 1] = { "│", "XrayFaint" }
    end
    if i <= #vals then
      segs[#segs + 1] = { " " .. pad(vals[i], cw) .. " ", "XrayCell" }
    elseif i <= n then
      segs[#segs + 1] = { " " .. pad("·", cw) .. " ", "XrayCell" }
    else
      segs[#segs + 1] = { " " .. string.rep("░", cw) .. " ", "XraySpare" }
    end
    used = used + cw + 3
  end
  return segs
end

-- rows of a block's box, each a list of segments; all rows `w` wide
local function box_rows(g, b, labels, w)
  local label = labels[b.id] or "?"
  local rows = {}
  local inner = w - 4
  -- header
  local size = b.size and (" · " .. b.size .. " B") or ""
  local badge, badge_hl = change_badge(b.change)
  local head = { { "╭─", "XrayBox" }, { " " .. label .. " ", "XrayLabel" }, { " " .. clip(b.ty, inner - 12), "XrayType" }, { size, "XrayDim" }, { " ", "XrayBox" } }
  local used = 0
  for _, s in ipairs(head) do
    used = used + len(s[1])
  end
  -- what comes after the fill: the badge and its dash, then the corner
  local tail = (badge and (len(badge) + 1) or 0) + 1
  local fill = math.max(1, w - used - tail)
  head[#head + 1] = { string.rep("─", fill), "XrayBox" }
  if badge then
    head[#head + 1] = { badge, badge_hl }
    head[#head + 1] = { "─", "XrayBox" }
  end
  head[#head + 1] = { "╮", "XrayBox" }
  rows[1] = head

  local function line(segs)
    -- never past the right border: clip whatever doesn't fit
    local n = 0
    local out = { { "│ ", "XrayBox" } }
    for _, s in ipairs(segs) do
      local room = inner - n
      if room <= 0 then
        break
      end
      local text = len(s[1]) > room and clip(s[1], room) or s[1]
      out[#out + 1] = { text, s[2] }
      n = n + len(text)
    end
    if n < inner then
      out[#out + 1] = { string.rep(" ", inner - n), nil }
    end
    out[#out + 1] = { " │", "XrayBox" }
    rows[#rows + 1] = out
  end

  local outs = block_out(g, b)
  local function target_of(path)
    for _, e in ipairs(outs) do
      local p = e.from.path or ""
      if p == path or p:sub(1, #path + 1) == path .. "." then
        return e
      end
    end
  end

  if b.kind == "buffer" then
    local segs = strip(b, w)
    line(segs)
    local n, cap = b.len or 0, b.cap
    line({ { "len " .. n, "XrayDim" }, { cap and (" · cap " .. cap) or "", (cap and cap == n) and "XrayWarn" or "XrayDim" }, { (cap and cap == n) and "  full: the next push reallocates" or "", "XrayFaint" } })
    -- elements that own or point elsewhere: [0] ─▶ C
    local links = {}
    for _, e in ipairs(outs) do
      local idx = (e.from.path or ""):match("^(%[%d+%])")
      if idx and #links < 4 then
        links[#links + 1] = { idx, e }
      end
    end
    if #links > 0 then
      local segs2 = {}
      for i, l in ipairs(links) do
        segs2[#segs2 + 1] = { (i > 1 and "  " or "") .. l[1] .. " ", "XrayDim" }
        segs2[#segs2 + 1] = { theme.ARROW[l[2].kind] .. " " .. describe(g, l[2].to, labels), theme.KIND_HL[l[2].kind] }
      end
      line(segs2)
    end
  elseif b.kind == "bytes" then
    local cap, n = b.cap or b.len or 0, b.len or 0
    local spare = math.min(math.max(cap - n, 0), 8)
    line({ { clip(b.summary, inner - spare - 1), "XrayCell" }, { spare > 0 and (" " .. string.rep("░", spare)) or "", "XraySpare" } })
    line({ { "len " .. n .. " · cap " .. cap .. " bytes", "XrayDim" } })
  elseif b.kind == "counted" then
    local segs = {}
    for _, key in ipairs({ "strong", "weak" }) do
      local f = fact(b.facts, key)
      if f then
        segs[#segs + 1] = { (#segs > 0 and " · " or "") .. key .. " " .. f.value, theme.TONE_HL[f.tone] or "XrayValue" }
      end
    end
    for _, f in ipairs(b.facts or {}) do
      if f.key ~= "strong" and f.key ~= "weak" then
        segs[#segs + 1] = { (#segs > 0 and " · " or "") .. f.value, theme.TONE_HL[f.tone] or "XrayValue" }
      end
    end
    if #segs > 0 then
      line(segs)
    end
    local inner_ty = (b.ty:match("^%w+Inner<(.*)>$") or b.ty)
    if #outs == 0 then
      line({ { clip(inner_ty, 22) .. " ", "XrayType" }, { clip(b.summary, inner - math.min(len(inner_ty), 22) - 1), "XrayValue" } })
    else
      line({ { clip(inner_ty, inner), "XrayType" } })
    end
    -- what the value points at: a Vec's buffer, a Weak parent
    for i, e in ipairs(outs) do
      if i > 4 then
        line({ { "… " .. (#outs - 4) .. " more", "XrayDim" } })
        break
      end
      local p = (e.from.path or ""):gsub("^%.", "")
      line({ { pad(p == "" and "value" or p, 12) .. " ", "XrayDim" }, { theme.ARROW[e.kind] .. " " .. describe(g, e.to, labels), theme.KIND_HL[e.kind] } })
    end
  elseif b.kind == "table" then
    for i, it in ipairs(b.items or {}) do
      if i > 5 then
        line({ { "… " .. (#b.items - 5) .. " more", "XrayDim" } })
        break
      end
      local v = it.value:gsub("^%(", ""):gsub("%)$", "")
      line({ { clip(v, inner), "XrayValue" } })
    end
  else
    -- a struct behind a Box (or anything else): its fields
    local items = b.items or {}
    -- a Box of a plain value: its one child is the value itself (`*0`)
    if #items == 1 and items[1].name:match("^%*") then
      items = {}
    end
    if #items == 0 then
      line({ { clip(b.summary, inner), "XrayValue" } })
    end
    local nw = 4
    for _, it in ipairs(items) do
      nw = math.max(nw, math.min(len(it.name), 10))
    end
    for i, it in ipairs(items) do
      if i > 6 then
        line({ { "… " .. (#items - 6) .. " more", "XrayDim" } })
        break
      end
      local e = target_of("." .. it.name) or target_of(it.name)
      local segs = { { pad(it.name, nw) .. " ", "XrayName" } }
      if e then
        segs[#segs + 1] = { clip(it.value, 8) .. " ", "XrayDim" }
        segs[#segs + 1] = { theme.ARROW[e.kind] .. " " .. describe(g, e.to, labels), theme.KIND_HL[e.kind] }
      else
        segs[#segs + 1] = { clip(it.value, inner - nw - 1), "XrayValue" }
      end
      line(segs)
    end
  end
  rows[#rows + 1] = { { "╰" .. string.rep("─", w - 2) .. "╯", "XrayBox" } }
  return rows
end

-- stack cards --------------------------------------------------------------

local function marker(s, moved)
  if moved then
    return "↷", "XrayAlert"
  end
  local c = s.change
  if c and c.kind == "changed" then
    return "✱", "XrayChanged"
  elseif c and c.kind == "new" then
    return "+", "XrayChanged"
  end
  return " ", nil
end

-- One row of a slot: the inline part (value, or `─▷ v` for a borrow of
-- another local / static data) and its heap edges, which become arrows.
local function slot_row(g, s, labels, opts, nw, tw, vw)
  opts = opts or {}
  local mk, mk_hl = marker(s, opts.moved and opts.moved[s.id])
  local name_hl = (opts.moved and opts.moved[s.id]) and "XrayMoved" or "XrayName"
  local segs = { { mk, mk_hl }, { pad(s.name, nw) .. " ", name_hl }, { pad(s.ty, tw) .. " ", "XrayType" } }
  local heap = {}
  local inline = {}
  for _, e in ipairs(edges_from_slot(g, s)) do
    local b = block_of(g, e.to)
    if is_heap(b) then
      heap[#heap + 1] = e
    else
      inline[#inline + 1] = e
    end
  end
  local value_hl = (s.change and s.change.kind == "changed") and "XrayChanged" or "XrayValue"
  if #inline > 0 then
    local e = inline[1]
    local text = theme.ARROW[e.kind] .. " " .. describe(g, e.to, labels)
    segs[#segs + 1] = { clip(text, vw), theme.KIND_HL[e.kind] }
    local rest = vw - len(text) - 2
    if rest > 6 and s.summary ~= "" and not s.summary:match("^len %d+$") then
      segs[#segs + 1] = { "  " .. clip(s.summary, rest), "XrayDim" }
    end
  else
    segs[#segs + 1] = { clip(s.summary, vw), value_hl }
  end
  return segs, heap
end

-- layout -------------------------------------------------------------------

-- Lay everything out. opts.width: columns available; opts.moved: slot ids
-- that were moved from (decided from the source by the caller).
-- Returns lines, hls, rows (0-based row → { slot = id } / { block = id } /
-- { frame = frame }), labels (block id → letter).
function M.render(g, opts)
  opts = opts or {}
  local width = math.max(opts.width or 110, 70)
  local cards = M.frames(g)

  -- 1. which slots point at heap blocks
  local heap_of = {} -- slot id → heap edges
  local sources = {} -- in stack order: { slot, edge }
  for _, c in ipairs(cards) do
    for _, id in ipairs(c.frame.slots) do
      local s = g.slots[id + 1]
      heap_of[s.id] = {}
      for _, e in ipairs(edges_from_slot(g, s)) do
        if is_heap(block_of(g, e.to)) then
          table.insert(heap_of[s.id], e)
          sources[#sources + 1] = { slot = s.id, edge = e }
        end
      end
    end
  end

  -- 2. heap blocks in order of their first arrow, children right after parents
  local order, placed = {}, {}
  local function place(b)
    if not is_heap(b) or placed[b.id] then
      return
    end
    placed[b.id] = true
    order[#order + 1] = b
    for _, e in ipairs(block_out(g, b)) do
      if e.kind == "owns" or e.kind == "shared" then
        place(block_of(g, e.to))
      end
    end
  end
  for _, src in ipairs(sources) do
    place(block_of(g, src.edge.to))
  end
  local labels = {}
  local letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
  for i, b in ipairs(order) do
    labels[b.id] = i <= 26 and letters:sub(i, i) or ("Z" .. (i - 26))
  end

  -- 3. the stack column
  -- as wide as the values need, between 36 and half the width (60 at most)
  local nw, tw, want = 4, 6, 8
  for _, c in ipairs(cards) do
    for _, id in ipairs(c.frame.slots) do
      local s = g.slots[id + 1]
      nw = math.max(nw, math.min(len(s.name), 10))
      tw = math.max(tw, math.min(len(s.ty), 16))
      want = math.max(want, math.min(len(s.summary), 34))
    end
    want = math.max(want, len(c.frame.name) + len(short_file(c.frame.file)) - nw - tw + 4)
  end
  local SW = math.max(36, math.min(math.floor(width * 0.5), 60, nw + tw + want + 6))
  local vw = SW - 4 - nw - tw - 2

  local cv = canvas(width)
  local rows = {}
  local slot_y = {}
  local y = 1
  cv:put(1, y, "STACK", "XrayHead")
  if #g.threads > 1 and cards[1] then
    cv:put(7, y, " thread " .. cards[1].thread.name .. " · " .. #g.threads .. " threads", "XrayDim")
  end
  y = y + 1
  if #cards == 0 then
    cv:put(1, y, "no locals here (optimised out, or not your code)", "XrayDim")
    y = y + 1
  end
  for _, c in ipairs(cards) do
    local title = clip(" " .. c.frame.name .. " · " .. short_file(c.frame.file) .. ":" .. c.frame.line .. " ", SW - 6)
    cv:put(1, y, "╭─", "XrayCard")
    local x = cv:put(3, y, title, c.index == 0 and "XrayCardTitle" or "XrayDim")
    cv:put(x, y, string.rep("─", SW - x) .. "╮", "XrayCard")
    rows[y] = { frame = c.frame }
    y = y + 1
    for _, id in ipairs(c.frame.slots) do
      local s = g.slots[id + 1]
      local segs = slot_row(g, s, labels, opts, nw, tw, vw)
      local heap = heap_of[s.id]
      cv:put(1, y, "│", "XrayCard")
      cv:segs(2, y, segs)
      cv:put(SW, y, #heap > 0 and "●" or "│", #heap > 0 and theme.KIND_HL[heap[1].kind] or "XrayCard")
      rows[y] = { slot = s.id }
      slot_y[s.id] = y
      y = y + 1
    end
    cv:put(1, y, "╰" .. string.rep("─", SW - 2) .. "╯", "XrayCard")
    y = y + 2
  end
  local stack_h = y

  -- 4. boxes: each header as level with its first arrow as there is room for
  local first_src = {}
  for _, src in ipairs(sources) do
    local b = block_of(g, src.edge.to)
    local sy = slot_y[src.slot]
    first_src[b.id] = math.min(first_src[b.id] or sy, sy)
  end
  local box_y, boxes, hy = {}, {}, 2
  for _, b in ipairs(order) do
    local at = math.max(hy, first_src[b.id] or hy)
    local h = #box_rows(g, b, labels, 40) -- the row count doesn't depend on width
    boxes[#boxes + 1] = { b = b, y = at }
    box_y[b.id] = at
    hy = at + h + 1
  end

  -- 5. lanes: one per block with stack arrows, reused when spans don't overlap
  local spans = {}
  for _, src in ipairs(sources) do
    local b = block_of(g, src.edge.to)
    local sy, by = slot_y[src.slot], box_y[b.id]
    local sp = spans[b.id] or { id = b.id, lo = by, hi = by, srcs = {} }
    sp.lo, sp.hi = math.min(sp.lo, sy), math.max(sp.hi, sy)
    table.insert(sp.srcs, { y = sy, kind = src.edge.kind })
    spans[b.id] = sp
  end
  local list = vim.tbl_values(spans)
  table.sort(list, function(a, b)
    return a.lo < b.lo or (a.lo == b.lo and a.id < b.id)
  end)
  local lane_end = {}
  for _, sp in ipairs(list) do
    local lane = 1
    while lane_end[lane] and lane_end[lane] >= sp.lo do
      lane = lane + 1
    end
    sp.lane = lane
    lane_end[lane] = sp.hi
  end
  local HX = SW + 1
  local G = math.max(4, #lane_end * 2 + 3)
  local BX = HX + G
  local BW = math.max(30, math.min(48, width - BX))

  local gt = gutter()
  for _, sp in ipairs(list) do
    local lx = HX + sp.lane * 2
    local by = box_y[sp.id]
    for _, src in ipairs(sp.srcs) do
      gt:mark(HX, src.y, "l", src.kind) -- joins the ● on the card's edge
      gt:path({ { HX, src.y }, { lx, src.y }, { lx, by }, { BX - 1, by } }, src.kind)
    end
    gt:cell(BX - 1, by).head = true
  end

  -- 6. draw the boxes and the arrows
  cv:put(BX, 1, "HEAP", "XrayHead")
  if #order == 0 then
    cv:put(BX, 2, "nothing on the heap from here", "XrayDim")
  end
  for _, bx in ipairs(boxes) do
    for i, segs in ipairs(box_rows(g, bx.b, labels, BW)) do
      cv:segs(BX, bx.y + i - 1, segs)
      rows[bx.y + i - 1] = rows[bx.y + i - 1] or { block = bx.b.id }
    end
  end
  gt:draw(cv)

  -- 7. freed since the last stop: ghosts under the heap column
  local yy = math.max(cv:height(), stack_h - 1) + 1
  if #(g.freed or {}) > 0 then
    cv:put(BX, yy, "freed since the last stop", "XrayAlert")
    yy = yy + 1
    for i, b in ipairs(g.freed) do
      if i > 4 then
        cv:put(BX, yy, "… " .. (#g.freed - 4) .. " more", "XrayDim")
        break
      end
      cv:put(BX, yy, "✕ " .. clip(b.ty .. "  " .. b.summary, BW - 2), "XrayFaint")
      yy = yy + 1
    end
  end

  -- 8. what the model noticed, across the whole width
  if #(g.notes or {}) > 0 then
    yy = math.max(yy, cv:height() + 2)
    for _, n in ipairs(g.notes) do
      local icon = n.kind == "realloc" and "⚠ " or "↷ "
      local hl = n.kind == "realloc" and "XrayWarn" or "XrayAlert"
      local text = n.text:gsub("`", "")
      local first = true
      for _, part in ipairs(M.wrap(text, width - 3)) do
        cv:put(1, yy, (first and icon or "  ") .. part, hl)
        first = false
        yy = yy + 1
      end
    end
  end

  local lines, hls = cv:render(0)
  local by_row = {}
  for r, v in pairs(rows) do
    by_row[r - 1] = v
  end
  return lines, hls, by_row, labels
end

-- Narrow layout for the sidebar: the stack card on top, heap boxes stacked
-- under it, and heap pointers written as `─▶ A` instead of routed arrows.
function M.render_compact(g, opts)
  opts = opts or {}
  local W = math.max(40, opts.width or 60)
  local cards = M.frames(g)
  local sources, order, placed = {}, {}, {}
  local heap_of = {}
  for _, c in ipairs(cards) do
    for _, id in ipairs(c.frame.slots) do
      local s = g.slots[id + 1]
      heap_of[s.id] = {}
      for _, e in ipairs(edges_from_slot(g, s)) do
        if is_heap(block_of(g, e.to)) then
          table.insert(heap_of[s.id], e)
          sources[#sources + 1] = e
        end
      end
    end
  end
  local function place(b)
    if not is_heap(b) or placed[b.id] then
      return
    end
    placed[b.id] = true
    order[#order + 1] = b
    for _, e in ipairs(block_out(g, b)) do
      if e.kind == "owns" or e.kind == "shared" then
        place(block_of(g, e.to))
      end
    end
  end
  for _, e in ipairs(sources) do
    place(block_of(g, e.to))
  end
  local labels = {}
  local letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
  for i, b in ipairs(order) do
    labels[b.id] = i <= 26 and letters:sub(i, i) or ("Z" .. (i - 26))
  end

  local cv = canvas(W)
  local rows = {}
  local y = 1
  cv:put(1, y, "STACK", "XrayHead")
  if #g.threads > 1 then
    cv:put(7, y, " · " .. #g.threads .. " threads", "XrayDim")
  end
  y = y + 1
  local nw, tw = 4, 6
  for _, c in ipairs(cards) do
    for _, id in ipairs(c.frame.slots) do
      local s = g.slots[id + 1]
      nw = math.max(nw, math.min(len(s.name), 9))
      tw = math.max(tw, math.min(len(s.ty), 12))
    end
  end
  for _, c in ipairs(cards) do
    local title = clip(" " .. c.frame.name .. " · " .. short_file(c.frame.file) .. ":" .. c.frame.line .. " ", W - 6)
    cv:put(1, y, "╭─", "XrayCard")
    local x = cv:put(3, y, title, c.index == 0 and "XrayCardTitle" or "XrayDim")
    cv:put(x, y, string.rep("─", W - x) .. "╮", "XrayCard")
    rows[y] = { frame = c.frame }
    y = y + 1
    for _, id in ipairs(c.frame.slots) do
      local s = g.slots[id + 1]
      local heap = heap_of[s.id]
      local tail = {}
      for i, e in ipairs(heap) do
        if i <= 2 then
          tail[#tail + 1] = { " " .. theme.ARROW[e.kind] .. " " .. (labels[e.to.id] or "?") .. (e.to.path or ""), theme.KIND_HL[e.kind] }
        end
      end
      local tail_w = 0
      for _, t in ipairs(tail) do
        tail_w = tail_w + len(t[1])
      end
      local vw = math.max(6, W - 4 - nw - tw - 2 - tail_w)
      local segs = slot_row(g, s, labels, opts, nw, tw, vw)
      cv:put(1, y, "│", "XrayCard")
      local x2 = cv:segs(2, y, segs)
      cv:segs(math.max(x2, W - tail_w), y, tail)
      cv:put(W, y, "│", "XrayCard")
      rows[y] = { slot = s.id }
      y = y + 1
    end
    cv:put(1, y, "╰" .. string.rep("─", W - 2) .. "╯", "XrayCard")
    y = y + 2
  end
  if #cards == 0 then
    cv:put(1, y, "no locals here", "XrayDim")
    y = y + 2
  end
  cv:put(1, y, "HEAP", "XrayHead")
  y = y + 1
  if #order == 0 then
    cv:put(1, y, "nothing on the heap from here", "XrayDim")
    y = y + 1
  end
  for _, b in ipairs(order) do
    for _, segs in ipairs(box_rows(g, b, labels, W)) do
      cv:segs(1, y, segs)
      rows[y] = { block = b.id }
      y = y + 1
    end
  end
  if #(g.freed or {}) > 0 then
    y = y + 1
    cv:put(1, y, "freed since the last stop", "XrayAlert")
    y = y + 1
    for i, b in ipairs(g.freed) do
      if i > 3 then
        break
      end
      cv:put(1, y, "✕ " .. clip(b.ty .. "  " .. b.summary, W - 2), "XrayFaint")
      y = y + 1
    end
  end
  for _, n in ipairs(g.notes or {}) do
    y = y + 1
    local hl = n.kind == "realloc" and "XrayWarn" or "XrayAlert"
    for i, part in ipairs(M.wrap(n.text:gsub("`", ""), W - 2)) do
      cv:put(1, y, (i == 1 and (n.kind == "realloc" and "⚠ " or "↷ ") or "  ") .. part, hl)
      y = y + 1
    end
  end
  local lines, hls = cv:render(0)
  local by_row = {}
  for r, v in pairs(rows) do
    by_row[r - 1] = v
  end
  return lines, hls, by_row, labels
end

-- the legend line, the same glyphs and colors as everywhere
function M.legend()
  local segs = {}
  for _, k in ipairs({ "owns", "shared", "weak", "borrow", "borrow_mut" }) do
    segs[#segs + 1] = { theme.ARROW[k] .. " " .. theme.WORD[k], theme.KIND_HL[k] }
    segs[#segs + 1] = { "   ", nil }
  end
  segs[#segs + 1] = { "✱ changed  + new  ↷ moved from  ░ spare capacity", "XrayDim" }
  return segs
end

return M
