-- Where locals live in the source: the line each one is declared on (let,
-- for, if let, parameters; in C and C++ declarations, parameters and
-- range-for), found with treesitter in the function around the stop line.
-- Inline X-ray text goes on those lines.

local M = {}

local query

local function get_query()
  if query == nil then
    local ok, q = pcall(vim.treesitter.query.parse, "rust", [[
      (let_declaration pattern: (_) @pat)
      (let_condition pattern: (_) @pat)
      (for_expression pattern: (_) @pat)
      (parameter pattern: (_) @pat)
      (closure_parameters (_) @pat)
      (self_parameter) @pat
    ]])
    query = ok and q or false
  end
  return query or nil
end

-- names bound by a pattern: `(a, mut b)`, `Point { x, y: py }`, `Some(v)`
local function names(node, buf, out)
  local t = node:type()
  if t == "identifier" or t == "shorthand_field_identifier" or t == "self" then
    out[#out + 1] = vim.treesitter.get_node_text(node, buf)
    return out
  end
  if t == "self_parameter" then
    out[#out + 1] = "self"
    return out
  end
  for child, field in node:iter_children() do
    -- `Some` in `Some(v)` and the field name in `y: py` are not bindings
    if field ~= "type" and field ~= "name" and child:named() then
      names(child, buf, out)
    end
  end
  return out
end

-- The function (or closure) around a 1-based line.
local function enclosing(buf, line)
  local ok, parser = pcall(vim.treesitter.get_parser, buf, "rust")
  if not ok or not parser then
    return nil
  end
  local root = parser:parse()[1]:root()
  local text = vim.api.nvim_buf_get_lines(buf, line - 1, line, false)[1] or ""
  local col = #(text:match("^%s*") or "")
  local node = root:named_descendant_for_range(line - 1, col, line - 1, col)
  while node and node:type() ~= "function_item" and node:type() ~= "closure_expression" do
    node = node:parent()
  end
  return node
end

-- C and C++: declarations, parameters, range-for and structured bindings.
local c_queries = {}

local function get_c_query(lang)
  if c_queries[lang] == nil then
    local src = [[
      (declaration declarator: (_) @decl)
      (parameter_declaration declarator: (_) @decl)
    ]]
    if lang == "cpp" then
      src = src .. [[
        (for_range_loop declarator: (_) @decl)
        (optional_parameter_declaration declarator: (_) @decl)
      ]]
    end
    local ok, q = pcall(vim.treesitter.query.parse, lang, src)
    c_queries[lang] = ok and q or false
  end
  return c_queries[lang] or nil
end

-- names a C declarator binds: `*p`, `a[4]`, `x = 1`, `&r`, `[a, b]`
local C_SKIP = { value = true, size = true, parameters = true, type = true, default_value = true, arguments = true }

local function c_names(node, buf, out)
  local t = node:type()
  if t == "identifier" then
    out[#out + 1] = vim.treesitter.get_node_text(node, buf)
    return out
  end
  if t == "function_declarator" then
    return out -- a prototype, not a local
  end
  for child, field in node:iter_children() do
    if child:named() and not C_SKIP[field] then
      c_names(child, buf, out)
    end
  end
  return out
end

local C_FN = { function_definition = true, lambda_expression = true }

local function decls_c(buf, line, lang)
  local out = {}
  local ok, parser = pcall(vim.treesitter.get_parser, buf, lang)
  local q = get_c_query(lang)
  if not ok or not parser or not q then
    return out
  end
  local root = parser:parse()[1]:root()
  local text = vim.api.nvim_buf_get_lines(buf, line - 1, line, false)[1] or ""
  local col = #(text:match("^%s*") or "")
  local fn = root:named_descendant_for_range(line - 1, col, line - 1, col)
  while fn and not C_FN[fn:type()] do
    fn = fn:parent()
  end
  -- a lambda first, then what it captures from the functions around it
  local limit = line - 1
  while fn do
    local found = {}
    for _, node in q:iter_captures(fn, buf, fn:start(), limit + 1) do
      local row = node:start()
      if row < limit then
        for _, n in ipairs(c_names(node, buf, {})) do
          found[n] = row
        end
      end
    end
    for n, row in pairs(found) do
      if out[n] == nil then
        out[n] = row
      end
    end
    if fn:type() ~= "lambda_expression" then
      break
    end
    limit = fn:start()
    fn = fn:parent()
    while fn and not C_FN[fn:type()] do
      fn = fn:parent()
    end
  end
  return out
end

-- name → 0-based row of its latest declaration before the stop line.
-- Declarations on the stop line itself haven't run yet: left out.
function M.decls(buf, line)
  local ft = vim.bo[buf].filetype
  if ft == "c" or ft == "cpp" then
    return decls_c(buf, line, ft)
  end
  local out = {}
  local fn = enclosing(buf, line)
  local q = get_query()
  if fn and q then
    -- the closure first, then what it captures from the functions around it
    local limit = line - 1
    while fn do
      local found = {}
      for _, node in q:iter_captures(fn, buf, fn:start(), limit + 1) do
        local row = node:start()
        if row < limit then
          for _, n in ipairs(names(node, buf, {})) do
            found[n] = row -- captures come in order, so shadowing keeps the latest
          end
        end
      end
      for n, row in pairs(found) do
        if out[n] == nil then
          out[n] = row
        end
      end
      if fn:type() ~= "closure_expression" then
        break
      end
      limit = fn:start()
      fn = fn:parent()
      while fn and fn:type() ~= "function_item" and fn:type() ~= "closure_expression" do
        fn = fn:parent()
      end
    end
    return out
  end
  -- no treesitter: look back for `let name` / `let mut name`
  local from = math.max(0, line - 300)
  local lines = vim.api.nvim_buf_get_lines(buf, from, line - 1, false)
  for i, l in ipairs(lines) do
    for n in l:gmatch("let%s+m?u?t?%s*([%a_][%w_]*)") do
      out[n] = from + i - 1
    end
  end
  return out
end

-- Which slots were moved from, from the model's "two owners" notes: of the
-- two, the one whose name shows up in the other's declaration line was moved
-- into it (`let taken = words;`). Returns { [slot id] = "taken" }.
function M.moved(g, buf, decls)
  local out = {}
  for _, n in ipairs(g.notes or {}) do
    if n.kind == "two-owners" and #n.slots == 2 then
      local a, b = g.slots[n.slots[1] + 1], g.slots[n.slots[2] + 1]
      local function uses(x, y) -- x's declaration line mentions y
        local row = decls[x.name]
        local text = row and vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1] or ""
        local rhs = text:match("=(.*)$") or ""
        return rhs:find("%f[%w_]" .. vim.pesc(y.name) .. "%f[^%w_]") ~= nil
      end
      if uses(b, a) then
        out[a.id] = b.name
      elseif uses(a, b) then
        out[b.id] = a.name
      end
    end
  end
  return out
end

-- The buffer showing a file, if it's loaded.
function M.buf_for(file)
  if not file then
    return nil
  end
  local b = vim.fn.bufnr(file)
  if b > 0 and vim.api.nvim_buf_is_loaded(b) then
    return b
  end
end

return M
