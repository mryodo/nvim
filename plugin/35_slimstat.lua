local now, now_if_args, later = Config.now, Config.now_if_args, Config.later
local add = vim.pack.add

vim.pack.add({
  "https://github.com/sschleemilch/slimline.nvim",
})
require("slimline").setup({

  configs = {
    mode = {
      format = {
        ['n'] = { short = 'NOR' },
        ['v'] = { short = 'VIS' },
        ['V'] = { short = 'V-L' },
        ['\22'] = { short = 'V-B' },
        ['s'] = { short = 'SEL' },
        ['S'] = { short = 'S-L' },
        ['\19'] = { short = 'S-B' },
        ['i'] = { short = 'INS' },
        ['R'] = { short = 'REP' },
        ['c'] = { short = 'CMD' },
        ['r'] = { short = 'PRO' },
        ['!'] = { short = 'SHE' },
        ['t'] = { short = 'TER' },
        ['U'] = { short = 'UNK' },
      },
    },
  },

  components = {
    left = {
      'mode',
      'git',
      'diagnostics',
      -- 'path',
    },
    center = {
    },
    right = {
      'filetype_lsp',
      'progress',
      'searchcount'
    },
  },
})
