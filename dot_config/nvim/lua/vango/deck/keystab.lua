-- The deck's Keys tab, generated from the live keymaps every time the deck
-- opens: the cheat sheet can never disagree with what the keys really do.
-- Buffer-local maps of the buffer you came from (LSP, Rust, man) are included.

local M = {}

local function pretty(lhs)
  local leader = vim.g.mapleader or "\\"
  if lhs:sub(1, #leader) == leader then
    lhs = "Space " .. lhs:sub(#leader + 1)
  end
  return (lhs:gsub("|", "\\|"))
end

local function cell(s)
  return (s:gsub("|", "\\|"):gsub("\n", " "))
end

local function collect(mode, bufnr)
  local seen, maps = {}, {}
  local function add(list, buffer_local)
    for _, m in ipairs(list) do
      if m.desc and m.desc ~= "" and not m.lhs:match("^<Plug>") and not m.desc:match("^:help") then
        -- buffer maps win over globals with the same lhs
        if buffer_local or not seen[m.lhs] then
          seen[m.lhs] = { lhs = m.lhs, desc = m.desc, buf = buffer_local }
        end
      end
    end
  end
  add(vim.api.nvim_get_keymap(mode), false)
  if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
    add(vim.api.nvim_buf_get_keymap(bufnr, mode), true)
  end
  for _, m in pairs(seen) do
    table.insert(maps, m)
  end
  table.sort(maps, function(x, y)
    return x.lhs:lower() < y.lhs:lower() or (x.lhs:lower() == y.lhs:lower() and x.lhs < y.lhs)
  end)
  return maps
end

local function table_lines(lines, maps)
  table.insert(lines, "| Keys | What it does |")
  table.insert(lines, "| ---- | ------------ |")
  for _, m in ipairs(maps) do
    local mark = m.buf and "  ·" or ""
    table.insert(lines, ("| `%s` | %s%s |"):format(pretty(m.lhs), cell(m.desc), mark))
  end
  table.insert(lines, "")
end

function M.lines(bufnr)
  local leader = vim.g.mapleader or "\\"
  local groups = require("vango.core.groups")
  local ft = bufnr and vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].filetype or ""
  local lines = {
    "# Keys",
    "",
    ("Generated from your live keymaps%s. A `·` marks keys that only exist in that buffer."):format(
      ft ~= "" and (" for a **" .. ft .. "** buffer") or ""
    ),
    "",
    "> Space ? opens this tab · Space r toggles the deck · Space alone shows which-key",
    "",
  }

  local normal = collect("n", bufnr)
  local by_group, other, single = {}, {}, {}
  for _, m in ipairs(normal) do
    if m.lhs:sub(1, #leader) == leader and #m.lhs > #leader then
      local k = m.lhs:sub(#leader + 1, #leader + 1)
      if #m.lhs == #leader + 1 then
        table.insert(single, m)
      else
        by_group[k] = by_group[k] or {}
        table.insert(by_group[k], m)
      end
    else
      table.insert(other, m)
    end
  end

  if #single > 0 then
    table.insert(lines, "## Space + one key")
    table.insert(lines, "")
    table_lines(lines, single)
  end

  local named = {}
  for _, g in ipairs(groups) do
    named[g[1]] = true
    if by_group[g[1]] then
      table.insert(lines, ("## %s  Space %s · %s"):format(g[3], g[1], g[2]))
      table.insert(lines, "")
      table_lines(lines, by_group[g[1]])
    end
  end
  for k, maps in vim.spairs(by_group) do
    if not named[k] then
      table.insert(lines, ("## Space %s"):format(k))
      table.insert(lines, "")
      table_lines(lines, maps)
    end
  end

  if #other > 0 then
    table.insert(lines, "## Without leader")
    table.insert(lines, "")
    table_lines(lines, other)
  end

  local visual = vim.tbl_filter(function(m)
    return not m.lhs:match("^[%[%]]")
  end, collect("x", bufnr))
  if #visual > 0 then
    table.insert(lines, "## Visual mode")
    table.insert(lines, "")
    table_lines(lines, visual)
  end
  return lines
end

return M
