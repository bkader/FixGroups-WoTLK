--- Bench (i.e., move to group 8) all guild members below a certain rank.
local A, L = unpack(select(2, ...))
local P = A.sortModes
local M = P:NewModule("core", "AceEvent-3.0")
P.core = M
local R = {core = {}, nonCore = {}}
M.private = R

local PADDING_PLAYER = {isDummy = true}

local format, gsub, ipairs, max, min, select, sort, strfind, strlower, tinsert, wipe = format, gsub, ipairs, max, min, select, sort, strfind, strlower, tinsert, wipe
local GuildControlGetNumRanks, GuildControlGetRankName, GetGuildInfo, GetRealmName, UnitIsInMyGuild = GuildControlGetNumRanks, GuildControlGetRankName, GetGuildInfo, GetRealmName, UnitIsInMyGuild

local function getGuildFullName()
	local guildName, _, _, realm = GetGuildInfo("player")
	if not guildName then return end
	return format("%s-%s", guildName, gsub(realm or GetRealmName(), "[ %-]", ""))
end

function M:GetCoreRank()
	return A.options.coreRaiderRank[getGuildFullName()]
end

function M:SetCoreRank(rank)
	A.options.coreRaiderRank[getGuildFullName()] = rank
end

function M:GetGuildRanks()
	if not A.db.global.guildRanks then
		A.db.global.guildRanks = {}
	end
	local guildName = getGuildFullName()
	if not guildName then
		return
	end
	if not A.db.global.guildRanks[guildName] then
		A.db.global.guildRanks[guildName] = {}
	end
	return A.db.global.guildRanks[guildName]
end

function M:UpdateGuildRanks()
	local ranks = M:GetGuildRanks()
	if not ranks then
		return
	end
	wipe(ranks)
	for i = 1, GuildControlGetNumRanks() do
		tinsert(ranks, GuildControlGetRankName(i))
	end
	local rank = M:GetCoreRank()
	if rank and rank >= 1 and rank <= #ranks then
		return
	end
	-- New set of guild ranks.
	-- Make an intelligent guess which one is for core raiders.
	-- First pass: highest (i.e. closest to GM) rank containing "core".
	for i = 1, #ranks do
		if strfind(strlower(ranks[i]), "core") then
			M:SetCoreRank(i)
			return
		end
	end
	-- Second pass: lowest (i.e. furthest from GM) rank containing "raid", but
	-- not a keyword indicating the player is a fresh recruit or a non-raider.
	for i = #ranks, 1, -1 do
		local name = strlower(ranks[i])
		if
			strfind(name, "raid") and not strfind(name, "no[nt]") and not strfind(name, "trial") and
				not strfind(name, "new") and
				not strfind(name, "recruit") and
				not strfind(name, "backup") and
				not strfind(name, "ex") and
				not strfind(name, "retire") and
				not strfind(name, "former") and
				not strfind(name, "casual") and
				not strfind(name, "alt")
		 then
			M:SetCoreRank(i)
			return
		end
	end
	-- Otherwise just guess 4, on the theory that many guilds have a rank
	-- structure similar to:
	-- GM > Officer > Veteran > Core > Recruit > Alt > Casual > Muted.
	M:SetCoreRank(max(1, min(4, #ranks - 1)))
end

function M:OnEnable()
	A.sortModes:Register({
		key = "core",
		name = L["sorter.mode.core"],
		desc = function(t)
			t:AddLine(format("%s: |n%s.", L["tooltip.right.fixGroups"], L["sorter.mode.core"]), 1, 1, 0)
			t:AddLine(" ")
			local guildName = GetGuildInfo("player")
			if guildName then
				M:UpdateGuildRanks()
				local rank = M:GetCoreRank()
				t:AddLine(format(L["gui.fixGroups.help.note.core.1"], A.util:HighlightGuild(format("<%s>", guildName)), A.util:HighlightGuild(M:GetGuildRanks()[rank]), rank), 1, 1, 1, true)
				t:AddLine(" ")
				t:AddLine(L["gui.fixGroups.help.note.core.2"], 1, 1, 1, true)
			else
				t:AddLine(format(L["sorter.print.notInGuild"], "core"), 1, 1, 1, true)
			end
		end,
		isIncludingSitting = true,
		onBeforeStart = M.verifyInGuild,
		onStart = M.UpdateGuildRanks,
		onBeforeSort = M.verifyInGuild,
		onSort = M.onSort
	})
end

function M.verifyInGuild()
	if not GetGuildInfo("player") then
		A.console:Printf(L["sorter.print.notInGuild"], "core")
		return true
	end
end

function M.onSort(sortMode, keys, players)
	-- Perform an initial sort.
	sort(keys, P:GetDefault().getDefaultCompareFunc(sortMode, keys, players))

	-- Split keys into core/nonCore.
	-- Subtract 1 because GetGuildInfo is 0-based, but
	-- GuildControlGetRankName is 1-based.
	local maxRank = M:GetCoreRank() - 1
	local core, nonCore = wipe(R.core), wipe(R.nonCore)
	local unitID
	for _, k in ipairs(keys) do
		unitID = players[k].unitID
		if unitID and UnitIsInMyGuild(unitID) and select(3, GetGuildInfo(unitID)) > maxRank then
			tinsert(nonCore, k)
		else
			-- Note that non-guildmates will be considered core.
			-- This is a good thing: if you have to PUG to fill in a key role,
			-- you definitely want them in the raid.
			tinsert(core, k)
		end
	end

	-- Recombine into keys, inserting padding to force nonCore into group 8.
	wipe(keys)
	for _, k in ipairs(core) do
		tinsert(keys, k)
	end
	local k
	for i = 1, (40 - #core - #nonCore) do
		k = format("_pad%02d", i)
		tinsert(keys, k)
		players[k] = PADDING_PLAYER
	end
	for _, k in ipairs(nonCore) do
		tinsert(keys, k)
	end
end