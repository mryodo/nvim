local M = {}

local config = {
	kitty = "kitty",

	-- Must match kitty.conf:
	-- listen_on unix:/tmp/kitty
	listen_on = vim.env.KITTY_LISTEN_ON or vim.env.LISTEN_ON or "unix:/tmp/kitty",

	julia = { "julia", "--project=@." },

	location = "vsplit",
	open_wait_ms = 3000,
	open_wait_interval_ms = 100,
	cwd = function()
		return vim.fn.getcwd()
	end,

	title = "nvim-julia-slime-" .. vim.fn.getpid(),

	open_on_send = true,

	keymaps = {
		open = "<leader>jo",
		line = "<leader>jl",
		visual = "<leader>js",
		enclosing = "<leader>je",
		buffer = "<leader>jb",
		enter_normal = "<CR>",
		enter_visual = "<CR>",
	},

	enclosing = {
		include_module = false,

		hard_patterns = {
			"^function_definition$",
			"^short_function_definition$",
			"^macro_definition$",
			"^struct_definition$",
			"^mutable_struct_definition$",
			"^abstract_definition$",
			"^primitive_definition$",
		},

		module_patterns = {
			"^module_definition$",
			"^baremodule_definition$",
		},

		scope_patterns = {
			"^for_statement$",
			"^while_statement$",
			"^let_statement$",
			"^try_statement$",
			"^if_statement$",
			"^begin_statement$",
			"^quote_statement$",
			"^do_clause$",
		},
	},
}

local state = {
	opened = false,
	kitty_window = nil,
	listen_on = nil,
}

local function notify(msg, level)
	vim.notify("[julia-slime] " .. msg, level or vim.log.levels.INFO)
end

local function merge_config(defaults, opts)
	return vim.tbl_deep_extend("force", defaults, opts or {})
end

local function current_cwd()
	if type(config.cwd) == "function" then
		return config.cwd()
	end
	return config.cwd
end

local function system(cmd)
	local out = vim.fn.system(cmd)
	local code = vim.v.shell_error

	if code ~= 0 then
		notify("Command failed:\n" .. table.concat(cmd, " ") .. "\n\nOutput:\n" .. tostring(out), vim.log.levels.ERROR)
		return nil
	end

	return out
end

local function kitty_remote_cmd(args)
	local cmd = {
		config.kitty,
		"@",
	}

	if config.listen_on and config.listen_on ~= "" then
		table.insert(cmd, "--to")
		table.insert(cmd, config.listen_on)
	end

	vim.list_extend(cmd, args)

	return cmd
end

local function configure_vim_slime()
	if not state.kitty_window then
		notify("No Kitty window id known", vim.log.levels.ERROR)
		return
	end

	state.listen_on = config.listen_on

	local kitty_window = tostring(state.kitty_window)
	local listen_on = tostring(state.listen_on)

	-- Environment variables useful for goerz/vim-slime and debugging.
	vim.env.LISTEN_ON = listen_on
	vim.env.KITTY_LISTEN_ON = listen_on
	vim.env.KITTY_WINDOW = kitty_window
	vim.env.KITTY_WINDOW_ID = kitty_window

	vim.g.slime_target = "kitty"
	vim.g.slime_dont_ask_default = 1
	vim.g.slime_no_mappings = 1

	-- Keep this disabled for Julia unless you explicitly want to test it.
	vim.g.slime_bracketed_paste = 1

	-- Standard vim-slime Kitty config.
	-- Different vim-slime forks have used slightly different names,
	-- so we provide both canonical and convenience names.
	local slime_config = {
		socket_name = listen_on,
		window_id = kitty_window,

		-- Extra aliases; harmless if ignored.
		listen_on = listen_on,
		kitty_window = kitty_window,
		kitty_window_id = kitty_window,
	}

	vim.g.slime_default_config = slime_config

	-- Important: make config buffer-local so vim-slime does not ask.
	vim.b.slime_config = slime_config

	-- notify(
	--   "Configured vim-slime: LISTEN_ON="
	--   .. listen_on
	--   .. ", KITTY_WINDOW="
	--   .. kitty_window
	-- )
end

local function first_nonblank_col(line)
	local col = line:find("%S")
	if not col then
		return 0
	end
	return col - 1
end

local function move_cursor_to_line(lnum)
	local win = vim.api.nvim_get_current_win()
	local bufnr = vim.api.nvim_get_current_buf()

	vim.schedule(function()
		if not vim.api.nvim_win_is_valid(win) then
			return
		end

		if not vim.api.nvim_buf_is_valid(bufnr) then
			return
		end

		if vim.api.nvim_win_get_buf(win) ~= bufnr then
			return
		end

		local line_count = vim.api.nvim_buf_line_count(bufnr)

		if line_count == 0 then
			return
		end

		lnum = math.max(1, math.min(lnum, line_count))

		local line = vim.api.nvim_buf_get_lines(bufnr, lnum - 1, lnum, false)[1] or ""
		local col = first_nonblank_col(line)

		pcall(vim.api.nvim_win_set_cursor, win, { lnum, col })
	end)
end

local function next_line_after_node(node)
	local _, _, end_row, _ = node:range()

	-- Tree-sitter rows are 0-based.
	-- end_row is the row where the node ends.
	-- Therefore the next 1-based Vim line is end_row + 2.
	return end_row + 2
end

local function json_decode(str)
	if vim.json and vim.json.decode then
		return vim.json.decode(str)
	end

	return vim.fn.json_decode(str)
end

local function kitty_ls()
	local out = system(kitty_remote_cmd({ "ls" }))

	if not out then
		return nil
	end

	local ok, decoded = pcall(json_decode, out)

	if not ok then
		notify("Could not decode `kitty @ ls` JSON:\n" .. tostring(decoded), vim.log.levels.ERROR)
		return nil
	end

	return decoded
end

local function all_kitty_windows()
	local tree = kitty_ls()

	if not tree then
		return {}
	end

	local windows = {}

	for _, os_window in ipairs(tree) do
		for _, tab in ipairs(os_window.tabs or {}) do
			for _, win in ipairs(tab.windows or {}) do
				table.insert(windows, win)
			end
		end
	end

	return windows
end

local function kitty_window_ids()
	local ids = {}

	for _, win in ipairs(all_kitty_windows()) do
		if win.id then
			ids[tostring(win.id)] = true
		end
	end

	return ids
end

local function window_title(win)
	return tostring(win.title or win.window_title or win.override_title or "")
end

local function find_kitty_window_id(title, before_ids)
	local fallback_new_id = nil
	local fallback_title_match = nil

	for _, win in ipairs(all_kitty_windows()) do
		local id = win.id and tostring(win.id) or nil
		local title_current = window_title(win)

		if id then
			-- Best case: exact title match.
			if title_current == title then
				return id
			end

			-- Still okay: title contains our unique title.
			if title_current:find(title, 1, true) then
				fallback_title_match = fallback_title_match or id
			end

			-- Fallback: a window appeared after launch.
			if before_ids and not before_ids[id] then
				fallback_new_id = fallback_new_id or id
			end
		end
	end

	return fallback_title_match or fallback_new_id
end

function M.open()
	local before_ids = kitty_window_ids()

	local unique_title = config.title .. "-" .. tostring(os.time()) .. "-" .. tostring(math.random(100000, 999999))

	state.title = unique_title

	local args = {
		"launch",
		"--type",
		"window",
		"--location",
		config.location,
		"--cwd",
		current_cwd(),
		"--title",
		unique_title,
		"--keep-focus",
	}

	for _, a in ipairs(config.julia) do
		table.insert(args, a)
	end

	local out = system(kitty_remote_cmd(args))

	if not out then
		return
	end

	-- Some Kitty versions print the id even without --print-window-id.
	-- If not, we fall back to `kitty @ ls`.
	local id = tostring(out):match("^%s*(%d+)%s*$")

	if not id then
		local wait_ms = config.open_wait_ms or 3000
		local interval_ms = config.open_wait_interval_ms or 100

		vim.wait(wait_ms, function()
			id = find_kitty_window_id(unique_title, before_ids)
			return id ~= nil
		end, interval_ms)
	end

	if not id then
		notify(
			"Could not determine Kitty window id. "
				.. "Try running `kitty @ --to "
				.. tostring(config.listen_on)
				.. " ls` manually.",
			vim.log.levels.ERROR
		)
		return
	end

	state.kitty_window = tostring(id)
	state.opened = true

	configure_vim_slime()

	notify("Opened Julia in Kitty window " .. tostring(id))
end

local function ensure_open()
	if not state.opened and config.open_on_send then
		M.open()
	end

	if not state.opened then
		notify("Julia Kitty window is not open. Run :JuliaSlimeOpen first.", vim.log.levels.ERROR)
		return false
	end

	configure_vim_slime()

	return true
end

local function slime_send(text)
	if not text or text == "" then
		return
	end

	if not ensure_open() then
		return
	end

	if not text:match("\n$") then
		text = text .. "\n"
	end

	-- Make sure vim-slime runtime files are available.
	-- This is harmless if they are already loaded.
	pcall(vim.cmd, "runtime plugin/slime.vim")
	pcall(vim.cmd, "runtime autoload/slime.vim")

	-- Do NOT guard this with exists("*slime#send").
	-- slime#send is an autoload function; exists() can lie before loading.
	local ok, err = pcall(function()
		vim.fn["slime#send"](text)
	end)

	if not ok then
		notify(
			"Could not call vim-slime slime#send().\n\n"
				.. "Error:\n"
				.. tostring(err)
				.. "\n\n"
				.. "Runtime check:\n"
				.. "autoload/slime.vim = "
				.. tostring(vim.fn.globpath(vim.o.runtimepath, "autoload/slime.vim")),
			vim.log.levels.ERROR
		)
	end
end

function M.send(text)
	slime_send(text)
end

function M.send_line()
	local line = vim.api.nvim_get_current_line()
	slime_send(line)
end

function M.send_range(line1, line2)
	local lines = vim.api.nvim_buf_get_lines(0, line1 - 1, line2, false)
	slime_send(table.concat(lines, "\n"))
end

local function get_visual_selection()
	local bufnr = vim.api.nvim_get_current_buf()

	local start_pos = vim.fn.getpos("'<")
	local end_pos = vim.fn.getpos("'>")

	local start_line = start_pos[2]
	local start_col = start_pos[3]
	local end_line = end_pos[2]
	local end_col = end_pos[3]

	if start_line > end_line or start_line == end_line and start_col > end_col then
		start_line, end_line = end_line, start_line
		start_col, end_col = end_col, start_col
	end

	local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)

	if #lines == 0 then
		return ""
	end

	local mode = vim.fn.visualmode()

	-- Linewise visual mode.
	if mode == "V" then
		return table.concat(lines, "\n")
	end

	-- Blockwise visual mode.
	if mode == "\022" then
		local selected = {}

		for _, line in ipairs(lines) do
			table.insert(selected, string.sub(line, start_col, end_col))
		end

		return table.concat(selected, "\n")
	end

	-- Characterwise visual mode.
	if #lines == 1 then
		lines[1] = string.sub(lines[1], start_col, end_col)
	else
		lines[1] = string.sub(lines[1], start_col)
		lines[#lines] = string.sub(lines[#lines], 1, end_col)
	end

	return table.concat(lines, "\n")
end

function M.send_visual()
	local text = get_visual_selection()
	slime_send(text)
end

function M.send_buffer()
	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	slime_send(table.concat(lines, "\n"))
end

local function matches_any(node_type, patterns)
	for _, pattern in ipairs(patterns) do
		if node_type:match(pattern) then
			return true
		end
	end

	return false
end

local function get_ts_root(bufnr)
	local ok, parser = pcall(vim.treesitter.get_parser, bufnr, "julia")

	if not ok or not parser then
		return nil
	end

	local trees = parser:parse()

	if not trees or not trees[1] then
		return nil
	end

	return trees[1]:root()
end

local function get_node_at_cursor(bufnr)
	local root = get_ts_root(bufnr)

	if not root then
		return nil, nil
	end

	local cursor = vim.api.nvim_win_get_cursor(0)
	local row = cursor[1] - 1
	local col = cursor[2]

	local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""

	if line == "" then
		return nil, root
	end

	if col >= #line then
		col = math.max(#line - 1, 0)
	end

	local node = root:named_descendant_for_range(row, col, row, col + 1)

	return node, root
end

local function get_node_for_line_range(bufnr, line1, line2)
	local root = get_ts_root(bufnr)

	if not root then
		return nil, nil
	end

	local start_row = line1 - 1
	local end_row = line2 - 1

	local last_line = vim.api.nvim_buf_get_lines(bufnr, end_row, end_row + 1, false)[1] or ""
	local end_col = #last_line

	local node = root:named_descendant_for_range(start_row, 0, end_row, end_col)

	return node, root
end

local function node_text(bufnr, node)
	local sr, sc, er, ec = node:range()
	local lines = vim.api.nvim_buf_get_text(bufnr, sr, sc, er, ec, {})

	return table.concat(lines, "\n")
end

local function is_rootish_type(t)
	return t == "source_file" or t == "program" or t == "translation_unit"
end

local function find_nearest_matching_ancestor(node, root, patterns)
	local n = node

	while n and n ~= root do
		if matches_any(n:type(), patterns) then
			return n
		end

		n = n:parent()
	end

	return nil
end

local function find_outermost_matching_ancestor(node, root, patterns)
	local result = nil
	local n = node

	while n and n ~= root do
		if matches_any(n:type(), patterns) then
			result = n
		end

		n = n:parent()
	end

	return result
end

local function choose_enclosing_node(node, root)
	if not node then
		return nil
	end

	if config.enclosing.include_module then
		local module_node = find_nearest_matching_ancestor(node, root, config.enclosing.module_patterns)

		if module_node then
			return module_node
		end
	end

	-- Important behavior:
	-- If cursor is inside:
	--
	--   function f()
	--       for i in xs
	--           cursor_here
	--       end
	--   end
	--
	-- this returns the function, not the for-loop.
	local hard_node = find_nearest_matching_ancestor(node, root, config.enclosing.hard_patterns)

	if hard_node then
		return hard_node
	end

	-- Outside functions, choose the outermost surrounding control-flow block.
	local scope_node = find_outermost_matching_ancestor(node, root, config.enclosing.scope_patterns)

	if scope_node then
		return scope_node
	end

	-- Fallback: send the top-level expression/statement containing the cursor.
	local n = node

	while n and n ~= root do
		local p = n:parent()

		if not p then
			break
		end

		local pt = p:type()

		if p == root or is_rootish_type(pt) or pt == "block" then
			return n
		end

		n = p
	end

	return node
end

function M.enclosing_text_at_cursor()
	local bufnr = vim.api.nvim_get_current_buf()
	local node, root = get_node_at_cursor(bufnr)

	if not node or not root then
		return vim.api.nvim_get_current_line()
	end

	local target = choose_enclosing_node(node, root)

	if not target then
		return vim.api.nvim_get_current_line()
	end

	return node_text(bufnr, target)
end

function M.enclosing_text_for_range(line1, line2)
	local bufnr = vim.api.nvim_get_current_buf()
	local node, root = get_node_for_line_range(bufnr, line1, line2)

	if not node or not root then
		local lines = vim.api.nvim_buf_get_lines(bufnr, line1 - 1, line2, false)
		return table.concat(lines, "\n")
	end

	local target = choose_enclosing_node(node, root)

	if not target then
		local lines = vim.api.nvim_buf_get_lines(bufnr, line1 - 1, line2, false)
		return table.concat(lines, "\n")
	end

	return node_text(bufnr, target)
end

local function choose_executable_node(node, root)
	if not node then
		return nil
	end

	-- Optional module behavior.
	-- If include_module = true and cursor/range is inside a module,
	-- send the module.
	if config.enclosing.include_module then
		local module_node = find_nearest_matching_ancestor(node, root, config.enclosing.module_patterns)

		if module_node then
			return module_node
		end
	end

	-- Function-like / definition-like environments have priority.
	-- This means:
	--
	-- function f()
	--     for i in xs
	--         cursor_here
	--     end
	-- end
	--
	-- sends the whole function, not only the for loop.
	local hard_node = find_nearest_matching_ancestor(node, root, config.enclosing.hard_patterns)

	if hard_node then
		return hard_node
	end

	-- Outside functions, send the outermost surrounding executable block.
	local scope_node = find_outermost_matching_ancestor(node, root, config.enclosing.scope_patterns)

	if scope_node then
		return scope_node
	end

	-- No enclosing executable block found.
	return nil
end

function M.executable_chunk_at_cursor_or_line()
	local bufnr = vim.api.nvim_get_current_buf()
	local current_line_number = vim.fn.line(".")
	local node, root = get_node_at_cursor(bufnr)

	if node and root then
		local target = choose_executable_node(node, root)

		if target then
			return node_text(bufnr, target), next_line_after_node(target)
		end
	end

	-- Fallback: send current line and move to the next line.
	return vim.api.nvim_get_current_line(), current_line_number + 1
end

function M.executable_chunk_for_range_or_selection(line1, line2)
	local bufnr = vim.api.nvim_get_current_buf()
	local node, root = get_node_for_line_range(bufnr, line1, line2)

	if node and root then
		local target = choose_executable_node(node, root)

		if target then
			return node_text(bufnr, target), next_line_after_node(target)
		end
	end

	-- Fallback: send selected line range and move after the selection.
	local lines = vim.api.nvim_buf_get_lines(bufnr, line1 - 1, line2, false)
	return table.concat(lines, "\n"), line2 + 1
end

function M.send_executable_or_line()
	local text, next_line = M.executable_chunk_at_cursor_or_line()
	slime_send(text)
	move_cursor_to_line(next_line)
end

function M.send_executable_range(line1, line2)
	local text, next_line = M.executable_chunk_for_range_or_selection(line1, line2)
	slime_send(text)
	move_cursor_to_line(next_line)
end

function M.send_enclosing()
	local text = M.enclosing_text_at_cursor()
	slime_send(text)
end

function M.send_enclosing_range(line1, line2)
	local text = M.enclosing_text_for_range(line1, line2)
	slime_send(text)
end

function M.status()
	print(vim.inspect({
		opened = state.opened,
		listen_on = state.listen_on or config.listen_on,
		kitty_window = state.kitty_window,
		slime_target = vim.g.slime_target,
		slime_default_config = vim.g.slime_default_config,
		buffer_slime_config = vim.b.slime_config,
	}))
end

function M.setup(opts)
	config = merge_config(config, opts or {})

	vim.g.slime_target = "kitty"
	vim.g.slime_dont_ask_default = 1

	vim.api.nvim_create_user_command("JuliaSlimeOpen", function()
		M.open()
	end, {})

	vim.api.nvim_create_user_command("JuliaSlimeSendLine", function()
		M.send_line()
	end, {})

	vim.api.nvim_create_user_command("JuliaSlimeSendSelection", function(cmd_opts)
		M.send_range(cmd_opts.line1, cmd_opts.line2)
	end, {
		range = true,
	})

	vim.api.nvim_create_user_command("JuliaSlimeSendEnclosing", function(cmd_opts)
		if cmd_opts.range and cmd_opts.range > 0 then
			M.send_enclosing_range(cmd_opts.line1, cmd_opts.line2)
		else
			M.send_enclosing()
		end
	end, {
		range = true,
	})

	vim.api.nvim_create_user_command("JuliaSlimeSendBuffer", function()
		M.send_buffer()
	end, {})

	vim.api.nvim_create_user_command("JuliaSlimeStatus", function()
		M.status()
	end, {})

	vim.api.nvim_create_user_command("JuliaSlimeSendExecutable", function(cmd_opts)
		if cmd_opts.range and cmd_opts.range > 0 then
			M.send_executable_range(cmd_opts.line1, cmd_opts.line2)
		else
			M.send_executable_or_line()
		end
	end, {
		range = true,
	})

	if config.keymaps then
		local km = config.keymaps

		if vim.bo.filetype == "julia" then
			if km.open then
				vim.keymap.set("n", km.open, M.open, {
					desc = "Open Julia in Kitty and configure vim-slime",
				})
			end

			if km.line then
				vim.keymap.set("n", km.line, M.send_line, {
					desc = "Send current line to Julia via vim-slime",
				})
			end

			if km.visual then
				vim.keymap.set("x", km.visual, function()
					M.send_visual()
				end, {
					desc = "Send visual selection to Julia via vim-slime",
				})
			end

			if km.enclosing then
				vim.keymap.set("n", km.enclosing, M.send_enclosing, {
					desc = "Send enclosing Julia block/function via vim-slime",
				})

				vim.keymap.set("x", km.enclosing, function()
					local start_line = vim.fn.line("'<")
					local end_line = vim.fn.line("'>")
					M.send_enclosing_range(start_line, end_line)
				end, {
					desc = "Send enclosing Julia block/function around selection via vim-slime",
				})
			end

			if km.buffer then
				vim.keymap.set("n", km.buffer, M.send_buffer, {
					desc = "Send whole buffer to Julia via vim-slime",
				})
			end

			if km.enter_normal then
				vim.keymap.set("n", km.enter_normal, M.send_executable_or_line, {
					desc = "Send enclosing Julia executable block or current line",
					silent = true,
				})
			end

			if km.enter_visual then
				vim.keymap.set("x", km.enter_visual, function()
					local start_line = vim.fn.getpos("v")[2]
					local end_line = vim.fn.getpos(".")[2]

					if start_line > end_line then
						start_line, end_line = end_line, start_line
					end

					M.send_executable_range(start_line, end_line)
				end, {
					desc = "Send enclosing Julia executable block for visual range",
					silent = true,
				})
			end
		end
	end
end

return M
