local logger = hs.logger.new("reload", "debug")

-- CLI `hs` pour piloter/inspecter Hammerspoon depuis le terminal (debug)
require("hs.ipc").cliInstall("/opt/homebrew")

-- Gestion des fenêtres — aiguillage automatique :
--   • si yabai est installé → tiling bsp + Spaces, piloté via Yabai.spoon.
--       Fenêtres : ⌃⌥ flèches = focus, ⌃⌥⇧ flèches = échange, ⌃⌥⌘ flèches = warp (arbre).
--       Agencement : ⌃⌥⌘ f/r/e = float/rotate/balance, ⌃⌥⌘ espace = cycle layout.
--       Spaces : ⌃⌥⌘ 1-9 = focus Space, +⇧ = envoyer la fenêtre ; ⌃⌥⌘ , ; = Space préc./suiv.,
--         +⇧ = y envoyer la fenêtre ; ⌃⌥⌘ n/w = créer/détruire un Space.
--       Écrans (touche « = » = l'autre écran) : ⌃⌥⌘ = focus écran, ⌃⌥⌘⇧ = y envoyer la
--         fenêtre, ⌃⌥⇧ = déplacer le Space entier vers l'autre écran.
--   Touches choisies pour AZERTY belge : , ; = sont natives du keymap ([ ] . ne le sont
--   pas → tombent sur des touches mortes). Voir hs.keycodes.map / hs.keycodes.currentLayout().
--   • sinon → fallback 100 % Hammerspoon : moitiés/quadrants/plein écran (window-snap).
-- Ce test évite de casser le placement tant que yabai n'est pas encore en place ; dès
-- qu'il l'est, HS bascule tout seul (les deux ne se marchent jamais dessus).
local yabaiBin = "/opt/homebrew/bin/yabai"
-- On ne bascule en mode tiling que si yabai est installé ET que son service RÉPOND
-- (`query --displays` renvoie 0). Évite de désactiver window-snap si le binaire est là
-- mais le service pas encore démarré.
local yabaiUp = hs.fs.attributes(yabaiBin) ~= nil
	and select(2, hs.execute(yabaiBin .. " -m query --displays 2>/dev/null")) == true
if yabaiUp then
	hs.loadSpoon("Yabai")
	spoon.Yabai.yabai = yabaiBin
	local wmFocus = { "ctrl", "alt" } -- déplacer le focus (reprend l'ancien réflexe des snaps)
	local wmSwap = { "ctrl", "alt", "shift" } -- échanger la fenêtre / déplacer le Space
	local sp = { "ctrl", "alt", "cmd" } -- Spaces / écrans / layout / warp
	local spSend = { "ctrl", "alt", "cmd", "shift" } -- envoyer la fenêtre (Space / écran)
	local ybMap = {
		-- Fenêtres
		focus_west = { wmFocus, "left" },
		focus_east = { wmFocus, "right" },
		focus_north = { wmFocus, "up" },
		focus_south = { wmFocus, "down" },
		swap_west = { wmSwap, "left" },
		swap_east = { wmSwap, "right" },
		swap_north = { wmSwap, "up" },
		swap_south = { wmSwap, "down" },
		-- Warp : ré-insertion de la fenêtre dans l'arbre (⌃⌥⌘ flèches)
		warp_west = { sp, "left" },
		warp_east = { sp, "right" },
		warp_north = { sp, "up" },
		warp_south = { sp, "down" },
		-- Agencement
		toggle_zoom = { wmFocus, "return" }, -- plein cadre (remplace l'ancien ⌃⌥⏎)
		toggle_float = { sp, "f" }, -- (dé)flotter (géré ↔ flottant ; centrer = ⌘⌥C)
		layout_cycle = { sp, "space" }, -- bsp → stack → float → bsp
			layout_toggle = { sp, "t" }, -- bascule pavage auto (bsp) ↔ manuel (float)
		rotate = { sp, "r" }, -- pivoter l'agencement
		balance = { sp, "e" }, -- rééquilibrer
		-- Spaces relatifs + gestion dynamique ( , ; = préc./suiv. )
		space_prev = { sp, "," }, -- Space précédent
		space_next = { sp, ";" }, -- Space suivant
		send_prev = { spSend, "," }, -- envoyer la fenêtre au Space précédent
		send_next = { spSend, ";" }, -- ... au Space suivant
		space_create = { sp, "n" }, -- créer + focaliser un Space
		space_destroy = { sp, "w" }, -- détruire le Space courant
		-- Écrans (touche « = » = l'autre écran ; le modif dit QUOI on déplace)
		display_next = { sp, "=" }, -- focaliser l'autre écran
		send_display_next = { spSend, "=" }, -- y envoyer la fenêtre (+ suivre)
		space_display_next = { wmSwap, "=" }, -- y déplacer le Space entier (+ suivre)
	}
	for n = 1, 9 do
		ybMap["space_" .. n] = { sp, tostring(n) } -- ⌃⌥⌘ N   → focaliser le Space N
		ybMap["send_" .. n] = { spSend, tostring(n) } -- ⌃⌥⌘⇧ N → y envoyer la fenêtre
	end
	spoon.Yabai:bindHotkeys(ybMap)
else
	-- Placement fenêtre en quadrants/moitiés/plein écran, 100 % Hammerspoon
	require("window-snap")
end

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

-- Placement de fenêtres façon Magnet/Rectangle : ⌘⌥ + touche.
--   Moitiés  : ⌘⌥ ← → ↑ ↓        Quarts : ⌘⌥ U I J K (haut-g/haut-d/bas-g/bas-d)
--   Tiers    : ⌘⌥ D F G (g/centre/d), ⌘⌥ E / T (deux-tiers g/d)
--   Plein    : ⌘⌥ ↩              Centré : ⌘⌥ C
-- Sous yabai, la fenêtre est d'abord rendue flottante ; ⌃⌥⌘F la ré-intègre au tiling.
hs.loadSpoon("WindowSnap")
spoon.WindowSnap.yabai = yabaiBin
-- spoon.WindowSnap.gap = 8         -- marge autour (optionnel)
-- spoon.WindowSnap.centerRatio = 0.6
spoon.WindowSnap:start()
local sn = { "cmd", "alt" }
spoon.WindowSnap:bindHotkeys({
	left = { sn, "left" },
	right = { sn, "right" },
	top = { sn, "up" },
	bottom = { sn, "down" },
	top_left = { sn, "u" },
	top_right = { sn, "i" },
	bottom_left = { sn, "j" },
	bottom_right = { sn, "k" },
	left_third = { sn, "d" },
	center_third = { sn, "f" },
	right_third = { sn, "g" },
	left_two_thirds = { sn, "e" },
	right_two_thirds = { sn, "t" },
	maximize = { sn, "return" },
	center = { sn, "c" },
})

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
-- led.baseUrl = "http://127.0.0.1:8787" -- optionnel (défaut)
led:bindHotkeys({
	show = { { "ctrl", "alt" }, "l" }, -- ouvre la fenêtre de l'app LedControl
	travail = { { "ctrl", "alt" }, "1" }, -- scène « travail »
	detente = { { "ctrl", "alt" }, "2" }, -- scène « détente »
	off = { { "ctrl", "alt" }, "0" }, -- scène « off » (tout éteindre)
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

-- hs.hotkey.bind({ "cmd" }, "T", function()
-- 	hs.execute('open -n "/Applications/Ghostty.app"')
-- end)
