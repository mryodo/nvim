-- ┌──────────────────┐
-- │ fzf-lua as picker │
-- └──────────────────┘
--
-- Loaded in `later()`, so these `<Leader>f` mappings override the 'mini.pick'
-- ones from 'plugin/33_pick.lua'. `fA`/`fM`/`fV` are intentionally left to
-- 'mini.pick': 'fzf-lua' has no per-buffer hunk or visit-path source.

local add = vim.pack.add
local later = Config.later

later(function()
	add({ "https://github.com/ibhagwan/fzf-lua" })
	local actions = require("fzf-lua.actions")

	local opts = {
		winopts = {
			backdrop = 60,

			-- Full-width panel docked to the bottom of the screen
			height = 0.45,
			width = 1,
			row = 1,
			zindex = 100,
			preview = {
				title_pos = "left",
				scrollbar = false,
				layout = "horizontal",
				horizontal = "right:50%",
				winopts = {},
			},
		},
		actions = {
			-- Pickers inheriting these actions:
			--   files, git_files, git_status, grep, lsp, oldfiles, quickfix, loclist,
			--   tags, btags, args, buffers, tabs, lines, blines
			files = { true },
		},
		-- Colours come from the theme's highlights, with the tint set below
		fzf_colors = { true, gutter = { "bg", "FzfLuaNormal" } },
		fzf_opts = {
			["--layout"] = "reverse",
			["--separator"] = "‾",
		},
		defaults = {
			winopts = {
				title_pos = "left",
				preview = {
					winopts = {},
				},
			},
			cwd_prompt = false,
			prompt = "   ",
			header = false,
		},
		files = {
			winopts = {
				title = " Files ",
			},
			prompt = "   ",
			formatter = "path.dirname_first",
			no_ignore = true,
			previewer = "builtin",
		},
		buffers = {
			winopts = {
				title = " Switcher ",
				preview = {
					hidden = true,
				},
			},
			prompt = "  ",
		},
		grep = {
			winopts = {
				title = " Find in Files ",
			},
			prompt = "   ",
			previewer = "builtin",
			formatter = "path.dirname_first",
			RIPGREP_CONFIG_PATH = vim.env.RIPGREP_CONFIG_PATH,
			no_ignore = true,
			hidden = true,
		},
		lsp = {
			symbols = {
				symbol_hl = function(s)
					-- `JBIcon<Kind>` generated in jb.nvim colorscheme
					return "JBIcon" .. s:lower()
				end,
			},
		},
		previewers = {
			builtin = {
				title_fnamemodify = function(s)
					-- Get absolute path of parent directory
					local absParentPath = vim.fn.fnamemodify(s, ":h")
					-- Convert absolute path to path relative to cwd
					local relParentPath = vim.fn.fnamemodify(absParentPath, ":~:.")

					local path = require("fzf-lua.path")
					local name = path.tail(s)

					-- Handle case when file is outside of cwd
					if relParentPath:find("^%./") then
						relParentPath = relParentPath:sub(3) -- Remove leading ./
					end

					-- Return filename with relative parent path
					return name .. " - " .. relParentPath
				end,
			},
		},
	}
	-- adds ability to delete buffers in Switcher
	opts.buffers.actions = opts.buffers.actions or {}
	opts.buffers.actions["alt-backspace"] = { fn = actions.buf_del, reload = true }


	-- Padding in the float tint, no drawn lines, matching 'winborder'
	-- ('plugin/10_options.lua')
	opts.winopts.border = "solid"
	opts.winopts.preview.border = Config.float_border_after -- Rule between results and preview

	opts.lsp.symbols.symbol_icons = Config.kind_icons

	require("fzf-lua").setup(opts)

	-- The shared float surface ('plugin/90_theme_compat.lua'), plus a fixed
	-- black backdrop: the theme's one is cleared under Ghostty
	local set_fzf_highlights = function()
		-- stylua: ignore
		local links = {
			FzfLuaNormal        = "NormalFloat",     FzfLuaBorder        = "FloatBorder",
			FzfLuaTitle         = "FloatTitle",      FzfLuaCursorLine    = "FloatCursorLine",
			FzfLuaPreviewNormal = "NormalFloat",     FzfLuaPreviewBorder = "FloatBorder",
			FzfLuaPreviewTitle  = "FloatTitle",
		}
		for group, target in pairs(links) do
			vim.api.nvim_set_hl(0, group, { link = target })
		end
		vim.api.nvim_set_hl(0, "FzfLuaBackdrop", { bg = "#000000" })
	end
	set_fzf_highlights()
	Config.new_autocmd("ColorScheme", nil, set_fzf_highlights, "Style fzf picker")

	local nmap_leader = function(suffix, rhs, desc)
		vim.keymap.set("n", "<Leader>" .. suffix, rhs, { desc = desc })
	end
	nmap_leader("f/", "<Cmd>FzfLua history <CR>", '"/" history')
	nmap_leader("f:", "<Cmd>FzfLua command_history <CR>", '":" history')
	nmap_leader("fa", '<Cmd>FzfLua git_hunks "staged"<CR>', "Added hunks (all)")
	nmap_leader("fb", "<Cmd>FzfLua buffers<CR>", "Buffers")
	nmap_leader("fc", "<Cmd>FzfLua git_commits<CR>", "Commits (all)")
	nmap_leader("fC", "<Cmd>FzfLua colorschemes <CR>", "Colorschemes")
	nmap_leader("fd", "<Cmd>FzfLua diagnostics_workspace<CR>", "Diagnostic workspace")
	nmap_leader("fD", "<Cmd>FzfLua diagnostics_document<CR>", "Diagnostic buffer")
	nmap_leader("ff", "<Cmd>FzfLua files<CR>", "Files")
	nmap_leader("<Space>", "<Cmd>FzfLua files<CR>", "Files")
	nmap_leader("fg", "<Cmd>FzfLua live_grep<CR>", "Grep live")
	nmap_leader("fG", "<Cmd>FzfLua grep_cword<CR>", "Grep current word")
	nmap_leader("fh", "<Cmd>FzfLua help<CR>", "Help tags")
	nmap_leader("fH", "<Cmd>FzfLua highlights<CR>", "Highlight groups")
	nmap_leader("fl", "<Cmd>FzfLua lines<CR>", "Lines (all)")
	nmap_leader("fL", "<Cmd>FzfLua blines<CR>", "Lines (buf)")
	nmap_leader("fm", "<Cmd>FzfLua git_hunks<CR>", "Modified hunks (all)")
	nmap_leader("fq", "<Cmd>FzfLua quickfix<CR>", "Quickfix")
	nmap_leader("fr", "<Cmd>FzfLua resume<CR>", "Resume")
	nmap_leader("fR", "<Cmd>FzfLua lsp_references<CR>", "References (LSP)")
	nmap_leader("fs", "<Cmd>FzfLua lsp_live_workspace_symbols<CR>", "Symbols workspace (live)")
	nmap_leader("fS", "<Cmd>FzfLua lsp_document_symbols<CR>", "Symbols document")
	nmap_leader("ft", "<Cmd>TodoFzfLua<CR>", "Todo (directory)")
	nmap_leader("fv", "<Cmd>FzfLua oldfiles<CR>", "Recent files")
end)
