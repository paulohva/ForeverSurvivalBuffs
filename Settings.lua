--------------------------------------------------------------------------------
-- Settings: a panel in Options > AddOns > ForeverSurvivalBuffs, and the switches
-- shared with the minimap menu and the slash commands.
--------------------------------------------------------------------------------

local _, ns = ...
local Safe, L = ns.Safe, ns.L

local Options = {}
ns.Options = Options

local category

-- turns the reminders on or off; quiet: no chat line (from the panel's own check box)
function ns.SetEnabled(on, quiet)
	ns.db.settings.enabled = on and true or false
	ns.Reminders.Refresh()
	if Settings and Settings.NotifyUpdate then pcall(Settings.NotifyUpdate, "ForeverSurvivalBuffs_enabled") end
	if not quiet then
		ns.Print(on and L["Reminders on."] or L["Reminders off."])
	end
end

--------------------------------------------------------------------------------
-- The panel. Nothing here adds search tags or Blizzard key binding rows: built
-- from addon code they taint the Options search (a lesson from Old Friends List).
--------------------------------------------------------------------------------

local function VarType(kind)
	local t = Settings.VarType
	if t then
		if kind == "boolean" then return t.Boolean end
		if kind == "string" then return t.String end
		return t.Number
	end
	return kind
end

local function AddHeader(layout, text)
	if CreateSettingsListSectionHeaderInitializer then
		layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(text))
	end
end

local function AddProxyCheckbox(key, name, tooltip, default, get, set)
	local setting = Settings.RegisterProxySetting(category, "ForeverSurvivalBuffs_" .. key, VarType("boolean"),
		name, default, get, set)
	Settings.CreateCheckbox(category, setting, tooltip)
end

local function AddIconSizeSlider()
	local setting = Settings.RegisterAddOnSetting(category, "ForeverSurvivalBuffs_iconSize", "iconSize",
		ns.db.settings, VarType("number"), L["Icon size"], ns.DEFAULTS.iconSize)
	local options = Settings.CreateSliderOptions(20, 64, 2)
	if MinimalSliderWithSteppersMixin and MinimalSliderWithSteppersMixin.Label then
		options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, function(v) return ("%d"):format(v) end)
	end
	Settings.CreateSlider(category, setting, options, L["The size of the reminder icons."])
	if setting.SetValueChangedCallback then
		setting:SetValueChangedCallback(function() ns.Reminders.Refresh() end)
	elseif Settings.SetOnValueChangedCallback then
		Settings.SetOnValueChangedCallback("ForeverSurvivalBuffs_iconSize", function() ns.Reminders.Refresh() end)
	end
end

local function AddButton(layout, name, buttonText, onClick, tooltip)
	if not CreateSettingsButtonInitializer then return end
	layout:AddInitializer(CreateSettingsButtonInitializer(name, buttonText, onClick, tooltip, false))
end

local function Build()
	if not (Settings and Settings.RegisterVerticalLayoutCategory and Settings.RegisterAddOnCategory) then
		ns.Debug("no Settings API: options panel unavailable")
		return
	end
	local layout
	category, layout = Settings.RegisterVerticalLayoutCategory(ns.NAME)
	local s = ns.db.settings

	-- each piece on its own, so one API difference doesn't take the whole panel down
	local function Try(fn, ...)
		local ok, err = pcall(fn, ...)
		if not ok then ns.Debug("settings: %s", tostring(err)) end
	end

	Try(AddHeader, layout, L["Buffs"])
	Try(AddButton, layout, L["Buffs to remind"], L["Choose..."], function() ns.BuffWindow.Toggle() end,
		L["Tick the survival buffs, class buffs and weapon enhancements you want to be reminded of."])

	Try(AddHeader, layout, L["Reminders"])
	Try(AddProxyCheckbox, "enabled", L["Show reminders"],
		L["Show an icon for each chosen buff you're missing."], true,
		function() return s.enabled end, function(value) ns.SetEnabled(value, true) end)
	Try(AddProxyCheckbox, "hideInCombat", L["Hide in combat"],
		L["Hide the reminders during a fight. In combat the game doesn't let addons see your buffs anyway."], true,
		function() return s.hideInCombat end,
		function(value)
			s.hideInCombat = value and true or false
			ns.Reminders.Refresh()
		end)
	Try(AddProxyCheckbox, "locked", L["Lock position"],
		L["Untick to show every chosen buff and drag the row where you want it. Alt + drag always works."], true,
		function() return s.locked end, function(value) ns.Reminders.SetLocked(value) end)
	Try(AddIconSizeSlider)
	Try(AddButton, layout, L["Position"], L["Reset"], function() ns.Reminders.ResetPosition() end,
		L["Put the reminders back in their first place, below the middle of the screen."])

	Try(AddHeader, layout, L["Minimap"])
	Try(AddProxyCheckbox, "minimap", L["Show minimap button"],
		L["Left-click opens the buffs window, right-click the options."], true,
		function() return not s.minimapHidden end, function(value) ns.MinimapButton.SetShown(value, true) end)

	Settings.RegisterAddOnCategory(category)
end

ns.Listen("DB_READY", Build)

-- opens the panel; false when this client has no options panel for addons
function Options.Open()
	if not (category and Settings and Settings.OpenToCategory) then return false end
	if Safe.InCombat() then
		ns.Print(L["The options can't be opened in combat. Try again after the fight."])
		return true
	end
	local id = category.GetID and category:GetID() or category.ID
	return pcall(Settings.OpenToCategory, id) and true or false
end
