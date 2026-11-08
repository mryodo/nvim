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
-- Deferred on purpose: none of these is the active scheme, so pulling 22 repos
-- into 'runtimepath' and sourcing their `plugin/` files is pure startup cost.
-- `later()` does it once the first screen is on the terminal.
later(function()
	-- 'colors/everforest-{dark,light}.lua' wrap it, so the names match the
	-- Kitty/Ghostty theme files and threader's themes.
	-- Before the list below: 'neanias/everforest' also ships a `lua/everforest`.
	add({ "https://github.com/neanias/everforest-nvim" })
	require("everforest").setup({
		background = "medium",
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
		"https://github.com/nendix/zen.nvim",
		"https://github.com/nyoom-engineering/oxocarbon.nvim",
		"https://github.com/slugbyte/lackluster.nvim",
		"https://github.com/tanmaymanojgandhi/circadia",
		"https://github.com/thesimonho/kanagawa-paper.nvim",
		"https://github.com/vague-theme/vague.nvim",
		"https://github.com/webhooked/kanso.nvim",
		"https://github.com/ThorstenRhau/token",
		"https://github.com/rktjmp/lush.nvim",
		"https://github.com/lucobellic/ayugloom.nvim",
		"https://codeberg.org/navahas/sanzo.nvim",
		"https://github.com/mryodo/rwth.nvim",
	})

	-- `minifilesstyle` would re-run `mini.files` setup with its own look on top of
	-- 'plugin/96_files.lua'
	require("rwth").setup({ transparent = false, minifilesstyle = false })

	-- 'circadia' nests its Neovim port under 'ports/neovim' rather than the
	-- plugin root, so its `lua/circadia` module is invisible to the native
	-- loader until that subdirectory joins 'runtimepath' too. Its
	-- `colors/circadia-dark.lua` and `colors/circadia-light.lua` entrypoints
	-- (kept in this repo, since the plugin ships no `colors/*.lua` of its own)
	-- depend on this to make `:colorscheme circadia-dark` work.
	local circadia = vim.pack.get({ "circadia" })[1]
	vim.opt.rtp:prepend(vim.fs.joinpath(circadia.path, "ports", "neovim"))
end)

-- Active colorscheme =========================================================
now(function()
	add({ "https://github.com/nickkadutskyi/jb.nvim" })
	local borders = require("jb.borders").borders.dialog

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
		},
	})

	-- Active scheme: 'koda-dark' / 'koda-glade'.
	-- `\b` still toggles 'background' and syncs Kitty.
	--
	-- 'jb.nvim' stays installed: `jb.borders` is used across
	-- this config and `:colorscheme jb` still works. The JetBrains-specific
	-- highlight groups it would otherwise define (dialog and tool-window
	-- borders, `JBIcon*`, the statusline groups) are bridged to standard ones
	-- for every other scheme in 'plugin/90_theme_compat.lua'.
	add({ "https://github.com/oskarnurm/koda.nvim" })
	require("koda").setup({ theme = { dark = "dark", light = "glade" } })

	-- local background_schemes = { light = "sw1comm", dark = "hellbound" }
	-- local background_schemes = { light = "sw1comm", dark = "sanzo" }
	-- local background_schemes = { light = "ayugloom", dark = "ayugloom" }
	-- local background_schemes = { light = "koda-dark", dark = "koda-dark" }
	-- local background_schemes = { light = "sw1comm", dark = "koda-dark" }
	-- local background_schemes = { light = "sw1comm", dark = "ayugloom" }
	-- local background_schemes = { light = "everforest-light", dark = "everforest-dark" }
	-- local background_schemes = { light = "rwth-light", dark = "rwth-dark" }
	-- local background_schemes = { light = "circadia-light", dark = "circadia-dark" }
	-- local background_schemes = { light = "minischeme2-light", dark = "minischeme2-dark" }
	local background_schemes = { light = "koda-glade", dark = "koda-dark" }

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
-- Deferred: none of this is needed to paint the first buffer.
later(function()
	-- Terminals on the float tint, marking them as tool panes
	local tint_terminal = function()
		vim.wo.winhighlight = "Normal:NormalFloat"
	end
	Config.new_autocmd({ "TermOpen", "BufWinEnter" }, "term://*", tint_terminal, "Tint terminal windows")

	add({ "https://github.com/lukas-reineke/indent-blankline.nvim" })
	require("ibl").setup({
		-- Groups defined in 'plugin/90_theme_compat.lua'
		indent = { char = "▏", tab_char = "▏", highlight = "IndentFaint" },
		scope = { char = "▏", show_start = false, show_end = false, highlight = "IndentScope" },
	})

	add({ "https://github.com/nvim-treesitter/nvim-treesitter-textobjects" })
	require("nvim-treesitter-textobjects").setup({
		select = { lookahead = true, include_surrounding_whitespace = false },
		move = { set_jumps = true },
	})

	-- Sticky scroll: the enclosing scopes stay pinned on the float tint
	-- ('plugin/90_theme_compat.lua'). Toggle with `:TSContextToggle`.
	add({ "https://github.com/nvim-treesitter/nvim-treesitter-context" })
	require("treesitter-context").setup({
		enable = true,
		multiwindow = false,
		max_lines = 3,
		min_window_height = 20,
		line_numbers = true,
		multiline_threshold = 1,
		trim_scope = "outer",
		mode = "topline",
		zindex = 20,
	})
end)

-- Leader hints ===============================================================
-- Deferred: the popup only ever appears after 'timeoutlen' on a <Leader> press.
later(function()
	add({ "https://github.com/folke/which-key.nvim" })
	local wk = require("which-key")
	wk.setup({ preset = "helix" })
	-- Codicons per group, tinted with the 'mini.icons' palette
	-- stylua: ignore
	local group_icons = {
		["AI"]           = { icon = "\u{ec10}", color = "purple" },
		["Buffer"]       = { icon = "\u{eaf0}", color = "cyan" },
		["Session"]      = { icon = "\u{eb49}", color = "azure" },
		["Explore/Edit"] = { icon = "\u{eaf7}", color = "yellow" },
		["Find"]         = { icon = "\u{ea6d}", color = "green" },
		["Git"]          = { icon = "\u{ea68}", color = "orange" },
		["Julia REPL"]   = { icon = "\u{eb9b}", color = "purple" },
		["Language"]     = { icon = "\u{eac4}", color = "azure" },
		["Other"]        = { icon = "\u{ea7c}", color = "grey" },
		["Run cell"]     = { icon = "\u{eb2c}", color = "green" },
		["Terminal"]     = { icon = "\u{ea85}", color = "red" },
		["Visits"]       = { icon = "\u{ea82}", color = "cyan" },
		["Todo"]         = { icon = "\u{eab3}", color = "yellow" },
	}
	for _, clue in ipairs(Config.leader_group_clues) do
		local group = clue.desc:sub(2)
		wk.add({ clue.keys, group = group, mode = clue.mode, icon = group_icons[group] })
	end

	add({ "https://github.com/folke/zen-mode.nvim" })
	require("zen-mode").setup({
		window = {
			backdrop = 0.95,
			width = 80,
			height = 0.9,
			options = { cursorline = true },
		},
	})
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
				border = "solid",
				normal_hl = "NormalFloat", -- The shared float tint
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
