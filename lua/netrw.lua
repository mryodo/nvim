-- local utils = require("ide.utils")
-- local spec = require("ide.spec.builder")

--- MODULE DEFINITION ----------------------------------------------------------

local M = {}
local I = {}

---@type string?
I.current_file = nil
I.project_view_winid = nil
I.project_view_winnr = nil

-- function M.later(fn, error_prefix)
-- 	table.insert(I.cache.queue, { fn = fn, error_prefix = "later: " .. (error_prefix and error_prefix or "") })
-- 	I.schedule()
-- end

function M.create_tool_window(
	title,
	position,
	close_on_leave,
	callback_before_entering,
	callaback_on_leave,
	callaback_on_close,
	bufnr
)
	position = position or "left"
	if close_on_leave == nil then
		close_on_leave = true
	end
	-- close_on_leave = close_on_leave ~= nil and close_on_leave or true
	local width = 45
	local col, border
	if position == "left" then
		col = 0
		border = require("jb.borders").borders.tool_window.left
	elseif position == "right" then
		col = vim.o.columns - width
		border = require("jb.borders").borders.tool_window.right
	else
		error("Position must be either 'left' or 'right'")
	end
	local opts = {
		relative = "editor",
		width = width,
		height = vim.o.lines - (vim.o.cmdheight + 3),
		row = 0,
		col = col,
		zindex = 100,
		style = "minimal",
		border = border,
		title = title,
		title_pos = "left",
		-- Provides empty full-width footer to use its underline as border
		footer = string.rep(" ", width),
	}
	bufnr = (bufnr and vim.api.nvim_buf_is_valid(bufnr)) and bufnr or vim.api.nvim_create_buf(false, true)
	local winid = vim.api.nvim_open_win(bufnr, false, opts)
	local winnr = vim.api.nvim_win_get_number(winid)
	local bufnrs = { [bufnr] = true }
	vim.api.nvim_set_option_value(
		"winhl",
		"FloatTitle:ToolWindowFloatTitle,"
			.. "FloatFooter:ToolWindowFloatFooter,"
			.. "NormalFloat:ToolWindowFloatNormal",
		{ win = winid }
	)
	local close_tool_window = function()
		-- Requires delay to ensure the window is left
		vim.schedule(function()
			if vim.api.nvim_win_is_valid(winid) then
				vim.api.nvim_win_close(winid, true)
			end
		end)
	end
	local leave_tool_window = function(e)
		if type(callaback_on_leave) == "function" then
			callaback_on_leave(e, winid, winnr, bufnr)
		end
		if close_on_leave then
			close_tool_window()
		end
	end
	local group = vim.api.nvim_create_augroup("kdtsk-tool-window-" .. winid, { clear = true })
	vim.api.nvim_create_autocmd({ "WinLeave" }, {
		group = group,
		nested = true,
		callback = function(e)
			local ebuf_curr_winid = vim.fn.bufwinid(e.buf)
			if ebuf_curr_winid == winid then
				leave_tool_window(e)
			end
		end,
	})
	vim.api.nvim_create_autocmd("VimResized", {
		group = group,
		callback = function(e)
			vim.api.nvim_win_set_height(winid, vim.o.lines - (vim.o.cmdheight + 3))
		end,
	})
	vim.api.nvim_create_autocmd("WinClosed", {
		pattern = tostring(winid),
		group = group,
		callback = function(e)
			bufnrs[e.buf] = true
			vim.api.nvim_del_augroup_by_id(group)
			for nr, _ in pairs(bufnrs) do
				vim.api.nvim_buf_delete(nr, { force = true })
			end
			if type(callaback_on_close) == "function" then
				callaback_on_close(e, winid, winnr, bufnr)
			end
		end,
	})
	vim.api.nvim_create_autocmd({ "WinEnter", "TermEnter" }, {
		group = group,
		nested = true,
		callback = function(e)
			local ebuf_curr_winid = vim.fn.bufwinid(e.buf)
			if ebuf_curr_winid == winid then
				bufnrs[e.buf] = true
				for _, lhs in ipairs({ "<Esc>", "q", "<A-Esc>" }) do
					vim.keymap.set("n", lhs, function()
						if close_on_leave or lhs == "q" then
							vim.api.nvim_win_close(winid, true)
						end
					end, { buffer = e.buf })
				end
			else
				-- Entering Terminal mode doesn't trigger WinLeave in previous window
				-- So it is tracked here to indicate WinLeave
				if e.event == "TermEnter" then
					leave_tool_window(e)
				end
			end
		end,
	})
	if type(callback_before_entering) == "function" then
		callback_before_entering(winid, winnr, bufnr)
	end

	vim.schedule(function()
		vim.fn.win_gotoid(winid)
	end)

	return bufnr, winid, winnr
end

function M.setup()
	-- Netrw Configs
	vim.g.netrw_keepdir = 1 -- To avoid changing cwd when navigating in netrw
	vim.g.netrw_banner = 0 -- remove the banner at the top
	vim.g.netrw_preview = 1
	vim.g.netrw_liststyle = 3 -- default directory view. Cycle with i
	vim.g.netrw_fastbrowse = 2 -- Use fast browsing
end

function M.toggle_vim_explorer_float()
	-- Configures a proper window to open a file in after selection
	local _, open_in_winid = I.get_win_with_normal_buffer(vim.api.nvim_get_current_buf())
	if open_in_winid ~= nil then
		vim.g.netrw_chgwin = vim.api.nvim_win_get_number(open_in_winid)
	end
	if I.project_view_winid ~= nil then
		-- Close Netrw window if it's open
		I.close_project_view()
	else
		-- Create floating window
		local _, winid, winnr = M.create_tool_window(
			"Project",
			"left",
			true,
			function(winid)
				I.current_file = vim.fn.expand("%:p")
				local filename = vim.fn.fnamemodify(I.current_file, ":t")
				if vim.fn.isdirectory(I.current_file) == 1 or filename == "" then
					vim.fn.win_execute(winid, "Explore")
				else
					require("run").later(function()
						-- vim.fn.win_execute(winid, "ExploreFind")
						I.explore_find()
					end)
				end
			end,
			nil,
			function()
				-- Clear Netrw variables on close
				I.project_view_winid = nil
				I.project_view_winnr = nil
			end
		)
		I.project_view_winid = winid
		I.project_view_winnr = winnr
		-- Adds custom CursorLine highlight group
		vim.api.nvim_set_option_value(
			"winhl",
			(vim.api.nvim_get_option_value("winhl", { win = winid }) or "")
				.. ",CursorLine:NetrwCursorLine"
				.. ",CursorLineNr:NetrwCursorLine"
				.. ",CursorLineSign:NetrwCursorLine",
			{ win = winid }
		)
	end
end

function I.explore_find()
	local current_file = I.current_file or vim.fn.expand("%:p")
	local filename = vim.fn.fnamemodify(current_file, ":t")
	local directory = vim.fn.fnamemodify(current_file, ":h")

	-- If no file is open or filename is empty, just open explorer without searching
	if filename == "" or current_file == "" then
		vim.cmd("Explore " .. (directory ~= "" and directory or "."))
	else
		vim.fn.setreg("/", filename) -- Set search register
		vim.cmd("Explore " .. directory)
		vim.cmd("normal n") -- Go to next search match
		vim.cmd("noh")
	end
	I.current_file = nil
end

---@param bufnr number
---@return boolean
function I.is_normal_buffer(bufnr)
	if vim.api.nvim_buf_is_valid(bufnr) then
		return vim.api.nvim_get_option_value("buftype", { buf = bufnr }) == "" and vim.fn.buflisted(bufnr) == 1
	end
	return false
end

---@param bufnr? number
---@return number?, number?
function I.get_win_with_normal_buffer(bufnr)
	if bufnr ~= nil and I.is_normal_buffer(bufnr) then
		return bufnr, vim.fn.bufwinid(bufnr)
	end
	-- local bufs = vim.fn.tabpagebuflist()
	local bufs = {}
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		bufs[vim.api.nvim_win_get_buf(win)] = win
		-- table.insert(bufs, vim.api.nvim_win_get_buf(win))
	end
	for buf, win in pairs(bufs) do
		if I.is_normal_buffer(buf) then
			return buf, win
		end
	end
	return nil, nil
end

function I.close_project_view()
	if I.project_view_winid ~= nil and vim.api.nvim_win_is_valid(I.project_view_winid) then
		vim.api.nvim_win_close(I.project_view_winid, true)
	end
	I.project_view_winid = nil
	I.project_view_winnr = nil
end

return M
