-- ┌─────────────────┐
-- │ Custom mappings │
-- └─────────────────┘
--
-- General and <Leader> mappings that do not belong to a single plugin.
--
-- Mappings that only make sense together with one plugin live next to that
-- plugin's setup instead:
-- - `<Leader>f*` (find)      - 'plugin/95_fzf.lua', with 'plugin/33_pick.lua'
--                              providing the few pickers 'fzf-lua' has no
--                              equivalent for.
-- - `<Leader>a*` (AI)        - 'plugin/97_ai.lua'
-- - `<Leader>g[g]` (lazygit) - 'plugin/50_lazygit.lua'
-- - `<Leader>r*` (run cell)  - 'plugin/62_repl.lua'
-- - `<Leader>T*` (todo)      - 'plugin/61_markdown.lua'
-- - `<LocalLeader>h*` (hunk) - 'plugin/91_git.lua'
-- - `<LocalLeader>l*` (TeX)  - 'plugin/60_vimtex.lua'

-- General mappings ===========================================================

-- An example helper to create a Normal mode mapping. See `:h vim.keymap.set()`.
local nmap = function(lhs, rhs, desc)
	vim.keymap.set("n", lhs, rhs, { desc = desc })
end

-- Paste linewise before/after current line
-- Usage: `yiw` to yank a word and `]p` to put it on the next line.
nmap("[p", '<Cmd>exe "iput! " . v:register<CR>', "Paste Above")
nmap("]p", '<Cmd>exe "iput "  . v:register<CR>', "Paste Below")

-- Many general mappings are created by 'mini.basics'. See 'plugin/30_mini.lua'

-- stylua: ignore start
-- The next part (until `-- stylua: ignore end`) is aligned manually for easier
-- reading. Consider preserving this or remove `-- stylua` lines to autoformat.

-- Leader mappings ============================================================

-- Neovim has the concept of a Leader key (see `:h <Leader>`). It is a configurable
-- key that is primarily used for "workflow" mappings (opposed to text editing).
-- Like "open file explorer", "create scratch buffer", "pick from buffers".
--
-- In 'plugin/10_options.lua' <Leader> is set to <Space>, i.e. press <Space>
-- whenever there is a suggestion to press <Leader>.
--
-- This config uses a "two key Leader mappings" approach: first key describes
-- semantic group, second key executes an action. Both keys are usually chosen
-- to create some kind of mnemonic.
-- Example: `<Leader>f` groups "find" type of actions; `<Leader>ff` - find files.
--
-- Usually if there are global and local kinds of actions, lowercase second key
-- denotes global and uppercase - local.
-- Example: `<Leader>fs` / `<Leader>fS` - find workspace/document LSP symbols.

-- Information about Leader groups, consumed by 'which-key.nvim'.
-- Add an entry if you create a new group.
Config.leader_group_clues = {
  { mode = 'n', keys = '<Leader>a', desc = '+AI' },
  { mode = 'n', keys = '<Leader>b', desc = '+Buffer' },
  { mode = 'n', keys = '<Leader>c', desc = '+Session' },
  { mode = 'n', keys = '<Leader>e', desc = '+Explore/Edit' },
  { mode = 'n', keys = '<Leader>f', desc = '+Find' },
  { mode = 'n', keys = '<Leader>g', desc = '+Git' },
  { mode = 'n', keys = '<Leader>j', desc = '+Julia REPL' },
  { mode = 'n', keys = '<Leader>l', desc = '+Language' },
  { mode = 'n', keys = '<Leader>m', desc = '+Map' },
  { mode = 'n', keys = '<Leader>o', desc = '+Other' },
  { mode = 'n', keys = '<Leader>r', desc = '+Run cell' },
  { mode = 'n', keys = '<Leader>t', desc = '+Terminal' },
  { mode = 'n', keys = '<Leader>v', desc = '+Visits' },
  { mode = 'n', keys = '<Leader>T', desc = '+Todo' },

  { mode = 'x', keys = '<Leader>a', desc = '+AI' },
  { mode = 'x', keys = '<Leader>g', desc = '+Git' },
  { mode = 'x', keys = '<Leader>l', desc = '+Language' },
  { mode = 'x', keys = '<Leader>r', desc = '+Run cell' },
}

-- Helpers for a more concise `<Leader>` mappings.
-- Most of the mappings use `<Cmd>...<CR>` string as a right hand side (RHS) in
-- an attempt to be more concise yet descriptive. See `:h <Cmd>`.
-- This approach also doesn't require the underlying commands/functions to exist
-- during mapping creation: a "lazy loading" approach to improve startup time.
local nmap_leader = function(suffix, rhs, desc)
  vim.keymap.set('n', '<Leader>' .. suffix, rhs, { desc = desc })
end
local xmap_leader = function(suffix, rhs, desc)
  vim.keymap.set('x', '<Leader>' .. suffix, rhs, { desc = desc })
end

-- Top level ------------------------------------------------------------------
nmap_leader('w', '<Cmd>w<CR>', 'Save')

-- b is for 'Buffer'. Common usage:
-- - `<Leader>bs` - create scratch (temporary) buffer
-- - `<Leader>ba` - navigate to the alternative buffer
-- - `<Leader>bw` - wipeout (fully delete) current buffer
local new_scratch_buffer = function()
  vim.api.nvim_win_set_buf(0, vim.api.nvim_create_buf(true, true))
end

nmap_leader('ba', '<Cmd>b#<CR>',                             'Alternate')
nmap_leader('bd', '<Cmd>lua MiniBufremove.delete()<CR>',     'Delete')
nmap_leader('bD', '<Cmd>lua MiniBufremove.delete(0, true)<CR>',  'Delete!')
nmap_leader('bs', new_scratch_buffer,                        'Scratch')
nmap_leader('bw', '<Cmd>lua MiniBufremove.wipeout()<CR>',    'Wipeout')
nmap_leader('bW', '<Cmd>lua MiniBufremove.wipeout(0, true)<CR>', 'Wipeout!')

-- c is for 'Config/session'. Common usage:
-- - `<Leader>cn` - start new session
-- - `<Leader>cr` - read previously started session
-- - `<Leader>cd` - delete previously started session
local session_new = 'MiniSessions.write(vim.fn.input("Session name: "))'

nmap_leader('cd', '<Cmd>lua MiniSessions.select("delete")<CR>', 'Delete')
nmap_leader('cn', '<Cmd>lua ' .. session_new .. '<CR>',         'New')
nmap_leader('cr', '<Cmd>lua MiniSessions.select("read")<CR>',   'Read')
nmap_leader('cw', '<Cmd>lua MiniSessions.write()<CR>',          'Write current')

-- e is for 'Explore' and 'Edit'. Common usage:
-- - `<Leader>ed` - open explorer at current working directory
-- - `<Leader>ef` - open directory of current file (needs to be present on disk)
-- - `<Leader>ei` - edit 'init.lua'
-- - All mappings that use `edit_plugin_file` - edit 'plugin/' config files
local edit_plugin_file = function(filename)
  return string.format('<Cmd>edit %s/plugin/%s<CR>', vim.fn.stdpath('config'), filename)
end
local explore_at_project = '<Cmd>lua MiniFiles.open(vim.fn.getcwd())<CR>'
local explore_at_file = '<Cmd>lua MiniFiles.open(vim.api.nvim_buf_get_name(0))<CR>'
local explore_quickfix = function()
  vim.cmd(vim.fn.getqflist({ winid = true }).winid ~= 0 and 'cclose' or 'copen')
end
local explore_locations = function()
  vim.cmd(vim.fn.getloclist(0, { winid = true }).winid ~= 0 and 'lclose' or 'lopen')
end

nmap_leader('ed', explore_at_project,                        'Explorer')
nmap_leader('ef', explore_at_file,                           'File directory')
nmap_leader('ei', '<Cmd>edit $MYVIMRC<CR>',                  'init.lua')
nmap_leader('ek', edit_plugin_file('20_keymaps.lua'),        'Keymaps config')
nmap_leader('em', edit_plugin_file('30_mini.lua'),           'MINI config')
nmap_leader('en', '<Cmd>Fidget history<CR>',                  'Notifications')
nmap_leader('eo', edit_plugin_file('10_options.lua'),        'Options config')
nmap_leader('ep', edit_plugin_file('40_lsp.lua'),            'LSP config')
nmap_leader('eq', explore_quickfix,                          'Quickfix list')
nmap_leader('eQ', explore_locations,                         'Location list')

-- g is for 'Git'. Common usage:
-- - `<Leader>gs` - show information at cursor
-- - `<Leader>go` - toggle 'mini.diff' overlay to show in-buffer unstaged changes
-- - `<Leader>gd` - show unstaged changes as a patch in separate tabpage
-- - `<Leader>gL` - show Git log of current file
-- `<Leader>gg` opens lazygit; see 'plugin/50_lazygit.lua'.
local git_log_cmd = [[Git log --pretty=format:\%h\ \%as\ │\ \%s --topo-order]]
local git_log_buf_cmd = git_log_cmd .. ' --follow -- %'

nmap_leader('ga', '<Cmd>Git diff --cached<CR>',              'Added diff')
nmap_leader('gA', '<Cmd>Git diff --cached -- %<CR>',         'Added diff buffer')
nmap_leader('gc', '<Cmd>Git commit<CR>',                     'Commit')
nmap_leader('gC', '<Cmd>Git commit --amend<CR>',             'Commit amend')
nmap_leader('gd', '<Cmd>Git diff<CR>',                       'Diff')
nmap_leader('gD', '<Cmd>Git diff -- %<CR>',                  'Diff buffer')
nmap_leader('gl', '<Cmd>' .. git_log_cmd .. '<CR>',          'Log')
nmap_leader('gL', '<Cmd>' .. git_log_buf_cmd .. '<CR>',      'Log buffer')
nmap_leader('go', '<Cmd>lua MiniDiff.toggle_overlay()<CR>',  'Toggle overlay')
nmap_leader('gs', '<Cmd>lua MiniGit.show_at_cursor()<CR>',   'Show at cursor')

xmap_leader('gs', '<Cmd>lua MiniGit.show_at_cursor()<CR>',   'Show at selection')

-- l is for 'Language'. Common usage:
-- - `<Leader>ld` - show more diagnostic details in a floating window
-- - `<Leader>lr` - perform rename via LSP
-- - `<Leader>ls` - navigate to source definition of symbol under cursor
--
-- NOTE: most LSP mappings represent a more structured way of replacing built-in
-- LSP mappings (like `:h gra` and others). This is needed because `gr` is mapped
-- by an "replace" operator in 'mini.operators' (which is more commonly used).
nmap_leader('la', '<Cmd>lua vim.lsp.buf.code_action()<CR>',      'Actions')
nmap_leader('ld', '<Cmd>lua vim.diagnostic.open_float()<CR>',    'Diagnostic popup')
nmap_leader('lq', function()
  vim.lsp.buf.code_action({
    context = { only = { 'quickfix' } },
    apply = true,
  })
end, 'Apply quickfix' )

nmap_leader('lf', '<Cmd>lua require("conform").format()<CR>',    'Format')
nmap_leader('li', '<Cmd>lua vim.lsp.buf.implementation()<CR>',   'Implementation')
nmap_leader('lh', '<Cmd>lua vim.lsp.buf.hover()<CR>',            'Hover')
nmap_leader('ll', '<Cmd>lua vim.lsp.codelens.run()<CR>',         'Lens')
nmap_leader('lr', '<Cmd>lua vim.lsp.buf.rename()<CR>',           'Rename')
nmap_leader('lR', '<Cmd>lua vim.lsp.buf.references()<CR>',       'References')
nmap_leader('ls', '<Cmd>lua vim.lsp.buf.definition()<CR>',       'Source definition')
nmap_leader('lt', '<Cmd>lua vim.lsp.buf.type_definition()<CR>',  'Type definition')

xmap_leader('lf', '<Cmd>lua require("conform").format()<CR>',    'Format selection')

-- m is for 'Map'. Common usage:
-- - `<Leader>mt` - toggle map from 'mini.map' (closed by default)
-- - `<Leader>mf` - focus on the map for fast navigation
-- - `<Leader>ms` - change map's side (if it covers something underneath)
nmap_leader('mf', '<Cmd>lua MiniMap.toggle_focus()<CR>',     'Focus (toggle)')
nmap_leader('mr', '<Cmd>lua MiniMap.refresh()<CR>',          'Refresh')
nmap_leader('ms', '<Cmd>lua MiniMap.toggle_side()<CR>',      'Side (toggle)')
nmap_leader('mt', '<Cmd>lua MiniMap.toggle()<CR>',           'Toggle')

-- o is for 'Other'. Common usage:
-- - `<Leader>oz` - toggle between "zoomed" and regular view of current buffer
-- `<Leader>oe` / `<Leader>op` open tool windows; see 'plugin/94_completion.lua'.
nmap_leader('or', '<Cmd>lua MiniMisc.resize_window()<CR>',   'Resize to default width')
nmap_leader('ot', '<Cmd>lua MiniTrailspace.trim()<CR>',      'Trim trailspace')
nmap_leader('oz', '<Cmd>lua MiniMisc.zoom()<CR>',            'Zoom toggle')

-- t is for 'Terminal'
nmap_leader('tT', '<Cmd>horizontal term<CR>',                'Terminal (horizontal)')
nmap_leader('tt', '<Cmd>vertical term<CR>',                  'Terminal (vertical)')

-- v is for 'Visits'. Common usage:
-- - `<Leader>vv` - add    "core" label to current file.
-- - `<Leader>vV` - remove "core" label to current file.
-- - `<Leader>vc` - pick among all files with "core" label.
local make_pick_core = function(cwd, desc)
  return function()
    local sort_latest = MiniVisits.gen_sort.default({ recency_weight = 1 })
    local local_opts = { cwd = cwd, filter = 'core', sort = sort_latest }
    MiniExtra.pickers.visit_paths(local_opts, { source = { name = desc } })
  end
end

nmap_leader('vc', make_pick_core('', 'Core visits (all)'),   'Core visits (all)')
nmap_leader('vC', make_pick_core(nil, 'Core visits (cwd)'),  'Core visits (cwd)')
nmap_leader('vv', '<Cmd>lua MiniVisits.add_label("core")<CR>',     'Add "core" label')
nmap_leader('vV', '<Cmd>lua MiniVisits.remove_label("core")<CR>',  'Remove "core" label')
nmap_leader('vl', '<Cmd>lua MiniVisits.add_label()<CR>',     'Add label')
nmap_leader('vL', '<Cmd>lua MiniVisits.remove_label()<CR>',  'Remove label')
-- stylua: ignore end
