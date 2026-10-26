-- ┌────────────────────────────────┐
-- │ Tree-sitter, LSP and formatting │
-- └────────────────────────────────┘
--
-- Language tooling only. Colorschemes live in 'plugin/93_ui.lua'.
-- Per-server settings can also go in 'after/lsp/<name>.lua' (see `:h vim.lsp.config()`).

local add = vim.pack.add
local now_if_args, later = Config.now_if_args, Config.later

-- Tree-sitter ================================================================
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
		"markdown_inline",
		"typescript",
		"tsx",
		"astro",
		"json",
		"toml",
		"yaml",
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
	-- 'tex' is deliberately excluded: VimTeX's own syntax engine drives
	-- highlighting there, which is what makes conceal (`\alpha` shown as α),
	-- `vimtex#syntax#in_mathzone()` and the `` ` `` math imaps work -- none of
	-- which survive a tree-sitter highlighter. The tree-sitter *parser* is still
	-- created on demand (by `snacks.image`, folds, `mini.ai`, ...), so only
	-- highlighting is given up. See `:h vimtex-faq-treesitter`.
	local vimtex_owned = { tex = true, plaintex = true }
	local ts_start = function(ev)
		if vimtex_owned[vim.bo[ev.buf].filetype] then
			return
		end
		vim.treesitter.start(ev.buf)
	end
	Config.new_autocmd("FileType", filetypes, ts_start, "Start tree-sitter")

	-- Register out-of-tree parsers so that `:TSUpdate` knows how to build them
	local register_extra_parsers = function()
		local parsers = require("nvim-treesitter.parsers")
		parsers.asciidoc = {
			install_info = {
				branch = "master",
				location = "tree-sitter-asciidoc",
				queries = "queries/asciidoc/",
				requires = { "asciidoc_inline" },
				url = "https://github.com/cathaysia/tree-sitter-asciidoc",
			},
		}
		parsers.asciidoc_inline = {
			install_info = {
				branch = "master",
				location = "tree-sitter-asciidoc_inline",
				queries = "queries/asciidoc_inline",
				url = "https://github.com/cathaysia/tree-sitter-asciidoc",
			},
		}
	end
	Config.new_autocmd("User", "TSUpdate", register_extra_parsers, "Register extra parsers")
end)

-- Language servers ===========================================================
now_if_args(function()
	add({ "https://github.com/neovim/nvim-lspconfig" })

	-- LaTeX/BibTeX formatter and linter. Not shipped by 'nvim-lspconfig', so the
	-- full client config is spelled out here.
	vim.lsp.config.badness = {
		cmd = { "badness", "lsp" },
		filetypes = { "tex", "plaintex", "bib" },
		root_markers = { "badness.toml", ".git" },
		init_options = { lineWidth = 1000, indentWidth = 2, wrap = "sentence" },
	}

	-- Julia. `jetls` reports references through a client-side command.
	vim.lsp.config("jetls", {
		cmd = { "jetls", "serve" },
		filetypes = { "julia" },
		root_markers = { "Project.toml" },
		commands = {
			["editor.action.showReferences"] = function(command, ctx)
				local client = assert(vim.lsp.get_client_by_id(ctx.client_id))
				local file_uri, position, references = unpack(command.arguments)
				local items = vim.lsp.util.locations_to_items(references, client.offset_encoding)
				vim.fn.setqflist({}, " ", { title = command.title, items = items })
				vim.lsp.util.show_document({
					uri = file_uri,
					range = { start = position, ["end"] = position },
				}, client.offset_encoding)
				vim.cmd("botright copen")
			end,
		},
	})

	vim.lsp.config("tsserver", {
		cmd = { "typescript-language-server", "--stdio" },
		filetypes = { "typescript", "typescriptreact" },
		root_markers = { "package.json", "tsconfig.json", ".git" },
	})

	-- Resolve the project's TypeScript per workspace, not once at startup.
	-- `params` is already built from `init_options` here, so it is edited directly.
	local project_tsdk = function(params, config)
		local root = config.root_dir or vim.fn.getcwd()
		params.initializationOptions = vim.tbl_deep_extend("force", params.initializationOptions or {}, {
			typescript = { tsdk = root .. "/node_modules/typescript/lib" },
		})
	end

	vim.lsp.config("astro", {
		cmd = { "astro-ls", "--stdio" },
		filetypes = { "astro" },
		root_markers = { "package.json", "tsconfig.json", "jsconfig.json", ".git" },
		before_init = project_tsdk,
	})

	vim.lsp.config("mdx_analyzer", { before_init = project_tsdk })

	-- Not enabled below, kept so that re-enabling is a one-line change.
	vim.lsp.config("ltex", {
		settings = { ltex = { checkFrequency = "save" } },
	})

	vim.lsp.enable({
		"astro",
		"badness",
		"jetls",
		"lua_ls", -- configured in 'after/lsp/lua_ls.lua'
		"marksman",
		"mdx_analyzer",
		"sourcekit",
		"taplo",
		"tsserver",
		"yamlls",
	})

	-- Off by default (configured in 'after/lsp/harper_ls.lua'): spell/grammar
	-- checking on every keystroke is noisy enough to want opt-in rather than
	-- opt-out. `:HarperToggle` starts it on demand.
	--
	-- `vim.lsp.enable(name, false)` stops future autostart, but leaves any
	-- already-running client attached, so that client is stopped explicitly too.
	vim.api.nvim_create_user_command("HarperToggle", function()
		local running = vim.lsp.get_clients({ name = "harper_ls" })
		if #running > 0 then
			vim.lsp.enable("harper_ls", false)
			for _, client in ipairs(running) do
				client:stop()
			end
			vim.notify("harper-ls disabled")
		else
			vim.lsp.enable("harper_ls", true)
			if vim.tbl_contains(vim.lsp.config.harper_ls.filetypes, vim.bo.filetype) then
				vim.lsp.start(vim.lsp.config.harper_ls)
			end
			vim.notify("harper-ls enabled")
		end
	end, { desc = "Toggle harper-ls spell/grammar checking" })
end)

-- Diagnostics display ========================================================
later(function()
	add({ "https://github.com/rachartier/tiny-inline-diagnostic.nvim" })
	require("tiny-inline-diagnostic").setup({
		options = {
			show_source = { enabled = true },
			add_messages = { display_count = true },
			multilines = { enabled = true },
		},
	})
end)

-- Formatting =================================================================
later(function()
	add({ "https://github.com/stevearc/conform.nvim" })
	require("conform").setup({
		default_format_opts = {
			-- Allow formatting from LSP server if no dedicated formatter is available
			lsp_format = "fallback",
		},
		format_on_save = function(bufnr)
			-- Disable with `:FormatDisable` / `:FormatDisable!`
			if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
				return
			end
			return { timeout_ms = 50000, lsp_format = "fallback" }
		end,
		formatters = {
			-- Not used by default: `tex` is formatted by the `badness` language
			-- server above. Add `tex = { "badness" }` below to use the CLI instead.
			badness = {
				command = "badness",
				args = { "format", "--wrap=semantic", "--stdin-filepath", "$FILENAME", "-" },
				stdin = true,
			},
		},
		-- Map of filetype to formatters. Filetypes absent here fall back to the
		-- attached language server (see `default_format_opts`), which is how
		-- `tex` is formatted.
		formatters_by_ft = {
			astro = { "prettier" },
			css = { "prettier" },
			html = { "prettier" },
			javascript = { "prettier" },
			julia = { "runic" },
			lua = { "stylua" },
			markdown = { "prettierd" },
			mdx = { "prettier" },
			toml = { "taplo" },
			typescript = { "prettier" },
			typescriptreact = { "prettier" },
			yaml = { "prettier" },
		},
	})

	vim.api.nvim_create_user_command("FormatDisable", function(args)
		-- `:FormatDisable!` disables formatting just for the current buffer
		if args.bang then
			vim.b.disable_autoformat = true
		else
			vim.g.disable_autoformat = true
		end
	end, { desc = "Disable autoformat-on-save", bang = true })

	vim.api.nvim_create_user_command("FormatEnable", function()
		vim.b.disable_autoformat = false
		vim.g.disable_autoformat = false
	end, { desc = "Re-enable autoformat-on-save" })
end)

-- Server/tool installer ======================================================
later(function()
	add({ "https://github.com/mason-org/mason.nvim" })
	add({ "https://github.com/mason-org/mason-lspconfig.nvim" })
	require("mason").setup()
	require("mason-lspconfig").setup()
end)
