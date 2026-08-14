-- lectern — brown leather. Companion to the ghostty theme of the same name.

local p = {
  bg         = "#392a22",
  fg         = "#ddd3c7",
  ink        = "#291c16", -- ghostty cursor-text; darkest ground
  bg_dark    = "#2e211a", -- derived: floats / popups
  bg_soft    = "#46352b", -- derived: cursorline
  sel_bg     = "#334a62",
  sel_fg     = "#f5ecdd",
  cursor     = "#df8623",

  black      = "#655851",
  red        = "#e26b6a",
  green      = "#61ab7c",
  orange     = "#dd8e42",
  blue       = "#6299d1",
  magenta    = "#bd78ae",
  cyan       = "#58a8b1",
  white      = "#ddd3c7",

  gray       = "#948a83",
  br_red     = "#ff928f",
  br_green   = "#8acaa0",
  br_orange  = "#f8b171",
  br_blue    = "#8abbed",
  br_magenta = "#dc9dce",
  br_cyan    = "#83c8d0",
  br_white   = "#f5ecdd",
}

vim.cmd("highlight clear")
if vim.fn.exists("syntax_on") == 1 then
  vim.cmd("syntax reset")
end
vim.g.colors_name = "lectern"
vim.o.background = "dark"

for i, c in ipairs({
  p.black, p.red, p.green, p.orange, p.blue, p.magenta, p.cyan, p.white,
  p.gray, p.br_red, p.br_green, p.br_orange, p.br_blue, p.br_magenta,
  p.br_cyan, p.br_white,
}) do
  vim.g["terminal_color_" .. (i - 1)] = c
end

local function hl(group, spec)
  vim.api.nvim_set_hl(0, group, spec)
end

-- UI
hl("Normal", { fg = p.fg, bg = p.bg })
hl("NormalFloat", { fg = p.fg, bg = p.bg_dark })
hl("FloatBorder", { fg = p.gray, bg = p.bg_dark })
hl("FloatTitle", { fg = p.orange, bg = p.bg_dark, bold = true })
hl("Cursor", { fg = p.ink, bg = p.cursor })
hl("CursorLine", { bg = p.bg_soft })
hl("CursorColumn", { bg = p.bg_soft })
hl("ColorColumn", { bg = p.bg_soft })
hl("CursorLineNr", { fg = p.orange, bold = true })
hl("LineNr", { fg = p.black })
hl("SignColumn", { bg = "NONE" })
hl("Visual", { fg = p.sel_fg, bg = p.sel_bg })
hl("Search", { fg = p.ink, bg = p.orange })
hl("IncSearch", { fg = p.ink, bg = p.cursor })
hl("CurSearch", { link = "IncSearch" })
hl("MatchParen", { bg = p.sel_bg, bold = true })
hl("Pmenu", { fg = p.fg, bg = p.bg_dark })
hl("PmenuSel", { fg = p.sel_fg, bg = p.sel_bg })
hl("PmenuSbar", { bg = p.bg_dark })
hl("PmenuThumb", { bg = p.black })
hl("StatusLine", { fg = p.fg, bg = p.bg_dark })
hl("StatusLineNC", { fg = p.gray, bg = p.bg_dark })
hl("WinSeparator", { fg = p.black })
hl("TabLine", { fg = p.gray, bg = p.bg_dark })
hl("TabLineFill", { bg = p.bg_dark })
hl("TabLineSel", { fg = p.br_white, bg = p.bg })
hl("Folded", { fg = p.gray, bg = p.bg_dark })
hl("FoldColumn", { fg = p.black })
hl("NonText", { fg = p.black })
hl("Whitespace", { fg = p.black })
hl("SpecialKey", { fg = p.black })
hl("EndOfBuffer", { fg = p.bg })
hl("Directory", { fg = p.blue })
hl("Title", { fg = p.orange, bold = true })
hl("ErrorMsg", { fg = p.br_red })
hl("WarningMsg", { fg = p.br_orange })
hl("MoreMsg", { fg = p.green })
hl("Question", { fg = p.green })
hl("ModeMsg", { fg = p.fg, bold = true })
hl("QuickFixLine", { bg = p.sel_bg })
hl("WildMenu", { link = "PmenuSel" })

-- Diffs
hl("DiffAdd", { bg = "#3e4130" })
hl("DiffChange", { bg = "#3a3e4a" })
hl("DiffDelete", { fg = p.red, bg = "#55332e" })
hl("DiffText", { bg = p.sel_bg })
hl("Added", { fg = p.green })
hl("Changed", { fg = p.orange })
hl("Removed", { fg = p.red })

-- Syntax
hl("Comment", { fg = p.gray, italic = true })
hl("Constant", { fg = p.magenta })
hl("String", { fg = p.green })
hl("Character", { fg = p.green })
hl("Number", { fg = p.magenta })
hl("Boolean", { fg = p.magenta })
hl("Float", { fg = p.magenta })
hl("Identifier", { fg = p.fg })
hl("Function", { fg = p.blue })
hl("Statement", { fg = p.red })
hl("Keyword", { fg = p.red })
hl("Conditional", { fg = p.red })
hl("Repeat", { fg = p.red })
hl("Label", { fg = p.red })
hl("Operator", { fg = p.br_white })
hl("Exception", { fg = p.red })
hl("PreProc", { fg = p.cyan })
hl("Include", { fg = p.cyan })
hl("Define", { fg = p.cyan })
hl("Macro", { fg = p.cyan })
hl("Type", { fg = p.br_orange })
hl("StorageClass", { fg = p.br_orange })
hl("Structure", { fg = p.br_orange })
hl("Typedef", { fg = p.br_orange })
hl("Special", { fg = p.cyan })
hl("SpecialChar", { fg = p.br_cyan })
hl("Tag", { fg = p.red })
hl("Delimiter", { fg = p.fg })
hl("SpecialComment", { fg = p.gray, bold = true })
hl("Debug", { fg = p.br_red })
hl("Underlined", { fg = p.blue, underline = true })
hl("Error", { fg = p.br_red })
hl("Todo", { fg = p.br_magenta, bold = true })

-- Treesitter (most @groups default-link to the standard groups above)
hl("@variable", { fg = p.fg })
hl("@variable.builtin", { fg = p.br_orange })
hl("@variable.member", { fg = p.br_cyan })
hl("@property", { fg = p.br_cyan })
hl("@constructor", { fg = p.br_orange })
hl("@tag", { fg = p.red })
hl("@tag.attribute", { fg = p.br_orange })
hl("@tag.delimiter", { fg = p.gray })
hl("@punctuation.bracket", { fg = p.fg })
hl("@punctuation.delimiter", { fg = p.fg })
hl("@markup.heading", { fg = p.orange, bold = true })
hl("@markup.strong", { bold = true })
hl("@markup.italic", { italic = true })
hl("@markup.link", { fg = p.blue, underline = true })
hl("@markup.raw", { fg = p.green })
hl("@markup.list", { fg = p.orange })

-- Diagnostics
hl("DiagnosticError", { fg = p.br_red })
hl("DiagnosticWarn", { fg = p.br_orange })
hl("DiagnosticInfo", { fg = p.br_blue })
hl("DiagnosticHint", { fg = p.br_cyan })
hl("DiagnosticUnderlineError", { undercurl = true, sp = p.br_red })
hl("DiagnosticUnderlineWarn", { undercurl = true, sp = p.br_orange })
hl("DiagnosticUnderlineInfo", { undercurl = true, sp = p.br_blue })
hl("DiagnosticUnderlineHint", { undercurl = true, sp = p.br_cyan })

-- Spelling
hl("SpellBad", { undercurl = true, sp = p.br_red })
hl("SpellCap", { undercurl = true, sp = p.br_orange })
hl("SpellLocal", { undercurl = true, sp = p.br_cyan })
hl("SpellRare", { undercurl = true, sp = p.br_magenta })

-- Gitsigns
hl("GitSignsAdd", { fg = p.green })
hl("GitSignsChange", { fg = p.orange })
hl("GitSignsDelete", { fg = p.red })

-- nvim-cmp
hl("CmpItemAbbrMatch", { fg = p.br_blue, bold = true })
hl("CmpItemAbbrMatchFuzzy", { fg = p.br_blue })
hl("CmpItemKind", { fg = p.magenta })
hl("CmpItemMenu", { fg = p.gray })

-- nvim-tree
hl("NvimTreeRootFolder", { fg = p.orange, bold = true })
hl("NvimTreeFolderIcon", { fg = p.blue })
hl("NvimTreeFolderName", { fg = p.blue })
hl("NvimTreeOpenedFolderName", { fg = p.br_blue })
hl("NvimTreeGitDirty", { fg = p.orange })
hl("NvimTreeGitNew", { fg = p.green })
hl("NvimTreeGitDeleted", { fg = p.red })
hl("NvimTreeSpecialFile", { fg = p.br_orange })

-- indentmini (init.lua leaves these to the colorscheme when lectern is active)
hl("IndentLine", { fg = "#4d3e33", bg = "NONE" })
hl("IndentLineCurrent", { fg = p.gray, bg = "NONE" })
