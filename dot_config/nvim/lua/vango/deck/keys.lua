-- The rail's keyboard map as a pure function, a port of Watchtower's
-- src/keys.rs so both feel the same and it can be tested headless.
--
-- action(key, cur, tabs, g_armed) -> { kind = ..., index = ... }
--   kinds: "select" (index), "enter", "close", "help", "search", "arm_g", "ignore"

local M = {}

function M.action(key, cur, tabs, g_armed)
  if key == "<Esc>" or key == "q" then
    return { kind = "close" }
  end
  if key == "<CR>" or key == "l" or key == "<C-l>" then
    return { kind = "enter" }
  end
  if key == "j" or key == "<Down>" or key == "<Tab>" then
    return { kind = "select", index = cur % tabs + 1 }
  end
  if key == "k" or key == "<Up>" or key == "<S-Tab>" then
    return { kind = "select", index = (cur - 2) % tabs + 1 }
  end
  if key == "?" then
    return { kind = "help" }
  end
  if key == "/" then
    return { kind = "search" }
  end
  if key == "G" then
    return { kind = "select", index = tabs }
  end
  if key == "g" then
    if g_armed then
      return { kind = "select", index = 1 }
    end
    return { kind = "arm_g" }
  end
  -- 1 … 9 are tabs 1 … 9, 0 is tab 10
  local d = tonumber(key)
  if d and #key == 1 then
    local index = d == 0 and 10 or d
    if index <= tabs then
      return { kind = "select", index = index }
    end
  end
  return { kind = "ignore" }
end

-- every key the rail listens to, so ui.lua can map exactly these
M.rail_keys = {
  "<Esc>", "q", "<CR>", "l", "<C-l>", "j", "k", "<Down>", "<Up>", "<Tab>", "<S-Tab>",
  "?", "/", "G", "g", "1", "2", "3", "4", "5", "6", "7", "8", "9", "0",
}

return M
