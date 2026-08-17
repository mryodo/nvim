local add = vim.pack.add
local now, now_if_args, later = Config.now, Config.now_if_args, Config.later

later(function()
  add({
    "https://github.com/OXY2DEV/markview.nvim",
  })

  -- vim.api.nvim_set_hl(0, "MarkviewHeading1", { bg = "#2c4249", fg = "#b3daf9", bold = true, blend = 50 })
  -- vim.api.nvim_set_hl(0, "MarkviewHeading2", { bg = "#2c4249", fg = "#b3daf9", bold = true, blend = 50 })
  -- vim.api.nvim_set_hl(0, "MarkviewHeading3", { bg = "#2c4249", fg = "#b3daf9", bold = true, blend = 50 })
  -- vim.api.nvim_set_hl(0, "MarkviewHeading4", { bg = "#2c4249", fg = "#b3daf9", bold = true, blend = 50 })
  -- vim.api.nvim_set_hl(0, "MarkviewHeading5", { bg = "#2c4249", fg = "#b3daf9", bold = true, blend = 50 })
  local presets = require("markview.presets");
  require("markview").setup({
    markdown_inline = {
      checkboxes = {
        enable = false,
      },
    },
    markdown = {

      headings = presets.headings.glow,
      block_quotes = presets.obsidian,
      tables = presets.none,

      list_items = {
        indent_size = 3,
        marker_minus = {
          add_padding = true,
          text = "▬", -- change to whatever bullet you like
          hl = "MarkviewListItemMinus",
        },
      },
    },
  })
  add({ { src = "https://github.com/bngarren/checkmate.nvim", version = "main" } })
  local rwth = require("rwth")
  local colors = rwth.get_palette()
  -- local colors = MiniHues.get_palette({ background = '#11262d', foreground = '#c0c8cc', saturation = 'lowmedium' })
  -- local colors = require("mini.hues").get_palette()
  require("checkmate").setup({
    metadata = {
      due = {
        key = "<leader>TD",
        style = {
          -- fg = "#89B4FA",
          fg = "#7A7F96", -- koda manual
          -- fg = colors.type,
          -- fg = colors.bg_mid2,
          bold = true
        },

        get_value = function()
          -- tomorrow's date (a very naive implementation)
          local t = os.date("*t")
          t.day = t.day + 1
          local tomorrow = os.time(t)
          return os.date("%m/%d/%y", tomorrow)
        end,
      },
      priority = {
        alias = "p",
      },
      p = {
        label = "priority",
        key = { "<leader>TP" },
        get_value = function()
          return "■"
        end,
        choices = function()
          return { "▼", "■", "▲" }
        end,
        style = function(context)
          local value = context.value:lower()

          if value == "▲" then
            return {
              fg = "#86cd82", -- koda manual
              -- fg = colors.info,
              -- fg = colors.yellow,
              bold = true,
            }
          end
        end,
      },

    },
    todo_states = {
      unchecked = { marker = "○" },
      checked = { marker = "✔" },
      in_progress = {
        marker = "󰥔",
        markdown = "/",
        order = 3,
      },

      cancelled = {
        marker = "󰜺",
        markdown = "-",
        order = 4,
      },
    },
    archive = {
      heading = {
        level = 2,
        title = "󰃨 Archived",
      },

      parent_spacing = 1,
    },

    smart_toggle = {
      enabled = true,
      check_down = "direct_children",
      uncheck_down = "none",
      check_up = "direct_children",
      uncheck_up = "direct_children",
    },

    show_todo_count = true,
    todo_count_position = "eol",
    todo_count_recursive = true,

    todo_count_formatter = function(completed, total)
      if total > 0 then
        local percent = completed / total * 100
        local bar_length = 8
        local filled = math.floor(bar_length * percent / 100)
        local bar = string.rep("■", filled) .. string.rep("□", bar_length - filled)
        return ("%s [%d/%d]"):format(bar, completed, total)
      else
        return string.format("[%d/%d]", completed, total)
      end
    end

  })


  vim.keymap.set("n", "<leader>Tp", function()
    require("checkmate").select_metadata_value({ key = "p" })
  end, { desc = "Cycle priority" })

  vim.api.nvim_create_user_command("CheckMateIncompleteTodos", function()
    local picker = require("checkmate.picker")
    local todos = require("checkmate").get_todos()
    local incomplete = vim.tbl_filter(function(todo)
      return todo.text:match("- ○") -- only unchecked
    end, todos)
    picker.pick(picker.map_items(incomplete, "text"), {
      method = "pick_todo",
      -- picker_opts = opts.picker_opts,
    })
    return true
  end, {})

  vim.api.nvim_create_user_command("Sync", function()
    vim.fn.system("sh ~/scripts/simple.sh")
  end, {})
end)
