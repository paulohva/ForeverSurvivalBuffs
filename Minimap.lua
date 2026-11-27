--------------------------------------------------------------------------------
-- Minimap button: left-click opens the buffs window, right-click the options
-- menu, drag to move it around the minimap. /fsb minimap shows or hides it.
-- The same two clicks work from the game's AddOns menu (addon compartment).
--------------------------------------------------------------------------------

local _, ns = ...
local L = ns.L

local MinimapButton = {}
ns.MinimapButton = MinimapButton

local button

-- the centre of the border ring's opening, from the button's top-left corner, and the icon's size
local RING_X, RING_Y = 17.8, -16.7
local ICON_SIZE = 22

local function SetAngle(angle)
	ns.db.settings.minimapAngle = angle
	local rad = math.rad(angle)
	local radius = (Minimap:GetWidth() / 2) + 5
	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER", math.cos(rad) * radius, math.sin(rad) * radius)
end

local function OnDragUpdate()
	local mx, my = Minimap:GetCenter()
	local scale = Minimap:GetEffectiveScale()
	local cx, cy = GetCursorPosition()
	cx, cy = cx / scale, cy / scale
	SetAngle(math.deg(math.atan2(cy - my, cx - mx)))
end

local function FillTooltip(tooltip)
	tooltip:AddLine(ns.NAME)
	tooltip:AddLine(L["Left-click: choose your buffs"], 0.5, 0.5, 0.5)
	tooltip:AddLine(L["Right-click: options"], 0.5, 0.5, 0.5)
end

-- right-click: the options (everything else lives there) and hiding the button,
-- like Old Friends List's (left-click opens the buffs window, so it isn't repeated here)
function MinimapButton.OpenMenu(owner)
	if not (MenuUtil and MenuUtil.CreateContextMenu) then
		if ns.Options then ns.Options.Open() end
		return
	end
	MenuUtil.CreateContextMenu(owner, function(_, root)
		root:CreateTitle(ns.NAME)
		root:CreateButton(SETTINGS or L["Settings..."], function() ns.Options.Open() end)
		root:CreateButton(L["Hide minimap button"], function() MinimapButton.SetShown(false) end)
	end)
end

local function Build()
	button = CreateFrame("Button", "ForeverSurvivalBuffsMinimapButton", Minimap)
	button:SetSize(31, 31)
	button:SetFrameStrata("MEDIUM")
	button:SetFrameLevel(8)
	button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:RegisterForDrag("LeftButton")

	-- the ring's opening isn't centred on the 31x31 button: icon and background are centred on it
	local background = button:CreateTexture(nil, "BACKGROUND")
	background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
	background:SetSize(ICON_SIZE + 2, ICON_SIZE + 2)
	background:SetPoint("CENTER", button, "TOPLEFT", RING_X, RING_Y)

	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetTexture(ns.MINIMAP_ICON)
	icon:SetSize(ICON_SIZE, ICON_SIZE)
	icon:SetPoint("CENTER", button, "TOPLEFT", RING_X, RING_Y)
	if icon.SetMask then pcall(icon.SetMask, icon, "Interface\\CharacterFrame\\TempPortraitAlphaMask") end
	button.icon = icon

	local border = button:CreateTexture(nil, "OVERLAY")
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	border:SetSize(53, 53)
	border:SetPoint("TOPLEFT")

	button:SetScript("OnClick", function(self, mouse)
		GameTooltip:Hide()
		if mouse == "RightButton" then MinimapButton.OpenMenu(self) else ns.BuffWindow.Toggle() end
	end)
	button:SetScript("OnDragStart", function(self)
		GameTooltip:Hide()
		self:SetScript("OnUpdate", OnDragUpdate)
	end)
	button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		FillTooltip(GameTooltip)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function() GameTooltip:Hide() end)
	button:SetScript("OnMouseDown", function() icon:SetSize(ICON_SIZE - 2, ICON_SIZE - 2) end)
	button:SetScript("OnMouseUp", function() icon:SetSize(ICON_SIZE, ICON_SIZE) end)

	SetAngle(ns.db.settings.minimapAngle or 225)
end

-- quiet: no chat message (when toggled from the options panel)
function MinimapButton.SetShown(show, quiet)
	ns.db.settings.minimapHidden = not show
	if show and not button then Build() end
	if button then button:SetShown(show) end
	if not show and not quiet then ns.Print(L["Minimap button hidden. /fsb minimap brings it back."]) end
end

ns.Listen("LOGIN", function()
	if not Minimap then return end
	if not ns.db.settings.minimapHidden then Build() end
end)

--------------------------------------------------------------------------------
-- The game's AddOns menu (named in the .toc)
--------------------------------------------------------------------------------

function ForeverSurvivalBuffs_OnAddonCompartmentClick(_, mouse, menuButton)
	if mouse == "RightButton" then
		MinimapButton.OpenMenu(menuButton or UIParent)
	else
		ns.BuffWindow.Toggle()
	end
end

function ForeverSurvivalBuffs_OnAddonCompartmentEnter(_, owner)
	GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
	FillTooltip(GameTooltip)
	GameTooltip:Show()
end

function ForeverSurvivalBuffs_OnAddonCompartmentLeave()
	GameTooltip:Hide()
end
