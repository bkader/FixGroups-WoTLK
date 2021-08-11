--- Modify group-related system messages to make them more informative.
local A, L = unpack(select(2, ...))
local M = A:NewModule("modJoinLeave", "AceHook-3.0")
A.modJoinLeave = M

local format, gsub, pairs, strmatch, tostring = format, gsub, pairs, strmatch, tostring
local ChatFrame_AddMessageEventFilter, ChatFrame_RemoveMessageEventFilter, UnitName = ChatFrame_AddMessageEventFilter, ChatFrame_RemoveMessageEventFilter, UnitName
local HEALER, INLINE_HEALER_ICON, INLINE_TANK_ICON, ERR_RAID_YOU_JOINED, TANK = HEALER, INLINE_HEALER_ICON, INLINE_TANK_ICON, ERR_RAID_YOU_JOINED, TANK
local _G = _G

-- Lazily built.
local PATTERNS = false

local function matchMessage(message)
	if not PATTERNS then
		local function makePattern(s)
			-- Change a formatting string into a string matching pattern.
			-- Example: "%s joins the party." becomes "([^%s]+) joins the party%."
			s = format(_G[s], "!NAME!", "!ROLE!", "!NAME!")
			s = gsub(s, "([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
			s = gsub(s, "!NAME!", "([^%%s]+)")
			s = gsub(s, "!ROLE!", "(%|T[^%%s]+%|t [^%%s]+)")
			return s
		end
		PATTERNS = {
			[makePattern("ERR_JOINED_GROUP_S")] = {isJoin = true},
			[makePattern("ERR_LEFT_GROUP_S")] = {isLeave = true},
			[makePattern("ERR_RAID_MEMBER_ADDED_S")] = {isJoin = true},
			[makePattern("ERR_RAID_MEMBER_REMOVED_S")] = {isLeave = true},
			[makePattern("ERR_INSTANCE_GROUP_ADDED_S")] = {isJoin = true},
			[makePattern("ERR_INSTANCE_GROUP_REMOVED_S")] = {isLeave = true},
			[makePattern("ROLE_CHANGED_INFORM")] = {isRoleChange = true},
			[makePattern("ROLE_CHANGED_INFORM_WITH_SOURCE")] = {isRoleChange = true},
			[makePattern("ROLE_REMOVED_INFORM")] = {isRoleChange = true, noRole = true},
			[makePattern("ROLE_REMOVED_INFORM_WITH_SOURCE")] = {isRoleChange = true, noRole = true}
		}
	end
	if message == ERR_RAID_YOU_JOINED then
		-- When a player first joins the raid, there will be a lot of unknown roles
		-- out there until the server has had a chance to send us all the data.
		-- Set the shortComp flag to just report the basic "T/H/D" comp, rather
		-- than the full "T/H/D (M+R+U)".
		return UnitName("player"), nil, nil, {isJoin = true, shortComp = true}
	end
	local matchName, matchRole, matchActor
	for pattern, matchInfo in pairs(PATTERNS) do
		matchName, matchRole, matchActor = strmatch(message, pattern)
		if matchName then
			return matchName, matchRole, matchActor, matchInfo
		end
	end
end

function M:Modify(message, previewComp, previewPlayer)
	-- Exit early if no modifications enabled in options.
	local found
	for _, value in pairs(A.options.sysMsg) do
		if value then
			found = true
		end
	end
	if not found then
		return message
	end
	if A.DEBUG >= 2 then
		A.console:Debugf(M, "message=[%s]", A.util:Escape(message))
	end

	-- Verify that this is a message we should modify.
	local matchName, matchRole, matchActor, matchInfo = matchMessage(message)
	if not matchName then
		return message
	end
	if A.DEBUG >= 1 then
		A.console:Debugf(M, "matchName=%s matchRole=%s matchActor=%s isJoin=%s isLeave=%s isRoleChange=%s noRole=%s", tostring(matchName), tostring(matchRole), tostring(matchActor), tostring(matchInfo.isJoin), tostring(matchInfo.isLeave), tostring(matchInfo.isRoleChange), tostring(matchInfo.noRole))
	end

	-- Get player from roster.
	local player
	if previewPlayer then
		player = previewPlayer
	else
		if not matchInfo.isLeave then
			A.group:ForceBuildRoster(M, "joined/roleChanged")
		end
		player = A.group:FindPlayer(matchName)
		if matchInfo.isLeave then
			A.group:ForceBuildRoster(M, "left")
		-- Despite the rebuild, it's still safe to keep using the player reference
		-- for the rest of this method.
		end
	end

	local namePattern = gsub(matchName, "%-", "%%-")

	if (A.options.sysMsg.roleName or A.options.sysMsg.roleIcon) and not matchInfo.noRole then
		local role, roleIcon
		-- Determine role.
		if matchInfo.isRoleChange then
			-- Alas, we have to parse the actual text for role changes.
			--
			-- We can't do a ForceBuildRoster to get the new role because the new
			-- role data isn't there yet.
			--
			-- The ROLE_CHANGED_INFORM event includes the new role data, but it
			-- doesn't fire until AFTER the system message.
			if matchRole == INLINE_TANK_ICON .. " " .. TANK then
				role = "tank"
			elseif matchRole == INLINE_HEALER_ICON .. " " .. HEALER then
				role = "healer"
			else
				role = false
			end
		else
			role = player and A.group.ROLE_NAME[player.role]
		end
		if not role or role == "unknown" or role == "damager" then
			if player and player.class then
				role = A.damagerRole.CLASS_DAMAGER_ROLE[player.class]
			end
			if not role or role == "unknown" then
				role = "damager"
			end
		end
		-- Determine roleIcon, and localize role.
		if role == "tank" then
			roleIcon = A.util:GetRoleIcon("TANK")
		elseif role == "healer" then
			roleIcon = A.util:GetRoleIcon("HEALER")
		else
			roleIcon = A.util:GetRoleIcon("DAMAGER")
		end
		role = L["word." .. role .. ".singular"]
		-- Combine roleIcon and role into role.
		if roleIcon and A.options.sysMsg.roleIcon then
			if role and A.options.sysMsg.roleName then
				if matchInfo.isRoleChange then
					role = format("%s %s", roleIcon, role)
				else
					role = format("%s (%s)", roleIcon, role)
				end
			else
				role = roleIcon
			end
		elseif role and A.options.sysMsg.roleName and not matchInfo.isRoleChange then
			role = format("(%s)", role)
		end
		-- Insert/substitute role into the message.
		if role then
			if matchInfo.isRoleChange then
				message = gsub(message, gsub(matchRole, "([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1"), role, 1)
			else
				message = gsub(message, namePattern, format("%s %s", matchName, role), 1)
			end
		end
	end

	if A.options.sysMsg.classColor then
		local color = A.util:ClassColor(player and player.class)
		message = gsub(message, namePattern, format("|c%s%s|r", color, matchName), 1)
	end

	if A.options.sysMsg.groupComp and not matchInfo.isRoleChange then
		-- See comment on role for the reason why we exclude the comp for role
		-- change system messages.
		local newComp =
			previewComp or
			A.group:GetComp(
				matchInfo.shortComp and A.util.GROUP_COMP_STYLE.TEXT_SHORT or A.util.GROUP_COMP_STYLE.TEXT_FULL
			)
		if A.options.sysMsg.groupCompHighlight then
			if matchInfo.isJoin then
				message = format("%s |cff00ff00%s.|r", message, newComp)
			elseif matchInfo.isLeave then
				message = format("%s |cff999999%s.|r", message, newComp)
			else
				message = format("%s %s.", message, newComp)
			end
		else
			message = format("%s %s.", message, newComp)
		end
	end

	return message
end

function M:FilterSystemMsg(event, message, ...)
	return false, M:Modify(message), ...
end

-- missing api function
local ChatFrame_DisplaySystemMessageInPrimary = _G.ChatFrame_DisplaySystemMessageInPrimary
if not ChatFrame_DisplaySystemMessageInPrimary then
	ChatFrame_DisplaySystemMessageInPrimary = function(messageTag)
		local info = ChatTypeInfo["SYSTEM"];
		DEFAULT_CHAT_FRAME:AddMessage(messageTag, info.r, info.g, info.b, info.id);
	end
	_G.ChatFrame_DisplaySystemMessageInPrimary = ChatFrame_DisplaySystemMessageInPrimary
end

function M:OnInitialize()
	ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", M.FilterSystemMsg)
	M:RawHook("ChatFrame_DisplaySystemMessageInPrimary", true)
end

function M:ChatFrame_DisplaySystemMessageInPrimary(message, ...)
	return M.hooks.ChatFrame_DisplaySystemMessageInPrimary(M:Modify(message), ...)
end