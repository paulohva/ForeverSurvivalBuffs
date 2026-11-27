--------------------------------------------------------------------------------
-- Which buffs are chosen, which of them are up, and which are missing.
--
-- Each buff gets a status:
--   "active"       it's on you
--   "missing"      it isn't (a reminder shows if the buff is chosen)
--   "unknown"      auras were secret since login, so it can't be told yet
--   "unavailable"  it can't apply right now (`reason`: notLearned, noWeapon,
--                  noBag, maxLevel)
-- While the game keeps auras secret (combat, some instances) the aura-based
-- statuses stay as they were last seen.
--------------------------------------------------------------------------------

local _, ns = ...
local Safe, Auras, Catalog = ns.Safe, ns.Auras, ns.Catalog

local Tracker = {}
ns.Tracker = Tracker

Tracker.state = {}     -- [key] = { status, reason, expires }
Tracker.entries = {}   -- every buff for this character, in display order
Tracker.missing = {}   -- the chosen buffs that are missing, in display order
Tracker.ending = {}    -- the buffs about to run out with their expiry warning on, in display order
Tracker.secret = false -- the last update couldn't read auras

-- names to look for (lower case, without accents: see Auras.Normalize)
local FOOD_KEYWORDS = { "well fed", "bem alimentado", "alimentado" }
local SLEEP_KEYWORDS = { "well rested", "bem descansado", "sleeping bag", "saco de dormir" }
-- the one-hour camp buff and the buffs of the camp's pieces (the passing aura you get
-- just for standing near a campfire doesn't count: it'd hide the reminder too soon)
local CAMP_KEYWORDS = {
	"camp benefits", "beneficios do acampamento", "beneficio do acampamento",
	"mana well", "poco de mana", "sharpening wheel", "rebolo", "lodestone", "magnetita",
	"incense candle", "vela de incenso", "camp chair", "cadeira de acampamento",
	"camp tent", "tenda de acampamento", "enchanted lute", "alaude encantado",
	"first aid kit", "estojo de primeiros socorros", "fish bowl", "aquario",
}
local CAMP_EXCEPT = { "campfire", "fogueira" }

--------------------------------------------------------------------------------
-- Chosen buffs, per class and per profile:
--   "world"     the usual list (ns.db.classes)
--   "instance"  dungeons and raids (ns.db.instanceClasses). Until it's first
--               changed it is the world list; then it starts as a copy of it
--               and goes its own way.
--------------------------------------------------------------------------------

local INSTANCE_TYPES = { party = true, raid = true }

function Tracker.InInstance()
	local inside, kind = Safe.CallAll(IsInInstance)
	return (inside and kind and INSTANCE_TYPES[kind]) and true or false
end

-- the profile in use right now
function Tracker.Profile()
	if Tracker.InInstance() then return "instance" end
	return "world"
end

local function WorldChosen(choices, entry)
	local value = choices and choices[entry.key]
	if value == nil then return Catalog.IsDefault(entry) end
	return value and true or false
end

local function ClassChoices(profile, create)
	local class = Catalog.PlayerClass()
	if not (class and ns.db) then return nil end
	local store = profile == "instance" and ns.db.instanceClasses or ns.db.classes
	local choices = store[class]
	if not choices and create then
		choices = {}
		if profile == "instance" then
			-- start from the world list as it is now
			local world = ns.db.classes[class]
			for _, entry in ipairs(Catalog.All(class)) do choices[entry.key] = WorldChosen(world, entry) end
		end
		store[class] = choices
	end
	return choices
end

-- profile: "world" or "instance" (default: the one in use)
function Tracker.IsChosen(entry, profile)
	profile = profile or Tracker.Profile()
	if profile == "instance" then
		local choices = ClassChoices("instance", false)
		local value = choices and choices[entry.key]
		if value ~= nil then return value and true or false end
	end
	return WorldChosen(ClassChoices("world", false), entry)
end

function Tracker.SetChosen(entry, chosen, profile)
	local choices = ClassChoices(profile or Tracker.Profile(), true)
	if not choices then return end
	choices[entry.key] = chosen and true or false
	Tracker.Update()
end

--------------------------------------------------------------------------------
-- What the character has
--------------------------------------------------------------------------------

function Tracker.KnowsSpell(id)
	if C_SpellBook and C_SpellBook.IsSpellKnown then
		if Safe.Call(C_SpellBook.IsSpellKnown, id) then return true end
	end
	if IsPlayerSpell and Safe.Call(IsPlayerSpell, id) then return true end
	if IsSpellKnown and Safe.Call(IsSpellKnown, id) then return true end
	return false
end

local function KnowsAny(entry)
	for _, id in ipairs(entry.spells) do
		if Tracker.KnowsSpell(id) then return true end
	end
	return false
end

local function OwnsSleepingBag()
	local id = Catalog.SLEEP_BAG_ITEM
	if C_ToyBox and C_ToyBox.PlayerHasToy and Safe.Call(C_ToyBox.PlayerHasToy, id) then return true end
	if PlayerHasToy and Safe.Call(PlayerHasToy, id) then return true end
	local count = (C_Item and C_Item.GetItemCount and Safe.Call(C_Item.GetItemCount, id))
		or (GetItemCount and Safe.Call(GetItemCount, id))
	return (count or 0) > 0
end

-- the sleeping bag only gives experience
local function AtMaxLevel()
	local level = Safe.Call(UnitLevel, "player")
	local max = (GetMaxLevelForPlayerExpansion and Safe.Call(GetMaxLevelForPlayerExpansion))
		or (GetMaxPlayerLevel and Safe.Call(GetMaxPlayerLevel))
	return level and max and level >= max or false
end

--------------------------------------------------------------------------------
-- Is it on?
--------------------------------------------------------------------------------

-- each of these returns the buff's aura, or nil

local function SpellAura(snap, entry)
	for _, list in ipairs({ entry.spells, entry.also or {}, entry.ranks or {} }) do
		for _, id in ipairs(list) do
			if snap.byID[id] then return snap.byID[id] end
			local name = Catalog.SpellName(id)
			local aura = name and snap.byNorm[Auras.Normalize(name)]
			if aura then return aura end
		end
	end
	return nil
end

local function FoodAura(snap)
	if snap.byID[Catalog.WELL_FED_SPELL] then return snap.byID[Catalog.WELL_FED_SPELL] end
	local name = Catalog.SpellName(Catalog.WELL_FED_SPELL)
	if name and snap.byName[name] then return snap.byName[name] end
	return Auras.FindKeyword(snap, FOOD_KEYWORDS)
end

local function CampAura(snap)
	local aura = snap.byID[Catalog.CAMP_SPELL]
	if aura then
		-- remember the server's own icon for the reminder
		if aura.icon and ns.db then ns.db.campIcon = aura.icon end
		return aura
	end
	return Auras.FindKeyword(snap, CAMP_KEYWORDS, CAMP_EXCEPT)
end

-- the Well Rested aura, or nil
local function SleepAura(snap)
	for _, id in ipairs(Catalog.SLEEP_SPELLS) do
		if snap.byID[id] then return snap.byID[id] end
	end
	return Auras.FindKeyword(snap, SLEEP_KEYWORDS)
end

local function Now() return Safe.Call(GetTime) or 0 end

-- status, reason, expires
local function LastSeen(entry)
	local last = Tracker.state[entry.key]
	if last and last.status == "active" then
		-- a buff known to have run out since then is missing
		if last.expires and last.expires <= Now() then return "missing" end
		return "active", nil, last.expires
	end
	if last and last.status == "missing" then return "missing" end
	return "unknown"
end

local function Evaluate(entry, snap)
	local kind = entry.kind
	if kind == "sleep" then
		if not OwnsSleepingBag() then return "unavailable", "noBag" end
		if AtMaxLevel() then return "unavailable", "maxLevel" end
	elseif kind == "spell" then
		if not KnowsAny(entry) then return "unavailable", "notLearned" end
	end

	-- while the game hides auras, keep what was last seen (weapons too, to be safe)
	if not snap then
		if kind == "weapon" and Auras.WeaponEnhanced(entry.slot) == nil then return "unavailable", "noWeapon" end
		return LastSeen(entry)
	end

	if kind == "weapon" then
		local enhanced, left = Auras.WeaponEnhanced(entry.slot)
		if enhanced == nil then return "unavailable", "noWeapon" end
		if not enhanced then return "missing" end
		return "active", nil, left and (Now() + left) or nil
	end

	local aura
	if kind == "sleep" then aura = SleepAura(snap)
	elseif kind == "food" then aura = FoodAura(snap)
	elseif kind == "camp" then aura = CampAura(snap)
	else aura = SpellAura(snap, entry) end
	if not aura then return "missing" end
	return "active", nil, aura.expires
end

-- seconds left on an active buff that ends, or nil
function Tracker.TimeLeft(entry)
	local s = Tracker.state[entry.key]
	if not (s and s.status == "active" and s.expires) then return nil end
	return math.max(0, s.expires - Now())
end

--------------------------------------------------------------------------------
-- Warnings before a buff runs out: per class, for any buff (only the sleeping bag
-- by default), all at the same time before the end (settings.warnMinutes).
--------------------------------------------------------------------------------

function Tracker.WarnSeconds()
	local minutes = ns.db and ns.db.settings.warnMinutes or ns.DEFAULTS.warnMinutes
	return minutes * 60
end

local function WarnChoices(create)
	local class = Catalog.PlayerClass()
	if not (class and ns.db) then return nil end
	local choices = ns.db.warn[class]
	if not choices and create then
		choices = {}
		ns.db.warn[class] = choices
	end
	return choices
end

function Tracker.WarnOn(entry)
	local choices = WarnChoices(false)
	local value = choices and choices[entry.key]
	if value == nil then return entry.kind == "sleep" end
	return value and true or false
end

function Tracker.SetWarn(entry, on)
	local choices = WarnChoices(true)
	if not choices then return end
	choices[entry.key] = on and true or false
	Tracker.Update()
end

-- every buff of this character at once (the window's "all" check box)
function Tracker.SetWarnAll(on)
	local choices = WarnChoices(true)
	if not choices then return end
	for _, entry in ipairs(Tracker.entries) do choices[entry.key] = on and true or false end
	Tracker.Update()
end

-- back to the defaults for this character's class: both lists and the expiry
-- warnings (the survival buffs reminded, the sleeping bag warned, nothing else)
function Tracker.ResetChoices()
	local class = Catalog.PlayerClass()
	if not (class and ns.db) then return end
	ns.db.classes[class] = nil
	ns.db.instanceClasses[class] = nil
	ns.db.warn[class] = nil
	Tracker.Update()
end

function Tracker.AllWarn()
	for _, entry in ipairs(Tracker.entries) do
		if not Tracker.WarnOn(entry) then return false end
	end
	return #Tracker.entries > 0
end

-- an active buff with its warning on that ends within the warning time
function Tracker.IsEnding(entry)
	if not Tracker.WarnOn(entry) then return false end
	local left = Tracker.TimeLeft(entry)
	return left ~= nil and left <= Tracker.WarnSeconds()
end

-- look again exactly when a buff's warning starts (no game event says so)
local warnTimers = {}
local function ScheduleWarning(entry, expires)
	if not (expires and Tracker.WarnOn(entry)) then return end
	local at = expires - Tracker.WarnSeconds()
	-- weapon end times are worked out again on each look, a few milliseconds apart
	local scheduled = warnTimers[entry.key]
	if scheduled and math.abs(scheduled - at) < 2 then return end
	local delay = at - Now()
	if delay <= 0 then return end
	warnTimers[entry.key] = at
	C_Timer.After(delay + 0.1, function() Tracker.Update() end)
end

function Tracker.Update()
	if not ns.db then return end
	local snap = Auras.Snapshot()
	Tracker.secret = snap == nil

	local entries = Catalog.All(Catalog.PlayerClass())
	local state, missing, ending = {}, {}, {}
	for _, entry in ipairs(entries) do
		local status, reason, expires = Evaluate(entry, snap)
		state[entry.key] = { status = status, reason = reason, expires = expires }
		if status == "active" then ScheduleWarning(entry, expires) end
	end
	Tracker.state = state
	Tracker.entries = entries
	-- the reminder (missing) and the expiry warning (ending) are chosen apart
	for _, entry in ipairs(entries) do
		if state[entry.key].status == "missing" then
			if Tracker.IsChosen(entry) then table.insert(missing, entry) end
		elseif Tracker.IsEnding(entry) then
			table.insert(ending, entry)
		end
	end
	Tracker.missing = missing
	Tracker.ending = ending
	ns.Fire("UPDATED")
end

function Tracker.Status(entry)
	local s = Tracker.state[entry.key]
	if not s then return "unknown" end
	return s.status, s.reason
end

--------------------------------------------------------------------------------
-- When to look again
--------------------------------------------------------------------------------

local function Soon() ns.Debounce("update", 0.2, Tracker.Update) end

ns.OnPlayer("UNIT_AURA", Soon)
ns.OnPlayer("UNIT_INVENTORY_CHANGED", Soon)   -- also when a weapon enhancement starts or ends
for _, event in ipairs({
	"PLAYER_ENTERING_WORLD", "PLAYER_EQUIPMENT_CHANGED", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED",
	"PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST", "BAG_UPDATE_DELAYED", "SPELLS_CHANGED",
	"PLAYER_LEVEL_UP", "TOYS_UPDATED", "ZONE_CHANGED_NEW_AREA",
}) do
	ns.On(event, Soon)
end

ns.Listen("LOGIN", function()
	Tracker.Update()
	-- weapon enhancements can run out without any event; a slow check covers that
	C_Timer.NewTicker(10, Soon)
end)
