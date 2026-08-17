local add = vim.pack.add
local now, now_if_args, later = Config.now, Config.now_if_args, Config.later

now_if_args(function()
  add({ "https://github.com/goerz/vim-slime" })
  add({
    "https://github.com/jmbuhr/otter.nvim",
    "https://github.com/nvim-treesitter/nvim-treesitter",
    "https://github.com/quarto-dev/quarto-nvim"
  })
  require("quarto").setup({
    debug = false,
    closePreviewOnExit = true,
    lspFeatures = {
      enabled = true,
      chunks = "curly",
      languages = { "r", "python", "julia", "bash", "html" },
      diagnostics = {
        enabled = true,
        triggers = { "BufWritePost" },
      },
      completion = {
        enabled = true,
      },
    },

    codeRunner = {
      enabled = true,
      default_method = "slime", -- "molten", "slime", "iron" or <function>
      ft_runners = {},          -- filetype to runner, ie. `{ python = "molten" }`.
      -- Takes precedence over `default_method`
      never_run = { "yaml" },   -- filetypes which are never sent to a code runner
    },
  })

  add({ 'https://github.com/mroavi/vim-julia-cell' })
  vim.g.julia_cell_delimit_cells_by = 'tags'
  vim.api.nvim_set_keymap("n", "<Leader>jr", ":JuliaCellRun<CR>",
    { noremap = true, silent = true, desc = "send julia cell" })
  vim.api.nvim_set_keymap("n", "<Leader>jc", ":JuliaCellExecuteCell<CR>",
    { noremap = true, silent = true, desc = "send julia execute cell" })
  vim.api.nvim_set_keymap("n", "<Leader>jC", ":JuliaCellExecuteCellJump<CR>",
    { noremap = true, silent = true, desc = "send julia execute jump cell" })
  vim.api.nvim_set_keymap("n", "<Leader>jl", ":JuliaCellClear<CR>",
    { noremap = true, silent = true, desc = "send julia clear" })
  vim.api.nvim_set_keymap("n", "<Leader>jp", ":JuliaCellPrevCell<CR>",
    { noremap = true, silent = true, desc = "send julia prev" })
  vim.api.nvim_set_keymap("n", "<Leader>jn", ":JuliaCellNextCell<CR>",
    { noremap = true, silent = true, desc = "send julia next" })
  vim.api.nvim_set_keymap("n", "<Leader>je", "<Plug>SlimeLineSend<CR>",
    { noremap = false, silent = true, desc = "send julia line" })
  vim.api.nvim_set_keymap("x", "<Leader>je", "<Plug>SlimeRegionSend<CR>",
    { noremap = false, silent = true, desc = "send julia region" })

  vim.api.nvim_create_autocmd('CursorMoved', {
    desc = 'Keep * synced with selection',
    callback = function()
      local mode = vim.fn.mode(false)
      if mode == 'v' or mode == 'V' or mode == '\22' then
        vim.fn.setreg('*', vim.fn.getregion(vim.fn.getpos('.'),
          vim.fn.getpos('v'), { type = mode }))
      end
    end,
  })


  vim.g.slime_target = "kitty"
  -- vim.g.slime_no_mappings = 1
  -- vim.g.slime_python_ipython = 1

  vim.api.nvim_set_keymap("n", "<leader>s", ":SlimeSend<CR>", { noremap = true, silent = true, desc = "Send to SLIME" }) -- normal mode
  vim.api.nvim_set_keymap(
    "x",
    "<leader>s",
    ":'<,'>SlimeSend<CR>'>",
    { noremap = true, silent = true, desc = "Send to SLIME" }
  ) -- visual mode
  vim.api.nvim_set_keymap(
    "x",
    "<c-c><c-c>",
    ":'<,'>SlimeSend<CR>'>",
    { noremap = true, silent = true, desc = "Send to SLIME" }
  ) -- visual mode
  local runner = require("quarto.runner")
  vim.keymap.set("n", "<leader>rc", runner.run_cell, { desc = "run cell", silent = true })
  vim.keymap.set("n", "<leader>ra", runner.run_above, { desc = "run cell and above", silent = true })
  vim.keymap.set("n", "<leader>rA", runner.run_all, { desc = "run all cells", silent = true })
  vim.keymap.set("n", "<leader>rl", runner.run_line, { desc = "run line", silent = true })
  vim.keymap.set("v", "<leader>rs", runner.run_range, { desc = "run visual range", silent = true })
  vim.keymap.set("n", "<localleader>RA", function()
    runner.run_all(true)
  end, { desc = "run all cells of all languages", silent = true })
end)
