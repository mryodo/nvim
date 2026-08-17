local add = vim.pack.add
local now, now_if_args, later = Config.now, Config.now_if_args, Config.later
later(function()
  add({ "https://github.com/serhez/bento.nvim" })
  require("bento").setup({
    highlights = {
      previous = "BentoNormal",
    },
  })
end)
