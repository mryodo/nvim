local now, now_if_args, later = Config.now, Config.now_if_args, Config.later
local add = vim.pack.add
now_if_args(function()
  add({ 'https://github.com/nvim-telescope/telescope.nvim' })
  add({ 'https://github.com/nvim-lua/plenary.nvim' })
  add({ 'https://github.com/nvim-telescope/telescope-fzf-native.nvim' })
  add({ 'https://github.com/nvim-telescope/telescope-media-files.nvim' })
  require('telescope').load_extension('media_files')
  add({ 'https://github.com/adriancmiranda/glimpse.nvim' })

  require('telescope').setup({
    defaults = {
      mappings = {
        i = {
          ["<Esc>"] = "close"
        },
      },
      border = true,
      borderchars = {
        " ", " ", " ", " ",
        " ", " ", " ", " ",
      },
    },
    pickers = {
      find_files = {
        previewer = require('glimpse.integrations.telescope').previewer(),
      },
    },
  })

  local builtin = require('telescope.builtin')
  local make_entry = require("telescope.make_entry")
  local entry_display = require("telescope.pickers.entry_display")

  local severity_name = {
    ["ERROR"] = "󰅚 ERROR",
    ["WARN"] = "󰀪 WARN",
    ["INFO"] = "󰋽 INFO",
    ["HINT"] = "󰌶 HINT",
  }

  local severity_hl = {
    ["ERROR"] = "MyTelescopeDiagnosticError",
    ["WARN"] = "MyTelescopeDiagnosticWarn",
    ["INFO"] = "MyTelescopeDiagnosticInfo",
    ["HINT"] = "MyTelescopeDiagnosticHint",
  }

  local function safe_str(value)
    if value == nil then
      return ""
    end
    return tostring(value):gsub("\n", " ")
  end

  local function cell(value, hl)
    return {
      safe_str(value),
      hl,
    }
  end

  local function get_filename(diagnostic)
    if diagnostic.filename then
      return vim.fn.fnamemodify(diagnostic.filename, ":~:.")
    end

    if diagnostic.bufnr and vim.api.nvim_buf_is_valid(diagnostic.bufnr) then
      local name = vim.api.nvim_buf_get_name(diagnostic.bufnr)

      if name ~= "" then
        return vim.fn.fnamemodify(name, ":~:.")
      end
    end

    return "[No Name]"
  end

  local function diagnostic_entry_maker(opts)
    opts = opts or {}

    local default_entry_maker = make_entry.gen_from_diagnostics(opts)

    local displayer = entry_display.create({
      separator = " ",
      items = {
        { width = 35 },
        { width = 9 },
        { width = 7 },
        { remaining = true },
      },
    })


    return function(diagnostic)
      local entry = default_entry_maker(diagnostic)
      local filename = get_filename(diagnostic)

      local location = string.format(
        "%d:%d",
        (diagnostic.lnum or 0) + 1,
        (diagnostic.col or 0) + 1
      )
      local severity = nil

      if entry.value and entry.value.type then
        severity = entry.value.type
      elseif diagnostic.severity then
        severity = diagnostic.type
      end
      local sev_name = severity_name[severity] or "UNKNOWN"
      local sev_hl = severity_hl[severity] or "TelescopeResultsComment"

      local message = diagnostic.message or ""

      entry.display = function()
        return displayer({
          cell(filename, "TelescopeResults"),
          cell(location, sev_hl),
          cell(sev_name, sev_hl),
          cell(message, sev_hl),
        })
      end

      return entry
    end
  end




  vim.keymap.set('n', '<leader>ff', builtin.find_files, { desc = 'Telescope find files' })
  vim.keymap.set('n', '<leader> ', builtin.find_files, { desc = 'Telescope find files' })
  vim.keymap.set('n', '<leader>fg', builtin.live_grep, { desc = 'Telescope live grep' })
  vim.keymap.set('n', '<leader>fb', builtin.buffers, { desc = 'Telescope buffers' })
  vim.keymap.set('n', '<leader>fh', builtin.help_tags, { desc = 'Telescope help tags' })
  vim.keymap.set('n', '<leader>fc', builtin.git_commits, { desc = 'Telescope commits' })
  vim.keymap.set('n', '<leader>fC', builtin.colorscheme, { desc = 'Telescope colorschemes' })
  vim.keymap.set('n', '<leader>fR', builtin.lsp_references, { desc = 'Telescope references' })
  vim.keymap.set('n', '<leader>fs', builtin.lsp_workspace_symbols, { desc = 'Telescope symbols (workspace)' })
  vim.keymap.set('n', '<leader>fS', builtin.lsp_document_symbols, { desc = 'Telescope symbols' })
  vim.keymap.set('n', '<leader>ft', "<cmd>TodoTelescope<CR>", { desc = 'Telescope todos' })
  vim.keymap.set('n', '<leader>fd',
    function() builtin.diagnostics({ bufnr = 0, entry_maker = diagnostic_entry_maker({}), }) end,
    { desc = 'Telescope diagnostics (buffer)' })
  vim.keymap.set('n', '<leader>fD', function() builtin.diagnostics({ entry_maker = diagnostic_entry_maker({}), }) end,
    { desc = 'Telescope diagnostics' })
end)
