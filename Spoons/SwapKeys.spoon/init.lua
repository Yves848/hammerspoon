--- === MonSpoon ===
---
--- Un exemple de squelette pour créer un spoon pour Hammerspoon.
---
local obj = {}
obj.__index = obj

-- Métadonnées
obj.name = "SwapKeys"
obj.version = "1.0"
obj.author = "Yves Godart <yves.godart@gmail.com>"
obj.homepage = "https://www.hammerspoon.org/Spoons/SwapKeys.html"
obj.license = "MIT - https://opensource.org/licenses/MIT"

--local logger = hs.logger.new("SwapKeys", "debug")
local keyDown = hs.eventtap.event.types.keyDown
-- Variables internes (à utiliser si besoin)
local internal = {
	remapEnabled = false,
	remapTap = nil,
	menuIcon = nil,
}

local function remapFunction(e)
	if not internal.remapEnabled then
		return false
	end

	local code = e:getKeyCode()
	local flags = e:getFlags()
	if code == 10 then
		if flags.shift then
			hs.eventtap.keyStrokes(">")
		else
			hs.eventtap.keyStrokes("<")
		end
		return true
	elseif code == 50 then
		if flags.shift then
			hs.eventtap.keyStrokes("#")
		else
			hs.eventtap.keyStrokes("@")
		end
		return true
	end
	return false
end
function obj:init() end

function obj:start()
	internal.remapTap = hs.eventtap.new({ keyDown }, remapFunction)
	internal.remapTap:start()
end

function obj:toggle()
	internal.remapEnabled = not internal.remapEnabled
	if not internal.remapEnabled then
		hs.alert.show("SwapKeys en pause!")
	else
		hs.alert.show("SwapKeys en fonctionnement!")
	end
end

function obj:isEnabled()
	return internal.remapEnabled
end

function obj:stop()
	--hs.alert.show("SwapKeys en arrêté!")
	if internal.remapTap then
		internal.remapTap = nil
	end
end

return obj
