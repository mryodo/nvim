local add = vim.pack.add
local now, now_if_args, later = Config.now, Config.now_if_args, Config.later
later(function()
	add({ "https://github.com/3rd/image.nvim" })
	require("image").setup({
		build = false,
		processor = "magick_cli",
	})
end)
