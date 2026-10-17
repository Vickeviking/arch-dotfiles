-- Ask (context and the answer stream), Run (commands per language), and the
-- statusline hints outside Rust.

local function scratch(ft, lines)
  local b = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_buf_set_name(b, vim.fn.tempname() .. "." .. ft)
  vim.api.nvim_buf_set_lines(b, 0, -1, false, lines)
  vim.api.nvim_set_current_buf(b)
  vim.bo[b].filetype = ft
  return b
end

describe("ask", function()
  local ask = require("vango.ask")

  it("sends the function around the cursor and the line's diagnostics", function()
    local b = scratch("python", {
      "import os",
      "",
      "def total(xs):",
      "    s = 0",
      "    for x in xs:",
      "        s += x",
      "    return s",
      "",
      "print(total([1, 2]))",
    })
    pcall(vim.treesitter.start, b, "python")
    vim.diagnostic.set(vim.api.nvim_create_namespace("t"), b, {
      { lnum = 5, col = 8, message = "s may be undefined", severity = vim.diagnostic.severity.WARN },
    })
    vim.api.nvim_win_set_cursor(0, { 6, 8 })
    local ctx = ask.context(vim.api.nvim_get_current_win())
    assert.truthy(ctx.text:find("def total", 1, true))
    assert.falsy(ctx.text:find("import os", 1, true)) -- only the function
    assert.truthy(ctx.text:find("s may be undefined", 1, true))
    assert.truthy(ctx.chip:find("this function", 1, true))
    assert.truthy(ctx.chip:find("1 diagnostic", 1, true))
  end)

  it("sends a selection instead when there is one", function()
    scratch("lua", { "local a = 1", "local b = 2", "local c = 3" })
    local ctx = ask.context(vim.api.nvim_get_current_win(), { 1, 2 })
    assert.truthy(ctx.text:find("local b = 2", 1, true))
    assert.falsy(ctx.text:find("local a = 1", 1, true))
    assert.truthy(ctx.chip:find("2 lines selected", 1, true))
  end)

  it("streams text deltas and keeps the session for follow-ups", function()
    ask.open({}) -- builds the windows and transcript
    ask._event({ type = "stream_event", event = { type = "content_block_delta", delta = { type = "text_delta", text = "Use `Rc`.\n```rust\nlet a = Rc::new(1);\n```" } } })
    local err = ask._event({ type = "result", session_id = "abc", is_error = false })
    assert.is_nil(err)
    assert.same({ "let a = Rc::new(1);" }, ask.last_code())
    ask.hide()
  end)
end)

describe("run", function()
  local run = require("vango.run")
  it("knows a command for the everyday languages", function()
    for _, ft in ipairs({ "python", "typescript", "javascript", "go", "lua", "sh", "c", "cpp", "java" }) do
      local cmd = run.command(ft, "/tmp/x/hello." .. ft)
      assert.truthy(cmd, ft)
      assert.truthy(cmd:find("hello", 1, true), ft)
    end
    assert.is_nil(run.command("haskell", "/tmp/a.hs"))
  end)
end)

describe("hints outside Rust", function()
  it("offer run and ask in a Python file", function()
    scratch("python", { "# just a comment", "x = 1" })
    vim.api.nvim_win_set_cursor(0, { 1, 4 })
    local keys = vim.tbl_map(function(i) return i[1] end, require("vango.hints").items())
    assert.truthy(vim.tbl_contains(keys, "Space cr"))
    assert.truthy(vim.tbl_contains(keys, "Space aq"))
  end)
end)
