-- desk: colorscheme built from the active desk-theme palette
-- (~/.config/themes/current/nvim.lua, written by `desk-theme <name>`).
-- `desk-theme` re-runs `:colorscheme desk` in every open nvim, so switching is live.

local ok, p = pcall(dofile, vim.fn.expand("~/.config/themes/current/nvim.lua"))
if not ok or type(p) ~= "table" then
  vim.notify("desk colorscheme: no palette, falling back to default", vim.log.levels.WARN)
  vim.cmd("colorscheme default")
  return
end

vim.cmd("highlight clear")
if vim.fn.exists("syntax_on") == 1 then
  vim.cmd("syntax reset")
end
vim.o.background = "dark"
vim.o.termguicolors = true
vim.g.colors_name = "desk"

-- helpers ---------------------------------------------------------------
local function rgb(h)
  return tonumber(h:sub(2, 3), 16), tonumber(h:sub(4, 5), 16), tonumber(h:sub(6, 7), 16)
end
local function mix(a, b, t) -- t of a, (1 - t) of b
  local ar, ag, ab = rgb(a)
  local br, bg, bb = rgb(b)
  return string.format("#%02X%02X%02X", ar * t + br * (1 - t), ag * t + bg * (1 - t), ab * t + bb * (1 - t))
end

local a = p.ansi
local c = {
  none = "NONE",
  bg = p.surface,
  panel = p.panel,
  border = p.border,
  fg = p.text,
  muted = p.muted,
  faint = mix(p.muted, p.surface, 0.55),
  accent = p.accent,
  accent2 = p.accent2,
  ok = p.ok,
  alert = p.alert,
  yellow = a[12], -- bright yellow
  blue = a[13], -- bright blue
  magenta = a[14], -- bright magenta
  cyan = a[15], -- bright cyan
  sel = mix(p.accent, p.surface, 0.22),
  line = mix(p.text, p.surface, 0.06),
  search = mix(p.accent, p.surface, 0.35),
}

local hl = {}

-- editor --------------------------------------------------------------
hl.Normal = { fg = c.fg, bg = c.none } -- transparent: kitty's translucency shows through
hl.NormalNC = { fg = c.fg, bg = c.none }
hl.NormalFloat = { fg = c.fg, bg = c.panel }
hl.FloatBorder = { fg = c.border, bg = c.panel }
hl.FloatTitle = { fg = c.accent, bg = c.panel, bold = true }
hl.WinSeparator = { fg = c.border }
hl.VertSplit = { fg = c.border }
hl.Cursor = { fg = c.bg, bg = c.accent }
hl.CursorLine = { bg = c.line }
hl.CursorColumn = { bg = c.line }
hl.ColorColumn = { bg = c.line }
hl.CursorLineNr = { fg = c.accent, bold = true }
hl.LineNr = { fg = c.faint }
hl.SignColumn = { bg = c.none }
hl.FoldColumn = { fg = c.faint, bg = c.none }
hl.Folded = { fg = c.muted, bg = c.panel, italic = true }
hl.Visual = { bg = c.sel }
hl.VisualNOS = { bg = c.sel }
hl.Search = { fg = c.fg, bg = c.search }
hl.IncSearch = { fg = c.bg, bg = c.accent, bold = true }
hl.CurSearch = { fg = c.bg, bg = c.accent, bold = true }
hl.Substitute = { fg = c.bg, bg = c.alert }
hl.MatchParen = { fg = c.accent, bold = true, underline = true }
hl.NonText = { fg = c.faint }
hl.Whitespace = { fg = c.faint }
hl.SpecialKey = { fg = c.faint }
hl.EndOfBuffer = { fg = c.bg }
hl.Pmenu = { fg = c.fg, bg = c.panel }
hl.PmenuSel = { fg = c.bg, bg = c.accent, bold = true }
hl.PmenuSbar = { bg = c.panel }
hl.PmenuThumb = { bg = c.border }
hl.StatusLine = { fg = c.fg, bg = c.panel }
hl.StatusLineNC = { fg = c.muted, bg = c.panel }
hl.TabLine = { fg = c.muted, bg = c.panel }
hl.TabLineFill = { bg = c.none }
hl.TabLineSel = { fg = c.bg, bg = c.accent, bold = true }
hl.WildMenu = { fg = c.bg, bg = c.accent }
hl.Title = { fg = c.accent, bold = true }
hl.Directory = { fg = c.accent2 }
hl.Question = { fg = c.accent2 }
hl.MoreMsg = { fg = c.accent2 }
hl.ModeMsg = { fg = c.fg, bold = true }
hl.ErrorMsg = { fg = c.alert }
hl.WarningMsg = { fg = c.yellow }
hl.QuickFixLine = { bg = c.sel }
hl.SpellBad = { sp = c.alert, undercurl = true }
hl.SpellCap = { sp = c.yellow, undercurl = true }
hl.SpellRare = { sp = c.magenta, undercurl = true }
hl.SpellLocal = { sp = c.cyan, undercurl = true }
hl.DiffAdd = { bg = mix(c.ok, c.bg, 0.18) }
hl.DiffChange = { bg = mix(c.blue, c.bg, 0.14) }
hl.DiffDelete = { fg = c.alert, bg = mix(c.alert, c.bg, 0.16) }
hl.DiffText = { bg = mix(c.blue, c.bg, 0.30) }

-- syntax --------------------------------------------------------------
hl.Comment = { fg = c.muted, italic = true }
hl.Constant = { fg = c.magenta }
hl.String = { fg = c.ok }
hl.Character = { fg = c.ok }
hl.Number = { fg = c.magenta }
hl.Boolean = { fg = c.magenta, bold = true }
hl.Float = { fg = c.magenta }
hl.Identifier = { fg = c.fg }
hl.Function = { fg = c.cyan }
hl.Statement = { fg = c.accent }
hl.Conditional = { fg = c.accent }
hl.Repeat = { fg = c.accent }
hl.Label = { fg = c.accent }
hl.Operator = { fg = mix(c.fg, c.muted, 0.6) }
hl.Keyword = { fg = c.accent }
hl.Exception = { fg = c.alert }
hl.PreProc = { fg = c.yellow }
hl.Include = { fg = c.accent }
hl.Define = { fg = c.accent }
hl.Macro = { fg = c.yellow }
hl.PreCondit = { fg = c.yellow }
hl.Type = { fg = c.yellow }
hl.StorageClass = { fg = c.accent }
hl.Structure = { fg = c.yellow }
hl.Typedef = { fg = c.yellow }
hl.Special = { fg = c.blue }
hl.SpecialChar = { fg = c.blue }
hl.Tag = { fg = c.accent2 }
hl.Delimiter = { fg = mix(c.fg, c.muted, 0.5) }
hl.SpecialComment = { fg = c.muted, italic = true }
hl.Debug = { fg = c.alert }
hl.Underlined = { underline = true }
hl.Error = { fg = c.alert }
hl.Todo = { fg = c.bg, bg = c.accent, bold = true }

-- treesitter -------------------------------------------------------------
hl["@variable"] = { fg = c.fg }
hl["@variable.builtin"] = { fg = c.magenta, italic = true }
hl["@variable.parameter"] = { fg = mix(c.fg, c.accent2, 0.75) }
hl["@variable.member"] = { fg = mix(c.fg, c.cyan, 0.7) }
hl["@property"] = { link = "@variable.member" }
hl["@constant"] = { link = "Constant" }
hl["@constant.builtin"] = { fg = c.magenta, bold = true }
hl["@constant.macro"] = { link = "Macro" }
hl["@module"] = { fg = c.blue }
hl["@label"] = { link = "Label" }
hl["@string"] = { link = "String" }
hl["@string.escape"] = { fg = c.blue }
hl["@string.regexp"] = { fg = c.blue }
hl["@string.special"] = { fg = c.blue }
hl["@character"] = { link = "Character" }
hl["@number"] = { link = "Number" }
hl["@boolean"] = { link = "Boolean" }
hl["@type"] = { link = "Type" }
hl["@type.builtin"] = { fg = c.yellow, italic = true }
hl["@attribute"] = { fg = c.yellow }
hl["@function"] = { link = "Function" }
hl["@function.builtin"] = { fg = c.cyan, italic = true }
hl["@function.macro"] = { fg = c.yellow }
hl["@function.method"] = { link = "Function" }
hl["@constructor"] = { fg = c.yellow }
hl["@operator"] = { link = "Operator" }
hl["@keyword"] = { link = "Keyword" }
hl["@keyword.function"] = { fg = c.accent, italic = true }
hl["@keyword.return"] = { fg = c.accent, bold = true }
hl["@keyword.import"] = { link = "Include" }
hl["@keyword.exception"] = { link = "Exception" }
hl["@lifetime"] = { fg = c.magenta, italic = true }
hl["@punctuation"] = { link = "Delimiter" }
hl["@punctuation.special"] = { fg = c.accent }
hl["@comment"] = { link = "Comment" }
hl["@comment.todo"] = { link = "Todo" }
hl["@tag"] = { fg = c.accent }
hl["@tag.attribute"] = { fg = c.yellow }
hl["@tag.delimiter"] = { fg = c.muted }
hl["@markup.heading"] = { fg = c.accent, bold = true }
hl["@markup.strong"] = { bold = true }
hl["@markup.italic"] = { italic = true }
hl["@markup.link"] = { fg = c.accent2, underline = true }
hl["@markup.raw"] = { fg = c.ok }
hl["@markup.list"] = { fg = c.accent }
hl["@markup.quote"] = { fg = c.muted, italic = true }
hl["@lsp.type.macro"] = { link = "Macro" }
hl["@lsp.type.lifetime"] = { link = "@lifetime" }
hl["@lsp.mod.mutable"] = { underline = true }

-- diagnostics + LSP -------------------------------------------------------
hl.DiagnosticError = { fg = c.alert }
hl.DiagnosticWarn = { fg = c.yellow }
hl.DiagnosticInfo = { fg = c.accent2 }
hl.DiagnosticHint = { fg = c.blue }
hl.DiagnosticOk = { fg = c.ok }
hl.DiagnosticUnderlineError = { sp = c.alert, undercurl = true }
hl.DiagnosticUnderlineWarn = { sp = c.yellow, undercurl = true }
hl.DiagnosticUnderlineInfo = { sp = c.accent2, undercurl = true }
hl.DiagnosticUnderlineHint = { sp = c.blue, undercurl = true }
hl.DiagnosticVirtualTextError = { fg = c.alert, bg = mix(c.alert, c.bg, 0.10) }
hl.DiagnosticVirtualTextWarn = { fg = c.yellow, bg = mix(c.yellow, c.bg, 0.10) }
hl.DiagnosticVirtualTextInfo = { fg = c.accent2, bg = mix(c.accent2, c.bg, 0.10) }
hl.DiagnosticVirtualTextHint = { fg = c.blue, bg = mix(c.blue, c.bg, 0.10) }
hl.LspReferenceText = { bg = c.line }
hl.LspReferenceRead = { bg = c.line }
hl.LspReferenceWrite = { bg = c.line, underline = true }
hl.LspInlayHint = { fg = c.faint, italic = true }
hl.LspSignatureActiveParameter = { fg = c.accent, bold = true }

-- plugins ---------------------------------------------------------------
-- telescope
hl.TelescopeNormal = { fg = c.fg, bg = c.panel }
hl.TelescopeBorder = { fg = c.border, bg = c.panel }
hl.TelescopeTitle = { fg = c.bg, bg = c.accent, bold = true }
hl.TelescopePromptPrefix = { fg = c.accent }
hl.TelescopeSelection = { bg = c.sel }
hl.TelescopeSelectionCaret = { fg = c.accent }
hl.TelescopeMatching = { fg = c.accent, bold = true }
-- nvim-tree
hl.NvimTreeNormal = { fg = c.fg, bg = c.none }
hl.NvimTreeFolderName = { fg = c.accent2 }
hl.NvimTreeOpenedFolderName = { fg = c.accent2, bold = true }
hl.NvimTreeFolderIcon = { fg = c.accent }
hl.NvimTreeRootFolder = { fg = c.accent, bold = true }
hl.NvimTreeGitDirty = { fg = c.yellow }
hl.NvimTreeGitNew = { fg = c.ok }
hl.NvimTreeGitDeleted = { fg = c.alert }
hl.NvimTreeIndentMarker = { fg = c.border }
hl.NvimTreeWinSeparator = { fg = c.border }
-- bufferline
hl.BufferLineFill = { bg = c.none }
hl.BufferLineBufferSelected = { fg = c.fg, bold = true }
hl.BufferLineIndicatorSelected = { fg = c.accent }
-- gitsigns
hl.GitSignsAdd = { fg = c.ok }
hl.GitSignsChange = { fg = c.yellow }
hl.GitSignsDelete = { fg = c.alert }
-- cmp
hl.CmpItemAbbrMatch = { fg = c.accent, bold = true }
hl.CmpItemAbbrMatchFuzzy = { fg = c.accent }
hl.CmpItemKindFunction = { fg = c.cyan }
hl.CmpItemKindMethod = { fg = c.cyan }
hl.CmpItemKindVariable = { fg = c.fg }
hl.CmpItemKindKeyword = { fg = c.accent }
hl.CmpItemKindStruct = { fg = c.yellow }
hl.CmpItemKindText = { fg = c.muted }
hl.CmpItemMenu = { fg = c.faint }
-- which-key
hl.WhichKey = { fg = c.accent }
hl.WhichKeyGroup = { fg = c.accent2 }
hl.WhichKeyDesc = { fg = c.fg }
hl.WhichKeySeparator = { fg = c.faint }
hl.WhichKeyNormal = { bg = c.panel }
-- noice / notify
hl.NoiceCmdlinePopupBorder = { fg = c.accent }
hl.NoiceCmdlineIcon = { fg = c.accent }
hl.NoiceCmdlinePopupTitle = { fg = c.accent }
-- flash
hl.FlashLabel = { fg = c.bg, bg = c.accent, bold = true }
hl.FlashMatch = { fg = c.fg, bg = c.search }
hl.FlashCurrent = { fg = c.bg, bg = c.accent2 }
hl.FlashBackdrop = { fg = c.faint }
-- indent-blankline
hl.IblIndent = { fg = mix(c.border, c.bg, 0.7) }
hl.IblScope = { fg = c.accent2 }
-- trouble / todo-comments
hl.TroubleNormal = { fg = c.fg, bg = c.none }
hl.TodoBgTODO = { fg = c.bg, bg = c.accent, bold = true }
hl.TodoFgTODO = { fg = c.accent }
hl.TodoBgFIX = { fg = c.bg, bg = c.alert, bold = true }
hl.TodoFgFIX = { fg = c.alert }
hl.TodoBgNOTE = { fg = c.bg, bg = c.accent2, bold = true }
hl.TodoFgNOTE = { fg = c.accent2 }
-- snacks / alpha dashboard
hl.SnacksDashboardHeader = { fg = c.accent }
hl.SnacksDashboardKey = { fg = c.accent2 }
hl.AlphaHeader = { fg = c.accent }
hl.AlphaButtons = { fg = c.accent2 }
-- render-markdown
hl.RenderMarkdownH1Bg = { bg = mix(c.accent, c.bg, 0.15) }
hl.RenderMarkdownH2Bg = { bg = mix(c.accent2, c.bg, 0.15) }
hl.RenderMarkdownCode = { bg = c.panel }

for group, spec in pairs(hl) do
  vim.api.nvim_set_hl(0, group, spec)
end

-- terminal colors inside :terminal / toggleterm follow the palette too
for i = 0, 15 do
  vim.g["terminal_color_" .. i] = a[i + 1]
end
