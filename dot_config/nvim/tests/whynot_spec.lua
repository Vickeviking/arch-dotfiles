-- "Why not?" against real rustc output: tests/fixtures/whynot/errors.json is
-- `cargo check --message-format=json` on genomlysning's fixtures/whynot,
-- one borrow error per function, in the label shape Space Rw builds.

local W = require("vango.xray.whynot")

local dir = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h") .. "/fixtures/whynot/"
local errors = vim.json.decode(io.open(dir .. "errors.json"):read("*a"))
local src = vim.fn.readfile(dir .. "main.rs")

local function err(code)
  for _, e in ipairs(errors) do
    if e.code == code then
      return e
    end
  end
  error("no " .. code)
end

local function bars(code)
  local out = {}
  for _, b in ipairs(W.model(err(code), src).bars) do
    out[#out + 1] = ("%s %d-%d"):format(b.kind, b.from + 1, b.to + 1)
  end
  table.sort(out)
  return out
end

describe("why not: bars from rustc's labels", function()
  it("a shared borrow spans its start to its last use (E0502)", function()
    assert.same({ "borrow 6-8" }, bars("E0502"))
  end)
  it("the first &mut is the bar, the second is the clash (E0499)", function()
    assert.same({ "borrow_mut 13-15" }, bars("E0499"))
  end)
  it("a moved value's life ends at the move (E0382)", function()
    assert.same({ "value 20-21" }, bars("E0382"))
  end)
  it("borrow and value overlap where the move happens (E0505)", function()
    assert.same({ "borrow 27-29", "value 26-28" }, bars("E0505"))
  end)
  it("the reference outlives the value's block (E0597)", function()
    assert.same({ "borrow 43-45", "value 42-44" }, bars("E0597"))
  end)
  it("a temporary lives one statement (E0716)", function()
    assert.same({ "borrow 50-51", "value 50-50" }, bars("E0716"))
  end)
  it("a closure's borrow escapes the function (E0373)", function()
    assert.same({ "borrow 56-57", "value 55-57" }, bars("E0373"))
  end)
end)

describe("why not: rendering", function()
  it("renders every error with its ✗ and a story", function()
    for _, e in ipairs(errors) do
      local m = W.model(e, src)
      local lines = W.render(m, src, 110)
      local text = table.concat(lines, "\n")
      assert.truthy(text:find("✗", 1, true), e.code)
      assert.truthy(W.CODES[e.code], "curated text for " .. e.code)
      assert.is_true(#W.story(m, src) > 20, e.code)
    end
  end)
  it("tells the story in plain words (E0502, E0382)", function()
    local s = W.story(W.model(err("E0502"), src), src)
    assert.truthy(s:find("line 6 (`first`) lasts until its last use on line 8", 1, true), s)
    assert.truthy(s:find("reallocating", 1, true), "push gets the realloc hint")
    s = W.story(W.model(err("E0382"), src), src)
    assert.truthy(s:find("moves on line 21 into `taken`", 1, true), s)
  end)
  it("explains with the rule, ways out and rustc's suggestions", function()
    local md = table.concat(W.explain(W.model(err("E0382"), src), src), "\n")
    assert.truthy(md:find("## The rule", 1, true))
    assert.truthy(md:find("## Ways out", 1, true))
    assert.truthy(md:find("clon", 1, true))
  end)
end)
