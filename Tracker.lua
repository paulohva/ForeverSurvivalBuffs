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

Tracker.state = {}     -- [key] = { status, reason }
Tracker.entries = {}   -- every buff for this character, in display order
Tracker.missing = {}   -- the chosen buffs that are missing, in display order
Tracker.ending = {}    -- the chosen buffs about to run out (entry.warn), in display order
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

local function HasSpellAura(snap, entry)
	for _, list in ipairs({ entry.spells, entry.also or {}, entry.ranks or {} }) do
		for _, id in ipairs(list) do
			if snap.byID[id] then return true end
			local name = Catalog.SpellName(id)
			if name and snap.byNorm[Auras.Normalize(name)] then return true end
		end
	end
	return false
end

local function HasFood(snap)
	if snap.byID[Catalog.WELL_FED_SPELL] then return true end
	local name = Catalog.SpellName(Catalog.WELL_FED_SPELL)
	if name and snap.byName[name] then return true end
	return Auras.FindKeyword(snap, FOOD_KEYWORDS) ~= nil
end

local function HasCamp(snap)
	local aura = snap.byID[Catalog.CAMP_SPELL]
	if aura then
		-- remember the server's own icon for the reminder
		if aura.icon and ns.db then ns.db.campIcon = aura.icon end
		return true
	end
	return Auras.FindKeyword(snap, CAMP_KEYWORDS, CAMP_EXCEPT) ~= nil
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
		local enhanced = Auras.WeaponEnhanced(entry.slot)
		if enhanced == nil then return "unavailable", "noWeapon" end
		return enhanced and "active" or "missing"
	end

	if kind == "sleep" then
		local aura = SleepAura(snap)
		if not aura then return "missing" end
		return "active", nil, aura.expires
	end

	local has
	if kind == "food" then has = HasFood(snap)
	elseif kind == "camp" then has = HasCamp(snap)
	else has = HasSpellAura(snap, entry) end
	return has and "active" or "missing"
end

-- seconds left on an active buff that ends, or nil
function Tracker.TimeLeft(entry)
	local s = Tracker.state[entry.key]
	if not (s and s.status == "active" and s.expires) then return nil end
	return math.max(0, s.expires - Now())
end

-- an active buff with a warning (entry.warn) that ends within that many seconds
function Tracker.IsEnding(entry)
	local left = entry.warn and Tracker.TimeLeft(entry)
	return left ~= nil and left <= entry.warn
end

-- look again exactly when a buff's warning starts (no game event says so)
local warnTimers = {}
local function ScheduleWarning(entry, expires)
	if not (entry.warn and expires) or warnTimers[entry.key] == expires then return end
	local delay = expires - entry.warn - Now()
	if delay <= 0 then return end
	warnTimers[entry.key] = expires
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
	for _, entry in ipairs(entries) do
		if Tracker.IsChosen(entry) then
			local status = state[entry.key].status
			if status == "missing" then table.insert(missing, entry)
			elseif Tracker.IsEnding(entry) then table.insert(ending, entry) end
		end
	end
	Tracker.missing = missing
	Tracker.ending = ending   -- chosen buffs that are about to run out
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
