local logger = hs.logger.new("reload", "debug")

-- CLI `hs` pour piloter/inspecter Hammerspoon depuis le terminal (debug)
require("hs.ipc").cliInstall("/opt/homebrew")

-- Gestion des fenêtres : yabai a été retiré (tiling bsp, Spaces, warp, JankyBorders).
-- Ce qui reste en service :
--   • déplacement / redimensionnement par pas → WindowStep, juste en dessous ;
--   • placement (moitiés, quarts, plein écran) → délégué à Rectangle, app externe.
-- WindowSnap.spoon reste présent mais débranché, voir plus bas.

-- Déplacer / redimensionner la fenêtre active par pas (flèches, répétition si maintenu)
--   Déplacer      : Shift+Alt+flèches
--   Redimensionner: Cmd+Ctrl+flèches (gauche/droite = largeur, haut/bas = hauteur)
--   (Shift+Ctrl+flèches est réservé par macOS pour changer de bureau/Space)
hs.loadSpoon("WindowStep")
spoon.WindowStep.step = 50 -- taille d'une "unité" en px
local wsMove = { "shift", "alt" }
local wsResize = { "cmd", "ctrl" }
spoon.WindowStep:bindHotkeys({
	move_left = { wsMove, "left" },
	move_right = { wsMove, "right" },
	move_up = { wsMove, "up" },
	move_down = { wsMove, "down" },
	resize_left = { wsResize, "left" },
	resize_right = { wsResize, "right" },
	resize_up = { wsResize, "up" },
	resize_down = { wsResize, "down" },
})

-- Passe-plat pour Ghostty : ⌘⌃+flèches sert aussi à Ghostty (resize_split).
-- Un hotkey global avale la touche avant l'app ; on désactive donc le resize
-- global de WindowStep quand Ghostty est au premier plan, pour laisser les
-- ⌘⌃+flèches atteindre Ghostty, et on le réactive dès qu'une autre app l'est.
-- (Le déplacement Shift+Alt+flèches ne rentre pas en conflit : on n'y touche pas.)
local wsGhosttyResizeKeys = { "resize_left", "resize_right", "resize_up", "resize_down" }
local function wsApplyGhostty(app)
	local isGhostty = app and app:bundleID() == "com.mitchellh.ghostty"
	spoon.WindowStep:setEnabled(wsGhosttyResizeKeys, not isGhostty)
end
-- Rangé dans le spoon (retenu par la table globale `spoon`) pour éviter le GC.
spoon.WindowStep._ghosttyWatcher = hs.application.watcher.new(function(_, event, app)
	if event == hs.application.watcher.activated then
		wsApplyGhostty(app)
	end
end)
spoon.WindowStep._ghosttyWatcher:start()
-- État initial selon l'app active au chargement de la config.
wsApplyGhostty(hs.application.frontmostApplication())

-- Placement de fenêtres : DÉLÉGUÉ À RECTANGLE (app externe), plus à WindowSnap.spoon.
-- WindowSnap est débranché pour éviter deux systèmes de placement redondants/concurrents.
-- Pour revenir au placement Hammerspoon (⌘⌥ + touche), décommenter le bloc ci-dessous.
--   Moitiés  : ⌘⌥ ← → ↑ ↓        Quarts : ⌘⌥ U I J K
--   Tiers    : ⌘⌥ D F G           Deux-tiers : ⌘⌥ E / T
--   Plein    : ⌘⌥ ↩               Centré : ⌘⌥ C
-- hs.loadSpoon("WindowSnap")
-- spoon.WindowSnap.gap = 10
-- spoon.WindowSnap.topInset = 0
-- spoon.WindowSnap:start()
-- local sn = { "cmd", "alt" }
-- spoon.WindowSnap:bindHotkeys({
-- 	left = { sn, "left" }, right = { sn, "right" }, top = { sn, "up" }, bottom = { sn, "down" },
-- 	top_left = { sn, "u" }, top_right = { sn, "i" }, bottom_left = { sn, "j" }, bottom_right = { sn, "k" },
-- 	left_third = { sn, "d" }, center_third = { sn, "f" }, right_third = { sn, "g" },
-- 	left_two_thirds = { sn, "e" }, right_two_thirds = { sn, "t" },
-- 	maximize = { sn, "return" }, center = { sn, "c" },
-- })

hs.loadSpoon("SwapKeys")
spoon.SwapKeys:start()

-- La touche « . » du pavé numérique produit toujours un vrai point (utile pour les IP)
-- ⌃⌥P : bascule le pavé décimal entre « . » et « , »
hs.loadSpoon("NumpadDot")
spoon.NumpadDot:bindHotkeys({ toggle = { { "ctrl", "alt" }, "p" } })
spoon.NumpadDot:start()

-- Pilotage des modules WLED (découverte mDNS + chooser ⌃⌥W)
hs.loadSpoon("WLED")
-- spoon.WLED.staticDevices = { { name = "Bureau", host = "192.168.50.50" } }
spoon.WLED:start()

-- Pilotage LedControl : scènes + prises Tuya + WLED.
-- L'app LedControl (C#/Avalonia) est autonome : elle a son propre menu (tray), sa fenêtre,
-- et demande elle-même l'autorisation « Réseau local ». Hammerspoon ne fait que DÉCLENCHER
-- des actions via l'API HTTP locale (127.0.0.1) → aucune permission réseau requise côté HS.
local led = hs.loadSpoon("LedControl")
-- led.baseUrl = "http://192.168.50.207:8787" -- optionnel (défaut : le LXC)
led:bindHotkeys({
	show = { { "ctrl", "alt" }, "l" }, -- ouvre la fenêtre de l'app LedControl
	-- Lettres mnémoniques (AZERTY-friendly) plutôt que 1/2/0 : la rangée des
	-- chiffres exige ⇧ sur AZERTY et le hotkey ne captait que la touche du haut.
	travail = { { "ctrl", "alt" }, "t" }, -- scène « travail »
	detente = { { "ctrl", "alt" }, "d" }, -- scène « détente »
	off = { { "ctrl", "alt" }, "o" },    -- scène « off » (tout éteindre)
	-- chooser = { { "ctrl", "alt" }, "p" }, -- palette clavier (optionnel, décommentez pour l'ajouter)
})

-- Partages SMB Synology : ⌃⌥N lance l'app GUI SynologyShares (C#/Photino).
-- Toute la logique (config, découverte, montage, Finder) vit dans l'app ;
-- Hammerspoon ne fait qu'intercepter le raccourci et la lancer.
local synologyApp = os.getenv("HOME") .. "/git/synology/SynologyShares/bin/Release/net10.0/SynologyShares"
hs.hotkey.bind({ "ctrl", "alt" }, "n", function()
	hs.task.new(synologyApp, nil):start()
end)

-- Bascule de profil sonore : l'app SoundControl (C#/Avalonia) vit dans la barre des menus
-- et héberge une API HTTP locale (127.0.0.1:8788). Hammerspoon ne fait que DÉCLENCHER.
--   ⌃⌥B : ouvre le popup → touche 1..9 applique le profil → Esc annule.
local sc = hs.loadSpoon("SoundControl")
sc:bindHotkeys({
	show = { { "ctrl", "alt" }, "b" }, -- ouvre le popup (flux principal)
	-- chooser = { { "ctrl", "alt" }, "shift", "b" }, -- palette Hammerspoon (optionnel)
})

-- Aide clavier : ⌃⌥H affiche/masque une fenêtre flottante listant tous les raccourcis
-- (données par défaut dans le Spoon ; surchargeables via spoon.CheatSheet.sections).
hs.loadSpoon("CheatSheet")
spoon.CheatSheet:bindHotkeys({ toggle = { { "ctrl", "alt" }, "h" } })

-- prompter : ⌥Espace puis une séquence de lettres → les actions de l'app au premier plan,
-- façon which-key. Enchaîné, l'action part sans rien afficher ; après ~300 ms d'hésitation,
-- une popup souffle la suite. Les menus sont lus automatiquement, une surcouche optionnelle
-- (~/.config/prompter/<bundle-id>.json) permet d'épingler des lettres, masquer, regrouper.
--   `make selftest` (dans le dépôt) imprime l'arbre et les lettres choisies sans rien exécuter.
-- ⚠️ Le Spoon est un LIEN SYMBOLIQUE vers le worktree ~/git/macos/prompter/.claude/worktrees/
--    prompter-v0, tant que la MR !1 n'est pas fusionnée — il n'est donc PAS suivi en git,
--    contrairement à Synology.spoon qui pointe vers un chemin stable. À re-pointer sur
--    ~/git/macos/prompter/Spoons/Prompter.spoon après la fusion, puis à commiter.
--    D'ici là le chargement est gardé : si le lien casse, on perd prompter, pas la config.
if hs.fs.attributes(hs.configdir .. "/Spoons/Prompter.spoon") then
	hs.loadSpoon("Prompter")
	spoon.Prompter:start()
else
	hs.printf("[config] Prompter.spoon introuvable — prompter n'est pas chargé")
end

-- Import automatique d'une carte d'appareil photo vers le NAS.
-- Au montage d'un volume portant un DCIM/, une notification annonce son
-- contenu ; un clic monte le partage `photo` et ouvre Ghostty sur l'outil
-- `photo-import`, qui range les fichiers en Appareil/Type/Année/Mois.
--
-- Le Spoon est un LIEN SYMBOLIQUE vers ~/git/config/helpers/, posé par

local menuIcon = nil
hs.osascript.javascript('console.log("Hello")')
hs.console.clearConsole()

function getLightData()
	local res, body, headers = hs.http.get("http://192.168.50.201/data", nil)
	local json = hs.json.decode(body)
	hs.alert.show("Jour : " .. json["day"] .. " | Nuit : " .. json["night"])
end

function choosehandle(f)
	if f ~= nil then
		if f.uuid == "001" then
			hs.alert.show(f.text)
			hs.http.post("http://192.168.50.201/night")
		end
		if f.uuid == "002" then
			hs.alert.show(f.text)
			hs.http.post("http://192.168.50.201/day")
		end
		if f.uuid == "003" then
			getLightData()
		end
	end
end

local image = hs.image.imageFromURL(
	"https://png.pngtree.com/png-vector/20250117/ourlarge/pngtree-detailed-illustration-of-a-modern-and-colorful-keyboard-fun-vibrant-graphic-png-image_15235991.png"
)

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

hs.hotkey.bind({ "ctrl", "alt" }, "A", function()
	local choose = hs.chooser.new(choosehandle)
	choose:choices(choices)
	choose:show()
end)

-- Icône dans la barre de menu
menuIcon = hs.menubar.new()

local function updateMenu()
	if spoon.SwapKeys:isEnabled() then
		menuIcon:setTitle("🔁") -- Icône active
		menuIcon:setTooltip("Remapping actif : </> ⇄ @/#")
	else
		menuIcon:setTitle("❌")
		menuIcon:setTooltip("Remapping désactivé")
	end
end

local function toggleRemap()
	spoon.SwapKeys:toggle()
	updateMenu()
end

if menuIcon then
	menuIcon:setClickCallback(toggleRemap)
	updateMenu()
end

-- Raccourci pour recharger Hammerspoon
hs.hotkey.bind({ "cmd", "alt", "ctrl" }, "R", function()
	--hs.alert.show("Config rechargée")
	hs.notify.new({ title = "Hammerspoon", informativeText = "Relolad configutation" }):send()
	hs.reload()
end)

-- gproj natif : Caps+P -> F18 via Karabiner.
-- Cibler le bundle installé évite une ancienne copie enregistrée par Launch Services.
-- -g laisse gproj décider du focus avant toute activation par Launch Services.
hs.hotkey.bind({}, "F18", function()
    local app = os.getenv("HOME") .. "/Applications/gproj.app"
    if not hs.fs.attributes(app) then
        hs.alert.show("gproj : application absente dans ~/Applications")
        return
    end
    hs.task.new("/usr/bin/open", function(code, _, err)
        if code ~= 0 then hs.alert.show("gproj : " .. (err or "ouverture impossible")) end
    end, {"-g", "-a", app, "gproj://open"}):start()
end)


-- Persistance de la géométrie des fenêtres projet.
local gprojBridgePath = os.getenv("HOME") .. "/.local/share/gproj/bridge.lua"
if hs.fs.attributes(gprojBridgePath) then
	GprojBridge = dofile(gprojBridgePath)
end

-- Remplace par les sequences natives de Ghostty : keybind = f20>...
-- dans config/ghostty/config du depot config. Tant que ce Spoon est
-- charge, hs.hotkey capte F20 AVANT Ghostty et les sequences natives
-- restent mortes, sans le moindre message. Le Spoon reste sur disque,
-- reactivable en decommentant ces deux lignes.
-- hs.loadSpoon("GhosttyLeader")
-- spoon.GhosttyLeader:start()

-- hs.hotkey.bind({ "cmd" }, "T", function()
-- 	hs.execute('open -n "/Applications/Ghostty.app"')
-- end)

-- Caps+Shift+P -> F17 : sélecteur des fenêtres Ghostty ouvertes par gproj.
-- F17 et non F19 : F19 sert deja a ForkLift (Caps+F). La regle Karabiner
-- « p + shift mandatory » doit preceder celle qui capte « p » avec optional:["any"],
-- sinon Shift est absorbe et F18 est emis a la place.
hs.hotkey.bind({}, "F17", function()
    local app = os.getenv("HOME") .. "/Applications/gproj.app"
    if not hs.fs.attributes(app) then
        hs.alert.show("gproj : application absente dans ~/Applications")
        return
    end
    hs.task.new("/usr/bin/open", function(code, _, err)
        if code ~= 0 then hs.alert.show("gproj : " .. (err or "ouverture impossible")) end
    end, {"-g", "-a", app, "gproj://windows"}):start()
end)
-- >>> configkit:configkit >>>
-- Lignes appartenant au depot config. Tout le reste d'init.lua appartient au
-- depot hammerspoon : voir l'ADR 0031.

-- PhotoImport : le Spoon est un lien pose par config, mais sa ligne de
-- chargement vivait jusqu'ici dans l'autre depot faute de pouvoir ecrire un
-- bloc gere dans du Lua. Elle rejoint son proprietaire.
--
-- Le :start() n'est pas decoratif : sans lui le Spoon se charge et ne fait
-- RIEN, sans erreur ni message -- l'import photo se tait et l'on cherche
-- longtemps pourquoi. Le repli hs.printf sert la meme fin : dire que le
-- composant n'est pas deploye plutot que de le laisser deviner.
if hs.fs.attributes(hs.configdir .. "/Spoons/PhotoImport.spoon") then
    hs.loadSpoon("PhotoImport")
    spoon.PhotoImport:start()
else
    hs.printf("[config] PhotoImport.spoon introuvable -- l'import photo n'est pas charge")
end

-- ForkLift sur le repertoire du contexte : Caps+F -> F19 via Karabiner.
-- AXDocument de la fenetre au premier plan porte le cwd reel de l'onglet
-- Ghostty (OSC 7). Toute appli qui renseigne cet attribut marche sans code
-- dedie.
function ForkliftIci()
    local win = hs.window.focusedWindow()
    if not win then return nil, "aucune fenetre au premier plan" end
    local element = hs.axuielement.windowElement(win)
    local doc = element and element:attributeValue("AXDocument")
    if type(doc) ~= "string" or doc == "" then
        return nil, (win:application():name() or "?") .. " n'expose pas de repertoire"
    end
    local chemin = hs.http.urlParts(doc).path
    if not chemin then return nil, "URL illisible : " .. doc end
    local attrs = hs.fs.attributes(chemin)
    if attrs and attrs.mode == "directory" then return chemin end
    local parent = chemin:match("^(.*)/[^/]*$")
    if parent == nil or parent == "" then parent = "/" end
    return parent
end

hs.hotkey.bind({}, "F19", function()
    local chemin, raison = ForkliftIci()
    local args = { "-a", "/Applications/ForkLift.app" }
    if chemin then args[3] = chemin else hs.alert.show("ForkLift : " .. raison) end
    hs.task.new("/usr/bin/open", function(code, _, err)
        if code ~= 0 then hs.alert.show("ForkLift : " .. (err or "ouverture impossible")) end
    end, args):start()
end)
-- <<< configkit:configkit <<<
