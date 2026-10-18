-- Trouble source: LSP document symbols for every file of the VimTeX project
-- (main file + `\input`/`\include`s). LSP symbols are per-file and the server
-- only answers for opened buffers, so each project file is loaded (unlisted)
-- and queried separately; items are built by Trouble's own LSP source, which
-- keeps kind icons and the foldable symbol tree.
local Lsp = require("trouble.sources.lsp")

local M = {}

M.config = {
	modes = {
		tex_symbols = {
			desc = "LaTeX project symbols (all VimTeX files)",
			source = "vimtex_toc",
			events = { "BufEnter", { event = "BufWritePost", main = true }, { event = "LspAttach", main = true } },
			groups = { { "filename", format = "{file_icon} {filename} {count}" } },
			sort = { "idx", "pos" },
			format = "{kind_icon} {symbol.name} {title:Comment} {pos}",
		},
	},
}

local method = "textDocument/documentSymbol"

---@param buf integer
---@param idx integer file order, so files are listed as in the project
---@param tries integer
---@param cb fun(items: trouble.Item[])
local function file_symbols(buf, idx, tries, cb)
	if #vim.lsp.get_clients({ bufnr = buf, method = method }) == 0 then
		-- freshly loaded buffer: give the server a moment to attach
		if tries <= 0 then
			return cb({})
		end
		return vim.defer_fn(function()
			file_symbols(buf, idx, tries - 1, cb)
		end, 100)
	end
	local uri = vim.uri_from_bufnr(buf)
	vim.lsp.buf_request_all(buf, method, { textDocument = { uri = uri } }, function(res)
		local items = {}
		for id, r in pairs(res) do
			local client = vim.lsp.get_client_by_id(id)
			if client and r.result then
				vim.list_extend(items, Lsp.results_to_items(client, r.result, uri))
			end
		end
		for _, item in ipairs(items) do
			item.idx = idx
			-- optional title of an environment: `\begin{theorem}[Title]`
			-- ponytail: single-line titles without nested `]`
			local line = vim.api.nvim_buf_get_lines(buf, item.pos[1] - 1, item.pos[1], false)[1] or ""
			item.title = item.kind == "Class" and line:match("\\begin%b{}%s*%[([^%]]+)%]")
		end
		cb(items)
	end)
end

function M.get(cb)
	if vim.fn.exists("b:vimtex") == 0 then
		return cb({})
	end
	local root = vim.fn.eval("b:vimtex.root")
	local files = vim.fn.eval("b:vimtex.get_sources({'refresh': 1})")
	local ret, pending = {}, #files
	if pending == 0 then
		return cb({})
	end
	for idx, file in ipairs(files) do
		local path = vim.fs.joinpath(root, file)
		local buf = vim.fn.bufadd(path)
		if not vim.api.nvim_buf_is_loaded(buf) then
			vim.fn.bufload(buf)
		end
		file_symbols(buf, idx, 30, function(items)
			vim.list_extend(ret, items)
			pending = pending - 1
			if pending == 0 then
				cb(ret)
			end
		end)
	end
end

return M
