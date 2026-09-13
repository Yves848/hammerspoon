--- === LedControl ===
---
--- Déclencheur clavier de LedControl.
---
--- Le **service LedControl** (headless, sur le LXC) est l'autorité unique : il tourne 24/7 et
--- expose l'API HTTP `http://192.168.50.207:8787`. Hammerspoon déclenche les actions directement
--- sur ce service (plus besoin que l'app de bureau tourne). L'app de bureau (« spoon ») n'est
--- qu'une télécommande visuelle ; `show` la fait remonter via son schéma d'URL `ledcontrol://show`.
---
--- Installation :
---   cp -r hammerspoon/LedControl.spoon ~/.hammerspoon/Spoons/
--- Dans ~/.hammerspoon/init.lua :
---   local led = hs.loadSpoon("LedControl")
---   -- led.baseUrl = "http://192.168.50.207:8787" -- optionnel (défaut : le LXC)
---   -- led.showUrl = "ledcontrol://show"          -- URL pour faire remonter la fenêtre (défaut)
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
obj.version = "0.5.0"
obj.author = "ledcontrol"
obj.license = "MIT"

-- Le service LedControl (LXC). Surchargeable depuis ~/.hammerspoon/init.lua.
obj.baseUrl = "http://192.168.50.207:8787"

-- Pour `show` : ouvre l'URL `ledcontrol://show`, que l'app agent gère en faisant remonter sa
-- fenêtre (et se lance si besoin). Plus fiable qu'`open -a` pour une app sans icône Dock.
obj.showUrl = "ledcontrol://show"

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

-- --- Actions (directes sur le service, toujours disponible) ----------------

-- Fait remonter la fenêtre de l'app de bureau (la démarre si besoin) via son schéma d'URL.
-- Aucun appel au service : le service headless du LXC ne peut pas afficher de fenêtre sur le Mac.
function obj:show()
  hs.execute('/usr/bin/open "' .. self.showUrl .. '"')
end

function obj:allOn() self:_post("/api/all/on") end
function obj:allOff() self:_post("/api/all/off") end
function obj:toggleDevice(id) self:_post("/api/devices/" .. id .. "/toggle") end
function obj:applyScene(name)
  self:_post("/api/scenes/" .. hs.http.encodeForQuery(name), function()
    hs.alert.show("Scène : " .. name)
  end)
end

-- --- Chooser (palette au clavier) -----------------------------------------

function obj:showChooser()
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
    show = function() self:show() end,       -- ouvre la fenêtre de l'app de bureau
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
