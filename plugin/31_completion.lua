local now, now_if_args, later = Config.now, Config.now_if_args, Config.later

now_if_args(function()
  local process_items_opts = { kind_priority = { Text = -1, Snippet = 999 } }
  pcall(function()
    vim.o.completeitemalign = "abbr,menu,kind"
  end)
  local process_items = function(items, base)
    items = MiniCompletion.default_process_items(items, base, process_items_opts)

    for _, item in ipairs(items) do
      local kind = item.kind

      if type(kind) == "string" and kind ~= "" then
        local icon, hl = MiniIcons.get("lsp", kind:lower())

        if icon and icon ~= "" then
          local old_menu = item.menu or ""

          item.menu = icon .. (old_menu ~= "" and " " .. old_menu or "")
          item.menu_hlgroup = hl
        end
      end
    end
    return items
  end
  require("mini.completion").setup({
    lsp_completion = {
      source_func = "omnifunc",
      auto_setup = false,
      process_items = process_items,
    },
    window = {
      info = { height = 25, width = 80, border = "solid" },
      signature = { height = 25, width = 80, border = "solid" },
    },
  })

  local on_attach = function(ev)
    vim.bo[ev.buf].omnifunc = "v:lua.MiniCompletion.completefunc_lsp"
  end
  Config.new_autocmd("LspAttach", nil, on_attach, "Set 'omnifunc'")


  vim.api.nvim_set_hl(0, "Pmenu", {
    link = "NormalFloat",
  })

  vim.api.nvim_set_hl(0, "PmenuSel", {
    link = "Visual",
  })

  vim.api.nvim_set_hl(0, "PmenuKind", {
    link = "Type",
  })

  vim.api.nvim_set_hl(0, "PmenuKindSel", {
    link = "Type",
  })

  vim.api.nvim_set_hl(0, "PmenuExtra", {
    link = "Comment",
  })

  vim.api.nvim_set_hl(0, "PmenuExtraSel", {
    link = "Comment",
  })

  vim.api.nvim_set_hl(0, "PmenuSbar", {
    link = "Pmenu",
  })

  vim.api.nvim_set_hl(0, "PmenuThumb", {
    link = "Visual",
  })



  vim.lsp.config("*", { capabilities = MiniCompletion.get_lsp_capabilities() })
end)


later(function()
  -- Define language patterns to work better with 'friendly-snippets'
  local latex_patterns = { "latex/**/*.json", "**/latex.json" }
  local lang_patterns = {
    tex = latex_patterns,
    plaintex = latex_patterns,
    -- Recognize special injected language of markdown tree-sitter parser
    markdown_inline = { "markdown.json" },
  }

  vim.loop.os_setenv("USERNAME", "user")
  -- Compute custom lookup for variables with dynamic values
  local insert_with_lookup = function(snippet)
    local lookup = {
      TM_SELECTED_TEXT = table.concat(vim.fn.getreg("a", true, true), "\n"),
    }
    return MiniSnippets.default_insert(snippet, { lookup = lookup })
  end

  local snippets = require("mini.snippets")
  local match_strict = function(snips)
    -- Do not match with whitespace to cursor's left
    return snippets.default_match(snips, { pattern_fuzzy = "%S+" })
  end
  local config_path = vim.fn.stdpath("config")
  snippets.setup({
    snippets = {
      -- Always load 'snippets/global.json' from config directory
      snippets.gen_loader.from_file(config_path .. "/snippets/global.json"),
      -- Load from 'snippets/' directory of plugins, like 'friendly-snippets'
      snippets.gen_loader.from_lang({ lang_patterns = lang_patterns }),
    },
    mappings = { expand = "", jump_next = "", jump_prev = "" },
    expand = { insert = insert_with_lookup, match = match_strict },
  })

  local expand_or_jump = function()
    local can_expand = #MiniSnippets.expand({ insert = false }) > 0
    if can_expand then
      vim.schedule(MiniSnippets.expand)
      return ""
    end
    local is_active = MiniSnippets.session.get() ~= nil
    if is_active then
      MiniSnippets.session.jump("next")
      return ""
    end
    return "\t"
  end
  local jump_prev = function()
    MiniSnippets.session.jump("prev")
  end
  vim.keymap.set("i", "<Tab>", expand_or_jump, { expr = true })
  vim.keymap.set("i", "<S-Tab>", jump_prev)

  local fin_stop = function(args)
    if args.data.tabstop_to == "0" then
      MiniSnippets.session.stop()
    end
  end
  local au_opts = { pattern = "MiniSnippetsSessionJump", callback = fin_stop }
  vim.api.nvim_create_autocmd("User", au_opts)

  local make_stop = function()
    local au_opts = { pattern = "*:n", once = true }
    au_opts.callback = function()
      while MiniSnippets.session.get() do
        MiniSnippets.session.stop()
      end
    end
    vim.api.nvim_create_autocmd("ModeChanged", au_opts)
  end
  local opts = { pattern = "MiniSnippetsSessionStart", callback = make_stop }
  vim.api.nvim_create_autocmd("User", opts)

  MiniSnippets.start_lsp_server()
end)
