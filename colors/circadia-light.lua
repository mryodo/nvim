-- Light variant of 'colors/circadia-dark.lua'; see that file for why this
-- exists as a static entrypoint instead of the upstream-generated one.

vim.o.background = "light"
require("circadia").setup({ mode = "light" })
