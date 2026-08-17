local add = vim.pack.add
local now, now_if_args, later = Config.now, Config.now_if_args, Config.later

later(function()
  add({ "https://github.com/nvim-lua/plenary.nvim", "https://github.com/folke/todo-comments.nvim"
  })
  require("todo-comments").setup()
  MiniPick.registry.todo = function()
    local ns_digit_prefix = vim.api.nvim_create_namespace("cur-buf-pick-show")
    local show_todo = function(buf_id, entries, query, opts)
      MiniPick.default_show(buf_id, entries, query, opts)

      -- Add highlighting to every line in the buffer
      for line, entry in ipairs(entries) do
        for _, hl in ipairs(entry.hl) do
          vim.api.nvim_buf_add_highlight(buf_id, ns_digit_prefix, hl[2], line - 1, hl[1][1], hl[1][2])
        end
      end
    end
    require("todo-comments.search").search(function(results)
      local Config = require("todo-comments.config")
      local Highlight = require("todo-comments.highlight")

      for i, entry in ipairs(results) do
        -- By default, mini.pick uses the path item when an item is choosen to open it
        entry.path = entry.filename
        entry.filename = nil

        local relative_path = string.gsub(entry.path, vim.fn.getcwd() .. "/", "")
        local display = string.format("%s:%s:%s ", relative_path, entry.lnum, entry.col)
        local text = entry.text
        local start, finish, kw = Highlight.match(text)

        entry.hl = {}

        if start then
          kw = Config.keywords[kw] or kw
          local icon = Config.options.keywords[kw].icon or " "
          display = icon .. " " .. display
          table.insert(entry.hl, { { 0, #icon + 1 }, "TodoFg" .. kw })
          text = vim.trim(text:sub(start))

          table.insert(entry.hl, {
            { #display, #display + finish - start + 2 },
            "TodoBg" .. kw,
          })
          table.insert(entry.hl, {
            { #display + finish - start + 1, #display + finish + 1 + #text },
            "TodoFg" .. kw,
          })
          entry.text = display .. " " .. text
        end

        results[i] = entry
      end

      MiniPick.start({ source = { name = "Find Todo", show = show_todo, items = results } })
    end)
  end
end)

later(function()
  local hipatterns = require("mini.hipatterns")
  local hi_words = MiniExtra.gen_highlighter.words
  hipatterns.setup({
    highlighters = {
      --   -- Highlight a fixed set of common words. Will be highlighted in any place,
      --   -- not like "only in comments".
      --   fixme = hi_words({ "FIXME", "Fixme", "fixme" }, "MiniHipatternsFixme"),
      --   hack = hi_words({ "HACK", "Hack", "hack" }, "MiniHipatternsHack"),
      --   todo = hi_words({ "TODO", "Todo", "todo" }, "MiniHipatternsTodo"),
      --   note = hi_words({ "NOTE", "Note", "note" }, "MiniHipatternsNote"),
      --
      --   -- Highlight hex color string (#aabbcc) with that color as a background
      hex_color = hipatterns.gen_highlighter.hex_color(),
    },
  })
end)
