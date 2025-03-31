hs.hotkey.bind({ "cmd", "shift" }, "T", function()
	hs.application.launchOrFocus("WezTerm")
end)
local logger = hs.logger.new("reload", "debug")

hs.console.clearConsole()

function getLightData()
	res, body, headers = hs.http.get("http://192.168.50.202/data", nil)
	logger.d(body)
	local json = hs.json.decode(body)
	hs.alert.show("Jour : " .. json["day"] .. "Nuit : " .. json["night"])
end

function choosehandle(f)
	if f ~= nil then
		if f.uuid == "001" then
			hs.alert.show(f.text)
			hs.http.post("http://192.168.50.202/night")
		end
		if f.uuid == "002" then
			hs.alert.show(f.text)
			hs.http.post("http://192.168.50.202/day")
		end
		if f.uuid == "003" then
			getLightData()
		end
	end
end

local image = hs.image.imageFromURL(
	"https://png.pngtree.com/png-vector/20250117/ourlarge/pngtree-detailed-illustration-of-a-modern-and-colorful-keyboard-fun-vibrant-graphic-png-image_15235991.png"
)

local notification = hs.notify.new()
notification:title("Hammerspoon")
notification:subTitle("Démarrage")
notification:contentImage(image)
notification:setIdImage(image)
notification:send()

logger.i("Initializing")
local choices = {
	{
		["text"] = "Eteindre",
		["subText"] = "Eteindre l'aquarium",
		["uuid"] = "001",
	},
	{
		["text"] = "Allumer",
		["subText"] = "Allumer l'aquarium",
		["uuid"] = "002",
	},
	{
		["text"] = "Status éclairage",
		["subText"] = "Obtenir l'état de l'éclairage",
		["uuid"] = "003",
	},
}

local choose = hs.chooser.new(choosehandle)
hs.hotkey.bind({ "ctrl", "shift" }, "L", function()
	choose:choices(choices)
	choose:show()
end)

local eventtap = hs.eventtap
local keyDown = hs.eventtap.event.types.keyDown

-- Variables globales
local remapEnabled = true
local remapTap = nil
local menuIcon = nil

-- Fonction de remapping
local function remapFunction(e)
	if not remapEnabled then
		return false
	end

	local code = e:getKeyCode()
	local flags = e:getFlags()

	if code == 10 then -- Touche @/#
		if flags.shift then
			hs.eventtap.keyStrokes(">")
		else
			hs.eventtap.keyStrokes("<")
		end
		return true
	elseif code == 50 then -- Touche </>
		if flags.shift then
			hs.eventtap.keyStrokes("#")
		else
			hs.eventtap.keyStrokes("@")
		end
		return true
	end

	return false
end

-- Création du watcher
remapTap = eventtap.new({ keyDown }, remapFunction)
remapTap:start()

-- Icône dans la barre de menu
menuIcon = hs.menubar.new()

local function updateMenu()
	if remapEnabled then
		menuIcon:setTitle("🔁") -- Icône active
		menuIcon:setTooltip("Remapping actif : </> ⇄ @/#")
	else
		menuIcon:setTitle("❌")
		menuIcon:setTooltip("Remapping désactivé")
	end
end

local function toggleRemap()
	remapEnabled = not remapEnabled
	updateMenu()
end

if menuIcon then
	menuIcon:setClickCallback(toggleRemap)
	updateMenu()
end

-- Raccourci pour recharger Hammerspoon
hs.hotkey.bind({ "cmd", "alt", "ctrl" }, "R", function()
	hs.reload()
	hs.alert.show("Config rechargée")
end)

local configFileWatcher = nil

function reloadConfig(files)
	hs.alert.show("reload")
	local doReload = false
	for _, file in pairs(files) do
		if file:sub(-4) == ".lua" then
			doReload = true
		end
	end

	hs.notify.new({ title = "Hammerspoon", informativeText = "Configuration rechargée" }):send()
	if doReload then
		hs.reload()
	end
end

-- Dossier à surveiller (celui où se trouve init.lua)
local configPath = os.getenv("HOME") .. "/.hammerspoon/"
configFileWatcher = hs.pathwatcher.new(configPath, reloadConfig):start()
