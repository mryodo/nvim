-- echasnovski's 'minischeme2' with a 'background' baked in, so `:colorscheme`
-- names one variant like the Kitty/Ghostty theme files do (see 'plugin/93_ui.lua').
vim.o.background = "light"
vim.cmd.runtime("colors/minischeme2.lua") -- a nested :colorscheme would be ignored
vim.g.colors_name = "minischeme2-light"
