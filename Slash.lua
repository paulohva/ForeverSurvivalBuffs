--------------------------------------------------------------------------------
-- Slash commands: /fsb
--------------------------------------------------------------------------------

local _, ns = ...
local L, Safe, Auras, Catalog, Tracker = ns.L, ns.Safe, ns.Auras, ns.Catalog, ns.Tracker

local function Line(fmt, ...)
	local msg = select("#", ...) > 0 and fmt:format(...) or tostring(fmt)
	DEFAULT_CHAT_FRAME:AddMessage("  " .. msg)
end

--------------------------------------------------------------------------------
-- /fsb diag (English on purpose: it goes into bug reports)
--------------------------------------------------------------------------------

local function Diag()
	ns.Print("diag")
	Line("client: %s", tostring((Safe.CallAll(GetBuildInfo))))
	Line("class: %s, level %s", tostring(Catalog.PlayerClass()), tostring(Safe.Call(UnitLevel, "player")))
	Line("C_Secrets: %s, auras secret now: %s", C_Secrets and "present" or "missing", tostring(Auras.AreSecret()))
	Line("in combat: %s", tostring(Safe.InCombat()))
	Line("instance: %s, list in use: %s", tostring((select(2, Safe.CallAll(IsInInstance)))), Tracker.Profile())

	local snap = Auras.Snapshot()
	if not snap then
		Line("buffs: secret right now, try again out of combat")
	else
		Line("buffs: %d", #snap.list)
		for i, aura in ipairs(snap.list) do
			Line("  %d. %s (spell %s)", i, tostring(aura.name), tostring(aura.spellID))
		end
	end

	Line("main hand enhanced: %s, off hand: %s", tostring(Auras.WeaponEnhanced(16)), tostring(Auras.WeaponEnhanced(17)))
	Tracker.Update()
	Line("tracked (%s):", Tracker.secret and "last seen" or "now")
	for _, entry in ipairs(Tracker.entries) do
		local status, reason = Tracker.Status(entry)
		local left = Tracker.TimeLeft(entry)
		Line("  [%s] %s: %s%s%s", Tracker.IsChosen(entry) and "x" or " ", Catalog.Name(entry), status,
			reason and (" (" .. reason .. ")") or "",
			left and (" (%ds left%s)"):format(left, Tracker.IsEnding(entry) and ", ending" or "") or "")
	end
end

--------------------------------------------------------------------------------
-- Commands
--------------------------------------------------------------------------------

local function Help()
	ns.Print(L["Commands:"])
	Line("/fsb - " .. L["open the window to choose your buffs"])
	Line("/fsb on | off - " .. L["turn the reminders on or off"])
	Line("/fsb unlock | lock - " .. L["move the reminders, then lock them in place"])
	Line("/fsb reset - " .. L["put the reminders back in their first place"])
	Line("/fsb options - " .. L["open the settings"])
	Line("/fsb minimap - " .. L["show or hide the minimap button"])
	Line("/fsb diag - " .. L["list your buffs and what the addon sees"])
	Line(L["Alt + drag the reminders to move them."])
end

local COMMANDS = {
	[""] = function() ns.BuffWindow.Toggle() end,
	buffs = function() ns.BuffWindow.Toggle() end,
	on = function() ns.SetEnabled(true) end,
	off = function() ns.SetEnabled(false) end,
	toggle = function() ns.SetEnabled(not ns.db.settings.enabled) end,
	unlock = function()
		ns.Reminders.SetLocked(false)
		ns.Print(L["Drag the reminders where you want them, then type /fsb lock."])
	end,
	lock = function()
		ns.Reminders.SetLocked(true)
		ns.Print(L["Reminders locked. Alt + drag still moves them."])
	end,
	reset = function()
		ns.Reminders.ResetPosition()
		ns.Print(L["Reminders back in their first place."])
	end,
	options = function()
		if not ns.Options.Open() then ns.Print(L["This client has no options panel for addons."]) end
	end,
	minimap = function()
		local shown = not ns.db.settings.minimapHidden
		ns.MinimapButton.SetShown(not shown)
	end,
	diag = Diag,
	debug = function()
		ns.db.debug = not ns.db.debug
		ns.Print(ns.db.debug and L["Debug messages on."] or L["Debug messages off."])
	end,
	help = Help,
}
COMMANDS.test = COMMANDS.unlock          -- 1.0.x name
COMMANDS.config = COMMANDS.options
COMMANDS.settings = COMMANDS.options

SLASH_FOREVERSURVIVALBUFFS1 = "/fsb"
SLASH_FOREVERSURVIVALBUFFS2 = "/foreversurvivalbuffs"
SlashCmdList["FOREVERSURVIVALBUFFS"] = function(msg)
	if not ns.db then return end
	local cmd = strtrim(msg or ""):lower()
	local fn = COMMANDS[cmd] or Help
	fn()
end
