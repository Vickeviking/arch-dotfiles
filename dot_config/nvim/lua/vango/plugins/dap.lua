-- Debugging: nvim-dap + nvim-dap-view (panel, hover, inline values), codelldb from mason.
-- rustaceanvim finds codelldb itself (through xray-dap); Space dd picks a Rust target to debug.
-- X-ray (lua/vango/xray) shows memory at every stop: inline notes and Space dx.
-- Keys are listed in the deck (Space r → Debugger) and under Space d in which-key.

local function dap()
	return require("dap")
end

local function debug_target()
	if vim.bo.filetype == "rust" and vim.fn.exists(":RustLsp") == 2 then
		vim.cmd.RustLsp("debuggables")
	else
		dap().continue()
	end
end

-- Space dk works like K: the value pops up without taking the cursor, any
-- move closes it, and Space dk again jumps in (Enter expands, q/Esc closes).
-- dap-view's default enters the 1-line float, which traps j/k.
local function hover_value()
	local dv_state = require("dap-view.state")
	-- strict boolean: dap-view reads enter == nil as "enter"
	local was_open = dv_state.hover_winnr ~= nil and vim.api.nvim_win_is_valid(dv_state.hover_winnr)
	require("dap-view").hover(nil, was_open)
	if was_open then
		return
	end
	local src = vim.api.nvim_get_current_win()
	local pos = vim.api.nvim_win_get_cursor(src)
	vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "InsertEnter", "BufLeave" }, {
		buffer = vim.api.nvim_win_get_buf(src),
		callback = function(ev)
			local w = dv_state.hover_winnr
			if not (w and vim.api.nvim_win_is_valid(w)) then
				return true -- already gone: drop this autocmd
			end
			if ev.event == "BufLeave" then
				-- decide after the jump lands: into the popup keeps it open
				vim.schedule(function()
					if vim.api.nvim_win_is_valid(w) and vim.api.nvim_get_current_win() ~= w then
						vim.api.nvim_win_close(w, true)
					end
				end)
				return true
			end
			if vim.api.nvim_get_current_win() == w then
				return
			end
			-- CursorMoved can fire without a real move; only close on one
			local now = vim.api.nvim_win_get_cursor(0)
			if ev.event == "CursorMoved" and now[1] == pos[1] and now[2] == pos[2] then
				return
			end
			vim.api.nvim_win_close(w, true)
			return true
		end,
	})
end

return {
	{
		"mfussenegger/nvim-dap",
		dependencies = { "igorlfs/nvim-dap-view" },
		keys = {
			{ "<leader>dd", debug_target, desc = "Debug: pick a target (Rust: debuggables)" },
			{ "<leader>dl", function() dap().run_last() end, desc = "Debug: run last target again" },
			{ "<leader>db", function() dap().toggle_breakpoint() end, desc = "Debug: toggle breakpoint" },
			{ "<F9>", function() dap().toggle_breakpoint() end, desc = "Debug: toggle breakpoint" },
			{
				"<leader>dB",
				function()
					dap().set_breakpoint(vim.fn.input("Condition: "))
				end,
				desc = "Debug: conditional breakpoint",
			},
			{
				"<leader>dL",
				function()
					dap().set_breakpoint(nil, nil, vim.fn.input("Log message ({expr} works): "))
				end,
				desc = "Debug: logpoint",
			},
			{ "<leader>dc", function() dap().continue() end, desc = "Debug: start / continue" },
			{ "<F5>", function() dap().continue() end, desc = "Debug: start / continue" },
			{ "<leader>dn", function() dap().step_over() end, desc = "Debug: step over" },
			{ "<F10>", function() dap().step_over() end, desc = "Debug: step over" },
			{ "<leader>di", function() dap().step_into() end, desc = "Debug: step into" },
			{ "<F11>", function() dap().step_into() end, desc = "Debug: step into" },
			{ "<leader>do", function() dap().step_out() end, desc = "Debug: step out" },
			{ "<F12>", function() dap().step_out() end, desc = "Debug: step out" },
			{ "<leader>dC", function() dap().run_to_cursor() end, desc = "Debug: run to cursor" },
			{ "<leader>dk", hover_value, desc = "Debug: value under cursor (again: jump in)" },
			-- true: the program-output terminal hides/shows together with the view
			{ "<leader>dv", function() require("dap-view").toggle(true) end, desc = "Debug: toggle debug view + output" },
			{ "<leader>dw", function() require("dap-view").add_expr() end, desc = "Debug: watch word under cursor" },
			{ "<leader>dr", function() dap().repl.toggle() end, desc = "Debug: toggle REPL" },
			{ "<leader>dq", function() dap().terminate() end, desc = "Debug: stop" },
			{ "<leader>dx", function() require("vango.xray").toggle_panel() end, desc = "X-ray: memory map (stack, heap, pointers)" },
			{ "<leader>dX", function() require("vango.xray").toggle_inline() end, desc = "X-ray: all automatic views off/on (this nvim)" },
			{ "<leader>dm", function() require("vango.xray").toggle_sidebar() end, desc = "X-ray: memory sidebar show/hide" },
			{ "<leader>dW", function() require("vango.xray").toggle_window() end, desc = "X-ray: window (second screen) open/close" },
		},
		config = function()
			local function colors()
				local p = require("vango.deck.theme").palette()
				local mix = require("vango.deck.theme").mix
				local set = vim.api.nvim_set_hl
				set(0, "DapBreakpoint", { fg = p.alert })
				set(0, "DapBreakpointCondition", { fg = p.accent })
				set(0, "DapLogPoint", { fg = p.accent2 })
				set(0, "DapStopped", { fg = p.ok })
				set(0, "DapStoppedLine", { bg = mix(p.ok, p.surface, 0.14) })
				set(0, "NvimDapViewVirtualText", { fg = mix(p.accent2, p.muted, 0.6), italic = true })
			end
			colors()
			vim.api.nvim_create_autocmd("ColorScheme", { callback = colors })

			local sign = vim.fn.sign_define
			sign("DapBreakpoint", { text = "●", texthl = "DapBreakpoint" })
			sign("DapBreakpointCondition", { text = "◆", texthl = "DapBreakpointCondition" })
			sign("DapBreakpointRejected", { text = "○", texthl = "DapBreakpoint" })
			sign("DapLogPoint", { text = "◇", texthl = "DapLogPoint" })
			sign("DapStopped", { text = "▶", texthl = "DapStopped", linehl = "DapStoppedLine" })

			require("vango.xray").setup()

			require("dap-view").setup({
				auto_toggle = true, -- the view opens when a session starts and closes when it ends
				virtual_text = { enabled = true, position = "eol" },
				keymaps = { hover = { quit = { "q", "<Esc>" } } },
			})
		end,
	},
}
