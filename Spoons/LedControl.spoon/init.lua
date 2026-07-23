--- === LedControl ===
---
--- Déclencheur clavier de l'app LedControl (C# / Avalonia).
---
--- L'app est une **application de bureau autonome** : elle a son propre menu (tray), sa fenêtre,
--- et demande elle-même l'autorisation « Réseau local » macOS. Hammerspoon ne fait que
--- **déclencher des actions** via l'API HTTP locale que l'app héberge (`http://127.0.0.1:8787`),
--- et **la démarre si elle ne tourne pas** (chaque raccourci vérifie d'abord qu'elle répond).
---
--- Installation :
---   cp -r hammerspoon/LedControl.spoon ~/.hammerspoon/Spoons/
---   # et installer l'app une fois : build/mac/bundle.sh puis
---   #   cp -R build/mac/dist/LedControl.app /Applications/
--- Dans ~/.hammerspoon/init.lua :
---   local led = hs.loadSpoon("LedControl")
---   -- led.appName = "LedControl"            -- nom pour `open -a` (défaut)
---   -- led.appPath = "/Applications/LedControl.app"  -- alternative : chemin absolu du bundle
---   -- led.baseUrl = "http://127.0.0.1:8787" -- optionnel (défaut)
---   led:bindHotkeys({
---     show    = {{"ctrl", "alt"}, "L"},             -- ouvre la fenêtre de l'app
---     all_on  = {{"cmd", "alt", "ctrl"}, "L"},
---     all_off = {{"cmd", "alt", "ctrl"}, "K"},
---     chooser = {{"cmd", "alt", "ctrl"}, "space"},  -- palette au clavier (optionnel)
---     travail = {{"cmd", "alt", "ctrl"}, "1"},      -- toute autre clé = nom de scène
---   })

local obj = {}
obj.__index = obj

obj.name = "LedControl"
obj.version = "0.4.0"
obj.author = "ledcontrol"
obj.license = "MIT"

obj.baseUrl = "http://127.0.0.1:8787"

-- Démarrage automatique si l'app ne répond pas :
obj.appName = "LedControl"   -- utilisé par `open -a <appName>` (bundle dans /Applications)
obj.appPath = nil            -- alternative : chemin absolu vers LedControl.app

-- --- HTTP helpers ---------------------------------------------------------

function obj:_get(path, cb)
  hs.http.asyncGet(self.baseUrl .. path, nil, function(status, body)
    if status ~= 200 then
      hs.printf("[LedControl] GET %s -> %s", path, tostring(status))
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
        hs.alert.show("LedControl : échec (" .. tostring(status) .. ")")
      end
      if cb then cb(status == 200) end
    end)
end

-- --- Démarrage automatique de l'app ---------------------------------------

-- L'API répond-elle ? (un statut négatif = connexion refusée → app absente)
function obj:_alive(cb)
  hs.http.asyncGet(self.baseUrl .. "/api/scenes", nil, function(status) cb(status == 200) end)
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
          hs.alert.show("LedControl : démarrage impossible")
        end
      end)
    end)
  end)
end

-- --- Actions (chacune démarre l'app si besoin) ----------------------------

-- Ouvre (fait remonter) la fenêtre de l'app native. La démarre si besoin.
function obj:show() self:ensureRunning(function() self:_post("/api/show") end) end

function obj:allOn() self:ensureRunning(function() self:_post("/api/all/on") end) end
function obj:allOff() self:ensureRunning(function() self:_post("/api/all/off") end) end
function obj:toggleDevice(id)
  self:ensureRunning(function() self:_post("/api/devices/" .. id .. "/toggle") end)
end
function obj:applyScene(name)
  self:ensureRunning(function()
    self:_post("/api/scenes/" .. hs.http.encodeForQuery(name), function()
      hs.alert.show("Scène : " .. name)
    end)
  end)
end

-- --- Chooser (palette au clavier) -----------------------------------------

function obj:showChooser()
  self:ensureRunning(function() self:_showChooserNow() end)
end

function obj:_showChooserNow()
  -- Récupère appareils + scènes puis affiche une palette de sélection.
  self:_get("/api/devices", function(devices)
    self:_get("/api/scenes", function(scenes)
      local choices = {}
      for _, name in ipairs(scenes or {}) do
        choices[#choices + 1] = {
          text = "🎬 Scène : " .. name,
          subText = "Appliquer la scène",
          act = { kind = "scene", name = name },
        }
      end
      choices[#choices + 1] = { text = "🔆 Tout allumer", act = { kind = "all", on = true } }
      choices[#choices + 1] = { text = "🌙 Tout éteindre", act = { kind = "all", on = false } }
      for _, dev in ipairs(devices or {}) do
        local st = dev.state or {}
        local mark = st.reachable == false and "⚠︎ " or (st.on and "🟢 " or "⚪ ")
        choices[#choices + 1] = {
          text = mark .. dev.name,
          subText = dev.type .. " — basculer on/off",
          act = { kind = "toggle", id = dev.id },
        }
      end

      local chooser = hs.chooser.new(function(sel)
        if not sel then return end
        local a = sel.act
        if a.kind == "scene" then
          self:applyScene(a.name)
        elseif a.kind == "all" then
          self:_post("/api/all/" .. (a.on and "on" or "off"))
        elseif a.kind == "toggle" then
          self:toggleDevice(a.id)
        end
      end)
      chooser:placeholderText("LedControl — scène, tout ON/OFF, ou appareil…")
      chooser:choices(choices)
      chooser:show()
    end)
  end)
end

-- --- Raccourcis -----------------------------------------------------------

function obj:bindHotkeys(mapping)
  local actions = {
    show = function() self:show() end,       -- ouvre la fenêtre de l'app native
    all_on = function() self:allOn() end,
    all_off = function() self:allOff() end,
    chooser = function() self:showChooser() end,
  }
  for action, spec in pairs(mapping) do
    -- Toute clé non réservée est traitée comme un nom de scène.
    local fn = actions[action] or function() self:applyScene(action) end
    hs.hotkey.bind(spec[1], spec[2], fn)
  end
  return self
end

return obj
