local add = vim.pack.add
local now, now_if_args, later = Config.now, Config.now_if_args, Config.later

later(function()
  add({ "https://github.com/windwp/nvim-autopairs" })
  local npairs = require("nvim-autopairs")
  local Rule = require("nvim-autopairs.rule")
  local cond = require("nvim-autopairs.conds")
  require("nvim-autopairs").setup()

  npairs.add_rules(
    {
      Rule("$", "$", { "tex", "latex" })
      -- don't add a pair if the next character is %
          :with_pair(cond.not_after_regex("%%"))
      -- don't add a pair if  the previous character is xxx
          :with_pair(cond.not_before_regex("xxx", 3))
      -- don't move right when repeat character
          :with_move(cond.none())
      -- don't delete if the next character is xx
          :with_del(cond.not_after_regex("xx"))
      -- disable adding a newline when you press <cr>
          :with_cr(cond.none()),
      Rule("\\(", "\\)", { "tex", "latex" }),
      Rule("\\[", "\\]", { "tex", "latex" }),
    }
  -- disable for .vim files, but it work for another filetypes
  )

  add({ "https://github.com/windwp/nvim-ts-autotag" })
  require('nvim-ts-autotag').setup({
    opts = {
      -- Defaults
      enable_close = true,          -- Auto close tags
      enable_rename = true,         -- Auto rename pairs of tags
      enable_close_on_slash = false -- Auto close on trailing </
    },
    -- Also override individual filetype configs, these take priority.
    -- Empty by default, useful if one of the "opts" global settings
    -- doesn't work well in a specific filetype
    per_filetype = {
      ["html"] = {
        enable_close = false
      }
    }
  })
end)
