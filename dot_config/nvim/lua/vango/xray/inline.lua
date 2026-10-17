-- X-ray inline: at each stop, a short note at the end of every local's
-- declaration line saying what it holds and where it points.
--
--   let v: Vec<u32> = vec![7, 8, 9];      [7, 8, 9] ─▶ heap [u32; 3] · 12 B  len 3 · cap 3
--   let r = &v;                           ─▷ v
--   let mut writing = alias.borrow_mut(); ━▶ *cell  borrowed mut
--   let words = vec![…];                  ↷ moved into taken

local map = require("vango.xray.map")
local source = require("vango.xray.source")
local theme = require("vango.xray.theme")

local M = {}

local ns = vim.api.nvim_create_namespace("vango_xray_inline")
local marked = {} -- buffers we drew in

function M.clear()
  for b in pairs(marked) do
    if vim.api.nvim_buf_is_valid(b) then
      vim.api.nvim_buf_clear_namespace(b, ns, 0, -1)
    end
  end
  marked = {}
end

-- facts worth a glance, as one dim string; skips what the summary already says
local KEYS = { len = true, cap = true, borrow = true, lock = true, poison = true }

local function facts_text(list, summary)
  local parts = {}
  for _, f in ipairs(list or {}) do
    if KEYS[f.key] and not summary:find(f.value, 1, true) then
      parts[#parts + 1] = (f.key == "len" or f.key == "cap") and (f.key .. " " .. f.value) or f.value
    end
  end
  return table.concat(parts, " · ")
end

local function chunks_for(g, s, moved_into, many)
  local out = {}
  local function add(text, hl)
    out[#out + 1] = { text, hl }
  end
  add("  ", nil)
  if many then
    add(s.name .. " ", "XrayDim")
  end
  if moved_into then
    add("↷ moved into " .. moved_into, "XrayMoved")
    add("  its heap data belongs to " .. moved_into .. " now", "XrayFaint")
    return out
  end
  local changed = s.change and s.change.kind == "changed"
  local edges = {}
  for _, i in ipairs(s.edges or {}) do
    edges[#edges + 1] = g.edges[i + 1]
  end
  -- a plain borrow says it all with its arrow; others show their value
  local only_borrow = #edges > 0 and (edges[1].kind == "borrow" or edges[1].kind == "borrow_mut")
  if not only_borrow or changed then
    local summary = map.clip(s.summary, 40)
    if summary:match("^len %d+$") and #edges > 0 then
      summary = ""
    end
    if summary ~= "" then
      add((changed and "✱ " or "") .. summary, changed and "XrayChanged" or "XrayInline")
    end
  end
  for i, e in ipairs(edges) do
    if i > 2 then
      add(" +" .. (#edges - 2), "XrayDim")
      break
    end
    local own = e.kind == "owns" or e.kind == "shared" or e.kind == "atomic"
    local sep = (#out > 1 + (many and 1 or 0)) and "  " or ""
    add(sep .. theme.ARROW[e.kind] .. " " .. map.name_of(g, e, own), theme.KIND_HL[e.kind])
    -- the target's state matters for shared things: RefCell flags, locks
    if e.to.node == "block" then
      local b = g.blocks[e.to.id + 1]
      for _, f in ipairs(b.facts or {}) do
        if (f.key == "borrow" or f.key == "lock" or f.key == "poison") and f.tone ~= "plain" then
          add("  " .. f.value, theme.TONE_HL[f.tone] or "XrayInline")
        end
      end
      if b.change and b.change.kind == "realloc" then
        add("  ⚠ reallocated: the old buffer is freed", "XrayWarn")
      end
    end
  end
  local ft = facts_text(s.facts, s.summary)
  if ft ~= "" then
    add("  " .. ft, "XrayFaint")
  end
  if changed and s.change.before then
    add("  was " .. map.clip(s.change.before, 30), "XrayFaint")
  end
  return out
end

-- Draw for every frame of the stopped thread whose file is open.
function M.render(g)
  M.clear()
  if not g then
    return
  end
  for _, c in ipairs(map.frames(g)) do
    local buf = source.buf_for(c.frame.file)
    if buf then
      local decls = source.decls(buf, c.frame.line)
      local moved = source.moved(g, buf, decls)
      local by_row = {}
      for _, id in ipairs(c.frame.slots) do
        local s = g.slots[id + 1]
        local row = decls[s.name]
        if row then
          by_row[row] = by_row[row] or {}
          table.insert(by_row[row], s)
        end
      end
      for row, slots in pairs(by_row) do
        local chunks = {}
        for _, s in ipairs(slots) do
          vim.list_extend(chunks, chunks_for(g, s, moved[s.id], #slots > 1))
        end
        pcall(vim.api.nvim_buf_set_extmark, buf, ns, row, 0, {
          virt_text = chunks,
          virt_text_pos = "eol",
          hl_mode = "combine",
          priority = 150,
        })
      end
      marked[buf] = true
    end
  end
end

return M
