--------------------------------------------------------------------------------
-- The buffs window: every buff this character can be reminded of, each with a
-- check box. The survival buffs come ticked; the class buffs and weapon
-- enhancements are ticked by the player. Choices are kept per class, in two
-- lists: one for dungeons and raids, one for everywhere else (the tabs below).
-- Opened from the minimap button, the AddOns menu, a reminder's right-click or /fsb.
--------------------------------------------------------------------------------

local _, ns = ...
local L, Catalog, Tracker = ns.L, ns.Catalog, ns.Tracker

local Window = {}
ns.BuffWindow = Window

local WIDTH, HEIGHT = 360, 480
local ROW_HEIGHT = 26

local frame, scrollBox
local editing = "world"   -- the list the check boxes change: "world" or "instance"

-- the two lists, as tabs below the window
local TABS = {
	{ profile = "world", text = "Outside", tip = "The buffs to be reminded of everywhere else." },
	{ profile = "instance", text = "Dungeons and raids",
		tip = "The buffs to be reminded of inside dungeons and raids. Until you change it, it's the same as the other list." },
}

local STATUS = {
	active = { "Active", 0.25, 1, 0.25 },
	missing = { "Missing", 1, 0.3, 0.3 },
	unknown = { "?", 0.6, 0.6, 0.6 },
}
local REASON = {
	notLearned = "Not learned",
	noWeapon = "No weapon",
	noBag = "No sleeping bag",
	maxLevel = "Max level",
}

-- the expiry warning's clock: bright when on, faded when off
local CLOCK = "Interface\\Icons\\INV_Misc_PocketWatch_01"
local function ShowClock(texture, on)
	texture:SetTexture(CLOCK)
	texture:SetDesaturated(not on)
	texture:SetAlpha(on and 1 or 0.35)
end

local function ClassTitle()
	local name = ns.Safe.CallAll(UnitClass, "player")
	return name and L["%s buffs"]:format(name) or L["Class buffs"]
end

local function Items()
	local items = { { header = L["Survival"] } }
	local classHeader = false
	for _, entry in ipairs(Tracker.entries) do
		-- spells not learned yet stay out of the list (they show up once learned)
		local _, reason = Tracker.Status(entry)
		if reason ~= "notLearned" then
			if not Catalog.IsDefault(entry) and not classHeader then
				classHeader = true
				table.insert(items, { header = ClassTitle() })
			end
			table.insert(items, { entry = entry })
		end
	end
	return items
end

-- tab texts ("(now)" on the list in use) and which tab is selected
local function UpdateTabs()
	local current = Tracker.Profile()
	for i, info in ipairs(TABS) do
		local tab = frame.Tabs[i]
		local text = L[info.text]
		if info.profile == current then text = text .. L[" (now)"] end
		tab:SetText(text)
		if PanelTemplates_TabResize then pcall(PanelTemplates_TabResize, tab, 0) end
		if info.profile == editing then
			if PanelTemplates_SetTab then
				pcall(PanelTemplates_SetTab, frame, i)
			else
				tab:LockHighlight()
			end
		elseif not PanelTemplates_SetTab then
			tab:UnlockHighlight()
		end
	end
end

local function CreateTabs()
	frame.Tabs = {}
	for i, info in ipairs(TABS) do
		local name = "ForeverSurvivalBuffsFrameTab" .. i
		local ok, tab = pcall(CreateFrame, "Button", name, frame, "PanelTabButtonTemplate")
		if not ok or not tab then
			tab = CreateFrame("Button", name, frame, "UIPanelButtonTemplate")
			tab:SetSize(150, 22)
		end
		tab:SetID(i)
		if i == 1 then
			tab:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 11, 2)
		else
			tab:SetPoint("TOPLEFT", frame.Tabs[i - 1], "TOPRIGHT", 3, 0)
		end
		tab:SetScript("OnClick", function()
			editing = info.profile
			Window.Refresh()
		end)
		tab:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
			GameTooltip:AddLine(L[info.tip], 1, 1, 1, true)
			GameTooltip:Show()
		end)
		tab:SetScript("OnLeave", function() GameTooltip:Hide() end)
		frame.Tabs[i] = tab
	end
	if PanelTemplates_SetNumTabs then pcall(PanelTemplates_SetNumTabs, frame, #TABS) end
end

function Window.Refresh()
	if not (frame and frame:IsShown()) then return end
	UpdateTabs()
	ShowClock(frame.WarnAll.Clock, Tracker.AllWarn())
	scrollBox:SetDataProvider(CreateDataProvider(Items()), ScrollBoxConstants and ScrollBoxConstants.RetainScrollPosition)
end

local function StatusText(entry)
	local status, reason = Tracker.Status(entry)
	if status == "unavailable" then return L[REASON[reason] or "Not available"], 0.5, 0.5, 0.5 end
	if Tracker.IsEnding(entry) then return L["Ending soon"], 1, 0.75, 0.2 end
	local s = STATUS[status] or STATUS.unknown
	return L[s[1]], s[2], s[3], s[4]
end

local function FormatTime(seconds)
	seconds = math.floor(seconds + 0.5)
	return ("%d:%02d"):format(math.floor(seconds / 60), seconds % 60)
end

local function RowTooltip(row)
	local entry = row.entry
	if not entry then return end
	GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
	GameTooltip:AddLine(Catalog.Name(entry), 1, 0.82, 0, true)
	-- on you right now? (and for how long)
	local text, r, g, b = StatusText(entry)
	local left = Tracker.TimeLeft(entry)
	if left then text = text .. "  " .. FormatTime(left) end
	GameTooltip:AddLine(text, r, g, b)
	GameTooltip:AddLine(Catalog.Hint(entry), 1, 1, 1, true)
	if Tracker.secret then
		GameTooltip:AddLine(L["Buffs can't be read right now (combat or instance); this is what was last seen."],
			0.6, 0.6, 0.6, true)
	end
	GameTooltip:Show()
end

local function InitRow(row, item)
	local entry = item.entry
	row.entry = entry
	local status = Tracker.Status(entry)
	local dim = status == "unavailable"
	row.Icon:SetTexture(Catalog.Icon(entry))
	row.Icon:SetDesaturated(dim)
	row.Name:SetText(Catalog.Name(entry))
	local chosen = Tracker.IsChosen(entry, editing)
	-- ticked: full white; not ticked: faded; can't apply: grey, with the reason
	-- where the clock would be
	local _, reason = Tracker.Status(entry)
	row.Icon:SetAlpha((chosen and not dim) and 1 or 0.55)
	if dim then row.Name:SetTextColor(0.5, 0.5, 0.5)
	elseif chosen then row.Name:SetTextColor(1, 1, 1)
	else row.Name:SetTextColor(0.65, 0.65, 0.65) end
	row.Reason:SetText(dim and L[REASON[reason] or "Not available"] or "")
	row.Name:SetPoint("RIGHT", row, "RIGHT", dim and -((row.Reason:GetStringWidth() or 0) + 12) or -30, 0)
	row.Check:SetChecked(chosen)
	row.Check:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(L["Remind me"], 1, 0.82, 0)
		GameTooltip:AddLine(L["An icon shows while this buff is missing."], 1, 1, 1, true)
		GameTooltip:Show()
	end)
	row.Check:SetScript("OnLeave", function() GameTooltip:Hide() end)
	row.Check:SetScript("OnClick", function(self)
		Tracker.SetChosen(entry, self:GetChecked(), editing)
	end)
	-- the clock: the expiry warning, on every buff that can apply (it works apart
	-- from the check box: warned before it runs out, reminded or not when it's missing)
	local warnOn = Tracker.WarnOn(entry)
	row.Warn:SetShown(not dim)
	ShowClock(row.Warn.Clock, warnOn)
	row.Warn:SetScript("OnClick", function()
		Tracker.SetWarn(entry, not Tracker.WarnOn(entry))
	end)
	row.Warn:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(Tracker.WarnOn(entry) and L["Expiry warning: on"] or L["Expiry warning: off"], 1, 0.82, 0)
		GameTooltip:AddLine(L["The reminder shows again, fading in and out, %d min before this buff ends (set the time in the options)."]
			:format(Tracker.WarnSeconds() / 60), 1, 1, 1, true)
		GameTooltip:AddLine(L["Click to turn it on or off."], 0.6, 0.6, 0.6)
		GameTooltip:Show()
	end)
	row.Warn:SetScript("OnLeave", function() GameTooltip:Hide() end)
	row:EnableMouse(true)
	row:SetScript("OnEnter", RowTooltip)
	row:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function WarnAllTooltip(self)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:AddLine(L["Expiry warning on every buff"], 1, 0.82, 0)
	GameTooltip:AddLine(L["Turns the clock of every buff on or off at once."], 1, 1, 1, true)
	GameTooltip:Show()
end

local function InitHeader(row, item)
	row.Text:SetText(item.header)
end

local function Build()
	frame = CreateFrame("Frame", "ForeverSurvivalBuffsFrame", UIParent, "ButtonFrameTemplate")
	frame:SetSize(WIDTH, HEIGHT)
	frame:SetFrameStrata("DIALOG")
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local point, _, relPoint, x, y = self:GetPoint(1)
		ns.db.windowPosition = { point, relPoint, x, y }
	end)
	local pos = ns.db.windowPosition
	if pos then
		frame:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
	else
		frame:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
	end

	if frame.SetTitle then frame:SetTitle(ns.NAME)
	elseif frame.TitleText then frame.TitleText:SetText(ns.NAME) end
	if frame.SetPortraitToAsset then pcall(frame.SetPortraitToAsset, frame, ns.PORTRAIT) end

	local help = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	-- one line, centred in the band between the title bar and the list, on the
	-- gear's line (its centre is 43 px down)
	help:SetPoint("LEFT", frame, "TOPLEFT", 70, -43)
	help:SetPoint("RIGHT", frame, "TOPRIGHT", -34, -43)   -- room for the gear
	help:SetJustifyH("LEFT")
	help:SetText(L["Tick the buffs to be reminded of."])


	local inset = frame.Inset or frame
	scrollBox = CreateFrame("Frame", nil, inset, "WowScrollBoxList")
	scrollBox:SetPoint("TOPLEFT", inset, "TOPLEFT", 4, -4)
	scrollBox:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -20, 4)
	local scrollBar = CreateFrame("EventFrame", nil, inset, "MinimalScrollBar")
	scrollBar:SetPoint("TOPLEFT", scrollBox, "TOPRIGHT", 6, -2)
	scrollBar:SetPoint("BOTTOMLEFT", scrollBox, "BOTTOMRIGHT", 6, 2)

	local view = CreateScrollBoxListLinearView()
	view:SetElementExtent(ROW_HEIGHT)
	view:SetElementFactory(function(factory, item)
		if item.header then
			factory("ForeverSurvivalBuffsHeaderTemplate", InitHeader)
		else
			factory("ForeverSurvivalBuffsRowTemplate", InitRow)
		end
	end)
	ScrollUtil.InitScrollBoxListWithScrollBar(scrollBox, scrollBar, view)

	CreateTabs()

	-- the clock for every buff at once: in the grey strip below the list, right under
	-- the rows' clocks (rows end 20 px short of the list's edge, for the scroll bar,
	-- and the clock sits 6 px in from there)
	local warnAll = CreateFrame("Button", nil, frame)
	-- in the middle of the visible grey strip (the window's border covers its
	-- bottom few pixels): 10 px below the list
	warnAll:SetSize(18, 18)
	warnAll:SetPoint("RIGHT", inset, "BOTTOMRIGHT", -26, -10)
	warnAll.Clock = warnAll:CreateTexture(nil, "ARTWORK")
	warnAll.Clock:SetAllPoints()
	warnAll.Clock:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	local warnText = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	warnText:SetPoint("RIGHT", warnAll, "LEFT", -5, 0)
	warnText:SetText(L["Expiry warning on every buff"])
	warnAll:SetScript("OnClick", function() Tracker.SetWarnAll(not Tracker.AllWarn()) end)
	warnAll:SetScript("OnEnter", WarnAllTooltip)
	warnAll:SetScript("OnLeave", function() GameTooltip:Hide() end)
	frame.WarnAll = warnAll

	-- a small, quiet gear under the title bar, as in Old Friends List's window:
	-- opens the options (closing this window, which would cover them)
	local gear = CreateFrame("Button", nil, frame)
	gear:SetSize(16, 16)
	gear:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -35)
	local gearIcon = gear:CreateTexture(nil, "ARTWORK")
	gearIcon:SetAllPoints()
	if not (gearIcon.SetAtlas and pcall(gearIcon.SetAtlas, gearIcon, "QuestLog-icon-setting")) then
		gearIcon:SetTexture("Interface\\Buttons\\UI-OptionsButton")
	end
	gearIcon:SetDesaturated(true)
	gear:SetAlpha(0.45)
	gear:SetScript("OnClick", function()
		frame:Hide()
		if not ns.Options.Open() then ns.Print(L["This client has no options panel for addons."]) end
	end)
	gear:SetScript("OnEnter", function(self)
		self:SetAlpha(1)
		gearIcon:SetDesaturated(false)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(L["Settings..."], 1, 1, 1)
		GameTooltip:Show()
	end)
	gear:SetScript("OnLeave", function(self)
		self:SetAlpha(0.45)
		gearIcon:SetDesaturated(true)
		GameTooltip:Hide()
	end)
	local close = frame.CloseButton or _G["ForeverSurvivalBuffsFrameCloseButton"]

	frame:SetScript("OnShow", function()
		editing = Tracker.Profile()
		Tracker.Update()
		Window.Refresh()
	end)

	-- the template's close button uses HideUIPanel, protected in combat: hide directly
	if close then close:SetScript("OnClick", function() frame:Hide() end) end

	tinsert(UISpecialFrames, "ForeverSurvivalBuffsFrame")
	frame:Hide()
end

function Window.Toggle()
	if not ns.db then return end
	if not frame then Build() end
	frame:SetShown(not frame:IsShown())
end

ns.Listen("UPDATED", function() ns.Debounce("buffWindow", 0.1, Window.Refresh) end)
