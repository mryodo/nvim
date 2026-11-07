-- ┌────────────────────────────┐
-- │ TODO comments and patterns │
-- └────────────────────────────┘

local add = vim.pack.add
local later = Config.later

-- Highlight TODO/FIXME/... comments. `<Leader>ft` picks them with 'fzf-lua'
-- (`:TodoFzfLua`).
later(function()
	add({
		"https://github.com/nvim-lua/plenary.nvim",
		"https://github.com/folke/todo-comments.nvim",
	})
	require("todo-comments").setup()
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
