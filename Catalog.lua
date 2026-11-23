--------------------------------------------------------------------------------
-- The buffs the addon can remind you of: the survival buffs (on by default) and,
-- per class, the self-buffs and shields that stay on the character, plus the
-- temporary weapon enhancements (sharpening stones, oils, poisons, imbues).
-- Only these can be chosen; nothing here is on unless the player ticks it.
--
-- Spell entries list rank 1 of each spell. The game gives every rank the same
-- name, so an aura counts when its name matches (in any language) or its ID does.
--   spells: the player's own spells; the buff can be chosen once one is learned
--   also:   other spells whose aura counts too (the group versions, for example)
--------------------------------------------------------------------------------

local _, ns = ...
local L, Safe = ns.L, ns.Safe

local Catalog = {}
ns.Catalog = Catalog

Catalog.WELL_FED_SPELL = 19705
Catalog.CAMP_SPELL = 1229741
Catalog.SLEEP_SPELLS = { 429957, 429958, 429959 }
Catalog.SLEEP_BAG_ITEM = 211527

Catalog.SURVIVAL = {
	{ key = "food", kind = "food" },
	{ key = "camp", kind = "camp" },
	{ key = "sleep", kind = "sleep" },
}

-- what each class puts on its weapons, for the label and the icon
local WEAPON_STUFF = {
	stone = { label = "Sharpening stone or weightstone", item = 2862 },     -- Rough Sharpening Stone
	poison = { label = "Poison", item = 6947 },                             -- Instant Poison
	imbue = { label = "Weapon imbue or stone", spell = 8017 },              -- Rockbiter Weapon
	oil = { label = "Wizard oil or mana oil", item = 20744 },               -- Minor Wizard Oil
}

local MAIN_HAND, OFF_HAND = 16, 17

local function Weapons(stuff, dualWield)
	local list = { { key = "weaponMain", kind = "weapon", slot = MAIN_HAND, stuff = stuff } }
	if dualWield then
		table.insert(list, { key = "weaponOff", kind = "weapon", slot = OFF_HAND, stuff = stuff })
	end
	return list
end

local CLASS = {
	MAGE = {
		{ key = "arcaneIntellect", spells = { 1459 }, also = { 23028 } },   -- Arcane Brilliance
		{ key = "frostArmor", spells = { 168, 7302 } },                     -- Frost Armor, Ice Armor
		{ key = "mageArmor", spells = { 6117 } },
		{ key = "iceBarrier", spells = { 11426 } },
		{ key = "manaShield", spells = { 1463 } },
		{ key = "dampenMagic", spells = { 604 } },
		{ key = "amplifyMagic", spells = { 1008 } },
		{ key = "fireWard", spells = { 543 } },
		{ key = "frostWard", spells = { 6143 } },
	},
	PRIEST = {
		{ key = "fortitude", spells = { 1243 }, also = { 21562 } },         -- Prayer of Fortitude
		{ key = "innerFire", spells = { 588 } },
		{ key = "divineSpirit", spells = { 14752 }, also = { 27681 } },     -- Prayer of Spirit
		{ key = "shadowProtection", spells = { 976 }, also = { 27683 } },   -- Prayer of Shadow Protection
		{ key = "shield", spells = { 17 } },                                -- Power Word: Shield
		{ key = "fearWard", spells = { 6346 } },
		{ key = "shadowform", spells = { 15473 } },
		{ key = "touchOfWeakness", spells = { 2652 } },
		{ key = "shadowguard", spells = { 18137 } },
	},
	DRUID = {
		{ key = "markOfTheWild", spells = { 1126 }, also = { 21849 } },     -- Gift of the Wild
		{ key = "thorns", spells = { 467 } },
		{ key = "omenOfClarity", spells = { 16864 } },
	},
	PALADIN = {
		{ key = "righteousFury", spells = { 25780 } },
		{ key = "blessingMight", spells = { 19740 }, also = { 25782 } },    -- and the Greater blessings
		{ key = "blessingWisdom", spells = { 19742 }, also = { 25894 } },
		{ key = "blessingKings", spells = { 20217 }, also = { 25898 } },
		{ key = "blessingSalvation", spells = { 1038 }, also = { 25895 } },
		{ key = "blessingLight", spells = { 19977 }, also = { 25890 } },
		{ key = "blessingSanctuary", spells = { 20911 }, also = { 25899 } },
		{ key = "devotionAura", spells = { 465 } },
		{ key = "retributionAura", spells = { 7294 } },
		{ key = "concentrationAura", spells = { 19746 } },
		{ key = "sanctityAura", spells = { 20218 } },
		{ key = "shadowResistanceAura", spells = { 19876 } },
		{ key = "frostResistanceAura", spells = { 19888 } },
		{ key = "fireResistanceAura", spells = { 19891 } },
	},
	HUNTER = {
		{ key = "trueshotAura", spells = { 19506 } },
		{ key = "aspectHawk", spells = { 13165 } },
		{ key = "aspectMonkey", spells = { 13163 } },
		{ key = "aspectCheetah", spells = { 5118 } },
		{ key = "aspectPack", spells = { 13159 } },
		{ key = "aspectWild", spells = { 20043 } },
		{ key = "aspectBeast", spells = { 13161 } },
	},
	WARLOCK = {
		{ key = "demonArmor", spells = { 687, 706 } },                      -- Demon Skin, Demon Armor
		{ key = "shadowWard", spells = { 6229 } },
		{ key = "soulLink", spells = { 19028 } },
	},
	WARRIOR = {
		{ key = "battleShout", spells = { 6673 } },
	},
	SHAMAN = {
		{ key = "lightningShield", spells = { 324 } },
	},
	ROGUE = {},
}

local WEAPONS = {
	WARRIOR = Weapons("stone", true),
	ROGUE = Weapons("poison", true),
	HUNTER = Weapons("stone", true),
	SHAMAN = Weapons("imbue", true),
	PALADIN = Weapons("stone"),
	DRUID = Weapons("oil"),
	MAGE = Weapons("oil"),
	PRIEST = Weapons("oil"),
	WARLOCK = Weapons("oil"),
}

for class, list in pairs(CLASS) do
	for _, entry in ipairs(list) do entry.kind = "spell" end
	for _, entry in ipairs(WEAPONS[class] or {}) do table.insert(list, entry) end
end

function Catalog.PlayerClass()
	local _, class = Safe.CallAll(UnitClass, "player")
	return class
end

-- the class's choices, without the spells this client doesn't have at all
function Catalog.ClassList(class)
	local out = {}
	for _, entry in ipairs(CLASS[class] or {}) do
		if entry.kind ~= "spell" or Catalog.SpellName(entry.spells[1]) then
			table.insert(out, entry)
		end
	end
	return out
end

-- every entry for this character: survival first, then the class
function Catalog.All(class)
	local out = {}
	for _, entry in ipairs(Catalog.SURVIVAL) do table.insert(out, entry) end
	for _, entry in ipairs(Catalog.ClassList(class)) do table.insert(out, entry) end
	return out
end

function Catalog.IsDefault(entry)
	return entry.kind == "food" or entry.kind == "camp" or entry.kind == "sleep"
end

--------------------------------------------------------------------------------
-- Names and icons, from the game (already translated)
--------------------------------------------------------------------------------

function Catalog.SpellName(id)
	if C_Spell and C_Spell.GetSpellName then return Safe.Call(C_Spell.GetSpellName, id) end
	return Safe.Call(GetSpellInfo, id)
end

function Catalog.SpellIcon(id)
	if C_Spell and C_Spell.GetSpellTexture then return Safe.Call(C_Spell.GetSpellTexture, id) end
	return (Safe.CallAll(GetSpellTexture, id))
end

local function ItemIcon(id)
	if C_Item and C_Item.GetItemIconByID then return Safe.Call(C_Item.GetItemIconByID, id) end
	return Safe.Call(GetItemIcon, id)
end

local function SlotText(slot)
	return slot == OFF_HAND and L["off hand"] or L["main hand"]
end

function Catalog.Name(entry)
	if entry.kind == "food" then return Catalog.SpellName(Catalog.WELL_FED_SPELL) or L["Well Fed"] end
	if entry.kind == "camp" then return L["Camp buff"] end
	if entry.kind == "sleep" then return L["Sleeping bag (Well Rested)"] end
	if entry.kind == "weapon" then
		return ("%s (%s)"):format(L[WEAPON_STUFF[entry.stuff].label], SlotText(entry.slot))
	end
	local names, seen = {}, {}
	for _, id in ipairs(entry.spells) do
		local name = Catalog.SpellName(id)
		if name and not seen[name] then
			seen[name] = true
			table.insert(names, name)
		end
	end
	return #names > 0 and table.concat(names, " / ") or ("spell " .. entry.spells[1])
end

-- the icon to show; for spells with several names, the highest one learned
function Catalog.Icon(entry)
	if entry.kind == "food" then return "Interface\\Icons\\spell_misc_food" end
	if entry.kind == "camp" then
		return (ns.db and ns.db.campIcon) or Catalog.SpellIcon(Catalog.CAMP_SPELL) or "Interface\\Icons\\Spell_Fire_Fire"
	end
	if entry.kind == "sleep" then
		return Catalog.SpellIcon(Catalog.SLEEP_SPELLS[3]) or ItemIcon(Catalog.SLEEP_BAG_ITEM) or "Interface\\Icons\\INV_Misc_Bag_08"
	end
	if entry.kind == "weapon" then
		local stuff = WEAPON_STUFF[entry.stuff]
		return (stuff.item and ItemIcon(stuff.item)) or (stuff.spell and Catalog.SpellIcon(stuff.spell))
			or "Interface\\Icons\\INV_Stone_SharpeningStone_01"
	end
	for i = #entry.spells, 1, -1 do
		if ns.Tracker and ns.Tracker.KnowsSpell(entry.spells[i]) then return Catalog.SpellIcon(entry.spells[i]) end
	end
	return Catalog.SpellIcon(entry.spells[1]) or "Interface\\Icons\\INV_Misc_QuestionMark"
end

-- what to do about it, for the reminder's tooltip
function Catalog.Hint(entry)
	if entry.kind == "food" then return L["Eat food that makes you Well Fed."] end
	if entry.kind == "camp" then return L["Rest at a campfire until you get the one-hour camp buff."] end
	if entry.kind == "sleep" then return L["Use your Cozy Sleeping Bag for extra experience."] end
	if entry.kind == "weapon" then return L["Put a temporary enhancement on this weapon."] end
	return L["Cast it on yourself."]
end
