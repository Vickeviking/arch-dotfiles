-- RustOwl: rest the cursor on a variable in Rust and it underlines where the
-- value lives, where it's borrowed (& / &mut), moved, and where a borrow
-- outlives it. Binary: ~/.rustowl (prebuilt v0.4.0 + its own toolchain),
-- linked as ~/.local/bin/rustowl. Off by default, Space Ro toggles it; legend in the deck (Ownership).
return {
	"cordx56/rustowl",
	version = "*",
	lazy = false, -- the plugin lazy-loads itself on Rust buffers
	opts = function()
		local p = require("vango.deck.theme").palette()
		local a = p.ansi
		return {
			auto_attach = true,
			auto_enable = false, -- off by default; Space Ro turns it on
			idle_time = 500,
			highlight_style = "undercurl",
			colors = {
				lifetime = p.ok, -- where the value is alive
				imm_borrow = a[13], -- & borrow (blue)
				mut_borrow = a[14], -- &mut borrow (magenta)
				move = p.accent, -- moved out
				call = a[12], -- passed to a call (yellow)
				outlive = p.alert, -- a borrow that outlives the value: the error
			},
			client = {
				-- absolute path: nvim started from a launcher doesn't get zsh's PATH
				cmd = { vim.fn.executable(vim.fn.expand("~/.local/bin/rustowl")) == 1 and vim.fn.expand("~/.local/bin/rustowl") or "rustowl" },
				on_attach = function(_, buffer)
					vim.keymap.set("n", "<leader>Ro", function()
						require("rustowl").toggle(buffer)
					end, { buffer = buffer, desc = "RustOwl: toggle ownership underlines" })
				end,
			},
		}
	end,
}
