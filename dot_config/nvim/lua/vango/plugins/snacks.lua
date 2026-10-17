-- PDFs and videos open in a real viewer instead of being converted inside nvim
-- (Viktor 2026-10-17: opening them could freeze nvim; ImageMagick also fails
-- on the big course PDFs). zathura for PDFs when installed, otherwise the
-- desktop default via xdg-open. The nvim buffer is closed right away.
local external = { "pdf", "mp4", "mov", "avi", "mkv", "webm" }

local function open_external(ev)
	local file = vim.fn.fnamemodify(ev.match, ":p")
	local ext = vim.fn.fnamemodify(file, ":e"):lower()
	local cmd = (ext == "pdf" and vim.fn.executable("zathura") == 1) and { "zathura", file } or { "xdg-open", file }
	vim.fn.jobstart(cmd, { detach = true })
	vim.notify(("Opened %s in %s"):format(vim.fn.fnamemodify(file, ":t"), cmd[1]))
	vim.schedule(function()
		if vim.api.nvim_buf_is_valid(ev.buf) then
			-- go back to where you were (or an empty buffer) and drop the placeholder
			local alt = vim.fn.bufnr("#")
			if alt > 0 and alt ~= ev.buf and vim.api.nvim_buf_is_valid(alt) then
				vim.api.nvim_set_current_buf(alt)
			else
				vim.cmd.enew()
			end
			pcall(vim.api.nvim_buf_delete, ev.buf, { force = true })
		end
	end)
end

return {
	"folke/snacks.nvim",
	priority = 1000,
	lazy = false,
	init = function()
		local patterns = {}
		for _, e in ipairs(external) do
			table.insert(patterns, "*." .. e)
			table.insert(patterns, "*." .. e:upper())
		end
		vim.api.nvim_create_autocmd("BufReadCmd", {
			group = vim.api.nvim_create_augroup("vango_external_viewer", { clear = true }),
			pattern = patterns,
			callback = open_external,
		})
	end,
	-- only the image module for now — notifications, dashboard etc. are
	-- already covered by nvim-notify/noice/alpha
	opts = {
		image = {
			enabled = true,
			-- still images only; PDFs and videos go to an external viewer (above)
			formats = { "png", "jpg", "jpeg", "gif", "bmp", "webp", "tiff", "heic", "avif", "icns" },
			doc = {
				-- render images inline in the buffer (markdown, html, css, ...)
				inline = true,
				-- and in hover floats where inline isn't possible
				float = true,
			},
		},
	},
}
