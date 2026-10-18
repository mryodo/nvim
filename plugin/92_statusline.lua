-- ┌────────────────────────┐
-- │ Statusline and linting │
-- └────────────────────────┘
--
-- 'lualine.nvim' owns 'statusline' (globally, via `globalstatus`).
-- 'mini.statusline' is deliberately not set up. The buffer line lives in
-- 'plugin/93_ui.lua'.
--
-- Laid out the way 'test-nvim' lays out its 'heirline' status line, so that the
-- three horizontal rules of the frame divide the work instead of repeating it:
--
-- - the buffer line names every listed buffer,
-- - 'incline' ('plugin/93_ui.lua') shows what is wrong with each window's buffer
--   and how it differs from the git index, as badges in its top-right corner,
-- - the status line spells the current file out in full -- name and the
--   'nvim-navic' symbol path the cursor is inside -- and carries the session's
--   own state around it: mode, branch, diagnostics, linters, LSP progress,
--   search, clock.

local add = vim.pack.add
local later = Config.later

-- Linting ====================================================================
-- Prose linting for LaTeX. The statusline shows currently running linters.
later(function()
	add({ "https://github.com/mfussenegger/nvim-lint" })
	local lint = require("lint")
	lint.linters_by_ft = { tex = { "vale" } }
	lint.linters.vale.args = {
		"--config=" .. vim.fn.expand("~/.config/vale/.vale.ini"),
		"--output=line",
		"--",
	}
end)

-- Breadcrumbs ================================================================
-- Feeds the `navic` lualine component below.
--
-- Deferred: `later()` runs on the next event-loop tick, which is still well
-- before any language server finishes handshaking, so `lsp.auto_attach` below
-- usually sees every `LspAttach` -- see the catch-up loop for when it does not.
later(function()
	add({ "https://github.com/SmiteshP/nvim-navic" })
	local navic = require("nvim-navic")

	-- `nixd` returns `{anonymous}` as the name of an Array kind; shorten it and
	-- elide the middle of any other over-long symbol name.
	local format_text = function(text)
		if text == "{anonymous}" then
			return "{a}"
		end
		local len, goal_len = #text, 30
		if len <= goal_len then
			return text
		end
		local middle_len = 2 -- Length of ".."
		local left_len = math.floor((goal_len - middle_len) * 0.7)
		local right_len = goal_len - middle_len - left_len
		return text:sub(1, left_len) .. ".." .. text:sub(len - right_len + 1, len)
	end

	-- JSON objects are reported as `Module`; show them with the Object icon
	local format_data = function(data, _)
		if vim.bo.filetype == "json" then
			for _, item in ipairs(data) do
				if item.type == "Module" then
					item.type, item.kind = "Object", 19
				end
			end
		end
		return data
	end

	---@diagnostic disable-next-line: duplicate-set-field
	navic.get_location = function(opts_internal, bufnr)
		local data = format_data(navic.get_data(bufnr), opts_internal)
		return navic.format_data(data, opts_internal)
	end

	navic.setup({
		depth_limit = 4,
		highlight = true,
		separator = " › ",
		color_correction = "dynamic",
		lsp = {
			auto_attach = true,
			preference = { "phpactor", "nixd" },
		},
		format_text = format_text,
		icons = vim.tbl_map(function(icon)
			return icon ~= "" and icon .. " " or ""
		end, require("jb.icons").kind),
	})

	-- `auto_attach` is an |LspAttach| autocommand, and `later()` can run after a
	-- language server has already attached -- `mini.misc` spreads its queue over
	-- several event-loop ticks, so on a warm start `lua_ls` wins the race and
	-- the autocommand never fires for the buffer that is already open. Attach to
	-- whatever is running before leaving it to the autocommand.
	for _, client in ipairs(vim.lsp.get_clients()) do
		if client.server_capabilities.documentSymbolProvider then
			for buf in pairs(client.attached_buffers or {}) do
				if vim.api.nvim_buf_is_valid(buf) then
					navic.attach(client, buf)
				end
			end
		end
	end
end)

-- Statusline =================================================================
later(function()
	add({ "https://github.com/nvim-lualine/lualine.nvim" })
	add({ "https://github.com/arkav/lualine-lsp-progress" })

	local excluded_filetypes = { qf = true, help = true, NvimTree = true, fzf = true, netrw = true }

	local function should_track_buffer(buffer)
		-- Skip non-listed, non-loaded and non-modifiable buffers
		if not vim.api.nvim_get_option_value("buflisted", { buf = buffer }) then
			return false
		end
		if not vim.api.nvim_buf_is_loaded(buffer) then
			return false
		end
		if not vim.api.nvim_get_option_value("modifiable", { buf = buffer }) then
			return false
		end
		return not excluded_filetypes[vim.api.nvim_get_option_value("filetype", { buf = buffer })]
	end

	--- Count buffers with unsaved work: modified files, modified unnamed buffers
	--- and named buffers whose file does not exist on disk yet.
	local function count_modified_buffers()
		local count, cwd = 0, vim.fn.getcwd()

		for _, buffer in ipairs(vim.api.nvim_list_bufs()) do
			if should_track_buffer(buffer) then
				local is_modified = vim.api.nvim_get_option_value("modified", { buf = buffer })
				local filename = vim.api.nvim_buf_get_name(buffer)

				-- Ignore the empty buffer Neovim opens when started on a directory
				local is_empty_initial_buffer = false
				if not is_modified and filename ~= "" then
					is_empty_initial_buffer = vim.fn.resolve(filename) == cwd
						and vim.api.nvim_buf_line_count(buffer) <= 1
				end

				if not is_empty_initial_buffer then
					if is_modified then
						count = count + 1
					elseif filename ~= "" and not vim.uv.fs_stat(filename) then
						count = count + 1
					end
				end
			end
		end

		return count
	end

	-- Scanning every buffer on each redraw is wasteful; cache for 500ms
	local modified_cache = { count = 0, checked_at = 0 }
	local function unsaved_indicator()
		local now_ms = vim.uv.now()
		if now_ms - modified_cache.checked_at > 500 then
			modified_cache.count = count_modified_buffers()
			modified_cache.checked_at = now_ms
		end
		return modified_cache.count > 0 and "󰽃" or ""
	end

	local function running_linters()
		local linters = vim.tbl_map(function(linter)
			return " " .. linter
		end, require("lint").get_running())
		return #linters > 0 and table.concat(linters, " ") or ""
	end

	-- stylua: ignore
	local short_mode = {
		["NORMAL"]    = "NO", ["O-PENDING"] = "OP", ["VISUAL"]  = "VI",
		["V-LINE"]    = "VL", ["V-BLOCK"]   = "VB", ["SELECT"]  = "SE",
		["S-LINE"]    = "SL", ["S-BLOCK"]   = "SB", ["INSERT"]  = "IN",
		["REPLACE"]   = "RE", ["V-REPLACE"] = "VR", ["COMMAND"] = "CL",
		["EX"]        = "Ex", ["MORE"]      = "MO", ["CONFIRM"] = "??",
		["SHELL"]     = "Sh", ["TERMINAL"]  = "TE",
	}

	-- Mode colours come from the rwth lualine theme ('lua/lualine/themes/rwth.lua'
	-- in rwth.nvim), so the blocks drawn here match the theme's own sections.
	-- `load_theme` uses `dofile`, so re-reading it picks up the light/dark palette.
	local mode_colors = {}
	local theme_mode = {
		n = "normal", i = "insert", v = "visual", V = "visual", ["\22"] = "visual",
		s = "visual", S = "visual", ["\19"] = "visual", c = "command", ["!"] = "command",
		R = "replace", r = "replace", t = "terminal",
	}

	local function refresh_palette()
		local theme = require("lualine.utils.loader").load_theme("rwth")
		for key, name in pairs(theme_mode) do
			mode_colors[key] = theme[name].a
		end
		pcall(function()
			require("lualine").refresh()
		end)
	end
	refresh_palette()
	Config.new_autocmd("ColorScheme", nil, refresh_palette, "Refresh statusline palette from theme")

	local function mode_a()
		return mode_colors[(vim.fn.mode(1) or "n"):sub(1, 1)] or mode_colors.n
	end

	--- Filled block: the theme's mode section colours.
	local function primary()
		local a = mode_a()
		return { bg = a.bg, fg = a.fg }
	end

	--- Unfilled: the mode colour as a foreground.
	local function secondary()
		return { fg = mode_a().bg }
	end

	local function divider()
		return "┃"
	end

	-- The same glyphs 'incline' puts in its badges ('plugin/93_ui.lua')
	local jb_diagnostic = require("jb.icons").diagnostic
	local diagnostic_symbols = {
		error = jb_diagnostic[1] .. " ",
		warn = jb_diagnostic[2] .. " ",
		info = jb_diagnostic[3] .. " ",
		hint = jb_diagnostic[4] .. " ",
	}

	local function clock()
		return "  " .. os.date("%Hh%M") .. " "
	end

	local function navic_available()
		local ok, navic = pcall(require, "nvim-navic")
		return ok and navic.is_available()
	end

	local function no_jujutsu()
		return not require("lualine.components.jujutsu").is_jujutsu_repo()
	end

	require("lualine").setup({
		options = {
			theme = "rwth",
			globalstatus = true, -- sets 'laststatus' to 3, making the status line global
			component_separators = { left = "", right = "" },
			section_separators = { left = "", right = "" },
			always_divide_middle = true,
		},
		sections = {
			lualine_a = {},
			lualine_b = {},
			-- Left: one filled block of mode and branch, then the breadcrumb --
			-- the file's own icon, its name, and the symbol path the cursor is
			-- inside. The `navic` half carries its own `%#group#` markup; the
			-- groups it names are filled in 'plugin/90_theme_compat.lua'.
			lualine_c = {
				{
					"mode",
					fmt = function(mode)
						return short_mode[mode] or mode
					end,
					color = primary,
					padding = { left = 1, right = 1 },
				},
				{
					"branch",
					icon = "",
					color = primary,
					padding = { left = 0, right = 1 },
					cond = no_jujutsu,
				},
				-- Local component, see 'lua/lualine/components/jujutsu.lua'
				{ "jujutsu", color = primary, padding = { left = 0, right = 1 } },
				{ divider, color = secondary, padding = { left = 1, right = 1 } },
				{
					"filetype",
					icon_only = true,
					padding = { left = 0, right = 0 },
					fmt = function(filetype, _)
						-- Force the default filetype icon when there is none
						return filetype ~= "" and filetype or " "
					end,
				},
				{
					"filename",
					path = 0,
					color = "Title",
					padding = { left = 0, right = 0 },
					file_status = true,
					newfile_status = true,
					symbols = { newfile = "[new]", unnamed = "[no name]" },
				},
				-- Both hide themselves when no server can answer, so there is no
				-- dangling "›". lualine's own `separator` is not used for this:
				-- it draws a *transitional* highlight, which paints the glyph in
				-- the section background and makes it invisible.
				{
					function()
						return "›"
					end,
					cond = navic_available,
					color = "NavicSeparator",
					padding = { left = 1, right = 1 },
				},
				{
					"navic",
					color_correction = nil,
					navic_opts = { click = true, highlight = true },
					padding = { left = 0, right = 0 },
				},
			},
			-- Right: what the session is busy with, then the clock as the closing
			-- block -- the mirror of the mode block on the left.
			lualine_x = {
				-- Severity colour carries the meaning here, so this is the one
				-- thing on the line that does not follow the mode.
				{
					"diagnostics",
					sources = { "nvim_diagnostic" },
					symbols = diagnostic_symbols,
					padding = { left = 0, right = 1 },
				},
				{
					"lsp_progress",
					color = secondary,
					fmt = function(str)
						-- Should fix "E539: Illegal character <,>" error
						return require("lualine.utils.utils").stl_escape(str)
					end,
				},
				{
					unsaved_indicator,
					color = "StatusBarHasUnsavedBuffers",
					padding = { left = 0, right = 1 },
				},
				{ "searchcount", color = secondary, padding = { left = 0, right = 1 } },
				{ divider, color = secondary, padding = { left = 0, right = 1 } },
				{ clock, color = primary, padding = { left = 0, right = 0 } },
			},
			lualine_y = {},
			lualine_z = {},
		},
		-- Inactive windows get no statusline at all ('globalstatus' is on)
		inactive_sections = {
			lualine_a = {},
			lualine_b = {},
			lualine_c = {},
			lualine_x = {},
			lualine_y = {},
			lualine_z = {},
		},
	})
end)
