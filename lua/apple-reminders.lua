local M = {}

local APPLESCRIPT = [[
on run argv
    set reminderTitle to item 1 of argv
    set reminderBody to item 2 of argv
    set listName to item 3 of argv

    tell application "Reminders"
        if listName is "" then
            set targetList to default list
        else
            set targetList to list listName
        end if

        tell targetList
            make new reminder with properties ¬
                {name:reminderTitle, body:reminderBody}
        end tell
    end tell
end run
]]

local function notify(msg, level)
	vim.notify(msg, level or vim.log.levels.INFO, {
		title = "Apple Reminders",
	})
end

local function get_visual_selection()
	local start_pos = vim.fn.getpos("'<")
	local end_pos = vim.fn.getpos("'>")

	local start_line = start_pos[2]
	local end_line = end_pos[2]
	local start_col = start_pos[3]
	local end_col = end_pos[3]

	if start_line == 0 or end_line == 0 then
		return nil
	end

	local lines = vim.fn.getline(start_line, end_line)

	if #lines == 0 then
		return nil
	end

	-- Visual line mode
	if vim.fn.visualmode() == "V" then
		return table.concat(lines, "\n")
	end

	-- Character-wise selection
	if vim.fn.visualmode() == "v" then
		lines[1] = string.sub(lines[1], start_col)
		lines[#lines] = string.sub(lines[#lines], 1, end_col - start_col + 1)

		if #lines == 1 then
			lines[1] = string.sub(vim.fn.getline(start_line), start_col, end_col)
		end

		return table.concat(lines, "\n")
	end

	-- Block-wise selection
	if vim.fn.visualmode() == "\22" then
		local result = {}

		for _, line in ipairs(lines) do
			table.insert(result, string.sub(line, start_col, end_col))
		end

		return table.concat(result, "\n")
	end

	return table.concat(lines, "\n")
end

local function clean_text(text)
	-- Remove leading/trailing whitespace.
	text = text:gsub("^%s+", "")
	text = text:gsub("%s+$", "")

	return text
end

local function get_context()
	local file = vim.fn.expand("%:p")
	local line = vim.fn.line(".")

	if file == "" then
		return string.format("Neovim — line %d", line)
	end

	return string.format("Neovim — %s:%d", file, line)
end

local function choose_list(callback)
	vim.ui.input({
		prompt = "Reminders list (empty = default): ",
	}, function(list)
		if list == nil then
			return
		end

		callback(list)
	end)
end

function M.create(text, opts)
	opts = opts or {}

	text = clean_text(text or "")

	if text == "" then
		notify("No text selected", vim.log.levels.WARN)
		return
	end

	-- First line becomes the reminder title.
	local lines = vim.split(text, "\n", {
		plain = true,
	})

	local title = clean_text(lines[1])

	-- Keep the full selection as the body when it contains
	-- more than just the title.
	local body = opts.body or text

	local context = get_context()

	if body == title then
		body = context
	else
		body = body .. "\n\n" .. context
	end

	choose_list(function(list)
		notify("Creating reminder…")

		vim.system({
			"osascript",
			"-e",
			APPLESCRIPT,
			title,
			body,
			list,
		}, {
			text = true,
		}, function(result)
			vim.schedule(function()
				if result.code == 0 then
					notify("Created: " .. title)
				else
					notify(
						"Failed to create reminder:\n" .. (result.stderr or result.stdout or "unknown error"),
						vim.log.levels.ERROR
					)
				end
			end)
		end)
	end)
end

function M.from_visual()
	local text = get_visual_selection()

	if not text then
		notify("Could not get visual selection", vim.log.levels.ERROR)
		return
	end

	M.create(text)
end

function M.from_todo()
	local line = vim.api.nvim_get_current_line()

	-- Matches things such as:
	--
	-- TODO: fix this
	-- FIXME: something is broken
	-- // TODO do something
	-- # HACK: temporary solution
	--
	local todo, description = line:match("%f[%w](TODO|FIXME|HACK|WARN|PERF|NOTE|TEST)%f[%W]%s*:?%s*(.*)")

	if not todo then
		notify("Current line doesn't contain a TODO comment", vim.log.levels.WARN)
		return
	end

	if description == "" then
		description = todo
	end

	M.create(description, {
		body = line,
	})
end

function M.setup()
	-- Visual selection → Apple Reminder
	vim.keymap.set("v", "<leader>tr", M.from_visual, {
		desc = "Create Apple Reminder from selection",
	})

	-- Current TODO line → Apple Reminder
	vim.keymap.set("n", "<leader>tr", M.from_todo, {
		desc = "Create Apple Reminder from TODO",
	})

	vim.api.nvim_create_user_command("AppleReminder", function(opts)
		if opts.range > 0 then
			local lines = vim.fn.getline(opts.line1, opts.line2)

			M.create(table.concat(lines, "\n"))
		else
			M.from_todo()
		end
	end, {
		range = true,
		desc = "Create an Apple Reminder",
	})
end

return M
