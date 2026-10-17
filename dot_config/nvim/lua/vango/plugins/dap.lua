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
			{ "<leader>dk", function() require("dap-view").hover() end, desc = "Debug: value under cursor" },
			{ "<leader>dv", function() require("dap-view").toggle() end, desc = "Debug: toggle debug view" },
			{ "<leader>dw", function() require("dap-view").add_expr() end, desc = "Debug: watch word under cursor" },
			{ "<leader>dr", function() dap().repl.toggle() end, desc = "Debug: toggle REPL" },
			{ "<leader>dq", function() dap().terminate() end, desc = "Debug: stop" },
			{ "<leader>dx", function() require("vango.xray").toggle_panel() end, desc = "X-ray: memory map (stack, heap, pointers)" },
			{ "<leader>dX", function() require("vango.xray").toggle_inline() end, desc = "X-ray: all automatic views off/on (this nvim)" },
			{ "<leader>dm", function() require("vango.xray").toggle_sidebar() end, desc = "X-ray: memory sidebar show/hide" },
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
			})
		end,
	},
}
