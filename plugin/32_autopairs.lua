-- ┌────────────────────────┐
-- │ Auto-pairs and auto-tags │
-- └────────────────────────┘
--
-- 'nvim-autopairs' is the single pair engine: it maps the bracket keys plus
-- `<CR>` and `<BS>`, and it is the only one of the two candidates that can
-- express multi-character LaTeX pairs such as `\(` `\)`. 'mini.pairs' is
-- deliberately not set up -- having both meant whichever loaded last silently
-- won every key.

local add = vim.pack.add
local later = Config.later

later(function()
	add({ "https://github.com/windwp/nvim-autopairs" })
	local npairs = require("nvim-autopairs")
	local Rule = require("nvim-autopairs.rule")
	local cond = require("nvim-autopairs.conds")

	npairs.setup()

	npairs.add_rules({
		-- Inline math. Typing the closing `$` steps over the one that was
		-- inserted for you instead of opening a second pair (which is what
		-- turned `$x$` into `$x$$$`). No pair after `\` so `\$` stays literal.
		Rule("$", "$", { "tex", "plaintex" })
			-- Step over the closing `$` instead of opening a second pair, which
			-- is what turned `$x$` into `$x$$$`. `cond.move_right()` cannot be
			-- used: it only recognises brackets and quotes, and returns false
			-- for every other character.
			:with_move(
				function(opts)
					return opts.next_char == opts.char
				end
			)
			:with_pair(cond.not_before_regex("\\", 1))
			:with_pair(cond.not_after_regex("%a"))
			:with_cr(cond.none()),

		-- The other two inline/display math delimiters
		Rule("\\(", "\\)", { "tex", "plaintex" }),
		Rule("\\[", "\\]", { "tex", "plaintex" }),
	})

	-- Don't pair a bracket typed straight after `@`. Every LaTeX snippet in
	-- 'after/snippets/latex.json' is prefixed with `@`, including `@(` and `@[`
	-- for `\left( ... \right)` and `\left[ ... \right]`. Auto-pairing turns
	-- those two into `@()` and `@[]` before <C-k> gets a chance to expand them,
	-- and `MiniSnippets.default_match()` only looks at the text *before* the
	-- cursor, so the snippet does expand -- leaving the orphaned `)` or `]`
	-- behind as `\left(  \right))`. The `@` prefix is never a real bracket
	-- context, so suppressing the pair there costs nothing.
	for _, open_char in ipairs({ "(", "[" }) do
		for _, rule in ipairs(npairs.get_rules(open_char)) do
			rule:with_pair(cond.not_before_regex("@", 1))
		end
	end

	add({ "https://github.com/windwp/nvim-ts-autotag" })
	require("nvim-ts-autotag").setup({
		opts = {
			enable_close = true, -- Auto close tags
			enable_rename = true, -- Auto rename pairs of tags
			enable_close_on_slash = false, -- Auto close on trailing </
		},
		-- Per-filetype overrides take priority over `opts` above
		per_filetype = {
			html = { enable_close = false },
		},
	})
end)
