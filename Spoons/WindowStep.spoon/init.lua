--- === WindowStep ===
---
--- Déplace et redimensionne la fenêtre active « par pas » (une unité à la fois),
--- au clavier. Maintenir la touche répète l'action.
---
--- Usage dans ~/.hammerspoon/init.lua :
---   hs.loadSpoon("WindowStep")
---   spoon.WindowStep.step = 50   -- taille d'une "unité" en pixels (optionnel, défaut 50)
---   local moveMods   = { "ctrl", "alt", "shift" }
---   local resizeMods = { "ctrl", "alt", "cmd" }
---   spoon.WindowStep:bindHotkeys({
---     move_left  = { moveMods, "left" },  move_right = { moveMods, "right" },
---     move_up    = { moveMods, "up" },    move_down  = { moveMods, "down" },
---     resize_left  = { resizeMods, "left" },  resize_right = { resizeMods, "right" },
---     resize_up    = { resizeMods, "up" },    resize_down  = { resizeMods, "down" },
---   })

local obj = {}
obj.__index = obj

obj.name = "WindowStep"
obj.version = "1.0"
obj.author = "ledcontrol"
obj.license = "MIT"

-- Taille d'une "unité", en pixels.
obj.step = 50
-- Taille minimale d'une fenêtre lors du redimensionnement.
obj.minSize = 120

function obj:_win()
  return hs.window.focusedWindow()
end

--- Déplace la fenêtre de (dx, dy) unités-pixels.
function obj:move(dx, dy)
  local win = self:_win()
  if not win then return end
  local f = win:frame()
  f.x = f.x + dx
  f.y = f.y + dy
  win:setFrame(f)
end

--- Redimensionne la fenêtre de (dw, dh) pixels (coin haut-gauche fixe).
function obj:resize(dw, dh)
  local win = self:_win()
  if not win then return end
  local f = win:frame()
  f.w = math.max(self.minSize, f.w + dw)
  f.h = math.max(self.minSize, f.h + dh)
  win:setFrame(f)
end

--- bindHotkeys : accepte move_{left,right,up,down} et resize_{left,right,up,down}.
--- resize_left/right = moins/plus large ; resize_up/down = moins/plus haut.
function obj:bindHotkeys(mapping)
  local s = self.step
  local actions = {
    move_left    = function() self:move(-s, 0) end,
    move_right   = function() self:move(s, 0) end,
    move_up      = function() self:move(0, -s) end,
    move_down    = function() self:move(0, s) end,
    resize_left  = function() self:resize(-s, 0) end, -- moins large
    resize_right = function() self:resize(s, 0) end,  -- plus large
    resize_up    = function() self:resize(0, -s) end, -- moins haut
    resize_down  = function() self:resize(0, s) end,  -- plus haut
  }
  for name, spec in pairs(mapping or {}) do
    local fn = actions[name]
    if fn then
      -- pressedfn + repeatfn = fn -> l'action se répète si la touche est maintenue.
      hs.hotkey.bind(spec[1], spec[2], fn, nil, fn)
    end
  end
  return self
end

return obj
