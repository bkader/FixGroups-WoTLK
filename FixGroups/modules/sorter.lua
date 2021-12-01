--- Coordinate player sorting. This usually involves multiple client/server
-- round trips. Handle synchronization in general, including support for
-- pausing/resuming a sort due to combat.
local A, L = unpack(select(2, ...))
local M = A:NewModule("sorter", "AceEvent-3.0")
A.sorter = M
M.private = {
	active = {
		key = false,
		sortMode = false,
		startTime = false,
		stepCount = false,
		timeoutCount = false
	},
	resumeAfterCombat = {},
	resumeSave = {},
	lastComplete = {},
	announced = false,
	timeoutTimer = false
}
local R = M.private

local MAX_STEPS = 30
local MAX_TIMEOUTS = 20
local DELAY_TIMEOUT = 1.0

local floor, format, max, tostring, time, wipe = floor, format, max, tostring, time, wipe
local InCombatLockdown, SendChatMessage = InCombatLockdown, SendChatMessage

local function swap(t, k1, k2)
	local tmp = t[k1]
	t[k1] = t[k2]
	t[k2] = tmp
end

function M:OnEnable()
	M:RegisterEvent("PLAYER_ENTERING_WORLD")
	M:RegisterEvent("PLAYER_REGEN_ENABLED")
	M:RegisterMessage("FIXGROUPS_PLAYER_CHANGED_GROUP")
	M:RegisterMessage("FIXGROUPS_GROUP_DISBANDING")
end

function M:PLAYER_ENTERING_WORLD(event)
	wipe(R.lastComplete)
end

function M:PLAYER_REGEN_ENABLED(event)
	M:ResumeIfPaused()
end

function M:FIXGROUPS_PLAYER_CHANGED_GROUP(event, name, prevGroup, group)
	if M:IsProcessing() and A.sortRaid:DidActionFinish() then
		M:ProcessStep()
	else
		if A.DEBUG >= 2 then
			A.console:Debugf(M, "someone else moved %s %d->%d", name, prevGroup, group)
		end
	end
end

function M:FIXGROUPS_GROUP_DISBANDING(event, numDropped)
	if M:IsProcessing() or M:IsPaused() then
		A.console:Print(L["sorter.print.groupDisbanding"])
		M:Stop()
	end
end

function M:GetKey()
	return R.active.key or R.resumeAfterCombat.key or R.lastComplete.key or ""
end

function M:IsProcessing()
	return R.active.sortMode and true or false
end

function M:IsPaused()
	return R.resumeAfterCombat.sortMode and true or false
end

function M:GetPausedSortMode()
	return format(L["sorter.print.combatPaused"], R.resumeAfterCombat.sortMode.getFullName())
end

function M:CanBegin()
	return not M:IsProcessing() and not M:IsPaused() and not InCombatLockdown() and A.IsInRaid() and
		A.util:IsLeaderOrAssist()
end

function M:Stop()
	A.sortRaid:CancelAction()
	wipe(R.active)
	wipe(R.resumeAfterCombat)
	M:ClearTimeout(true)
	A.buttonGui:Refresh()
end

function M:StopTimedOut()
	A.console:Printf(L["sorter.print.timedOut"], R.active.sortMode.getFullName())
	if A.DEBUG >= 1 then
		A.console:Debugf(M, "steps=%d seconds=%.1f timeouts=%d", R.active.stepCount, (time() - R.active.startTime), R.active.timeoutCount)
	end
	M:Stop()
end

local function getModeToStop()
	if M:IsProcessing() then
		return R.active.sortMode.getFullName()
	elseif M:IsPaused() then
		return R.resumeAfterCombat.sortMode.getFullName()
	end
end

function M:StopManual()
	local mode = getModeToStop()
	if mode then
		M:Stop()
		A.console:Printf(L["sorter.print.manualCancel"], mode)
	else
		A.console:Print(L["sorter.print.notActive"])
	end
end

function M:StopYield(raidOfficerName, message, isCancel)
	local mode = getModeToStop()
	if mode then
		M:Stop()
		A.console:Print(L["sorter.print.raidOfficer." .. (isCancel and "cancel" or "yield")], mode, A.util:UnitNameWithColor(raidOfficerName))
	end
	message = message and strtrim(message) or ""
	if not isCancel and message ~= "" then
		R.lastComplete.key = message
	end
end

function M:StopIfNeeded()
	if not A.util:IsLeaderOrAssist() or not A.IsInRaid() then
		A.console:Print(L["sorter.print.needRank"])
		M:Stop()
		return true
	end
	if InCombatLockdown() then
		swap(R, "resumeSave", "active")
		M:Stop()
		if A.options.resumeAfterCombat then
			swap(R, "resumeAfterCombat", "resumeSave")
			A.console:Print(M:GetPausedSortMode())
			A.buttonGui:Refresh()
		else
			A.console:Printf(L["sorter.print.combatCancelled"], R.resumeSave.sortMode.getFullName())
		end
		return true
	end
	return not M:IsProcessing()
end

function M:Start(sortMode)
	M:Stop()
	if sortMode.onBeforeStart and sortMode.onBeforeStart() then
		return true
	end
	R.active.sortMode = sortMode
	R.active.key = sortMode.getFullKey()
	R.active.stepCount = 0
	R.active.startTime = time()
	if M:StopIfNeeded() then
		return true
	end
	if sortMode.key == "clear1" or sortMode.key == "clear2" then
		-- The whole point of these sort modes is so the user can manually
		-- populate those groups, so make it easy for them.
		A.utilGui:OpenRaidTab()
	end
	A.group:PrintIfThereAreUnknowns()
	if sortMode.onStart then
		sortMode.onStart()
	end
	M:ProcessStep()
end

function M:GetLastSortModeName()
	if R.lastComplete.sortMode then
		return R.lastComplete.sortMode.getFullName()
	end
end

function M:GetLastOrDefaultSortMode()
	return R.lastComplete.sortMode or A.sortModes:GetDefault()
end

function M:ResumeIfPaused()
	if M:IsPaused() and not InCombatLockdown() then
		swap(R, "resumeSave", "resumeAfterCombat")
		wipe(R.resumeAfterCombat)
		A.console:Printf(L["sorter.print.combatResumed"], R.resumeSave.sortMode.getFullName())
		M:Start(R.resumeSave.sortMode)
	end
end

function M:ProcessStep()
	if M:StopIfNeeded() then
		return
	end
	M:ClearTimeout(false)
	if A.sortRaid:BuildDelta(R.active.sortMode) then
		M:Stop()
		return
	end
	if A.sortRaid:IsDeltaEmpty() then
		M:AnnounceComplete()
		M:Stop()
		return
	elseif R.active.stepCount > MAX_STEPS then
		M:StopTimedOut()
		return
	end
	A.sortRaid:ProcessDelta()
	if A.DEBUG >= 2 then
		A.sortRaid:DebugPrintAction()
	end
	if A.sortRaid:IsActionScheduled() then
		R.active.stepCount = R.active.stepCount + 1
		M:ScheduleTimeout()
		A.buttonGui:Refresh()
	else
		M:Stop()
	end
end

function M:ResetAnnounced()
	R.announced = false
end

function M:AnnounceComplete()
	if R.lastComplete.key ~= R.active.key then
		R.announced = false
	end
	if R.active.stepCount == 0 then
		if R.active.sortMode.isSplit then
			A.console:Print(L["sorter.print.alreadySplit"])
		else
			A.console:Printf(L["sorter.print.alreadySorted"], R.active.sortMode.getFullName())
		end
	else
		-- Announce sort mode.
		local msg
		if R.active.sortMode.isSplit then
			msg = format(L["sorter.print.split"], A.sortRaid:GetSplitGroups(R.active.sortMode))
		else
			msg = format(L["sorter.print.sorted"], R.active.sortMode.getFullName())
		end
		-- Announce group comp.
		msg = format("%s %s: %s.", msg, L["phrase.groupComp"], A.group:GetComp(A.util.GROUP_COMP_STYLE.TEXT_FULL))
		-- Announce who we excluded, if any.
		local sitting = A.group:NumSitting()
		if sitting == 1 then
			msg = msg .. " " .. format(L["sorter.print.excludedSitting.singular"], A.util:GetSittingGroupList())
		elseif sitting > 1 then
			msg = msg .. " " .. format(L["sorter.print.excludedSitting.plural"], sitting, A.util:GetSittingGroupList())
		end
		-- Announce to group or to self.
		if A.options.announceChatAlways or (A.options.announceChatPRN and not R.announced) then
			SendChatMessage(format("[%s] %s", A.NAME, msg), A.util:GetGroupChannel())
			R.announced = true
		else
			A.console:Print(msg)
		end
		if A.DEBUG >= 1 then
			A.console:Debugf(M, "steps=%d seconds=%.1f timeouts=%d", R.active.stepCount, (time() - R.active.startTime), R.active.timeoutCount)
		end
	end
	swap(R, "lastComplete", "active")
end

function M:ClearTimeout(resetCount)
	if R.timeoutTimer then
		R.timeoutTimer = A.CancelTimer(R.timeoutTimer, true)
	end
	if resetCount then
		R.active.timeoutCount = false
	end
end

-- Timeouts can happen for a variety of reasons.
-- Example: While the raid leader's original request to move a player is en
-- route to the server, that player leaves the group or is moved to a different
-- group by someone else.
-- Another example: Good old-fashioned lag.
function M:ScheduleTimeout()
	M:ClearTimeout(false)
	R.timeoutTimer = A.NewTimer(DELAY_TIMEOUT, function()
		M:ClearTimeout(false)
		R.active.timeoutCount = (R.active.timeoutCount or 0) + 1
		if A.DEBUG >= 1 then
			A.console:Debugf(M, "timeout %d of %d", R.active.timeoutCount, MAX_TIMEOUTS)
		end
		if R.active.timeoutCount >= MAX_TIMEOUTS then
			M:StopTimedOut()
			return
		end
		A.group:ForceBuildRoster(M, "Timeout")
		M:ProcessStep()
	end)
end