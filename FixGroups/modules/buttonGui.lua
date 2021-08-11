--- Define the minimap icon, the Fix Groups button on the raid tab, and
-- their tooltips.
local A, L = unpack(select(2, ...))
local M = A:NewModule("buttonGui", "AceEvent-3.0")
A.buttonGui = M
M.private = {icon = false, iconLDB = false, raidTabButton = false, flashTimer = false}
local R = M.private

local NUM_FLASHES = 3
local DELAY_FLASH = 0.5

local format, strfind, strlower, time, tostring = format, strfind, strlower, time, tostring
local CreateFrame, InCombatLockdown, IsControlKeyDown, IsShiftKeyDown, UnitName =
	CreateFrame,
	InCombatLockdown,
	IsControlKeyDown,
	IsShiftKeyDown,
	UnitName
-- GLOBALS: LibStub, GameTooltip, RaidFrame, RaidFrameRaidInfoButton

local CUBE_ICON_0 = "Interface\\Addons\\" .. A.NAME .. "\\media\\cubeIcon0_64.tga"
local CUBE_ICON_1 = "Interface\\Addons\\" .. A.NAME .. "\\media\\cubeIcon1_64.tga"
local CUBE_ICON_BW = "Interface\\Addons\\" .. A.NAME .. "\\media\\cubeIconBW_64.tga"
local TOOLTIP_RIGHT_GUI = format(L["tooltip.right.gui"], A.util:Highlight("/fg"))

local function handleClick(_, button)
	if button == "RightButton" then
		if IsControlKeyDown() then
			A.fgCommand:Command("config")
		else
			A.fgCommand:Command("")
		end
	else
		if IsControlKeyDown() then
			A.fgCommand:Command("cancel")
		elseif IsShiftKeyDown() then
			A.fgCommand:Command("last")
		else
			A.fgCommand:Command("default")
		end
	end
end

local function watchChat(event, message, sender)
	if A.DEBUG >= 1 then
		A.console:Debugf(M, "watchChat event=%s message=[%s] sender=%s", event, A.util:Escape(message), sender)
	end
	if A.options.watchChat and sender ~= UnitName("player") and message and A.sorter:CanBegin() then
		message = strlower(message)
		-- Search for both the default and the localized keywords.
		if
			strfind(message, "fix%s+group") or strfind(message, "mark%s+tank") or strfind(message, "set%s+tank") or
				A.util:WatchChatKeywordMatches(message)
		 then
			M:FlashRaidTabButton()
		end
	end
end

local function refresh()
	M:Refresh()
end

local function setupMinimapIcon()
	if R.icon then
		return
	end
	R.iconLDB = LibStub("LibDataBroker-1.1"):NewDataObject(A.NAME, {
		type = "launcher",
		text = A.NAME,
		icon = CUBE_ICON_1,
		OnClick = handleClick,
		OnTooltipShow = function(tooltip) M:SetupTooltip(tooltip, true) end
	})
	R.icon = LibStub("LibDBIcon-1.0")
	R.icon:Register(A.NAME, R.iconLDB, A.options.minimapIcon)
end

local function setupRaidTabButton()
	if R.raidTabButton then return end
	local b = CreateFrame("BUTTON", nil, RaidFrame, "UIPanelButtonTemplate")
	b:SetPoint("TOPLEFT", RaidFrame, "TOPLEFT", 68, -13)
	b:SetSize(RaidFrameRaidInfoButton:GetWidth(), RaidFrameRaidInfoButton:GetHeight())
	b:GetFontString():SetFont(RaidFrameRaidInfoButton:GetFontString():GetFont())
	b:SetText(L["button.fixGroups.text"])
	b:RegisterForClicks("AnyUp")
	b:SetScript("OnClick", handleClick)
	b:SetScript("OnEnter", function(frame)
		GameTooltip:SetOwner(frame, "ANCHOR_BOTTOMRIGHT")
		M:SetupTooltip(GameTooltip, false)
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	local skin = A.utilGui and A.utilGui:GetElvUISkinModule()
	if skin then
		skin:HandleButton(b, true)
	end
	if A.options.addButtonToRaidTab then
		b:Show()
	else
		b:Hide()
	end
	R.raidTabButton = b
end

function M:OnEnable()
	M:RegisterEvent("PLAYER_ENTERING_WORLD", refresh)
	M:RegisterEvent("PARTY_MEMBERS_CHANGED", refresh)
	M:RegisterEvent("RAID_ROSTER_UPDATE", refresh)
	M:RegisterEvent("CHAT_MSG_RAID", watchChat)
	M:RegisterEvent("CHAT_MSG_RAID_LEADER", watchChat)
	M:RegisterEvent("CHAT_MSG_SAY", watchChat)
	M:RegisterEvent("CHAT_MSG_WHISPER", watchChat)
	setupMinimapIcon()
	setupRaidTabButton()
end

function M:SetupTooltip(tooltip, isMinimapIcon)
	tooltip:ClearLines()
	if A:IsInGroup() then
		tooltip:AddDoubleLine(A.NAME, A.group:GetComp(A.util.GROUP_COMP_STYLE.ICONS_FULL))
	else
		tooltip:AddLine(A.NAME)
	end
	if A.sorter:IsPaused() then
		tooltip:AddLine(" ")
		tooltip:AddLine(A.util:Highlight(A.sorter:GetPausedSortMode()))
	end
	tooltip:AddLine(" ")
	tooltip:AddDoubleLine(L["phrase.mouse.clickLeft"], L["tooltip.right.fixGroups"] .. ":", 1, 1, 1, 1, 1, 0)
	tooltip:AddDoubleLine(" ", A.sortModes:GetDefault().name, 1, 1, 1, 1, 1, 0)
	tooltip:AddLine(" ")
	tooltip:AddDoubleLine(L["phrase.mouse.clickRight"], TOOLTIP_RIGHT_GUI, 1, 1, 1, 1, 1, 0)

	if isMinimapIcon then
		tooltip:AddLine(" ")
		tooltip:AddDoubleLine(L["phrase.mouse.drag"], L["tooltip.right.moveMinimapIcon"], 1, 1, 1, 1, 1, 0)
	end
	if A.DEBUG >= 1 then
		tooltip:AddLine(" ")
		tooltip:AddLine("DEBUG group rebuild stats:")
		A.group:DebugGetStats(function(caller, count) tooltip:AddDoubleLine("  " .. tostring(caller), count) end)
	end
	tooltip:Show()
end

function M:OnDisable()
	M:Refresh()
end

function M:ButtonPress(button)
	handleClick(button)
end

function M:FlashRaidTabButton()
	A.utilGui:OpenRaidTab()
	if R.flashTimer or not A.options.addButtonToRaidTab then
		return
	end
	local count = NUM_FLASHES * 2
	local function flash()
		count = count - 1
		if count % 2 == 0 then
			R.raidTabButton:UnlockHighlight()
		else
			R.raidTabButton:LockHighlight()
		end
		if count > 0 then
			R.flashTimer = A.NewTimer(DELAY_FLASH, flash)
		else
			R.flashTimer = false
		end
	end
	flash()
end

local function setUI(buttonText, iconTexture)
	R.iconLDB.icon = iconTexture
	if R.raidTabButton then
		R.raidTabButton:SetText(L[buttonText])
		if buttonText == "button.fixGroups.text" then
			R.raidTabButton:Enable()
		else
			R.raidTabButton:Disable()
		end
	end
end

function M:Refresh()
	A.fgGui:Refresh()
	if not M:IsEnabled() then
		R.icon:Hide(A.NAME)
		R.raidTabButton:Hide()
		return
	end
	if A.sorter:IsProcessing() then
		if time() % 2 == 0 then
			setUI("button.fixGroups.working.text", CUBE_ICON_0)
		else
			setUI("button.fixGroups.working.text", CUBE_ICON_1)
		end
	elseif A.sorter:IsPaused() then
		setUI("button.fixGroups.paused.text", CUBE_ICON_BW)
	elseif A.util:IsLeader() then
		setUI("button.fixGroups.text", "Interface\\GROUPFRAME\\UI-Group-LeaderIcon")
	elseif A.util:IsLeaderOrAssist() then
		setUI("button.fixGroups.text", "Interface\\GROUPFRAME\\UI-GROUP-ASSISTANTICON")
	else
		setUI("button.fixGroups.text", CUBE_ICON_1)
	end
	if A.options.showMinimapIconAlways or (A.options.showMinimapIconPRN and A.util:IsLeaderOrAssist()) then
		R.icon:Show(A.NAME)
	else
		R.icon:Hide(A.NAME)
	end
	if A.options.addButtonToRaidTab then
		R.raidTabButton:Show()
	else
		R.raidTabButton:Hide()
	end
end