--------------------------------------------------------------------------------
-- The reminders: one icon for each chosen buff that's missing, in a row that
-- stays centred on its spot. Nothing shows when every chosen buff is up. A buff
-- about to run out (the sleeping bag, 3 minutes before) shows too, fading in and out.
-- Alt + drag moves the row; "Unlock" (options, minimap menu, /fsb unlock) shows
-- every chosen buff so the row can be placed and dragged without Alt.
--------------------------------------------------------------------------------

local _, ns = ...
local L, Safe, Catalog, Tracker = ns.L, ns.Safe, ns.Catalog, ns.Tracker

local Reminders = {}
ns.Reminders = Reminders

local GAP = 6
local DEFAULT_Y = -240   -- below the character, above the action bars

local frame, label
local buttons = {}

local function Opts() return ns.db.settings end

--------------------------------------------------------------------------------
-- Position: kept as the row's centre relative to the screen's centre, so the
-- row grows evenly to both sides when more buffs are missing.
--------------------------------------------------------------------------------

local function ApplyPosition()
	local pos = ns.db.position
	frame:ClearAllPoints()
	if pos then
		frame:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
	else
		frame:SetPoint("CENTER", UIParent, "CENTER", 0, DEFAULT_Y)
	end
end

local function SavePosition()
	local x, y = frame:GetCenter()
	local px, py = UIParent:GetCenter()
	if not (x and px) then return end
	local scale = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
	ns.db.position = { "CENTER", "CENTER", x * scale - px, y * scale - py }
	ApplyPosition()
end

function Reminders.ResetPosition()
	ns.db.position = nil
	if frame then ApplyPosition() end
end

local function CanDrag()
	return not Opts().locked or IsAltKeyDown()
end

local function DragStart()
	if CanDrag() then
		frame.moving = true
		frame:StartMoving()
	end
end

local function DragStop()
	if not frame.moving then return end
	frame.moving = false
	frame:StopMovingOrSizing()
	SavePosition()
end

--------------------------------------------------------------------------------
-- Icons
--------------------------------------------------------------------------------

local function FormatTime(seconds)
	seconds = math.floor(seconds + 0.5)
	return ("%d:%02d"):format(math.floor(seconds / 60), seconds % 60)
end

local function ShowTooltip(self)
	local entry = self.entry
	if not entry then return end
	GameTooltip:SetOwner(self, "ANCHOR_TOP")
	local left = Tracker.IsEnding(entry) and Tracker.TimeLeft(entry)
	if left then
		GameTooltip:AddLine(L["%s ends in %s"]:format(Catalog.Name(entry), FormatTime(left)), 1, 0.82, 0)
		GameTooltip:AddLine(Catalog.Hint(entry), 1, 1, 1, true)
	elseif Opts().locked then
		GameTooltip:AddLine(L["Missing: %s"]:format(Catalog.Name(entry)), 1, 0.82, 0)
		GameTooltip:AddLine(Catalog.Hint(entry), 1, 1, 1, true)
	else
		GameTooltip:AddLine(Catalog.Name(entry), 1, 0.82, 0)
	end
	GameTooltip:AddLine(" ")
	GameTooltip:AddLine(Opts().locked and L["Alt + drag to move."] or L["Drag to move. Lock it in the options when done."],
		0.6, 0.6, 0.6, true)
	GameTooltip:AddLine(L["Right-click: choose your buffs"], 0.6, 0.6, 0.6)
	GameTooltip:Show()
end

local function CreateIcon()
	local button = CreateFrame("Button", nil, frame)
	button:RegisterForClicks("RightButtonUp")
	button:RegisterForDrag("LeftButton")

	local bg = button:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0, 0, 0, 0.6)

	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetPoint("TOPLEFT", 1, -1)
	icon:SetPoint("BOTTOMRIGHT", -1, 1)
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	button.icon = icon

	-- a soft red tint: something is missing
	local tint = button:CreateTexture(nil, "OVERLAY")
	tint:SetAllPoints()
	tint:SetColorTexture(0.9, 0.2, 0.2, 0.35)
	tint:SetBlendMode("ADD")
	button.tint = tint

	-- a slow, soft fade in and out: the buff is about to run out
	local pulse = button:CreateAnimationGroup()
	pulse:SetLooping("BOUNCE")
	local fade = pulse:CreateAnimation("Alpha")
	fade:SetFromAlpha(1)
	fade:SetToAlpha(0.3)
	fade:SetDuration(1.2)
	if fade.SetSmoothing then fade:SetSmoothing("IN_OUT") end
	button.pulse = pulse

	button:SetScript("OnDragStart", DragStart)
	button:SetScript("OnDragStop", DragStop)
	button:SetScript("OnClick", function() if ns.BuffWindow then ns.BuffWindow.Toggle() end end)
	button:SetScript("OnEnter", ShowTooltip)
	button:SetScript("OnLeave", function() GameTooltip:Hide() end)
	return button
end

-- what to show: the chosen buffs that are missing, and the buffs with an expiry
-- warning about to run out; while unlocked, every chosen buff that applies
local function Shown()
	local locked = Opts().locked
	local list = {}
	for _, entry in ipairs(Tracker.entries) do
		local status = Tracker.Status(entry)
		if locked then
			if (status == "missing" and Tracker.IsChosen(entry)) or Tracker.IsEnding(entry) then
				table.insert(list, entry)
			end
		elseif Tracker.IsChosen(entry) and status ~= "unavailable" then
			table.insert(list, entry)
		end
	end
	return list
end

-- missing: red tint; about to run out: a golden tint that fades in and out
local function Style(button, entry)
	local ending = Tracker.IsEnding(entry)
	if ending then
		button.tint:SetColorTexture(1, 0.75, 0.2, 0.3)
		button.tint:Show()
		if not button.pulse:IsPlaying() then button.pulse:Play() end
	else
		button.tint:SetColorTexture(0.9, 0.2, 0.2, 0.35)
		button.tint:SetShown(Opts().locked)
		button.pulse:Stop()
		button:SetAlpha(1)
	end
end

local function ShouldHide()
	local s = Opts()
	if not s.locked then return false end
	if not s.enabled then return true end
	if Safe.Call(UnitIsDeadOrGhost, "player") then return true end
	if s.hideInCombat and Safe.InCombat() then return true end
	return false
end

function Reminders.Refresh()
	if not frame then return end
	local list = ShouldHide() and {} or Shown()
	local size = Opts().iconSize or ns.DEFAULTS.iconSize
	local n = #list

	for i, entry in ipairs(list) do
		local button = buttons[i] or CreateIcon()
		buttons[i] = button
		button.entry = entry
		button:SetSize(size, size)
		button.icon:SetTexture(Catalog.Icon(entry))
		Style(button, entry)
		button:ClearAllPoints()
		button:SetPoint("LEFT", frame, "LEFT", (i - 1) * (size + GAP), 0)
		button:Show()
	end
	for i = n + 1, #buttons do
		buttons[i]:Hide()
		buttons[i].pulse:Stop()
		buttons[i].entry = nil
	end

	if n == 0 then
		if frame.moving then DragStop() end
		frame:Hide()
		return
	end
	frame:SetSize(n * size + (n - 1) * GAP, size)
	label:SetShown(not Opts().locked)
	frame:Show()
end

--------------------------------------------------------------------------------
-- Locking
--------------------------------------------------------------------------------

function Reminders.SetLocked(locked)
	Opts().locked = locked and true or false
	Reminders.Refresh()
	if Settings and Settings.NotifyUpdate then pcall(Settings.NotifyUpdate, "ForeverSurvivalBuffs_locked") end
end

local function Build()
	frame = CreateFrame("Frame", "ForeverSurvivalBuffsReminders", UIParent)
	frame:SetSize(32, 32)
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", DragStart)
	frame:SetScript("OnDragStop", DragStop)
	frame:SetScript("OnHide", function() if frame.moving then DragStop() end end)
	ApplyPosition()

	label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	label:SetPoint("BOTTOM", frame, "TOP", 0, 4)
	label:SetText(L["ForeverSurvivalBuffs: drag to move"])
	label:Hide()

	frame:Hide()
end

ns.Listen("LOGIN", function()
	Build()
	Reminders.Refresh()
end)
ns.Listen("UPDATED", Reminders.Refresh)
ns.On("PLAYER_REGEN_DISABLED", function() Reminders.Refresh() end)
ns.On("PLAYER_REGEN_ENABLED", function() Reminders.Refresh() end)
