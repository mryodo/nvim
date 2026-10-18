-- ┌───────────────────────────┐
-- │ Colorscheme and visual UI │
-- └───────────────────────────┘
--
-- This file owns the active colorscheme, icons, indent guides, tree-sitter
-- context, the buffer line and the message UI. Plain options belong in
-- 'plugin/10_options.lua'.

local add = vim.pack.add
local now, later = Config.now, Config.later

-- Colorscheme collection =====================================================
-- Installed and available via `:colorscheme` / `<Leader>fC`. Only the schemes
-- that need a `setup()` call before use are configured here.
--
-- Deferred on purpose: none of these is the active scheme, so pulling 18 repos
-- into 'runtimepath' and sourcing their `plugin/` files is pure startup cost.
-- `later()` does it once the first screen is on the terminal.
later(function()
	add({
		"https://github.com/Aejkatappaja/cendre",
		"https://github.com/MartyBeGood/lorem-gypsum.nvim",
		"https://github.com/Shatur/neovim-ayu",
		"https://github.com/WTFox/luna.nvim",
		"https://github.com/ellisonleao/gruvbox.nvim",
		"https://github.com/neanias/everforest",
		"https://github.com/jpwol/thorn.nvim",
		"https://github.com/mcauley-penney/techbase.nvim",
		"https://github.com/mitander/flume.nvim",
		"https://github.com/mryodo/rwth.nvim",
		"https://github.com/nendix/zen.nvim",
		"https://github.com/nyoom-engineering/oxocarbon.nvim",
		"https://github.com/slugbyte/lackluster.nvim",
		"https://github.com/tanmaymanojgandhi/circadia",
		"https://github.com/thesimonho/kanagawa-paper.nvim",
		"https://github.com/vague-theme/vague.nvim",
		"https://github.com/webhooked/kanso.nvim",
		"https://github.com/ThorstenRhau/token",
	})

	require("rwth").setup({ transparent = false })

	-- 'circadia' nests its Neovim port under 'ports/neovim' rather than the
	-- plugin root, so its `lua/circadia` module is invisible to the native
	-- loader until that subdirectory joins 'runtimepath' too. Its
	-- `colors/circadia-dark.lua` and `colors/circadia-light.lua` entrypoints
	-- (kept in this repo, since the plugin ships no `colors/*.lua` of its own)
	-- depend on this to make `:colorscheme circadia-dark` work.
	local circadia = vim.pack.get({ "circadia" })[1]
	vim.opt.rtp:prepend(vim.fs.joinpath(circadia.path, "ports", "neovim"))

	add({ "https://github.com/neanias/everforest-nvim" })
	require("everforest").setup({
		background = "hard",
		transparent_background_level = 0,
		sign_column_background = "none",
		ui_contrast = "low",
		diagnostic_text_highlight = false,
		diagnostic_virtual_text = "coloured",
		diagnostic_line_highlight = true,
		spell_foreground = false,
		show_eob = true,
		float_style = "bright",
		inlay_hints_background = "none",
	})
end)

-- File icons =================================================================
now(function()
	add({ "https://github.com/nvim-tree/nvim-web-devicons" })
	add({ "https://github.com/nickkadutskyi/jb.nvim" })
	local devicons = require("nvim-web-devicons")
	local icons = require("jb.icons")

	devicons.setup({
		default = false,
		strict = true,
		color_icons = true,
		override = {
			zsh = { icon = "", color = "#428850", cterm_color = "65", name = "Zsh" },
		},
		override_by_filename = icons.files.by_filename,
		override_by_extension = icons.files.by_extension,
	})
	devicons.set_icon(icons.by_variant(vim.o.background))

	-- Icons come in light and dark variants; re-apply when 'background' flips
	local sync_icons = function()
		later(function()
			devicons.set_icon(icons.by_variant(vim.o.background))
		end)
	end
	Config.new_autocmd("OptionSet", "background", sync_icons, "Sync devicons with 'background'")
end)

-- Active colorscheme =========================================================
now(function()
	add({ "https://github.com/nickkadutskyi/jb.nvim" })
	local borders = require("jb.borders").borders.dialog

	-- 'fff' is not installed; these conditions are no-ops until it is. They are
	-- kept because the border styles they pick are what the picker expects.
	local fff_buf = function(field)
		return function(bufnr, _)
			local ok, state = pcall(require, "fff.picker_ui.picker_ui_state")
			return ok and state ~= nil and bufnr == state.state[field]
		end
	end

	require("jb").setup({
		transparent = false,
		integrations = { ghostty = true },
		enforce_float_style = {
			{
				style = { border = borders.default_box_header_shadowed },
				condition = function(_, config)
					if type(config.title) ~= "string" then
						return false
					end
					return config.title == " Plugins " or config.title:find("99") ~= nil
				end,
			},
			{
				style = { border = borders.default_box_split_top_no_footer_shadowed },
				condition = fff_buf("input_buf"),
			},
			{
				style = { border = borders.default_box_split_middle_shadowed_no_footer },
				condition = fff_buf("list_buf"),
			},
			{
				style = { border = borders.default_box_split_bottom_shadowed_header },
				condition = fff_buf("preview_buf"),
			},
		},
	})

	-- Active scheme: 'koda-dark' (dark only, so both 'background' slots use it).
	-- `\b` still toggles 'background' and syncs Kitty.
	--
	-- 'jb.nvim' stays installed: `jb.icons` and `jb.borders` are used across
	-- this config and `:colorscheme jb` still works. The JetBrains-specific
	-- highlight groups it would otherwise define (dialog and tool-window
	-- borders, `JBIcon*`, the statusline groups) are bridged to standard ones
	-- for every other scheme in 'plugin/90_theme_compat.lua'.
	add({
		"https://github.com/rktjmp/lush.nvim",
		"https://github.com/lucobellic/ayugloom.nvim",
		"https://github.com/mcauley-penney/techbase.nvim",
	})
	vim.pack.add({
		"https://codeberg.org/navahas/sanzo.nvim",
	})
	add({ "https://github.com/oskarnurm/koda.nvim" })
	require("koda").setup({ theme = { dark = "dark", light = "glade" } })

	-- local background_schemes = { light = "sw1comm", dark = "hellbound" }
	-- local background_schemes = { light = "sw1comm", dark = "sanzo" }
	-- local background_schemes = { light = "ayugloom", dark = "ayugloom" }
	-- local background_schemes = { light = "koda-dark", dark = "koda-dark" }
	local background_schemes = { light = "sw1comm", dark = "koda-dark" }
	-- local background_schemes = { light = "rwth-light", dark = "rwth-dark" }
	-- local background_schemes = { light = "circadia-light", dark = "circadia-dark" }

	-- Persisted across sessions so a new `nvim` starts in whatever 'background'
	-- the last `\b` left behind, whether that happened in this terminal or
	-- another one. `~/.config/kitty/<scheme>.conf` has one file per scheme
	-- above; Kitty itself is kept in sync the same way, both live (through its
	-- remote-control socket, so every open window repaints immediately) and
	-- for future windows (by rewriting the one uncommented `include *.conf`
	-- line at the bottom of 'kitty.conf', which is what a fresh Kitty process
	-- actually loads).
	local state_file = vim.fs.joinpath(vim.fn.stdpath("state"), "background")

	local function read_background()
		local ok, lines = pcall(vim.fn.readfile, state_file)
		local bg = ok and lines[1]
		return (bg == "dark") and "dark" or "light"
	end

	local function write_background(bg)
		pcall(vim.fn.writefile, { bg }, state_file)
	end

	local function sync_kitty(scheme)
		-- Only meaningful inside an actual Kitty window, and only if Kitty
		-- itself is on 'PATH' (`kitty @` is the remote-control CLI).
		if vim.env.KITTY_WINDOW_ID == nil or vim.fn.executable("kitty") == 0 then
			return
		end

		local conf_dir = vim.fs.joinpath(vim.env.HOME, ".config", "kitty")
		local scheme_conf = vim.fs.joinpath(conf_dir, scheme .. ".conf")
		local target = vim.env.KITTY_LISTEN_ON or "unix:/tmp/kitty"
		vim.system({ "kitty", "@", "--to", target, "set-colors", "--all", scheme_conf }, { detach = true })

		local kitty_conf = vim.fs.joinpath(conf_dir, "kitty.conf")
		local ok, lines = pcall(vim.fn.readfile, kitty_conf)
		if not ok then
			return
		end
		local changed = false
		for i, line in ipairs(lines) do
			if line:match("^include %S+%.conf$") then
				lines[i] = "include " .. scheme .. ".conf"
				changed = true
			end
		end
		if changed then
			vim.fn.writefile(lines, kitty_conf)
		end
	end

	-- Ghostty has no remote-control socket, so the `theme = ` line in its config
	-- is rewritten (`~/.config/ghostty/themes/<scheme>.conf` must exist) and
	-- every window is repainted by asking it to reload through AppleScript.
	local function sync_ghostty(scheme)
		if vim.env.TERM_PROGRAM ~= "ghostty" then
			return
		end

		local conf_dir = vim.fs.joinpath(vim.env.HOME, ".config", "ghostty")
		if vim.fn.filereadable(vim.fs.joinpath(conf_dir, "themes", scheme .. ".conf")) == 0 then
			return
		end
		local ghostty_conf = vim.fs.joinpath(conf_dir, "config")
		local ok, lines = pcall(vim.fn.readfile, ghostty_conf)
		if not ok then
			return
		end
		for i, line in ipairs(lines) do
			if line:match("^theme%s*=") then
				lines[i] = "theme = " .. scheme .. ".conf"
			end
		end
		vim.fn.writefile(lines, ghostty_conf)
		vim.system({
			"osascript",
			"-e",
			'tell application "Ghostty" to perform action "reload_config" on terminal 1 of window 1',
		}, { detach = true })
	end

	local toggle_background = function()
		vim.o.background = vim.o.background == "dark" and "light" or "dark"
		local scheme = background_schemes[vim.o.background]
		vim.cmd("colorscheme " .. scheme)
		write_background(vim.o.background)
		sync_kitty(scheme)
		sync_ghostty(scheme)
	end
	vim.keymap.set("n", "\\b", toggle_background, { desc = "Toggle background" })

	vim.o.background = read_background()
	vim.cmd("colorscheme " .. background_schemes[vim.o.background])
end)

-- In-window decorations ======================================================
-- Deferred: none of this is needed to paint the first buffer, and
-- 'nvim-treesitter-context' below is off by default anyway.
later(function()
	-- Per-window diffstat in the top-right corner: how this window's buffer
	-- differs from the git index, and nothing else. It does not name the file --
	-- the buffer line lists it and the status line spells out its whole path --
	-- and it does not count diagnostics either; those are on the status line,
	-- where they are counted once rather than once per split.
	add({ "https://github.com/b0o/incline.nvim" })
	add({ "https://github.com/nvim-lua/plenary.nvim" })

	local UNFOCUSED = "NonText"

	-- Diffstat signs rather than glyphs: three counts that only differ by icon
	-- read faster when the icon is the arithmetic, and "+366" is legible in a
	-- terminal font at any size where a Nerd Font glyph is a smudge.
	-- stylua: ignore
	local diff_parts = {
		{ key = "added",   icon = "+", group = "GitSignsAdd" },
		{ key = "changed", icon = "~", group = "GitSignsChange" },
		{ key = "removed", icon = "-", group = "GitSignsDelete" },
	}

	local function git_label(props)
		local signs = vim.b[props.buf].gitsigns_status_dict
		if signs == nil then
			return {}
		end
		local label = {}
		for _, part in ipairs(diff_parts) do
			local n = tonumber(signs[part.key])
			if n ~= nil and n > 0 then
				local group = props.focused and part.group or UNFOCUSED
				table.insert(label, { part.icon .. n .. " ", group = group })
			end
		end
		return label
	end

	require("incline").setup({
		render = function(props)
			local buftype, filetype = vim.bo[props.buf].buftype, vim.bo[props.buf].filetype
			if buftype == "nofile" and filetype == "" then
				return {}
			end

			return git_label(props)
		end,
	})

	add({ "https://github.com/lukas-reineke/indent-blankline.nvim" })
	require("ibl").setup({
		indent = { char = "▏", tab_char = "▏" },
		scope = { char = "▏", show_start = false, show_end = false },
	})

	add({ "https://github.com/nvim-treesitter/nvim-treesitter-textobjects" })
	require("nvim-treesitter-textobjects").setup({
		select = { lookahead = true, include_surrounding_whitespace = false },
		move = { set_jumps = true },
	})

	-- Disabled by default; toggle with `:TSContextToggle`
	add({ "https://github.com/nvim-treesitter/nvim-treesitter-context" })
	require("treesitter-context").setup({
		enable = false,
		multiwindow = false,
		max_lines = 5,
		min_window_height = 0,
		line_numbers = true,
		multiline_threshold = 1,
		trim_scope = "outer",
		mode = "topline",
		separator = "-",
		zindex = 20,
		on_attach = nil,
	})
end)

-- Buffer line ================================================================
-- Owns 'tabline'. 'mini.tabline' is deliberately not set up.
--
-- Styled after 'test-nvim': flat tabs with no separators, no close buttons and
-- no active indicator, so the only thing marking the current buffer is its own
-- highlight. Names drop the extension because the filetype icon in front of
-- them already says what the file is, and a pinned buffer collapses to nothing
-- but its pin.
now(function()
	add({ "https://github.com/akinsho/bufferline.nvim" })
	local groups = require("bufferline.groups")

	--- Whether `bufnr` currently sits in the pinned group.
	--- @param bufnr integer
	local function is_pinned(bufnr)
		for _, element in ipairs(require("bufferline").get_elements().elements or {}) do
			if element.id == bufnr then
				return groups._is_pinned(element)
			end
		end
		return false
	end

	-- 'ayugloom' defines the `BufferLine*` groups itself, and 'bufferline.nvim'
	-- sets its own with `default = true` -- that is what `themable` means -- so
	-- the scheme wins for the tab. The per-filetype icon groups, though, are
	-- derived from bufferline's *own* palette and keep its background, which is
	-- why an icon sits in a rectangle of the wrong colour: #0f131a on a #152537
	-- tab. Resolve the background from the group that is actually in effect, and
	-- let only the current buffer's icon keep a colour of its own.
	local visibility = require("bufferline.constants").visibility
	local parents = {
		[visibility.SELECTED] = "BufferLineBufferSelected",
		[visibility.INACTIVE] = "BufferLineBufferVisible",
		[visibility.NONE] = "BufferLineBackground",
	}
	local suffixes = {
		[visibility.SELECTED] = "Selected",
		[visibility.INACTIVE] = "Inactive",
		[visibility.NONE] = "",
	}
	local icon_hl_cache = {}

	--- @param state integer one of `bufferline.constants.visibility`
	--- @param base_hl string the devicon's own highlight group
	--- @return string
	require("bufferline.highlights").set_icon_highlight = function(state, _, base_hl)
		local parent = parents[state] or parents[visibility.NONE]
		local name = "BufferLine" .. base_hl .. (suffixes[state] or "")
		if icon_hl_cache[name] then
			return name
		end
		if state == visibility.SELECTED then
			vim.api.nvim_set_hl(0, name, {
				fg = vim.api.nvim_get_hl(0, { name = base_hl, link = false }).fg,
				bg = vim.api.nvim_get_hl(0, { name = parent, link = false }).bg,
			})
		else
			vim.api.nvim_set_hl(0, name, { link = parent })
		end
		icon_hl_cache[name] = true
		return name
	end

	-- The groups above are cached on first draw and resolved from colours that
	-- `:colorscheme` has just replaced, so they have to be rebuilt with it.
	local rebuild_icon_highlights = function()
		icon_hl_cache = {}
		pcall(function()
			require("bufferline.ui").refresh()
		end)
	end
	Config.new_autocmd("ColorScheme", nil, rebuild_icon_highlights, "Rebuild buffer line icon highlights")

	require("bufferline").setup({
		highlights = {
			-- The buffer line and the status line are the top and bottom rules
			-- of the same frame, so the empty part of one is the background of
			-- the other.
			fill = { bg = { attribute = "bg", highlight = "StatusLine" } },
		},
		options = {
			themable = true,
			always_show_bufferline = true,
			show_buffer_close_icons = false,
			show_close_icon = false,
			show_tab_indicators = true,
			modified_icon = "●",
			truncate_names = false,
			tab_size = 0,
			separator_style = { "", "" },
			indicator = { icon = "", style = "none" },
			-- Diagnostics belong to a window, not to a tab: 'incline' above
			-- already renders them for the window they are actually in.
			diagnostics = false,
			hover = { enabled = false },
			name_formatter = function(buf)
				return is_pinned(buf.bufnr) and "" or vim.fn.fnamemodify(buf.name, ":t:r")
			end,
			groups = {
				items = { groups.builtin.pinned:with({ icon = "󱂺" }) },
			},
		},
	})

	-- 'bufferline.nvim' has no default mappings and neither did 'barbar.nvim'
	-- before it; buffers are still cycled with `[b` / `]b` ('mini.bracketed')
	-- and picked with `<Leader>fb`. Pinning is the one thing configured above
	-- that nothing else can reach.
	vim.keymap.set("n", "<Leader>bp", "<Cmd>BufferLineTogglePin<CR>", { desc = "Pin" })
end)

-- Leader hints ===============================================================
-- Deferred: the popup only ever appears after 'timeoutlen' on a <Leader> press.
later(function()
	add({ "https://github.com/folke/which-key.nvim" })
	require("which-key").setup({})
end)

-- Messages and notifications =================================================
-- 'fidget.nvim' owns `vim.notify`. Its own progress subsystem is turned off:
-- LSP progress is already on the status line ('plugin/92_statusline.lua', the
-- `lsp_progress` component), and two spinners for the same handshake is one
-- too many. Drop `ignore` below to let fidget have it back.
later(function()
	add({ "https://github.com/j-hui/fidget.nvim" })
	require("fidget").setup({
		notification = {
			override_vim_notify = true,
			view = { group_separator = "───" },
			window = {
				winblend = 0,
				border = "single",
				normal_hl = "Comment",
				x_padding = 1,
			},
		},
		progress = {
			ignore = {
				function()
					return true
				end,
			},
		},
	})

	-- Route `window/showMessage` through the same notifier
	local levels = { "ERROR", "WARN", "INFO", "INFO", "DEBUG" }
	vim.lsp.handlers["window/showMessage"] = function(_, result, ctx)
		local client = vim.lsp.get_client_by_id(ctx.client_id) or {}
		vim.notify(result.message, vim.log.levels[levels[result.type]], {
			annote = client.name or "unknown",
			group = "lsp",
		})
	end

	require("vim._core.ui2").enable({
		enable = true,
		msg = {
			targets = { bufwrite = "msg", undo = "msg" },
			timeout = 4000,
		},
	})
end)
