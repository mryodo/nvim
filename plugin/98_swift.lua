local add = vim.pack.add
local later = Config.later

later(function()
	add({ "https://github.com/devswiftzone/swift.nvim" })
	require("swift").setup({
		features = {
			-- Off: swift.nvim uses the deprecated lspconfig framework.
			-- sourcekit is enabled in 'plugin/40_lsp.lua' instead.
			lsp = { enabled = false },
			formatter = {
				format_on_save = true,
				tool = "swift-format", -- or "swiftformat"
			},
		},
	})

	-- Xcode projects (.xcodeproj/.xcworkspace); swift.nvim only handles SwiftPM.
	-- Needs: brew install xcbeautify xcode-build-server
	add({
		"https://github.com/MunifTanjim/nui.nvim",
		"https://github.com/wojciech-kulik/xcodebuild.nvim",
	})
	require("xcodebuild").setup({})

	local map = function(lhs, rhs, desc) vim.keymap.set("n", lhs, rhs, { desc = desc }) end
	map("<leader>xb", "<cmd>XcodebuildBuild<cr>", "Xcode build")
	map("<leader>xr", "<cmd>XcodebuildBuildRun<cr>", "Xcode build & run")
	map("<leader>xt", "<cmd>XcodebuildTest<cr>", "Xcode test")
	map("<leader>xs", "<cmd>XcodebuildSetup<cr>", "Xcode setup project")
	map("<leader>xx", "<cmd>XcodebuildPicker<cr>", "Xcode actions")
end)
