-- ┌────────────────────┐
-- │ LaTeX buffer setup │
-- └────────────────────┘
--
-- Highlighting here comes from VimTeX's syntax engine, not tree-sitter (see the
-- note in 'plugin/40_lsp.lua'). That is what makes the settings below work:
-- conceal, `vimtex#syntax#in_mathzone()`, the `` ` `` math imaps (`` `a `` ->
-- \alpha, inside math only) and the `i$` / `ie` text objects.
--
-- Window options are set through `vim.wo[0][0]`, which scopes them to this
-- buffer, so they are restored when another file is opened in the same window
-- instead of leaking 'conceallevel' into Lua and Julia buffers.

local wo = vim.wo[0][0]

-- Prose, not code ------------------------------------------------------------
-- 'spell' is genuinely useful in LaTeX and is off by default. `z=` suggests,
-- `zg` adds a word to the dictionary, `]s` / `[s` jump between misspellings.
-- wo.spell = true
wo.wrap = true
wo.linebreak = true

-- Don't hard-wrap: `badness` reflows on save with semantic line breaks.
vim.bo.textwidth = 0

-- Conceal --------------------------------------------------------------------
-- Level 2 renders `\alpha` as α. An empty 'concealcursor' means the line the
-- cursor is on is always shown raw, so you can still edit what you wrote.
-- Which groups are concealed is configured by `g:vimtex_syntax_conceal`
-- in 'plugin/60_vimtex.lua'.
wo.conceallevel = 0
wo.concealcursor = ""

-- Folding --------------------------------------------------------------------
-- VimTeX supplies 'foldexpr' (sections, environments, ...) but leaves
-- 'foldmethod' at manual because of `g:vimtex_fold_manual`, so ask for
-- expression folds explicitly and start with everything open.
wo.foldmethod = "expr"
wo.foldexpr = "vimtex#fold#level(v:lnum)"
wo.foldtext = "vimtex#fold#text()"
wo.foldlevel = 99

-- Inline images ---------------------------------------------------------------
-- `snacks.image` renders every `$...$` and `\[...\]` in the buffer as an image,
-- and inline and display math come out at inconsistent sizes. Setting the flag
-- it uses to track attachment makes it skip this buffer: `snacks` attaches from
-- a `vim.schedule()` on `FileType`, so this runs first and wins.
--
-- This turns off inline `\includegraphics` previews here too, which is the
-- price of keeping it filetype-precise -- Markdown math is found through an
-- *injected* `latex` tree, so overriding the `latex` images query would have
-- taken math preview out of Markdown as well.
--
-- `:lua Snacks.image.doc.hover()` still previews whatever is under the cursor.
vim.b.snacks_image_attached = true

-- Auto-pairs for `$`, `\(` and `\[` are in 'plugin/32_autopairs.lua'.

-- Close environments ----------------------------------------------------------
-- Leaving insert mode on a `\begin{env}` line adds `\end{env}` below it, unless
-- the environment is already closed further down (nesting is counted).
local group = vim.api.nvim_create_augroup("tex_close_env", { clear = false })
vim.api.nvim_clear_autocmds({ group = group, buffer = 0 })
vim.api.nvim_create_autocmd("InsertLeave", {
	group = group,
	buffer = 0,
	desc = "Close unmatched \\begin{env}",
	callback = function()
		local row = vim.api.nvim_win_get_cursor(0)[1]
		local indent, env = vim.api.nvim_get_current_line():match("^(%s*)\\begin(%b{})")
		if not env then return end
		local depth = 0
		for _, l in ipairs(vim.api.nvim_buf_get_lines(0, row - 1, -1, false)) do
			for kind in l:gmatch("\\(%a+)" .. vim.pesc(env)) do
				depth = depth + (kind == "begin" and 1 or kind == "end" and -1 or 0)
			end
			if depth <= 0 then return end
		end
		vim.api.nvim_buf_set_lines(0, row, row, false, { indent .. "\\end" .. env })
	end,
})
