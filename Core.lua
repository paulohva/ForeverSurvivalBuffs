--------------------------------------------------------------------------------
-- ForeverSurvivalBuffs: core (namespace, secret-safe helpers, events, saved data)
--------------------------------------------------------------------------------

local ADDON, ns = ...

ns.NAME = "ForeverSurvivalBuffs"
ns.ACCENT = "ffd100"   -- Blizzard gold
ns.ICON = "Interface\\AddOns\\ForeverSurvivalBuffs\\Media\\Icon"
-- the buffs window's round portrait only shows the middle of its texture: the same
-- cheese, smaller, with more background around it
ns.PORTRAIT = "Interface\\AddOns\\ForeverSurvivalBuffs\\Media\\Portrait"
-- the minimap button's ring hides the icon's edges: the cheese a little smaller, centred
ns.MINIMAP_ICON = "Interface\\AddOns\\ForeverSurvivalBuffs\\Media\\Minimap"

local DB_VERSION = 2

--------------------------------------------------------------------------------
-- Printing
--------------------------------------------------------------------------------

function ns.Print(fmt, ...)
	local msg = select("#", ...) > 0 and fmt:format(...) or tostring(fmt)
	DEFAULT_CHAT_FRAME:AddMessage("|cff" .. ns.ACCENT .. ns.NAME .. "|r: " .. msg)
end

function ns.Debug(fmt, ...)
	if not (ns.db and ns.db.debug) then return end
	local msg = select("#", ...) > 0 and fmt:format(...) or tostring(fmt)
	DEFAULT_CHAT_FRAME:AddMessage("|cff888888[FSB]|r " .. msg)
end

--------------------------------------------------------------------------------
-- Secret-safe reads. WoW: Forever runs Midnight's addon restrictions: in combat
-- and in some instances aura data is "secret": an addon can't compare or store
-- it, and some aura functions even raise an error when an addon calls them.
-- Everything the addon reads from the game goes through these helpers, and a
-- secret value counts as unknown.
--------------------------------------------------------------------------------

local Safe = {}
ns.Safe = Safe

function Safe.Value(v)
	if issecretvalue and issecretvalue(v) then return nil end
	return v
end

-- calls fn(...) and returns its first result when plain, else nil
function Safe.Call(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, v = pcall(fn, ...)
	if not ok then return nil end
	return Safe.Value(v)
end

local function SafeResults(ok, ...)
	if not ok then return end
	local n = select("#", ...)
	local out = { ... }
	for i = 1, n do out[i] = Safe.Value(out[i]) end
	return unpack(out, 1, n)
end

-- calls fn(...) and returns all its results (each made safe), or nothing on error
function Safe.CallAll(fn, ...)
	if type(fn) ~= "function" then return end
	return SafeResults(pcall(fn, ...))
end

-- a table field read that survives secret tables / values
function Safe.Field(t, key)
	if type(t) ~= "table" then return nil end
	local ok, v = pcall(function() return t[key] end)
	if not ok then return nil end
	return Safe.Value(v)
end

function Safe.InCombat()
	return (Safe.Call(InCombatLockdown) or Safe.Call(UnitAffectingCombat, "player")) and true or false
end

--------------------------------------------------------------------------------
-- Events: any number of handlers per event. Events this client doesn't know
-- are skipped instead of raising an error.
--------------------------------------------------------------------------------

local eventFrame = CreateFrame("Frame")
local handlers = {}

function ns.IsEventValid(event)
	if C_EventUtils and C_EventUtils.IsEventValid then
		return C_EventUtils.IsEventValid(event) and true or false
	end
	return true
end

function ns.On(event, fn)
	if not handlers[event] then
		if not ns.IsEventValid(event) or not pcall(eventFrame.RegisterEvent, eventFrame, event) then
			return false
		end
		handlers[event] = {}
	end
	table.insert(handlers[event], fn)
	return true
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
	for _, fn in ipairs(handlers[event]) do
		local ok, err = pcall(fn, ...)
		if not ok then geterrorhandler()(err) end
	end
end)

-- A unit event for the player only (UNIT_AURA, UNIT_INVENTORY_CHANGED). Registered
-- with RegisterUnitEvent, so the handler never has to look at the unit argument,
-- which can itself be secret while auras are restricted.
local unitFrame = CreateFrame("Frame")
local unitHandlers = {}

function ns.OnPlayer(event, fn)
	if not unitHandlers[event] then
		if not ns.IsEventValid(event) or not pcall(unitFrame.RegisterUnitEvent, unitFrame, event, "player") then
			return false
		end
		unitHandlers[event] = {}
	end
	table.insert(unitHandlers[event], fn)
	return true
end

unitFrame:SetScript("OnEvent", function(_, event)
	for _, fn in ipairs(unitHandlers[event]) do
		local ok, err = pcall(fn)
		if not ok then geterrorhandler()(err) end
	end
end)

-- internal callbacks (ns.Fire("CHANGED") etc.)
local callbacks = {}

function ns.Listen(name, fn)
	callbacks[name] = callbacks[name] or {}
	table.insert(callbacks[name], fn)
end

function ns.Fire(name, ...)
	for _, fn in ipairs(callbacks[name] or {}) do
		local ok, err = pcall(fn, ...)
		if not ok then geterrorhandler()(err) end
	end
end

-- runs fn once, `delay` seconds from now; later calls with the same key while
-- one is pending are dropped (coalesces bursts of UNIT_AURA etc.)
local pending = {}
function ns.Debounce(key, delay, fn)
	if pending[key] then return end
	pending[key] = true
	C_Timer.After(delay, function()
		pending[key] = nil
		local ok, err = pcall(fn)
		if not ok then geterrorhandler()(err) end
	end)
end

--------------------------------------------------------------------------------
-- Saved data
--   ForeverSurvivalBuffsDB = {
--     version, debug,
--     settings = { enabled, locked, hideInCombat, iconSize, minimapHidden, minimapAngle, warnMinutes },
--     position = { point, relPoint, x, y },             -- the reminders
--     windowPosition = { point, relPoint, x, y },       -- the buffs window
--     campIcon,                                         -- the camp buff's icon, once seen
--     classes = { [CLASS] = { [buffKey] = true/false } },  -- the buffs chosen, per class
--     instanceClasses = { ... },                        -- the same, for dungeons and raids
--     warn = { [CLASS] = { [buffKey] = true/false } },  -- warn before it runs out (default: sleeping bag)
--   }
-- A buff missing from `classes` uses its default (on for the survival buffs, off
-- for the class buffs), so new buffs in later versions just show up.
--------------------------------------------------------------------------------

ns.DEFAULTS = {
	enabled = true,
	locked = true,
	hideInCombat = true,
	iconSize = 32,
	warnMinutes = 3,   -- how long before a buff ends its warning shows
}

-- 1.0.x kept the position as loose fields (point, relPoint, x, y) and a `disabled` flag
local function Migrate(db)
	if db.x and db.y and not db.position then
		db.position = { db.point or "CENTER", db.relPoint or db.point or "CENTER", db.x, db.y }
	end
	if db.disabled ~= nil then
		db.settings.enabled = not db.disabled
	end
	db.point, db.relPoint, db.x, db.y, db.disabled = nil, nil, nil, nil, nil
end

local function InitDB()
	local db = ForeverSurvivalBuffsDB
	if type(db) ~= "table" then db = {} end
	db.settings = type(db.settings) == "table" and db.settings or {}
	if (db.version or 1) < 2 then Migrate(db) end
	db.version = DB_VERSION
	for key, value in pairs(ns.DEFAULTS) do
		if db.settings[key] == nil then db.settings[key] = value end
	end
	db.classes = type(db.classes) == "table" and db.classes or {}
	db.instanceClasses = type(db.instanceClasses) == "table" and db.instanceClasses or {}
	db.warn = type(db.warn) == "table" and db.warn or {}
	ForeverSurvivalBuffsDB = db
	ns.db = db
end

ns.On("ADDON_LOADED", function(name)
	if name ~= ADDON then return end
	InitDB()
	ns.Fire("DB_READY")
end)

ns.On("PLAYER_LOGIN", function()
	if not ns.db then InitDB() end
	ns.Fire("LOGIN")
end)
