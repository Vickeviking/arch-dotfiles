-- X-ray's nvim side against graphs recorded from genomlysning's fixtures/zoo
-- (tests/fixtures/xray/NN.json, exported with `xray-show --json`) and that
-- program's source (zoo.rs).

local map = require("vango.xray.map")
local source = require("vango.xray.source")

local dir = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h") .. "/fixtures/xray/"

local function graph(n)
  local f = assert(io.open(dir .. string.format("%02d.json", n)))
  local g = vim.json.decode(f:read("*a"), { luanil = { object = true, array = true } })
  f:close()
  return g
end

local function render(n, width)
  local lines = map.render(graph(n), { width = width or 120 })
  return lines, table.concat(lines, "\n")
end

local function find(lines, pat)
  for i, l in ipairs(lines) do
    if l:find(pat, 1, true) then
      return i, l
    end
  end
end

describe("xray map", function()
  it("renders every recorded stop within the width", function()
    for n = 1, 12 do
      for _, w in ipairs({ 80, 120, 160 }) do
        local lines = map.render(graph(n), { width = w })
        assert.is_true(#lines > 3)
        for _, l in ipairs(lines) do
          assert.is_true(vim.fn.strdisplaywidth(l) <= w, ("stop %d width %d: %q"):format(n, w, l))
        end
      end
    end
  end)

  it("draws boxes with matching top and bottom edges", function()
    for n = 1, 12 do
      local lines = map.render(graph(n), { width = 120 })
      for i, l in ipairs(lines) do
        local s = l:find("╭─ ", 1, true)
        if s and l:find("╮", s, true) then
          local top = vim.fn.strdisplaywidth(l:sub(s, l:find("╮", s, true) + #"╮" - 1))
          -- the matching bottom edge starts in the same column further down
          local col = vim.fn.strdisplaywidth(l:sub(1, s - 1))
          for j = i + 1, #lines do
            local b = lines[j]
            local prefix = vim.fn.strcharpart(b, col, 1)
            if prefix == "╰" then
              local rest = vim.fn.strcharpart(b, col)
              local e = rest:find("╯", 1, true)
              assert.equals(top, vim.fn.strdisplaywidth(rest:sub(1, e + #"╯" - 1)), ("stop %d box at line %d"):format(n, i))
              break
            end
          end
        end
      end
    end
  end)

  it("points v at its buffer and lists borrows inline (basics)", function()
    local lines = render(1)
    local _, v = find(lines, "│ v ")
    assert.truthy(v:find("●", 1, true), "v has an arrow")
    assert.truthy(v:find("▶╭─ A", 1, true), "straight into box A")
    assert.truthy(find(lines, "─▷ v"), "r = &v is written inline")
    assert.truthy(find(lines, "─▷ p.x"))
    assert.truthy(find(lines, "next Some"), "the list's node points on")
  end)

  it("shows the reallocation (growth)", function()
    local lines, text = render(6)
    assert.truthy(text:find("moved", 1, true))
    assert.truthy(text:find("freed since the last stop", 1, true))
    assert.truthy(find(lines, "░░"), "spare capacity is hatched")
    assert.truthy(text:find("grew from 4 to 8", 1, true))
  end)

  it("shares one Rc box and points back weakly (shared, tree)", function()
    local _, text = render(8)
    assert.truthy(text:find("borrowed mut", 1, true))
    assert.truthy(text:find("┄", 1, true), "the weak arrow is dashed")
    local lines = render(9)
    local count = 0
    for _, l in ipairs(lines) do
      if l:find("parent       ┄▶ A", 1, true) then
        count = count + 1
      end
    end
    assert.equals(2, count, "both children point back at the parent")
  end)

  it("marks moved-from slots it is told about", function()
    local g = graph(12)
    local words
    for _, s in ipairs(g.slots) do
      if s.name == "words" then
        words = s.id
      end
    end
    local lines = map.render(g, { width = 120, moved = { [words] = "taken" } })
    assert.truthy(find(lines, "↷words"))
  end)
end)

describe("xray source", function()
  local buf
  before_each(function()
    buf = vim.fn.bufadd(dir .. "zoo.rs")
    vim.fn.bufload(buf)
    vim.bo[buf].filetype = "rust"
  end)

  it("finds declarations before the stop line", function()
    local d = source.decls(buf, 46)
    assert.equals(42, d.v) -- 0-based row of `let mut v`
    assert.equals(43, d.i) -- the for pattern
    assert.is_nil(source.decls(buf, 38).nothing_here)
  end)

  it("finds a closure's captures in the function around it", function()
    local d = source.decls(buf, 97)
    assert.truthy(d.guard and d.data and d.gate and d.t)
  end)

  it("tells which of two owners was moved from", function()
    local g = graph(12)
    local moved = source.moved(g, buf, source.decls(buf, 114))
    local names = {}
    for id, into in pairs(moved) do
      names[#names + 1] = g.slots[id + 1].name .. "→" .. into
    end
    assert.same({ "words→taken" }, names)
  end)
end)

describe("xray history", function()
  it("steps back through stops and returns to live", function()
    local xray = require("vango.xray")
    xray.setup()
    for n = 2, 6 do
      xray._show(graph(n))
    end
    xray.scrub(-2)
    local g, info = xray.graph()
    assert.equals(4, g.stop)
    assert.is_false(info.live)
    xray.scrub(-10)
    assert.equals(2, (xray.graph()).stop, "stops at the first")
    xray.scrub(10)
    g, info = xray.graph()
    assert.equals(6, g.stop)
    assert.is_true(info.live, "the last stop is live again")
  end)
end)
