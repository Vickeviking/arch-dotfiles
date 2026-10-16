-- ==================================================
--  KoolDots (2026)
--  Project URL: https://github.com/LinuxBeginnings
--  License: GNU GPLv3
--  SPDX-License-Identifier: GPL-3.0-or-later
-- ==================================================

-- User keybind overrides (auto-generated).
-- Add keybinds with bind("MODS", "KEY", fn, opts).
-- Example:
-- bind("SUPER", "Z", exec_cmd("ghostty"), { description = "Launch ghostty" })
-- Helper functions live in ${XDG_CONFIG_HOME:-$HOME/.config}/hypr/lua/user_keybinds_helper.lua so they can be updated separately.
local user_keybinds_helper = nil
do
  local source = (debug.getinfo(1, "S") or {}).source or ""
  local source_path = source:match("^@(.+)$")
  local source_dir = source_path and source_path:match("^(.*)/[^/]+$") or nil
  local home = os.getenv("HOME") or ""
  local candidate_paths = {
    source_dir and (source_dir .. "/../lua/user_keybinds_helper.lua") or nil,
    home ~= "" and (home .. "/.config/hypr/lua/user_keybinds_helper.lua") or nil,
    home ~= "" and (home .. "/.config/hypr/user_keybinds_helper.lua") or nil,
  }

  local tried_paths = {}
  for _, helper_path in ipairs(candidate_paths) do
    if helper_path then
      table.insert(tried_paths, helper_path)
      local f = io.open(helper_path, "r")
      if f then
        f:close()
        local loaded_ok, loaded_helpers = pcall(dofile, helper_path)
        if loaded_ok and type(loaded_helpers) == "table" and loaded_helpers.bind then
          user_keybinds_helper = loaded_helpers
          break
        end
      end
    end
  end

  if not user_keybinds_helper then
    error("Failed to load user_keybinds_helper.lua from: " .. table.concat(tried_paths, ", "))
  end
end
local exec_cmd = user_keybinds_helper.exec_cmd
local dispatch = user_keybinds_helper.dispatch
local bind = user_keybinds_helper.bind
local unbind = user_keybinds_helper.unbind

-- Converted from UserKeybinds.conf
bind("SUPER", "D", exec_cmd("pkill rofi || true && rofi -show drun -modi drun, filebrowser, run, window"))
bind("SUPER", "B", exec_cmd("google-chrome-stable"), { description = "Chrome" }) -- was firefox-hybrid (2026-10-16)
bind("SUPER SHIFT", "T", exec_cmd("pkill rofi || true && $HOME/.local/bin/desk-theme --rofi"), { description = "Desk theme picker" })
bind("SUPER", "A", dispatch("global", "quickshell:overviewToggle"))
bind("SUPER", "Return", exec_cmd("kitty"))
bind("SUPER", "E", exec_cmd("thunar"))
bind("SUPER", "H", exec_cmd("$HOME/.config/hypr/scripts/hypr_sheet.py"), { description = "Cheat sheet, Ask and AI photos" })
bind("SUPER ALT", "R", exec_cmd("$HOME/.config/hypr/scripts/Refresh.sh"))
bind("SUPER ALT", "E", exec_cmd("$HOME/.config/hypr/scripts/RofiEmoji.sh"))
bind("SUPER", "S", exec_cmd("$HOME/.config/hypr/scripts/RofiSearch.sh"))
bind("SUPER ALT", "O", exec_cmd("$HOME/.config/hypr/scripts/ChangeBlur.sh"))
bind("SUPER SHIFT", "G", exec_cmd("$HOME/.config/hypr/scripts/GameMode.sh"))
bind("SUPER ALT", "L", exec_cmd("$HOME/.config/hypr/scripts/ChangeLayout.sh"))
bind("SUPER ALT", "V", exec_cmd("$HOME/.config/hypr/scripts/ClipManager.sh"))
bind("SUPER CTRL", "R", exec_cmd("$HOME/.config/hypr/scripts/RofiThemeSelector.sh"))
bind("SUPER CTRL SHIFT", "R", exec_cmd("pkill rofi || true && $HOME/.config/hypr/scripts/RofiThemeSelector-modified.sh"))
bind("SUPER SHIFT", "F", dispatch("fullscreen", ""))
bind("SUPER CTRL", "F", dispatch("fullscreen", "1"))
bind("SUPER", "SPACE", dispatch("togglefloating", ""))
bind("SUPER ALT", "SPACE", exec_cmd("hyprctl dispatch workspaceopt allfloat"))
bind("SUPER SHIFT", "Return", exec_cmd("$HOME/.config/hypr/scripts/Dropterminal.sh kitty"))
bind("SUPER ALT", "mouse_down", exec_cmd("hyprctl keyword cursor:zoom_factor \"$(hyprctl getoption cursor:zoom_factor | awk 'NR==1 {factor = $2; if (factor < 1) {factor = 1}; print factor * 2.0}')\""))
bind("SUPER ALT", "mouse_up", exec_cmd("hyprctl keyword cursor:zoom_factor \"$(hyprctl getoption cursor:zoom_factor | awk 'NR==1 {factor = $2; if (factor < 1) {factor = 1}; print factor / 2.0}')\""))
bind("SUPER CTRL ALT", "B", exec_cmd("pkill -SIGUSR1 waybar"))
bind("SUPER CTRL", "B", exec_cmd("$HOME/.config/hypr/scripts/WaybarStyles.sh"))
bind("SUPER ALT", "B", exec_cmd("$HOME/.config/hypr/scripts/WaybarLayout.sh"))
bind("SUPER SHIFT", "M", exec_cmd("$HOME/.config/hypr/UserScripts/RofiBeats.sh"))
bind("SUPER", "W", exec_cmd("$HOME/.config/hypr/UserScripts/WallpaperSelect.sh"))
bind("SUPER SHIFT", "W", exec_cmd("$HOME/.config/hypr/UserScripts/WallpaperEffects.sh"))
bind("CTRL ALT", "W", exec_cmd("$HOME/.config/hypr/UserScripts/WallpaperRandom.sh"))
bind("SUPER CTRL", "O", exec_cmd("hyprctl setprop active opaque toggle"))
bind("SUPER SHIFT", "K", exec_cmd("$HOME/.config/hypr/scripts/hypr_sheet.py --section ask"), { description = "Ask your setup (local LLM)" })
bind("SUPER SHIFT", "A", exec_cmd("$HOME/.config/hypr/scripts/Animations.sh"))
bind("SUPER SHIFT", "O", exec_cmd("$HOME/.config/hypr/UserScripts/ZshChangeTheme.sh"))
bind("ALT_L", "SHIFT_L", exec_cmd("$HOME/.config/hypr/scripts/SwitchKeyboardLayout.sh"), { description = "exec", locked = true })
bind("SHIFT_L", "ALT_L", exec_cmd("$HOME/.config/hypr/scripts/Tak0-Per-Window-Switch.sh"), { description = "exec", locked = true })
bind("SUPER ALT", "C", exec_cmd("$HOME/.config/hypr/UserScripts/RofiCalc.sh"))
bind("", "KP_Home", exec_cmd("/home/vango/planner/scripts/launch_planner_railway.sh"))
bind("", "KP_Up", exec_cmd("obsidian --enable-features=UseOzonePlatform --ozone-platform=wayland"))
bind("", "KP_Prior", exec_cmd("anki"))
bind("", "KP_End", exec_cmd("kitty --class cheats-select -e ~/.local/bin/cheat_sheets.sh"))

-- Flywheel radial-meny (Viktor 2026-10-11): SUPER+SPACE öppnar hjulet.
-- Gamla SUPER+SPACE (togglefloating) flyttas till SUPER+ALT+SPACE, som tidigare
-- bara körde Float-all-Windows.sh (ingen märkbar effekt).
unbind("SUPER", "SPACE")
unbind("SUPER ALT", "SPACE")
bind("SUPER", "SPACE", exec_cmd("$HOME/.local/bin/arch-flywheel"), { description = "Flywheel radial-meny" })
bind("SUPER ALT", "SPACE", dispatch("togglefloating", ""), { description = "Toggle floating" })
