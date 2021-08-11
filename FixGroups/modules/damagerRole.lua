--- Determine whether a player in the group is melee or ranged. This is trivial
-- for most cases, but requires inspecting the player if they're a DPS shaman
-- or druid.
local A, L = unpack(select(2, ...))
local M = A:NewModule("damagerRole", "AceEvent-3.0")
A.damagerRole = M
M.private = {
	needToInspect = {},
	sessionCache = {melee = {}, ranged = {}, tank = {}, healer = {}},
	dbGuildCache = false,
	dbNonGuildCache = false,
	dbCleanedUp = false
}
local R = M.private

M.CLASS_DAMAGER_ROLE = {
	WARRIOR = "melee",
	DEATHKNIGHT = "melee",
	PALADIN = "melee",
	PRIEST = "ranged",
	-- SHAMAN
	-- DRUID
	ROGUE = "melee",
	MAGE = "ranged",
	WARLOCK = "ranged",
	HUNTER = "ranged", -- comment out for WoW 7.0 (Legion)
}
-- We have to include tanks and healers to handle people who clear their role.
local SPECID_ROLE = {
	[262] = "ranged", -- Elemental Shaman
	[263] = "melee", -- Enhancement Shaman
	[264] = "healer", -- Restoration Shaman
	[102] = "ranged", -- Balance Druid
	[103] = "melee", -- Feral Druid
	[104] = "tank", -- Bear Druid
	[105] = "healer" -- Restoration Druid
	-- Uncomment Hunter specs for WoW 7.0 (Legion):
	--[253] = "ranged",  -- Beast Mastery Hunter
	--[254] = "ranged",  -- Marksmanship Hunter
	--[255] = "melee",   -- Survival Hunter
}
-- Lazily populated.
local BUFF_ROLE = false
local DELAY_DB_CLEANUP = 20.0
local DB_CLEANUP_GUILD_MAX_AGE_DAYS = 21
local DB_CLEANUP_NONGUILD_MAX_AGE_DAYS = 1.5

local format, ipairs, max, pairs, select, time, tostring = format, ipairs, max, pairs, select, time, tostring
local GetSpellInfo, InCombatLockdown, UnitBuff, UnitClass, UnitExists, UnitIsInMyGuild, UnitIsUnit = GetSpellInfo, InCombatLockdown, UnitBuff, UnitClass, UnitExists, UnitIsInMyGuild, UnitIsUnit

local function cleanDbCache(cache, maxAgeDays)
	local earliest = time() - (60 * 60 * 24 * maxAgeDays)
	local total, removed = 0, 0
	for _, role in ipairs({"melee", "ranged"}) do
		for fullName, when in pairs(cache[role]) do
			total = total + 1
			if when < earliest then
				cache[role][fullName] = nil
				removed = removed + 1
			end
		end
	end
	if A.DEBUG >= 1 then
		A.console:Debugf(M, "cleanDbCache removed %d/%d players older than %d days", removed, total, maxAgeDays)
	end
end

function M:OnEnable()
	M:RegisterEvent("INSPECT_READY")
	M:RegisterMessage("FIXGROUPS_PLAYER_LEFT")
	-- Set local references to dbCaches, creating them if they don't exist.
	if not A.db.faction.damagerRoleGuildCache then
		A.db.faction.damagerRoleGuildCache = {melee = {}, ranged = {}}
	end
	R.dbGuildCache = A.db.faction.damagerRoleGuildCache
	if not A.db.faction.damagerRoleNonGuildCache then
		A.db.faction.damagerRoleNonGuildCache = {melee = {}, ranged = {}}
	end
	R.dbNonGuildCache = A.db.faction.damagerRoleNonGuildCache
	if not R.dbCleanedUp and not InCombatLockdown() then
		R.dbCleanedUp = A.NewTimer(DELAY_DB_CLEANUP, function()
			R.dbCleanedUp = true
			if InCombatLockdown() or A.sorter:IsProcessing() then
				-- Don't worry about trying to reschedule the timer. DB cleanup is
				-- very low priority. Another session will get it done eventually.
				return
			end
			cleanDbCache(R.dbGuildCache, DB_CLEANUP_GUILD_MAX_AGE_DAYS)
			cleanDbCache(R.dbNonGuildCache, DB_CLEANUP_NONGUILD_MAX_AGE_DAYS)
			-- Cleanup from legacy version of addon.
			A.db.faction.dpsRoleCache = nil
		end)
	end
end

function M:INSPECT_READY(event, guid)
	local isValid, name, specId = A.inspect:GetInspectData(guid)
	if not isValid then
		return
	end
	local fullName = R.needToInspect[name]
	local role = SPECID_ROLE[specId]
	if not fullName then
		-- We didn't request this inspect, but let's see if we can make use of it.
		if not role or role == "tank" or role == "healer" or not UnitExists(name) then
			return
		end
		fullName = A.util:NameAndRealm(name)
		if not fullName then
			return
		end
		if A.DEBUG >= 2 then
			A.console:Debugf(M, "unsolicited inspect ready for %s", name)
		end
	end

	-- Remove from needToInspect and add to sessionCache.
	R.needToInspect[name] = nil
	-- Sanity checks.
	if not role then
		A.console:Errorf(M, "unknown specId %s for %s!", specId, fullName)
		return
	elseif not R.sessionCache[role] then
		A.console:Errorf(M, "unknown role %s, specId %s for %s!", tostring(role), specId, fullName)
		return
	end
	for r, t in pairs(R.sessionCache) do
		t[fullName] = (r == role) and true or nil
	end
	if A.DEBUG >= 2 then
		A.console:Debugf(M, "sessionCache add fullName=%s role=%s", fullName, role)
	end

	-- Add to dbCache.
	if (role == "melee" or role == "ranged") and not UnitIsUnit(name, "player") then
		local isGuildmate = UnitIsInMyGuild(name) or R.dbGuildCache.melee[fullName] or R.dbGuildCache.ranged[fullName]
		-- Ensure the player is only in one of the tables.
		R.dbGuildCache["melee"][fullName] = nil
		R.dbGuildCache["ranged"][fullName] = nil
		R.dbNonGuildCache["melee"][fullName] = nil
		R.dbNonGuildCache["ranged"][fullName] = nil
		-- Add to appropriate table.
		local ts = time()
		if isGuildmate then
			R.dbGuildCache[role][fullName] = ts
		else
			R.dbNonGuildCache[role][fullName] = ts
		end
		if A.DEBUG >= 1 then
			A.console:Debugf(M, "dbCache add fullName=%s role=%s isGuildmate=%s", fullName, role, tostring(isGuildmate))
		end
	end

	-- Rebuild roster.
	A.group:ForceBuildRoster(M, event)
end

function M:FIXGROUPS_PLAYER_LEFT(player)
	if not player.isUnknown and player.name then
		if A.DEBUG >= 2 then
			A.console:Debugf(M, "cancelled needToInspect %s", player.name)
		end
		R.needToInspect[player.name] = false
	end
end

local function guessMeleeOrRangedFromBuffs(name)
	if not BUFF_ROLE then
		BUFF_ROLE = {}
		for buff, role in pairs({
			-- [156064] = A.group.ROLE.MELEE, -- Greater Draenic Agility Flask
			-- [156073] = A.group.ROLE.MELEE, -- Draenic Agility Flask
			-- [175456] = A.group.ROLE.MELEE, -- Hyper Augmentation
			-- [156079] = A.group.ROLE.RANGED, -- Greater Draenic Intellect Flask
			-- [156070] = A.group.ROLE.RANGED, -- Draenic Intellect Flask
			-- [175457] = A.group.ROLE.MELEE, -- Focus Augmentation
			[24858] = A.group.ROLE.RANGED -- Moonkin Form
		}) do
			buff = GetSpellInfo(buff)
			if A.DEBUG >= 1 then
				A.console:Debugf(M, "buff=%s role=%s", tostring(buff), role)
			end
			if buff then
				BUFF_ROLE[buff] = role
			end
		end
	end
	if UnitClass(name) == "HUNTER" then
		return
	end
	for buff, role in pairs(BUFF_ROLE) do
		if UnitBuff(name, buff) then
			if A.DEBUG >= 2 then
				A.console:Debugf(M, "guessMeleeOrRangedFromBuffs found name=%s buff=%s role=%s", name, buff, role)
			end
			return role
		end
	end
end

function M:ForgetSession(name)
	local fullName = A.util:NameAndRealm(name)
	if A.DEBUG >= 2 then
		A.console:Debugf(M, "forgetSession %s", fullName)
	end
	for _, c in pairs(R.sessionCache) do
		c[fullName] = nil
	end
end

function M:GetDamagerRole(player)
	-- Check for unambiguous classes.
	if player.class and M.CLASS_DAMAGER_ROLE[player.class] then
		return (M.CLASS_DAMAGER_ROLE[player.class] == "melee") and A.group.ROLE.MELEE or A.group.ROLE.RANGED
	end

	-- Sanity check unit name.
	if player.isUnknown or not player.name or not UnitExists(player.name) then
		return A.group.ROLE.UNKNOWN
	end

	-- Ambiguous class, need to check spec.
	if UnitIsUnit(player.name, "player") then
		local specId = A.GetSpecialization(player.name)
		if specId then
			if SPECID_ROLE[specId] == "melee" then
				return A.group.ROLE.MELEE
			elseif SPECID_ROLE[specId] == "ranged" then
				return A.group.ROLE.RANGED
			elseif SPECID_ROLE[specId] == "tank" then
				return A.group.ROLE.TANK
			elseif SPECID_ROLE[specId] == "healer" then
				return A.group.ROLE.HEALER
			end
		end
		return A.group.ROLE.UNKNOWN
	end

	-- We're looking at another player. Try the session cache first.
	local fullName = A.util:NameAndRealm(player.name)
	if R.sessionCache.melee[fullName] then
		return A.group.ROLE.MELEE
	elseif R.sessionCache.ranged[fullName] then
		return A.group.ROLE.RANGED
	elseif R.sessionCache.tank[fullName] then
		return A.group.ROLE.TANK
	elseif R.sessionCache.healer[fullName] then
		return A.group.ROLE.HEALER
	end

	-- Okay, the session cache failed. Add the player to the inspection request
	-- queue so we can get their true specID.
	R.needToInspect[player.name] = fullName
	A.inspect:Request(player.name)

	-- In the meantime, try two fallbacks to get a tentative answer:
	-- 1) Guess based on the presence of certain buffs; and
	-- 2) Check the db caches, if we've encountered this player before.
	local role = guessMeleeOrRangedFromBuffs(player.name)
	if role then
		return role
	elseif R.dbGuildCache.melee[fullName] or R.dbNonGuildCache.melee[fullName] then
		if A.DEBUG >= 1 then
			A.console:Debugf(M, "dbCache.melee found %s", fullName)
		end
		return A.group.ROLE.MELEE
	elseif R.dbGuildCache.ranged[fullName] or R.dbNonGuildCache.ranged[fullName] then
		if A.DEBUG >= 1 then
			A.console:Debugf(M, "dbCache.ranged found %s", fullName)
		end
		return A.group.ROLE.RANGED
	else
		-- Oh well.
		if A.DEBUG >= 1 then
			A.console:Debugf(M, "unknown role: %s", fullName)
		end
		return A.group.ROLE.UNKNOWN
	end
end