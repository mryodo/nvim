local add = vim.pack.add
local now_if_args, later = Config.now_if_args, Config.later

now_if_args(function()
  -- Define hook to update tree-sitter parsers after plugin is updated
  local ts_update = function()
    vim.cmd("TSUpdate")
  end
  Config.on_packchanged("nvim-treesitter", { "update" }, ts_update, ":TSUpdate")

  add({
    "https://github.com/nvim-treesitter/nvim-treesitter",
    "https://github.com/nvim-treesitter/nvim-treesitter-textobjects",
  })


  require("nvim-treesitter").setup({
    highlight = {
      enable = true,
      additional_vim_regex_highlighting = false,
    },
  })
  local languages = {
    "lua",
    "vimdoc",
    "markdown",
    "latex",
    "julia",
    "typescript",
    "astro",
    "json",
    "toml",

  }
  local isnt_installed = function(lang)
    return #vim.api.nvim_get_runtime_file("parser/" .. lang .. ".*", false) == 0
  end
  local to_install = vim.tbl_filter(isnt_installed, languages)
  if #to_install > 0 then
    require("nvim-treesitter").install(to_install)
  end

  -- Enable tree-sitter after opening a file for a target language
  local filetypes = {}
  for _, lang in ipairs(languages) do
    for _, ft in ipairs(vim.treesitter.language.get_filetypes(lang)) do
      table.insert(filetypes, ft)
    end
  end
  local ts_start = function(ev)
    vim.treesitter.start(ev.buf)
  end
  Config.new_autocmd("FileType", filetypes, ts_start, "Start tree-sitter")
  vim.api.nvim_create_autocmd("User", {
    pattern = "TSUpdate",
    callback = function()
      require("nvim-treesitter.parsers").asciidoc = {
        install_info = {
          branch = "master",
          location = "tree-sitter-asciidoc",
          queries = "queries/asciidoc/",
          requires = { "asciidoc_inline" },
          url = "https://github.com/cathaysia/tree-sitter-asciidoc",
        },
      }
      require("nvim-treesitter.parsers").asciidoc_inline = {
        install_info = {
          branch = "master",
          location = "tree-sitter-asciidoc_inline",
          queries = "queries/asciidoc_inline",
          url = "https://github.com/cathaysia/tree-sitter-asciidoc",
        },
      }
    end,
  })
end)

now_if_args(function()
  add({ "https://github.com/neovim/nvim-lspconfig" })
  vim.lsp.config("ltex", {
    settings = {
      ltex = {
        checkFrequency = "save",
      },
    },
  })

  vim.lsp.enable({
    -- For example, if `lua-language-server` is installed, use `'lua_ls'` entry
    "lua_ls",
    -- "ltex",
    "julials",
    "texlab",
    "marksman",
  })
end)

later(function()
  add({ "https://github.com/stevearc/conform.nvim" })
  require("conform").setup({
    default_format_opts = {
      -- Allow formatting from LSP server if no dedicated formatter is available
      lsp_format = "fallback",
    },
    format_on_save = function(bufnr)
      -- Disable with a global or buffer-local variable
      if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
        return
      end
      return { timeout_ms = 50000, lsp_format = "fallback" }
    end,
    -- Map of filetype to formatters
    -- Make sure that necessary CLI tool is available
    formatters_by_ft = {
      lua = { "stylua" },
      tex = { "latexindent" },
      latex = { "latexindent" },
      markdown = { "prettierd" },
      julia = { "runic" },
    },

    -- Map of filetype to formatters
    -- Make sure that necessary CLI tool is available
    -- formatters_by_ft = { lua = { 'stylua' } },
  })
  vim.api.nvim_create_user_command("FormatDisable", function(args)
    if args.bang then
      -- FormatDisable! will disable formatting just for this buffer
      vim.b.disable_autoformat = true
    else
      vim.g.disable_autoformat = true
    end
  end, {
    desc = "Disable autoformat-on-save",
    bang = true,
  })
  vim.api.nvim_create_user_command("FormatEnable", function()
    vim.b.disable_autoformat = false
    vim.g.disable_autoformat = false
  end, {
    desc = "Re-enable autoformat-on-save",
  })
end)

later(function()
  add({ "https://github.com/mason-org/mason.nvim" })
  add({ "https://github.com/mason-org/mason-lspconfig.nvim" })
  require("mason").setup()
  require("mason-lspconfig").setup()
end)

later(function()
  add({ 'https://github.com/rachartier/tiny-inline-diagnostic.nvim' })
  require("tiny-inline-diagnostic").setup({
    options = {
      show_source = {
        enabled = true,
      },
      add_messages = {
        display_count = true,
      },
      multilines = {
        enabled = true,
      },
    },
  })
end)


Config.now(function()
  add({
    "https://github.com/oskarnurm/koda.nvim",
    'https://github.com/sainnhe/everforest',
    'https://github.com/Shatur/neovim-ayu',
    'https://github.com/ellisonleao/gruvbox.nvim',
  })
  add({ "https://github.com/jpwol/thorn.nvim" })
  add({ 'https://github.com/vague-theme/vague.nvim' })
  add({ 'https://github.com/nyoom-engineering/oxocarbon.nvim' })
  add({ 'https://github.com/webhooked/kanso.nvim' })
  add({ 'https://github.com/nendix/zen.nvim' })
  add({ 'https://github.com/slugbyte/lackluster.nvim' })
  add({ 'https://github.com/thesimonho/kanagawa-paper.nvim' })
  add({ 'https://github.com/mitander/flume.nvim' })
  add({ "https://github.com/mcauley-penney/techbase.nvim" })
  add({ 'https://github.com/MartyBeGood/lorem-gypsum.nvim' })
  add({ "https://github.com/mryodo/rwth.nvim" })
  add({ 'https://github.com/Aejkatappaja/cendre' })
  add({ 'https://github.com/WTFox/luna.nvim' })

  require("rwth").setup({
    transparent = false,
  })

  vim.keymap.set(
    'n',
    '\\b',
    function()
      if vim.o.background == "light" then
        vim.o.background = "dark"
        vim.cmd.colorscheme("rwth-dark")
        vim.cmd("RWTHFetch")
        vim.cmd("set guicursor=n-v-c:block-Cursor/lCursor,i-ci-ve:ver25-Cursor/lCursor,r-cr:hor20,o:hor50")
      else
        vim.o.background = "light"
        vim.cmd.colorscheme("rwth-light")
        vim.cmd("RWTHFetch")
        vim.cmd("set guicursor=n-v-c:block-Cursor/lCursor,i-ci-ve:ver25-Cursor/lCursor,r-cr:hor20,o:hor50")
      end
    end,
    { desc = "new Toggle 'background'" }
  )
  vim.cmd("colorscheme rwth-dark")
end)

later(function()
  vim.cmd("colorscheme rwth-dark")
end)
