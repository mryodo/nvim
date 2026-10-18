local add = vim.pack.add
local now_if_args, later = Config.now_if_args, Config.later

-- Registers the `mdx` filetype, so it must load before a file given as an argument.
now_if_args(function()
	add({ "https://github.com/davidmh/mdx.nvim" })
end)

later(function()
	add({
		"https://github.com/OXY2DEV/markview.nvim",
	})
	local presets = require("markview.presets")
	require("markview").setup({
		markdown_inline = {
			checkboxes = {
				enable = false,
			},
		},
		markdown = {

			headings = presets.headings.glow,
			block_quotes = presets.obsidian,
			tables = presets.none,

			list_items = {
				indent_size = 3,
				marker_minus = {
					add_padding = true,
					text = "▬", -- change to whatever bullet you like
					hl = "MarkviewListItemMinus",
				},
			},
		},
	})
	add({ { src = "https://github.com/mryodo/checkmate.nvim", version = "mryodo" } })
	require("checkmate").setup({
		metadata = {
			due = {
				key = "<leader>TD",
				style = { fg = "#7A7F96", bold = true },

				get_value = function()
					-- tomorrow's date (a very naive implementation)
					local t = os.date("*t")
					t.day = t.day + 1
					local tomorrow = os.time(t)
					return os.date("%m/%d/%y", tomorrow)
				end,
			},
			priority = {
				alias = "p",
			},
			p = {
				label = "priority",
				key = { "<leader>TP" },
				get_value = function()
					return "■"
				end,
				choices = function()
					return { "▼", "■", "▲" }
				end,
				style = function(context)
					local value = context.value:lower()

					if value == "▲" then
						return { fg = "#86cd82", bold = true }
					end
				end,
			},
		},
		todo_states = {
			unchecked = { marker = "○" },
			checked = { marker = "✔" },
			in_progress = {
				marker = "󰥔",
				markdown = "/",
				order = 3,
			},

			cancelled = {
				marker = "󰜺",
				markdown = "-",
				order = 4,
			},
		},
		archive = {
			heading = {
				level = 2,
				title = "󰃨 Archived",
			},

			parent_spacing = 1,
		},

		smart_toggle = {
			enabled = true,
			check_down = "direct_children",
			uncheck_down = "none",
			check_up = "direct_children",
			uncheck_up = "direct_children",
		},

		show_todo_count = true,
		todo_count_position = "eol",
		todo_count_recursive = true,

		todo_count_formatter = function(completed, total)
			if total > 0 then
				local percent = completed / total * 100
				local bar_length = 8
				local filled = math.floor(bar_length * percent / 100)
				local bar = string.rep("■", filled) .. string.rep("□", bar_length - filled)
				return ("%s [%d/%d]"):format(bar, completed, total)
			else
				return string.format("[%d/%d]", completed, total)
			end
		end,
	})

	vim.keymap.set("n", "<leader>Tp", function()
		require("checkmate").select_metadata_value({ key = "p" })
	end, { desc = "Cycle priority" })
	vim.keymap.set("n", "<leader>TG", "<Cmd>CheckMateIncompleteTodos<CR>", { desc = "Pick incomplete TODOs" })

	vim.api.nvim_create_user_command("CheckMateIncompleteTodos", function()
		local picker = require("checkmate.picker")
		local todos = require("checkmate").get_todos()
		local incomplete = vim.tbl_filter(function(todo)
			return todo.text:match("- ○") -- only unchecked
		end, todos)
		picker.pick(picker.map_items(incomplete, "text"), { method = "pick_todo" })
		return true
	end, { desc = "Pick incomplete checkmate TODOs" })

	vim.api.nvim_create_user_command("Sync", function()
		vim.fn.system("sh ~/scripts/simple.sh")
	end, { desc = "Run ~/scripts/simple.sh" })
end)
