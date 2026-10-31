-- Inline images ---------------------------------------------------------------
-- `snacks.image` renders Typst math and `image(...)` calls inline. Off by
-- default, same trick as 'after/ftplugin/tex.lua': setting the attachment flag
-- before `snacks` attaches (from a `vim.schedule()` on `FileType`) makes it
-- skip this buffer. `\p` toggles the previews for the current buffer.
vim.b.snacks_image_attached = true

-- `snacks` has no per-buffer "off" switch once attached, so route its image
-- search through a flag: with `snacks_image_off` set it finds nothing and its
-- own update loop closes whatever is on screen.
-- Done on first use: `snacks` is set up in a `later()` and may not exist yet.
local function wrap_find_visible()
	local doc = Snacks.image.doc
	if doc._typst_toggle_wrapped then
		return
	end
	local find_visible = doc.find_visible
	doc.find_visible = function(buf, cb)
		if vim.b[buf].snacks_image_off then
			return cb({})
		end
		return find_visible(buf, cb)
	end
	doc._typst_toggle_wrapped = true
end

vim.keymap.set("n", "\\p", function()
	wrap_find_visible()
	local buf = vim.api.nvim_get_current_buf()
	if vim.b[buf].typst_previews then
		vim.b[buf].snacks_image_off = true
		Snacks.image.placement.clean(buf)
		vim.b[buf].typst_previews = false
	else
		vim.b[buf].snacks_image_off = nil
		vim.b[buf].typst_previews = true
		if vim.fn.exists("#snacks.image.inline." .. buf) == 1 then
			vim.api.nvim_exec_autocmds("WinScrolled", { group = "snacks.image.inline." .. buf, buffer = buf })
		else
			vim.b[buf].snacks_image_attached = nil
			Snacks.image.doc.attach(buf)
		end
	end
	vim.notify("Typst previews " .. (vim.b[buf].typst_previews and "on" or "off"))
end, { buffer = true, desc = "Toggle math/image previews" })

-- Compile ---------------------------------------------------------------------
-- `\ll` writes and runs `typst compile` on this file, like VimTeX's `\ll`.
vim.keymap.set("n", "\\ll", function()
	vim.cmd.update()
	vim.system({ "typst", "compile", vim.api.nvim_buf_get_name(0) }, { text = true }, function(r)
		vim.schedule(function()
			vim.notify(r.code == 0 and "Typst: compiled" or r.stderr, r.code == 0 and vim.log.levels.INFO or vim.log.levels.ERROR)
		end)
	end)
end, { buffer = true, desc = "Typst compile" })

-- Live view -------------------------------------------------------------------
-- `\lp` toggles `tinymist preview` (browser), `\lw` toggles `typst watch` and
-- opens the PDF in Skim (needs Skim's "Check for file changes" on).
-- Jobs are global so they survive re-sourcing and get killed on exit.
TypstJobs = TypstJobs or {}
vim.api.nvim_create_autocmd("VimLeavePre", {
	group = vim.api.nvim_create_augroup("typst_jobs", { clear = true }),
	callback = function()
		for _, job in pairs(TypstJobs) do
			job:kill("sigterm")
		end
	end,
})

local function toggle(name, cmd, on_stderr)
	local key = name .. ":" .. vim.api.nvim_buf_get_name(0)
	if TypstJobs[key] then
		TypstJobs[key]:kill("sigterm")
		TypstJobs[key] = nil
		return vim.notify(name .. " stopped")
	end
	TypstJobs[key] = vim.system(cmd, { text = true, stderr = on_stderr }, function()
		TypstJobs[key] = nil
	end)
	vim.notify(name .. " started")
end

vim.keymap.set("n", "\\lp", function()
	toggle("tinymist preview", { "tinymist", "preview", "--open", vim.api.nvim_buf_get_name(0) })
end, { buffer = true, desc = "Typst live preview (tinymist)" })

vim.keymap.set("n", "\\lw", function()
	vim.cmd.update()
	local file = vim.api.nvim_buf_get_name(0)
	local opened = false
	toggle("typst watch", { "typst", "watch", file }, function(_, data)
		-- open Skim once the first compile has written the PDF
		if not opened and data and data:find("compiled") then
			opened = true
			vim.system({ "open", "-a", "Skim", (file:gsub("%.typ$", ".pdf")) })
		end
	end)
end, { buffer = true, desc = "Typst watch + Skim" })

-- `\lh` toggles `typst watch` in HTML mode: built-in server with live reload.
vim.keymap.set("n", "\\lh", function()
	vim.cmd.update()
	local shown = false
	toggle("typst watch html", { "typst", "watch", vim.api.nvim_buf_get_name(0), "--features", "html", "--format", "html", "--open" }, function(_, data)
		local url = not shown and data and data:match("[Ss]erving at (%S+)")
		if url then
			shown = true
			vim.schedule(function() vim.notify("typst html: " .. url) end)
		end
	end)
end, { buffer = true, desc = "Typst HTML live preview" })
