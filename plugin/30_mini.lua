local now, now_if_args, later = Config.now, Config.now_if_args, Config.later

-- Colorscheme is set in 'plugin/93_ui.lua'; 'mini.hues'-based schemes
-- live in 'colors/' and can be picked with `:colorscheme` / `<Leader>fC`.

now(function()
	require("mini.basics").setup({
		options = { basic = true },
		mappings = {
			-- [''] = { b = 'e' },
			windows = true,
			move_with_alt = true,
		},
		autocommands = { basic = false },
	})

	-- Must come after `mini.basics`: it appends window-border pieces to
	-- 'fillchars' unconditionally, so this is the last word on the option.
	vim.o.fillchars = "eob: ,diff:━"
	-- `\l` (toggle 'list') shadows typst's `\ll`/`\lp`/`\lw`/`\lh` after 'timeoutlen'.
	vim.keymap.del("n", "\\l")
end)

now(function()
	local ext3_blocklist = { scm = true, txt = true, yml = true }
	local ext4_blocklist = { json = true, yaml = true }
	require("mini.icons").setup({
		use_file_extension = function(ext, _)
			return not (ext3_blocklist[ext:sub(-3)] or ext4_blocklist[ext:sub(-4)])
		end,
	})
	-- Right away, not in `later()`: 'bufferline.nvim' draws its first frame with
	-- whatever `require("nvim-web-devicons")` returns.
	MiniIcons.mock_nvim_web_devicons()
	later(MiniIcons.tweak_lsp_kind)
end)


now(function()
	require("mini.sessions").setup()
end)

now(function()
	require("mini.starter").setup()
end)

now_if_args(function()
	require("mini.misc").setup()
	MiniMisc.setup_auto_root()
	MiniMisc.setup_restore_cursor()
	MiniMisc.setup_termbg_sync()
end)

later(function()
	require("mini.extra").setup()
end)

later(function()
	local ai = require("mini.ai")
	ai.setup({
		custom_textobjects = {
			B = MiniExtra.gen_ai_spec.buffer(),
			F = ai.gen_spec.treesitter({ a = "@function.outer", i = "@function.inner" }),
		},
		search_method = "cover",
	})
end)

later(function()
	require("mini.align").setup()
end)

later(function()
	require("mini.bracketed").setup()
end)

later(function()
	require("mini.bufremove").setup()
end)



later(function()
	require("mini.comment").setup()
end)


later(function()
	require("mini.git").setup()
end)


later(function()
	require("mini.keymap").setup()
	-- These only back up the *built-in* popup menu: 'blink.cmp'
	-- ('plugin/94_completion.lua') takes these keys first and only falls
	-- through to here when its own menu is closed. `<CR>`/`<BS>` are left
	-- alone because 'nvim-autopairs' owns them (see 'plugin/32_autopairs.lua').
	--
	-- `minisnippets_expand` is the expand key for 'mini.snippets', which is why
	-- its own `mappings.expand` is left empty in 'plugin/94_completion.lua'. It
	-- only fires when a prefix actually matches at the cursor, so <Tab> still
	-- indents everywhere else. This is the only way to reach prefixes made of
	-- punctuation -- `@(`, `@[`, `@/`, `@^` and the rest of
	-- 'after/snippets/latex.json' -- because `(` and `[` are not keyword
	-- characters and so never make it into a 'blink.cmp' completion keyword.
	--
	-- `minisnippets_next` comes first so that inside an active session <Tab>
	-- walks the tabstops, which is what `\left( $1 \right)` and friends want
	-- straight after expanding. <C-l> still jumps forward and <C-j> back.
	MiniKeymap.map_multistep("i", "<Tab>", { "minisnippets_next", "minisnippets_expand", "pmenu_next" })
	MiniKeymap.map_multistep("i", "<S-Tab>", { "pmenu_prev" })
end)

later(function()
	require("mini.move").setup()
end)

later(function()
	require("mini.operators").setup()
	vim.keymap.set("n", "(", "gxiagxila", { remap = true, desc = "Swap arg left" })
	vim.keymap.set("n", ")", "gxiagxina", { remap = true, desc = "Swap arg right" })
end)

later(function()
	-- Command line only. 'nvim-autopairs' ('plugin/32_autopairs.lua') owns Insert
	-- mode -- it is the only one of the two that can express `\(` `\)` -- but it
	-- never maps the command line, which this was enabled for.
	require("mini.pairs").setup({
		modes = { insert = false, command = true, terminal = false },
	})
end)

later(function()
	require("mini.splitjoin").setup()
end)

later(function()
	require("mini.surround").setup({
		custom_surroundings = {
			m = {
				input = { "\\%(().-()\\%)" },
				output = { left = "\\(", right = "\\)" },
			},
			e = {
				-- ponytail: `.-` stops at the first `\end`, so nested envs of the same depth confuse it
				input = { "\\begin%b{}%s*().-()%s*\\end%b{}" },
				output = function()
					local env = MiniInput.get({ prompt = "Environment: ", scope = "cursor" })
					if env == nil or env == "" then
						return nil
					end
					return {
						left = "\\begin{" .. env .. "}\n",
						right = "\n\\end{" .. env .. "}",
					}
				end,
			},
			f = {
				input = { "\\%a+%b{}", "^\\%a+{().*()}$" },
				output = function()
					local fn = MiniInput.get({ prompt = "Command: ", scope = "cursor" })
					if fn == nil or fn == "" then
						return nil
					end
					return { left = "\\" .. fn .. "{", right = "}" }
				end,
			},
		},
	})
end)

later(function()
	require("mini.trailspace").setup()
end)

later(function()
	require("mini.visits").setup()
end)
later(function()
	require("mini.input").setup()
end)
