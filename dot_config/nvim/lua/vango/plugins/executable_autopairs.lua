return {
  "windwp/nvim-autopairs",
  event = { "InsertEnter" },
  config = function()
    -- import nvim-autopairs
    local autopairs = require("nvim-autopairs")

    -- configure autopairs
    autopairs.setup({
      check_ts = true, -- enable treesitter
      ts_config = {
        lua = { "string" }, -- don't add pairs in lua string treesitter nodes
        javascript = { "template_string" }, -- don't add pairs in javascript template_string treesitter nodes
        java = false, -- don't check treesitter on java
        rust = {}, -- adjust if you want specific behavior for Rust
        c = {},    -- adjust if you want specific behavior for C
      },
    })
    -- brackets after accepting a completion come from blink (accept.auto_brackets)
  end,
}

