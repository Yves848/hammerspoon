--- === CheatSheet ===
---
--- Affiche une fenêtre popup **flottante** (via `hs.webview`) listant tous les raccourcis
--- clavier et leur description, façon « which-key ». Un même raccourci l'affiche et le
--- masque ; `Échap` ferme aussi. La fenêtre est *non-activante* : elle apparaît sans voler
--- le focus à l'application courante.
---
--- Les données sont hiérarchisées sur deux niveaux :
---   * `obj.groups` : les **domaines**, rendus en **onglets** (ex. « Hammerspoon », « Ghostty »).
---     Forme : `{ { title, subtitle?, sections = { ... } }, ... }`.
---   * chaque groupe contient des `sections` (les cartes façon which-key), forme :
---     `{ title, accent, items = { { keys, description }, ... } }`.
--- S'il n'y a qu'un seul groupe, aucun onglet n'est affiché (rendu « à plat »).
---
--- Navigation entre onglets : clic sur l'onglet, ou `⇥` / `⇧⇥` pour cycler, ou `1`…`9`
--- pour aller directement à un onglet (touches captées par le modal tant que l'aide est
--- visible). La hauteur de la fenêtre s'ajuste à l'onglet **le plus haut** → pas de saut
--- de taille au changement d'onglet.
---
--- Rétro-compatibilité : si `obj.groups` est vide mais `obj.sections` est défini (ancien
--- format), ces sections sont rendues comme un unique groupe sans onglet.
---
--- Usage dans ~/.hammerspoon/init.lua :
---   hs.loadSpoon("CheatSheet")
---   -- Optionnel : remplacer/compléter les groupes (sinon le défaut est utilisé)
---   -- spoon.CheatSheet.groups = {
---   --   { title = "Hammerspoon", sections = { ... } },
---   --   { title = "Ghostty",     sections = { ... } },
---   -- }
---   spoon.CheatSheet:bindHotkeys({ toggle = { { "ctrl", "alt" }, "h" } })
---
--- Chaque item est { keys, description }. Dans `keys`, les jetons séparés par des espaces
--- sont rendus en touches (`<kbd>`) ; les séparateurs « / · … + » restent en texte discret.
--- Groupez les modificateurs (« ⌃⌥⌘ ») et espacez ce qui doit devenir des touches distinctes
--- (« ← → ↑ ↓ »).

local obj = {}
obj.__index = obj

obj.name = "CheatSheet"
obj.version = "1.1"
obj.author = "ledcontrol"
obj.license = "MIT"

-- Titre affiché en haut de la fenêtre.
obj.title = "Raccourcis"

-- Sous-titre global : conservé pour rétro-compat quand on n'utilise que `obj.sections`.
-- Avec `obj.groups`, préférez un `subtitle` par groupe (affiché sous ses onglets).
obj.subtitle = nil

-- Dimensions de la fenêtre (px). La hauteur est recalculée sur l'onglet le plus haut ;
-- le corps défile si besoin.
obj.width = 980
obj.height = 660

-- Jeu par défaut (config de l'auteur), hiérarchisé en domaines → onglets. Surchargeable
-- depuis init.lua via `spoon.CheatSheet.groups`.
obj.groups = {
  { title = "Hammerspoon",
    subtitle = "Placement des fenêtres : Rectangle Pro (⌃⌥ + touche)",
    sections = {
      { title = "Placement — Rectangle Pro", accent = "#3fb6c9", items = {
        { "⌃⌥ ← → ↑ ↓", "Moitié gauche / droite / haut / bas" },
        { "⌃⌥ U I J K",  "Quarts : haut-g / haut-d / bas-g / bas-d" },
        { "⌃⌥ D F G",    "Tiers : gauche / centre / droite" },
        { "⌃⌥ E / T",    "Deux-tiers : gauche / droite" },
        { "⌃⌥ ↩",        "Maximiser" },
        { "⌃⌥ C",        "Centrer" },
        { "⌃⌥ ⌫",        "Restaurer la taille précédente" },
        { "⌃⌥ = / −",    "Agrandir / réduire" },
        { "⌃⌥⌘ → / ←",   "Envoyer à l'écran suivant / précédent" },
      } },
      { title = "Fenêtre au pixel (flottantes)", accent = "#e0a13a", items = {
        { "⇧⌥ ← → ↑ ↓", "Déplacer par pas (50 px)" },
        { "⌘⌃ ← →",     "Redimensionner — largeur" },
        { "⌘⌃ ↑ ↓",     "Redimensionner — hauteur" },
      } },
      { title = "Éclairage & domotique", accent = "#f0803a", items = {
        { "⌃⌥ L", "LedControl — ouvrir la fenêtre" },
        { "⌃⌥ T", "LedControl — scène « travail »" },
        { "⌃⌥ D", "LedControl — scène « détente »" },
        { "⌃⌥ O", "LedControl — tout éteindre" },
        { "⌃⌥ W", "WLED — palette (chooser)" },
        { "⌃⌥ A", "Aquarium — palette (on / off / état)" },
      } },
      { title = "Son", accent = "#e35aa8", items = {
        { "⌃⌥ B", "SoundControl — popup profils (puis 1…9, Échap)" },
      } },
      { title = "Système & divers", accent = "#8b97a8", items = {
        { "⌃⌥ N",  "Synology — monter les partages SMB" },
        { "⌃⌥ P",  "Pavé num. « . » ⇄ « , » (bascule)" },
        { "⌘⌥⌃ R", "Recharger la config Hammerspoon" },
        { "⌃⌥ H",  "Afficher / masquer cette aide" },
        { "menubar 🔁 / ❌", "SwapKeys : < / > ⇄ @ / # (clic sur l'icône)" },
      } },
    } },

  { title = "Ghostty",
    subtitle = "Défauts Ghostty + config perso (~/.config/ghostty/config)",
    sections = {
      { title = "Config & application", accent = "#cba6f7", items = {
        { "⌘ ,",   "Ouvrir la config" },
        { "⌘⇧ , / ⌘⇧ R", "Recharger la config" },
        { "⌘⇧ P",  "Palette de commandes" },
        { "⌘⌥ I",  "Inspector (basculer)" },
        { "⌘ Q",   "Quitter" },
      } },
      { title = "Presse-papiers & sélection", accent = "#89b4fa", items = {
        { "⌘ C",         "Copier" },
        { "⌘ V",         "Coller" },
        { "⌘⇧ V",        "Coller (sélection primaire)" },
        { "⌘ A",         "Tout sélectionner" },
        { "⇧ ← → ↑ ↓",   "Étendre la sélection" },
        { "⇧ ⇞ ⇟ ↖ ↘",  "Étendre : page / début / fin" },
      } },
      { title = "Police", accent = "#94e2d5", items = {
        { "⌘ =", "Agrandir" },
        { "⌘ −", "Réduire" },
        { "⌘ 0", "Taille par défaut" },
      } },
      { title = "Édition", accent = "#f9e2af", items = {
        { "⌘ Z",  "Annuler" },
        { "⌘⇧ Z", "Rétablir" },
      } },
      { title = "Onglets", accent = "#a6e3a1", items = {
        { "⌘ T",         "Nouvel onglet" },
        { "⌘ 1 … 8",     "Aller à l'onglet N (touche physique, OK AZERTY)" },
        { "⌘ 9",         "Dernier onglet" },
        { "⌃ ⇥ / ⌃⇧ ⇥",  "Onglet suivant / précédent" },
        { "⌘⇧ ← / →",    "Déplacer l'onglet" },
        { "⌘⌃ T",        "Renommer l'onglet" },
        { "⌘⌥ W",        "Fermer l'onglet" },
      } },
      { title = "Fenêtres & plein écran", accent = "#89dceb", items = {
        { "⌘ N",        "Nouvelle fenêtre" },
        { "⌘ W",        "Fermer (surface)" },
        { "⌘⇧ W",       "Fermer la fenêtre" },
        { "⌘⌥⇧ W",      "Tout fermer" },
        { "⌘ ↩ / ⌘⌃ F", "Plein écran" },
        { "⌘⌃ M",       "Maximiser" },
        { "⌘⌃ 0",       "Réinitialiser la taille" },
        { "⌘⌃ P",       "Épingler au-dessus" },
      } },
      { title = "Splits (panneaux)", accent = "#f38ba8", items = {
        { "⌘ D",        "Split à droite" },
        { "⌘⇧ D",       "Split en bas" },
        { "⌘⌥ ← → ↑ ↓", "Aller au split (direction)" },
        { "⌘⌃ ← → ↑ ↓", "Redimensionner le split" },
        { "⌘⌃ =",       "Égaliser les splits" },
        { "⌘⇧ ↩",       "Zoom split (basculer)" },
        { "⌘⌥ T",       "Renommer le split" },
      } },
      { title = "Défilement & prompts", accent = "#fab387", items = {
        { "⌘ ↖ / ⌘ ↘",  "Haut / bas de l'historique" },
        { "⌘ ⇞ / ⌘ ⇟",  "Page précédente / suivante" },
        { "⌘ K",        "Effacer l'écran" },
        { "⌘ J",        "Défiler vers la sélection" },
        { "⌘ ↑ / ⌘⇧ ↑", "Prompt précédent" },
        { "⌘⇧ ↓",       "Prompt suivant" },
      } },
      { title = "Terminal rapide", accent = "#f5c2e7", items = {
        { "⌘ ↓", "Quick terminal (basculer)" },
      } },
      { title = "Recherche", accent = "#b4befe", items = {
        { "⌘ F",          "Rechercher" },
        { "⌘ E",          "Rechercher la sélection" },
        { "⌘ G / ⌘⇧ G",   "Occurrence suivante / précédente" },
        { "⌘⇧ F / Échap", "Fermer la recherche" },
      } },
      { title = "Export & saisie shell", accent = "#eba0ac", items = {
        { "⌘⌃⇧ J",      "Écrire l'écran → copier" },
        { "⌘⇧ J",       "Écrire l'écran → coller" },
        { "⌘⌥⇧ J",      "Écrire l'écran → ouvrir" },
        { "⌘ → / ⌘ ←",  "Fin / début de ligne (⌃E / ⌃A)" },
        { "⌘ ⌫",        "Effacer la ligne (⌃U)" },
        { "⌥ ← / ⌥ →",  "Mot précédent / suivant" },
      } },
      { title = "Affichage & divers", accent = "#f2cdcd", items = {
        { "⌘⌃ O",  "Transparence du fond (on/off)" },
        { "⌘⌃⇧ A", "Vue d'ensemble des onglets" },
      } },
      { title = "Pavé num. (Magic Keyboard)", accent = "#74c7ec", items = {
        { "⌘ 1 … 8", "Aller à l'onglet N" },
        { "⌘ 9",     "Dernier onglet" },
        { "⌘ + / −", "Police plus grande / plus petite" },
        { "⌘ ,",     "Taille de police par défaut" },
        { "⌘ =",     "Égaliser les splits" },
      } },
    } },

  { title = "Neovim (LazyVim)",
    subtitle = "Défauts LazyVim · leader = Espace, localleader = \\",
    sections = {
      { title = "Fenêtres (splits)", accent = "#cba6f7", items = {
        { "⌃ h j k l",  "Aller à la fenêtre gauche / bas / haut / droite" },
        { "⌃ ← → ↑ ↓",  "Redimensionner la fenêtre" },
        { "Espace -",   "Split horizontal (dessous)" },
        { "Espace |",   "Split vertical — AZERTY : | = ⌥⇧L" },
        { "Espace w d", "Fermer la fenêtre" },
        { "Espace w m", "Zoom (agrandir / restaurer)" },
        { "Espace u z", "Mode Zen" },
      } },
      { title = "Buffers", accent = "#89b4fa", items = {
        { "⇧ h / ⇧ l",  "Buffer précédent / suivant (AZERTY-friendly)" },
        { "Espace b j", "Pick — sauter à un buffer par lettre" },
        { "Espace b b", "Basculer vers le buffer alterné" },
        { "Espace b d", "Fermer le buffer (garde la fenêtre)" },
        { "Espace b o", "Fermer les autres buffers" },
        { "[b / ]b",    "Idem préc./suiv. — AZERTY : [ ] = ⌥⇧( ⌥⇧)" },
        { "[B / ]B",    "Déplacer le buffer — mêmes touches [ ]" },
      } },
      { title = "Onglets", accent = "#a6e3a1", items = {
        { "Espace ⇥ ⇥",         "Nouvel onglet" },
        { "Espace ⇥ ] / ⇥ [",   "Onglet suivant / précédent" },
        { "Espace ⇥ f / ⇥ l",   "Premier / dernier onglet" },
        { "Espace ⇥ d",         "Fermer l'onglet" },
        { "Espace ⇥ o",         "Fermer les autres onglets" },
        { "g t / g T",          "Onglet suivant / précédent (Vim)" },
      } },
      { title = "Recherche & navigation", accent = "#94e2d5", items = {
        { "Espace Espace", "Chercher un fichier" },
        { "Espace ,",      "Chercher parmi les buffers ouverts" },
        { "Espace e",      "Explorateur de fichiers" },
        { "Espace s g",    "Rechercher dans le projet (grep)" },
        { "s",             "Saut à l'écran (flash — 2 lettres)" },
        { "⌃ o / ⌃ i",     "Reculer / avancer (jumplist)" },
      } },
      { title = "Aide & divers", accent = "#f9e2af", items = {
        { "Espace",     "which-key — menu contextuel des raccourcis" },
        { "Espace c f", "Formater le fichier" },
        { "Espace l",   "Lazy (gestionnaire de plugins)" },
        { "Espace q q", "Quitter tout" },
      } },
    } },
}

-- Séparateurs rendus en texte discret plutôt qu'en touche.
local SEPARATORS = { ["/"] = true, ["·"] = true, ["…"] = true }

-- Échappe le texte destiné au HTML (descriptions, libellés de touches).
local function esc(s)
  return (tostring(s):gsub("[&<>]", { ["&"] = "&amp;", ["<"] = "&lt;", [">"] = "&gt;" }))
end

-- Transforme "⌃⌥⌘ , / ;" en une suite de <kbd> + séparateurs.
local function renderKeys(keys)
  local parts = {}
  for tok in keys:gmatch("%S+") do
    if SEPARATORS[tok] then
      parts[#parts + 1] = '<span class="sep">' .. esc(tok) .. "</span>"
    else
      parts[#parts + 1] = "<kbd>" .. esc(tok) .. "</kbd>"
    end
  end
  return table.concat(parts, " ")
end

-- Renvoie la liste des groupes (domaines). Rétro-compat : si `obj.groups` est vide mais
-- `obj.sections` existe (ancien format), on enveloppe ces sections dans un unique groupe.
function obj:_groups()
  if self.groups and #self.groups > 0 then return self.groups end
  return { { title = self.title, subtitle = self.subtitle, sections = self.sections or {} } }
end

-- Rend le corps d'un groupe : son sous-titre optionnel + la grille de cartes.
local function renderGroup(g)
  local cards = {}
  for _, sec in ipairs(g.sections or {}) do
    local rows = {}
    for _, it in ipairs(sec.items or {}) do
      rows[#rows + 1] = string.format(
        '<tr><td class="k">%s</td><td class="d">%s</td></tr>',
        renderKeys(it[1]), esc(it[2]))
    end
    local accent = sec.accent or "#4b9fff"
    cards[#cards + 1] = string.format(
      '<section class="card"><h2 style="color:%s;border-color:%s">%s</h2>'
        .. '<table>%s</table></section>',
      accent, accent, esc(sec.title), table.concat(rows))
  end
  local sub = (g.subtitle and g.subtitle ~= "")
    and ('<div class="sub">' .. esc(g.subtitle) .. "</div>") or ""
  return sub .. '<div class="grid">' .. table.concat(cards) .. "</div>"
end

--- Construit le document HTML complet (thème sombre translucide) à partir de `obj.groups`.
function obj:_html()
  local groups = self:_groups()
  local hasTabs = #groups > 1

  local tabs, panels = {}, {}
  for i, g in ipairs(groups) do
    local active = (i == 1) and " active" or ""
    if hasTabs then
      tabs[#tabs + 1] = string.format(
        '<button class="tab%s" onclick="selectTab(%d)">%s</button>',
        active, i - 1, esc(g.title or ("Onglet " .. i)))
    end
    panels[#panels + 1] = string.format(
      '<div class="tabpanel%s">%s</div>', active, renderGroup(g))
  end
  local nav = hasTabs and ('<nav class="tabs">' .. table.concat(tabs) .. "</nav>") or ""
  local hint = hasTabs
    and '<kbd>1</kbd>…<kbd>9</kbd> / <kbd>⇥</kbd> onglets · <kbd>Échap</kbd> fermer'
    or '<kbd>Échap</kbd> ou <kbd>⌃⌥H</kbd> pour fermer'

  return [[<!doctype html><html lang="fr"><head><meta charset="utf-8"><style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    html, body { background: transparent; overflow: hidden; }
    body {
      font-family: -apple-system, "Helvetica Neue", Arial, sans-serif;
      color: #e6e9ef; padding: 14px; -webkit-user-select: none; user-select: none;
    }
    .panel {
      background: rgba(24, 27, 34, 0.97); border: 1px solid rgba(255,255,255,0.08);
      border-radius: 16px; padding: 16px 18px 14px;
      box-shadow: 0 18px 60px rgba(0,0,0,0.55);
    }
    header { display: flex; align-items: baseline; justify-content: space-between;
      margin-bottom: 12px; padding-bottom: 8px; border-bottom: 1px solid rgba(255,255,255,0.08); }
    header h1 { font-size: 16px; font-weight: 600; letter-spacing: .2px; }
    header .hint { font-size: 11px; color: #8b93a3; }
    header .hint kbd { font-size: 10px; }
    .tabs { display: flex; gap: 6px; margin-bottom: 12px; }
    .tab {
      font-family: inherit; font-size: 12px; font-weight: 600; letter-spacing: .2px;
      color: #aab2c2; background: rgba(255,255,255,0.04);
      border: 1px solid rgba(255,255,255,0.08); border-radius: 9px;
      padding: 5px 14px; cursor: pointer; -webkit-user-select: none;
      transition: background .12s, color .12s, border-color .12s;
    }
    .tab:hover { color: #e6e9ef; background: rgba(255,255,255,0.08); }
    .tab.active {
      color: #0f1219; background: #e6e9ef; border-color: #e6e9ef;
    }
    .tabpanel { display: none; }
    .tabpanel.active { display: block; }
    .sub { font-size: 11px; color: #8b93a3; margin: -2px 0 11px; }
    .grid { column-count: 3; column-gap: 16px; }
    @media (max-width: 720px) { .grid { column-count: 2; } }
    .card { break-inside: avoid; margin-bottom: 13px; }
    .card h2 { font-size: 11px; font-weight: 700; text-transform: uppercase;
      letter-spacing: .4px; padding-bottom: 3px; margin-bottom: 3px;
      border-bottom: 1px solid; }
    table { width: 100%; border-collapse: collapse; }
    td { padding: 2.5px 0; vertical-align: middle; font-size: 12px; }
    td.k { text-align: right; white-space: nowrap; width: 1%; padding-right: 10px; }
    td.d { color: #c3c9d4; }
    kbd { display: inline-block; font-family: inherit; font-size: 11px; font-weight: 600;
      min-width: 15px; text-align: center; padding: 1px 5px; margin: 1px;
      color: #eef1f6; background: #2b3140;
      border: 1px solid #3d4557; border-bottom-width: 2px; border-radius: 5px; }
    .sep { color: #6b7385; padding: 0 1px; }
  </style></head><body><div class="panel">
    <header><h1>]] .. esc(self.title) .. [[</h1>
    <span class="hint">]] .. hint .. [[</span></header>]]
    .. nav .. table.concat(panels)
    .. [[<script>
    function selectTab(i){
      var t=document.querySelectorAll('.tab'), p=document.querySelectorAll('.tabpanel');
      for(var x=0;x<t.length;x++) t[x].classList.toggle('active', x===i);
      for(var x=0;x<p.length;x++) p[x].classList.toggle('active', x===i);
    }
    </script>
  </div></body></html>]]
end

-- Crée (une seule fois) le modal qui capte Échap — et la navigation entre onglets — quand
-- la fenêtre est visible.
function obj:_ensureModal()
  if self._modal then return end
  self._modal = hs.hotkey.modal.new()
  self._modal:bind({}, "escape", function() self:hide() end)
  local n = #self:_groups()
  if n > 1 then
    self._modal:bind({}, "tab", function() self:_cycleTab(1) end)
    self._modal:bind({ "shift" }, "tab", function() self:_cycleTab(-1) end)
    for i = 1, math.min(n, 9) do
      self._modal:bind({}, tostring(i), function() self:_selectTab(i) end)
    end
  end
end

-- Sélectionne l'onglet `i` (1-based) et le reflète dans le webview.
function obj:_selectTab(i)
  local n = #self:_groups()
  if i < 1 or i > n then return end
  self._tab = i - 1
  if self._webview then self._webview:evaluateJavaScript("selectTab(" .. self._tab .. ")") end
end

-- Cycle d'onglet (`dir` = +1 / -1), avec bouclage.
function obj:_cycleTab(dir)
  local n = #self:_groups()
  if n < 1 then return end
  self._tab = ((self._tab or 0) + dir) % n
  if self._webview then self._webview:evaluateJavaScript("selectTab(" .. self._tab .. ")") end
end

-- Marge transparente (px) autour du panneau, de chaque côté — laisse respirer l'ombre CSS
-- et sert au calcul de la hauteur finale. Doit valoir le `padding` du <body>.
local BODY_MARGIN = 14

-- Ajuste la hauteur de la fenêtre à celle de l'onglet **le plus haut** (+ marges) et la
-- re-centre verticalement sur l'écran `scr`. Mesurer le max garde la fenêtre stable quand
-- on change d'onglet. Appelé une fois le chargement terminé.
function obj:_fitHeight(scr, w)
  if not self._webview then return end
  -- On force `display:block` en inline pour mesurer chaque panneau, PUIS on remet
  -- systématiquement `display=''` : ne laisser aucun style inline, sinon il l'emporterait
  -- sur la règle CSS `.tabpanel:not(.active){display:none}` et l'onglet inactif resterait
  -- visible (empilé sous l'actif) au changement d'onglet.
  local js = [[(function(){
    var panels=document.querySelectorAll('.tabpanel'), max=0;
    for(var i=0;i<panels.length;i++){
      var p=panels[i];
      p.style.display='block';
      if(p.scrollHeight>max) max=p.scrollHeight;
      p.style.display='';
    }
    var panel=document.querySelector('.panel');
    var act=document.querySelector('.tabpanel.active');
    var chrome=panel.getBoundingClientRect().height-(act?act.getBoundingClientRect().height:0);
    return Math.ceil(chrome+max);
  })()]]
  self._webview:evaluateJavaScript(js, function(res)
    local ch = tonumber(res)
    if not ch or not self._webview then return end
    local nh = ch + 2 * BODY_MARGIN
    self._webview:frame({
      x = scr.x + (scr.w - w) / 2,
      y = scr.y + (scr.h - nh) / 2,
      w = w, h = nh,
    })
  end)
end

--- Affiche la fenêtre (recrée le webview à chaque fois → contenu toujours à jour).
--- La hauteur est ajustée à l'onglet le plus haut une fois le HTML chargé
--- (navigationCallback → evaluateJavaScript) : pas d'espace vide, centrage vertical exact.
function obj:show()
  self:_ensureModal()
  if self._webview then self:hide() end
  self._tab = 0
  local scr = (hs.screen.mainScreen() or hs.screen.primaryScreen()):frame()
  local w, h = self.width, self.height
  local rect = {
    x = scr.x + (scr.w - w) / 2,
    y = scr.y + (scr.h - h) / 2,
    w = w, h = h,
  }
  local masks = hs.webview.windowMasks
  self._webview = hs.webview.new(rect)
    :windowStyle(masks.borderless | masks.nonactivating)
    :level(hs.drawing.windowLevels.modalPanel)
    :shadow(false) -- pas d'ombre native (rectangulaire) → ombre gérée en CSS sur le panneau
    :transparent(true)
    :allowTextEntry(false)
    :navigationCallback(function(action)
      -- Le contenu est mis en page → on peut mesurer et ajuster la hauteur.
      if action == "didFinishNavigation" then self:_fitHeight(scr, w) end
    end)
    :html(self:_html())
  self._webview:show()
  self._modal:enter() -- capte Échap + navigation onglets tant que la fenêtre est visible
  self._visible = true
  return self
end

--- Masque et détruit la fenêtre.
function obj:hide()
  if self._webview then
    self._webview:delete()
    self._webview = nil
  end
  if self._modal then self._modal:exit() end
  self._visible = false
  return self
end

--- Bascule affichage/masquage.
function obj:toggle()
  if self._visible then self:hide() else self:show() end
  return self
end

--- bindHotkeys : action reconnue `toggle` (afficher/masquer la fenêtre d'aide).
function obj:bindHotkeys(mapping)
  self:_ensureModal()

  local spec = mapping and mapping.toggle
  if spec then
    hs.hotkey.bind(spec[1], spec[2], function() self:toggle() end)
  end
  return self
end

return obj
