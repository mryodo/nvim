-- ┌────────────────────────┐
-- │ Statusline and linting │
-- └────────────────────────┘
--
-- 'lualine.nvim' owns 'statusline' (globally, via `globalstatus`).
-- 'mini.statusline' is deliberately not set up. There is no buffer line.
--
-- One bar per edge, each with its own job:
--
-- - the winbar at the top of every window names its file, the 'nvim-navic'
--   symbol path the cursor is inside, and its diffstat against the git index,
-- - the status line carries the session's own state: mode, branch,
--   diagnostics, linters, LSP progress, search, clock.

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
		end, Config.kind_icons),
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
	local mode_icons = {
		["NORMAL"]    = "", ["O-PENDING"] = "", ["VISUAL"]  = "",
		["V-LINE"]    = "", ["V-BLOCK"]   = "", ["SELECT"]  = "",
		["S-LINE"]    = "", ["S-BLOCK"]   = "", ["INSERT"]  = "",
		["REPLACE"]   = "", ["V-REPLACE"] = "", ["COMMAND"] = "",
		["EX"]        = "", ["MORE"]      = "", ["CONFIRM"] = "",
		["SHELL"]     = "", ["TERMINAL"]  = "",
	}

	--- Reads a colour straight out of a highlight group instead of hardcoding a
	--- hex, so the status line follows whatever `:colorscheme` is active rather
	--- than only ever agreeing with one scheme. `attr` is `"fg"` or `"bg"`;
	--- `fallback` (an Ayu hex, so a scheme missing the group entirely still
	--- renders something sane) is used when the group is unset or the running
	--- Neovim has no GUI colours (`notermguicolors`).
	local function hl_color(name, attr, fallback)
		local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
		local value = ok and hl[attr]
		return value and string.format("#%06x", value) or fallback
	end

	-- Semantic groups every colorscheme defines, mapped to the same roles the
	-- old Ayu-literal palette used. `black` is the *background* of `Normal`,
	-- not a foreground: it is the text colour painted over a filled mode
	-- block, so it needs to read as "the editor's own background colour",
	-- whatever that is.
	local palette, mode_colors = {}, {}

	--- Re-derive `palette` and `mode_colors` from the highlight groups the
	--- active scheme defines. Run once at setup and again on every
	--- `ColorScheme`, so switching schemes repaints the status line instead of
	--- leaving it stuck on whatever theme was active at startup.
	local function refresh_palette()
		-- Under Ghostty `Normal` has no background ('plugin/90_theme_compat.lua'),
		-- so fall back to something that reads on a coloured block
		palette.black = hl_color("Normal", "bg", vim.o.background == "light" and "#ffffff" or "#101010")
		palette.fg = hl_color("Normal", "fg", vim.o.background == "light" and "#000000" or "#d0d0d0")
		palette.dark_gray = hl_color("Comment", "fg", "#70809b")
		-- Diagnostic groups, not syntax ones: monochrome schemes (koda) keep
		-- syntax grey but still colour diagnostics
		palette.red = hl_color("DiagnosticError", "fg", "#F07178")
		palette.green = hl_color("DiagnosticOk", "fg", "#AAD94C")
		palette.blue = hl_color("DiagnosticHint", "fg", "#59C2FF")
		palette.purple = hl_color("Constant", "fg", "#D2A6FF")
		palette.orange = hl_color("DiagnosticWarn", "fg", "#FFB454")

		-- Mode drives the two blocks at either end of the line: Normal mode in
		-- the text colour (reverse video), every other mode in its own colour.
		-- The "secondary" items (progress, search) pick that colour up as a
		-- foreground, dimmed to grey in Normal mode. Everything else on the
		-- line sits on the editor background.
		-- stylua: ignore
		mode_colors.n = palette.fg;        mode_colors.i = palette.green
		mode_colors.v = palette.orange;    mode_colors.V = palette.orange
		mode_colors["\22"] = palette.orange
		mode_colors.c = palette.blue;      mode_colors["!"] = palette.blue
		mode_colors.s = palette.purple;    mode_colors.S = palette.purple
		mode_colors["\19"] = palette.purple; mode_colors.t = palette.purple
		mode_colors.R = palette.red;       mode_colors.r = palette.red

		pcall(function()
			require("lualine").refresh()
		end)
	end
	refresh_palette()
	Config.new_autocmd("ColorScheme", nil, refresh_palette, "Refresh statusline palette from theme")

	local function mode_color()
		return mode_colors[(vim.fn.mode(1) or "n"):sub(1, 1)] or palette.fg
	end

	-- The cursor's line number takes the mode colour too
	local function paint_cursor_line_nr()
		vim.api.nvim_set_hl(0, "CursorLineNr", { fg = mode_color(), bold = true })
	end
	paint_cursor_line_nr()
	Config.new_autocmd({ "ModeChanged", "ColorScheme" }, nil, paint_cursor_line_nr, "Colour cursor line number by mode")

	--- Filled block: the mode colour as a background.
	local function primary()
		return { bg = mode_color(), fg = palette.black, gui = "bold" }
	end

	--- Unfilled: the mode colour as a foreground, grey in Normal mode.
	local function secondary()
		local color = mode_color()
		return { fg = color == palette.fg and palette.dark_gray or color }
	end

	--- Attached language servers, after the codicon "server" glyph
	local function lsp_clients()
		local names = {}
		for _, client in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do
			table.insert(names, client.name)
		end
		return #names > 0 and ("\u{eb50} " .. table.concat(names, " ")) or ""
	end

	-- The glyphs the diagnostic signs used before they became line numbers
	-- Coloured icon, faint count: the count follows the symbol in the
	-- component's output, so the symbol ends by switching to `FaintText`
	local diagnostic_symbols = {
		error = "%#DiagnosticError#\u{f015a} %#FaintText#",
		warn = "%#DiagnosticWarn#\u{f002a} %#FaintText#",
		info = "%#DiagnosticInfo#\u{f02fd} %#FaintText#",
		hint = "%#DiagnosticHint#\u{f0336} %#FaintText#",
	}

	local function clock()
		return "  " .. os.date("%H:%M") .. " "
	end

	-- Sections are coloured per component, so the theme only has to keep the
	-- whole line on one background.
	local flat = {}
	for _, section in ipairs({ "a", "b", "c", "x", "y", "z" }) do
		flat[section] = "StatusLineClear" -- No background ('plugin/90_theme_compat.lua')
	end
	local flat_theme = {}
	for _, mode in ipairs({ "normal", "insert", "visual", "replace", "command", "terminal", "inactive" }) do
		flat_theme[mode] = vim.deepcopy(flat)
	end

	require("lualine").setup({
		options = {
			theme = flat_theme,
			globalstatus = true, -- sets 'laststatus' to 3, making the status line global
			component_separators = { left = "", right = "" },
			section_separators = { left = "", right = "" },
			always_divide_middle = true,
			-- Default also re-evaluates the whole line on every |CursorMovedI|,
			-- i.e. on every keystroke in Insert mode. Nothing here needs that.
			refresh = {
				events = {
					"WinEnter", "BufEnter", "BufWritePost", "SessionLoadPost", "FileChangedShellPost",
					"VimResized", "Filetype", "CursorMoved", "ModeChanged",
				},
			},
		},
		sections = {
			lualine_a = {},
			lualine_b = {},
			-- Left: one filled block of mode and branch.
			lualine_c = {
				{
					"mode",
					fmt = function(mode)
						return (mode_icons[mode] or "") .. " " .. mode
					end,
					color = primary,
					padding = { left = 1, right = 1 },
				},
				{
					"branch",
					icon = "",
					color = primary,
					padding = { left = 0, right = 1 },
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
					-- Spinner and percentage only: the server name is already
					-- listed right next to it
					display_components = { "spinner", { "percentage" } },
					-- The component already writes its percentage sign as `%%`,
					-- which the escape below would double into a literal `%%`.
					separators = { percentage = { pre = "", post = "% " } },
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
				{ lsp_clients, color = "Comment", padding = { left = 0, right = 1 } },
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

-- Winbar =====================================================================
-- Native, not lualine's: lualine's winbar would inherit the status line's
-- background, while 'WinBar'/'WinBarNC' follow the editor's. Set per window,
-- and only on real file windows, so floats and tool windows stay bare.
later(function()
	-- stylua: ignore
	local diff_parts = {
		{ key = "added",   icon = "+", group = "GitSignsAdd" },
		{ key = "changed", icon = "~", group = "GitSignsChange" },
		{ key = "removed", icon = "-", group = "GitSignsDelete" },
	}

	Config.winbar = function()
		local win = vim.g.statusline_winid or vim.api.nvim_get_current_win()
		local buf = vim.api.nvim_win_get_buf(win)
		local focused = win == vim.api.nvim_get_current_win()
		local base = focused and "%#WinBar#" or "%#WinBarNC#"

		local path = vim.api.nvim_buf_get_name(buf)
		local name = vim.fn.fnamemodify(path, ":t")
		local icon, icon_hl = MiniIcons.get("file", name)
		-- Parent folder, relative to the working directory, dimmed
		local dir = vim.fn.fnamemodify(path, ":~:.:h")
		dir = dir == "." and "" or (#dir > 30 and vim.fn.pathshorten(dir) or dir) .. "/"
		local parts = {
			" ",
			focused and ("%#" .. icon_hl .. "#") or base,
			icon,
			" ",
			"%#Comment#",
			dir:gsub("%%", "%%%%"),
			focused and "%#WinBarFile#" or base,
			name:gsub("%%", "%%%%"),
			vim.bo[buf].modified and " ●" or "",
			base,
			"%<", -- Narrow windows cut the breadcrumb, not the file name
		}

		local ok, navic = pcall(require, "nvim-navic")
		if focused and ok and navic.is_available(buf) then
			local location = navic.get_location({}, buf)
			if location ~= "" then
				vim.list_extend(parts, { " %#NavicSeparator#›%* ", location, base })
			end
		end

		table.insert(parts, "%=")

		-- Open file buffers, across all windows
		local n_bufs = 0
		for _, b in ipairs(vim.api.nvim_list_bufs()) do
			if vim.bo[b].buflisted and vim.bo[b].buftype == "" and vim.api.nvim_buf_get_name(b) ~= "" then
				n_bufs = n_bufs + 1
			end
		end
		if focused and n_bufs > 1 then
			table.insert(parts, "%#Comment#\u{f0222} " .. n_bufs .. "  ")
		end

		local signs = vim.b[buf].gitsigns_status_dict or {}
		for _, part in ipairs(diff_parts) do
			local n = tonumber(signs[part.key])
			if n ~= nil and n > 0 then
				-- Coloured sign, faint number
				local sign = focused and ("%#" .. part.group .. "#") or base
				table.insert(parts, sign .. part.icon .. (focused and "%#FaintText#" or "") .. n .. " ")
			end
		end
		return table.concat(parts)
	end

	local set_winbar = function()
		for _, win in ipairs(vim.api.nvim_list_wins()) do
			local buf = vim.api.nvim_win_get_buf(win)
			local is_file = vim.api.nvim_win_get_config(win).relative == ""
				and vim.bo[buf].buftype == ""
				and vim.api.nvim_buf_get_name(buf) ~= ""
			local value = is_file and "%{%v:lua.Config.winbar()%}" or ""
			if vim.wo[win].winbar ~= value then
				vim.wo[win].winbar = value
			end
		end
	end
	set_winbar()
	Config.new_autocmd({ "BufWinEnter", "WinNew", "BufFilePost", "FileType" }, nil, set_winbar, "Set winbar")

	-- The winbar is not re-evaluated on cursor moves by itself; 'nvim-navic'
	-- has updated its context by now (its autocommand was created first)
	local redraw = function()
		vim.cmd.redrawstatus()
	end
	Config.new_autocmd("CursorMoved", nil, redraw, "Refresh winbar breadcrumb")
	Config.new_autocmd("User", "GitSignsUpdate", redraw, "Refresh winbar diffstat")
end)
