-- Byte-strip drawings of a type's memory layout, cheats.rs style, from real data:
-- rust-analyzer's recursive layout (concrete types) or lens-sizes' sizes.json
-- (every generic instantiation the crate actually builds).
--
-- render_*() return lines plus highlights { {row, col, end_col, group} } for
-- a panel tab (raw = true, so rows stay where they are written).

local M = {}

local FIELD_HL = 8 -- LensF1 … LensF8, assigned in order
local MAX_BYTES = 128 -- longer types show their first 128 bytes

function M.colors()
  local theme = require("vango.deck.theme")
  local p, mix = theme.palette(), theme.mix
  local a = p.ansi
  local field = { p.accent, p.accent2, a[13], a[14], a[12], p.ok, a[15], a[10] }
  for i, c in ipairs(field) do
    vim.api.nvim_set_hl(0, "LensF" .. i, { fg = c })
    vim.api.nvim_set_hl(0, "LensF" .. i .. "Text", { fg = c, bold = true })
  end
  vim.api.nvim_set_hl(0, "LensPad", { fg = mix(p.muted, p.panel, 0.45) })
  vim.api.nvim_set_hl(0, "LensTag", { fg = p.alert })
  vim.api.nvim_set_hl(0, "LensTagText", { fg = p.alert, bold = true })
  vim.api.nvim_set_hl(0, "LensDim", { fg = p.muted })
  vim.api.nvim_set_hl(0, "LensNum", { fg = mix(p.muted, p.panel, 0.7) })
  vim.api.nvim_set_hl(0, "LensRecvMove", { fg = p.accent, bold = true })
  vim.api.nvim_set_hl(0, "LensRecvRef", { fg = a[13], bold = true })
  vim.api.nvim_set_hl(0, "LensRecvMut", { fg = a[14], bold = true })
  vim.api.nvim_set_hl(0, "LensRecvNone", { fg = p.muted })
end

local function hlx(hls, row, col, end_col, group)
  table.insert(hls, { row, col, end_col, group })
end

-- what kind of pointer a type is, for the note under the strip
local function pointer_note(ty)
  ty = ty or ""
  if ty:match("^&.-dyn ") or ty:match("^Box<dyn ") or ty:match("%*const dyn ") or ty:match("%*mut dyn ") then
    return "fat pointer: data ptr + vtable ptr"
  elseif ty:match("^&.-%[") or ty:match("^&.-str$") or ty:match("^&'.- str$") or ty:match("^Box<%[") then
    return "fat pointer: data ptr + length"
  end
end

-- One strip: `segments` are { name, ty, offset, size, group }; bytes no segment
-- covers are padding. Writes rows of 8 bytes, each byte a 2-cell block.
local function strip(lines, hls, size, segments)
  local owner = {}
  for _, s in ipairs(segments) do
    for b = s.offset, s.offset + s.size - 1 do
      if b < MAX_BYTES and owner[b] == nil then
        owner[b] = s
      end
    end
  end
  local shown = math.min(size, MAX_BYTES)
  local words = math.max(1, math.ceil(shown / 8))
  for w = 0, words - 1 do
    local row = #lines
    local prefix = (" %5s  "):format("+" .. (w * 8))
    local line = prefix
    local cells = {}
    for b = w * 8, math.min(w * 8 + 7, shown - 1) do
      local col = #line
      local s = owner[b]
      local glyph = s and "██" or "░░"
      line = line .. glyph .. " "
      table.insert(cells, { col, col + #glyph, s and s.group or "LensPad" })
    end
    -- name the fields that start in this word
    local starts = {}
    for _, s in ipairs(segments) do
      if s.size > 0 and math.floor(s.offset / 8) == w then
        table.insert(starts, s)
      end
    end
    local label_cols = {}
    if #starts > 0 then
      line = line .. string.rep(" ", math.max(0, #prefix + 24 - #line)) .. " "
      for _, s in ipairs(starts) do
        local c = #line
        line = line .. s.name .. "  "
        table.insert(label_cols, { c, c + #s.name, s.group .. "Text" })
      end
    end
    table.insert(lines, line)
    hlx(hls, row, 0, #prefix, "LensNum")
    for _, c in ipairs(cells) do
      hlx(hls, row, c[1], c[2], c[3])
    end
    for _, c in ipairs(label_cols) do
      hlx(hls, row, c[1], c[2], c[3])
    end
  end
  if size > MAX_BYTES then
    table.insert(lines, ("        … %d more bytes"):format(size - MAX_BYTES))
  end
end

local function legend(lines, hls, segments)
  table.insert(lines, "")
  for _, s in ipairs(segments) do
    local row = #lines
    local name = s.name
    local ty = s.ty and #s.ty > 32 and (s.ty:sub(1, 31) .. "…") or s.ty
    local line = ty and (" ■ %-14s %-32s %4d B  at +%d"):format(name, ty, s.size, s.offset)
      or (" ■ %-14s %4d B  at +%d"):format(name, s.size, s.offset)
    local note = pointer_note(s.ty)
    if note then
      line = line .. "  · " .. note
    end
    table.insert(lines, line)
    hlx(hls, row, 1, 4, s.group)
    hlx(hls, row, 5, 5 + #name, s.group .. "Text")
    local num_at = line:find("%d+ B  at")
    if num_at then
      hlx(hls, row, num_at - 1, #line, "LensDim")
    end
  end
end

-- `<` in a heading would read as a markdown autolink (`DateTime<Utc>`)
local function heading(t)
  return (t:gsub("<", "\\<"))
end

local function padding_of(size, segments)
  local used = {}
  for _, s in ipairs(segments) do
    for b = s.offset, s.offset + s.size - 1 do
      used[b] = true
    end
  end
  local pad = 0
  for b = 0, size - 1 do
    if not used[b] then
      pad = pad + 1
    end
  end
  return pad
end

--- rust-analyzer's viewRecursiveMemoryLayout result → lines, hls, summary
function M.render_ra(result)
  local nodes = result and result.nodes
  if not nodes or #nodes == 0 then
    return nil
  end
  local lines, hls = {}, {}
  local root = nodes[1]
  local segs = {}
  if root.childrenStart >= 0 then
    for i = root.childrenStart, root.childrenStart + root.childrenLen - 1 do
      local n = nodes[i + 1]
      table.insert(segs, {
        name = n.itemName,
        ty = n.typename,
        offset = n.offset,
        size = n.size,
        group = "LensF" .. ((#segs % FIELD_HL) + 1),
      })
    end
  end
  table.sort(segs, function(x, y)
    return x.offset < y.offset
  end)
  -- an enum (or opaque type) with no fields to show: the bytes are the value
  -- itself, not padding
  local whole = #segs == 0 and root.size > 0
  if whole then
    segs = { { name = "value", ty = root.typename, offset = 0, size = root.size, group = "LensF1" } }
  end
  local pad = padding_of(root.size, segs)
  table.insert(lines, "## " .. heading(root.typename))
  table.insert(lines, "")
  table.insert(lines, ("%d bytes · align %d · %d bytes padding%s"):format(
    root.size,
    root.alignment,
    pad,
    whole and " · no field breakdown" or ""
  ))
  if whole and root.typename:match("^Option<%s*[%w:]*[BRANW][%w]*<") or root.typename:match("^Option<&") then
    hlx(hls, #lines - 1, 0, #lines[#lines], "LensDim")
    table.insert(lines, "")
    table.insert(lines, "> None is stored as the null pointer (a niche), so the Option costs no extra byte.")
  end
  hlx(hls, #lines - 1, 0, #lines[#lines], "LensDim")
  table.insert(lines, "")
  if root.size > 0 then
    strip(lines, hls, root.size, segs)
  end
  if #segs > 0 then
    legend(lines, hls, segs)
  elseif pointer_note(root.typename) then
    table.insert(lines, "")
    table.insert(lines, " " .. pointer_note(root.typename))
  end

  -- the nested structure below the top level, as a tree
  -- the tree is collected first, so the size column lines up with the widest row
  local rows = {}
  local function walk(idx, depth, guide)
    local n = nodes[idx + 1]
    if n.childrenStart < 0 then
      return
    end
    local last_i = n.childrenStart + n.childrenLen - 1
    for i = n.childrenStart, last_i do
      local c = nodes[i + 1]
      local last = i == last_i
      local pre = " " .. guide .. (last and "└ " or "├ ")
      -- rust-analyzer prints pattern types (`usize is 0..=isize::MAX`) as {pat}
      local ty = c.typename
      if ty == "{pat}" then
        ty = n.typename:match("^NonNull") and "*const T (never null)" or "usize (≤ isize::MAX)"
      end
      table.insert(rows, {
        pre = pre,
        head = ("%s%s: %s"):format(pre, c.itemName, ty),
        tail = c.size == 0 and "zero-sized" or ("%d B  +%d"):format(c.size, c.offset),
        zst = c.size == 0,
      })
      if depth < 5 then
        walk(i, depth + 1, guide .. (last and "  " or "│ "))
      end
    end
  end
  local function emit(out)
    local w = 0
    for _, r in ipairs(rows) do
      w = math.max(w, vim.fn.strdisplaywidth(r.head))
    end
    for row, r in ipairs(rows) do
      local line = r.head .. string.rep(" ", w + 3 - vim.fn.strdisplaywidth(r.head)) .. r.tail
      table.insert(out, line)
      hlx(hls, row - 1, 0, #r.pre, "LensNum")
      hlx(hls, row - 1, #line - #r.tail, #line, "LensDim")
      if r.zst then
        hlx(hls, row - 1, #r.pre, #line, "LensDim")
      end
    end
  end
  local tree = {}
  local first_tree_row = #lines + 3
  -- rows in `tree` are relative; shift their highlights after appending
  local before = #hls
  walk(0, 0, "")
  emit(tree)
  if #tree > #segs then
    table.insert(lines, "")
    table.insert(lines, "### Inside")
    table.insert(lines, "")
    for i = before + 1, #hls do
      hls[i][1] = hls[i][1] + first_tree_row
    end
    vim.list_extend(lines, tree)
  else
    for i = #hls, before + 1, -1 do
      table.remove(hls, i)
    end
  end
  return lines, hls, { size = root.size, align = root.alignment, padding = pad }
end

--- one lens-sizes Layout (from sizes.json) → appended to lines/hls
function M.render_sizes(layout, lines, hls)
  lines, hls = lines or {}, hls or {}
  local function seg_list(fields, offset_group)
    local segs = {}
    for _, f in ipairs(fields) do
      table.insert(segs, {
        name = f.name,
        ty = f.ty,
        offset = f.offset,
        size = f.size,
        group = "LensF" .. (((#segs + (offset_group or 0)) % FIELD_HL) + 1),
      })
    end
    return segs
  end
  local pad_total = 0
  table.insert(lines, "## " .. heading(layout.name))
  table.insert(lines, "")
  local head_row = #lines
  table.insert(lines, "")
  table.insert(lines, "")
  if not layout.variants or #layout.variants == 0 then
    local segs = seg_list(layout.fields or {})
    pad_total = padding_of(layout.size, segs)
    if layout.size > 0 then
      strip(lines, hls, layout.size, segs)
    end
    legend(lines, hls, segs)
  else
    local tag = layout.discriminant
    if tag then
      table.insert(lines, (" tag: %d byte%s at +0, then the variant's fields"):format(tag, tag == 1 and "" or "s"))
      hlx(hls, #lines - 1, 1, 4, "LensTagText")
    else
      table.insert(lines, " no separate tag: the variant is encoded in a niche (bytes no valid value uses)")
      hlx(hls, #lines - 1, 1, #lines[#lines], "LensDim")
    end
    for _, v in ipairs(layout.variants) do
      table.insert(lines, "")
      table.insert(lines, ("### %s"):format(v.name))
      table.insert(lines, "")
      local segs = seg_list(v.fields or {})
      for _, s in ipairs(segs) do
        s.name = s.name:match("^%d+$") and ("." .. s.name) or s.name -- tuple fields: .0, .1
      end
      if tag then
        table.insert(segs, 1, { name = "tag", ty = "discriminant", offset = 0, size = tag, group = "LensTag" })
      end
      if layout.size > 0 then
        strip(lines, hls, layout.size, segs)
      end
      if #segs > 0 then
        legend(lines, hls, segs)
      end
    end
    pad_total = layout.size
      - (tag or 0)
      - (function()
        local m = 0
        for _, v in ipairs(layout.variants) do
          local s = 0
          for _, f in ipairs(v.fields or {}) do
            s = s + f.size
          end
          m = math.max(m, s)
        end
        return m
      end)()
  end
  lines[head_row + 1] = ("%d bytes · align %d · %d bytes padding"):format(layout.size, layout.align, math.max(0, pad_total))
  hlx(hls, head_row, 0, #lines[head_row + 1], "LensDim")
  table.insert(lines, "")
  return lines, hls, { size = layout.size, align = layout.align, padding = math.max(0, pad_total) }
end

return M
