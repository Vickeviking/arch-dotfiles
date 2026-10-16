return {
  "nvim-lualine/lualine.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  config = function()
    local lualine = require("lualine")
    local lazy_status = require("lazy.status")

    -- Colors from the active desk-theme palette (~/.config/themes/current/nvim.lua);
    -- falls back to the old gruvbox colors if the palette is missing.
    local function palette()
      local ok, p = pcall(dofile, vim.fn.expand("~/.config/themes/current/nvim.lua"))
      if ok and type(p) == "table" then
        return {
          bg = p.panel, fg = p.text, normal = p.accent, insert = p.ok, visual = p.ansi[14],
          command = p.ansi[12], replace = p.alert, accent = p.accent,
          inactive_bg = p.surface, inactive_fg = p.muted,
        }
      end
      return {
        bg = "#282828", fg = "#ebdbb2", normal = "#d3869b", insert = "#98971a", visual = "#458588",
        command = "#d79921", replace = "#cc241d", accent = "#d65d0e",
        inactive_bg = "#3c3836", inactive_fg = "#a89984",
      }
    end

    local function theme(c)
      local function mode(color)
        return {
          a = { bg = color, fg = c.bg, gui = "bold" },
          b = { bg = c.bg, fg = c.fg },
          c = { bg = c.bg, fg = c.fg },
        }
      end
      return {
        normal = mode(c.normal),
        insert = mode(c.insert),
        visual = mode(c.visual),
        command = mode(c.command),
        replace = mode(c.replace),
        inactive = {
          a = { bg = c.inactive_bg, fg = c.inactive_fg, gui = "bold" },
          b = { bg = c.inactive_bg, fg = c.inactive_fg },
          c = { bg = c.inactive_bg, fg = c.inactive_fg },
        },
      }
    end

    local function setup()
      local c = palette()
      lualine.setup({
        options = {
          theme = theme(c),
        },
        sections = {
          lualine_c = {
            {
              "filename",
              path = 1,
            },
          },
          lualine_x = {
            {
              lazy_status.updates,
              cond = lazy_status.has_updates,
              color = { fg = c.accent },
            },
            { "encoding" },
            { "fileformat" },
            { "filetype" },
          },
        },
      })
    end

    setup()

    -- desk-theme switches re-run :colorscheme desk; rebuild the statusline with the new palette
    vim.api.nvim_create_autocmd("ColorScheme", {
      group = vim.api.nvim_create_augroup("VangoLualineDesk", { clear = true }),
      pattern = "desk",
      callback = setup,
    })
  end,
}
