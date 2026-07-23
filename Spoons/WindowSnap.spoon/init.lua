--- === WindowSnap ===
---
--- Placement de fenêtres façon **Magnet / Rectangle** : moitiés (gauche/droite/haut/bas),
--- quarts (les 4 coins), tiers (gauche/centre/droite + deux-tiers), plein écran et centré.
--- Le cadre est calculé sur la zone *utile* de l'écran de la fenêtre (hors barre des menus
--- et Dock) et appliqué instantanément. Placement 100 % Hammerspoon, sans dépendance à un
--- gestionnaire de fenêtres externe.
---
--- Usage dans ~/.hammerspoon/init.lua :
---   hs.loadSpoon("WindowSnap")
---   -- spoon.WindowSnap.gap = 8            -- marge en px autour de la fenêtre (optionnel, défaut 0)
---   -- spoon.WindowSnap.centerRatio = 0.6  -- taille de l'action "center" (0..1, défaut 0.6)
---   -- spoon.WindowSnap.topInset = 40       -- réserve le haut pour une barre externe (SketchyBar)
---   spoon.WindowSnap:start()
---   local sn = { "cmd", "alt" }
---   spoon.WindowSnap:bindHotkeys({
---     left = { sn, "left" }, right = { sn, "right" }, top = { sn, "up" }, bottom = { sn, "down" },
---     top_left = { sn, "u" }, top_right = { sn, "i" }, bottom_left = { sn, "j" }, bottom_right = { sn, "k" },
---     left_third = { sn, "d" }, center_third = { sn, "f" }, right_third = { sn, "g" },
---     left_two_thirds = { sn, "e" }, right_two_thirds = { sn, "t" },
---     maximize = { sn, "return" }, center = { sn, "c" },
---   })

local obj = {}
obj.__index = obj

obj.name = "WindowSnap"
obj.version = "1.0"
obj.author = "ledcontrol"
obj.license = "MIT"

-- Marge (px) laissée autour de la fenêtre placée. 0 = collé aux bords / adjacent.
obj.gap = 0
-- Fraction de l'écran pour l'action "center" (fenêtre centrée occupant ce ratio).
obj.centerRatio = 0.6
-- Espace (px) réservé en haut de l'écran pour une barre externe (ex. SketchyBar). Utile
-- quand la barre des menus native est masquée : `hs.screen:frame()` ne réserve alors plus
-- rien en haut, donc les fenêtres « maximisées » passeraient sous la barre. 0 = désactivé.
obj.topInset = 0

-- Régions exprimées en fractions { x, y, w, h } de la zone utile de l'écran.
local REGIONS = {
  left         = { 0,    0,   1 / 2, 1 },
  right        = { 1 / 2, 0,   1 / 2, 1 },
  top          = { 0,    0,   1,    1 / 2 },
  bottom       = { 0,    1 / 2, 1,    1 / 2 },
  top_left     = { 0,    0,   1 / 2, 1 / 2 },
  top_right    = { 1 / 2, 0,   1 / 2, 1 / 2 },
  bottom_left  = { 0,    1 / 2, 1 / 2, 1 / 2 },
  bottom_right = { 1 / 2, 1 / 2, 1 / 2, 1 / 2 },
  left_third      = { 0,     0, 1 / 3, 1 },
  center_third    = { 1 / 3, 0, 1 / 3, 1 },
  right_third     = { 2 / 3, 0, 1 / 3, 1 },
  left_two_thirds = { 0,     0, 2 / 3, 1 },
  right_two_thirds = { 1 / 3, 0, 2 / 3, 1 },
  maximize     = { 0, 0, 1, 1 },
}

--- Applique une région (fractions) à la fenêtre focalisée.
function obj:_apply(frac)
  local win = hs.window.focusedWindow()
  if not win then return end
  local scr = win:screen()
  local sf = scr:frame()     -- zone utile (hors Dock ; hors barre native si affichée)
  local ff = scr:fullFrame() -- écran complet (bord supérieur réel)
  local g = self.gap or 0
  -- Réserve `topInset` px en haut pour une barre externe (SketchyBar…) : si la barre
  -- native est masquée, `frame()` ne réserve plus rien en haut, donc on le fait ici.
  -- `math.max` garde le comportement correct que la barre native soit affichée ou non.
  local top = math.max(sf.y, ff.y + (self.topInset or 0))
  local uw, uh = sf.w, (sf.y + sf.h) - top
  local target = {
    x = sf.x + frac[1] * uw + g,
    y = top + frac[2] * uh + g,
    w = frac[3] * uw - 2 * g,
    h = frac[4] * uh - 2 * g,
  }
  -- setFrame sans animation (0) → placement immédiat.
  win:setFrame(target, 0)
end

--- Place la fenêtre selon une action nommée (voir REGIONS + "center").
function obj:place(name)
  if name == "center" then
    local r = self.centerRatio or 0.6
    self:_apply({ (1 - r) / 2, (1 - r) / 2, r, r })
  else
    local frac = REGIONS[name]
    if frac then self:_apply(frac) end
  end
  return self
end

--- Aucun état à initialiser — présent pour respecter la convention Spoon (start/stop).
function obj:start()
  return self
end

--- bindHotkeys : chaque clé du mapping est une action de placement.
--- Actions reconnues :
---   Moitiés  : left, right, top, bottom
---   Quarts   : top_left, top_right, bottom_left, bottom_right
---   Tiers    : left_third, center_third, right_third, left_two_thirds, right_two_thirds
---   Autres   : maximize (plein écran utile), center (centré, voir centerRatio)
function obj:bindHotkeys(mapping)
  for name, spec in pairs(mapping or {}) do
    local isAction = (name == "center") or (REGIONS[name] ~= nil)
    if isAction then
      hs.hotkey.bind(spec[1], spec[2], function() self:place(name) end)
    end
  end
  return self
end

return obj
