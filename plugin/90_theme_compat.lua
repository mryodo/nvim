-- ┌─────────────────────────────────┐
-- │ Highlight groups for any scheme │
-- └─────────────────────────────────┘
--
-- The active colorscheme is 'ayugloom' ('plugin/93_ui.lua'), but several parts
-- of this config still draw with highlight groups that only 'jb.nvim' defines:
--
-- - `jb.borders` border styles ('plugin/94_completion.lua', 'plugin/95_fzf.lua',
--   'lua/netrw.lua') name `DialogFloatBorder*` and `ToolWindowFloatBorder*` per
--   border cell.
-- - 'fzf-lua' colours LSP symbols with `JBIcon<kind>` and the 'jb.nvim' lualine
--   `nav_bar` component uses `JBIconModule`.
-- - 'plugin/92_statusline.lua' links its groups to `MiniStatusline*`, which
--   nothing defines because 'mini.statusline' is deliberately not set up.
--
-- A link to an undefined group renders as `Normal`, which is how the shadowed
-- dialog borders turn into solid blocks and symbol icons lose their colour.
-- Everything below is set with `default = true`, so it only fills gaps: under
-- `:colorscheme jb` the real definitions still win. `:colorscheme` clears all
-- highlights, hence the `ColorScheme` autocommand.

-- stylua: ignore
local links = {
  -- Dialog (centred float) borders ------------------------------------------
  DialogFloatBorder                   = 'FloatBorder',
  DialogFloatBorderTop                = 'FloatBorder',
  DialogFloatBorderCorner             = 'FloatBorder',
  DialogFloatBorderBetween            = 'FloatBorder',
  DialogFloatBorderEditorArea         = 'FloatBorder',
  DialogNotificationFloatBorder       = 'FloatBorder',
  -- The drop shadow sits outside the box and should stay dimmer than the border
  DialogFloatBorderOuter              = 'NonText',
  DialogFloatBorderOuterShadowedDark  = 'NonText',
  DialogFloatBorderOuterShadowedLight = 'NonText',
  DialogNotificationFloatBorderOuter  = 'NonText',

  -- Tool windows (full-height side floats, e.g. the netrw explorer) ----------
  ToolWindowFloatBorder    = 'FloatBorder',
  ToolWindowFloatBorderTop = 'FloatBorder',
  ToolWindowFloatTitle     = 'FloatTitle',
  ToolWindowFloatFooter    = 'FloatBorder',
  ToolWindowFloatNormal    = 'NormalFloat',
  NetrwCursorLine          = 'CursorLine',

  -- Breadcrumbs ('plugin/92_statusline.lua') --------------------------------
  -- 'nvim-navic' only ever *references* these; nothing defines them outside of
  -- `:colorscheme jb`.
  NavicText      = 'Comment',
  NavicSeparator = 'NonText',

  -- Statusline --------------------------------------------------------------
  StatusBarHasUnsavedBuffers = 'DiagnosticWarn',
  MiniStatuslineNormal       = 'StatusLine',
  MiniStatuslineDevInfo      = 'StatusLine',
  MiniStatuslineModeNormal   = 'Search',
  MiniStatuslineModeInsert   = 'DiffAdd',
  MiniStatuslineModeVisual   = 'DiffChange',
  MiniStatuslineModeCommand  = 'DiffText',
}

-- LSP symbol kinds. 'fzf-lua' asks for `JBIcon` .. kind:lower(), 'jb.nvim'
-- defines the capitalised spelling, so both are provided. 'nvim-navic' asks for
-- `NavicIcons` .. kind for the status line breadcrumbs and defines none of them
-- itself, so it is filled from the same table.
-- stylua: ignore
local kind_links = {
  Array         = '@punctuation.bracket', Boolean    = 'Boolean',
  Class         = '@lsp.type.class',      Color      = 'Special',
  Constant      = 'Constant',             Constructor = '@constructor',
  Enum          = '@lsp.type.enum',       EnumMember = '@lsp.type.enumMember',
  Event         = '@lsp.type.event',      Field      = '@variable.member',
  File          = 'Directory',            Folder     = 'Directory',
  Function      = '@function',            Interface  = '@lsp.type.interface',
  Key           = '@variable.member',     Keyword    = '@keyword',
  Method        = '@function.method',     Module     = '@module',
  Namespace     = '@module',              Null       = 'Constant',
  Number        = 'Number',               Object     = '@lsp.type.class',
  Operator      = '@operator',            Package    = '@module',
  Property      = '@property',            Reference  = '@variable',
  Snippet       = 'Special',              String     = 'String',
  Struct        = '@lsp.type.struct',     Text       = '@string',
  TypeParameter = '@lsp.type.typeParameter',
  Unit          = 'Number',               Value      = 'Constant',
  Variable      = '@variable',
}

-- 'blink.cmp' kind icons are drawn inverted: the kind colour fills the cell of
-- the kind column ('plugin/94_completion.lua') and the glyph is knocked out of
-- it in the menu background colour. 'ayugloom' already defines every
-- `BlinkCmpKind<kind>` that way; this keeps it so under any colour scheme.
-- `BlinkCmpKindUnknown` (the fallback for an item whose kind 'blink.cmp' does
-- not recognise) is named explicitly because nothing defines it, so it is not
-- in the highlight table to be found by the scan.
--
-- The groups have to be resolved with `link = false` first: a highlight
-- definition is either a link or a set of attributes, so `reverse` cannot be
-- added on top of a link.
local reverse_blink_kinds = function()
	local names = { BlinkCmpKindUnknown = true }
	for name in pairs(vim.api.nvim_get_hl(0, {})) do
		if name:find("^BlinkCmpKind") ~= nil then
			names[name] = true
		end
	end
	for name in pairs(names) do
		local attrs = vim.api.nvim_get_hl(0, { name = name, link = false })
		if not attrs.reverse then
			attrs.reverse = true
			vim.api.nvim_set_hl(0, name, attrs)
		end
	end
end

--- Mix two 0xRRGGBB colours: `t = 0` is `a`, `t = 1` is `b`
local blend = function(a, b, t)
	local mix = function(shift)
		local x, y = bit.band(bit.rshift(a, shift), 0xff), bit.band(bit.rshift(b, shift), 0xff)
		return bit.lshift(math.floor(x + (y - x) * t + 0.5), shift)
	end
	return mix(16) + mix(8) + mix(0)
end

--- One tinted surface for every floating window -- pickers, completion, hover,
--- diagnostics, which-key, notifications -- so none of them blends into the
--- text behind it. Themes give floats `Normal`'s background, which Ghostty
--- clears to NONE (see below). The tint is the theme's `StatusLine`
--- background; the selected row is that tint pushed towards the text colour.
--- Border for a float that sits right of another one (a picker's preview, a
--- mini.files column): the usual tint padding, plus a faint vertical rule on
--- the left edge so the two read as separate panes.
local sep = { "│", "FloatSeparator" }
Config.float_border_after = { sep, " ", " ", " ", " ", " ", sep, sep }

local apply_surfaces = function()
	local get = function(name)
		return vim.api.nvim_get_hl(0, { name = name, link = false })
	end
	local set = vim.api.nvim_set_hl
	local light = vim.o.background == "light"
	local normal = get("Normal")
	local fg = normal.fg or (light and 0x000000 or 0xd0d0d0)
	local bg = normal.bg or (light and 0xffffff or 0x101010)
	local tint = get("StatusLine").bg or blend(bg, fg, 0.08)
	local comment = get("Comment").fg or blend(bg, fg, 0.5)
	local nontext = get("NonText").fg or comment
	local warn = get("DiagnosticWarn").fg or comment
	local selected = blend(tint, fg, 0.12)

	set(0, "NormalFloat", { fg = fg, bg = tint })
	set(0, "FloatBorder", { fg = get("FloatBorder").fg or comment, bg = tint })
	set(0, "FloatTitle", { fg = fg, bg = tint, bold = true })
	set(0, "FloatCursorLine", { bg = selected })
	set(0, "FloatSeparator", { fg = blend(tint, fg, 0.25), bg = tint })
	set(0, "Pmenu", { fg = fg, bg = tint })
	set(0, "PmenuSel", { bg = selected, bold = true })
	set(0, "PmenuSbar", { bg = tint })
	set(0, "PmenuThumb", { bg = comment })

	-- Inactive windows: plain text pushed a third of the way to the background.
	-- No `bg`: 'NormalNC' also paints unfocused floats that don't remap
	-- `Normal` in 'winhighlight' (e.g. 'nvim-treesitter-context'), erasing their tint.
	set(0, "NormalNC", { fg = blend(fg, bg, 0.35) })

	-- Cursor line: barely-there tint ('cursorlineopt' includes `line`)
	set(0, "CursorLine", { bg = blend(bg, fg, 0.04) })

	-- Sticky scroll ('nvim-treesitter-context', 'plugin/93_ui.lua'), with a
	-- faint rule under the last pinned line
	set(0, "TreesitterContext", { bg = tint })
	set(0, "TreesitterContextLineNumber", { fg = comment, bg = tint })
	set(0, "TreesitterContextBottom", { underline = true, sp = comment })
	set(0, "TreesitterContextLineNumberBottom", { underline = true, sp = comment })

	-- Selection on the float tint; search matches in a muted accent, the
	-- current one stronger
	set(0, "Visual", { bg = selected })
	set(0, "Search", { fg = fg, bg = blend(bg, warn, 0.25) })
	set(0, "CurSearch", { fg = fg, bg = blend(bg, warn, 0.5), bold = true })
	set(0, "IncSearch", { link = "CurSearch" })
	-- Secondary numbers (winbar diffstat, statusline diagnostic counts) next
	-- to a coloured sign
	set(0, "FaintText", { fg = blend(bg, fg, 0.3) })

	-- Scrollbar marks ('satellite.nvim') at half strength
	for _, kind in ipairs({ "Error", "Warn", "Info", "Hint" }) do
		set(0, "SatelliteDiagnostic" .. kind, { fg = blend(bg, get("Diagnostic" .. kind).fg or comment, 0.5) })
	end
	for _, kind in ipairs({ "Add", "Change", "Delete" }) do
		set(0, "SatelliteGitSigns" .. kind, { fg = blend(bg, get("GitSigns" .. kind).fg or comment, 0.5) })
	end
	set(0, "SatelliteSearch", { fg = blend(bg, warn, 0.5) })
	set(0, "SatelliteSearchCurrent", { fg = blend(bg, warn, 0.8) })

	-- Code lenses ('plugin/40_lsp.lua'): faint italic lines above definitions
	set(0, "LspCodeLens", { fg = blend(bg, fg, 0.3), italic = true })
	set(0, "LspCodeLensSeparator", { link = "LspCodeLens" })

	-- Match counts ('nvim-hlslens') barely there, the nearest a shade less so
	set(0, "HlSearchLens", { fg = blend(bg, fg, 0.18) })
	set(0, "HlSearchLensNear", { fg = blend(bg, fg, 0.3) })

	-- Faint relative numbers and invisible-character markers, so the
	-- mode-coloured current number ('plugin/92_statusline.lua') stands out
	set(0, "LineNr", { fg = blend(bg, comment, 0.6) })
	set(0, "LineNrAbove", { link = "LineNr" })
	set(0, "LineNrBelow", { link = "LineNr" })
	set(0, "NonText", { fg = blend(bg, nontext, 0.7) })

	-- Inlay hints as faint pills: annotation, not code
	set(0, "LspInlayHint", { fg = comment, bg = tint, italic = true })

	-- Matching bracket: bold and underlined instead of a filled block
	set(0, "MatchParen", { bold = true, underline = true })

	-- Indent guides ('plugin/93_ui.lua'): every level barely there, the
	-- current scope in the comment colour
	set(0, "IndentFaint", { fg = blend(bg, nontext, 0.5) })
	set(0, "IndentScope", { fg = comment })

	-- Start screen ('plugin/30_mini.lua')
	set(0, "MiniStarterHeader", { fg = fg, bold = true })
	set(0, "MiniStarterSection", { fg = comment, bold = true })
	set(0, "MiniStarterItemPrefix", { link = "DiagnosticHint" })
	set(0, "MiniStarterQuery", { link = "DiagnosticWarn" })
	set(0, "MiniStarterItemBullet", { link = "NonText" })
	set(0, "MiniStarterFooter", { link = "Comment" })
end

local apply = function()
	for group, target in pairs(links) do
		vim.api.nvim_set_hl(0, group, { link = target, default = true })
	end
	for kind, target in pairs(kind_links) do
		vim.api.nvim_set_hl(0, "JBIcon" .. kind, { link = target, default = true })
		vim.api.nvim_set_hl(0, "JBIcon" .. kind:lower(), { link = target, default = true })
		vim.api.nvim_set_hl(0, "NavicIcons" .. kind, { link = target, default = true })
	end
	-- Used by the 'jb.nvim' lualine `nav_bar` component
	vim.api.nvim_set_hl(0, "JBIconModuleProject", { link = "Directory", default = true })
	reverse_blink_kinds()
	-- Hairline window splits, whatever the scheme draws them as
	vim.api.nvim_set_hl(0, "WinSeparator", { link = "NonText" })
	-- Winbar ('plugin/92_statusline.lua'): file name in the text colour, the
	-- breadcrumb dimmed (`NavicText` above), inactive windows dimmed whole
	local normal_fg = vim.api.nvim_get_hl(0, { name = "Normal", link = false }).fg
	vim.api.nvim_set_hl(0, "WinBarFile", { fg = normal_fg, bold = true })
	vim.api.nvim_set_hl(0, "WinBarNC", { link = "Comment" })
	-- Status line ('plugin/92_statusline.lua') on the editor background, like
	-- the winbar. `StatusLine` itself keeps its tint: floats are painted with it.
	vim.api.nvim_set_hl(0, "StatusLineClear", { fg = normal_fg })
	apply_surfaces()
end

Config.new_autocmd("ColorScheme", nil, apply, "Fill in jb.nvim-specific highlight groups")
apply()

-- Ghostty transparency ========================================================
-- Kitty makes every cell whose background equals its own default colour
-- translucent, so an opaque `Normal` still shows through. Ghostty only does
-- that for cells that use the *default* background, so under Ghostty every
-- group painted with `Normal`'s background is cleared to NONE -- the same
-- set of cells Kitty would treat as transparent. Kitty is left untouched.
if vim.env.TERM_PROGRAM == "ghostty" then
	local clear_normal_bg = function()
		local bg = vim.api.nvim_get_hl(0, { name = "Normal" }).bg
		if bg == nil then
			return
		end
		for name, hl in pairs(vim.api.nvim_get_hl(0, {})) do
			if hl.link == nil and hl.bg == bg then
				hl.bg = nil
				vim.api.nvim_set_hl(0, name, hl)
			end
		end
	end
	Config.new_autocmd("ColorScheme", nil, clear_normal_bg, "Clear Normal background under Ghostty")
	clear_normal_bg()
end
