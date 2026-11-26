--------------------------------------------------------------------------------
-- Reading the player's buffs, without ever touching secret auras.
--
-- 1.0.x called C_UnitAuras.GetAuraDataByIndex on every UNIT_AURA. In combat and
-- in some instances the game makes aura data secret, and that call then raises
-- "Auras cannot be accessed when secret while tainted". Now:
--   * C_Secrets.ShouldAurasBeSecret() is asked first: while auras are secret
--     nothing is read, and the caller keeps what it last knew;
--   * each aura index is checked with C_Secrets.ShouldUnitAuraIndexBeSecret;
--   * every call is protected (pcall) and every value goes through ns.Safe.
--------------------------------------------------------------------------------

local _, ns = ...
local Safe = ns.Safe

local Auras = {}
ns.Auras = Auras

local MAX_AURAS = 255

-- true while the game hides aura data from addons
function Auras.AreSecret()
	local secrets = C_Secrets
	if secrets and secrets.ShouldAurasBeSecret then
		local ok, secret = pcall(secrets.ShouldAurasBeSecret)
		if not ok then return true end
		if issecretvalue and issecretvalue(secret) then return true end
		return secret and true or false
	end
	return false
end

local function IndexIsSecret(index)
	local fn = C_Secrets and C_Secrets.ShouldUnitAuraIndexBeSecret
	if not fn then return false end
	local ok, secret = pcall(fn, "player", index, "HELPFUL")
	if not ok or (issecretvalue and issecretvalue(secret)) then return true end
	return secret and true or false
end

-- the aura at `index`: name, spellID, icon, expirationTime (each nil when unknown;
-- expirationTime 0 = no end); `false` past the last one
local function ReadIndex(index)
	if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
		local ok, aura = pcall(C_UnitAuras.GetAuraDataByIndex, "player", index, "HELPFUL")
		if not ok then return nil end
		if aura == nil then return false end
		return Safe.Field(aura, "name"), Safe.Field(aura, "spellId"), Safe.Field(aura, "icon"),
			Safe.Field(aura, "expirationTime")
	end
	if UnitAura then
		local ok, name, icon, _, _, _, expires, _, _, _, spellID = pcall(UnitAura, "player", index, "HELPFUL")
		if not ok then return nil end
		if name == nil then return false end
		return Safe.Value(name), Safe.Value(spellID), Safe.Value(icon), Safe.Value(expires)
	end
	return false
end

-- Everything on the player right now:
--   { list = { {name, spellID, icon, expires}, ... }, byName = { [name] = aura }, byID = { [id] = aura } }
-- (expires: GetTime() when it ends; nil when it doesn't end or can't be read)
-- or nil while auras are secret (the caller keeps its last answer).
function Auras.Snapshot()
	if Auras.AreSecret() then return nil end
	local snap = { list = {}, byName = {}, byNorm = {}, byID = {} }
	for index = 1, MAX_AURAS do
		if not IndexIsSecret(index) then
			local name, spellID, icon, expires = ReadIndex(index)
			if name == false then break end
			if name or spellID then
				if type(expires) ~= "number" or expires <= 0 then expires = nil end
				local aura = { name = name, spellID = spellID, icon = icon, expires = expires }
				table.insert(snap.list, aura)
				if name then
					snap.byName[name] = aura
					snap.byNorm[Auras.Normalize(name)] = aura
				end
				if spellID then snap.byID[spellID] = aura end
			end
		end
	end
	return snap
end

--------------------------------------------------------------------------------
-- Matching names in any language: lower case, accents off ("Benefícios" and
-- "beneficios" are the same), so the keyword lists can be plain ASCII.
--------------------------------------------------------------------------------

local ACCENTS = {
	["á"] = "a", ["à"] = "a", ["â"] = "a", ["ã"] = "a", ["ä"] = "a",
	["Á"] = "a", ["À"] = "a", ["Â"] = "a", ["Ã"] = "a", ["Ä"] = "a",
	["é"] = "e", ["è"] = "e", ["ê"] = "e", ["ë"] = "e",
	["É"] = "e", ["È"] = "e", ["Ê"] = "e", ["Ë"] = "e",
	["í"] = "i", ["ì"] = "i", ["î"] = "i", ["ï"] = "i",
	["Í"] = "i", ["Ì"] = "i", ["Î"] = "i", ["Ï"] = "i",
	["ó"] = "o", ["ò"] = "o", ["ô"] = "o", ["õ"] = "o", ["ö"] = "o",
	["Ó"] = "o", ["Ò"] = "o", ["Ô"] = "o", ["Õ"] = "o", ["Ö"] = "o",
	["ú"] = "u", ["ù"] = "u", ["û"] = "u", ["ü"] = "u",
	["Ú"] = "u", ["Ù"] = "u", ["Û"] = "u", ["Ü"] = "u",
	["ç"] = "c", ["Ç"] = "c", ["ñ"] = "n", ["Ñ"] = "n",
}

function Auras.Normalize(text)
	if type(text) ~= "string" then return "" end
	-- every accented letter above is two bytes in UTF-8: a lead byte 0xC3 and one more
	text = text:gsub("\195[\128-\191]", function(ch) return ACCENTS[ch] or ch end)
	return (text:lower():gsub("%-", " "))
end

-- does any aura's name contain one of the keywords (already normalized)?
-- `except` (optional): normalized substrings that rule an aura out
function Auras.FindKeyword(snap, keywords, except)
	for _, aura in ipairs(snap.list) do
		local name = aura.name and Auras.Normalize(aura.name)
		if name then
			local excluded = false
			for _, bad in ipairs(except or {}) do
				if name:find(bad, 1, true) then excluded = true break end
			end
			if not excluded then
				for _, keyword in ipairs(keywords) do
					if name:find(keyword, 1, true) then return aura end
				end
			end
		end
	end
	return nil
end

--------------------------------------------------------------------------------
-- Temporary weapon enhancements (sharpening stones, oils, poisons, imbues):
-- they aren't auras, the game keeps them on the item.
--------------------------------------------------------------------------------

local WEAPON_CLASS = (Enum and Enum.ItemClass and Enum.ItemClass.Weapon) or 2

-- true / false, or nil when there's no weapon in that slot (nothing to remind)
function Auras.WeaponEnhanced(slot)
	local itemID = Safe.Call(GetInventoryItemID, "player", slot)
	if not itemID then return nil end
	local getInstant = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
	local classID = select(6, Safe.CallAll(getInstant, itemID))
	if classID and classID ~= WEAPON_CLASS then return nil end   -- a shield or an off-hand item

	if C_PaperDollInfo and C_PaperDollInfo.GetTemporaryEnchantmentInfo then
		local ok, info = pcall(C_PaperDollInfo.GetTemporaryEnchantmentInfo, slot)
		if ok and not (issecretvalue and issecretvalue(info)) then return info ~= nil end
	end
	if GetWeaponEnchantInfo then
		local hasMain, _, _, _, hasOff = Safe.CallAll(GetWeaponEnchantInfo)
		if slot == 17 then return hasOff and true or false end
		return hasMain and true or false
	end
	return nil
end
