local add = vim.pack.add
-- Also load immediately in headless instances: Galley's inverse search runs
-- `nvim --headless -c 'VimtexInverseSearch ...'` with no file arguments, and
-- the command must exist by the time `-c` is executed.
local now_if_args = #vim.api.nvim_list_uis() == 0 and Config.now or Config.now_if_args

-- `now_if_args`, matching 'plugin/40_lsp.lua': the `vim.g.vimtex_*` settings
-- below have to be in place before VimTeX's ftplugin runs, which happens during
-- startup only when Neovim is started on a file (`nvim paper.tex`). Otherwise
-- this is deferred, and the next event-loop tick is still long before any
-- `:edit` can open a `tex` buffer.
now_if_args(function()
	add({ { src = "https://github.com/mryodo/pdftui", version = "mryodo" } })
	require("pdftui").setup({
		pdf_path = nil, -- auto-detected from .tex file
		split = true, -- false = open in new tab, true = split
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
	-- Conceal ---------------------------------------------------------------
	-- Requires VimTeX's own syntax engine, which is why tree-sitter highlighting
	-- is skipped for 'tex' in 'plugin/40_lsp.lua'. 'conceallevel' is set per
	-- buffer in 'after/ftplugin/tex.lua'.
	vim.g.tex_conceal = "abdmg"
	vim.g.vimtex_syntax_conceal = {
		accents = 1, -- \"o  ->  ö
		ligatures = 1, -- ``x''  ->  “x”
		cites = 1,
		fancy = 1, -- \item  ->  ◦
		spacing = 1, -- \quad and friends
		greek = 1, -- \alpha  ->  α
		math_bounds = 0, -- keep $ … $ visible so math boundaries stay obvious
		math_delimiters = 1, -- \left( -> (
		math_fracs = 1, -- \frac{1}{2} -> ½-style
		math_super_sub = 1, -- x^2 -> x²
		math_symbols = 1, -- \to -> →
		sections = 0, -- keep \section{...} spelled out
		styles = 1, -- \textbf{x} rendered bold
		texTabularChar = 1,
	}

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
	vim.g.vimtex_log_ignore = { -- Suppress specific log messages
		"Underfull",
		"Overfull",
		"specifier changed to",
		"Token not allowed in a PDF string",
	}

	-- Other settings
	vim.g.vimtex_mappings_enabled = false -- Disable default mappings
	vim.g.tex_flavor = "latex" -- Set file type for TeX files
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
