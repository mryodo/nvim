-- ┌──────────────────────────────┐
-- │ Git integration and scrollbar │
-- └──────────────────────────────┘
--
-- 'mini.diff' and 'mini.git' are also available: 'mini.git' powers the
-- `<Leader>g*` mappings in 'plugin/20_keymaps.lua', while in-buffer signs,
-- blame and hunk actions come from 'gitsigns.nvim' below.

local add = vim.pack.add
local later = Config.later

-- Deferred: nothing here paints the first frame. 'diffview.nvim' in particular
-- pulls in its own render stack, and 'gitsigns.nvim' has to shell out to `git`
-- before it can draw a single sign, so running this on the first event-loop
-- tick instead of during startup costs nothing and is never noticeable.
later(function()
	add({ "https://github.com/sindrets/diffview.nvim" })
	require("diffview").setup({
		enhanced_diff_hl = true,
		show_help_hints = false,
		icons = { -- Only applies when use_icons is true.
			folder_closed = "",
			folder_open = "",
		},
	})

	add({ "https://github.com/kevinhwang91/nvim-hlslens" })
	require("hlslens").setup()

	add({ "https://github.com/lewis6991/gitsigns.nvim" })
	require("gitsigns").setup({
		signs = {
			add = { text = "▐ " },
			change = { text = "▐ " },
			delete = { text = "▁" },
			topdelete = { text = "▔" },
			changedelete = { text = "▐" },
			untracked = { text = "▐" },
		},
		signs_staged = {
			add = { text = "║" },
			change = { text = "║" },
			delete = { text = "‗" },
			topdelete = { text = "═" },
			changedelete = { text = "≈" },
			untracked = { text = "┆" },
		},
		culhl = true,
		diff_opts = {
			internal = true,
		},
		attach_to_untracked = true,
		current_line_blame = true, -- Toggle with `:Gitsigns toggle_current_line_blame`

		current_line_blame_opts = {
			virt_text = true,
			virt_text_pos = "eol", -- 'eol' | 'overlay' | 'right_align'
			delay = 400,
			ignore_whitespace = false,
			virt_text_priority = 100,
			use_focus = true,
		},
		current_line_blame_formatter = "<author>, <author_time:%m/%d/%y>, <author_time:%I:%M %p> · <summary>",
		preview_config = {
			-- Options passed to nvim_open_win
			border = "single",
			style = "minimal",
			relative = "cursor",
			row = 0,
			col = 1,
		},
		-- Hunk mappings are buffer-local, so they live with the plugin setup
		on_attach = function(bufnr)
			local gitsigns = require("gitsigns")

			-- Hunk Actions
			-- Previewing changes
			vim.keymap.set("n", "<localleader>hp", gitsigns.preview_hunk, {
				buffer = bufnr,
				desc = "VCS: [h]unk [p]review",
			})
			vim.keymap.set("n", "<localleader>hP", gitsigns.preview_hunk_inline, {
				buffer = bufnr,
				desc = "VCS: [h]unk [P]review inline",
			})
			-- Staging changes
			vim.keymap.set("n", "<localleader>hs", gitsigns.stage_hunk, {
				buffer = bufnr,
				desc = "VCS: [h]unk [s]tage",
			})
			vim.keymap.set("v", "<localleader>hs", function()
				gitsigns.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
			end, {
				buffer = bufnr,
				desc = "VCS: [h]unk [s]tage",
			})
			vim.keymap.set("n", "<localleader>hS", gitsigns.stage_buffer, {
				buffer = bufnr,
				desc = "VCS: [h]unk [S]tage buffer",
			})
			-- Resetting changes
			vim.keymap.set("n", "<localleader>hr", gitsigns.reset_hunk, {
				buffer = bufnr,
				desc = "VCS: [h]unk [r]eset",
			})
			vim.keymap.set("v", "<localleader>hr", function()
				gitsigns.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
			end, {
				buffer = bufnr,
				desc = "VCS: [h]unk [r]eset",
			})
			vim.keymap.set("n", "<localleader>hR", gitsigns.reset_buffer, {
				buffer = bufnr,
				desc = "VCS: [h]unk [R]eset buffer",
			})
			-- Diff between hunk and index
			vim.keymap.set("n", "<localleader>hd", gitsigns.diffthis, {
				buffer = bufnr,
				desc = "VCS: [h]unk [d]iff",
			})
			vim.keymap.set("n", "<localleader>hD", function()
				gitsigns.diffthis("~")
			end, {
				buffer = bufnr,
				desc = "VCS: [h]unk [D]iff against HEAD",
			})

			-- Navigation
			vim.keymap.set("n", "]c", function()
				if vim.wo.diff then
					vim.cmd.normal({ "]c", bang = true })
				else
					gitsigns.nav_hunk("next", { target = "all" })
				end
			end, {
				buffer = bufnr,
				desc = "VCS: [n]ext [c]hange hunk",
			})
			vim.keymap.set("n", "[c", function()
				if vim.wo.diff then
					vim.cmd.normal({ "[c", bang = true })
				else
					gitsigns.nav_hunk("prev", { target = "all" })
				end
			end, {
				buffer = bufnr,
				desc = "VCS: [p]revious [c]hange hunk",
			})
		end,
	})

	-- Diagnostics, git hunks and search results on the right edge.
	--
	-- 'satellite.nvim' draws into a floating window of its own rather than into
	-- the buffer, which is the whole reason it is here instead of
	-- 'nvim-scrollbar': that one placed `right_align` virtual text on *buffer*
	-- lines, so with 'wrap' set a mark landed on the last screen row of a
	-- wrapped line -- in the middle of the prose -- and the bar itself broke up
	-- into one mark per buffer line instead of running down the edge.
	--
	-- Its `under_caret` and `todo` handlers are not ported: both read from
	-- `vim.g.highlighted_lines` and `vim.g.todos_in_files`, which nothing in
	-- this config or any installed plugin ever writes, so both always returned
	-- an empty list.
	add({ "https://github.com/lewis6991/satellite.nvim" })
	require("satellite").setup({
		current_only = true,
		-- Any blend > 0 makes the text under the bar's blank cells show through,
		-- so the last columns of a line are no longer hidden behind it.
		winblend = 30,
		zindex = 21,
		excluded_filetypes = {
			"snacks_picker_list",
			"snacks_picker_input",
			"fzf",
			"netrw",
			"qf",
			"help",
		},
		handlers = {
			-- Refreshing on every `CursorMoved` is too slow to be worth it
			cursor = { enable = false },
			search = { enable = true },
			diagnostic = {
				enable = true,
				signs = { "┊", "┊", "┊" },
				min_severity = vim.diagnostic.severity.WARN,
			},
			gitsigns = {
				enable = true,
				signs = { add = "│", change = "│", delete = "│" },
			},
			marks = { enable = false, show_builtins = false },
			quickfix = { enable = false },
		},
	})
end)
