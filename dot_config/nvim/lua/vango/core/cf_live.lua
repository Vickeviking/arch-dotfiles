-- cf live (Viktor 2026-09-29, Arcturon T-1405): every save of a file inside a
-- code-fluency exercise pushes the code to Arcturon, so Arc always reads the
-- latest version when asked about the exercise.
--
-- `cf save <file>` finds the exercise from the path and exits quietly when
-- the file is in none. It runs as a detached job: the editor never waits, and
-- a failed push (offline, Arcturon down) is simply redone by the next save.
-- One job per buffer at a time — a burst of :w does not become a burst of
-- uploads; the save that lands while one is running is picked up after it.

local M = {}

local ROOT = vim.fn.expand("~/school/code-fluency/")
local running = {}
local again = {}

local function push(buf, file)
	if running[buf] then
		again[buf] = file
		return
	end
	if vim.fn.executable("cf") == 0 then
		return
	end
	running[buf] = vim.fn.jobstart({ "cf", "save", file }, {
		detach = false,
		on_exit = function()
			running[buf] = nil
			local next_file = again[buf]
			again[buf] = nil
			if next_file then
				push(buf, next_file)
			end
		end,
	})
	if running[buf] <= 0 then
		running[buf] = nil
	end
end

vim.api.nvim_create_autocmd("BufWritePost", {
	pattern = { ROOT .. "cpp/*", ROOT .. "rust/*" },
	desc = "Push the code-fluency exercise to Arc on save",
	callback = function(ev)
		push(ev.buf, vim.api.nvim_buf_get_name(ev.buf))
	end,
})

return M
