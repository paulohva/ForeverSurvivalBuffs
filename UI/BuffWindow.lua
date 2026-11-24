--------------------------------------------------------------------------------
-- The buffs window: every buff this character can be reminded of, each with a
-- check box. The survival buffs come ticked; the class buffs and weapon
-- enhancements are ticked by the player. Choices are kept per class, and with
-- "Another list in dungeons and raids" on, two tabs choose which list to change.
-- Opened from the minimap button, the AddOns menu, a reminder's right-click or /fsb.
--------------------------------------------------------------------------------

local _, ns = ...
local L, Catalog, Tracker = ns.L, ns.Catalog, ns.Tracker

local Window = {}
ns.BuffWindow = Window

local WIDTH, HEIGHT = 360, 480
local ROW_HEIGHT = 26

local TAB_HEIGHT = 22
local TAB_WIDTH = 166   -- two side by side in the list area (about 350 wide)

local frame, scrollBox, tabs, instanceCheck
local editing = "world"   -- the list the check boxes change: "world" or "instance"

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

-- the two lists, as tabs above the buffs, when the dungeon list is on
local TAB_TEXT = { world = "Outside", instance = "Dungeons and raids" }

local function LayoutTabs()
	local on = ns.db.settings.instanceProfile and true or false
	if not on then editing = "world" end
	instanceCheck:SetChecked(on)
	local inset = frame.Inset or frame
	scrollBox:SetPoint("TOPLEFT", inset, "TOPLEFT", 4, on and -(TAB_HEIGHT + 8) or -4)
	local current = Tracker.Profile()
	for profile, tab in pairs(tabs) do
		tab:SetShown(on)
		local text = L[TAB_TEXT[profile]]
		if profile == current then text = text .. L[" (now)"] end
		tab:SetText(text)
		if profile == editing then
			tab:LockHighlight()
			tab:GetFontString():SetTextColor(1, 0.82, 0)
		else
			tab:UnlockHighlight()
			tab:GetFontString():SetTextColor(1, 1, 1)
		end
	end
end

function Window.Refresh()
	if not (frame and frame:IsShown()) then return end
	LayoutTabs()
	scrollBox:SetDataProvider(CreateDataProvider(Items()), ScrollBoxConstants and ScrollBoxConstants.RetainScrollPosition)
end

local function StatusText(entry)
	local status, reason = Tracker.Status(entry)
	if status == "unavailable" then return L[REASON[reason] or "Not available"], 0.5, 0.5, 0.5 end
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
	if frame.SetPortraitToAsset then pcall(frame.SetPortraitToAsset, frame, ns.ICON) end

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

	-- the lists' tabs
	tabs = {}
	for i, profile in ipairs({ "world", "instance" }) do
		local tab = CreateFrame("Button", nil, inset, "UIPanelButtonTemplate")
		tab:SetSize(TAB_WIDTH, TAB_HEIGHT)
		if i == 1 then
			tab:SetPoint("TOPLEFT", inset, "TOPLEFT", 6, -4)
		else
			tab:SetPoint("TOPRIGHT", inset, "TOPRIGHT", -6, -4)
		end
		tab:SetScript("OnClick", function()
			editing = profile
			Window.Refresh()
		end)
		tab:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip:AddLine(profile == "instance"
				and L["The buffs to be reminded of inside dungeons and raids."]
				or L["The buffs to be reminded of everywhere else."], 1, 1, 1, true)
			GameTooltip:Show()
		end)
		tab:SetScript("OnLeave", function() GameTooltip:Hide() end)
		tab:Hide()
		tabs[profile] = tab
	end

	-- the switch for the dungeon list, below the buffs
	instanceCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
	instanceCheck:SetSize(24, 24)
	instanceCheck:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 6, 1)
	local checkText = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	checkText:SetPoint("LEFT", instanceCheck, "RIGHT", 2, 1)
	checkText:SetText(L["Another list in dungeons and raids"])
	instanceCheck:SetScript("OnClick", function(self)
		local on = self:GetChecked() and true or false
		editing = on and "instance" or "world"
		Tracker.SetInstanceProfile(on)
		Window.Refresh()
	end)
	instanceCheck:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:AddLine(L["Another list in dungeons and raids"], 1, 0.82, 0)
		GameTooltip:AddLine(L["Inside a dungeon or raid the addon switches to its own list of buffs. It starts as a copy of the usual one."],
			1, 1, 1, true)
		GameTooltip:Show()
	end)
	instanceCheck:SetScript("OnLeave", function() GameTooltip:Hide() end)

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
