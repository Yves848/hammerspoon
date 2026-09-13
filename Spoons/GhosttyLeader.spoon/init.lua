local obj = {}
obj.__index = obj

obj.name = "GhosttyLeader"
obj.version = "0.2.2"
obj.author = "YG"
obj.homepage = ""
obj.license = "MIT"

local ghosttyBundleID = "com.mitchellh.ghostty"
local leaderKey = "F20"
local showDelay = 0.275
local idleTimeout = 8

local canvas = nil
local timer = nil
local idleTimer = nil
local modal = nil
local leaderHotkey = nil
local appWatcher = nil
local actionTasks = {}
local activePath = {}

local bindings = {
	["h"] = { label = "Split ←", action = "goto_split:left" },
	["j"] = { label = "Split ↓", action = "goto_split:down" },
	["k"] = { label = "Split ↑", action = "goto_split:up" },
	["l"] = { label = "Split →", action = "goto_split:right" },

	["v"] = { label = "Split right", action = "new_split:right" },
	["s"] = { label = "Split down", action = "new_split:down" },
	["z"] = { label = "Zoom split", action = "toggle_split_zoom" },

	["n"] = { label = "New tab", action = "new_tab" },

	["1"] = { label = "Agent", action = "goto_tab:1" },
	["2"] = { label = "Shell", action = "goto_tab:2" },
	["3"] = { label = "Tests", action = "goto_tab:3" },
	["4"] = { label = "Git", action = "goto_tab:4" },

	["w"] = {
		label = "Window…",
		children = {
			["m"] = { label = "Maximize", action = "toggle_maximize" },
			["f"] = { label = "Fullscreen", action = "toggle_fullscreen" },
			["c"] = { label = "Center", windowAction = "centerOnScreen" },
		},
	},
}

local function isGhosttyFrontmost()
	local app = hs.application.frontmostApplication()
	return app and app:bundleID() == ghosttyBundleID
end

local function currentBindings()
	local node = bindings

	for _, key in ipairs(activePath) do
		if not node[key] or not node[key].children then
			return {}
		end
		node = node[key].children
	end

	return node
end

local function currentTitle()
	if #activePath == 0 then
		return "Ghostty"
	end

	local parts = { "Ghostty" }
	local node = bindings

	for _, key in ipairs(activePath) do
		local item = node[key]
		if item then
			table.insert(parts, (item.label:gsub("…$", "")))
			node = item.children or {}
		end
	end

	return table.concat(parts, " › ")
end

local function sortedKeys(tbl)
	local keys = {}

	for key, _ in pairs(tbl) do
		table.insert(keys, key)
	end

	table.sort(keys, function(a, b)
		local an = tonumber(a)
		local bn = tonumber(b)

		if an and bn then
			return an < bn
		elseif an then
			return false
		elseif bn then
			return true
		end

		return a < b
	end)

	return keys
end

local function buildLines()
	local node = currentBindings()
	local keys = sortedKeys(node)

	local lines = {}

	for _, key in ipairs(keys) do
		local item = node[key]
		table.insert(lines, {
			key = key,
			label = item.label,
		})
	end

	return lines
end

local function destroyCanvas()
	if canvas then
		canvas:delete()
		canvas = nil
	end
end

local function hideHelper()
	-- Release hotkeys first, even if drawing cleanup fails afterwards.
	if modal then
		local previous = modal
		modal = nil
		previous:exit()
		previous:delete()
	end
	if timer then
		timer:stop()
		timer = nil
	end
	if idleTimer then
		idleTimer:stop()
		idleTimer = nil
	end
	activePath = {}
	destroyCanvas()
end

local function guarded(fn)
	return function(...)
		local ok, err = xpcall(fn, debug.traceback, ...)
		if not ok then
			hideHelper()
			hs.printf("[GhosttyLeader] %s", err)
			hs.alert.show("GhosttyLeader : erreur, mode fermé")
		end
	end
end

local function createCanvas()
	destroyCanvas()

	local win = hs.window.frontmostWindow()
	if not win then
		return
	end

	local wf = win:frame()
	local lines = buildLines()

	if #lines == 0 then
		return
	end

	local columns = 2
	local rows = math.ceil(#lines / columns)

	local width = math.min(620, math.floor(wf.w * 0.72))
	local lineHeight = 30
	local headerHeight = 44
	local footerHeight = 24
	local padding = 18
	local height = headerHeight + rows * lineHeight + footerHeight + padding * 2

	local x = wf.x + math.floor((wf.w - width) / 2)
	local y = wf.y + math.floor(wf.h * 0.64)

	if y + height > wf.y + wf.h - 20 then
		y = wf.y + wf.h - height - 20
	end

	canvas = hs.canvas.new({
		x = x,
		y = y,
		w = width,
		h = height,
	})

	canvas:level(hs.canvas.windowLevels.overlay)
	canvas:behavior({
		"canJoinAllSpaces",
		"stationary",
		"ignoresCycle",
	})

	canvas[1] = {
		type = "rectangle",
		action = "fill",
		fillColor = {
			hex = "#1e1e2e",
			alpha = 0.94,
		},
		roundedRectRadii = {
			xRadius = 12,
			yRadius = 12,
		},
	}

	canvas[2] = {
		type = "rectangle",
		action = "stroke",
		strokeColor = {
			hex = "#6c7086",
			alpha = 0.9,
		},
		strokeWidth = 1,
		roundedRectRadii = {
			xRadius = 12,
			yRadius = 12,
		},
	}

	canvas[3] = {
		type = "text",
		text = currentTitle(),
		textColor = { hex = "#cba6f7" },
		textFont = "Maple Mono NF",
		textSize = 16,
		textStyle = {
			alignment = "left",
		},
		frame = {
			x = padding,
			y = padding,
			w = width - padding * 2,
			h = 28,
		},
	}

	local colWidth = math.floor((width - padding * 2) / columns)

	for i, item in ipairs(lines) do
		local col = (i - 1) % columns
		local row = math.floor((i - 1) / columns)

		local tx = padding + col * colWidth
		local ty = padding + headerHeight + row * lineHeight

		canvas[#canvas + 1] = {
			type = "text",
			text = string.upper(item.key),
			textColor = { hex = "#fab387" },
			textFont = "Maple Mono NF",
			textSize = 14,
			frame = {
				x = tx,
				y = ty,
				w = 34,
				h = lineHeight,
			},
		}

		canvas[#canvas + 1] = {
			type = "text",
			text = item.label,
			textColor = { hex = "#cdd6f4" },
			textFont = "Maple Mono NF",
			textSize = 14,
			frame = {
				x = tx + 38,
				y = ty,
				w = colWidth - 42,
				h = lineHeight,
			},
		}
	end

	canvas[#canvas + 1] = {
		type = "text",
		text = "Esc cancel",
		textColor = { hex = "#a6adc8" },
		textFont = "Maple Mono NF",
		textSize = 11,
		textStyle = {
			alignment = "right",
		},
		frame = {
			x = padding,
			y = height - footerHeight - padding,
			w = width - padding * 2,
			h = footerHeight,
		},
	}

	canvas:show()
end

local function runAction(item)
	if not isGhosttyFrontmost() then return end
	if item.windowAction then
		local win = hs.window.frontmostWindow()
		if win and win:application():bundleID() == ghosttyBundleID then
			win[item.windowAction](win)
		end
		return
	end

	-- Ghostty 1.3+ native actions: no synthetic keys or keyboard listener.
	-- Async execution keeps Hammerspoon responsive even during an OS prompt.
	local script = string.format([[
		with timeout of 2 seconds
			tell application id "%s"
				if not frontmost then return false
				return perform action "%s" on focused terminal of selected tab of front window
			end tell
		end timeout
	]], ghosttyBundleID, item.action)
	local task
	task = hs.task.new("/usr/bin/osascript", function(code, stdout, stderr)
		actionTasks[task] = nil
		if code ~= 0 or not stdout:match("^true%s*$") then
			hs.printf("[GhosttyLeader] %s: %s %s", item.action, stdout, stderr)
			hs.alert.show("Ghostty : action indisponible — " .. item.label)
		end
	end, { "-e", script })
	assert(task, "Cannot create Ghostty action task")
	actionTasks[task] = true
	if not task:start() then
		actionTasks[task] = nil
		error("Cannot start Ghostty action task")
	end
end

local function resetIdleTimer()
	if idleTimer then idleTimer:stop() end
	idleTimer = hs.timer.doAfter(idleTimeout, guarded(hideHelper))
end

local enterLevel
enterLevel = function()
	if modal then
		modal:exit()
		modal:delete()
	end
	modal = hs.hotkey.modal.new()
	modal:bind({}, "escape", guarded(hideHelper))

	for key, item in pairs(currentBindings()) do
		local callback = guarded(function()
			if not isGhosttyFrontmost() then
				hideHelper()
				return
			end
			if item.children then
				table.insert(activePath, key)
				if timer then timer:stop(); timer = nil end
				enterLevel()
				createCanvas()
			else
				-- Exit before dispatch: failures cannot leave the modal active.
				hideHelper()
				runAction(item)
			end
		end)
		local digit = tonumber(key)
		if digit then
			-- Physical &/1, é/2, etc. on Belgian AZERTY; also Shift and keypad.
			local topRow = ({ 18, 19, 20, 21 })[digit]
			local keypad = ({ 83, 84, 85, 86 })[digit]
			modal:bind({}, topRow, callback)
			modal:bind({ "shift" }, topRow, callback)
			modal:bind({}, keypad, callback)
		else
			modal:bind({}, key, callback)
		end
	end
	modal:enter()
	resetIdleTimer()
end

local function onLeader()
	obj.leaderPresses = (obj.leaderPresses or 0) + 1
	if modal then
		hideHelper()
		return
	end
	if not isGhosttyFrontmost() or not hs.window.frontmostWindow() then return end
	hideHelper()
	enterLevel()
	timer = hs.timer.doAfter(showDelay, guarded(function()
		timer = nil
		if modal and isGhosttyFrontmost() then
			createCanvas()
		else
			hideHelper()
		end
	end))
end

-- Appel direct depuis Karabiner via le CLI hs, sans touche F20 synthétique.
function obj:toggle()
	guarded(onLeader)()
	return self
end

function obj:stop()
	hideHelper()
	if leaderHotkey then leaderHotkey:delete(); leaderHotkey = nil end
	if appWatcher then appWatcher:stop(); appWatcher = nil end
	for task in pairs(actionTasks) do task:terminate() end
	actionTasks = {}
	return self
end

function obj:start()
	self:stop()
	leaderHotkey = hs.hotkey.new({}, leaderKey, guarded(onLeader))
	local function updateApp(app)
		if app and app:bundleID() == ghosttyBundleID then
			leaderHotkey:enable()
		else
			hideHelper()
			leaderHotkey:disable()
		end
	end
	appWatcher = hs.application.watcher.new(guarded(function(_, event, app)
		if event == hs.application.watcher.activated then
			-- Use the event's app: the frontmost query can lag during a switch.
			updateApp(app)
		elseif event == hs.application.watcher.deactivated
			and app and app:bundleID() == ghosttyBundleID then
			-- Another app's late deactivation must not disable F20 again.
			-- The next activation decides whether the leader stays enabled.
			hideHelper()
		end
	end))
	appWatcher:start()
	updateApp(hs.application.frontmostApplication())
	return self
end

return obj
