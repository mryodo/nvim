-- Entrypoint for 'circadia' (https://github.com/tanmaymanojgandhi/circadia),
-- installed and added to 'runtimepath' in 'plugin/93_ui.lua'. The plugin
-- itself ships no `colors/*.lua`; upstream's own install instructions
-- generate one under `stdpath("data")` at startup, but a static file
-- alongside the rest of this directory's colorschemes is simpler.

vim.o.background = "dark"
require("circadia").setup({ mode = "dark" })
