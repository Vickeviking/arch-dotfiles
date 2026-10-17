-- Deck highlights, derived from the active desk-theme palette
-- (~/.config/themes/current/nvim.lua) the same way colors/desk.lua does it.
-- apply() runs on every ColorScheme, so `desk-theme <name>` recolors the deck live.

local M = {}

local function rgb(h)
  return tonumber(h:sub(2, 3), 16), tonumber(h:sub(4, 5), 16), tonumber(h:sub(6, 7), 16)
end

local function mix(a, b, t) -- t of a, (1 - t) of b
  local ar, ag, ab = rgb(a)
  local br, bg, bb = rgb(b)
  return string.format("#%02X%02X%02X", ar * t + br * (1 - t), ag * t + bg * (1 - t), ab * t + bb * (1 - t))
end
M.mix = mix

local FALLBACK = {
  surface = "#0F1216", panel = "#171B21", border = "#2A3038", text = "#E6DCCB", muted = "#8A8F96",
  accent = "#F0913C", accent2 = "#6E9A9C", ok = "#8FB573", alert = "#E5534B",
  ansi = { "#171B21", "#E5534B", "#8FB573", "#E8B45A", "#6C8FB8", "#B07AA1", "#6E9A9C", "#CFC6B6",
    "#4A515C", "#F2726B", "#A9CC8E", "#F5C77A", "#8DAED3", "#C99BC0", "#8FBDBF", "#E6DCCB" },
}

function M.palette()
  local ok, p = pcall(dofile, vim.fn.expand("~/.config/themes/current/nvim.lua"))
  if ok and type(p) == "table" and p.accent then
    return p
  end
  return FALLBACK
end

function M.apply()
  local p = M.palette()
  local a = p.ansi
  -- the deck sits one step above the editor: panel is its ground, surface its wells
  local ground = p.panel
  local well = mix(p.surface, p.panel, 0.7)
  local rail = mix(p.surface, p.panel, 0.45)
  local hl = {
    DeckBackdrop = { bg = "#000000" },
    DeckNormal = { fg = p.text, bg = ground },
    DeckBorder = { fg = mix(p.accent, p.border, 0.35), bg = ground },
    DeckTitle = { fg = p.surface, bg = p.accent, bold = true },
    DeckFooter = { fg = p.muted, bg = ground },
    DeckFooterKey = { fg = p.accent, bg = ground, bold = true },
    DeckRail = { fg = p.muted, bg = rail },
    DeckRailSep = { fg = p.border, bg = rail },
    DeckRailNum = { fg = mix(p.muted, rail, 0.6), bg = rail },
    DeckRailSel = { fg = p.text, bg = mix(p.accent, rail, 0.16), bold = true },
    DeckRailSelNum = { fg = p.accent, bg = mix(p.accent, rail, 0.16), bold = true },
    DeckRailStripe = { fg = p.accent, bg = mix(p.accent, rail, 0.16) },
    DeckRailHead = { fg = p.accent2, bg = rail, bold = true },
    DeckCursorLine = { bg = mix(p.text, ground, 0.05) },
    DeckFocus = { fg = p.accent, bg = ground, bold = true },
    -- render-markdown, remapped inside the content window only
    DeckH1 = { fg = p.surface, bg = p.accent, bold = true },
    DeckH1Bg = { fg = p.accent, bg = mix(p.accent, ground, 0.14), bold = true },
    DeckH2Bg = { fg = a[15], bg = mix(p.accent2, ground, 0.14), bold = true },
    DeckH3Bg = { fg = a[12], bg = mix(a[12], ground, 0.08), bold = true },
    DeckCode = { bg = well },
    DeckCodeInline = { fg = mix(p.accent, p.text, 0.55), bg = well },
    DeckTableHead = { fg = p.accent2, bold = true },
    DeckTableRow = { fg = p.border },
    DeckQuote = { fg = p.accent2 },
    DeckBullet = { fg = p.accent },
    DeckDash = { fg = p.border },
    DeckKbd = { fg = p.accent, bold = true },
  }
  for group, spec in pairs(hl) do
    vim.api.nvim_set_hl(0, group, spec)
  end
end

-- winhighlight for the content window: render-markdown and the editor groups
-- point at deck colors here, without touching any other window.
M.content_winhl = table.concat({
  "Normal:DeckNormal",
  "NormalFloat:DeckNormal",
  "FloatBorder:DeckBorder",
  "CursorLine:DeckCursorLine",
  "EndOfBuffer:DeckNormal",
  "RenderMarkdownH1:DeckH1Bg",
  "RenderMarkdownH1Bg:DeckH1Bg",
  "RenderMarkdownH2:DeckH2Bg",
  "RenderMarkdownH2Bg:DeckH2Bg",
  "RenderMarkdownH3:DeckH3Bg",
  "RenderMarkdownH3Bg:DeckH3Bg",
  "RenderMarkdownCode:DeckCode",
  "RenderMarkdownCodeInline:DeckCodeInline",
  "RenderMarkdownTableHead:DeckTableHead",
  "RenderMarkdownTableRow:DeckTableRow",
  "RenderMarkdownQuote:DeckQuote",
  "RenderMarkdownBullet:DeckBullet",
  "RenderMarkdownDash:DeckDash",
}, ",")

M.rail_winhl = "Normal:DeckRail,NormalFloat:DeckRail,FloatBorder:DeckRailSep,CursorLine:DeckRail,EndOfBuffer:DeckRail"
M.frame_winhl = "Normal:DeckNormal,NormalFloat:DeckNormal,FloatBorder:DeckBorder,FloatTitle:DeckTitle,FloatFooter:DeckFooter"

return M
