-- ┌──────────────────────────────────┐
-- │ Snippets, completion and explorer │
-- └──────────────────────────────────┘
--
-- 'blink.cmp' owns the completion menu and 'mini.snippets' owns the snippet
-- bodies. The `<Tab>`/`<CR>` multistep mappings from 'mini.keymap'
-- ('plugin/30_mini.lua') only apply to the built-in popup menu, which
-- 'blink.cmp' replaces.

local add = vim.pack.add
local now, later = Config.now, Config.later

-- Snippets ===================================================================
now(function()
	add({ "https://github.com/rafamadriz/friendly-snippets" })

	local snippets = require("mini.snippets")
	local gen_loader = snippets.gen_loader
	local config_dir = vim.fn.stdpath("config")

	snippets.setup({
		-- Loaders run in order and prefixes are unique: a later snippet with the
		-- same prefix *replaces* an earlier one, and a prefix with no `body`
		-- deletes it. 'after/snippets/' is searched last (it sits at the end of
		-- 'runtimepath'), which is what lets 'after/snippets/latex.json' override
		-- 'friendly-snippets' instead of duplicating all 111 of its entries.
		snippets = {
			gen_loader.from_lang({
				lang_patterns = {
					-- 'friendly-snippets' files LaTeX under 'latex', but the
					-- filetype is 'tex', so the default patterns miss it.
					tex = { "global.json", "latex.json", "latex/**/*.json", "tex.json" },
					plaintex = { "global.json", "latex.json", "latex/**/*.json", "tex.json" },
					bib = { "latex.json", "bib.json" },
				},
			}),
			-- Personal snippets for every filetype, loaded last so they win
			gen_loader.from_file(config_dir .. "/snippets/global.json"),
		},

		-- `expand` is deliberately empty: <Tab> expands, through the
		-- `minisnippets_expand` step of the 'mini.keymap' multistep mapping in
		-- 'plugin/30_mini.lua'. A mapping here as well would be a second, always
		-- firing binding for the same thing, and <C-k> in particular is now
		-- `select_prev` whenever the 'blink.cmp' menu is open. The jump keys are
		-- unaffected and only live for the duration of a session.
		mappings = {
			expand = "",
			jump_next = "<C-l>",
			jump_prev = "<C-j>",
			stop = "<C-c>",
		},

		-- `$TM_SELECTED_TEXT` resolves to the |quote_quote| register by default,
		-- so expanding a snippet that mentions it any time after a yank or a
		-- delete silently pastes that unrelated text into the body. Nothing
		-- here wants that, so the variable is forced to the empty string.
		-- Everything else stays `MiniSnippets.default_insert()`; 'blink.cmp'
		-- goes through this exact function too (see its `mini_snippets` preset),
		-- so accepting a snippet from the completion menu is covered as well.
		expand = {
			insert = function(snippet, opts)
				opts = opts or {}
				opts.lookup = vim.tbl_extend("keep", opts.lookup or {}, { TM_SELECTED_TEXT = "" })
				return MiniSnippets.default_insert(snippet, opts)
			end,

			-- Exact prefixes only. `MiniSnippets.default_match()` falls back to a
			-- fuzzy pass whose `'%S*'` pattern matches the empty string, so at the
			-- start of a line or straight after a space *every* snippet counts as
			-- a match -- which would make <Tab> open the snippet picker instead of
			-- indenting. Dropping the fuzzy pass (`pattern_fuzzy = ''` returns no
			-- matches) leaves <Tab> expanding only what has actually been typed;
			-- fuzzy discovery still happens in the 'blink.cmp' menu, which asks
			-- for snippets with `match = false` and so never reaches this.
			match = function(snippets)
				return MiniSnippets.default_match(snippets, { pattern_fuzzy = "" })
			end,
		},
	})

	-- Clear tabstop decorations on <Esc>. A session normally outlives Insert
	-- mode, which leaves the inline "•"/"∎" dots and the tabstop underlines
	-- sitting in the buffer until it is stopped explicitly with <C-c>. Arm a
	-- one-shot autocommand on every session start that stops every (possibly
	-- nested) session the first time Normal mode is entered.
	local stop_all_sessions = function()
		while MiniSnippets.session.get() do
			MiniSnippets.session.stop()
		end
	end
	local arm_stop_on_normal = function()
		vim.api.nvim_create_autocmd("ModeChanged", {
			pattern = "*:n",
			once = true,
			callback = stop_all_sessions,
			desc = "Stop snippet session on Normal mode",
		})
	end
	Config.new_autocmd("User", "MiniSnippetsSessionStart", arm_stop_on_normal, "Arm snippet session stop")
end)

-- Completion =================================================================
now(function()
	-- 'blink.cmp' ships its fuzzy matcher as a Rust library, expected at
	-- `$repo/lib/libblink_cmp_fuzzy.<ext>.<short-commit>`. Outside of lazy.nvim's
	-- `build` hook nothing produces it, so rebuild on install/update the same way
	-- 'plugin/40_lsp.lua' hooks `:TSUpdate`.
	local build_blink = function()
		require("blink.cmp").build()
	end
	Config.on_packchanged("blink.cmp", { "install", "update" }, build_blink, "Build blink.cmp matcher")

	add({
		"https://github.com/saghen/blink.lib",
		"https://github.com/saghen/blink.cmp",
		"https://github.com/mikavilpas/blink-ripgrep.nvim",
	})

	local LATEX_FILETYPES = { tex = true, plaintex = true, bib = true }

	--- True when the keyword being completed is preceded by `@`, i.e. the user
	--- is part-way through typing something like `@a`.
	--- @param ctx blink.cmp.Context
	local function after_at_sign(ctx)
		return ctx.line:sub(1, ctx.bounds.start_col - 1):sub(-1) == "@"
	end

	-- Menu styling mirrors 'test-nvim', which draws the kind column with
	-- 'lspkind' in `symbol` mode. Its `symbol_map` overrides every entry of the
	-- `codicons` preset, so the table below is that map copied verbatim rather
	-- than a call to `lspkind.init()`: that rewrites
	-- `vim.lsp.protocol.CompletionItemKind` in place and would undo
	-- `MiniIcons.tweak_lsp_kind()` ('plugin/30_mini.lua'). `jb.icons` (still used
	-- by 'nvim-navic' and 'fzf-lua') draws JetBrains-style square glyphs, which
	-- do not read well at the narrow kind column width.
	-- stylua: ignore
	local kind_icons = {
		Text          = "", Method        = "", Function      = "", Constructor   = "",
		Field         = "", Variable      = "", Class         = "", Interface     = "",
		Module        = "", Property      = "", Unit          = "", Value         = "",
		Enum          = "", Keyword       = "", Snippet       = "", Color         = "",
		File          = "", Reference     = "", Folder        = "", EnumMember    = "",
		Constant      = "", Struct        = "", Event         = "", Operator      = "",
		TypeParameter = "", Copilot       = "",
	}

	--- Kind column: one space of padding either side, and `path` items get the
	--- devicon for the file they point at instead of a generic file glyph.
	--- @param ctx blink.cmp.DrawItemContext
	local function kind_icon_text(ctx)
		local icon = ctx.kind_icon
		if ctx.source_name == "Path" then
			icon = require("nvim-web-devicons").get_icon(ctx.label) or icon
		end
		return " " .. icon .. " "
	end

	-- Command -> glyph, scraped from the tables 'vimtex' uses for math conceal
	-- (`s:cmd_symbols` and the `texCmdGreek` matches). They are script-local,
	-- so the file is read rather than called. Built on first use.
	local latex_glyphs

	--- Glyph column: the rendered symbol of the first `\command` an item would
	--- insert (snippet body, else insert text), e.g. `@a` -> `α`. LaTeX only.
	--- @param ctx blink.cmp.DrawItemContext
	local function latex_glyph_text(ctx)
		if not LATEX_FILETYPES[vim.bo.filetype] then
			return ""
		end
		if latex_glyphs == nil then
			latex_glyphs = {}
			local file = vim.api.nvim_get_runtime_file("autoload/vimtex/syntax/core.vim", false)[1]
			for line in file and io.lines(file) or function() end do
				local cmd, glyph = line:match("^%s*\\ %['(%a%a+)', '([^']+)'%]")
				if not cmd then
					cmd, glyph = line:match([[\\(%a%a+)\>".-cchar=(%S+)]])
				end
				if cmd and not latex_glyphs[cmd] then
					latex_glyphs[cmd] = glyph
				end
			end
		end
		local data = ctx.item.data
		local snip = type(data) == "table" and data.snip or nil
		local text = snip and snip.body or ctx.item.insertText or ctx.label
		if type(text) == "table" then
			text = table.concat(text, "\n")
		end
		local glyph = latex_glyphs[text:match("\\(%a+)") or ""]
		return glyph and (glyph .. " ") or ""
	end

	require("blink.cmp").setup({
		-- 'test-nvim' builds on the `super-tab` preset and then overrides most of
		-- it. The preset is what still supplies <S-Tab> (`snippet_backward`),
		-- <C-e>, <C-n>/<C-p> and the documentation scroll keys.
		--
		-- Every entry ends in `fallback`, and each command returns `false` when the
		-- menu is closed, so with no menu open <C-k>/<C-j> still reach the
		-- 'mini.snippets' mappings set above (expand / jump prev) -- which is what
		-- keeps `@(`-style prefixes expandable. <C-l> and <C-h> are mapped to
		-- nothing at all so 'blink.cmp' never claims them.
		keymap = {
			preset = "super-tab",
			["<Tab>"] = { "fallback" },
			["<CR>"] = { "accept", "fallback" },
			["<C-space>"] = { "show", "show_documentation", "hide_documentation" },
			["<Up>"] = { "select_prev", "fallback" },
			["<Down>"] = { "select_next", "fallback" },
			["<C-k>"] = { "select_prev", "fallback" },
			["<C-j>"] = { "select_next", "fallback" },
			["<C-l>"] = {},
			["<C-h>"] = {},
			["<Left>"] = { "fallback" },
			["<Right>"] = { "fallback" },
		},

		snippets = {
			preset = "mini_snippets",
			-- Default is -3, which penalises every snippet item. Snippets are
			-- boosted instead, via the `snippets` provider below.
			score_offset = 0,
		},

		completion = {
			-- Cap the list: the menu shows ~10 rows, so ranking 500 buffer words
			-- on every keystroke is wasted work.
			list = {
				max_items = 100,
				-- Preselect the best match and type it into the buffer as you
				-- move through the list, so <CR> is only needed to commit.
				selection = { preselect = true, auto_insert = true },
			},
			-- 'test-nvim' never pops the documentation window open by itself; it
			-- is reachable with <C-space> on an already-selected item.
			documentation = {
				auto_show = false,
				window = { border = "single" },
			},
			menu = {
				border = "single",
				auto_show = true,
				-- Don't build and paint the menu on every keystroke of a burst.
				-- This is the single biggest "typing feels smooth" knob here:
				-- fast typing never materialises a window at all.
				auto_show_delay_ms = 300,
				-- Keep the menu below the cursor unless there is no room, so it
				-- doesn't jump over the line being edited.
				direction_priority = { "n", "s" },
				min_width = 35,
				draw = {
					-- Tree-sitter-highlighting every label means parsing a
					-- throwaway buffer per item per redraw. Plain highlights.
					treesitter = {},
					components = {
						kind_icon = { text = kind_icon_text },
						latex_glyph = { text = latex_glyph_text, highlight = "Special" },
					},
					columns = {
						{ "kind_icon" },
						{ "label", "label_description", gap = 1 },
						{ "latex_glyph" },
					},
				},
			},
			ghost_text = { enabled = false },
		},

		-- Command-line completion, which replaces 'wildmenu' (turned off in
		-- 'plugin/10_options.lua'). <Up>/<Down> and <C-k>/<C-j> move through the
		-- list and insert as they go; <Tab> is left to the shell-like default.
		cmdline = {
			enabled = true,
			completion = {
				list = { selection = { preselect = false } },
				menu = { auto_show = true },
			},
			keymap = {
				["<Tab>"] = false,
				["<Up>"] = {
					function(cmp)
						return cmp.select_prev({ auto_insert = true })
					end,
					"fallback",
				},
				["<Down>"] = {
					function(cmp)
						return cmp.select_next({ auto_insert = true })
					end,
					"fallback",
				},
				["<C-k>"] = {
					function(cmp)
						return cmp.select_prev({ auto_insert = true })
					end,
					"fallback",
				},
				["<C-j>"] = {
					function(cmp)
						return cmp.select_next({ auto_insert = true })
					end,
					"fallback",
				},
			},
		},

		sources = {
			default = { "lsp", "snippets", "path", "buffer" },
			per_filetype = {
				lua = { "lazydev", "lsp", "snippets", "path", "buffer" },

				-- LaTeX: 'vimtex' completes \cite{}, \ref{}, \begin{}, package
				-- and class names from the actual project, which no other source
				-- here can do. Snippets carry the math/environment shorthands.
				tex = { "vimtex", "snippets", "lsp", "buffer", "path" },
				plaintex = { "vimtex", "snippets", "lsp", "buffer", "path" },
				bib = { "vimtex", "buffer", "path" },

				-- Julia: 'jetls' also serves the `\alpha`-style unicode
				-- completions, so the LSP has to stay ahead of `buffer`.
				julia = { "lsp", "snippets", "path", "buffer" },

				-- Prose: whole-project word search is worth the `rg` call here
				markdown = { "lsp", "snippets", "path", "buffer", "ripgrep" },
			},
			providers = {
				lsp = { fallbacks = {} },

				-- Snippets first. Lower this to ~25 if it starts burying exact
				-- LSP matches.
				snippets = {
					score_offset = 100,
					opts = { use_items_cache = true },

					-- `@` is not a completion keyword character, so typing `@a`
					-- makes blink search for just `a`. Allow the empty keyword
					-- right after an `@` so that `@` on its own lists every
					-- `@`-prefixed snippet.
					min_keyword_length = function(ctx)
						return after_at_sign(ctx) and 0 or 1
					end,

					-- ...and for the same reason `@a` would otherwise be scored
					-- as a loose match for `a` and sort below `algo`, `ali` and
					-- friends. Boost the `@` snippets whenever the cursor is
					-- actually sitting after an `@`.
					transform_items = function(ctx, items)
						if not after_at_sign(ctx) then
							return items
						end
						for _, item in ipairs(items) do
							if item.label:sub(1, 1) == "@" then
								item.score_offset = (item.score_offset or 0) + 100
							end
						end
						return items
					end,
					-- ...except inside a LaTeX argument. Halfway through
					-- `\begin{ali` or `\ref{sec` the useful answers are the
					-- project's environments and labels, and an exact-prefix
					-- snippet match would otherwise outscore all of them.
					enabled = function()
						if not LATEX_FILETYPES[vim.bo.filetype] then
							return true
						end
						local col = vim.api.nvim_win_get_cursor(0)[2]
						local before = vim.api.nvim_get_current_line():sub(1, col)
						return before:match("\\%a+%*?{[^}]*$") == nil
					end,
				},

				lazydev = {
					name = "LazyDev",
					module = "lazydev.integrations.blink",
					score_offset = 100,
				},

				-- Wraps whatever 'omnifunc' the filetype installs, which for
				-- 'tex' and 'bib' buffers is `vimtex#complete#omnifunc`.
				-- Ranked above snippets on purpose: this source only returns
				-- anything inside a real LaTeX context (`\cite{`, `\begin{`,
				-- `\usepackage{`, ...), and there a project label or bib key
				-- beats a fuzzy snippet match every time.
				vimtex = {
					name = "LaTeX",
					module = "blink.cmp.sources.complete_func",
					score_offset = 120,
					opts = {
						complete_func = function()
							-- Neovim's built-in LSP client claims 'omnifunc' for
							-- itself, as a raw Lua function rather than a name
							-- (`vim.lsp.lua:854`), whenever it attaches to a
							-- buffer where 'omnifunc' is still unset. On a
							-- `:restart`, every LSP client and 'vimtex's own
							-- `FileType` autocommand race to set it, and
							-- whichever LSP wins leaves a function value here
							-- instead of a string. `complete_func.lua` only
							-- ever expects a string (it calls `:match()` on it),
							-- so passing the function through crashes every
							-- completion request until the buffer is
							-- re-entered. Disabling the source for that one
							-- request is the safe fallback: 'vimtex' still sets
							-- its own omnifunc correctly on the next `FileType`
							-- pass, and every other source keeps working.
							local omnifunc = vim.bo.omnifunc
							return type(omnifunc) == "string" and omnifunc ~= "" and omnifunc or nil
						end,
					},
				},

				-- Weakest source: only worth showing for longer words, and only
				-- from buffers that are actually on screen.
				buffer = {
					score_offset = -10,
					min_keyword_length = 3,
					max_items = 10,
					opts = {
						get_bufnrs = function()
							local bufs = {}
							for _, win in ipairs(vim.api.nvim_list_wins()) do
								local buf = vim.api.nvim_win_get_buf(win)
								if vim.bo[buf].buftype == "" then
									bufs[buf] = true
								end
							end
							return vim.tbl_keys(bufs)
						end,
					},
				},

				-- Spawns `rg` across the project, so keep it off the default list
				-- and only let it run once there is a real word to search for.
				ripgrep = {
					module = "blink-ripgrep",
					name = "Ripgrep",
					async = true,
					score_offset = -15,
					min_keyword_length = 4,
					---@module "blink-ripgrep"
					---@type blink-ripgrep.Options
					opts = {},
				},
			},
		},

		fuzzy = {
			-- The Rust matcher adds typo tolerance, frecency and proximity
			-- boosting and sorts without crossing back into Lua. Warn (rather than
			-- silently drop to the slow Lua fallback) if the library is missing,
			-- e.g. after an update whose build hook failed. Check with
			-- `:lua = require("blink.cmp.fuzzy").implementation_type`.
			implementation = "prefer_rust_with_warning",
			max_typos = function(keyword)
				return math.floor(#keyword / 4)
			end,
			use_proximity = true,
			frecency = { enabled = true },
			-- All built-in, so the Rust matcher can sort without a Lua callback
			sorts = { "score", "sort_text" },
		},

		appearance = {
			kind_icons = kind_icons,
			nerd_font_variant = "mono",
		},
	})

	-- Fix https://github.com/saghen/blink.cmp/issues/2419, which the 300ms
	-- `auto_show_delay_ms` above makes reachable: `queue_auto_show()` schedules
	-- its callback with `vim.schedule_wrap`, so a timer that has already been
	-- stopped by `reset_auto_show()` can still run its callback one tick later
	-- and pop the menu open after the cursor has moved away. Upstream even
	-- marks the spot with a `TODO: this can race`. Re-check the timer key
	-- inside the scheduled callback; `reset_auto_show()` blanks it, so a
	-- cancelled timer now bails out instead of opening a stale menu.
	local menu = require("blink.cmp.completion.windows.menu")
	menu.queue_auto_show = function(context, items)
		local auto = menu.auto_show
		if not auto.enabled(context, items) then
			return
		end

		local delay_ms = math.max(0, auto.delay_ms(context, items) - (vim.uv.now() - context.timestamp))
		if delay_ms == 0 then
			auto.timer:stop()
			menu.open()
			menu.update_position()
			return
		end

		local timer_key = ("%d|%d|%d"):format(context.id, context.pos.row, context.pos.col)
		if auto.timer:is_active() and auto.timer_key == timer_key then
			return
		end

		auto.timer_key = timer_key
		auto.timer:start(
			delay_ms,
			0,
			vim.schedule_wrap(function()
				-- Bail out if `reset_auto_show()` ran before this was scheduled
				if auto.timer_key ~= timer_key then
					return
				end
				menu.open()
				menu.update_position()
			end)
		)
	end

	-- Open the menu as soon as the cursor lands inside a LaTeX argument, so
	-- `\cite{` lists the bibliography, `\ref{` the labels and `\begin{` the
	-- environments without having to type a first letter. `{` and `,` are not
	-- keyword characters, so `show_on_keyword` never fires for them.
	--
	-- The obvious route -- giving the `vimtex` provider `{` and `,` as trigger
	-- characters -- does not survive 'nvim-autopairs': typing `{` makes it feed a
	-- closing `}` as well, so the last |InsertCharPre| 'blink.cmp' sees before
	-- |TextChangedI| is `}`, not `{`, and it hides the menu instead. Reading the
	-- line back is independent of who inserted what.
	--
	-- `[^}]*$` keeps this to an argument that is still open, so a `{` closed on
	-- the same line (`\begin{align}`) does not re-trigger, and `vimtex`'s
	-- 'omnifunc' returns nothing outside a command it knows, which closes the
	-- menu again straight away.
	local function show_in_latex_argument()
		if not LATEX_FILETYPES[vim.bo.filetype] then
			return
		end
		local col = vim.api.nvim_win_get_cursor(0)[2]
		local before = vim.api.nvim_get_current_line():sub(1, col)
		local last = before:sub(-1)
		if (last ~= "{" and last ~= ",") or before:match("\\%a+%*?{[^}]*$") == nil then
			return
		end
		-- After 'blink.cmp' has finished handling the same |TextChangedI|, which
		-- would otherwise hide the menu right after this opened it.
		vim.schedule(function()
			require("blink.cmp").show()
		end)
	end
	Config.new_autocmd("TextChangedI", "*", show_in_latex_argument, "Complete inside LaTeX arguments")

	add({ "https://github.com/smjonas/inc-rename.nvim" })
	require("inc_rename").setup({
		save_in_cmdline_history = true,
	})

	add({ "https://github.com/folke/lazydev.nvim" })
	require("lazydev.config").lua_root = false
	require("lazydev").setup({
		-- Until lazy.nvim is present it won't find those in vim.pack unless provide a full path
		library = {
			-- Load luvit types when the `vim.uv` word is found
			{ path = "${3rd}/luv/library", words = { "vim%.uv" } },
			{ path = "inc-rename.nvim", words = { "inc_rename" } },
			{ path = "snacks.nvim", words = { "Snacks" } },
			{ path = "nvim-lint", words = { "lint%.Linter", "lint%.Parser", "lint%.parse" } },
			{ path = "conform.nvim", words = { "conform%.setupOpts" } },
		},
	})
end)

-- Explorer and QoL ===========================================================
later(function()
	add({ "https://github.com/nickkadutskyi/snacks.nvim" })
	require("snacks").setup({

		---@class snacks.bigfile.Config
		bigfile = { enabled = true },
		-- Moves git status to the right side of the row numbers like in IntelliJ
		statuscolumn = {
			enabled = true,
			folds = {
				open = true, -- show open fold icons
				git_hl = true, -- use Git Signs hl for fold icons
			},
		},

		explorer = {
			enabled = true,
			replace_netrw = true,
		},
		---@class snacks.picker.Config
		picker = {
			sources = {
				---@type snacks.picker.explorer.Config|{}
				explorer = {
					auto_close = true,
					title = "Project",
					hidden = true,
					ignored = true,
					win = {
						list = {
							keys = {
								["<M-CR>"] = "tab",
								["<C-t>"] = "tab",
							},
						},
					},
					formatters = {
						file = {
							filename_first = false, -- display filename before the file path
							truncate = 40, -- truncate the file path to (roughly) this length
							filename_only = false, -- only show the filename
							icon_width = 4, -- width of the icon (in characters)
							icon_align_opts = { align = "right" },
							git_status_hl = true, -- use the git status highlight group for the filename
						},
					},
					icons = {
						files = {
							enabled = true, -- show file icons
							dir = " ",
							dir_open = " ",
							file = "",
						},
						tree = {
							vertical = "│",
							middle = "│",
							last = "│",
						},
					},
					layouts = {
						sidebar_float = {
							preview = "main",
							layout = {
								backdrop = false,
								width = 40,
								min_width = 40,
								height = 0,
								col = 0,
								row = 0,
								position = "float",
								-- border = "none",
								border = {
									"",
									"",
									{ "▕", "ToolWindowFloatBorder" },
									{ "▕", "ToolWindowFloatBorder" },
									{ "▕", "ToolWindowFloatBorder" },
									{ " ", "ToolWindowFloatBorder" },
									{ " ", "ToolWindowFloatBorder" },
									"",
								},
								box = "vertical",
								{
									box = "vertical",
									{
										win = "input",
										height = 1,
										border = { "", " ", "", "", "", "", "", "" }, -- only top border for title
										title = "{title} {live} {flags}",
										title_pos = "left",
									},
									{ win = "list", border = "none" },
									{ win = "preview", title = "{preview}", height = 0.4, border = "top" },
								},
							},
						},
					},
					layout = {
						preset = "sidebar_float",
					},
				},
			},
		},

		image = {
			enabled = true,
			doc = {
				enabled = true,
				inline = true,
				-- In Markdown a rendered equation is strictly better than its
				-- source, so hide the source. In LaTeX the source *is* what you
				-- are editing, so keep it and put the image underneath.
				conceal = function(lang, type)
					return type == "math" and lang ~= "latex"
				end,
			},
			-- Renders `$...$`, `\[...\]` and math environments as images in both
			-- LaTeX and Markdown buffers. Needs a terminal speaking the Kitty
			-- graphics protocol (Ghostty does) plus `latex`, `dvipng` and
			-- `magick`, all of which are installed. Only the visible region is
			-- rendered and results are cached under `stdpath("cache")`, but the
			-- first render of an equation runs pdflatex and costs a few hundred
			-- ms. `Snacks.image.doc.hover()` previews just the one at the cursor.
			math = {
				enabled = true,
				latex = { font_size = "Large" },
			},
			formats = {
				"png",
				"jpg",
				"jpeg",
				"gif",
				"bmp",
				"webp",
				"tiff",
				"heic",
				"avif",
				"mp4",
				"mov",
				"avi",
				"mkv",
				"webm",
				"pdf",
				"svg",
			},
		},
	})

	vim.keymap.set("n", "<leader>oe", require("netrw").toggle_vim_explorer_float, {
		desc = "Project: [o]pen netrw [e]xplorer window.",
	})

	-- Open the explorer sidebar; if it is already open, focus it (or close it
	-- again when it already has focus). `<Leader>ed` ('plugin/20_keymaps.lua')
	-- reaches the same function.
	Config.toggle_explorer = function()
		local explorer = Snacks.picker.get({ source = "explorer" })[1]
		if explorer == nil or explorer:is_focused() then
			Snacks.picker.explorer({ auto_close = true })
		else
			explorer:focus()
		end
	end
	vim.keymap.set("n", "<leader>op", Config.toggle_explorer, {
		desc = "Project: [o]pen [p]roject tool window.",
	})
end)

later(function()
	add({ "https://github.com/folke/trouble.nvim" })
	local trouble = require("trouble")
	local ran_setup = false
	local opts = {
		auto_close = true,
		win = {
			wo = {
				winhighlight = "Normal:TroubleNormal,NormalNC:TroubleNormalNC,EndOfBuffer:TroubleNormal,CursorLine:NetrwCursorLine,FloatBorder:ToolWindowFloatBorder",
			},
		},
		modes = {
			document_diagnostics = {
				title = "{hl:TroubleTitle}Problems{hl} "
					.. "{hl:TroubleTabSelected} File{hl}"
					.. "{hl:TroubleTabSelectedCount}{count}{hl} "
					.. "Project Errors",
				mode = "diagnostics",
				filter = { buf = 0 },
				focus = true,
				win = {
					type = "float",
					relative = "editor",
					position = { 0.95, 0 },
					size = { width = 1, height = 15 },
					border = { "‾", "‾", "‾", "", "", "", "", "" },
				},
			},
			workspace_diagnostics = {
				title = "{hl:TroubleTitle}Problems{hl} "
					.. " File "
					.. "{hl:TroubleTabSelected} Project Errors{hl}"
					.. "{hl:TroubleTabSelectedCount}{count}{hl}",
				mode = "diagnostics",
				filter = {},
				focus = true,
				win = {
					type = "float",
					relative = "editor",
					position = { 0.95, 0 },
					size = { width = 1, height = 15 },
					border = { "‾", "‾", "‾", "", "", "", "", "" },
				},
			},
			symbols = {
				multiline = true,
				title = "{hl:TroubleTitle}Structure{hl} {count}",
				desc = "Structure",
				focus = true,
				win = {
					-- type = "float",
					-- size = { width = 50, height = 0.99 },
					-- position = { 0, 0 },
					-- border = { "", "", "", "▕", "", "", "", "" },
					size = 50,
					position = "right",
				},
				filter = {
					-- remove Package since luals uses it for control flow structures
					["not"] = { ft = "lua", kind = "Package" },
					any = {
						-- PHP: only show class name, constructor, properties and methods
						{ ft = "php", kind = { "Class", "Constructor", "Property", "Method", "Field" } },
						-- non-PHP: fall back to default list
						{
							["not"] = { ft = "php" },
							kind = {
								"Class",
								"Constructor",
								"Enum",
								"Field",
								"Function",
								"Interface",
								"Method",
								"Module",
								"Namespace",
								"Package",
								"Property",
								"Struct",
								"Trait",
								"String",
								"Number",
								"Null",
								-- "Variable",
								"Object",
								"Array",
							},
						},
						-- Commented this to let this table through the event.data needed during vim.pack.add/update
						-- all symbol kinds for help / markdown files
						-- ft = { "help", "markdown" },
					},
				},
			},
		},
	}
	opts.icons = { kinds = require("jb.icons").kind }
	trouble.setup(opts)
	ran_setup = true
	if not ran_setup then
		trouble.setup(opts)
	end

	vim.keymap.set("n", "]p", function()
		require("trouble")._action("next")("document_diagnostics")
	end, { desc = "Problems: next [p]roblem" })
	vim.keymap.set("n", "[p", function()
		require("trouble")._action("prev")("document_diagnostics")
	end, { desc = "Problems: previous [p]roblem" })
	local nmap_leader = function(suffix, rhs, desc)
		vim.keymap.set("n", suffix, rhs, { desc = desc })
	end

	nmap_leader(
		"<localleader>tp",
		'<Cmd>lua require("trouble").open("document_diagnostics")<CR>',
		"Problems: [t]oggle [p]roblem tool window"
	)
	nmap_leader(
		"<leader>tp",
		'<Cmd>lua require("trouble").open("workspace_diagnostics")<CR>',
		"Problems: [t]oggle [p]roblem tool window"
	)
	nmap_leader("<leader>ts", function()
		-- LaTeX: VimTeX TOC spans all `\input` files ('lua/trouble/sources/vimtex_toc.lua')
		if vim.bo.filetype == "tex" then
			trouble.open({ mode = "tex_symbols", focus = true, title = opts.modes.symbols.title, win = opts.modes.symbols.win })
		else
			trouble.open("symbols")
		end
	end, "Problems: [t]oggle [s]ymbols tool window")
	nmap_leader("<leader>tb", '<Cmd>lua require("trouble").open("todo")<CR>', "Problems: [t]oggle [b]ugs tool window")
	nmap_leader("<leader>tq", '<Cmd>lua require("trouble").open("qflist")<CR>', "Problems: [t]oggle [q]uickfix window")
end)
