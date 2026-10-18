-- ┌────────────────────────────┐
-- │ TODO comments and patterns │
-- └────────────────────────────┘

local add = vim.pack.add
local later = Config.later

-- Highlight TODO/FIXME/... comments. `<Leader>ft` picks them with 'fzf-lua'
-- (`:TodoFzfLua`); `:Pick todo` below is the 'mini.pick' equivalent.
later(function()
	add({
		"https://github.com/nvim-lua/plenary.nvim",
		"https://github.com/folke/todo-comments.nvim",
	})
	require("todo-comments").setup()

	-- `:Pick todo` needs 'mini.pick', which is currently disabled in
	-- 'plugin/33_pick.lua'. Everything below is a no-op until it is enabled;
	-- '<Leader>ft' (`:TodoFzfLua`) is the picker that is actually used.
	if MiniPick == nil then
		return
	end

	local ns = vim.api.nvim_create_namespace("pick-todo")

	local show_todo = function(buf_id, entries, query, opts)
		MiniPick.default_show(buf_id, entries, query, opts)
		for line, entry in ipairs(entries) do
			for _, hl in ipairs(entry.hl) do
				vim.hl.range(buf_id, ns, hl[2], { line - 1, hl[1][1] }, { line - 1, hl[1][2] })
			end
		end
	end

	MiniPick.registry.todo = function()
		require("todo-comments.search").search(function(results)
			local TodoConfig = require("todo-comments.config")
			local Highlight = require("todo-comments.highlight")

			for i, entry in ipairs(results) do
				-- 'mini.pick' opens the `path` item, `filename` means something else
				entry.path, entry.filename = entry.filename, nil

				local relative_path = string.gsub(entry.path, vim.fn.getcwd() .. "/", "")
				local display = string.format("%s:%s:%s ", relative_path, entry.lnum, entry.col)
				local text = entry.text
				local start, finish, kw = Highlight.match(text)

				entry.hl = {}

				if start then
					kw = TodoConfig.keywords[kw] or kw
					local icon = TodoConfig.options.keywords[kw].icon or " "
					display = icon .. " " .. display
					table.insert(entry.hl, { { 0, #icon + 1 }, "TodoFg" .. kw })
					text = vim.trim(text:sub(start))

					table.insert(entry.hl, {
						{ #display, #display + finish - start + 2 },
						"TodoBg" .. kw,
					})
					table.insert(entry.hl, {
						{ #display + finish - start + 1, #display + finish + 1 + #text },
						"TodoFg" .. kw,
					})
					entry.text = display .. " " .. text
				end

				results[i] = entry
			end

			MiniPick.start({ source = { name = "Find Todo", show = show_todo, items = results } })
		end)
	end
end)

-- Highlight `#aabbcc` color strings with that color as a background
later(function()
	local hipatterns = require("mini.hipatterns")
	hipatterns.setup({
		highlighters = {
			hex_color = hipatterns.gen_highlighter.hex_color(),
		},
	})
end)
