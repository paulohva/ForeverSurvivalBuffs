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

local function ClassTitle()
	local name = ns.Safe.CallAll(UnitClass, "player")
	return name and L["%s buffs"]:format(name) or L["Class buffs"]
end

local function Items()
	local items = { { header = L["Survival"] } }
	local classHeader = false
	for _, entry in ipairs(Tracker.entries) do
		if not Catalog.IsDefault(entry) and not classHeader then
			classHeader = true
			table.insert(items, { header = ClassTitle() })
		end
		table.insert(items, { entry = entry })
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
	scrollBox:SetDataProvider(CreateDataProvider(Items()), ScrollBoxConstants and ScrollBoxConstants.RetainScrollPosition)
end

local function StatusText(entry)
	local status, reason = Tracker.Status(entry)
	if status == "unavailable" then return L[REASON[reason] or "Not available"], 0.5, 0.5, 0.5 end
	if Tracker.IsEnding(entry) then return L["Ending soon"], 1, 0.75, 0.2 end
	local s = STATUS[status] or STATUS.unknown
	return L[s[1]], s[2], s[3], s[4]
end

local function RowTooltip(row)
	local entry = row.entry
	if not entry then return end
	GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
	GameTooltip:AddLine(Catalog.Name(entry), 1, 0.82, 0, true)
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
	if dim then row.Name:SetTextColor(0.6, 0.6, 0.6) else row.Name:SetTextColor(1, 1, 1) end
	local text, r, g, b = StatusText(entry)
	row.Status:SetText(text)
	row.Status:SetTextColor(r, g, b)
	row.Check:SetChecked(Tracker.IsChosen(entry, editing))
	row.Check:SetScript("OnClick", function(self)
		Tracker.SetChosen(entry, self:GetChecked(), editing)
	end)
	row:EnableMouse(true)
	row:SetScript("OnEnter", RowTooltip)
	row:SetScript("OnLeave", function() GameTooltip:Hide() end)
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
	help:SetPoint("TOPLEFT", frame, "TOPLEFT", 64, -30)
	help:SetPoint("RIGHT", frame, "RIGHT", -12, 0)
	help:SetJustifyH("LEFT")
	help:SetText(L["Tick the buffs you want to be reminded of."])

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

	frame:SetScript("OnShow", function()
		editing = Tracker.Profile()
		Tracker.Update()
		Window.Refresh()
	end)

	-- the template's close button uses HideUIPanel, protected in combat: hide directly
	local close = frame.CloseButton or _G["ForeverSurvivalBuffsFrameCloseButton"]
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
