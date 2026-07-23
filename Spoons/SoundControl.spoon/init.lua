--- === SoundControl ===
---
--- Déclencheur clavier de l'app SoundControl (C# / Avalonia).
---
--- L'app est une **application de bureau autonome** : elle vit dans la barre des menus (tray),
--- affiche un popup clavier-first, et héberge une petite API HTTP locale (`http://127.0.0.1:8788`).
--- Hammerspoon ne fait que **déclencher** des actions via cette API, et **démarre l'app** si elle
--- ne répond pas (chaque raccourci vérifie d'abord qu'elle répond).
---
--- Flux principal (cf. DESCRIPTION) :
---   ⌃⌥B → ouvre le popup → l'utilisateur presse « 1 » → profil 1 appliqué → popup fermé.
---   (Esc ferme le popup sans rien changer.)
---
--- Installation :
---   cp -r hammerspoon/SoundControl.spoon ~/.hammerspoon/Spoons/
---   # et installer l'app une fois : build/mac/bundle.sh puis
---   #   cp -R build/mac/dist/SoundControl.app /Applications/
--- Dans ~/.hammerspoon/init.lua :
---   local sc = hs.loadSpoon("SoundControl")
---   -- sc.appName = "SoundControl"            -- nom pour `open -a` (défaut)
---   -- sc.baseUrl = "http://127.0.0.1:8788"   -- optionnel (défaut)
---   sc:bindHotkeys({
---     show    = {{"ctrl", "alt"}, "b"},           -- ouvre le popup (flux principal)
---     chooser = {{"ctrl", "alt"}, "shift", "b"},  -- palette Hammerspoon (optionnel)
---     -- Raccourci direct vers un profil : toute clé non réservée = NOM de profil.
---     -- ["DAC USB"] = {{"cmd", "alt", "ctrl"}, "3"},
---   })

local obj = {}
obj.__index = obj

obj.name = "SoundControl"
obj.version = "0.1.0"
obj.author = "soundcontrol"
obj.license = "MIT"

obj.baseUrl = "http://127.0.0.1:8788"

-- Démarrage automatique si l'app ne répond pas :
obj.appName = "SoundControl"   -- utilisé par `open -a <appName>` (bundle dans /Applications)
obj.appPath = nil              -- alternative : chemin absolu vers SoundControl.app

-- --- HTTP helpers ---------------------------------------------------------

function obj:_get(path, cb)
  hs.http.asyncGet(self.baseUrl .. path, nil, function(status, body)
    if status ~= 200 then
      hs.printf("[SoundControl] GET %s -> %s", path, tostring(status))
      cb(nil)
      return
    end
    local ok, data = pcall(hs.json.decode, body)
    cb(ok and data or nil)
  end)
end

function obj:_post(path, cb)
  hs.http.asyncPost(self.baseUrl .. path, "", { ["Content-Type"] = "application/json" },
    function(status, body)
      if status ~= 200 then
        local detail = ""
        if body then
          local ok, data = pcall(hs.json.decode, body)
          if ok and data and data.detail then detail = " : " .. data.detail end
        end
        hs.alert.show("SoundControl : échec (" .. tostring(status) .. ")" .. detail)
      end
      if cb then cb(status == 200) end
    end)
end

-- --- Démarrage automatique de l'app ---------------------------------------

-- L'API répond-elle ? (un statut négatif = connexion refusée → app absente)
function obj:_alive(cb)
  hs.http.asyncGet(self.baseUrl .. "/api/profiles", nil, function(status) cb(status == 200) end)
end

function obj:_launch()
  local cmd = self.appPath
      and ('/usr/bin/open "' .. self.appPath .. '"')
      or ('/usr/bin/open -a "' .. self.appName .. '"')
  hs.execute(cmd)
end

-- Garantit que l'app tourne, puis exécute fn(). La démarre au besoin et attend qu'elle réponde.
function obj:ensureRunning(fn)
  self:_alive(function(ok)
    if ok then fn(); return end
    self:_launch()
    local tries = 0
    local timer
    timer = hs.timer.doEvery(0.5, function()
      tries = tries + 1
      self:_alive(function(alive)
        if alive then
          timer:stop()
          fn()
        elseif tries >= 24 then   -- ~12 s
          timer:stop()
          hs.alert.show("SoundControl : démarrage impossible")
        end
      end)
    end)
  end)
end

-- --- Actions (chacune démarre l'app si besoin) ----------------------------

-- Ouvre (fait remonter) le popup. Le démarre si besoin.
function obj:show() self:ensureRunning(function() self:_post("/api/show") end) end

-- Ouvre la fenêtre de construction de profils. La démarre si besoin.
function obj:edit() self:ensureRunning(function() self:_post("/api/editor") end) end

-- Applique un profil par son nom, sans passer par le popup.
function obj:applyProfile(name)
  self:ensureRunning(function()
    self:_post("/api/apply/" .. hs.http.encodeForQuery(name), function(ok)
      if ok then hs.alert.show("Profil : " .. name) end
    end)
  end)
end

-- --- Chooser (palette au clavier) -----------------------------------------

function obj:showChooser()
  self:ensureRunning(function() self:_showChooserNow() end)
end

function obj:_showChooserNow()
  self:_get("/api/profiles", function(profiles)
    local choices = {}
    for _, p in ipairs(profiles or {}) do
      local mark = p.active and "🔊 " or (p.available and "○ " or "⚠︎ ")
      local key = (p.key and p.key ~= "") and ("[" .. p.key .. "] ") or ""
      choices[#choices + 1] = {
        text = mark .. key .. p.name,
        subText = p.available and p.output or (p.output .. " — non branché"),
        name = p.name,
      }
    end
    local chooser = hs.chooser.new(function(sel)
      if sel then self:applyProfile(sel.name) end
    end)
    chooser:placeholderText("SoundControl — choisir un profil sonore…")
    chooser:choices(choices)
    chooser:show()
  end)
end

-- --- Raccourcis -----------------------------------------------------------

function obj:bindHotkeys(mapping)
  local actions = {
    show = function() self:show() end,           -- ouvre le popup (flux principal)
    edit = function() self:edit() end,           -- ouvre la fenêtre de construction de profils
    chooser = function() self:showChooser() end, -- palette Hammerspoon
  }
  for action, spec in pairs(mapping) do
    -- Toute clé non réservée est traitée comme un nom de profil (raccourci direct).
    local fn = actions[action] or function() self:applyProfile(action) end
    hs.hotkey.bind(spec[1], spec[2], fn)
  end
  return self
end

return obj
