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
  NavicText      = 'StatusLine',
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
