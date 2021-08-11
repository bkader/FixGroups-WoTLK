--- Send inspection requests to the server. Maintain a table of pending
-- requests for players that we can't inspect yet. Pause during combat.
local A, L = unpack(select(2, ...))
local M = A:NewModule("inspect", "AceEvent-3.0")
A.inspect = M
M.private = {
	requests = {},
	timer = false,
	lastNotifyTime = 0
}
local R = M.private

local DELAY_TIMER = 16.0
local DELAY_NOTIFY = 1.0
local DELAY_INSPECT_NEXT = 0.01

local format, gsub, ipairs, pairs, select, time = format, gsub, ipairs, pairs, select, time
local CanInspect, GetPlayerInfoByGUID, InCombatLockdown, NotifyInspect, UnitExists, UnitIsConnected = CanInspect, GetPlayerInfoByGUID, InCombatLockdown, NotifyInspect, UnitExists, UnitIsConnected

function M:OnEnable()
	M:RegisterEvent("INSPECT_READY")
	M:RegisterEvent("PLAYER_REGEN_ENABLED")
end

local function inspectTimerStop(reason)
	if R.timer then
		R.timer:Cancel()
		if A.DEBUG >= 2 then
			A.console:Debugf(M, "timer stop %s", reason)
		end
	end
	R.timer = nil
end

local function inspectTimerTick()
	if InCombatLockdown() then
		inspectTimerStop("combat")
		return
	end
	local now = time()
	local count = 0
	local notifySent
	for name, _ in pairs(R.requests) do
		if not UnitExists(name) then
			R.requests[name] = nil
			if A.DEBUG >= 2 then
				A.console:Debugf(M, "queue remove non-existent %s", name)
			end
		else
			count = count + 1
			if not notifySent and (now > R.lastNotifyTime + DELAY_NOTIFY) and CanInspect(name) and UnitIsConnected(name) and A.group:IsInSameZone(name) then
				notifySent = true
				R.lastNotifyTime = now
				NotifyInspect(name)
				if A.DEBUG >= 1 then
					A.console:Debugf(M, "send %s", name)
				end
			end
		end
	end
	if count == 0 then
		inspectTimerStop("empty")
	elseif not notifySent then
		if A.DEBUG >= 2 then
			A.console:Debugf(M, "waiting count=%d", count)
		end
	end
end

local function isQueueEmpty()
	return A.tLength(R.requests or {}) > 0
end

local function inspectTimerStart()
	inspectTimerStop("sanity check")
	if isQueueEmpty() then
		return
	end
	-- R.timer = M:ScheduleRepeatingTimer(inspectTimerTick, DELAY_TIMER)
	R.timer = M:NewTicker(DELAY_TIMER, inspectTimerTick)
	if A.DEBUG >= 2 then
		A.console:Debug(M, "timer start")
	end
	inspectTimerTick()
end

function M:INSPECT_READY(event, guid)
	local isValid, name = M:GetInspectData(guid)
	if isValid then
		if A.DEBUG >= 1 and R.requests[name] then
			A.console:Debugf(M, "recv %s", name)
		end
		R.requests[name] = nil
	end
	if not InCombatLockdown() then
		-- Use a short delay to allow other modules and addons a chance to
		-- process the INSPECT_READY event.
		-- M:ScheduleTimer(inspectTimerTick, DELAY_INSPECT_NEXT)
		A.NewTimer(DELAY_INSPECT_NEXT, inspectTimerTick)
	end
end

function M:PLAYER_REGEN_ENABLED(event)
	inspectTimerStart()
end

function M:GetInspectData(guid)
	local name, realm = select(6, GetPlayerInfoByGUID(guid))
	local specId = 0
	if name and realm and realm ~= "" then
		name = name .. "-" .. gsub(realm, "[ %-]", "")
	end
	if not name then
		return false, name, specId
	end
	specId = A.GetSpecialization(name)
	if not specId or specId == 0 then
		return false, name, specId
	end
	return true, name, specId
end

function M:Request(name)
	if A.DEBUG >= 2 then
		A.console:Debugf(M, "queue %s %s", (R.requests[name] and "update" or "add"), name)
	end
	R.requests[name] = true
	if not InCombatLockdown() and not R.timer then
		inspectTimerStart()
	end
end

function M:DebugPrintRequests()
	local line = ""
	local count = 0
	for _, k in ipairs(A.util:SortedKeys(R.requests)) do
		line = line .. " " .. k
		count = count + 1
	end
	A.console:Debugf(M, "request count=%d names:%s", count, line)
end