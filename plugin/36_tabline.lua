local now, now_if_args, later = Config.now, Config.now_if_args, Config.later
local add = vim.pack.add
now(function()
  -- Optional: keep mini.tabline installed, but don't let it control 'tabline'
  pcall(function()
    require("mini.tabline").setup({
      set_vim_settings = false,
    })
  end)

  local function escape_tabline_text(text)
    return text:gsub("%%", "%%%%")
  end

  local function get_icon(filename)
    local ok, mini_icons = pcall(require, "mini.icons")

    if ok and mini_icons.get then
      local icon = select(1, mini_icons.get("file", filename))

      if icon and icon ~= "" then
        return icon .. " "
      end
    end

    return ""
  end

  local function get_buf_label(buf)
    local name = vim.api.nvim_buf_get_name(buf)
    local filename = name == "" and "[No Name]" or vim.fn.fnamemodify(name, ":t")

    local label = get_icon(filename) .. filename

    if vim.bo[buf].modified then
      label = label .. " "
    end

    return escape_tabline_text(label)
  end

  local function get_groups(buf)
    local is_current = buf == vim.api.nvim_get_current_buf()
    local is_visible = vim.fn.bufwinnr(buf) ~= -1
    local is_modified = vim.bo[buf].modified


    if is_current and is_modified then
      return "SlimlineDiagnosticsHint", "SlimlineDiagnosticsHintSep"
    elseif is_current then
      return "SlimlineGitPrimary", "SlimlineGitPrimarySep"
    elseif is_visible then
      return "SlimlineGitSecondary", "SlimlineGitSecondarySep"
    elseif is_modified then
      return "SlimlineGitSecondary", "SlimlineGitSecondarySep"
    else
      return "SlimlineGitSecondary", "SlimlineGitSecondarySep"
    end
  end


  _G.PillTablineGoToBuffer = function(buf)
    buf = tonumber(buf)

    if buf and vim.api.nvim_buf_is_valid(buf) then
      pcall(vim.api.nvim_set_current_buf, buf)
    end
  end

  local function truncate(path, chars, full_dirs)
    local parts = vim.split(path, '/', { trimempty = true })

    local truncated = {}
    local n_parts = #parts

    for i, component in ipairs(parts) do
      if i > (n_parts - full_dirs) then
        table.insert(truncated, component)
      else
        local len = #component
        if len > chars then
          table.insert(truncated, component:sub(1, chars))
        else
          table.insert(truncated, component)
        end
      end
    end

    local result = table.concat(truncated, '/')
    return result
  end


  _G.PillTabline = function()
    local parts = {
      "%#Slimline#%= ",
    }

    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted then
        local body_hl, sep_hl = get_groups(buf)
        local label = get_buf_label(buf)

        local path = vim.fs.normalize(vim.fn.expand('%:.:h'))
        path = truncate(path, 1, 1)
        path = " " .. path
        path = buf == vim.api.nvim_get_current_buf() and path or ""



        if buf == vim.api.nvim_get_current_buf() then
          table.insert(
            parts,
            string.format(
              "%%%d@v:lua.PillTablineGoToBuffer@%%#%s#%%#%s# %s %%#%s#%%#%s# %s %%#%s#%%X%%#Slimline# ",
              buf,
              sep_hl,
              body_hl,
              label,
              "SlimlineGitPrimarySep2Sec",
              "SlimlineGitSecondary",
              path,
              "SlimlineGitSecondarySep"
            )
          )
        else
          table.insert(
            parts,
            string.format(
              "%%%d@v:lua.PillTablineGoToBuffer@%%#%s#%%#%s# %s %%#%s#%%X%%#Slimline# ",
              buf,
              sep_hl,
              body_hl,
              label,
              sep_hl
            )
          )
        end
      end
    end

    table.insert(parts, "%#Slimline#%=")

    return table.concat(parts)
  end

  vim.o.showtabline = 2
  vim.o.tabline = "%!v:lua.PillTabline()"
end)
