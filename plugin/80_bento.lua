-- ┌────────────────┐
-- │ Buffer manager │
-- └────────────────┘
--
-- 'bento.nvim' is a floating buffer switcher: press the expand key, then the
-- one-character label of the buffer you want. It is not the buffer *line* --
-- 'bufferline.nvim' ('plugin/93_ui.lua') still owns 'tabline', which is why
-- `ui.mode` is left on its `"floating"` default.
--
-- Everything below the `setup()` call is required for the plugin to appear at
-- all. v1 registered a `;` mapping and a full set of actions during `setup()`;
-- v2 registers nothing, and `setup()` only configures behaviour and appearance.
-- With no expand key and no `ui.floating.minimal_menu`, `toggle_menu()` bails
-- out at `if not minimal_menu_active and not force_create then return end` and
-- no window is ever created -- `:BentoToggle` included.

local add = vim.pack.add
local later = Config.later

later(function()
	add({ "https://github.com/serhez/bento.nvim" })
	require("bento").setup({
		highlights = {
			previous = "BentoNormal",
		},
	})

	local api = require("bento.api")

	-- The only global mapping bento makes, and the one v1 used to register on
	-- its own. It shadows the built-in `;` (repeat the last `f`/`t` motion);
	-- 'mini.jump', which would also want the key for `repeat_jump`, is commented
	-- out in 'plugin/30_mini.lua'. Any other single character works here.
	api.register_expand_key(";", { desc = "Bento menu" })

	-- Label for the last-accessed buffer, *not* a global mapping -- bento only
	-- binds it inside the open menu, and restores whatever `;` was mapped to on
	-- the way out. Sharing the expand key is the README's tip: `;;` jumps
	-- straight back to the previous buffer. It has to stay one character wide,
	-- since the label is drawn verbatim next to the single letters of every
	-- other buffer.
	api.register_last_buffer_key(";")

	-- These three only exist inside the menu window
	api.register_collapse_key("<Esc>")
	api.register_prev_page_key("[")
	api.register_next_page_key("]")

	-- ...and so do these. Without at least one registered action the menu opens
	-- but can do nothing with the buffer under the label, and `expand_menu()`
	-- warns about it.
	-- stylua: ignore
	local actions = {
		{ "open",   "<CR>", api.actions.open,   "DiagnosticVirtualTextHint" },
		{ "delete", "<BS>", api.actions.delete, "DiagnosticVirtualTextError" },
		{ "vsplit", "|",    api.actions.vsplit, "DiagnosticVirtualTextInfo" },
		{ "split",  "_",    api.actions.split,  "DiagnosticVirtualTextInfo" },
		{ "lock",   "*",    api.actions.lock,   "DiagnosticVirtualTextWarn" },
	}
	for _, spec in ipairs(actions) do
		local name, key, action, hl = unpack(spec)
		api.register_action(name, { key = key, action = action, hl = hl })
	end
	api.set_default_action("open")
end)
