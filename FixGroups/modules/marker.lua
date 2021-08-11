--- Handle setting target marker icons on players, giving tanks assist,
-- setting main tanks, and changing master looter.
local A, L = unpack(select(2, ...))
local M = A:NewModule("marker")
A.marker = M
M.private = {tmp1 = {}, tmp2 = {}, tmp3 = {}}
local R = M.private

local min, sort, tinsert, wipe = min, sort, tinsert, wipe
local GetRaidRosterInfo, GetRaidTargetIndex, IsInInstance, PromoteToAssistant, SetLootMethod, SetRaidTarget, UnitExists, UnitName = GetRaidRosterInfo, GetRaidTargetIndex, IsInInstance, PromoteToAssistant, SetLootMethod, SetRaidTarget, UnitExists, UnitName

function M:FixParty()
	if A:IsInRaid() then
		return
	end
	local party = wipe(R.tmp1)
	local unitID, p
	for i = 1, 5 do
		unitID = (i == 5) and "player" or ("party" .. i)
		if UnitExists(unitID) then
			p = {unitID = unitID, key = A.GetUnitRole(unitID)}
			if p.key == "TANK" then
				p.key = "a"
			elseif p.key == "HEALER" then
				p.key = "b"
			else
				p.key = "c"
			end
			p.key = p.key .. (UnitName(unitID) or "Unknown")
			tinsert(party, p)
		end
	end
	sort(party, function(a, b) return a.key < b.key end)
	local mark
	local allMarked = true
	for i = 1, min(#party, #A.options.partyMarkIcons) do
		mark = A.options.partyMarkIcons[i]
		if mark > 0 and mark <= 8 and GetRaidTargetIndex(party[i].unitID) ~= mark then
			SetRaidTarget(party[i].unitID, mark)
			allMarked = false
		end
	end
	if allMarked then
		-- Clear marks.
		for i = 1, min(#party, #A.options.partyMarkIcons) do
			SetRaidTarget(party[i].unitID, 0)
		end
	end
end

function M:FixRaid(isRequestFromAssist)
	if not A.util:IsLeaderOrAssist() or not A:IsInRaid() then
		return
	end

	local marks = wipe(R.tmp1)
	local unsetTanks = wipe(R.tmp2)
	local setNonTanks = wipe(R.tmp3)
	local name, rank, subgroup, online, raidRole, isML, _, unitID, unitRole
	for i = 1, A.GetNumGroupMembers() do
		name, rank, subgroup, _, _, _, _, online, _, raidRole, isML = GetRaidRosterInfo(i)
		if A.util:IsLeader() and A.options.fixOfflineML and isML and not online then
			SetLootMethod("master", "player")
		end
		if subgroup >= 1 and subgroup < A.util:GetFirstSittingGroup() then
			name = name or "Unknown"
			unitID = "raid" .. i
			unitRole = A.GetUnitRole(unitID)
			if A:IsInRaid() and A.util:IsLeader() and A.options.tankAssist and (unitRole == "TANK" or isML) and (not rank or rank < 1) then
				PromoteToAssistant(unitID)
			end
			if not isRequestFromAssist and A.options.clearRaidMarks and unitRole ~= "TANK" then
				if GetRaidTargetIndex(unitID) then
					SetRaidTarget(unitID, 0)
				end
			end
			if unitRole == "TANK" then
				-- Don't mark tanks right away. We need to assign them alphabetically.
				tinsert(marks, {key = name, unitID = unitID})
				if raidRole ~= "MAINTANK" then
					-- Can't call protected func: SetPartyAssignment("MAINTANK", unitID)
					tinsert(unsetTanks, A.util:UnitNameWithColor(unitID))
				end
			elseif raidRole == "MAINTANK" then
				-- Can't call protected func: SetPartyAssignment(nil, unitID)
				tinsert(setNonTanks, A.util:UnitNameWithColor(unitID))
			end
		end
	end

	if isRequestFromAssist then
		return
	end

	if A.options.tankMark then
		sort(marks, function(a, b) return a.key < b.key end)
		local mark
		for i = 1, min(#marks, #A.options.tankMarkIcons) do
			mark = A.options.tankMarkIcons[i]
			if mark > 0 and mark <= 8 and GetRaidTargetIndex(marks[i].unitID) ~= mark then
				SetRaidTarget(marks[i].unitID, mark)
			end
		end
	end

	if A.options.tankMainTankAlways or (A.options.tankMainTankPRN and IsInInstance()) then
		local bad
		if #unsetTanks > 0 then
			bad = true
			if #unsetTanks == 1 then
				A.console:Printf(L["marker.print.needSetMainTank.singular"], A.util:LocaleTableConcat(unsetTanks))
			else
				A.console:Printf(L["marker.print.needSetMainTank.plural"], A.util:LocaleTableConcat(unsetTanks))
			end
		end
		if #setNonTanks > 0 then
			bad = true
			if #setNonTanks == 1 then
				A.console:Printf(L["marker.print.needClearMainTank.singular"], A.util:LocaleTableConcat(setNonTanks))
			else
				A.console:Printf(L["marker.print.needClearMainTank.plural"], A.util:LocaleTableConcat(setNonTanks))
			end
		end
		if bad then
			if A.options.openRaidTabPRN then
				A.console:Print(L["marker.print.useRaidTab"])
				A.utilGui:OpenRaidTab()
				return
			end
			A.console:Printf(L["marker.print.openRaidTab"], A.util:Highlight(A.util:GetBindingKey("TOGGLESOCIAL", "O")))
		end
	end
end