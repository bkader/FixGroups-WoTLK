--- Track the group roster and generate AceEvent messages when things change.
-- Each player in the roster has their own table, with the following keys:
-- @field rindex      internal raid index, volatile
-- @field unitID      raidX, partyX, or player
-- @field isUnknown   true if the server hasn't sent us data for this player yet
-- @field name        player name or "Unknown"
-- @field uniqueName  player name minus realm suffix, unless it's needed to
--                    disambiguate multiple players with the same name
-- @field class       non-localized string, e.g. "PALADIN"
-- @field role        M.ROLE.x constant
-- @field isDamager   true if role is melee, ranged, or unknown
-- @field rank        0: raid member, 1: raid assist, 2: raid lead
-- @field group       1-8
-- @field isSitting   true if inside a non-40-man instance and group=7|8
-- @field zone        localized string, e.g. "Tanaan"
local A, L = unpack(select(2, ...))
local M = A:NewModule("group", "AceEvent-3.0")
A.group = M
M.private = {
	roster = {},
	rosterArray = {},
	prevRoster = {},
	prevRosterArray = {},
	size = 0,
	groupSizes = {0, 0, 0, 0, 0, 0, 0, 0},
	roleCountsTHMRU = {0, 0, 0, 0, 0},
	roleCountsString = false,
	prevRoleCountsString = false,
	recentlyDropped = {count = 0, when = 0},
	builtUniqueNames = false,
	rebuildTimer = false,
	stats = {},
	tmp1 = {},
	tmp2 = {}
}
local R = M.private

local DELAY_REBUILD_FOR_UNKNOWN = 5.0
local DELAY_REBUILD_FOR_EVENT = 1.0

M.ROLE = {TANK = 1, HEALER = 2, MELEE = 3, RANGED = 4, UNKNOWN = 5}
M.ROLE_NAME = {"tank", "healer", "melee", "ranged", "unknown"}
M.EXAMPLE_PLAYER1 = {
	rindex = 4,
	name = L["character.thrall"],
	rank = 1,
	group = 2,
	class = "SHAMAN",
	zone = "Tanaan",
	unitID = "raid4",
	role = M.ROLE.MELEE,
	isDamager = true
}
M.EXAMPLE_PLAYER2 = {
	rindex = 18,
	name = L["character.liadrin"],
	rank = 1,
	group = 5,
	class = "PALADIN",
	zone = "Orgrimmar",
	unitID = "raid18",
	role = M.ROLE.HEALER
}
M.EXAMPLE_PLAYER3 = {
	rindex = 7,
	name = L["character.chen"],
	rank = 1,
	group = 5,
	class = "MONK",
	zone = "Tanaan",
	unitID = "raid7",
	role = M.ROLE.TANK
}

-- Maintain rosterArray to avoid creating up to 40 new tables every time
-- we build the roster. The individual tables are wiped on demand.
-- There will be leftover data whenever a player drops, but it's harmless.
-- The leftover table is not indexed in R.roster and will be re-used if the
-- group refills.
for i = 1, 40 do
	R.rosterArray[i] = {}
	R.prevRosterArray[i] = {}
end

local format, gsub, ipairs, pairs, select, time, tinsert, tostring, unpack, wipe = format, gsub, ipairs, pairs, select, time, tinsert, tostring, unpack, wipe
local GetRealZoneText, GetRaidRosterInfo, UnitClass, UnitExists, UnitIsUnit, UnitName = GetRealZoneText, GetRaidRosterInfo, UnitClass, UnitExists, UnitIsUnit, UnitName
local tconcat = table.concat

local function rebuildTimerDone(event)
	if A.DEBUG >= 1 then
		A.console:Debugf(M, "%s ForceBuildRoster", event)
	end
	R.rebuildTimer = false
	M:ForceBuildRoster(M, event)
end

function M:OnEnable()
	M:RegisterEvent("PARTY_MEMBERS_CHANGED")
	M:RegisterEvent("RAID_ROSTER_UPDATE")
	M:RegisterEvent("PLAYER_ENTERING_WORLD")
	M:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
	M:RegisterEvent("ROLE_CHANGED_INFORM")
	M:RegisterEvent("ZONE_CHANGED")
	M:RegisterEvent("ZONE_CHANGED_INDOORS")
	M:RegisterEvent("ZONE_CHANGED_NEW_AREA")
end

function M:PARTY_MEMBERS_CHANGED(event)
	M:ForceBuildRoster(M, event)
end
M.RAID_ROSTER_UPDATE = M.PARTY_MEMBERS_CHANGED

function M:PLAYER_ENTERING_WORLD(event)
	A.After(1, function() M:ForceBuildRoster(M, event) end)
end

function M:PLAYER_SPECIALIZATION_CHANGED(event, unitID)
	if unitID then
		local name, realm = UnitName(unitID)
		if name and realm and realm ~= "" then
			name = name .. "-" .. gsub(realm, "[ %-]", "")
		end
		if name then
			A.damagerRole:ForgetSession(name)
		end
	end
	if not R.rebuildTimer then
		R.rebuildTimer = A.NewTimer(DELAY_REBUILD_FOR_EVENT, function() rebuildTimerDone(event) end)
	end
end

function M:ROLE_CHANGED_INFORM(event)
	if not R.rebuildTimer then
		R.rebuildTimer = A.NewTimer(DELAY_REBUILD_FOR_EVENT, function() rebuildTimerDone(event) end)
	end
end

function M:ZONE_CHANGED(event)
	M:ForceBuildRoster(M, event)
end

function M:ZONE_CHANGED_INDOORS(event)
	M:ForceBuildRoster(M, event)
end

function M:ZONE_CHANGED_NEW_AREA(event)
	M:ForceBuildRoster(M, event)
end

local function wipeRoster()
	R.size = 0
	for g = 1, 8 do
		R.groupSizes[g] = 0
	end
	for i = 1, 5 do
		R.roleCountsTHMRU[i] = 0
	end
	R.builtUniqueNames = false
	R.prevRoleCountsString = R.roleCountsString
	R.roleCountsString = false

	local tmp = wipe(R.prevRoster)
	R.prevRoster = R.roster
	R.roster = tmp

	tmp = R.prevRosterArray
	R.prevRosterArray = R.rosterArray
	R.rosterArray = tmp
end

local function buildSoloRoster(rindex)
	local p = wipe(R.rosterArray[rindex])
	p.rindex = rindex
	p.unitID = "player"
	p.name = UnitName("player")
	p.rank = 2
	p.group = 1
	p.class = select(2, UnitClass("player"))
	p.zone = GetRealZoneText()
	R.groupSizes[1] = R.groupSizes[1] + 1
	local unitRole = A.GetUnitRole("player")
	if unitRole == "TANK" then
		p.role = M.ROLE.TANK
	elseif unitRole == "HEALER" then
		p.role = M.ROLE.HEALER
	else
		p.role = A.damagerRole:GetDamagerRole(p)
		if p.role ~= M.ROLE.TANK and p.role ~= M.ROLE.HEALER then
			p.isDamager = true
		end
	end
	R.roleCountsTHMRU[p.role] = R.roleCountsTHMRU[p.role] + 1
	R.roster[p.name] = p
end

local function findPartyUnitID(name, nextGuess)
	local unitID
	if name then
		if UnitIsUnit(name, "player") then
			return "player", nextGuess
		end
		for i = 1, 4 do
			unitID = "party" .. i
			if UnitIsUnit(name, unitID) then
				return unitID, nextGuess
			end
		end
	end
	-- The server hasn't sent us this player's name yet!
	-- Getting the party unit ID will take some extra work.
	local existing = wipe(R.tmp1)
	for i = 1, R.size do
		name = GetRaidRosterInfo(i)
		if name then
			for j = nextGuess, 4 do
				unitID = "party" .. j
				if UnitIsUnit(name, unitID) then
					existing[unitID] = true
				end
			end
		end
	end
	for j = nextGuess, 4 do
		unitID = "party" .. j
		if not existing[unitID] then
			return unitID, nextGuess + 1
		end
	end
	A.console:Errorf(M, "invalid party unitIDs")
	return "Unknown" .. nextGuess, nextGuess + 1
end

local function buildRoster()
	wipeRoster()
	local isRaid = A.IsInRaid()
	local areAnyUnknown
	if A.IsInGroup() then
		R.size = A.GetNumGroupMembers()
		local p, _, unitRole
		local firstSittingGroup = A.util:GetFirstSittingGroup()
		local nextGuess = 1
		for i = 1, R.size do
			p = wipe(R.rosterArray[i])
			p.rindex = i
			p.name, p.rank, p.group, _, _, p.class, p.zone, _, _, unitRole = GetRaidRosterInfo(i)
			if isRaid then
				p.unitID = "raid" .. i
			else
				-- The number in party unit IDs (party1, party2, party3, party4)
				-- does NOT correspond to the GetRaidRosterInfo index.
				-- We have to check names to get the proper unit ID.
				p.unitID, nextGuess = findPartyUnitID(p.name, nextGuess)
			end
			if not p.name then
				p.isUnknown = true
				areAnyUnknown = true
				p.name = p.unitID
			end
			if p.group >= firstSittingGroup then
				p.isSitting = true
			end
			R.groupSizes[p.group] = R.groupSizes[p.group] + 1
			unitRole = unitRole or A.GetUnitRole(p.unitID)
			if unitRole == "TANK" or unitRole == "MAINTANK" or unitRole == "MAINASSIST" then
				p.role = M.ROLE.TANK
			elseif unitRole == "HEALER" then
				p.role = M.ROLE.HEALER
			else
				p.role = A.damagerRole:GetDamagerRole(p)
				if p.role ~= M.ROLE.TANK and p.role ~= M.ROLE.HEALER then
					p.isDamager = true
				end
			end
			if not p.isSitting then
				R.roleCountsTHMRU[p.role] = R.roleCountsTHMRU[p.role] + 1
			end
			R.roster[p.name] = p
		end
	else
		R.size = 1
		buildSoloRoster(1)
	end

	-- Build comp string.
	R.roleCountsString = tconcat(R.roleCountsTHMRU, ":")

	-- Schedule rebuild if there are any unknown players.
	if areAnyUnknown then
		if not R.rebuildTimer then
			-- R.rebuildTimer = M:ScheduleTimer(rebuildTimerDone, DELAY_REBUILD_FOR_UNKNOWN, "unknown")
			R.rebuildTimer = A.NewTimer(DELAY_REBUILD_FOR_UNKNOWN, function() rebuildTimerDone("unknown") end)
		end
	elseif R.rebuildTimer then
		if A.DEBUG >= 1 then
			A.console:Debugf(M, "cancelling scheduled ForceBuildRoster")
		end
		if R.rebuildTimer then
			R.rebuildTimer = A.CancelTimer(R.rebuildTimer, true)
		end
	end
end

function M:BuildUniqueNames()
	if R.builtUniqueNames then
		return
	end
	local nameCounts = wipe(R.tmp1)
	local p, onlyName
	-- First pass: build nameCounts.
	for i = 1, R.size do
		p = R.rosterArray[i]
		if not p.isUnknown then
			onlyName = A.util:StripRealm(p.name)
			nameCounts[onlyName] = (nameCounts[onlyName] or 0) + 1
		end
	end
	-- Second pass: set uniqueName for each player.
	for i = 1, R.size do
		p = R.rosterArray[i]
		if not p.isUnknown then
			onlyName = A.util:StripRealm(p.name)
			p.uniqueName = nameCounts[onlyName] > 1 and A.util:NameAndRealm(p.name) or onlyName
		end
	end
	R.builtUniqueNames = true
end

function M:ForceBuildRoster(callerModule, callerEvent)
	if A.DEBUG >= 1 then
		local caller = tostring(callerModule and callerModule:GetName()) .. ":" .. tostring(callerEvent)
		R.stats[caller] = (R.stats[caller] or 0) + 1
	end
	buildRoster()
	if A.DEBUG >= 2 then
		M:DebugPrintRoster()
	end

	local prevGroup, group
	for name, player in pairs(R.roster) do
		if R.prevRoster[name] then
			prevGroup = R.prevRoster[name].group
			group = player.group
			if prevGroup ~= group then
				if A.DEBUG >= 1 then
					A.console:Debugf(M, "PLAYER_CHANGED_GROUP %s %d->%d", name, prevGroup, group)
				end
				M:SendMessage("FIXGROUPS_PLAYER_CHANGED_GROUP", name, prevGroup, group)
			end
		end
	end

	local dropped = 0
	for name, player in pairs(R.prevRoster) do
		if not player.isUnknown and not R.roster[name] then
			if A.DEBUG >= 1 then
				A.console:Debugf(M, "PLAYER_LEFT %s", name)
			end
			-- Message consumers should not modify the player table.
			M:SendMessage("FIXGROUPS_PLAYER_LEFT", player)
			dropped = dropped + 1
		end
	end

	for name, player in pairs(R.roster) do
		if not player.isUnknown and not R.prevRoster[name] then
			if A.DEBUG >= 1 then
				A.console:Debugf(M, "PLAYER_JOINED %s", name)
			end
			-- Message consumers should not modify the player table.
			M:SendMessage("FIXGROUPS_PLAYER_JOINED", player)
		end
	end

	if R.prevRoleCountsString ~= R.roleCountsString then
		if A.DEBUG >= 1 then
			A.console:Debugf(M, "COMP_CHANGED %s -> %s", tostring(R.prevRoleCountsString), R.roleCountsString)
		end
		M:SendMessage("FIXGROUPS_COMP_CHANGED", R.prevRoleCountsString, R.roleCountsString)
	end

	if dropped > 0 then
		local d, now = R.recentlyDropped, time()
		if d.when + 2 < now then
			d.count = 0
		end
		d.when = now
		d.count = d.count + dropped
		if d.count >= 5 then
			-- The group is falling apart: 5 or more players recently dropped,
			-- each within 2 seconds of the last.
			if A.DEBUG >= 1 then
				A.console:Debugf(M, "GROUP_DISBANDING %d", d.count)
			end
			M:SendMessage("FIXGROUPS_GROUP_DISBANDING", d.count)
		end
	end
end

function M:NumSitting()
	local t = 0
	for i = A.util:GetFirstSittingGroup(), 8 do
		t = t + R.groupSizes[i]
	end
	return t
end

function M:GetRoleCountsTHMRU()
	return unpack(R.roleCountsTHMRU)
end

function M:GetComp(style)
	local t, h, m, r, u = unpack(R.roleCountsTHMRU)
	return A.util:FormatGroupComp(style, t, h, m, r, u)
end

function M:GetUnknownNames()
	local names = wipe(R.tmp1)
	local p
	for _, name in ipairs(A.util:SortedKeys(R.roster, R.tmp2)) do
		p = R.roster[name]
		if p.role == M.ROLE.UNKNOWN then
			tinsert(names, A.util:UnitNameWithColor(name))
		end
	end
	return A.util:LocaleTableConcat(names)
end

function M:PrintIfThereAreUnknowns()
	local u = R.roleCountsTHMRU[M.ROLE.UNKNOWN]
	if u > 0 then
		local line = format(L["phrase.waitingOnDataFromServerFor"], M:GetUnknownNames())
		line =
			line ..
			" " .. (u == 1 and L["phrase.assumingRangedForNow.singular"] or L["phrase.assumingRangedForNow.plural"])
		A.console:Print(line)
	end
end

function M:GetSize()
	return R.size
end

function M:GetGroupSize(group)
	return R.groupSizes[group]
end

function M:GetPlayer(name)
	return name and R.roster[name]
end

function M:FindPlayer(name)
	local p = M:GetPlayer(name)
	if p then
		return p
	end
	local onlyName = A.util:StripRealm(name)
	p = M:GetPlayer(onlyName)
	if p then
		return p
	end
	p = M:GetPlayer(A.util:NameAndRealm(name))
	if p then
		return p
	end
	local found
	for i = 1, R.size do
		p = R.rosterArray[i]
		if not p.isUnknown then
			if onlyName == A.util:StripRealm(p.name) then
				if found then
					-- Multiple players match, ambiguous!
					return nil
				end
				found = p
			end
		end
	end
	return found
end

function M:GetRoster()
	return R.roster
end

function M:IsHealer(name)
	return name and R.roster[name] and (R.roster[name].role == M.ROLE.HEALER)
end

function M:IsTank(name)
	return name and R.roster[name] and (R.roster[name].role == M.ROLE.TANK)
end

function M:IsMelee(name)
	return name and R.roster[name] and (R.roster[name].role == M.ROLE.MELEE)
end

function M:IsRanged(name)
	return name and R.roster[name] and (R.roster[name].role == M.ROLE.RANGED)
end

function M:IsDamager(name)
	return name and R.roster[name] and R.roster[name].isDamager and true or false
end

function M:IsInSameZone(name)
	if name and R.roster[name] then
		return R.roster[name].zone == R.roster[UnitName("player")].zone
	end
end

function M:GetUniqueNameParty(unitID)
	local nameCounts = wipe(R.tmp1)
	local partyUnitID, onlyName
	for i = 1, 5 do
		partyUnitID = (i == 5) and "player" or ("party" .. i)
		if UnitExists(partyUnitID) then
			onlyName = A.util:StripRealm(UnitName(partyUnitID))
			nameCounts[onlyName] = (nameCounts[onlyName] or 0) + 1
		end
	end
	onlyName = A.util:StripRealm(UnitName(unitID))
	return nameCounts[onlyName] > 1 and A.util:NameAndRealm(UnitName(unitID)) or onlyName
end

function M:DebugGetStats(addDoubleLine)
	for _, caller in ipairs(A.util:SortedKeys(R.stats, R.tmp1)) do
		addDoubleLine(caller, R.stats[caller])
	end
end

function M:DebugPrintStats()
	A.console:Debugf(M, "stats:")
	M:DebugGetStats(function(caller, count) A.console:DebugMore(M, format("  %s = %d", tostring(caller), count)) end)
end

function M:DebugPrintRoster()
	A.console:Debugf(M, "roster size=%d groupSizes={%s} roleCountsString=[%s]:", R.size, tconcat(R.groupSizes, ","), R.roleCountsString)
	local p, line
	for i = 1, R.size do
		p = R.rosterArray[i]
		line = " "
		for _, k in ipairs(A.util:SortedKeys(p, R.tmp1)) do
			line = line .. " " .. k .. "=" .. tostring(p[k])
		end
		A.console:DebugMore(M, line)
	end
end