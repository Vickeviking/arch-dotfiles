-- ==================================================
--  KoolDots (2026)
--  Project URL: https://github.com/LinuxBeginnings
--  License: GNU GPLv3
--  SPDX-License-Identifier: GPL-3.0-or-later
-- ==================================================

-- User animations overrides.
--
-- 2026-10-16: "snappy & subtle" (Viktor's pick). Short ease-out curves, ~150-250 ms,
-- small pop-in for windows, short slide+fade for workspaces, no looping border spin.
-- speed is in deciseconds: 2 = 200 ms.
-- To turn animations off again: set enabled = false below (was off since 2026-08-05).

hl.config({
  animations = {
    enabled = true,
  },
})

hl.curve("deskOut", { type = "bezier", points = { { 0.16, 1 }, { 0.3, 1 } } })   -- ease-out
hl.curve("deskInOut", { type = "bezier", points = { { 0.65, 0 }, { 0.35, 1 } } }) -- ease-in-out

hl.animation({ leaf = "windowsIn", enabled = true, speed = 2.2, bezier = "deskOut", style = "popin 92%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.5, bezier = "deskOut", style = "popin 92%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 2.2, bezier = "deskOut", style = "slide" })
hl.animation({ leaf = "fade", enabled = true, speed = 1.8, bezier = "deskOut" })
hl.animation({ leaf = "layers", enabled = true, speed = 1.8, bezier = "deskOut", style = "fade" })
hl.animation({ leaf = "border", enabled = true, speed = 2.5, bezier = "deskOut" })
hl.animation({ leaf = "borderangle", enabled = false })
hl.animation({ leaf = "workspaces", enabled = true, speed = 2.5, bezier = "deskInOut", style = "slidefade 12%" })
