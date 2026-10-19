-- Ask: a chat with Claude (Haiku by default) in a float, for quick questions
-- without leaving the code. Runs the `claude` CLI you're already logged into,
-- slimmed down (no tools, no MCP, no CLAUDE.md), so an answer takes ~2 s.
--
--   Space Space  ask (in visual mode: about the selection); Space aq works too
--   Space ae   explain the diagnostic under the cursor
--   :Ask …     ask straight from the command line
--   Super+A    Quick ask from anywhere on the desktop (quick-ask script):
--              a screenshot comes along, and Claude may read ~/.config
--
-- Every question carries a small context block: file, the function around
-- the cursor (or the selection), the diagnostics on that line, and while the
-- debugger is stopped, X-ray's view of the stack and heap. Follow-ups continue
-- the same conversation (`--resume`); C-n starts a fresh one.

local M = {}

M.model = vim.g.vango_ask_model or "haiku"

local SYSTEM = [[You are a concise coding helper living inside Neovim.
The user is Viktor, an embedded-systems student comfortable with Rust, C, nvim,
Arch and Hyprland: skip beginner explanations. Refer to them as they/them.
Answer in GitHub Markdown. Lead with the answer; keep it short (a few lines or
one code block) unless asked for depth. Tag code blocks with their language.
This renders in a narrow floating panel, about 60 columns wide: a markdown
table wider than that wraps and its borders render broken. Avoid tables here —
use a short bullet list instead. If a table genuinely is the clearest form,
keep every cell to a couple of words.
Each question may start with an <editor> block describing what the user is
looking at; use it when relevant, never repeat it back.]]

-- Quick ask (Super+A): the screen and the dotfiles, read-only
local QUICK = [[You are a concise helper on Viktor's Arch + Hyprland desktop.
Viktor is comfortable with Rust, nvim, Arch and Hyprland: skip beginner
explanations, refer to them as they/them. Answer in GitHub Markdown, short.
A screenshot of the screen at the moment they asked is at %s: read it with
the Read tool when the question is about what's on screen. Their dotfiles are
in ~/.config (Hyprland Lua config in ~/.config/hypr, KoolDots base modules in
hypr/lua are upstream; personal overrides in hypr/UserConfigs/user_*.lua).
You can read files but not change them: when a change helps, show the exact
edit (file path and the lines) for Viktor to make.]]

local ns = vim.api.nvim_create_namespace("vango.ask")

local S = {
  buf = nil, -- transcript
  input = nil, -- input box
  win = nil,
  iwin = nil,
  session = nil, -- claude session id for follow-ups
  job = nil,
  origin = nil, -- the code window the chat was opened from
  spin = nil,
  started = nil,
}

local SPIN = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }

local function hl()
  local th = require("vango.deck.theme")
  local p = th.palette()
  local mix = th.mix
  local set = vim.api.nvim_set_hl
  set(0, "AskYou", { fg = p.surface, bg = p.accent2, bold = true })
  set(0, "AskHaiku", { fg = p.surface, bg = p.accent, bold = true })
  set(0, "AskChip", { fg = p.muted, bg = mix(p.accent2, p.panel, 0.10), italic = true })
  set(0, "AskDim", { fg = p.muted })
  set(0, "AskInput", { fg = p.text, bg = mix(p.surface, p.panel, 0.7) })
  set(0, "AskInputBorder", { fg = p.accent2, bg = mix(p.surface, p.panel, 0.7) })
  set(0, "AskInputTitle", { fg = p.surface, bg = p.accent2, bold = true })
  set(0, "AskErr", { fg = p.alert, bold = true })
end

-- context ---------------------------------------------------------------------

local FN_NODES = {
  function_item = true, impl_item = true, function_definition = true, function_declaration = true,
  method_definition = true, method_declaration = true, arrow_function = true, func_literal = true,
  constructor_declaration = true, local_function = true, ["function"] = true,
}

-- the smallest function-like treesitter node around the cursor
local function enclosing_fn(buf, row, col)
  local ok, node = pcall(vim.treesitter.get_node, { bufnr = buf, pos = { row, col } })
  if not ok then
    return nil
  end
  while node do
    if FN_NODES[node:type()] then
      local sr, _, er = node:range()
      if er - sr <= 120 then
        return sr, er
      end
      return nil
    end
    node = node:parent()
  end
end

local function xray_view()
  local dap = package.loaded["dap"]
  local s = dap and dap.session()
  if not (s and s.stopped_thread_id) then
    return nil
  end
  local ok, xr = pcall(require, "vango.xray")
  if not ok then
    return nil
  end
  local g = xr.graph()
  if not g then
    return nil
  end
  local ok2, lines = pcall(require("vango.xray.map").render_compact, g, { width = 70 })
  if not ok2 or type(lines) ~= "table" then
    return nil
  end
  return table.concat(vim.list_slice(lines, 1, 80), "\n")
end

-- what the user is looking at, as text for the model and a one-line chip for the screen
function M.context(win, range)
  if not (win and vim.api.nvim_win_is_valid(win)) then
    return nil
  end
  local buf = vim.api.nvim_win_get_buf(win)
  if vim.bo[buf].buftype ~= "" then
    return nil
  end
  local name = vim.api.nvim_buf_get_name(buf)
  local rel = name ~= "" and vim.fn.fnamemodify(name, ":~:.") or "[no name]"
  local ft = vim.bo[buf].filetype
  local row = vim.api.nvim_win_get_cursor(win)[1] - 1
  local parts = { ("file: %s (%s), cursor on line %d"):format(rel, ft, row + 1) }
  local chip = { ("%s:%d"):format(rel, row + 1) }

  local sr, er, what
  if range then
    sr, er, what = range[1], range[2], "selection"
  else
    sr, er = enclosing_fn(buf, row, vim.api.nvim_win_get_cursor(win)[2])
    what = "enclosing function"
    if not sr and vim.api.nvim_buf_line_count(buf) <= 300 then
      sr, er, what = 0, vim.api.nvim_buf_line_count(buf) - 1, "whole file"
    elseif not sr then -- no function in a long file: a window around the cursor
      sr, er, what = math.max(0, row - 25), row + 25, "lines around the cursor"
    end
  end
  local code = vim.api.nvim_buf_get_lines(buf, sr, er + 1, false)
  if #code > 0 then
    parts[#parts + 1] = ("%s (lines %d–%d):\n```%s\n%s\n```"):format(what, sr + 1, sr + #code, ft, table.concat(code, "\n"))
    chip[#chip + 1] = range and ("%d lines selected"):format(#code) or (what == "enclosing function" and "this function" or what == "whole file" and "whole file" or "nearby lines")
  end

  local diags = vim.diagnostic.get(buf, { lnum = row })
  if range then
    diags = vim.tbl_filter(function(d)
      return d.lnum >= sr and d.lnum <= er
    end, vim.diagnostic.get(buf))
  end
  if #diags > 0 then
    local ds = {}
    for _, d in ipairs(diags) do
      ds[#ds + 1] = ("- line %d [%s%s]: %s"):format(d.lnum + 1, vim.diagnostic.severity[d.severity]:lower(),
        d.code and (" " .. d.code) or "", d.message)
    end
    parts[#parts + 1] = "diagnostics:\n" .. table.concat(ds, "\n")
    chip[#chip + 1] = #diags == 1 and "1 diagnostic" or (#diags .. " diagnostics")
  end

  local xr = xray_view()
  if xr then
    parts[#parts + 1] = "debugger stopped here; X-ray's view of stack and heap:\n" .. xr
    chip[#chip + 1] = "X-ray"
  end
  return { text = "<editor>\n" .. table.concat(parts, "\n\n") .. "\n</editor>", chip = table.concat(chip, " · ") }
end

-- transcript ------------------------------------------------------------------

-- render-markdown redraws on events of the current buffer; the answers are
-- written from outside (you're typing below), so ask it to redraw, at most
-- every 60 ms while an answer streams in
local redraw_timer
local function rerender()
  redraw_timer = redraw_timer or vim.uv.new_timer()
  redraw_timer:start(60, 0, vim.schedule_wrap(function()
    if S.buf and vim.api.nvim_buf_is_valid(S.buf) then
      pcall(function()
        require("render-markdown.api").render({ buf = S.buf })
      end)
    end
  end))
end

local function tlines()
  return vim.api.nvim_buf_line_count(S.buf)
end

local function append(lines)
  vim.bo[S.buf].modifiable = true
  local n = tlines()
  local empty = n == 1 and vim.api.nvim_buf_get_lines(S.buf, 0, 1, false)[1] == ""
  vim.api.nvim_buf_set_lines(S.buf, empty and 0 or n, -1, false, lines)
  vim.bo[S.buf].modifiable = false
  rerender()
  return empty and 0 or n
end

local function follow()
  if S.win and vim.api.nvim_win_is_valid(S.win) and vim.api.nvim_get_current_win() ~= S.win then
    vim.api.nvim_win_set_cursor(S.win, { tlines(), 0 })
  end
end

-- streamed text: continue the last line, split on newlines
local function stream(text)
  vim.bo[S.buf].modifiable = true
  local n = tlines()
  local last = vim.api.nvim_buf_get_lines(S.buf, n - 1, n, false)[1] or ""
  local new = vim.split(last .. text, "\n", { plain = true })
  vim.api.nvim_buf_set_lines(S.buf, n - 1, n, false, new)
  vim.bo[S.buf].modifiable = false
  rerender()
  follow()
end

local function label(row, text, group)
  vim.api.nvim_buf_set_extmark(S.buf, ns, row, 0, {
    virt_text = { { " " .. text .. " ", group } },
    virt_text_pos = "overlay",
  })
end

local function welcome()
  local lines = S.quick and {
    "",
    "  Ask about anything on screen, or your dotfiles.",
    "  The screenshot is attached; Claude can read ~/.config but not change it.",
    "",
    "  ⏎ send   ⇧⏎ new line   C-n new chat   Esc close",
    "",
  } or {
    "",
    "  Ask anything. The code you're looking at comes along.",
    "",
    "  ⏎ send   ⇧⏎ new line   C-n new chat   C-c stop",
    "  Tab to the answers: y yank code · i ask more · q hide",
    "",
  }
  append(lines)
  for i = 0, #lines - 1 do
    vim.api.nvim_buf_add_highlight(S.buf, ns, "AskDim", i, 0, -1)
  end
end

-- windows ---------------------------------------------------------------------

local function footer(busy)
  if busy then
    local t = (vim.uv.now() - S.started) / 1000
    return { { (" %s thinking %.1fs "):format(SPIN[math.floor(t * 10) % #SPIN + 1], t), "DeckFooterKey" } }
  end
  return {
    { " ⏎", "DeckFooterKey" }, { " send  ", "DeckFooter" },
    { "C-n", "DeckFooterKey" }, { " new  ", "DeckFooter" },
    { "Tab", "DeckFooterKey" }, { " answers  ", "DeckFooter" },
    { S.quick and "Esc" or "q", "DeckFooterKey" }, { S.quick and " close " or " hide ", "DeckFooter" },
  }
end

local function set_footer(busy)
  if S.iwin and vim.api.nvim_win_is_valid(S.iwin) then
    vim.api.nvim_win_set_config(S.iwin, { footer = footer(busy), footer_pos = "right" })
  end
end

local function geometry()
  local cols, lines = vim.o.columns, vim.o.lines
  if S.quick then -- its own small window: fill it
    -- two bordered boxes stacked; no statusline or cmdline in this window
    return { w = cols - 2, th = lines - 3 - 4, ih = 3, col = 0, row = 0 }
  end
  local w = math.min(110, math.max(50, math.floor(cols * 0.48)))
  local h = math.max(12, lines - 6)
  local col = cols - w - 3
  local ih = 3
  return { w = w, th = h - ih - 3, ih = ih, col = col, row = 1 }
end

local function buffers()
  if not (S.buf and vim.api.nvim_buf_is_valid(S.buf)) then
    -- render-markdown loads on the markdown filetype; load it first so it
    -- attaches to this buffer too (code blocks, headings)
    pcall(require, "render-markdown")
    S.buf = vim.api.nvim_create_buf(false, true)
    vim.bo[S.buf].filetype = "markdown"
    vim.bo[S.buf].bufhidden = "hide"
    vim.bo[S.buf].modifiable = false
    vim.api.nvim_buf_set_name(S.buf, "ask://Ask answers")
    welcome()
  end
  if not (S.input and vim.api.nvim_buf_is_valid(S.input)) then
    S.input = vim.api.nvim_create_buf(false, true)
    vim.bo[S.input].bufhidden = "hide"
    vim.bo[S.input].filetype = "markdown"
    vim.api.nvim_buf_set_name(S.input, "ask://Ask")
    M._keys()
  end
end

function M.is_open()
  return S.win ~= nil and vim.api.nvim_win_is_valid(S.win)
end

local function open_windows()
  buffers()
  local g = geometry()
  if not M.is_open() then
    S.win = vim.api.nvim_open_win(S.buf, false, {
      relative = "editor", row = g.row, col = g.col, width = g.w, height = g.th,
      border = "rounded", style = "minimal", zindex = 60,
      title = { { " 󰚩 Ask ", "DeckTitle" }, { " " .. M.model .. " ", "DeckFooter" } }, title_pos = "left",
    })
    vim.wo[S.win].winhighlight = require("vango.deck.theme").content_winhl .. ",FloatTitle:DeckTitle"
    vim.wo[S.win].wrap = true
    vim.wo[S.win].linebreak = true
    vim.wo[S.win].breakindent = true
    vim.wo[S.win].conceallevel = 2
    vim.wo[S.win].cursorline = false
    vim.wo[S.win].statuscolumn = " "
  end
  if not (S.iwin and vim.api.nvim_win_is_valid(S.iwin)) then
    S.iwin = vim.api.nvim_open_win(S.input, true, {
      relative = "editor", row = g.row + g.th + 2, col = g.col, width = g.w, height = g.ih,
      border = "rounded", style = "minimal", zindex = 61,
      title = { { "  you ", "AskInputTitle" } }, title_pos = "left",
      footer = footer(S.job ~= nil), footer_pos = "right",
    })
    vim.wo[S.iwin].winhighlight = "Normal:AskInput,NormalFloat:AskInput,FloatBorder:AskInputBorder,FloatFooter:DeckFooter"
    vim.wo[S.iwin].wrap = true
    vim.wo[S.iwin].statuscolumn = " "
  end
  vim.api.nvim_set_current_win(S.iwin)
  follow()
end

function M.hide()
  if S.quick then
    return vim.cmd("qa!")
  end
  for _, w in ipairs({ S.iwin, S.win }) do
    if w and vim.api.nvim_win_is_valid(w) then
      vim.api.nvim_win_close(w, true)
    end
  end
  S.win, S.iwin = nil, nil
  if S.origin and vim.api.nvim_win_is_valid(S.origin) then
    vim.api.nvim_set_current_win(S.origin)
  end
  vim.cmd.stopinsert()
end

-- talking to claude -------------------------------------------------------------

local function cmd(prompt)
  local c = {
    "claude", "-p", "--model", M.model,
    "--output-format", "stream-json", "--verbose", "--include-partial-messages",
    "--strict-mcp-config", "--setting-sources", "", "--disable-slash-commands",
  }
  if S.quick then -- read-only tools: the screenshot and ~/.config
    vim.list_extend(c, {
      "--tools", "Read,Grep,Glob", "--allowedTools", "Read,Grep,Glob",
      "--add-dir", vim.fn.expand("~/.config"),
      "--system-prompt", QUICK:format(S.quick.shot),
    })
  else
    vim.list_extend(c, { "--tools", "", "--system-prompt", SYSTEM })
  end
  if S.session then
    vim.list_extend(c, { "--resume", S.session })
  end
  c[#c + 1] = prompt
  return c
end

local function done(err)
  if S.spin then
    S.spin:stop()
    S.spin:close()
    S.spin = nil
  end
  S.job = nil
  if err then
    append({ "", "**" .. err .. "**" })
    label(tlines() - 1, " " .. err, "AskErr")
  end
  append({ "" })
  set_footer(false)
  follow()
end

-- the answer as an event stream: text deltas, then a result with the session id
function M._event(ev)
  if ev.type == "stream_event" and ev.event and ev.event.type == "content_block_delta" then
    local d = ev.event.delta
    if d and d.type == "text_delta" then
      stream(d.text)
    end
  elseif ev.type == "assistant" and ev.message then
    -- a tool call (Quick ask reads the screenshot or a dotfile): say so, dimmed
    for _, c in ipairs(ev.message.content or {}) do
      if c.type == "tool_use" then
        local input = c.input or {}
        local what
        if input.file_path then
          what = S.quick and input.file_path == S.quick.shot and "the screen" or vim.fn.fnamemodify(input.file_path, ":~")
        else
          what = ("`%s`"):format(input.pattern or input.path or "")
        end
        stream(("*󰈈 %s %s*\n\n"):format(({ Read = "looked at", Grep = "searched", Glob = "listed" })[c.name] or c.name, what))
      end
    end
  elseif ev.type == "result" then
    S.session = ev.session_id or S.session
    if ev.is_error then
      return ev.result or "claude returned an error"
    end
  end
end

function M.send(question, opts)
  opts = opts or {}
  question = vim.trim(question or "")
  if question == "" or S.job then
    return
  end
  if vim.fn.executable("claude") == 0 then
    vim.notify("Ask needs the `claude` CLI on PATH", vim.log.levels.ERROR)
    return
  end
  buffers()
  local ctx = (opts.no_context or S.quick) and nil or M.context(S.origin, opts.range)
  local row = append({ "", "you", "" })
  label(row + 1, " you", "AskYou")
  if ctx then
    local r = append({ "> " .. ctx.chip })
    vim.api.nvim_buf_add_highlight(S.buf, ns, "AskChip", r, 0, -1)
  end
  append(vim.split(question, "\n", { plain = true }))
  local hr = append({ "", M.model, "", "" })
  label(hr + 1, "󰚩 " .. M.model, "AskHaiku")
  follow()

  local prompt = ctx and (ctx.text .. "\n\n" .. question) or question
  local dir = vim.fn.stdpath("cache") .. "/ask"
  vim.fn.mkdir(dir, "p")
  local pending, err = "", nil
  S.started = vim.uv.now()
  S.job = vim.fn.jobstart(cmd(prompt), {
    cwd = dir,
    stdin = "null",
    on_stdout = function(_, data)
      data[1] = pending .. data[1]
      pending = table.remove(data)
      for _, line in ipairs(data) do
        if line ~= "" then
          local ok, ev = pcall(vim.json.decode, line)
          if ok and type(ev) == "table" then
            err = M._event(ev) or err
          end
        end
      end
    end,
    on_stderr = function(_, data)
      local msg = vim.trim(table.concat(data, " "))
      if msg ~= "" then
        err = msg
      end
    end,
    on_exit = function(_, code)
      vim.schedule(function()
        done((code ~= 0 or err) and (err or ("claude exited with " .. code)) or nil)
      end)
    end,
  })
  if S.job <= 0 then
    S.job = nil
    done("could not start claude")
    return
  end
  S.spin = vim.uv.new_timer()
  S.spin:start(0, 100, vim.schedule_wrap(function()
    if S.job then
      set_footer(true)
    end
  end))
end

function M.stop()
  if S.job then
    vim.fn.jobstop(S.job)
  end
end

function M.new()
  M.stop()
  S.session = nil
  if S.buf and vim.api.nvim_buf_is_valid(S.buf) then
    vim.bo[S.buf].modifiable = true
    vim.api.nvim_buf_set_lines(S.buf, 0, -1, false, {})
    vim.api.nvim_buf_clear_namespace(S.buf, ns, 0, -1)
    vim.bo[S.buf].modifiable = false
    welcome()
  end
end

-- the last fenced code block in the transcript
function M.last_code()
  local lines = vim.api.nvim_buf_get_lines(S.buf, 0, -1, false)
  local stop
  for i = #lines, 1, -1 do
    if lines[i]:match("^%s*```") then
      if not stop then
        stop = i
      else
        return vim.list_slice(lines, i + 1, stop - 1)
      end
    end
  end
end

local function submit()
  local q = table.concat(vim.api.nvim_buf_get_lines(S.input, 0, -1, false), "\n")
  vim.api.nvim_buf_set_lines(S.input, 0, -1, false, {})
  M.send(q, { range = S.range })
  S.range = nil
end

function M._keys()
  local function map(buf, mode, lhs, fn, desc)
    vim.keymap.set(mode, lhs, fn, { buffer = buf, nowait = true, silent = true, desc = desc })
  end
  local function to_answers()
    vim.cmd.stopinsert()
    if M.is_open() then
      vim.api.nvim_set_current_win(S.win)
    end
  end
  local function to_input()
    if S.iwin and vim.api.nvim_win_is_valid(S.iwin) then
      vim.api.nvim_set_current_win(S.iwin)
      vim.cmd.startinsert({ bang = true })
    end
  end
  local function yank()
    local code = M.last_code()
    if code then
      vim.fn.setreg("+", table.concat(code, "\n"))
      vim.fn.setreg('"', table.concat(code, "\n"))
      vim.notify(("Ask: yanked %d lines of code"):format(#code))
    end
  end
  -- input box
  map(S.input, { "i", "n" }, "<CR>", submit, "Send")
  map(S.input, "i", "<S-CR>", "<CR>", "New line")
  map(S.input, "i", "<C-j>", "<CR>", "New line")
  map(S.input, { "i", "n" }, "<C-n>", M.new, "New chat")
  map(S.input, { "i", "n" }, "<C-c>", M.stop, "Stop the answer")
  map(S.input, { "i", "n" }, "<Tab>", to_answers, "To the answers")
  map(S.input, "n", "q", M.hide, "Hide")
  map(S.input, "n", "<Esc>", M.hide, "Hide")
  -- transcript
  map(S.buf, "n", "q", M.hide, "Hide")
  map(S.buf, "n", "<Esc>", M.hide, "Hide")
  map(S.buf, "n", "i", to_input, "Ask more")
  map(S.buf, "n", "a", to_input, "Ask more")
  map(S.buf, "n", "<Tab>", to_input, "Ask more")
  map(S.buf, "n", "y", yank, "Yank the last code block")
  map(S.buf, "n", "<C-n>", M.new, "New chat")
  map(S.buf, "n", "<C-c>", M.stop, "Stop the answer")
end

-- entry points ------------------------------------------------------------------

local function remember_origin()
  local w = vim.api.nvim_get_current_win()
  if w ~= S.win and w ~= S.iwin then
    S.origin = w
  end
end

-- Space Space (or Space aq): open (or hide) the chat; from visual mode the selection is the context
function M.open(opts)
  opts = opts or {}
  if M.is_open() and not opts.range and not opts.question then
    if vim.api.nvim_get_current_win() == S.win or vim.api.nvim_get_current_win() == S.iwin then
      return M.hide()
    end
    remember_origin()
    vim.api.nvim_set_current_win(S.iwin)
    vim.cmd.startinsert({ bang = true })
    return
  end
  remember_origin()
  S.range = opts.range
  open_windows()
  if opts.question then
    M.send(opts.question, { range = opts.range })
    S.range = nil
    vim.cmd.stopinsert()
  else
    vim.cmd.startinsert({ bang = true })
  end
end

function M.visual()
  local a, b = vim.fn.line("v"), vim.fn.line(".")
  vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)
  M.open({ range = { math.min(a, b) - 1, math.max(a, b) - 1 } })
end

-- Space ae: explain the diagnostic under the cursor
function M.explain()
  local row = vim.api.nvim_win_get_cursor(0)[1] - 1
  -- the diagnostic on this line, or the nearest one within a few lines
  local best
  for _, d in ipairs(vim.diagnostic.get(0)) do
    local dist = math.abs(d.lnum - row)
    if dist <= 5 and (not best or dist < math.abs(best.lnum - row) or (dist == math.abs(best.lnum - row) and d.severity < best.severity)) then
      best = d
    end
  end
  if not best then
    vim.notify("Ask: no diagnostic near the cursor", vim.log.levels.INFO)
    return
  end
  if best.lnum ~= row then
    vim.api.nvim_win_set_cursor(0, { best.lnum + 1, best.col })
  end
  M.open({ question = ("Explain this diagnostic on line %d in plain words and show the smallest fix:\n`%s`"):format(
    best.lnum + 1, (best.message:gsub("\n", " "))) })
end

-- Super+A (quick-ask script): this nvim is only the chat, in its own window
function M.quick(shot)
  S.quick = { shot = shot }
  vim.o.laststatus, vim.o.cmdheight, vim.o.showtabline, vim.o.ruler = 0, 0, 0, false
  M.setup()
  open_windows()
  vim.cmd.startinsert({ bang = true })
end

function M.setup()
  hl()
  vim.api.nvim_create_autocmd("ColorScheme", { callback = hl })
  vim.api.nvim_create_autocmd("VimResized", {
    callback = function()
      if M.is_open() then
        local origin = S.origin
        M.hide()
        S.origin = origin
        open_windows()
      end
    end,
  })
  vim.api.nvim_create_user_command("Ask", function(a)
    if a.args ~= "" then
      M.open({ question = a.args, range = a.range > 0 and { a.line1 - 1, a.line2 - 1 } or nil })
    else
      M.open()
    end
  end, { nargs = "*", range = true, desc = "Ask Claude about the code" })
end

return M
