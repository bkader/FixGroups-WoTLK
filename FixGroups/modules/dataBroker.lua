--- Define a Data Broker Object (a.k.a. LDB plugin) named Group Comp.
local A, L = unpack(select(2, ...))
local M = A:NewModule("dataBroker", "AceEvent-3.0")
A.dataBroker = M
M.private = {groupComp = false}
local R = M.private
local H, HA, HD = A.util.Highlight, A.util.HighlightAddon, A.util.HighlightDim

local NOT_IN_GROUP = HD(L["dataBroker.groupComp.notInGroup"])

local format, tostring = format, tostring
local IsAddOnLoaded, IsShiftKeyDown = IsAddOnLoaded, IsShiftKeyDown
-- GLOBALS: C_LFGList, LibStub

local function groupCompOnClick(frame, button)
	if A.DEBUG >= 2 then
		A.console:Debugf(M, "groupCompOnClick frame=%s button=%s", tostring(frame), tostring(button))
	end
	if IsShiftKeyDown() then
		if button == "RightButton" then
			A.utilGui:InsertText(A.group:GetComp(A.util.GROUP_COMP_STYLE.VERBOSE))
		else
			A.utilGui:InsertText(A.group:GetComp(A.util.GROUP_COMP_STYLE.TEXT_FULL))
		end
	else
		if button == "RightButton" then
			A.fgGui:Toggle()
		else
			A.utilGui:ToggleRaidTab()
		end
	end
end

local function groupCompOnTooltipShow(tooltip)
	if A.DEBUG >= 1 then
		A.console:Debugf(M, "groupCompOnTooltipShow tooltip=%s", tostring(tooltip))
	end
	if A:IsInGroup() then
		local t, h, m, r, u = A.group:GetRoleCountsTHMRU()
		tooltip:AddDoubleLine(format("%s (%s):", L["phrase.groupComp"], (A:IsInRaid() and L["word.raid"] or L["word.party"])), A.util:FormatGroupComp(A.util.GROUP_COMP_STYLE.TEXT_SHORT, t, h, m, r, u), 1, 1, 0, 1, 1, 0)
		tooltip:AddLine(" ")
		tooltip:AddDoubleLine(A.util:GetRoleIcon("TANK") .. " " .. L["word.tank.plural"], tostring(t), 1, 1, 1, 1, 1, 0)
		tooltip:AddDoubleLine(A.util:GetRoleIcon("HEALER") .. " " .. L["word.healer.plural"], tostring(h), 1, 1, 1, 1, 1, 0)
		tooltip:AddDoubleLine(A.util:GetRoleIcon("DAMAGER") .. " " .. L["word.damager.plural"], tostring(m + r + u), 1, 1, 1, 1, 1, 0)
		local indent = A.util:BlankInline(8, A.options.roleIconSize) .. "    "
		tooltip:AddDoubleLine(indent .. L["word.melee.plural"], HD(tostring(m)), 1, 1, 1, 1, 1, 0)
		tooltip:AddDoubleLine(indent .. L["word.ranged.plural"], HD(tostring(r)), 1, 1, 1, 1, 1, 0)
		if u > 0 then
			tooltip:AddDoubleLine(indent .. L["word.unknown.plural"], HD(tostring(u)), 1, 1, 1, 1, 1, 0)
		end
		tooltip:AddDoubleLine(A.util:BlankInline(8, A.options.roleIconSize) .. " " .. L["word.total"], tostring(t + h + m + r + u), 1, 1, 1, 1, 1, 0)
		if u > 0 then
			tooltip:AddLine(" ")
			tooltip:AddLine(format(L["phrase.waitingOnDataFromServerFor"], A.group:GetUnknownNames()), 1, 1, 1, true)
		end
		local sitting = A.group:NumSitting()
		if sitting > 0 then
			tooltip:AddLine(" ")
			tooltip:AddDoubleLine(format(L["dataBroker.groupComp.sitting"], A.util:GetSittingGroupList()), HD(tostring(sitting)), 1, 1, 1, 1, 1, 0)
		end
	else
		tooltip:AddDoubleLine(format("%s:", L["phrase.groupComp"]), NOT_IN_GROUP, 1, 1, 0, 1, 1, 0)
	end
	-- FIXME PLEASE
	-- if C_LFGList.GetActiveEntryInfo() then
	-- 	tooltip:AddLine(" ")
	-- 	tooltip:AddLine(L["dataBroker.groupComp.groupQueued"], 0, 1, 0)
	-- end
	tooltip:AddLine(" ")
	tooltip:AddDoubleLine(format("%s:", L["phrase.mouse.clickLeft"]), L["dataBroker.groupComp.toggleRaidTab"], 1, 1, 1, 1, 1, 0)
	tooltip:AddDoubleLine(format("%s:", L["phrase.mouse.clickRight"]), format(L["dataBroker.groupComp.toggleAddonWindow"], A.NAME), 1, 1, 1, 1, 1, 0)
	tooltip:AddDoubleLine(format("%s:", L["phrase.mouse.shiftClickLeft"]), L["dataBroker.groupComp.linkShortComp"], 1, 1, 1, 1, 1, 0)
	tooltip:AddDoubleLine(format("%s:", L["phrase.mouse.shiftClickRight"]), L["dataBroker.groupComp.linkFullComp"], 1, 1, 1, 1, 1, 0)
	tooltip:Show()
end

function M:OnEnable()
	-- See also: the buttonGui module, which defines another LDB DataObject for the
	-- minimap icon (type="launcher").
	local LDB = LibStub:GetLibrary("LibDataBroker-1.1")
	R.groupComp = {
		type = "data source",
		text = NOT_IN_GROUP,
		label = L["phrase.groupComp"],
		OnClick = groupCompOnClick,
		OnTooltipShow = groupCompOnTooltipShow
	}
	if not LDB:NewDataObject(R.groupComp.label, R.groupComp) then
		-- Some other addon has already registered the name. Disambiguate.
		LDB:NewDataObject(format("%s (%s)", R.groupComp.label, A.NAME), R.groupComp)
	end
	M:RegisterMessage("FIXGROUPS_COMP_CHANGED")
	M:RefreshGroupComp()
end

function M:FIXGROUPS_COMP_CHANGED(message)
	M:RefreshGroupComp()
end

function M:RefreshGroupComp()
	if A:IsInGroup() and A.group:GetSize() > 0 then
		R.groupComp.text = A.group:GetComp(A.options.dataBrokerGroupCompStyle)
	else
		R.groupComp.text = NOT_IN_GROUP
	end
end