-- ┌──────────────────────────┐
-- │ Built-in Neovim behavior │
-- └──────────────────────────┘
--
-- Single source of truth for global options. Anything that is not
-- plugin-specific belongs here, not scattered across `plugin/9*.lua`.
--
-- Here `vim.o.xxx = value` sets default value of option `xxx` to `value`.
-- See `:h 'xxx'` (replace `xxx` with actual option name).
--
-- Option values can be customized on per buffer or window basis.
-- See 'after/ftplugin/' for common example.
--
-- NOTE: 'mini.basics' (set up in 'plugin/30_mini.lua') only assigns options
-- that were *not* already set here, so everything below always wins. The one
-- exception is 'fillchars', which 'mini.basics' appends window-border pieces
-- to; it is therefore set in 'plugin/30_mini.lua' right after the setup call.

-- stylua: ignore start
-- The next part (until `-- stylua: ignore end`) is aligned manually for easier
-- reading. Consider preserving this or remove `-- stylua` lines to autoformat.

-- General ====================================================================
vim.g.mapleader      = ' ' -- Use `<Space>` as <Leader> key
vim.g.maplocalleader = "," -- Use `,` as <LocalLeader> key

vim.o.mouse          = 'a'                              -- Enable mouse
vim.o.mousescroll    = 'ver:25,hor:6'                   -- Customize mouse scroll
vim.o.switchbuf      = 'usetab'                         -- Use already opened buffers when switching
vim.o.undofile       = true                             -- Enable persistent undo
vim.o.autoread       = true                             -- Reload files changed outside of Neovim
vim.o.shada          = "'100,<50,s10,:1000,/100,@100,h" -- Limit ShaDa file (for startup)

-- Key timings. 'test-nvim' runs `timeoutlen = 0` so a mapping never waits, but
-- that is not viable here: 25 mappings in this config are *complete* mappings
-- that are also the prefix of a longer one, and with a zero timeout the short
-- one always wins. `grr`/`gcc`/`gxx`/`gss` ('mini.operators' line-wise forms),
-- every `s`-prefixed 'mini.surround' mapping and `in`/`an` ('mini.ai' next/last
-- textobjects) would all become untypeable. 300ms keeps them reachable while
-- cutting the default one-second stall to a third; 'which-key' pops up on the
-- same timer, so leader hints appear noticeably faster too.
vim.o.timeout        = true
vim.o.timeoutlen     = 300
vim.o.ttimeoutlen    = 10                       -- Don't linger after <Esc> in a terminal escape sequence

-- Enable all filetype plugins and syntax (if not enabled, for better startup)
vim.cmd('filetype plugin indent on')
if vim.fn.exists('syntax_on') ~= 1 then vim.cmd('syntax enable') end

-- Providers and built-in plugins =============================================
-- Neovim probes for every language provider at startup. Only the Python one is
-- wanted (Jupyter/REPL tooling), and naming its interpreter outright saves the
-- $PATH search. Re-enable any of the others by deleting its line.
vim.g.python3_host_prog     = '/usr/local/bin/python3'
vim.g.loaded_perl_provider  = 0
vim.g.loaded_ruby_provider  = 0

-- Shipped plugins that are never used. 'netrwPlugin' is deliberately *not*
-- disabled: 'lua/netrw.lua' builds the project tool window on top of it.
vim.g.loaded_gzip              = 1
vim.g.loaded_tar               = 1
vim.g.loaded_tarPlugin         = 1
vim.g.loaded_zip               = 1
vim.g.loaded_zipPlugin         = 1
vim.g.loaded_2html_plugin      = 1
vim.g.loaded_tutor_mode_plugin = 1

-- Clipboard ==================================================================
vim.opt.clipboard:append('unnamedplus')

vim.g.clipboard = {
  name  = 'macOS clipboard',
  copy  = { ['+'] = '/usr/bin/pbcopy',  ['*'] = '/usr/bin/pbcopy' },
  paste = { ['+'] = '/usr/bin/pbpaste', ['*'] = '/usr/bin/pbpaste' },
  cache_enabled = 0,
}

-- UI =========================================================================
vim.o.cmdheight       = 0                       -- Hide command line until it is needed
vim.o.colorcolumn     = '+1'                    -- Draw column on the right of maximum width
vim.o.cursorline      = true                    -- Enable current line highlighting
vim.o.cursorlineopt   = 'screenline,number'     -- Show cursor line per screen line
vim.o.inccommand      = 'split'                 -- Preview substitutions live, as you type
vim.o.list            = true                    -- Show helpful text indicators
vim.o.number          = true                    -- Show line numbers
vim.o.relativenumber  = true                    -- Show line numbers relative to the cursor
vim.o.report          = 20                      -- Don't report on small line-count changes
vim.o.ruler           = false                   -- Don't show cursor coordinates
vim.o.scrolloff       = 3                       -- Keep this many lines above/below the cursor
vim.o.smoothscroll    = true                    -- Scroll by screen line, not by (long, wrapped) buffer line
vim.o.shortmess       = 'CFOSWacoI'             -- Disable some built-in completion/intro messages
vim.o.showmode        = false                   -- Don't show mode in command line
vim.o.signcolumn      = 'yes'                   -- Always show signcolumn (less flicker)
vim.o.splitbelow      = true                    -- Horizontal splits will be below
vim.o.splitkeep       = 'screen'                -- Reduce scroll during window split
vim.o.splitright      = true                    -- Vertical splits will be to the right
vim.o.synmaxcol       = 500                     -- Don't syntax-highlight very long lines
vim.o.termguicolors   = true                    -- Use 24-bit RGB colors
vim.o.termsync        = true                    -- Batch each redraw into one atomic terminal update (Ghostty supports it); set false if the terminal doesn't
vim.o.pumblend        = 0                       -- No pseudo-transparency: blended cells are recomposited on every redraw
vim.o.winblend        = 0
vim.o.title           = true                    -- Put file name and path in window title
vim.o.winborder       = 'single'                -- Use border in floating windows

-- Command line. 'blink.cmp' completes `:` commands (see 'plugin/94_completion.lua'),
-- so the built-in 'wildmenu' would only draw a second, worse menu underneath it.
vim.o.wildmenu        = false
vim.o.wildmode        = ''
vim.o.more            = false                   -- Never page long output with the "-- More --" prompt

-- Popup menu (built-in completion and 'blink.cmp')
vim.o.pumborder       = 'bold'
vim.o.pumheight       = 10                      -- Make popup menu smaller
vim.o.pummaxwidth     = 100                     -- Make popup menu not too wide
vim.o.pumwidth        = 30                      -- Make popup menu not too narrow

-- Line wrapping
vim.o.wrap            = true                    -- Visually wrap long lines
vim.o.linebreak       = true                    -- Wrap lines at 'breakat'
vim.o.breakindent     = true                    -- Indent wrapped lines to match line start
vim.o.breakindentopt  = 'shift:0,min:20,sbr'    -- Keep wrapped lines readable and show 'showbreak'
vim.o.showbreak       = '↳ '

-- Special UI symbols. 'fillchars' is set in 'plugin/30_mini.lua' (see note above).
vim.o.listchars       = 'extends:⟩,nbsp:␣,space:·,tab:——-,trail:·'

-- Caret blinking pattern
vim.o.guicursor       = table.concat({
  'n-v-c:block-Cursor/lCursor-blinkon1',
  'i-ci-ve:ver25-Cursor/lCursor-blinkon1',
  'r-cr:hor20',
  'o:hor50',
  'a:blinkwait700-blinkoff400-blinkon250-Cursor/lCursor',
  'sm:block-blinkwait175-blinkoff150-blinkon175',
}, ',')

vim.g.nerd_font_is_present = true

-- Folds (see `:h fold-commands`, `:h zM`, `:h zR`, `:h zA`, `:h zj`) =========
vim.o.foldmethod      = 'expr'
vim.o.foldexpr        = 'v:lua.vim.treesitter.foldexpr()'
vim.o.foldtext        = ''                      -- Show text under fold with its highlighting
vim.o.foldcolumn      = '1'
vim.o.foldenable      = true
vim.o.foldlevel       = 99                      -- Fold nothing by default
vim.o.foldlevelstart  = 99
vim.o.foldnestmax     = 6                       -- Limit number of fold levels
vim.o.foldopen        = 'block,hor,insert,jump,mark,percent,quickfix,search,tag,undo'
vim.o.foldclose       = 'all'

-- Editing ====================================================================
vim.o.autoindent      = true                    -- Use auto indent
vim.o.expandtab       = true                    -- Convert tabs to spaces
vim.o.formatoptions   = 'rqnl1j'                -- Improve comment editing
vim.o.ignorecase      = true                    -- Ignore case during search
vim.o.incsearch       = false                   -- Don't re-search and re-scroll on every keystroke of a pattern ('nvim-hlslens' shows the match counts)
vim.o.infercase       = true                    -- Infer case in built-in completion
vim.o.shiftwidth      = 2                       -- Use this number of spaces for indentation
vim.o.smartcase       = true                    -- Respect case if search pattern has upper case
vim.o.smartindent     = true                    -- Make indenting smart
vim.o.softtabstop     = 2                       -- Treat this many spaces as a tab when editing
vim.o.spell    = false                 -- Treat camelCase word parts as separate words
vim.o.spelloptions    = 'camel'                 -- Treat camelCase word parts as separate words
vim.o.tabstop         = 2                       -- Show tab as this number of spaces
vim.o.virtualedit     = 'onemore'               -- Allow moving one column past end of line

vim.o.iskeyword       = '@,48-57,_,192-255,-'   -- Treat dash as `word` textobject part
vim.opt.isfname:append('@-@')                   -- Allow more characters in file names

-- Pattern for a start of numbered list (used in `gw`). This reads as
-- "Start of list item is: at least one special character (digit, -, +, *)
-- possibly followed by punctuation (. or `)`) followed by at least one space".
vim.o.formatlistpat   = [[^\s*[0-9\-\+\*]\+[\.\)]*\s\+]]

-- Built-in completion. 'blink.cmp' draws its own menu and ignores 'completeopt'
-- entirely, so leaving it populated only buys a second popup on `<C-x><C-*>`.
-- Restore 'menuone,noselect,fuzzy,nosort' to get the built-in menu back.
vim.o.completeopt     = ''
vim.o.completetimeout = 100                     -- Limit sources delay
-- stylua: ignore end

-- Autocommands ===============================================================

-- Don't auto-wrap comments and don't insert comment leader after hitting 'o'.
-- Do on `FileType` to always override these changes from filetype plugins.
local fix_formatoptions = function()
	vim.cmd("setlocal formatoptions-=c formatoptions-=o")
end
Config.new_autocmd("FileType", nil, fix_formatoptions, "Proper 'formatoptions'")

-- Tree-sitter folds need the parser to be started first, which `FileType` in
-- 'plugin/40_lsp.lua' only does for a known language list. Julia is folded via
-- tree-sitter here so that `zx` refreshes folds right after the parser starts.
local start_julia_folds = function(args)
	if not pcall(vim.treesitter.start, args.buf, "julia") then
		return
	end
	vim.wo.foldmethod = "expr"
	vim.wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"
	vim.wo.foldlevel = 99
	vim.wo.foldenable = true
	vim.cmd("normal! zx")
end
Config.new_autocmd("FileType", "julia", start_julia_folds, "Tree-sitter folds for Julia")

-- There are other autocommands created by 'mini.basics'. See 'plugin/30_mini.lua'.

-- Diagnostics ================================================================

-- Neovim has built-in support for showing diagnostic messages. This configures
-- a more conservative display while still being useful. In-buffer virtual text
-- is rendered by 'tiny-inline-diagnostic.nvim' (see 'plugin/40_lsp.lua'), which
-- is why `virtual_text`/`virtual_lines` stay off here.
-- See `:h vim.diagnostic` and `:h vim.diagnostic.config()`.
local severity = vim.diagnostic.severity
local diagnostic_opts = {
	-- Show signs on top of any other sign
	signs = {
		priority = 9999,
		severity = { min = "HINT", max = "ERROR" },
		text = {
			[severity.ERROR] = "󰅚 ",
			[severity.WARN] = "󰀪 ",
			[severity.INFO] = "󰋽 ",
			[severity.HINT] = "󰌶 ",
		},
		numhl = {
			[severity.ERROR] = "DiagnosticSignError",
			[severity.WARN] = "DiagnosticSignWarn",
			[severity.INFO] = "DiagnosticSignInfo",
			[severity.HINT] = "DiagnosticSignHint",
		},
	},

	-- Show all diagnostics as underline (for their messages type `<Leader>ld`)
	underline = { severity = { min = "HINT", max = "ERROR" } },

	virtual_lines = false,

	float = {
		border = "rounded",
		source = "if_many",
		header = "DIAGNOSTICS",
		prefix = " ● ",
	},

	-- Don't update diagnostics when typing
	update_in_insert = false,
}

-- Use `later()` to avoid sourcing `vim.diagnostic` on startup
Config.later(function()
	vim.diagnostic.config(diagnostic_opts)
end)
