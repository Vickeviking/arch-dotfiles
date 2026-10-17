-- What a type can do: its impl blocks (inherent methods and trait impls) and
-- derives, read with treesitter from the files rust-analyzer points at. Works
-- for std types too, since rust-src is installed.

local M = {}

local file_cache = {} -- path -> { text, root }

local function parse_file(path)
  local hit = file_cache[path]
  local mtime = vim.fn.getftime(path)
  if hit and hit.mtime == mtime then
    return hit
  end
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then
    return nil
  end
  local text = table.concat(lines, "\n")
  local parser = vim.treesitter.get_string_parser(text, "rust")
  local root = parser:parse()[1]:root()
  hit = { text = text, root = root, mtime = mtime }
  file_cache[path] = hit
  return hit
end

local function node_text(node, text)
  return vim.treesitter.get_node_text(node, text)
end

local function squash(s)
  return (s:gsub("%s+", " "):gsub("^ ", ""):gsub(" $", ""))
end

local function enclosing(root, row, col, kinds)
  local n = root:named_descendant_for_range(row, col, row, col)
  while n do
    if kinds[n:type()] then
      return n
    end
    n = n:parent()
  end
end

-- receiver of a method: "self", "&self", "&mut self" (or nil for associated fns)
local function receiver(fn_node, text)
  local params = fn_node:field("parameters")[1]
  if not params then
    return nil
  end
  for child in params:iter_children() do
    if child:type() == "self_parameter" then
      local t = squash(node_text(child, text))
      if t:match("&%s*mut") or t:match("&'%w+%s+mut") then
        return "&mut self"
      elseif t:match("^&") then
        return "&self"
      end
      return "self"
    end
  end
end

-- source text of `node` up to where its body starts (byte offsets from treesitter)
local function head(node, body, text)
  local _, _, from = node:start()
  if not body then
    return squash(vim.treesitter.get_node_text(node, text))
  end
  local _, _, to = body:start()
  return squash(text:sub(from + 1, to))
end

--- One implementation location → { header, trait, methods = {...}, loc }
function M.read_impl(location)
  local uri = location.uri or location.targetUri
  local range = location.range or location.targetSelectionRange or location.targetRange
  local path = vim.uri_to_fname(uri)
  local f = parse_file(path)
  if not f then
    return nil
  end
  local impl = enclosing(f.root, range.start.line, range.start.character, { impl_item = true })
  if not impl then
    return nil
  end
  local body = impl:field("body")[1]
  local header = head(impl, body, f.text)
  local trait = impl:field("trait")[1]
  local out = {
    header = squash(header),
    trait = trait and squash(node_text(trait, f.text)) or nil,
    methods = {},
    loc = { uri = uri, range = range },
  }
  if body then
    for child in body:iter_children() do
      if child:type() == "function_item" then
        local name = child:field("name")[1]
        local nr, nc = name:start()
        table.insert(out.methods, {
          name = node_text(name, f.text),
          recv = receiver(child, f.text),
          sig = head(child, child:field("body")[1], f.text),
          loc = { uri = uri, range = { start = { line = nr, character = nc }, ["end"] = { line = nr, character = nc } } },
        })
      elseif child:type() == "type_item" or child:type() == "const_item" then
        local name = child:field("name")[1]
        if name then
          local nr, nc = name:start()
          table.insert(out.methods, {
            name = node_text(name, f.text),
            sig = squash(node_text(child, f.text)),
            assoc = child:type(),
            loc = { uri = uri, range = { start = { line = nr, character = nc }, ["end"] = { line = nr, character = nc } } },
          })
        end
      end
    end
  end
  return out
end

--- derives on the struct/enum/union at a definition location
function M.derives(location)
  local uri = location.uri or location.targetUri
  local range = location.range or location.targetSelectionRange or location.targetRange
  local f = parse_file(vim.uri_to_fname(uri))
  if not f then
    return {}
  end
  local item = enclosing(f.root, range.start.line, range.start.character, {
    struct_item = true,
    enum_item = true,
    union_item = true,
  })
  if not item then
    return {}
  end
  local names = {}
  local prev = item:prev_named_sibling()
  while prev and (prev:type() == "attribute_item" or prev:type() == "line_comment" or prev:type() == "block_comment") do
    if prev:type() == "attribute_item" then
      local t = node_text(prev, f.text)
      local list = t:match("derive%s*%((.-)%)")
      if list then
        for d in list:gmatch("[%w_:]+") do
          table.insert(names, 1, (d:gsub("^.*::", "")))
        end
      end
    end
    prev = prev:prev_named_sibling()
  end
  return names
end

return M
