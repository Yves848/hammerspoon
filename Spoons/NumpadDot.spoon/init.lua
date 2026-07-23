--- === NumpadDot ===
---
--- Force la touche « . » du pavé numérique à produire un point « . », quelle que soit
--- la disposition clavier (sur AZERTY belge/français, elle tape une virgule par défaut).
--- Pratique pour saisir des adresses IP.
---
--- Usage dans ~/.hammerspoon/init.lua :
---   hs.loadSpoon("NumpadDot")
---   spoon.NumpadDot:bindHotkeys({ toggle = { { "ctrl", "alt" }, "p" } })  -- bascule . <> ,
---   spoon.NumpadDot:start()
---
--- Optionnel : spoon.NumpadDot.char = ","  -- pour forcer autre chose que "."

local obj = {}
obj.__index = obj

obj.name = "NumpadDot"
obj.version = "1.0"
obj.author = "ledcontrol"
obj.license = "MIT"

-- Caractère à produire (par défaut le point).
obj.char = "."

-- keycode de la touche décimale du pavé numérique (kVK_ANSI_KeypadDecimal = 65).
local KEYPAD_DECIMAL = hs.keycodes.map["pad."] or 65

obj.tap = nil

function obj:start()
  if self.tap then return self end
  self.tap = hs.eventtap.new({ hs.eventtap.event.types.keyDown }, function(e)
    if e:getKeyCode() == KEYPAD_DECIMAL then
      e:setUnicodeString(self.char)
    end
    return false -- on laisse passer l'événement (éventuellement modifié)
  end)
  self.tap:start()
  return self
end

function obj:stop()
  if self.tap then
    self.tap:stop()
    self.tap = nil
  end
  return self
end

--- Bascule le caractère produit par le pavé décimal entre « . » et « , ».
function obj:toggle()
  self.char = (self.char == ".") and "," or "."
  hs.alert.show('Pavé num  ⌨  →  « ' .. self.char .. ' »')
  return self
end

--- bindHotkeys({ toggle = { {mods}, "key" } })
function obj:bindHotkeys(mapping)
  if mapping and mapping.toggle then
    hs.hotkey.bind(mapping.toggle[1], mapping.toggle[2], function() self:toggle() end)
  end
  return self
end

return obj
