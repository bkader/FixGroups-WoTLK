--- Handle exchanging addon messages with other players using WoW's
-- CHAT_MSG_ADDON channels.
local A, L = unpack(select(2, ...))
local M = A:NewModule("addonChannel", "AceEvent-3.0")
A.addonChannel = M
M.private = {broadcastVersionTimer = false, newerVersion = false}
local R = M.private
local H, HA = A.util.Highlight, A.util.HighlightAddon

local strsplit, strtrim = strsplit, strtrim
local SendAddonMessage, UnitExists, UnitIsRaidOfficer, UnitName = SendAddonMessage, UnitExists, UnitIsRaidOfficer, UnitName

local PREFIX = "FIXGROUPS"
local DELAY_BROADCAST_VERSION = 15.5
local VERSION_STRING
do
	local r, i = 0, 0
	for part in gmatch(A.VERSION_RELEASED, "[%d]+") do
		if i < 3 then
			r = r + tonumber(part) * (i < 1 and 1000 or 1) * (i < 2 and 1000 or 1)
			i = i + 1
		end
	end
	VERSION_STRING = format("%d:%s", r, A.VERSION_RELEASED)
end

function M:OnEnable()
	M:RegisterEvent("CHAT_MSG_ADDON")
	M:RegisterMessage("FIXGROUPS_PLAYER_JOINED")
end

function M:CHAT_MSG_ADDON(event, prefix, message, channel, sender)
	if prefix ~= PREFIX or not sender then
		return
	end
	if not UnitExists(sender) then
		sender = A.util:StripRealm(sender)
	end
	if A.DEBUG >= 1 then
		A.console:Debugf(M, "CHAT_MSG_ADDON prefix=%s channel=%s sender=%s message=%s", prefix, channel, (sender == UnitName("player")) and sender or H(sender), message)
	end
	if sender == UnitName("player") then
		return
	end
	local cmd
	cmd, message = strsplit(":", message, 2)
	if cmd == "v" and not R.newerVersion and A.options.notifyNewVersion then
		if message and (message > VERSION_STRING) then
			message, R.newerVersion = strsplit(":", message, 2)
			if R.newerVersion and strtrim(R.newerVersion) ~= "" then
				A.console:Printf(L["addonChannel.print.newerVersion"], A.NAME, H(A.util:Escape(R.newerVersion)), A.VERSION_PACKAGED)
			else
				R.newerVersion = false
			end
		end
	elseif cmd == "f" and A.IsInRaid() and UnitIsRaidOfficer(sender) then
		if message == "cancel" then
			A.sorter:StopYield(sender, message, true)
		else
			A.sorter:StopYield(sender, message, false)
			if A.util:IsLeader() then
				A.marker:FixRaid(true)
			end
		end
	end
end

function M:FIXGROUPS_PLAYER_JOINED(event, player)
	if not R.broadcastVersionTimer then
		R.broadcastVersionTimer = A.NewTimer(DELAY_BROADCAST_VERSION, function()
			if R.broadcastVersionTimer then
				R.broadcastVersionTimer = A.CancelTimer(R.broadcastVersionTimer, true)
			end
			M:Broadcast("v:" .. VERSION_STRING)
		end)
	end
end

function M:Broadcast(message)
	if A.IsInGroup() then
		SendAddonMessage(PREFIX, message, A.util:GetGroupChannel())
	end
end