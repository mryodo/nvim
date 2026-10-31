-- everforest-nvim with a 'background' baked in, so `:colorscheme` names one
-- variant like the Kitty/Ghostty theme files do (see 'plugin/93_ui.lua').
vim.o.background = "light"
require("everforest").load() -- a nested :colorscheme would be ignored
vim.g.colors_name = "everforest-light"
