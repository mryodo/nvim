local add = vim.pack.add
local now_if_args = Config.now_if_args

now_if_args(function()
	add({ "https://github.com/goerz/vim-slime" })
	add({
		"https://github.com/jmbuhr/otter.nvim",
		"https://github.com/nvim-treesitter/nvim-treesitter",
		"https://github.com/quarto-dev/quarto-nvim",
	})
	require("quarto").setup({
		debug = false,
		closePreviewOnExit = true,
		lspFeatures = {
			enabled = true,
			chunks = "curly",
			languages = { "r", "python", "julia", "bash", "html" },
			diagnostics = {
				enabled = true,
				triggers = { "BufWritePost" },
			},
			completion = {
				enabled = true,
			},
		},

		codeRunner = {
			enabled = true,
			default_method = "slime", -- "molten", "slime", "iron" or <function>
			ft_runners = {}, -- filetype to runner, ie. `{ python = "molten" }`.
			-- Takes precedence over `default_method`
			never_run = { "yaml" }, -- filetypes which are never sent to a code runner
		},
	})

	-- vim-slime sends text to a kitty window; `<Leader>s` sends the current
	-- line or selection, `<C-c><C-c>` does the same from Visual mode.
	vim.g.slime_target = "kitty"
	vim.g.slime_no_mappings = 1
	vim.g.slime_dont_ask_default = 1
	vim.g.slime_bracketed_paste = 0

	local slime_send = { noremap = true, silent = true, desc = "Send to SLIME" }
	vim.keymap.set("n", "<leader>s", ":SlimeSend<CR>", slime_send)
	vim.keymap.set("x", "<leader>s", ":'<,'>SlimeSend<CR>'>", slime_send)
	vim.keymap.set("x", "<c-c><c-c>", ":'<,'>SlimeSend<CR>'>", slime_send)

	local runner = require("quarto.runner")
	vim.keymap.set("n", "<leader>rc", runner.run_cell, { desc = "run cell", silent = true })
	vim.keymap.set("n", "<leader>ra", runner.run_above, { desc = "run cell and above", silent = true })
	vim.keymap.set("n", "<leader>rA", runner.run_all, { desc = "run all cells", silent = true })
	vim.keymap.set("n", "<leader>rl", runner.run_line, { desc = "run line", silent = true })
	vim.keymap.set("v", "<leader>rs", runner.run_range, { desc = "run visual range", silent = true })
	vim.keymap.set("n", "<localleader>RA", function()
		runner.run_all(true)
	end, { desc = "run all cells of all languages", silent = true })

	add({ "https://github.com/wurli/jet.nvim" })
	require("jet").setup({
		image = {
			-- Julia's GR backend (the Plots.jl default) sends both `image/png`
			-- and `image/svg+xml` for every plot, but jet.nvim only natively
			-- writes `png` data to disk - any other MIME subtype is treated as
			-- an error. Since `pairs()` iteration order isn't guaranteed, that
			-- svg entry intermittently gets processed and logs an error on
			-- what looks like every plot. Rasterise it with `magick` (already
			-- a dependency for the LaTeX/math image rendering below) instead
			-- of just erroring out.
			handlers = {
				svg = function(data, _mime, filepath)
					local png_path = filepath:gsub("%.svg$", ".png")
					local res = vim.system({ "magick", "svg:-", png_path }, { stdin = data }):wait()
					return res.code == 0 and png_path or false
				end,
			},
		},
	})

	-- Julia support for jet.nvim: talks to the IJulia Jupyter kernel (already
	-- registered under `~/Library/Jupyter/kernels/julia-1.12`), independent of
	-- the kitty-based 'julia-repl' setup below. Keymaps are buffer-local to
	-- `julia` so they don't leak into other filetypes or clash with the
	-- `<leader>j*` keymaps used by 'julia-repl'.
	vim.api.nvim_create_autocmd("FileType", {
		pattern = "julia",
		desc = "jet.nvim keymaps for Julia",
		callback = function(args)
			local jet_api = require("jet.api")

			local bufmap = function(mode, lhs, rhs, desc, opts)
				vim.keymap.set(
					mode,
					lhs,
					rhs,
					vim.tbl_extend("force", { buffer = args.buf, silent = true, desc = desc }, opts or {})
				)
			end

			bufmap("n", "<localleader>kk", function()
				jet_api.get_kernel({ filetype = "julia" }, function(k)
					k:term_toggle()
				end)
			end, "Toggle Julia kernel (Jet)")

			bufmap(
				{ "n", "x" },
				"<localleader>ks",
				jet_api.handle_motion(function(range)
					jet_api.get_kernel({
						filetype = "julia",
						current = true,
						status = { "connected", "connecting" },
					}, function(k)
						local code = range:code({ comments = false })
						if code then
							k:send_repl(code)
						end
					end)
				end),
				"Send code to Julia kernel (Jet)",
				{ expr = true }
			)

			bufmap({ "x", "o" }, "ie", function()
				local expr = jet_api.get_expr()
				if not expr then
					local pos = jet_api.next_expr_boundary({ current_ok = false, boundary = "start" })
					expr = pos and jet_api.get_expr(pos)
				end
				if expr then
					expr:textobject()
				end
			end, "[i]n [e]xpression (Jet)")

			bufmap("n", "]e", function()
				local pos = jet_api.next_expr_boundary({ direction = 1, boundary = "start" })
				if pos then
					vim.fn.cursor(pos:to_cursor())
				end
			end, "Next expression (Jet)")

			bufmap("n", "[e", function()
				local pos = jet_api.next_expr_boundary({ direction = -1, boundary = "start" })
				if pos then
					vim.fn.cursor(pos:to_cursor())
				end
			end, "Previous expression (Jet)")
		end,
	})

	vim.pack.add({
		{ src = "https://github.com/sheng-tse/jupynvim", version = vim.version.range("*") },
	})
	require("jupynvim").setup({})
	vim.api.nvim_create_autocmd("PackChanged", {
		callback = function(ev)
			local d = ev.data
			if d.spec.name == "jupynvim" and (d.kind == "install" or d.kind == "update") then
				dofile(d.path .. "/lua/jupynvim/install.lua").run({ dir = d.path })
			end
		end,
	})

	-- Julia REPL in a kitty window, see 'lua/julia-repl/'
	require("julia-repl.init").setup({
		listen_on = "unix:/tmp/kitty",

		julia = { "julia", "--project=@." },

		keymaps = {
			open = "<leader>jo",
			line = "<leader>jl",
			visual = "<leader>js",
			enclosing = "<leader>je",
			buffer = "<leader>jb",
			enter_normal = "<CR>",
			enter_visual = "<CR>",
		},
	})
end)
