return {
	"alexghergh/nvim-tmux-navigation",
	config = function()
		local n = require("nvim-tmux-navigation")
		n.setup({ disable_when_zoomed = true }) -- keeps behavior sane when a tmux pane is zoomed

		-- Float-aware <C-h>/<C-l> (Viktor 2026-09-01): when a popup (LSP hover
		-- via K, diagnostics, etc.) is open, <C-h> jumps INTO it so j/k scroll
		-- it like any window, and <C-l> from inside closes it and drops you
		-- back where you were. With no float open, both fall through to tmux
		-- navigation — split/pane movement is untouched.
		local function float_win()
			-- Only focusable floats count — noice/notify draw non-focusable
			-- corner floats that must never swallow the jump. Cursor-anchored
			-- floats (the K hover, diagnostics) win over screen-anchored ones.
			local fallback = nil
			for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
				local cfg = vim.api.nvim_win_get_config(win)
				if cfg.relative ~= "" and cfg.focusable ~= false then
					if cfg.relative == "cursor" or cfg.relative == "win" then
						return win
					end
					fallback = fallback or win
				end
			end
			return fallback
		end

		vim.keymap.set("n", "<C-h>", function()
			local float = float_win()
			if float and vim.api.nvim_get_current_win() ~= float then
				vim.api.nvim_set_current_win(float)
			else
				n.NvimTmuxNavigateLeft()
			end
		end, { silent = true, desc = "Into popup, else tmux left" })

		vim.keymap.set("n", "<C-l>", function()
			if vim.api.nvim_win_get_config(0).relative ~= "" then
				vim.api.nvim_win_close(0, false)
			else
				n.NvimTmuxNavigateRight()
			end
		end, { silent = true, desc = "Close popup if inside one, else tmux right" })

		vim.keymap.set("n", "<C-j>", n.NvimTmuxNavigateDown, { silent = true })
		vim.keymap.set("n", "<C-k>", n.NvimTmuxNavigateUp, { silent = true })
		vim.keymap.set("n", "<C-\\>", n.NvimTmuxNavigateLastActive, { silent = true })

		-- Terminal splits (debug output, Claude Code): C-h/j/k/l leave terminal
		-- mode and move, so you land in normal mode where j/k scroll. Floating
		-- terminals (Space z, lazygit, htop) keep the keys for the shell/app.
		local dirs = { h = "Left", j = "Down", k = "Up", l = "Right" }
		for key, dir in pairs(dirs) do
			local lhs = "<C-" .. key .. ">"
			vim.keymap.set("t", lhs, function()
				if vim.api.nvim_win_get_config(0).relative ~= "" then
					return lhs
				end
				return "<C-\\><C-n><Cmd>lua require('nvim-tmux-navigation').NvimTmuxNavigate" .. dir .. "()<CR>"
			end, { expr = true, silent = true, desc = "Terminal: window " .. dir:lower() })
		end

		-- Always: plugins (nvim-tree's C-k = Info, ...) set buffer-local
		-- C-h/j/k/l that shadow the global ones. Drop them in normal windows;
		-- floats (deck, telescope, hovers) keep their own.
		vim.api.nvim_create_autocmd({ "BufEnter", "LspAttach", "FileType" }, {
			group = vim.api.nvim_create_augroup("vango_nav_keys", { clear = true }),
			callback = function(ev)
				vim.schedule(function()
					if not vim.api.nvim_buf_is_valid(ev.buf) or vim.api.nvim_win_get_config(0).relative ~= "" then
						return
					end
					for key in pairs(dirs) do
						pcall(vim.keymap.del, "n", "<C-" .. key .. ">", { buffer = ev.buf })
					end
				end)
			end,
		})
	end,
}
