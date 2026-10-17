# Lua & nvim config

## Lua in one screen

```lua
local name = "deck"                    -- always `local`; globals leak
local n = #list                        -- length of a sequence
local t = { 1, 2, 3, key = "value" }   -- tables are arrays and maps at once
t.key, t["key"]                        -- same thing
for i, v in ipairs(t) do end           -- array part, in order, from 1
for k, v in pairs(t) do end            -- every key, no order
if x ~= nil and not done then end      -- ~= is "not equal"; only nil and false are falsy (0 is true)
local s = "a" .. "b"                   -- concatenation
local function add(a, b) return a + b end
local ok, err = pcall(risky, arg)      -- catch errors
local M = {} ; function M.setup(opts) end ; return M   -- a module
```

Indices start at 1. `obj:method(x)` is `obj.method(obj, x)`.

## nvim API you'll use

| Call | Does |
| ---- | ---- |
| `vim.keymap.set("n", "<leader>x", fn, { desc = "…" })` | map a key (the `desc` shows in which-key and the deck) |
| `vim.api.nvim_create_autocmd("BufWritePre", { pattern = "*.rs", callback = fn })` | run code on an event |
| `vim.api.nvim_create_user_command("Name", fn, {})` | a `:Name` command |
| `vim.opt.relativenumber = true` | set an option (`vim.o` for plain values) |
| `vim.bo.filetype` / `vim.wo.wrap` | buffer / window options |
| `vim.notify("text", vim.log.levels.WARN)` | a notification |
| `vim.fn.expand("<cword>")` | call any Vimscript function |
| `vim.cmd("colorscheme desk")` | run an Ex command |
| `vim.api.nvim_buf_get_lines(0, 0, -1, false)` | the current buffer's lines |
| `vim.schedule(fn)` / `vim.defer_fn(fn, ms)` | run later on the main loop |
| `vim.inspect(t)` / `:lua =t` | print a table |

## This config

| Where | What |
| ----- | ---- |
| `init.lua` | loads `vango.core` (options, keymaps) and lazy.nvim |
| `lua/vango/core/` | options, keymaps, `groups.lua` (which-key group names) |
| `lua/vango/plugins/*.lua` | one plugin spec per file, picked up by lazy.nvim |
| `lua/vango/deck/` | this deck; tab texts in `deck/*.md` |
| `colors/desk.lua` | the colorscheme, built from the desk-theme palette |
| `lazy-lock.json` | exact plugin versions (in git) |

## A lazy.nvim plugin spec

```lua
return {
  "author/plugin.nvim",
  event = "VeryLazy",            -- or ft = "rust", cmd = "Name", keys = { … }: load on demand
  dependencies = { "nvim-lua/plenary.nvim" },
  opts = { option = true },      -- passed to require("plugin").setup(opts)
  keys = {
    { "<leader>xx", function() require("plugin").run() end, desc = "Plugin: run" },
  },
}
```

## Commands for config work

| Command | Does |
| ------- | ---- |
| `:Lazy` | plugins: update (`U`), sync, profile startup (`P`) |
| `:Mason` | install LSP servers, formatters, linters |
| `:checkhealth` | what's broken (`:checkhealth blink` for one plugin) |
| `:messages` | recent messages and errors |
| `:verbose map <leader>r` | who defined a mapping |
| `:Inspect` | highlight groups under the cursor |
| `:source %` / `:lua <code>` | run the current file / a line of Lua |
| `nvim --startuptime /tmp/s.log` | startup profile |
