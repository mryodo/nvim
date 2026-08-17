local add = vim.pack.add
local now, now_if_args, later = Config.now, Config.now_if_args, Config.later
now(function()
  add({ "https://github.com/tofunori/pdftui" })
  require("pdftui").setup({
    pdf_path = nil, -- auto-detected from .tex file
    split = true,   -- false = open in new tab, true = split
  })
  add({ "https://github.com/lervag/vimtex" })
  -- vim.g.vimtex_view_method = "pdftui"        -- For Wayland compatibility, avoid xdotool
  -- vim.g.vimtex_context_pdf_viewer = "pdftui" -- External PDF viewer for the Vimtex menu
  -- vim.g.vimtex_view_general_options = "file:///@pdf"


  -- vim.g.vimtex_view_method = "skim"
  vim.g.vimtex_view_method = "galley"
  vim.g.vimtex_view_galley_sync = 1
  -- vim.g.vimtex_view_general_viewer = 'kitty @launch --cwd=current pdftui'
  -- vim.g.vimtex_view_general_options = [[@pdf -f --inverse-cmd "nvim --headless -c 'VimtexInverseSearch {line} {file}'"]]

  -- vim.g.vimtex_compiler_method = "texpresso"
  vim.g.vimtex_compiler_latexmk = {
    options = {
      "-shell-escape",
      "-pdf",
      "-verbose",
      "-file-line-error",
      "-synctex=1",
      "-interaction=nonstopmode",
    },
  }
  -- vim.g.vimtex_view_skim_activate = 1
  -- vim.g.vimtex_view_skim_sync = 1
  -- vim.opt.conceallevel = 1
  -- vim.g.tex_conceal = "abdmg"
  -- Formatting settings
  vim.g.vimtex_format_enabled = true -- Enable formatting with latexindent
  vim.g.vimtex_format_program = "latexindent"
  vim.g.vimtex_fold_enabled = 1
  vim.g.vimtex_fold_manual = 1
  -- Indentation settings
  --vim.g.vimtex_indent_enabled = false -- Disable auto-indent from Vimtex
  --vim.g.tex_indent_items = false  -- Disable indent for enumerate
  --vim.g.tex_indent_brace = false  -- Disable brace indent

  -- Suppression settings
  vim.g.vimtex_quickfix_mode = 0 -- Suppress quickfix on save/build
  vim.g.vimtex_log_ignore = {    -- Suppress specific log messages
    "Underfull",
    "Overfull",
    "specifier changed to",
    "Token not allowed in a PDF string",
  }

  -- Other settings
  vim.g.vimtex_mappings_enabled = false -- Disable default mappings
  vim.g.tex_flavor = "latex"            -- Set file type for TeX files
  vim.api.nvim_create_autocmd("FileType", {
    pattern = "tex",
    -- group = my_augroup,
    desc = "set keymap for tex",
    callback = function()
      local bufmap = function(mode, lhs, rhs, desc)
        vim.keymap.set(mode, lhs, rhs, {
          buffer = true,
          noremap = false,
          silent = true,
          desc = desc,
        })
      end

      bufmap("n", "<LocalLeader>lt", "<Plug>(vimtex-toc-toggle)")
      bufmap("n", "<LocalLeader>ll", "<Plug>(vimtex-compile)")
      bufmap("n", "<LocalLeader>lc", "<Plug>(vimtex-clean)")
      bufmap("n", "<LocalLeader>lv", "<Plug>(vimtex-view)")
      bufmap("n", "<LocalLeader>lk", "<Plug>(vimtex-stop)")
      bufmap("n", "<LocalLeader>lm", "<Plug>(vimtex-toggle-main)")
      bufmap("n", "<LocalLeader>la", "<Plug>(vimtex-context-menu)")
      bufmap("n", "<LocalLeader>lo", "<Plug>(vimtex-compile-output)")
      bufmap("n", "<LocalLeader>ss", "<Plug>(vimtex-env-surround-line)")
      bufmap("n", "<LocalLeader>s", "<Plug>(vimtex-env-surround-operator)")
      bufmap("x", "<LocalLeader>s", "<Plug>(vimtex-env-surround-visual)")
    end,
  })

  local group = vim.api.nvim_create_augroup("vimtex_common", { clear = true })

  local function write_server_name()
    vim.fn.writefile({ vim.v.servername }, "/tmp/vimtexserver.txt")
  end

  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "tex",
    callback = write_server_name,
  })
end)
