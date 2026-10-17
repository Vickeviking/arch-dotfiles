-- The Deck: Viktor's floating cheat sheet (Space r), Watchtower keys inside nvim.
-- Tab 1 is generated from the live keymaps; the rest are markdown files in
-- ~/.config/nvim/deck/, edit them freely: the next open picks up the change.
-- The tabs follow the language of the buffer you open it from (PROFILES);
-- Rust, and any filetype without its own profile, gets the Rust deck.

local M = {}

local dir = vim.fn.stdpath("config") .. "/deck/"

-- order is the rail order; digits 1–9, 0 jump straight to the first ten
local KEYS = { name = "Keys", gen = true }
local MOVES = { name = "nvim moves", file = "02-nvim-moves.md" }

local RUST = {
  KEYS,
  MOVES,
  { name = "Ownership", file = "03-ownership.md" },
  { name = "Types & layout", file = "04-types-layout.md" },
  { name = "Traits & generics", file = "05-traits.md" },
  { name = "Iterators", file = "06-iterators.md" },
  { name = "Errors", file = "07-errors.md" },
  { name = "Smart pointers", file = "08-smart-pointers.md" },
  { name = "Concurrency", file = "09-concurrency.md" },
  { name = "Async & tokio", file = "10-async.md" },
  { name = "Cargo & tools", file = "11-cargo.md" },
  { name = "Debugger", file = "12-debugger.md" },
  { name = "Unsafe & embedded", file = "13-unsafe-embedded.md" },
}

local PROFILES = {
  rust = { label = nil, tabs = RUST },
  c = {
    label = "C / C++",
    tabs = {
      KEYS, MOVES,
      { name = "C essentials", file = "c/01-c.md" },
      { name = "Pointers & memory", file = "c/02-memory.md" },
      { name = "Modern C++", file = "c/03-cpp.md" },
      { name = "Build & debug", file = "c/04-build.md" },
    },
  },
  python = {
    label = "Python",
    tabs = {
      KEYS, MOVES,
      { name = "Python", file = "python/01-python.md" },
      { name = "Python tooling", file = "python/02-tooling.md" },
    },
  },
  web = {
    label = "TypeScript",
    tabs = {
      KEYS, MOVES,
      { name = "TypeScript", file = "web/01-typescript.md" },
      { name = "React & tooling", file = "web/02-react-tooling.md" },
    },
  },
  go = { label = "Go", tabs = { KEYS, MOVES, { name = "Go", file = "go/01-go.md" } } },
  java = { label = "Java", tabs = { KEYS, MOVES, { name = "Java", file = "java/01-java.md" } } },
  sql = { label = "SQL", tabs = { KEYS, MOVES, { name = "SQL", file = "sql/01-sql.md" } } },
  lua = { label = "Lua", tabs = { KEYS, MOVES, { name = "Lua & nvim config", file = "lua/01-lua.md" } } },
}

local FILETYPES = {
  c = "c", cpp = "c", objc = "c", cuda = "c",
  python = "python",
  typescript = "web", javascript = "web", typescriptreact = "web", javascriptreact = "web", vue = "web", svelte = "web",
  go = "go", java = "java", sql = "sql", lua = "lua",
}

local HELP = {
  "In the tab list",
  "  j / k      next / previous tab",
  "  1 … 9, 0   jump to a tab",
  "  gg / G     first / last tab",
  "  l  C-l  ⏎  read the tab",
  "  /          search every tab",
  "",
  "In a tab",
  "  j / k      scroll",
  "  C-h        back to the tab list",
  "  J / K      next / previous tab",
  "  /  n  N    find in this tab",
  "",
  "Anywhere",
  "  Space r    open / close the deck",
  "  Space ?    open on the Keys tab",
  "  q  Esc     close",
  "  ?          this list",
}

local panels = {} -- one panel per profile, each remembers its own tab and scroll

local function search(p)
  local all = p:all_lines({ origin_buf = p.origin_buf })
  local items = {}
  for i, lines in ipairs(all) do
    local fence = false
    for n, l in ipairs(lines) do
      if l:match("^```") then
        fence = not fence
      elseif l:match("%S") and not l:match("^|%s*%-") then
        local text = l:gsub("^#+%s*", ""):gsub("|", " "):gsub("`", ""):gsub("%s+", " ")
        table.insert(items, { tab = i, line = n, text = text, label = p.tabs[i].name })
      end
    end
  end
  p:hide()

  local ok_t = pcall(require, "telescope")
  if not ok_t then
    vim.ui.select(items, {
      prompt = "Deck",
      format_item = function(it)
        return it.label .. " › " .. it.text
      end,
    }, function(it)
      if it then
        p:jump(it.tab, it.line)
      end
    end)
    return
  end

  local pickers = require("telescope.pickers")
  local finders = require("telescope.finders")
  local conf = require("telescope.config").values
  local actions = require("telescope.actions")
  local state = require("telescope.actions.state")
  local entry_display = require("telescope.pickers.entry_display")
  local displayer = entry_display.create({ separator = " ", items = { { width = 18 }, { remaining = true } } })
  pickers
    .new({}, {
      prompt_title = "Search the deck",
      finder = finders.new_table({
        results = items,
        entry_maker = function(it)
          return {
            value = it,
            ordinal = it.label .. " " .. it.text,
            display = function()
              return displayer({ { it.label, "DeckRailHead" }, it.text })
            end,
          }
        end,
      }),
      sorter = conf.generic_sorter({}),
      attach_mappings = function(bufnr)
        actions.select_default:replace(function()
          local sel = state.get_selected_entry()
          actions.close(bufnr)
          if sel then
            vim.schedule(function()
              p:jump(sel.value.tab, sel.value.line)
            end)
          end
        end)
        return true
      end,
    })
    :find()
end

-- the profile for the current buffer, or the one whose deck is open
local function profile()
  for name, p in pairs(panels) do
    if p:is_open() then
      return name
    end
  end
  return FILETYPES[vim.bo.filetype] or "rust"
end

local function get(name)
  name = name or profile()
  if panels[name] then
    return panels[name]
  end
  local prof = PROFILES[name]
  local tabs = {}
  for _, t in ipairs(prof.tabs) do
    if t.gen then
      table.insert(tabs, {
        name = t.name,
        lines = function(ctx)
          return require("vango.deck.keystab").lines(ctx.origin_buf)
        end,
      })
    else
      table.insert(tabs, { name = t.name, file = dir .. t.file })
    end
  end
  panels[name] = require("vango.deck.ui").new({
    title = prof.label and ("Deck · " .. prof.label) or "Deck",
    icon = "󰘦",
    tabs = tabs,
    help_lines = HELP,
    on_search = search,
  })
  return panels[name]
end

function M.toggle()
  get():toggle()
end

-- Space ?: straight to the Keys tab, reading
function M.keys()
  local p = get()
  if p:is_open() then
    p:select(1)
    p:focus_to("content")
  else
    p:show({ tab = 1, focus = "content" })
  end
end

function M.search()
  search(get())
end

return M
