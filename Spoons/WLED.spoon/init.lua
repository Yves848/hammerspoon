--- === WLED ===
---
--- Découvre et pilote les modules WLED du réseau depuis Hammerspoon.
--- Découverte mDNS (_wled._tcp) + IP fixes optionnelles. Menubar + chooser.
---
--- Config (dans init.lua, avant :start()) :
---   spoon.WLED.staticDevices = { { name = "Bureau", host = "192.168.50.50" } }
---   spoon.WLED.hotkey = { mods = { "ctrl", "alt" }, key = "w" }
---   spoon.WLED:start()

local obj = {}
obj.__index = obj

obj.name = "WLED"
obj.version = "1.0"
obj.author = "Yves Godart"
obj.license = "MIT - https://opensource.org/licenses/MIT"

----------------------------------------------------------------------
-- Configuration (surchargeable depuis init.lua)
----------------------------------------------------------------------

--: Modules déclarés en dur, en secours de la découverte mDNS.
--: Chaque entrée : { name = "…", host = "192.168.x.x" | "wled-xxxx.local" }
obj.staticDevices = {}

--: Raccourci d'ouverture du chooser.
obj.hotkey = { mods = { "ctrl", "alt" }, key = "w" }

--: Rafraîchissement de l'état des modules (secondes).
obj.refreshInterval = 15

--: Palette de couleurs rapides { libellé, {r,g,b} }.
obj.colors = {
	{ "Blanc chaud", { 255, 180, 107 } },
	{ "Blanc", { 255, 255, 255 } },
	{ "Rouge", { 255, 0, 0 } },
	{ "Orange", { 255, 120, 0 } },
	{ "Jaune", { 255, 220, 0 } },
	{ "Vert", { 0, 255, 0 } },
	{ "Cyan", { 0, 255, 255 } },
	{ "Bleu", { 0, 80, 255 } },
	{ "Violet", { 150, 0, 255 } },
	{ "Magenta", { 255, 0, 150 } },
}

--: Paliers de luminosité { libellé, valeur 0-255 }.
obj.brightnessLevels = {
	{ "25 %", 64 },
	{ "50 %", 128 },
	{ "75 %", 191 },
	{ "100 %", 255 },
}

----------------------------------------------------------------------
-- État interne
----------------------------------------------------------------------

local internal = {
	devices = {}, -- [host] = { name, host, source="mdns"|"static", state, effects, palettes, presets }
	browser = nil,
	menubar = nil,
	chooser = nil,
	timer = nil,
	actions = {}, -- [id] = fonction : les choix du chooser n'y stockent qu'un id
	pending = {}, -- [serviceName] = serviceObject : ref forte pendant resolve()
	logger = hs.logger.new("WLED", "info"),
}

-- Debug optionnel → ~/.hammerspoon/wled-debug.log (mettre DEBUG=true pour diagnostiquer)
local DEBUG = false
local function dbg(...)
	if not DEBUG then
		return
	end
	local parts = {}
	for _, v in ipairs({ ... }) do
		parts[#parts + 1] = tostring(v)
	end
	local f = io.open(os.getenv("HOME") .. "/.hammerspoon/wled-debug.log", "a")
	if f then
		f:write(os.date("%H:%M:%S ") .. table.concat(parts, " ") .. "\n")
		f:close()
	end
end

----------------------------------------------------------------------
-- Utilitaires réseau (API JSON WLED)
----------------------------------------------------------------------

local function normHost(h)
	return (h or ""):gsub("%.$", "") -- retire le point final des noms mDNS
end

local function baseURL(host)
	return "http://" .. normHost(host)
end

-- POST d'un fragment d'état WLED (table Lua -> JSON) vers /json/state.
local function post(host, body, cb)
	local url = baseURL(host) .. "/json/state"
	local headers = { ["Content-Type"] = "application/json" }
	hs.http.asyncPost(url, hs.json.encode(body), headers, function(status, _, _)
		if cb then
			cb(status >= 200 and status < 300)
		end
	end)
end

-- GET JSON générique.
local function getJSON(url, cb)
	hs.http.asyncGet(url, nil, function(status, body, _)
		if status >= 200 and status < 300 and body then
			local ok, decoded = pcall(hs.json.decode, body)
			cb(ok and decoded or nil)
		else
			cb(nil)
		end
	end)
end

----------------------------------------------------------------------
-- Rafraîchissement d'un module
----------------------------------------------------------------------

-- Récupère état + méta (effets, palettes, nom) d'un module.
local function refreshDevice(dev, done)
	getJSON(baseURL(dev.host) .. "/json", function(data)
		if data then
			dev.state = data.state
			dev.effects = data.effects or dev.effects
			dev.palettes = data.palettes or dev.palettes
			if data.info and data.info.name and data.info.name ~= "" and data.info.name ~= "WLED" then
				dev.name = data.info.name
			end
			dev.online = true
		else
			dev.online = false
		end
		if done then
			done()
		end
	end)
end

-- Récupère les presets (/presets.json) — map "id" -> objet (avec "n" = nom).
local function refreshPresets(dev)
	getJSON(baseURL(dev.host) .. "/presets.json", function(data)
		if not data then
			return
		end
		local presets = {}
		for id, p in pairs(data) do
			local n = tonumber(id)
			if n and n > 0 and type(p) == "table" and next(p) ~= nil then
				presets[#presets + 1] = { id = n, name = (p.n and p.n ~= "" and p.n) or ("Preset " .. n) }
			end
		end
		table.sort(presets, function(a, b) return a.id < b.id end)
		dev.presets = presets
	end)
end

----------------------------------------------------------------------
-- Actions
----------------------------------------------------------------------

function obj:toggle(host)
	post(host, { on = "t" }, function() self:refreshSoon(host) end)
end

function obj:setOn(host, on)
	post(host, { on = on }, function() self:refreshSoon(host) end)
end

function obj:setBrightness(host, bri)
	post(host, { on = true, bri = bri }, function() self:refreshSoon(host) end)
end

function obj:setColor(host, rgb)
	post(host, { on = true, seg = { { id = 0, col = { rgb } } } }, function() self:refreshSoon(host) end)
end

function obj:setPreset(host, id)
	post(host, { ps = id }, function() self:refreshSoon(host) end)
end

function obj:setEffect(host, fx)
	post(host, { on = true, seg = { { id = 0, fx = fx } } }, function() self:refreshSoon(host) end)
end

function obj:setPalette(host, pal)
	post(host, { on = true, seg = { { id = 0, pal = pal } } }, function() self:refreshSoon(host) end)
end

function obj:allOn()
	for host in pairs(internal.devices) do self:setOn(host, true) end
end

function obj:allOff()
	for host in pairs(internal.devices) do self:setOn(host, false) end
end

-- Rafraîchit un module peu après une action (le firmware applique async).
function obj:refreshSoon(host)
	local dev = internal.devices[host]
	if not dev then return end
	hs.timer.doAfter(0.25, function()
		refreshDevice(dev, function() obj:rebuildMenu() end)
	end)
end

----------------------------------------------------------------------
-- Découverte
----------------------------------------------------------------------

local function addDevice(host, name, source)
	host = normHost(host)
	if internal.devices[host] then
		return internal.devices[host]
	end
	local dev = { host = host, name = name or host, source = source }
	internal.devices[host] = dev
	dbg("addDevice OK host=", host, "name=", dev.name, "source=", source)
	refreshDevice(dev, function()
		dbg("refreshDevice done host=", host, "online=", dev.online, "on=", dev.state and dev.state.on)
		obj:rebuildMenu()
	end)
	refreshPresets(dev)
	return dev
end

local function startDiscovery()
	internal.browser = hs.bonjour.new()
	if not internal.browser then
		dbg("ERREUR hs.bonjour.new() = nil (module bonjour indisponible ?)")
		return
	end
	internal.browser:findServices("_wled._tcp.", function(_, msg, added, service, _)
		dbg("browser cb: msg=", msg, "added=", added, "name=", service and service:name() or "?")
		-- NB : au runtime le message est "service" (et non "domain" comme dans la doc).
		if msg == "error" then
			return -- découverte passive : on ignore les erreurs
		end
		if not added then
			return -- retrait : on garde l'entrée (peut revenir), état passera "offline"
		end
		local key = service:name()
		internal.pending[key] = service -- ref forte : évite le GC pendant resolve()
		service:resolve(5, function(svc, rmsg)
			dbg("resolve cb: name=", svc:name(), "msg=", rmsg)
			if rmsg == "resolved" then
				-- On exige une IPv4 : la résolution .local de l'ESP32 est
				-- intermittente et fait échouer les requêtes ponctuelles.
				-- resolve() se rappelle en boucle : on ne garde que le 1er succès.
				local addrs = svc:addresses() or {}
				dbg("  addresses=", table.concat(addrs, ","), "hostname=", svc:hostname())
				local ip
				for _, a in ipairs(addrs) do
					if a:match("^%d+%.%d+%.%d+%.%d+$") then
						ip = a
						break
					end
				end
				if ip then
					dbg("  -> addDevice host=", ip)
					addDevice(ip, svc:name(), "mdns")
					internal.pending[key] = nil
					svc:stop() -- fige la résolution : stoppe les rappels
				end
				-- pas encore d'IP : on laisse resolve() réessayer
			elseif rmsg == "error" or rmsg == "stop" then
				internal.pending[key] = nil
			end
		end)
	end)
	dbg("findServices lancé")
end

----------------------------------------------------------------------
-- Menubar
----------------------------------------------------------------------

local function sortedDevices()
	local list = {}
	for _, d in pairs(internal.devices) do
		list[#list + 1] = d
	end
	table.sort(list, function(a, b) return (a.name or a.host) < (b.name or b.host) end)
	return list
end

local function deviceSubmenu(dev)
	local host = dev.host
	local sub = {}

	local on = dev.state and dev.state.on
	sub[#sub + 1] = { title = "Allumer", checked = on == true, fn = function() obj:setOn(host, true) end }
	sub[#sub + 1] = { title = "Éteindre", checked = on == false, fn = function() obj:setOn(host, false) end }
	sub[#sub + 1] = { title = "-" }

	-- Luminosité
	for _, b in ipairs(obj.brightnessLevels) do
		local label, val = b[1], b[2]
		local cur = dev.state and dev.state.bri
		sub[#sub + 1] = {
			title = "Luminosité " .. label,
			checked = cur ~= nil and math.abs(cur - val) <= 8,
			fn = function() obj:setBrightness(host, val) end,
		}
	end
	sub[#sub + 1] = { title = "-" }

	-- Couleurs
	local colorItems = {}
	for _, c in ipairs(obj.colors) do
		local label, rgb = c[1], c[2]
		colorItems[#colorItems + 1] = { title = label, fn = function() obj:setColor(host, rgb) end }
	end
	sub[#sub + 1] = { title = "Couleur", menu = colorItems }

	-- Presets
	if dev.presets and #dev.presets > 0 then
		local items = {}
		local curPs = dev.state and dev.state.ps
		for _, p in ipairs(dev.presets) do
			items[#items + 1] = {
				title = p.name,
				checked = curPs == p.id,
				fn = function() obj:setPreset(host, p.id) end,
			}
		end
		sub[#sub + 1] = { title = "Presets", menu = items }
	end

	sub[#sub + 1] = { title = "-" }
	sub[#sub + 1] = { title = dev.online == false and "⚠︎ hors ligne" or ("IP : " .. host), disabled = true }
	return sub
end

function obj:buildMenu()
	local menu = {}
	local devices = sortedDevices()

	if #devices == 0 then
		menu[#menu + 1] = { title = "Aucun module WLED trouvé", disabled = true }
	else
		for _, dev in ipairs(devices) do
			local on = dev.state and dev.state.on
			local dot = dev.online == false and "○" or (on and "●" or "◯")
			menu[#menu + 1] = { title = dot .. "  " .. (dev.name or dev.host), menu = deviceSubmenu(dev) }
		end
		menu[#menu + 1] = { title = "-" }
		menu[#menu + 1] = { title = "Tout allumer", fn = function() obj:allOn() end }
		menu[#menu + 1] = { title = "Tout éteindre", fn = function() obj:allOff() end }
	end

	menu[#menu + 1] = { title = "-" }
	menu[#menu + 1] = { title = "Rechercher… (⌃⌥W)", fn = function() obj:showChooser() end }
	menu[#menu + 1] = { title = "Rafraîchir", fn = function() obj:refreshAll() end }
	return menu
end

-- Titre de l'icône : reflète si au moins un module est allumé.
local function anyOn()
	for _, d in pairs(internal.devices) do
		if d.state and d.state.on then return true end
	end
	return false
end

function obj:rebuildMenu()
	if not internal.menubar then return end
	internal.menubar:setTitle(anyOn() and "💡" or "🔅")
	internal.menubar:setMenu(obj:buildMenu())
end

----------------------------------------------------------------------
-- Chooser (navigation par niveaux : modules → catégorie → valeur)
----------------------------------------------------------------------

-- hs.chooser ne stocke que des valeurs simples dans un choix (string/
-- number/bool) : on ne peut PAS y mettre de fonction. On garde donc les
-- actions dans internal.actions et chaque choix ne porte qu'un `id`.
-- Une action est de la forme { kind, fn } :
--   kind = "run" -> fn() exécute la commande, puis le chooser reste fermé.
--   kind = "nav" -> fn() renvoie une NOUVELLE liste de choix ; on rouvre le
--                   chooser avec celle-ci (descente dans un sous-menu ou
--                   retour). C'est ce qui simule un menu à plusieurs niveaux.
local rootBuilder, deviceBuilder

-- Réinitialise la table d'actions et renvoie (choices, add) pour un niveau.
local function makeAdder()
	internal.actions = {}
	local choices = {}
	local function add(text, subText, kind, fn)
		internal.actions[#internal.actions + 1] = { kind = kind, fn = fn }
		choices[#choices + 1] = { text = text, subText = subText, id = #internal.actions }
	end
	return choices, add
end

-- Sous-liste « feuille » : « ← Retour » vers le module, puis des actions run.
-- `items` = liste de { text, subText?, fn }.
local function leafBuilder(dev, items)
	return function()
		local choices, add = makeAdder()
		add("← Retour", dev.name or dev.host, "nav", function() return deviceBuilder(dev) end)
		for _, it in ipairs(items) do
			add(it.text, it.subText, "run", it.fn)
		end
		return choices
	end
end

-- Niveau 2 : le menu d'un module (catégories filtrables).
deviceBuilder = function(dev)
	local host = dev.host
	local dn = dev.name or dev.host
	local choices, add = makeAdder()
	add("← Retour", "liste des modules", "nav", rootBuilder)
	add("Allumer", dn, "run", function() obj:setOn(host, true) end)
	add("Éteindre", dn, "run", function() obj:setOn(host, false) end)
	add("Basculer", dn, "run", function() obj:toggle(host) end)

	local bri = {}
	for _, b in ipairs(obj.brightnessLevels) do
		bri[#bri + 1] = { text = "Luminosité " .. b[1], fn = function() obj:setBrightness(host, b[2]) end }
	end
	add("Luminosité ▸", "choisir un niveau", "nav", leafBuilder(dev, bri))

	local col = {}
	for _, c in ipairs(obj.colors) do
		col[#col + 1] = { text = c[1], fn = function() obj:setColor(host, c[2]) end }
	end
	add("Couleur ▸", "palette rapide", "nav", leafBuilder(dev, col))

	if dev.presets and #dev.presets > 0 then
		local ps = {}
		for _, p in ipairs(dev.presets) do
			ps[#ps + 1] = { text = p.name, subText = "preset " .. p.id, fn = function() obj:setPreset(host, p.id) end }
		end
		add("Presets ▸", #dev.presets .. " enregistré(s)", "nav", leafBuilder(dev, ps))
	end

	if dev.effects and #dev.effects > 0 then
		local fx = {}
		for i, name in ipairs(dev.effects) do
			fx[#fx + 1] = { text = name, subText = "fx " .. (i - 1), fn = function() obj:setEffect(host, i - 1) end }
		end
		add("Effets ▸", #dev.effects .. " disponibles", "nav", leafBuilder(dev, fx))
	end

	if dev.palettes and #dev.palettes > 0 then
		local pal = {}
		for i, name in ipairs(dev.palettes) do
			pal[#pal + 1] = { text = name, subText = "palette " .. (i - 1), fn = function() obj:setPalette(host, i - 1) end }
		end
		add("Palettes ▸", #dev.palettes .. " disponibles", "nav", leafBuilder(dev, pal))
	end

	return choices
end

-- Niveau 1 (racine) : les modules + les actions globales.
rootBuilder = function()
	local choices, add = makeAdder()
	local devices = sortedDevices()
	if #devices == 0 then
		add("Aucun module WLED trouvé", "⟳ pour relancer une recherche", "run", function() obj:refreshAll() end)
	else
		for _, dev in ipairs(devices) do
			local on = dev.state and dev.state.on
			local etat = dev.online == false and "hors ligne" or (on and "● allumé" or "◯ éteint")
			add(dev.name or dev.host, etat .. " · " .. dev.host, "nav", function() return deviceBuilder(dev) end)
		end
		add("★ Tout allumer", "tous les modules", "run", function() obj:allOn() end)
		add("★ Tout éteindre", "tous les modules", "run", function() obj:allOff() end)
	end
	add("⟳ Rafraîchir", "relancer la découverte et l'état", "run", function() obj:refreshAll() end)
	return choices
end

-- (Ré)affiche le chooser avec la liste produite par `builder`.
function obj:_navTo(builder)
	local choices = builder()
	internal.chooser:choices(choices)
	internal.chooser:query("") -- repart d'une recherche vide à chaque niveau
	internal.chooser:show()
end

function obj:showChooser()
	if not internal.chooser then
		internal.chooser = hs.chooser.new(function(choice)
			if not choice then return end -- Échap / clic hors zone : on ne fait rien
			local act = internal.actions[choice.id]
			if not act then return end
			if act.kind == "nav" then
				obj:_navTo(act.fn) -- descente ou retour : on rouvre le chooser
			else
				act.fn() -- action terminale : on exécute et le chooser reste fermé
			end
		end)
		internal.chooser:searchSubText(true)
	end
	dbg("showChooser: devices=", #sortedDevices())
	obj:_navTo(rootBuilder) -- toujours (r)ouvrir sur la racine
end

----------------------------------------------------------------------
-- Cycle de vie
----------------------------------------------------------------------

function obj:refreshAll()
	for _, dev in pairs(internal.devices) do
		refreshDevice(dev, function() obj:rebuildMenu() end)
		refreshPresets(dev)
	end
end

function obj:start()
	os.remove(os.getenv("HOME") .. "/.hammerspoon/wled-debug.log")
	dbg("=== WLED:start ===")
	-- IP fixes déclarées
	for _, d in ipairs(self.staticDevices) do
		addDevice(d.host, d.name, "static")
	end
	-- Découverte mDNS
	startDiscovery()
	-- Menubar
	internal.menubar = hs.menubar.new()
	dbg("menubar créée:", internal.menubar ~= nil, "titre:", anyOn() and "💡" or "🔅")
	obj:rebuildMenu()
	-- Raccourci chooser
	if self.hotkey then
		hs.hotkey.bind(self.hotkey.mods, self.hotkey.key, function() obj:showChooser() end)
	end
	-- Rafraîchissement périodique
	internal.timer = hs.timer.doEvery(self.refreshInterval, function() obj:refreshAll() end)
	return self
end

function obj:stop()
	if internal.browser then internal.browser:stop() end
	if internal.timer then internal.timer:stop() end
	if internal.menubar then internal.menubar:delete(); internal.menubar = nil end
	return self
end

return obj
