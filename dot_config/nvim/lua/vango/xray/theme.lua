-- X-ray colors, from the desk-theme palette like the deck's. One color per
-- kind of pointer, used the same way inline, in the memory map and in the
-- legend: owns · shares · weak · borrows · borrows mut.

local deck = require("vango.deck.theme")

local M = {}

M.KIND_HL = {
  owns = "XrayOwns",
  pointer = "XrayOwns",
  shared = "XrayShares",
  weak = "XrayWeak",
  borrow = "XrayBorrow",
  borrow_mut = "XrayBorrowMut",
  atomic = "XrayAtomic",
  ref = "XrayBorrow", -- C++ `T &`
}

-- the arrow drawn for each kind, inline and in the legend
M.ARROW = { owns = "─▶", pointer = "─▶", shared = "═▶", weak = "┄▶", borrow = "─▷", borrow_mut = "━▶", atomic = "╍▶", ref = "─▷" }

M.WORD = { owns = "owns", pointer = "points", shared = "shares", weak = "weak", borrow = "borrows", borrow_mut = "borrows mut", atomic = "atomic", ref = "refers" }

-- which kind wins when several meet on one line of the map
M.RANK = { weak = 1, borrow = 2, ref = 2, atomic = 3, owns = 3, pointer = 3, shared = 4, borrow_mut = 5 }

M.TONE_HL = { plain = "XrayValue", ok = "XrayOk", warn = "XrayWarn", alert = "XrayAlert", muted = "XrayDim" }

function M.apply()
  local p = deck.palette()
  local a = p.ansi
  local mix = deck.mix
  local ground = p.panel
  local hl = {
    XrayOwns = { fg = a[13] },
    XrayShares = { fg = a[12] },
    XrayAtomic = { fg = a[15] },
    XrayWeak = { fg = p.muted },
    XrayBorrow = { fg = p.ok },
    XrayBorrowMut = { fg = p.alert, bold = true },
    XrayName = { fg = p.text, bold = true },
    XrayType = { fg = mix(a[15], p.muted, 0.55) },
    XrayValue = { fg = p.text },
    XrayDim = { fg = p.muted },
    XrayFaint = { fg = mix(p.muted, ground, 0.55) },
    XrayChanged = { fg = p.accent, bold = true },
    XrayAlert = { fg = p.alert },
    XrayWarn = { fg = a[12] },
    XrayOk = { fg = p.ok },
    XrayBadgeNew = { fg = p.surface, bg = p.accent, bold = true },
    XrayBadgeMoved = { fg = p.surface, bg = p.alert, bold = true },
    XrayBadgeChanged = { fg = p.accent, bg = mix(p.accent, ground, 0.2), bold = true },
    XrayCard = { fg = mix(p.accent2, p.border, 0.5) },
    XrayCardTitle = { fg = p.accent2, bold = true },
    XrayBox = { fg = mix(a[13], p.border, 0.45) },
    XrayLabel = { fg = p.surface, bg = a[13], bold = true },
    XraySpare = { fg = mix(p.muted, ground, 0.45) },
    XrayCell = { fg = p.text, bg = mix(p.surface, ground, 0.55) },
    XrayMoved = { fg = p.muted, strikethrough = true },
    XrayHead = { fg = p.accent2, bold = true },
    -- inline, on the editor's own background
    XrayInline = { fg = mix(p.text, p.muted, 0.35), italic = true },
    XrayInlineSep = { fg = mix(p.border, p.surface, 0.8) },
  }
  for group, spec in pairs(hl) do
    vim.api.nvim_set_hl(0, group, spec)
  end
end

return M
