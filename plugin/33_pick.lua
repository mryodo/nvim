local now, now_if_args, later = Config.now, Config.now_if_args, Config.later
local add = vim.pack.add
now(function()
  require("mini.pick").setup()
end)
