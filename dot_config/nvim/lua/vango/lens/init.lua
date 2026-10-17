-- The Rust lens: K shows the hover (with size/align from rust-analyzer), K again
-- opens a Deck-style panel about the symbol under the cursor:
--   types and variables → Overview · Layout · Methods · Traits
--   functions           → Overview · Calls · Tests
-- Layouts come from rust-analyzer (concrete types) and lens-sizes' sizes.json
-- (generic types: every instantiation the crate builds; `r` in the lens rebuilds it).

local M = {}

local layout = require("vango.lens.layout")
local impls = require("vango.lens.impls")

local panel
local field_types -- defined before the layout tab
local state = {} -- data for the symbol on display; replaced on every open
local token = 0 -- bumps per open, so late answers for an old symbol are dropped

local HELP = {
  "Lens",
  "  j / k      scroll",
  "  C-h        tab list (j/k there switches tabs)",
  "  J / K      next / previous tab",
  "  ⏎          jump to the method, caller or test",
  "  r          rebuild layouts of generic types (nightly)",
  "  q  Esc     close",
  "",
  "From code",
  "  K          hover with size and align",
  "  K K        this lens",
}

-- helpers -----------------------------------------------------------------

local function ra(buf)
  return vim.lsp.get_clients({ bufnr = buf, name = "rust-analyzer" })[1]
end

local function request(client, method, params, buf, my_token, cb)
  client:request(method, params, function(err, result)
    vim.schedule(function()
      if my_token == token then
        cb(err, result)
      end
    end)
  end, buf)
end

local function refresh()
  if panel then
    panel:refresh()
  end
end

-- code blocks of a hover, and what kind of symbol its signature describes
local function read_hover(md)
  local blocks, cur = {}, nil
  local prose = {}
  for _, l in ipairs(vim.split(md or "", "\n", { plain = true })) do
    if l:match("^```") then
      if cur then
        table.insert(blocks, table.concat(cur, "\n"))
        cur = nil
      else
        cur = {}
      end
    elseif cur then
      table.insert(cur, l)
    else
      table.insert(prose, l)
    end
  end
  -- rust-analyzer puts the module path first, then the item
  local sig = blocks[#blocks >= 2 and 2 or 1] or ""
  local kind = "other"
  local first = sig:match("^%s*(.-)%s*$") or ""
  if first:match("^let ") or first:match("^[%w_]+: ") or first:match("^pub[%w%(%)]* [%w_]+: ") then
    kind = "value"
  elseif first:match("%f[%w]fn%f[%W]") then
    kind = "fn"
  elseif first:match("%f[%w]struct%f[%W]") or first:match("%f[%w]enum%f[%W]") or first:match("%f[%w]union%f[%W]") then
    kind = "type"
  elseif first:match("%f[%w]trait%f[%W]") then
    kind = "trait"
  elseif first:match("%f[%w]type%f[%W]") then
    kind = "type"
  end
  local size_line = md and md:match("(size = [^\n]+)")
  return { blocks = blocks, sig = sig, kind = kind, size_line = size_line, generic = first:match("<") ~= nil }
end

-- target/lens/sizes.json for the buffer's crate (looks in every ancestor's target/)
local function sizes_path(buf)
  local root = vim.fs.root(buf, "Cargo.toml")
  if not root then
    return nil, nil
  end
  local dir = root
  while dir do
    local p = dir .. "/target/lens/sizes.json"
    if vim.uv.fs_stat(p) then
      return p, root
    end
    local parent = vim.fs.dirname(dir)
    if parent == dir then
      break
    end
    dir = parent
  end
  return nil, root
end

local function load_sizes(buf)
  local p = sizes_path(buf)
  if not p then
    return nil
  end
  local ok, data = pcall(function()
    return vim.json.decode(table.concat(vim.fn.readfile(p), "\n"))
  end)
  if ok then
    data._path, data._mtime = p, vim.fn.getftime(p)
    return data
  end
end

local function rel(uri)
  local path = vim.uri_to_fname(uri)
  local cwd = vim.uv.cwd() or ""
  if path:sub(1, #cwd) == cwd then
    return path:sub(#cwd + 2)
  end
  return path:gsub("^.*/library/", "std/"):gsub("^" .. vim.env.HOME, "~")
end

-- tabs --------------------------------------------------------------------

local function tab_overview()
  local lines = { "# " .. (state.name or "?"), "" }
  local md = state.hover_md or "_asking rust-analyzer…_"
  -- the first block is the module path (`lens_demo`); the lens title says enough
  md = md:gsub("^%s*```rust\n[%w_:]+\n```\n*", "", 1)
  for _, l in ipairs(vim.split(md, "\n", { plain = true })) do
    table.insert(lines, l)
  end
  local glance = {}
  if state.summary then
    table.insert(glance, ("- %d bytes, align %d, %d bytes of padding"):format(state.summary.size, state.summary.align, state.summary.padding))
  end
  if state.impls then
    local inherent, traits = 0, 0
    for _, i in ipairs(state.impls) do
      if i.trait then
        traits = traits + 1
      else
        inherent = inherent + #i.methods
      end
    end
    table.insert(glance, ("- %d methods of its own, %d trait impls"):format(inherent, traits))
  end
  if state.derives and #state.derives > 0 then
    table.insert(glance, "- derives " .. table.concat(state.derives, ", "))
  end
  if state.incoming then
    table.insert(glance, ("- called from %d places, calls %d functions"):format(#state.incoming, #(state.outgoing or {})))
  end
  if #glance > 0 then
    table.insert(lines, "")
    table.insert(lines, "## At a glance")
    table.insert(lines, "")
    vim.list_extend(lines, glance)
  end
  return lines
end

-- Field types from the definition in the hover (`pub key: K`), with the generic
-- parameters replaced by an instantiation's arguments: Node<String, u64> → key: String.
local function split_args(s)
  local out, depth, cur = {}, 0, ""
  for ch in s:gmatch(".") do
    if ch == "<" or ch == "(" or ch == "[" then
      depth = depth + 1
    elseif ch == ">" or ch == ")" or ch == "]" then
      depth = depth - 1
    end
    if ch == "," and depth == 0 then
      table.insert(out, vim.trim(cur))
      cur = ""
    else
      cur = cur .. ch
    end
  end
  if vim.trim(cur) ~= "" then
    table.insert(out, vim.trim(cur))
  end
  return out
end

local function short(ty)
  -- std::string::String → String, alloc::boxed::Box<…> → Box<…>
  return (ty:gsub("[%w_]+::", ""))
end

function field_types(inst_name)
  local sig = state.sig or ""
  local params = sig:match("^[^{]-[%w_]+%s*<([^>]*)>") -- struct Node<K, V> {
  local args = inst_name:match("^[^<]+<(.*)>$")
  local subst = {}
  if params and args then
    local ps, as = split_args(params), split_args(args)
    for i, p in ipairs(ps) do
      local name = p:match("^'?[%w_]+")
      if name and as[i] then
        subst[name] = short(as[i])
      end
    end
  end
  local out = {}
  for line in sig:gmatch("[^\n]+") do
    local v = line:match("^%s*([%w_]+)%s*[%({]") or line:match("^%s*([%w_]+),%s*$")
    if v and not line:match(":") and not line:match("struct") and not line:match("enum") then
      -- tuple variant: Node(Node<K, V>) → field "0"
      local inner = line:match("^%s*[%w_]+%((.*)%),?%s*$")
      if inner then
        for i, t in ipairs(split_args(inner)) do
          out[v .. "." .. (i - 1)] = t:gsub("%f[%w_]([%w_]+)%f[^%w_]", function(w)
            return subst[w] or w
          end)
        end
      end
    end
    local fname, fty = line:match("^%s*[%w_%(%)]*%s*([%w_]+)%s*:%s*(.-),?%s*$")
    if fname and fty and not line:match("struct ") then
      fname = line:match("([%w_]+)%s*:") or fname
      out[fname] = fty:gsub("%f[%w_]([%w_]+)%f[^%w_]", function(w)
        return subst[w] or w
      end)
    end
  end
  return out
end

local function tab_layout()
  local lines, hls = {}, {}
  if state.layout_ra then
    local l, h, summary = layout.render_ra(state.layout_ra)
    if l then
      lines, hls = l, h
      state.summary = summary
    end
  end
  -- every instantiation the last nightly build recorded (generic types live here)
  local insts = state.sizes and state.sizes.by_base and state.sizes.by_base[state.base or ""]
  -- skipped when rust-analyzer already showed this exact value's layout
  if insts and #insts > 0 and not (state.layout_ra and state.layout_ra.nodes) then
    if #lines > 0 then
      table.insert(lines, "")
    end
    table.insert(lines, ("# Instantiations in this crate (%d)"):format(#insts))
    table.insert(lines, "")
    table.insert(lines, ("From the last nightly build, %s. `r` rebuilds."):format(os.date("%H:%M %d/%m", state.sizes._mtime)))
    table.insert(lines, "")
    for _, name in ipairs(insts) do
      local l = vim.deepcopy(state.sizes.types[name])
      local types = field_types(name)
      for _, f in ipairs(l.fields or {}) do
        f.ty = types[f.name]
      end
      for _, v in ipairs(l.variants or {}) do
        for _, f in ipairs(v.fields or {}) do
          f.ty = types[v.name .. "." .. f.name]
        end
      end
      local _, _, summary = layout.render_sizes(l, lines, hls)
      state.summary = state.summary or summary
    end
  end
  if #lines == 0 then
    if state.layout_pending then
      lines = { "_asking rust-analyzer for the layout…_" }
    elseif state.generic or state.kind == "type" then
      lines = {
        "# No layout yet",
        "",
        "This type is generic (or rust-analyzer can't see a concrete instance here), so its size",
        "depends on the types filled in. Press `r` to build the crate once with nightly and record",
        "every instantiation it really uses, like `Node<String, u64>`.",
        "",
        "Hovering a variable of a concrete type (`let n: Node<String, u64>`) also works right away.",
      }
    else
      lines = { "# No layout", "", "Nothing with a memory layout under the cursor." }
    end
  end
  if state.sizes_status then
    table.insert(lines, "")
    table.insert(lines, "> " .. state.sizes_status)
  end
  return lines, { hls = hls }
end

local RECV = {
  ["self"] = { "self", "LensRecvMove" },
  ["&self"] = { "&self", "LensRecvRef" },
  ["&mut self"] = { "&mut self", "LensRecvMut" },
}

local function method_row(lines, hls, targets, m)
  local r = m.assoc and { m.assoc == "type_item" and "type" or "const", "LensRecvNone" }
    or RECV[m.recv or ""]
    or { "assoc", "LensRecvNone" }
  local row = #lines
  local line = (" %-10s %s"):format(r[1], m.sig)
  table.insert(lines, line)
  table.insert(hls, { row, 1, 1 + #r[1], r[2] })
  targets[row] = m.loc
end

local function tab_methods()
  if not state.impls then
    return { state.impls_pending and "_looking up impl blocks…_" or "No impl blocks found." }
  end
  local lines, hls, targets = {}, {}, {}
  table.insert(lines, "Receivers: `self` takes ownership · `&self` borrows · `&mut self` borrows mutably · `assoc` has no self")
  table.insert(lines, "")
  local any = false
  for _, impl in ipairs(state.impls) do
    if not impl.trait and #impl.methods > 0 then
      any = true
      table.insert(lines, "## " .. impl.header)
      targets[#lines - 1] = impl.loc
      table.insert(lines, ("_%s_"):format(rel(impl.loc.uri)))
      table.insert(lines, "")
      for _, m in ipairs(impl.methods) do
        method_row(lines, hls, targets, m)
      end
      table.insert(lines, "")
    end
  end
  if not any then
    table.insert(lines, "No inherent methods: everything it can do comes from traits (see Traits).")
  end
  return lines, { hls = hls, targets = targets }
end

local function tab_traits()
  local lines, hls, targets = {}, {}, {}
  if state.derives and #state.derives > 0 then
    table.insert(lines, "## Derived")
    table.insert(lines, "")
    table.insert(lines, " " .. table.concat(state.derives, " · "))
    table.insert(hls, { #lines - 1, 1, #lines[#lines], "LensF2Text" })
    table.insert(lines, "")
  end
  if not state.impls then
    table.insert(lines, state.impls_pending and "_looking up trait impls…_" or "No trait impls found.")
    return lines, { hls = hls }
  end
  local traits = vim.tbl_filter(function(i)
    return i.trait ~= nil
  end, state.impls)
  table.sort(traits, function(a, b)
    return a.trait < b.trait
  end)
  table.insert(lines, ("## Implemented traits (%d)"):format(#traits))
  table.insert(lines, "")
  for _, impl in ipairs(traits) do
    local row = #lines
    local names = vim.tbl_map(function(m)
      return m.name
    end, impl.methods)
    local line = (" %-22s %s"):format(impl.trait, #names > 0 and ("· " .. table.concat(names, ", ")) or "")
    table.insert(lines, line)
    table.insert(hls, { row, 1, 1 + #impl.trait, "LensF1Text" })
    targets[row] = impl.loc
    local hrow = #lines
    table.insert(lines, "   " .. impl.header)
    table.insert(hls, { hrow, 0, #lines[#lines], "LensDim" })
    targets[hrow] = impl.loc
  end
  return lines, { hls = hls, targets = targets }
end

local function call_rows(lines, hls, targets, list, field)
  for _, c in ipairs(list) do
    local item = c[field]
    local row = #lines
    local where = ("%s:%d"):format(rel(item.uri), item.selectionRange.start.line + 1)
    table.insert(lines, (" %-34s %s"):format(item.name, where))
    table.insert(hls, { row, 1, 1 + #item.name, "LensF1Text" })
    table.insert(hls, { row, #lines[#lines] - #where, #lines[#lines], "LensDim" })
    targets[row] = { uri = item.uri, range = item.selectionRange }
  end
end

local function tab_calls()
  local lines, hls, targets = {}, {}, {}
  if not state.incoming then
    return { state.calls_pending and "_asking for the call hierarchy…_" or "No call information." }
  end
  table.insert(lines, ("## Called by (%d)"):format(#state.incoming))
  table.insert(lines, "")
  call_rows(lines, hls, targets, state.incoming, "from")
  table.insert(lines, "")
  table.insert(lines, ("## Calls (%d)"):format(#(state.outgoing or {})))
  table.insert(lines, "")
  call_rows(lines, hls, targets, state.outgoing or {}, "to")
  return lines, { hls = hls, targets = targets }
end

local function tab_tests()
  if not state.tests then
    return { state.tests_pending and "_looking for related tests…_" or "No related tests." }
  end
  if #state.tests == 0 then
    return { "No tests call this directly." }
  end
  local lines, hls, targets = { ("## Related tests (%d)"):format(#state.tests), "" }, {}, {}
  for _, t in ipairs(state.tests) do
    local r = t.runnable
    local loc = r.location
    local row = #lines
    table.insert(lines, " " .. r.label)
    table.insert(hls, { row, 1, 1 + #r.label, "LensF2Text" })
    if loc then
      targets[row] = { uri = loc.targetUri, range = loc.targetSelectionRange or loc.targetRange }
    end
  end
  table.insert(lines, "")
  table.insert(lines, "⏎ jumps to the test; `Space tn` there runs it.")
  return lines, { hls = hls, targets = targets }
end

-- lens-sizes ----------------------------------------------------------------

local function run_lens_sizes(buf, quiet, on_done)
  local _, root = sizes_path(buf)
  if not root or vim.fn.executable("lens-sizes") == 0 then
    state.sizes_status = "lens-sizes isn't installed (cargo install --path ~/dev/project/genomlysning/crates/lens-sizes)"
    return on_done and on_done(false)
  end
  if not quiet then
    state.sizes_status = "building with nightly to record layouts…"
    refresh()
  end
  vim.system({ "lens-sizes", "--manifest-path", root .. "/Cargo.toml" }, { text = true }, function(res)
    vim.schedule(function()
      if res.code == 0 then
        state.sizes = load_sizes(buf)
        state.sizes_status = nil
      else
        local msg = (res.stderr or ""):gsub("^lens%-sizes: ", ""):gsub("\n.*", "")
        state.sizes_status = "no fresh layouts: " .. msg
      end
      if not quiet then
        refresh()
      end
      if on_done then
        on_done(res.code == 0)
      end
    end)
  end)
end

-- open ----------------------------------------------------------------------

local function get_panel()
  if panel then
    return panel
  end
  layout.colors()
  vim.api.nvim_create_autocmd("ColorScheme", { callback = layout.colors })
  panel = require("vango.deck.ui").new({
    id = "lens",
    title = "Lens",
    icon = "",
    tabs = {},
    help_lines = HELP,
    keys = {
      {
        "r",
        function()
          run_lens_sizes(state.buf, false)
        end,
        "Lens: rebuild layouts (nightly)",
      },
    },
  })
  return panel
end

local TABS = {
  type = { { "Overview", tab_overview }, { "Layout", tab_layout, true }, { "Methods", tab_methods, true }, { "Traits", tab_traits, true } },
  value = { { "Overview", tab_overview }, { "Layout", tab_layout, true }, { "Methods", tab_methods, true }, { "Traits", tab_traits, true } },
  fn = { { "Overview", tab_overview }, { "Calls", tab_calls, true }, { "Tests", tab_tests, true } },
  trait = { { "Overview", tab_overview }, { "Implementors", tab_traits, true } },
  other = { { "Overview", tab_overview } },
}

local function fetch_impls(client, buf, my, params)
  state.impls_pending = true
  request(client, "textDocument/implementation", params, buf, my, function(_, result)
    state.impls_pending = false
    local list = {}
    local seen = {}
    for _, loc in ipairs(result or {}) do
      local impl = impls.read_impl(loc)
      if impl and not seen[impl.header .. impl.loc.uri] then
        seen[impl.header .. impl.loc.uri] = true
        table.insert(list, impl)
      end
    end
    state.impls = list
    refresh()
  end)
end

function M.open()
  local buf = vim.api.nvim_get_current_buf()
  local client = ra(buf)
  if not client then
    vim.notify("Lens: rust-analyzer isn't attached here", vim.log.levels.WARN)
    return
  end
  token = token + 1
  local my = token
  local params = vim.lsp.util.make_position_params(0, client.offset_encoding)
  local name = vim.fn.expand("<cword>")
  state = { buf = buf, name = name, base = name, sizes = load_sizes(buf), layout_pending = true }

  request(client, "textDocument/hover", params, buf, my, function(_, hover)
    local md = hover and hover.contents and (hover.contents.value or hover.contents) or ""
    if type(md) ~= "string" then
      md = ""
    end
    local h = read_hover(md)
    state.hover_md, state.kind, state.generic, state.sig = md, h.kind, h.generic, h.sig
    -- the base name for sizes.json: a value's type, or the item itself
    if h.kind == "value" then
      local ty = h.sig:match(":%s*&?%s*m?u?t?%s*([%w_:]+)")
      state.base = ty and ty:gsub("^.*::", "") or name
    end

    local p = get_panel()
    local tabs = {}
    for _, t in ipairs(TABS[h.kind] or TABS.other) do
      table.insert(tabs, { name = t[1], lines = t[2], raw = t[3] })
    end
    p:set_tabs(tabs, "Lens · " .. name)
    p:show({ tab = 1, focus = "content" })

    -- everything else in parallel; each answer refreshes the panel
    if h.kind == "type" or h.kind == "value" then
      request(client, "rust-analyzer/viewRecursiveMemoryLayout", params, buf, my, function(_, res)
        state.layout_pending = false
        state.layout_ra = res
        refresh()
      end)
      if h.kind == "type" then
        fetch_impls(client, buf, my, params)
        request(client, "textDocument/definition", params, buf, my, function(_, defs)
          local d = defs and (defs[1] or defs)
          if d and (d.uri or d.targetUri) then
            state.derives = impls.derives(d)
            refresh()
          end
        end)
      else
        request(client, "textDocument/typeDefinition", params, buf, my, function(_, defs)
          local d = defs and (defs[1] or defs)
          if not (d and (d.uri or d.targetUri)) then
            state.impls = {}
            refresh()
            return
          end
          state.derives = impls.derives(d)
          local r = d.targetSelectionRange or d.range
          fetch_impls(client, buf, my, { textDocument = { uri = d.targetUri or d.uri }, position = r.start })
        end)
      end
    elseif h.kind == "trait" then
      state.layout_pending = false
      fetch_impls(client, buf, my, params)
    elseif h.kind == "fn" then
      state.layout_pending = false
      state.calls_pending, state.tests_pending = true, true
      request(client, "textDocument/prepareCallHierarchy", params, buf, my, function(_, items)
        local item = items and items[1]
        if not item then
          state.calls_pending = false
          state.incoming, state.outgoing = {}, {}
          refresh()
          return
        end
        request(client, "callHierarchy/incomingCalls", { item = item }, buf, my, function(_, inc)
          state.incoming = inc or {}
          state.calls_pending = false
          refresh()
        end)
        request(client, "callHierarchy/outgoingCalls", { item = item }, buf, my, function(_, out)
          state.outgoing = out or {}
          refresh()
        end)
      end)
      request(client, "rust-analyzer/relatedTests", params, buf, my, function(_, tests)
        state.tests_pending = false
        state.tests = tests or {}
        refresh()
      end)
    else
      state.layout_pending = false
    end
  end)
end

--- K: hover; K while that hover is showing: the lens
function M.K()
  local w = vim.b.lsp_floating_preview
  if w and vim.api.nvim_win_is_valid(w) then
    pcall(vim.api.nvim_win_close, w, true)
    M.open()
  else
    vim.lsp.buf.hover({ border = "rounded" })
  end
end

--- keep sizes.json fresh on save, for crates that have one (opt-in by pressing r once)
function M.setup()
  local timers = {}
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = vim.api.nvim_create_augroup("vango_lens_sizes", { clear = true }),
    pattern = "*.rs",
    callback = function(ev)
      local p, root = sizes_path(ev.buf)
      if not p or not root then
        return
      end
      if timers[root] then
        timers[root]:stop()
      end
      timers[root] = vim.defer_fn(function()
        timers[root] = nil
        run_lens_sizes(ev.buf, true)
      end, 3000)
    end,
  })
end

return M
