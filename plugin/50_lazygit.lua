local later = Config.later

local function open_lazygit()
	-- Get dimensions
	local width = vim.o.columns
	local height = vim.o.lines
	local win_height = math.floor(height * 0.9)
	local win_width = math.floor(width * 0.9)

	-- Create buffer (will be auto-cleaned)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].bufhidden = "wipe"

	-- Create floating window
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = win_width,
		height = win_height,
		row = math.floor((height - win_height) / 2),
		col = math.floor((width - win_width) / 2),
		style = "minimal",
		border = "rounded",
	})

	-- Start lazygit (fresh every time)
	vim.fn.termopen("lazygit", {
		on_exit = function(_, exit_code)
			if vim.api.nvim_win_is_valid(win) then
				vim.api.nvim_win_close(win, true)
			end
			if exit_code == 0 then
				vim.cmd("checktime") -- Refresh file status
			end
		end,
	})

	vim.cmd("startinsert")
end

local function setup()
	vim.keymap.set("n", "<leader>gg", open_lazygit, { desc = "Open Lazygit (float)" })
	vim.keymap.set("n", "<C-g>", open_lazygit, { desc = "Open Lazygit (float)" })
end

later(setup)

-- now_if_args(function()
--   add({ 'https://github.com/103sbavert/lazygit.nvim' })
--   require("lazygit").setup({
--     config = function()
--       require("telescope").load_extension("lazygit")
--     end,
--   })
-- end)
