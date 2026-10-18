-- ┌────────────────────────┐
-- │ mini.files file explorer │
-- └────────────────────────┘
--
-- Opened with `<Leader>ed` / `<Leader>ef` (see 'plugin/20_keymaps.lua').
-- The sidebar tree is 'snacks.explorer' (`<Leader>op`, 'plugin/94_completion.lua');
-- this is the floating, column-based explorer.

local now_if_args = Config.now_if_args
local later = Config.later

now_if_args(function()
	require("mini.files").setup({
		windows = {
			preview = true,
			width_focus = math.min(45, math.floor(0.3 * vim.o.columns)),
			width_nofocus = math.min(30, math.floor(0.18 * vim.o.columns)),
			width_preview = math.min(60, math.floor(0.3 * vim.o.columns)),
		},
		options = {
			use_as_default_explorer = true,
		},
		content = {
			prefix = function(fs_entry)
				local category = fs_entry.fs_type == "directory" and "directory" or "file"
				local icon, hl = MiniIcons.get(category, fs_entry.name)
				return "  " .. icon .. "  ", hl
			end,
		},
	})

	-- '<CR>' has no default mapping (mini.files only binds 'l'/'L' to go in,
	-- deliberately, so that normal-mode navigation never risks opening a file
	-- by accident). Add it back as the equivalent of the default 'L'
	-- ('go_in_plus'): open a file and close the explorer, or just go a level
	-- deeper for a directory.
	Config.new_autocmd("User", "MiniFilesBufferCreate", function(args)
		vim.keymap.set("n", "<CR>", function()
			MiniFiles.go_in({ close_on_file = true })
		end, { buffer = args.data.buf_id, desc = "Open" })
	end, "Open mini.files entry on <CR>")

	-- Flip fg/bg for the pane title, same 'reverse' trick as the 'blink.cmp'
	-- kind icons ('plugin/90_theme_compat.lua'): a highlight is either a link
	-- or a set of attributes, so the link has to be resolved first before
	-- adding `reverse`. Mini.files relinks both groups to 'FloatTitle' on
	-- every 'ColorScheme' event, so this has to redo the flip on that event too.
	local function reverse_title_highlights()
		for _, name in ipairs({ "MiniFilesTitle", "MiniFilesTitleFocused" }) do
			local attrs = vim.api.nvim_get_hl(0, { name = name, link = false })
			if not attrs.reverse then
				attrs.reverse = true
				vim.api.nvim_set_hl(0, name, attrs)
			end
		end
	end
	reverse_title_highlights()
	Config.new_autocmd("ColorScheme", nil, reverse_title_highlights, "Flip mini.files title fg/bg")

	-- Dim unfocused columns -----------------------------------------------------
	local minifiles_windows = {}

	local function minifiles_winhl(focused)
		local normal = focused and "MiniFilesNormal" or "MiniFilesNormalInactive"
		-- Current line uses the same color as a 'changed' hunk mark on the
		-- 'satellite.nvim' scrollbar ('plugin/91_git.lua'), which links to
		-- 'gitsigns.nvim's own 'GitSignsChange'.
		local cursorline = focused and "GitSignsChange" or "CursorLine"
		local title = focused and "MiniFilesTitleFocused" or "MiniFilesTitle"
		local files = focused and "MiniFilesFile" or "MiniFilesFileInactive"
		local dirs = focused and "MiniFilesDirectory" or "MiniFilesFileDirectoryInactive"
		local border = focused and "MiniFilesBorder" or "MiniFilesBorderInactive"

		return table.concat({
			"Normal:" .. normal,
			"NormalFloat:" .. normal,
			"EndOfBuffer:" .. normal,
			"CursorLine:" .. cursorline,
			"MiniFilesBorder:" .. border,
			"FloatBorder:" .. border,
			"FloatTitle:" .. title,
			"MiniFilesFile:" .. files,
			"MiniFilesDirectory:" .. dirs,
		}, ",")
	end

	local function update_minifiles_backgrounds()
		local current_win = vim.api.nvim_get_current_win()

		for win_id in pairs(minifiles_windows) do
			if vim.api.nvim_win_is_valid(win_id) then
				local opts = { win = win_id }
				vim.api.nvim_set_option_value("winhighlight", minifiles_winhl(win_id == current_win), opts)
			else
				minifiles_windows[win_id] = nil
			end
		end
	end

	-- Anchor the columns against the top-left of the editor, full height, snacks.explorer-style.
	-- `row`/`col` are otherwise left alone: mini.files already cascades each
	-- column's `col` from 0 (flush left) based on the cumulative width of the
	-- columns to its left, so overriding `col` here would stack every column
	-- on top of the others instead of side by side.
	local function explorer_height()
		return vim.o.lines - vim.o.cmdheight - 3 -- leave room for the title row, statusline, cmdline
	end

	-- Like 'snacks.explorer's own sidebar: only the active column gets the
	-- right-edge separator; every other column is fully borderless so
	-- adjacent columns blend together instead of each drawing its own line.
	-- All still reserve a blank top row so `config.title` has somewhere to
	-- render (an empty top entry hides that row entirely, title and all).
	-- stylua: ignore
	local RIGHT_LINE = { "▕", "ToolWindowFloatBorder" }
	-- stylua: ignore
	local BOTTOM_PAD = { " ", "ToolWindowFloatBorder" }

	-- mini.files names every one of its buffers 'minifiles://<buf_id>/<fs path>',
	-- including the preview column (which shows the real file under the
	-- cursor), so this recovers the real path regardless of the window's role.
	local function minifiles_win_path(win_id)
		local name = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win_id))
		return name:match("^minifiles://%d+/(.*)$")
	end

	-- The first/last entries in `get_explorer_state().windows` are always the
	-- leftmost/rightmost columns of the whole explorer (the branch's first and
	-- last depth), regardless of whether a window id was freshly created or is
	-- being reused for a new path.
	local function minifiles_win_edges(win_id)
		local state = MiniFiles.get_explorer_state()
		local windows = state and state.windows or {}
		if #windows == 0 then return true, true end
		return windows[1].win_id == win_id, windows[#windows].win_id == win_id
	end

	-- A blank 1-cell margin on the left (only for the leftmost column) and on
	-- the right (either the active column's separator line, or a blank margin
	-- if the rightmost column -- e.g. the preview -- isn't the active one).
	-- Middle columns get neither, so they stay flush against their neighbours
	-- instead of each clipping a cell off the one next to it.
	local function minifiles_border(win_id)
		local is_focused = win_id == vim.api.nvim_get_current_win()
		local is_leftmost, is_rightmost = minifiles_win_edges(win_id)

		local left = is_leftmost and " " or ""
		local right = is_focused and RIGHT_LINE or (is_rightmost and " " or "")
		local bottom = is_focused and BOTTOM_PAD or ""

		return { left, " ", right, right, right, bottom, bottom, left }
	end

	local function on_window_open(args)
		local win_id = args.data.win_id
		minifiles_windows[win_id] = true
		vim.schedule(update_minifiles_backgrounds)

		local config = vim.api.nvim_win_get_config(win_id)
		config.title_pos = "center"
		vim.api.nvim_win_set_config(win_id, config)

		vim.wo[win_id].winblend = 0
		vim.wo[win_id].list = false -- no 'listchars' dots over the icon padding
	end

	local function on_window_update(args)
		local win_id = args.data.win_id
		local config = vim.api.nvim_win_get_config(win_id)
		config.border = minifiles_border(win_id)
		config.row = 0
		config.height = explorer_height()

		-- Show each pane's own directory/file name (not the full path, and not
		-- mini.files' default of a basename everywhere but the leftmost column).
		local path = minifiles_win_path(win_id)
		if path ~= nil then
			local name = vim.fn.fnamemodify(path, ":t")
			config.title = " " .. (name ~= "" and name or path) .. " "
		end

		vim.api.nvim_win_set_config(win_id, config)
	end

	Config.new_autocmd("User", "MiniFilesWindowOpen", on_window_open, "Place mini.files window")
	Config.new_autocmd("User", "MiniFilesWindowUpdate", on_window_update, "Resize mini.files window")
	Config.new_autocmd({ "WinEnter", "BufEnter" }, nil, function()
		vim.schedule(update_minifiles_backgrounds)
	end, "Refocus mini.files columns")

	local add_marks = function()
		MiniFiles.set_bookmark("c", vim.fn.stdpath("config"), { desc = "Config" })
		MiniFiles.set_bookmark("p", vim.fn.stdpath("data") .. "/site/pack/core/opt", { desc = "Plugins" })
		MiniFiles.set_bookmark("w", vim.fn.getcwd, { desc = "Working directory" })
	end

	-- Slight dim on the rest of the editor while the explorer is open --------
	local backdrop = { win = nil, buf = nil }

	local function close_minifiles_backdrop()
		if backdrop.win and vim.api.nvim_win_is_valid(backdrop.win) then
			vim.api.nvim_win_close(backdrop.win, true)
		end
		if backdrop.buf and vim.api.nvim_buf_is_valid(backdrop.buf) then
			vim.api.nvim_buf_delete(backdrop.buf, { force = true })
		end
		backdrop.win, backdrop.buf = nil, nil
	end

	local function open_minifiles_backdrop()
		close_minifiles_backdrop()

		local buf = vim.api.nvim_create_buf(false, true)
		vim.bo[buf].buftype = "nofile"
		vim.bo[buf].bufhidden = "wipe"
		vim.bo[buf].swapfile = false

		local win = vim.api.nvim_open_win(buf, false, {
			relative = "editor",
			row = 0,
			col = 0,
			width = vim.o.columns,
			height = vim.o.lines,
			style = "minimal",
			focusable = false,
			zindex = 1,
			border = "none",
		})

		vim.wo[win].winblend = 40
		vim.wo[win].winhighlight = "Normal:FzfLuaBackdrop"

		backdrop.buf, backdrop.win = buf, win
	end

	local function resize_backdrop()
		if backdrop.win and vim.api.nvim_win_is_valid(backdrop.win) then
			vim.api.nvim_win_set_config(backdrop.win, {
				relative = "editor",
				row = 0,
				col = 0,
				width = vim.o.columns,
				height = vim.o.lines,
			})
		end
	end

	Config.new_autocmd("User", "MiniFilesExplorerOpen", function()
		vim.schedule(open_minifiles_backdrop)
		add_marks()
	end, "Open mini.files backdrop and bookmarks")
	Config.new_autocmd("User", "MiniFilesExplorerClose", close_minifiles_backdrop, "Close mini.files backdrop")
	Config.new_autocmd("VimResized", nil, resize_backdrop, "Resize mini.files backdrop")
end)

-- Git, diagnostic and hidden-file status (snacks.explorer parity) ===========
--
-- 'snacks.explorer' (the sidebar tree, `<Leader>op`) shows a git-status icon
-- next to every entry, recolors the filename to match, rolls that status up
-- to parent directories, dims dotfiles/gitignored paths, and shows a
-- diagnostic icon for files with LSP problems. mini.files has none of this
-- built in, so it is recreated here with |extmarks| on `MiniFilesBufferUpdate`.
-- The git-status categorisation and merge rules are ported from
-- 'snacks.nvim's own 'lua/snacks/picker/source/git.lua' and
-- 'lua/snacks/explorer/git.lua' so the colors and icons match exactly.
later(function()
	local ns_git = vim.api.nvim_create_namespace("minifiles_status_git")
	local ns_diag = vim.api.nvim_create_namespace("minifiles_status_diag")
	local ns_sym = vim.api.nvim_create_namespace("minifiles_status_sym")

	---@param buf_id integer
	---@return { lnum: integer, line: string, fs_entry: table }[]
	local function fs_items(buf_id)
		local lines = vim.api.nvim_buf_get_lines(buf_id, 0, -1, true)
		local items = {}
		for lnum, line in ipairs(lines) do
			local fs_entry = MiniFiles.get_fs_entry(buf_id, lnum)
			if fs_entry ~= nil then
				table.insert(items, { lnum = lnum, line = line, fs_entry = fs_entry })
			end
		end
		return items
	end

	local function set_extmark(buf_id, ns_id, row, col, opts)
		opts.hl_mode = opts.hl_mode or "combine"
		vim.api.nvim_buf_set_extmark(buf_id, ns_id, row, col, opts)
	end

	-- Git status ----------------------------------------------------------------
	--
	-- `git_status()` turns a two-letter porcelain code into a category (plus
	-- whether it is staged/unmerged); `merge_status()` combines two codes the
	-- same way a directory's status becomes the "worst" of its children's.
	-- Both are a direct port of 'snacks.nvim's versions.

	local CATEGORY_OF = { A = "added", D = "deleted", M = "modified", R = "renamed", C = "copied" }
	local CODE_OF =
		{ added = "A", deleted = "D", modified = "M", renamed = "R", copied = "C", untracked = "?", ignored = "!" }
	local PRIORITY_ORDER = "!?CRDAM"

	---@param xy string
	local function git_status(xy)
		local x, y = xy:sub(1, 1), xy:sub(2, 2)
		if xy == "??" then
			return { status = "untracked" }
		elseif xy == "!!" then
			return { status = "ignored" }
		elseif xy == "UU" then
			return { status = "modified", unmerged = true }
		elseif xy == "DD" then
			return { status = "deleted", unmerged = true }
		elseif xy == "AA" then
			return { status = "added", unmerged = true }
		elseif x == "U" or y == "U" then
			return { status = (x == "A" or y == "A") and "added" or "deleted", unmerged = true }
		elseif CATEGORY_OF[x] ~= nil then
			return { status = CATEGORY_OF[x], staged = true }
		elseif CATEGORY_OF[y] ~= nil then
			return { status = CATEGORY_OF[y] }
		end
		return { status = "modified" }
	end

	---@param status table
	local function status_priority(status)
		local code = CODE_OF[status.status]
		local prio = (PRIORITY_ORDER:find(code, 1, true) or 0) + (status.unmerged and 20 or 0)
		if not status.staged and code ~= "!" then
			prio = prio + 10
		end
		return prio
	end

	---@param a string
	---@param b string
	local function merge_status(a, b)
		if a == b then
			return a
		end
		local as, bs = git_status(a), git_status(b)
		if as.unmerged or bs.unmerged then
			return status_priority(as) > status_priority(bs) and a or b
		end
		if not as.staged or not bs.staged then
			if as.status == bs.status then
				return as.staged and b or a
			end
			return " M"
		end
		return "M "
	end

	-- stylua: ignore
	local GIT_HL = {
		added     = "Added",
		modified  = "DiagnosticWarn",
		deleted   = "Removed",
		renamed   = "Special",
		copied    = "Special",
		untracked = "NonText",
		ignored   = "NonText",
	}
	-- stylua: ignore
	local GIT_ICON = {
		staged    = "●",
		added     = "",
		modified  = "○",
		deleted   = "",
		renamed   = "",
		copied    = "",
		unmerged  = " ",
		untracked = "?",
		ignored   = "\u{f070}", -- nf-fa-eye_slash: crossed-eye marker for git-ignored paths
	}

	---@param status table
	local function status_hl(status)
		if status.unmerged then
			return "DiagnosticError"
		end
		if status.staged then
			return "DiagnosticHint"
		end
		return GIT_HL[status.status] or "NonText"
	end

	---@param status table
	local function status_icon(status)
		if status.staged then
			return GIT_ICON.staged
		end
		if status.unmerged then
			return GIT_ICON.unmerged
		end
		return GIT_ICON[status.status] or "?"
	end

	---@type table<string, { results: {status: string, file: string}[], time: integer }>
	local git_cache = {}
	local GIT_CACHE_TTL = 2 -- seconds; keeps repeated directory navigation from re-spawning `git`

	---@param root string
	---@param callback fun(results: {status: string, file: string}[])
	local function git_fetch(root, callback)
		vim.system(
			{ "git", "status", "--porcelain=v1", "--ignored=matching" },
			{ text = true, cwd = root },
			function(out)
				if out.code ~= 0 or out.stdout == nil then
					return
				end
				local results = {}
				for line in out.stdout:gmatch("[^\r\n]+") do
					local status, file = line:match("^(..) (.+)$")
					if status ~= nil then
						file = file:match("^.* %-> (.+)$") or file -- rename: "old -> new"
						file = file:gsub("/$", "") -- directory entries are reported with a trailing slash
						table.insert(results, { status = status, file = root .. "/" .. file })
					end
				end
				if vim.fn.isdirectory(root .. "/.git") == 1 then
					table.insert(results, { status = "!!", file = root .. "/.git" })
				end
				vim.schedule(function()
					callback(results)
				end)
			end
		)
	end

	---@param root string
	---@param callback fun(results: {status: string, file: string}[])
	local function git_get(root, callback)
		local cached = git_cache[root]
		if cached ~= nil then
			callback(cached.results)
			if os.time() - cached.time < GIT_CACHE_TTL then
				return
			end
		end
		git_fetch(root, function(results)
			git_cache[root] = { results = results, time = os.time() }
			callback(results)
		end)
	end

	---@param path string
	---@param is_dir boolean
	---@param results {status: string, file: string}[]
	---@return string|nil
	local function entry_status(path, is_dir, results)
		for _, r in ipairs(results) do
			if r.file == path then
				return r.status
			end
		end
		if not is_dir then
			return nil
		end
		-- A directory's status is the merge of every (non-ignored) descendant's,
		-- mirroring how 'snacks.explorer' marks a folder dirty.
		local prefix, merged = path .. "/", nil
		for _, r in ipairs(results) do
			if r.status:sub(1, 1) ~= "!" and r.file:sub(1, #prefix) == prefix then
				merged = merged ~= nil and merge_status(merged, r.status) or r.status
			end
		end
		return merged
	end

	---@param buf_id integer
	---@param results {status: string, file: string}[]
	local function render_git(buf_id, results)
		if not vim.api.nvim_buf_is_valid(buf_id) then
			return
		end
		vim.api.nvim_buf_clear_namespace(buf_id, ns_git, 0, -1)
		for _, item in ipairs(fs_items(buf_id)) do
			local entry = item.fs_entry
			local xy = entry_status(entry.path, entry.fs_type == "directory", results)
			local hl = nil
			if xy ~= nil then
				local status = git_status(xy)
				hl = status_hl(status)
				set_extmark(buf_id, ns_git, item.lnum - 1, 0, {
					virt_text = { { status_icon(status), hl } },
					virt_text_pos = "eol_right_align",
				})
			elseif vim.startswith(entry.name, ".") then
				-- Dotfile with no git status of its own: dim like a hidden path.
				hl = "NonText"
			end
			if hl ~= nil then
				local name_col = item.line:find(entry.name, 1, true)
				if name_col ~= nil then
					set_extmark(buf_id, ns_git, item.lnum - 1, name_col - 1, {
						end_col = name_col - 1 + #entry.name,
						hl_group = hl,
					})
				end
			end
		end
	end

	---@param buf_id integer
	---@return string|nil root
	local function buffer_git_root(buf_id)
		local name = vim.api.nvim_buf_get_name(buf_id)
		local dir = name:match("^minifiles://%d+/(.*)$")
		if dir == nil then
			return nil
		end
		return vim.fs.root(vim.fs.normalize(dir), ".git")
	end

	local function refresh_git(buf_id)
		local root = buffer_git_root(buf_id)
		if root == nil then
			vim.api.nvim_buf_clear_namespace(buf_id, ns_git, 0, -1)
			return
		end
		git_get(root, function(results)
			render_git(buf_id, results)
		end)
	end

	local function minifiles_buffers()
		local bufs = {}
		for _, buf_id in ipairs(vim.api.nvim_list_bufs()) do
			if vim.api.nvim_buf_is_loaded(buf_id) and vim.api.nvim_buf_get_name(buf_id):match("^minifiles://") then
				table.insert(bufs, buf_id)
			end
		end
		return bufs
	end

	-- Diagnostics -----------------------------------------------------------
	--
	-- Worst severity of each open file is rolled up to its parent directories,
	-- same as 'snacks.explorer's 'lua/snacks/explorer/diagnostics.lua'.

	-- stylua: ignore
	local DIAG_ICON = { Error = " ", Warn = " ", Hint = " ", Info = " " }

	---@param severity integer
	local function severity_name(severity)
		local name = vim.diagnostic.severity[severity]
		return name:sub(1, 1) .. name:sub(2):lower()
	end

	local function diagnostic_severities()
		local by_path = {}
		for _, diag in ipairs(vim.diagnostic.get()) do
			local name = vim.api.nvim_buf_get_name(diag.bufnr)
			if name ~= "" then
				name = vim.fs.normalize(name)
				by_path[name] = math.min(by_path[name] or math.huge, diag.severity)
				for dir in vim.fs.parents(name) do
					by_path[dir] = math.min(by_path[dir] or math.huge, diag.severity)
				end
			end
		end
		return by_path
	end

	local function render_diag(buf_id)
		if not vim.api.nvim_buf_is_valid(buf_id) then
			return
		end
		vim.api.nvim_buf_clear_namespace(buf_id, ns_diag, 0, -1)
		local by_path = diagnostic_severities()
		for _, item in ipairs(fs_items(buf_id)) do
			local severity = by_path[vim.fs.normalize(item.fs_entry.path)]
			if severity ~= nil then
				local cap = severity_name(severity)
				set_extmark(buf_id, ns_diag, item.lnum - 1, 0, {
					virt_text = { { DIAG_ICON[cap] or "", "Diagnostic" .. cap } },
					virt_text_pos = "eol_right_align",
				})
			end
		end
	end

	-- Symlinks ----------------------------------------------------------------
	--
	-- Shown as `-> target`, same as 'snacks.explorer's filename formatter.

	local function render_symlinks(buf_id)
		if not vim.api.nvim_buf_is_valid(buf_id) then
			return
		end
		vim.api.nvim_buf_clear_namespace(buf_id, ns_sym, 0, -1)
		for _, item in ipairs(fs_items(buf_id)) do
			local target = vim.uv.fs_readlink(item.fs_entry.path)
			if target ~= nil then
				local broken = vim.uv.fs_stat(item.fs_entry.path) == nil
				set_extmark(buf_id, ns_sym, item.lnum - 1, 0, {
					virt_text = {
						{ " -> ", "NonText" },
						{ vim.fn.pathshorten(target), broken and "ErrorMsg" or "NonText" },
					},
					virt_text_pos = "eol",
				})
			end
		end
	end

	-- Wiring --------------------------------------------------------------------

	Config.new_autocmd("User", "MiniFilesBufferUpdate", function(args)
		refresh_git(args.data.buf_id)
		render_diag(args.data.buf_id)
		render_symlinks(args.data.buf_id)
	end, "Render mini.files git/diagnostic/symlink status")

	Config.new_autocmd("DiagnosticChanged", nil, function()
		for _, buf_id in ipairs(minifiles_buffers()) do
			render_diag(buf_id)
		end
	end, "Refresh mini.files diagnostic status")

	-- 'mini.git' (see 'plugin/30_mini.lua') triggers this after `git` state
	-- changes (stage, commit, checkout, ...) for the buffer it ran in, which
	-- lets the explorer drop its cache instead of waiting out the TTL.
	Config.new_autocmd("User", "MiniGitUpdated", function(args)
		local root = (MiniGit.get_buf_data(args.buf) or {}).root
		if root == nil then
			return
		end
		git_cache[root] = nil
		for _, buf_id in ipairs(minifiles_buffers()) do
			if buffer_git_root(buf_id) == root then
				refresh_git(buf_id)
			end
		end
	end, "Invalidate mini.files git status cache on mini.git update")

	Config.new_autocmd("User", "MiniFilesExplorerClose", function()
		git_cache = {}
	end, "Clear mini.files git status cache")
end)
