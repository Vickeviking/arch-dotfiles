-- "Why not?" (Space Rw): a borrow-checker error redrawn as a timeline.
--
--   ┏━    6 │ let first = &v[0];       ● immutable borrow occurs here
--   ┃     7 │ v.push(4);               ✗ mutable borrow occurs here
--   ┗━    8 │ println!("{first}");     ◆ immutable borrow later used here
--
-- Bars in the gutter are borrows (from where they start to their last use)
-- and values (from their `let` to where they're dropped or moved). The
-- error's ✗ sits where the bars say it can't happen. Built from rustc's own
-- labels, which rust-analyzer hands to nvim with every diagnostic.

local theme = require("vango.xray.theme")
local map = require("vango.xray.map")

local M = {}

-- the rules in plain words, for the classic borrow errors ----------------

M.CODES = {
  E0502 = {
    title = "changing a value while it's borrowed",
    rule = "While a shared borrow (`&`) is alive, the value can't be changed: no `&mut`, no assignment, no method that takes `&mut self`. A borrow lives until its last use, not to the end of the block.",
    ways = {
      "Finish with the borrow before changing the value: move its last use above the change.",
      "Copy or clone what you need instead of borrowing it: `let first = v[0];`",
      "Look the value up again after the change instead of keeping a reference across it.",
    },
  },
  E0499 = {
    title = "two mutable borrows at once",
    rule = "A `&mut` is exclusive: while one is alive (until its last use), no other borrow of the same value may exist, `&mut` or `&`.",
    ways = {
      "Use the first borrow completely before making the second.",
      "Do both changes through the same `&mut`.",
      "Borrow disjoint parts: separate struct fields, or `split_at_mut` for slices.",
      "Need shared mutation? `RefCell` (one thread) or `Mutex` (threads) checks it at run time.",
    },
  },
  E0382 = {
    title = "using a value after it moved",
    rule = "A move hands ownership to someone else; the old name can't be used afterwards. Types that aren't `Copy` (String, Vec, Box, …) move on `let a = b`, on assignment and when passed by value.",
    ways = {
      "Borrow instead of moving: pass `&name`, take `&str` / `&[T]` in the function.",
      "Clone when you really need two owners: `name.clone()`.",
      "Use the value before the move, or make the move the last use.",
    },
  },
  E0505 = {
    title = "moving a value while it's borrowed",
    rule = "A value can't move while a borrow of it is alive: the borrow would point at a place that no longer owns anything.",
    ways = {
      "Stop using the borrow before the move.",
      "Clone first and move the clone.",
      "Borrow again from the new owner after the move.",
    },
  },
  E0506 = {
    title = "assigning to a value while it's borrowed",
    rule = "While a borrow is alive the value must stay as it was: the borrow promised it. Assignment would change it under the borrow's feet.",
    ways = {
      "Finish with the borrow before assigning.",
      "Copy the value out instead of borrowing it (`let old = n;` for Copy types).",
      "A value that must change while shared belongs in a `Cell` / `RefCell`.",
    },
  },
  E0597 = {
    title = "a reference that outlives its value",
    rule = "A reference can't be used after the value it points at is dropped. A value is dropped at the end of the block it was declared in (its closing brace).",
    ways = {
      "Declare the value in the outer block, so it lives as long as the reference.",
      "Keep an owned value (String, Vec, a clone) instead of a reference.",
      "Move the use inside the inner block.",
    },
  },
  E0716 = {
    title = "a reference to a temporary",
    rule = "A value without a name (`String::from(..)` in the middle of an expression) is a temporary: it's dropped at the end of the statement, so a reference to it can't be kept.",
    ways = {
      "Give it a name with `let`, then borrow that: `let owned = String::from(..); let s = &owned;`",
      "Keep the owned value itself instead of a reference.",
    },
  },
  E0373 = {
    title = "a closure that may outlive what it borrows",
    rule = "A closure that may run later (a thread, a stored callback) can't borrow locals: the function could return first and the locals would be gone.",
    ways = {
      "`move ||` gives the closure ownership of what it uses.",
      "Clone the data (or wrap it in `Arc`) and move the clone in.",
      "`std::thread::scope` lets threads borrow locals; they're joined before the scope ends.",
    },
  },
}

-- labels → events, bars --------------------------------------------------

local function kind_of(text, primary)
  local t = text:lower()
  if t:find("after move") then
    return "use_after"
  elseif t:find("later used") or t:find("borrow later") then
    return "use_end"
  elseif t:find("creates a temporary") then
    return "temp"
  elseif t:find("dropped here") or t:find("is freed") then
    return "drop"
  elseif t:find("declared here") then
    return "decl"
  elseif t:find("move occurs because") then
    return "note_type"
  elseif t:find("value moved here") or t:find("move out of") then
    return "move"
  elseif t:find("assigned to here") then
    return "assign"
  elseif t:find("may outlive") then
    return "outlive"
  elseif t:find("borrow") then
    return "borrow"
  end
  return primary and "error" or "note"
end

local function is_mut(text)
  local t = text:lower()
  return t:find("mutabl") ~= nil and not t:find("immutabl")
end

-- The model of one error: events in line order and the bars between them.
-- diag = { code, message, labels = { {line, col, end_col, text, primary} }, helps, rendered }
function M.model(diag, src)
  local m = { code = diag.code, message = diag.message, helps = diag.helps or {}, rendered = diag.rendered, events = {}, bars = {} }
  m.name = diag.message:match("`([^`]+)`")
  for _, l in ipairs(diag.labels) do
    local ev = vim.deepcopy(l)
    ev.kind = kind_of(l.text or "", l.primary)
    ev.mut = is_mut(l.text or "")
    table.insert(m.events, ev)
  end
  table.sort(m.events, function(a, b)
    return a.line < b.line or (a.line == b.line and a.col < b.col)
  end)

  -- borrows: each use_end closes the borrow it talks about
  local borrows = {}
  for _, e in ipairs(m.events) do
    if e.kind == "borrow" or e.kind == "temp" then
      table.insert(borrows, e)
    end
  end
  for _, u in ipairs(m.events) do
    if u.kind == "use_end" then
      local t = u.text:lower()
      local pick
      for _, b in ipairs(borrows) do
        if not b.paired and b.line <= u.line then
          local fits = (t:find("immutable") and not b.mut) or (t:find("first") and true) or (not t:find("immutable") and not t:find("first"))
          -- the conflicting borrow itself is the ✗, not a bar, unless it's the only one
          if fits and (not b.primary or not pick) then
            if not pick or (pick.primary and not b.primary) then
              pick = b
            end
            if t:find("first") then
              break
            end
          end
        end
      end
      if pick then
        pick.paired = true
        table.insert(m.bars, { kind = pick.mut and "borrow_mut" or "borrow", from = pick.line, to = u.line, label = "borrow" })
      end
    end
  end

  -- values: from their declaration (or a temporary) to where they drop or move
  local start
  for _, e in ipairs(m.events) do
    if e.kind == "decl" or e.kind == "note_type" or e.kind == "temp" then
      start = start or e
    elseif (e.kind == "drop" or e.kind == "move") and start then
      table.insert(m.bars, { kind = "value", from = start.line, to = e.line, label = e.kind == "move" and "moved" or "dropped" })
      start = nil
    end
  end
  -- a move with no declaration in the labels still ends a life: from the first line shown
  for _, e in ipairs(m.events) do
    if e.kind == "move" then
      local covered = false
      for _, b in ipairs(m.bars) do
        if b.kind == "value" and b.to == e.line then
          covered = true
        end
      end
      if not covered then
        local lo = e.line
        for _, x in ipairs(m.events) do
          lo = math.min(lo, x.line)
        end
        table.insert(m.bars, { kind = "value", from = lo, to = e.line, label = "moved" })
      end
    end
  end

  -- E0373 has no lifetimes in its labels: the value lives to the end of the
  -- function, the closure may run past it. Draw both from the source.
  if m.code == "E0373" and src and m.name then
    local p
    for _, e in ipairs(m.events) do
      if e.primary then
        p = e
      end
    end
    if p then
      local decl
      for r = p.line, math.max(0, p.line - 200), -1 do
        if (src[r + 1] or ""):find("let%s+m?u?t?%s*" .. vim.pesc(m.name) .. "%f[^%w_]") then
          decl = r
          break
        end
      end
      local indent = #((src[p.line + 1] or ""):match("^%s*"))
      local fn_end
      for r = p.line + 1, math.min(#src - 1, p.line + 400) do
        local l = src[r + 1] or ""
        if l:match("^%s*}") and #(l:match("^%s*")) < indent then
          fn_end = r
          break
        end
      end
      if decl and fn_end then
        table.insert(m.events, { line = decl, col = 0, end_col = 0, text = "", kind = "decl" })
        table.insert(m.events, { line = fn_end, col = 0, end_col = 0, text = "`" .. m.name .. "` is dropped here, when the function returns", kind = "drop" })
        table.insert(m.bars, { kind = "value", from = decl, to = fn_end, label = "dropped" })
        table.insert(m.bars, { kind = "borrow", from = p.line, to = fn_end, escapes = true, label = "the closure keeps running" })
        table.sort(m.events, function(a, b)
          return a.line < b.line or (a.line == b.line and a.col < b.col)
        end)
      end
    end
  end

  m.lo, m.hi = math.huge, -1
  for _, e in ipairs(m.events) do
    m.lo, m.hi = math.min(m.lo, e.line), math.max(m.hi, e.end_line or e.line)
  end
  return m
end

-- what happens on these lines, as one or two sentences
function M.story(m, src)
  local function line_of(kind, primary)
    for _, e in ipairs(m.events) do
      if e.kind == kind and (primary == nil or e.primary == primary) then
        return e
      end
    end
  end
  local function binding(row) -- `let first = …` on that row → "first"
    local text = src and src[row + 1] or ""
    return text:match("let%s+mut%s+([%a_][%w_]*)") or text:match("let%s+([%a_][%w_]*)")
  end
  local name = m.name and ("`" .. m.name .. "`") or "the value"
  local p
  for _, e in ipairs(m.events) do
    if e.primary then
      p = e
    end
  end
  local bar
  for _, b in ipairs(m.bars) do
    if b.kind ~= "value" then
      bar = b
      break
    end
  end
  local L = function(e)
    return "line " .. ((type(e) == "table" and e.line or e) + 1)
  end
  if (m.code == "E0502" or m.code == "E0499" or m.code == "E0505" or m.code == "E0506") and bar and p then
    local who = binding(bar.from)
    local verb = ({ E0502 = "needs " .. name .. " mutably", E0499 = "takes a second `&mut` of " .. name, E0505 = "moves " .. name .. " out", E0506 = "assigns to " .. name })[m.code]
    local s = ("The borrow on %s%s lasts until its last use on %s. %s %s in between, while it's still alive."):format(L(bar.from), who and (" (`" .. who .. "`)") or "", L(bar.to), L(p):gsub("^l", "L"), verb)
    local text = src and src[p.line + 1] or ""
    if m.code == "E0502" and (text:find("%.push") or text:find("%.insert") or text:find("%.extend") or text:find("%.clear")) then
      s = s .. " A push can move the Vec to a bigger buffer (X-ray shows it reallocating), and the borrow would point at freed memory."
    end
    return s
  elseif m.code == "E0382" then
    local mv, use = line_of("move"), line_of("use_after")
    if mv and use then
      local into = binding(mv.line)
      return ("%s moves on %s%s. %s uses it again, but it isn't there anymore."):format(name, L(mv), into and (" into `" .. into .. "`") or "", L(use):gsub("^l", "L"))
    end
  elseif m.code == "E0597" then
    local drop, use = line_of("drop"), line_of("use_end")
    if drop and use then
      return ("%s is dropped on %s (its block ends there), but the reference to it is still used on %s."):format(name, L(drop), L(use))
    end
  elseif m.code == "E0716" then
    local temp, use = line_of("temp"), line_of("use_end")
    if temp and use then
      return ("The temporary on %s is freed at the end of that statement; %s still uses the reference to it."):format(L(temp), L(use))
    end
  elseif m.code == "E0373" and p then
    return ("The closure on %s borrows %s, but it may run after this function has returned and %s is gone."):format(L(p), name, name)
  end
  local parts = {}
  for _, e in ipairs(m.events) do
    if e.text ~= "" then
      parts[#parts + 1] = L(e) .. ": " .. e.text
    end
  end
  return table.concat(parts, " · ")
end

-- rendering ------------------------------------------------------------------

local EVENT = {
  borrow = { "●", nil },
  temp = { "●", "XrayShares" },
  use_end = { "◆", nil },
  drop = { "✕", "XrayAlert" },
  move = { "↷", "XrayWarn" },
  decl = { "○", "XrayOwns" },
  note_type = { "·", "XrayDim" },
  note = { "·", "XrayDim" },
}

local function event_hl(e)
  if e.primary then
    return "XrayAlert"
  end
  local spec = EVENT[e.kind]
  if spec and spec[2] then
    return spec[2]
  end
  if e.kind == "borrow" or e.kind == "use_end" then
    return e.mut and "XrayBorrowMut" or "XrayBorrow"
  end
  return "XrayValue"
end

local BAR_HL = { borrow = "XrayBorrow", borrow_mut = "XrayBorrowMut", value = "XrayOwns" }

-- Which source rows to draw: every row with an event, one row of context
-- around each, and ┆ for long stretches in between.
local function rows_to_show(m, nlines)
  local want = {}
  for _, e in ipairs(m.events) do
    for r = e.line - 1, (e.end_line or e.line) + 1 do
      want[r] = true
    end
  end
  -- short gaps are shown whole: the bars read better unbroken
  local out, last = {}, nil
  for r = math.max(0, m.lo - 1), math.min(nlines - 1, m.hi + 1) do
    if want[r] then
      if last and r - last > 1 then
        if r - last <= 4 then
          for g = last + 1, r - 1 do
            table.insert(out, g)
          end
        else
          table.insert(out, false)
        end
      end
      table.insert(out, r)
      last = r
    end
  end
  return out
end

-- The timeline: lines, highlights, targets (row → source line, 0-based).
function M.render(m, src, width)
  width = width or 110
  local lines, hls, targets = {}, {}, {}
  local function add(segs, target)
    local row, parts, byte = #lines, {}, 0
    for _, s in ipairs(segs) do
      if s[2] and #s[1] > 0 then
        hls[#hls + 1] = { row, byte, byte + #s[1], s[2] }
      end
      parts[#parts + 1] = s[1]
      byte = byte + #s[1]
    end
    lines[#lines + 1] = table.concat(parts)
    if target then
      targets[row] = target
    end
    return row, byte
  end

  local info = M.CODES[m.code]
  add({ { " " .. (m.code or "error") .. " ", "XrayBadgeMoved" }, { "  " .. (info and info.title or "the compiler says no"), "XrayName" } })
  for _, part in ipairs(map.wrap((m.message or ""):gsub("`", ""), width - 2)) do
    add({ { part, "XrayDim" } })
  end
  add({})

  -- gutter: one column pair per bar
  local nb = #m.bars
  local code_rows = rows_to_show(m, #src)
  local cw = 0
  for _, r in ipairs(code_rows) do
    if r then
      cw = math.max(cw, map.len(src[r + 1] or ""))
    end
  end
  cw = math.min(cw, math.max(30, width - nb * 2 - 8 - 34))
  local by_line = {}
  for _, e in ipairs(m.events) do
    by_line[e.line] = by_line[e.line] or {}
    table.insert(by_line[e.line], e)
  end

  for _, r in ipairs(code_rows) do
    if r == false then
      local segs = {}
      for _, b in ipairs(m.bars) do
        segs[#segs + 1] = { "┆ ", BAR_HL[b.kind] }
      end
      segs[#segs + 1] = { "      ┆", "XrayFaint" }
      add(segs)
    else
      local segs = {}
      for _, b in ipairs(m.bars) do
        local ch = "  "
        if r == b.from and r == b.to then
          ch = "◆━"
        elseif r == b.from then
          ch = "┏━"
        elseif r == b.to then
          ch = b.escapes and "┃▼" or "┗━"
        elseif r > b.from and r < b.to then
          ch = "┃ "
        end
        segs[#segs + 1] = { ch, BAR_HL[b.kind] }
      end
      local evs = by_line[r] or {}
      local has_err = false
      for _, e in ipairs(evs) do
        has_err = has_err or e.primary
      end
      segs[#segs + 1] = { string.format(" %4d ", r + 1), has_err and "XrayAlert" or "XrayDim" }
      segs[#segs + 1] = { "│ ", "XrayFaint" }
      local raw = (src[r + 1] or ""):gsub("\t", "    ")
      local code = map.pad(raw, cw)
      local row, code_start = add(segs)
      -- append code and notes to that row
      local line = lines[#lines] .. code
      local note_parts = {}
      for i, e in ipairs(evs) do
        if e.text ~= "" then
          local mark = e.primary and "✗" or ((EVENT[e.kind] or { "·" })[1])
          note_parts[#note_parts + 1] = { (i > 1 and "  " or "  ") .. mark .. " " .. e.text, event_hl(e) }
        end
      end
      -- spans inside the code, underlined in their event's color
      for _, e in ipairs(evs) do
        local s = math.min(e.col, #code)
        local stop = (e.end_line and e.end_line ~= e.line) and #raw or e.end_col
        stop = math.min(stop, #code)
        if stop > s then
          hls[#hls + 1] = { row, code_start + s, code_start + stop, e.primary and "XrayWhyPrimary" or "XrayWhySpan" }
        end
      end
      local byte = #line
      for _, np in ipairs(note_parts) do
        local text = map.clip(np[1], math.max(12, width - cw - nb * 2 - 8))
        hls[#hls + 1] = { row, byte, byte + #text, np[2] }
        line = line .. text
        byte = byte + #text
      end
      lines[#lines] = line
      targets[row] = r
    end
  end
  add({})
  -- the bars' legend, only for kinds present
  local legend, seen = {}, {}
  for _, b in ipairs(m.bars) do
    if not seen[b.kind] then
      seen[b.kind] = true
      legend[#legend + 1] = { "┃ ", BAR_HL[b.kind] }
      local words = { borrow = "shared borrow, start → last use", borrow_mut = "mutable borrow, start → last use", value = "value alive, let → dropped/moved" }
      legend[#legend + 1] = { (b.escapes and "borrow that escapes: the closure may run on (▼)" or words[b.kind]) .. "    ", "XrayDim" }
    end
  end
  legend[#legend + 1] = { "✗ ", "XrayAlert" }
  legend[#legend + 1] = { "what the compiler refuses", "XrayDim" }
  add(legend)
  add({})
  for i, part in ipairs(map.wrap(M.story(m, src), width - 2)) do
    add({ { i == 1 and "" or "", nil }, { part, "XrayValue" } })
  end
  add({})
  add({ { "a", "DeckKbd" }, { " fixes from rust-analyzer   ", "XrayDim" }, { "J", "DeckKbd" }, { " the rule and ways out   ", "XrayDim" }, { "Enter", "DeckKbd" }, { " jump to the line", "XrayDim" } })
  return lines, { hls = hls, targets = targets }
end

-- The Explain tab, as markdown for the deck renderer.
function M.explain(m, src)
  local info = M.CODES[m.code]
  local out = { "# " .. (m.code or "Error") .. ": " .. (info and info.title or "what the compiler says"), "" }
  if info then
    vim.list_extend(out, { "## The rule", "", info.rule, "" })
  end
  vim.list_extend(out, { "## Here", "", M.story(m, src), "" })
  if info then
    table.insert(out, "## Ways out")
    table.insert(out, "")
    for _, w in ipairs(info.ways) do
      table.insert(out, "- " .. w)
    end
    table.insert(out, "")
  end
  if #m.helps > 0 then
    vim.list_extend(out, { "## rustc suggests", "" })
    for _, h in ipairs(m.helps) do
      table.insert(out, "- " .. h:gsub("\n%s*", " "))
    end
    table.insert(out, "")
    table.insert(out, "`a` in the Timeline tab lists rust-analyzer's fixes, most of these among them.")
    table.insert(out, "")
  end
  if m.code then
    local ok, res = pcall(vim.fn.systemlist, { "rustc", "--explain", m.code })
    if ok and vim.v.shell_error == 0 and #res > 0 then
      vim.list_extend(out, { "## rustc --explain " .. m.code, "" })
      for _, l in ipairs(res) do
        -- its examples are ```compile_fail,E0502 blocks: plain ```rust renders them
        table.insert(out, (l:gsub("^```compile_fail.*$", "```rust"):gsub("^```edition%d+.*$", "```rust")))
      end
    end
  end
  return out
end

-- from nvim's diagnostics -----------------------------------------------------

local NOISE = { "Exact error occurred here", "Actual error occurred here", "Error originated from macro call here", "original diagnostic" }

local function noise(msg)
  for _, n in ipairs(NOISE) do
    if msg == n then
      return true
    end
  end
end

local function is_help(msg)
  return msg:match("^consider ") or msg:match("^to force ") or msg:match("^help: ") or msg:match("^try ")
end

-- The rustc error to explain for a cursor line: an error on it, the error a
-- label on it belongs to, or the nearest error in the buffer.
function M.find(buf, lnum)
  local errors, hints = {}, {}
  for _, d in ipairs(vim.diagnostic.get(buf)) do
    if d.source == "rustc" and d.user_data and d.user_data.lsp then
      if d.severity == vim.diagnostic.severity.ERROR then
        table.insert(errors, d)
      else
        table.insert(hints, d)
      end
    end
  end
  if #errors == 0 then
    return nil
  end
  for _, d in ipairs(errors) do
    if d.lnum == lnum then
      return d
    end
  end
  for _, h in ipairs(hints) do
    if h.lnum == lnum then
      for _, r in ipairs(h.user_data.lsp.relatedInformation or {}) do
        if r.message == "original diagnostic" then
          for _, d in ipairs(errors) do
            if d.lnum == r.location.range.start.line and d.code == h.code then
              return d
            end
          end
        end
      end
    end
  end
  for _, d in ipairs(errors) do
    for _, r in ipairs(d.user_data.lsp.relatedInformation or {}) do
      if r.location.range.start.line == lnum then
        return d
      end
    end
  end
  table.sort(errors, function(a, b)
    return math.abs(a.lnum - lnum) < math.abs(b.lnum - lnum)
  end)
  return errors[1]
end

-- An LSP diagnostic in the shape M.model takes.
function M.from_lsp(d, buf)
  local uri = vim.uri_from_bufnr(buf)
  local lsp = d.user_data.lsp
  local head, primary = d.message:match("^(.-)\n(.*)$")
  local diag = {
    code = type(d.code) == "string" and d.code or (lsp.code and tostring(lsp.code)),
    message = head or d.message,
    labels = { { line = d.lnum, col = d.col, end_line = d.end_lnum, end_col = d.end_col, text = primary or "", primary = true } },
    helps = {},
    rendered = lsp.data and lsp.data.rendered,
  }
  for _, r in ipairs(lsp.relatedInformation or {}) do
    if r.location.uri == uri and not noise(r.message) then
      local rg = r.location.range
      if is_help(r.message) then
        table.insert(diag.helps, r.message)
        -- rustc's fixes hang on the help's own span (the `.clone()` goes after the move)
        diag.fix_at = diag.fix_at or {}
        table.insert(diag.fix_at, { rg.start.line, rg.start.character, rg["end"].line, rg["end"].character })
      else
        table.insert(diag.labels, { line = rg.start.line, col = rg.start.character, end_line = rg["end"].line, end_col = rg["end"].character, text = r.message, primary = false })
      end
    end
  end
  return diag
end

-- the panel ---------------------------------------------------------------------

local panel
local current -- { m, src, buf, diag }

local function tab_timeline()
  if not current then
    return { "No error to explain." }
  end
  local lines, extra = M.render(current.m, current.src, panel.width)
  -- targets: rows → LSP locations in the source buffer
  local uri = vim.uri_from_bufnr(current.buf)
  local t = {}
  for row, r in pairs(extra.targets) do
    t[row] = { uri = uri, range = { start = { line = r, character = 0 }, ["end"] = { line = r, character = 0 } } }
  end
  extra.targets = t
  return lines, extra
end

local function tab_explain()
  return current and M.explain(current.m, current.src) or { "No error." }
end

local function tab_compiler()
  local text = current and current.m.rendered or "rust-analyzer didn't send the full message."
  return vim.split(text, "\n", { plain = true })
end

-- rust-analyzer's fixes: where rustc's help points (that's where its quick
-- fixes live), else at the error itself
local function fixes()
  if not current then
    return
  end
  local d = current.diag
  local at = (current.fix_at and current.fix_at[1]) or { d.lnum, d.col, d.end_lnum, d.end_col }
  panel:hide()
  local win = vim.fn.bufwinid(current.buf)
  if win ~= -1 then
    vim.api.nvim_set_current_win(win)
    vim.api.nvim_win_set_cursor(win, { at[1] + 1, at[2] })
  end
  -- nvim gathers the diagnostics on that line itself; rustc's suggestion is among them
  vim.lsp.buf.code_action()
end

local HELP = {
  "Why not?: a borrow-checker error as a timeline",
  "",
  "  j/k        scroll · C-h then j/k for the other tabs",
  "  a          rust-analyzer's fixes for this error",
  "  Enter      jump to that line",
  "  q / Esc    close (Space Rw opens it again)",
  "",
  "  ┃ green  a shared borrow, from where it starts to its last use",
  "  ┃ red    a mutable borrow",
  "  ┃ blue   a value's life, from its let to where it's dropped or moved",
  "  ✗        the line the compiler refuses",
}

function M.open()
  local buf = vim.api.nvim_get_current_buf()
  local lnum = vim.api.nvim_win_get_cursor(0)[1] - 1
  local d = M.find(buf, lnum)
  if not d then
    vim.notify("Why not?: no compiler error in this file (save, and give rust-analyzer a moment)", vim.log.levels.INFO)
    return
  end
  theme.apply()
  M.colors()
  local diag = M.from_lsp(d, buf)
  local src = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  current = { m = M.model(diag, src), src = src, buf = buf, diag = d, fix_at = diag.fix_at }
  if not panel then
    panel = require("vango.deck.ui").new({
      id = "whynot",
      title = "Why not?",
      icon = "󰅙",
      tabs = {},
      help_lines = HELP,
      keys = { { "a", fixes, "Why not?: fixes from rust-analyzer" } },
    })
  end
  panel:set_tabs({
    { name = "Timeline", lines = tab_timeline, raw = true, ft = "xray" },
    { name = "Explain", lines = tab_explain },
    { name = "Compiler", lines = tab_compiler, raw = true, ft = "xray" },
  }, "Why not? · " .. (diag.code or "error"))
  panel:show({ tab = 1, focus = "content" })
end

function M.colors()
  local p = require("vango.deck.theme").palette()
  vim.api.nvim_set_hl(0, "XrayWhyPrimary", { fg = p.alert, undercurl = true, sp = p.alert, bold = true })
  vim.api.nvim_set_hl(0, "XrayWhySpan", { underline = true, sp = p.accent2 })
end

return M
