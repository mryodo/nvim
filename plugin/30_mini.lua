local now, now_if_args, later = Config.now, Config.now_if_args, Config.later
local add = vim.pack.add

now(function()
  -- require("mini.hues").setup({ background = "#000f15", foreground = "#c9c5cb", n_hues = 6, saturation = 'low' }) -- purple
  vim.cmd("colorscheme miniwinter")
  -- require("mini.hues").setup({ background = '#11262d', foreground = '#c0c8cc', saturation = 'lowmedium' })
  -- require("mini.hues").setup({ background = "#000f15", foreground = "#c9c5cb", n_hues = 6 }) -- purple
end)


now(function()
  require("mini.basics").setup({
    options = { basic = true },
    mappings = {
      -- [''] = { b = 'e' },
      windows = true,
      move_with_alt = true,
    },
    autocommands = { basic = false },
  })
end)


now(function()
  local ext3_blocklist = { scm = true, txt = true, yml = true }
  local ext4_blocklist = { json = true, yaml = true }
  require("mini.icons").setup({
    use_file_extension = function(ext, _)
      return not (ext3_blocklist[ext:sub(-3)] or ext4_blocklist[ext:sub(-4)])
    end,
  })
  later(MiniIcons.mock_nvim_web_devicons)
  later(MiniIcons.tweak_lsp_kind)
end)

now(function()
  require("mini.notify").setup({
    window = {
      config = {
        border = "solid",
      },
    }
  })
end)

now(function()
  require("mini.sessions").setup()
end)

now(function()
  require("mini.starter").setup()
end)


now_if_args(function()
  require("mini.misc").setup()
  MiniMisc.setup_auto_root()
  MiniMisc.setup_restore_cursor()
  MiniMisc.setup_termbg_sync()
end)

later(function()
  require("mini.extra").setup()
end)

later(function()
  local ai = require("mini.ai")
  ai.setup({
    custom_textobjects = {
      B = MiniExtra.gen_ai_spec.buffer(),
      F = ai.gen_spec.treesitter({ a = "@function.outer", i = "@function.inner" }),
    },
    search_method = "cover",
  })
end)

later(function()
  require("mini.align").setup()
end)

later(function()
  require("mini.bracketed").setup()
end)

later(function()
  require("mini.bufremove").setup()
end)

later(function()
  local miniclue = require("mini.clue")
  -- stylua: ignore
  miniclue.setup({
    clues = {
      -- This is defined in 'plugin/20_keymaps.lua' with Leader group descriptions
      Config.leader_group_clues,
      miniclue.gen_clues.builtin_completion(),
      miniclue.gen_clues.g(),
      miniclue.gen_clues.marks(),
      miniclue.gen_clues.registers(),
      miniclue.gen_clues.square_brackets(),
      miniclue.gen_clues.windows({ submode_resize = true }),
      miniclue.gen_clues.z(),
    },
    triggers = {
      { mode = { 'n', 'x' }, keys = '<Leader>' }, -- Leader triggers
      { mode = 'n',          keys = '\\' },       -- mini.basics
      { mode = { 'n', 'x' }, keys = '[' },        -- mini.bracketed
      { mode = { 'n', 'x' }, keys = ']' },
      { mode = 'i',          keys = '<C-x>' },    -- Built-in completion
      { mode = { 'n', 'x' }, keys = 'g' },        -- `g` key
      { mode = { 'n', 'x' }, keys = "'" },        -- Marks
      { mode = { 'n', 'x' }, keys = '`' },
      { mode = { 'n', 'x' }, keys = '"' },        -- Registers
      { mode = { 'i', 'c' }, keys = '<C-r>' },
      { mode = 'n',          keys = '<C-w>' },    -- Window commands
      { mode = { 'n', 'x' }, keys = 's' },        -- `s` key (mini.surround, etc.)
      { mode = { 'n', 'x' }, keys = 'z' },        -- `z` key
    },
  })
end)

later(function()
  require("mini.cmdline").setup()
end)

later(function()
  require("mini.comment").setup()
end)

later(function()
  require("mini.diff").setup()
end)

later(function()
  require("mini.git").setup()
end)

later(function()
  require("mini.indentscope").setup({
    symbol = '▏',
  })
end)

later(function()
  require("mini.jump").setup()
end)

later(function()
  require("mini.keymap").setup()
  -- Navigate 'mini.completion' menu with `<Tab>` /  `<S-Tab>`
  MiniKeymap.map_multistep("i", "<Tab>", { "pmenu_next" })
  MiniKeymap.map_multistep("i", "<S-Tab>", { "pmenu_prev" })
  -- On `<CR>` try to accept current completion item, fall back to accounting
  -- for pairs from 'mini.pairs'
  MiniKeymap.map_multistep("i", "<CR>", { "pmenu_accept", "minipairs_cr" })
  -- On `<BS>` just try to account for pairs from 'mini.pairs'
  MiniKeymap.map_multistep("i", "<BS>", { "minipairs_bs" })
end)

later(function()
  require("mini.move").setup()
end)

later(function()
  require("mini.operators").setup()
  vim.keymap.set("n", "(", "gxiagxila", { remap = true, desc = "Swap arg left" })
  vim.keymap.set("n", ")", "gxiagxina", { remap = true, desc = "Swap arg right" })
end)

later(function()
  require("mini.pairs").setup({ modes = { command = true } })
end)

later(function()
  require("mini.splitjoin").setup()
end)

later(function()
  require("mini.surround").setup({
    custom_surroundings = {
      e = {
        input = { '\\begin%{[^}]*%}', '\\end%{[^}]*%}' },
        output = function()
          local env = MiniInput.get({ prompt = 'Environment: ', scope = 'cursor', })
          if env == '' then return nil end
          if env == nil then return nil end
          return {
            left  = '\\begin{' .. env .. '}\n',
            right = '\n\\end{' .. env .. '}',
          }
        end,
      },
      f = {
        input = { '\\%a+{', '}' },
        output = function()
          local fn = MiniInput.get({ prompt = 'Command: ', scope = 'cursor', })
          if fn == '' then return nil end
          if fn == nil then return nil end
          return { left = '\\' .. fn .. '{', right = '}' }
        end,
      },

    },
  }
  )
end)

later(function()
  require("mini.trailspace").setup()
end)

later(function()
  require("mini.visits").setup()
end)
later(function()
  require("mini.fuzzy").setup()
end)
later(function()
  require("mini.input").setup()
end)

now(function()
  require("statuscolumn.statuscolumn").setup()
  vim.api.nvim_set_hl(0, 'MiniStatuscolumnDimCursor', { link = 'CursorLineNr' })

  vim.o.foldcolumn = '1'
  vim.cmd('set fillchars+=foldsep:\\  fillchars+=foldopen:🯘 fillchars+=foldclose:🮥')
  if vim.fn.has('nvim-0.12') == 1 then vim.cmd('set fillchars+=foldinner:\\ ') end
end)
