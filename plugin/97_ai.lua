-- ┌──────────────┐
-- │ AI assistants │
-- └──────────────┘

local add = vim.pack.add
local later = Config.later

-- opencode ===================================================================
-- Deferred: this block only registers keymaps and a `vim.g` table, neither of
-- which can be reached before the first event-loop tick.
later(function()
	vim.pack.add({
		{
			src = "https://github.com/nickjvandyke/opencode.nvim",
			version = vim.version.range("*"), -- Latest stable release
		},
	})

	---@type opencode.Opts
	vim.g.opencode_opts = {
		-- Your configuration, if any; goto definition on the type for details
	}

	-- Recommended/example keymaps
	vim.keymap.set({ "n", "x" }, "<C-a>", function()
		require("opencode").ask("@this: ")
	end, { desc = "Ask OpenCode…" })
	vim.keymap.set({ "n", "x" }, "<C-x>", function()
		require("opencode").select()
	end, { desc = "Select OpenCode…" })
	vim.keymap.set({ "n", "x" }, "go", function()
		return require("opencode").operator("@this ")
	end, { desc = "Append range to OpenCode", expr = true })
	vim.keymap.set({ "n" }, "goo", function()
		return require("opencode").operator("@this ") .. "_"
	end, { desc = "Append line to OpenCode", expr = true })
	vim.keymap.set({ "n" }, "<S-C-u>", function()
		require("opencode").command("session.half.page.up")
	end, { desc = "Scroll OpenCode up" })
	vim.keymap.set({ "n" }, "<S-C-d>", function()
		require("opencode").command("session.half.page.down")
	end, { desc = "Scroll OpenCode down" })
end)

-- Claude Code ================================================================
later(function()
	add({ "https://github.com/coder/claudecode.nvim" })
	require("claudecode").setup()

	vim.keymap.set("n", "<leader>a", "<nop>", { desc = "AI/Claude Code" })
	vim.keymap.set("n", "<leader>ac", "<cmd>ClaudeCode<cr>", { desc = "Toggle Claude" })
	vim.keymap.set("n", "<leader>af", "<cmd>ClaudeCodeFocus<cr>", { desc = "Focus Claude" })
	vim.keymap.set("n", "<leader>ar", "<cmd>ClaudeCode --resume<cr>", { desc = "Resume Claude" })
	vim.keymap.set("n", "<leader>aC", "<cmd>ClaudeCode --continue<cr>", { desc = "Continue Claude" })
	vim.keymap.set("n", "<leader>am", "<cmd>ClaudeCodeSelectModel<cr>", { desc = "Select Claude model" })
	vim.keymap.set("n", "<leader>ab", "<cmd>ClaudeCodeAdd %<cr>", { desc = "Add current buffer" })
	vim.keymap.set("v", "<leader>as", "<cmd>ClaudeCodeSend<cr>", { desc = "Send to Claude" })
	vim.keymap.set("n", "<leader>aa", "<cmd>ClaudeCodeDiffAccept<cr>", { desc = "Accept diff" })
	vim.keymap.set("n", "<leader>ad", "<cmd>ClaudeCodeDiffDeny<cr>", { desc = "Deny diff" })

	vim.api.nvim_create_autocmd("FileType", {
		pattern = { "NvimTree", "neo-tree", "oil", "minifiles", "netrw", "snacks_picker_list" },
		callback = function(args)
			vim.keymap.set("n", "<leader>as", "<cmd>ClaudeCodeTreeAdd<cr>", {
				buffer = args.buf,
				desc = "Add file",
			})
		end,
	})
end)
