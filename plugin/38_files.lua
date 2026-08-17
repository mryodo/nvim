local now, now_if_args, later = Config.now, Config.now_if_args, Config.later
local add = vim.pack.add
now_if_args(function()
  require('mini.files').setup({
    windows = {
      preview = true,
      width_focus = math.floor(0.6 * vim.o.columns),
      width_nofocus = math.floor(0.36 * vim.o.columns),
      width_preview = math.floor(0.36 * vim.o.columns),
    },
    options = {
      use_as_default_explorer = true,
    },
    content = {
      prefix = function(fs_entry)
        local MiniIcons = require("mini.icons")

        local category = fs_entry.fs_type == "directory" and "directory" or "file"
        local icon, hl, is_default = MiniIcons.get(category, fs_entry.name)

        if is_default then
          hl = "MiniFilesIconDefault"
        end

        return " " .. icon .. " ", hl
      end,
    },
  })

  local add_marks = function()
    MiniFiles.set_bookmark("c", vim.fn.stdpath("config"), { desc = "Config" })
    local vimpack_plugins = vim.fn.stdpath("data") .. "/site/pack/core/opt"
    MiniFiles.set_bookmark("p", vimpack_plugins, { desc = "Plugins" })
    MiniFiles.set_bookmark("w", vim.fn.getcwd, { desc = "Working directory" })
  end
  Config.new_autocmd("User", "MiniFilesExplorerOpen", add_marks, "Add bookmarks")
end)
