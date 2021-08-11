--- Extract damage/healing meter data from other addons.
local A, L = unpack(select(2, ...))
local M = A:NewModule("meter")
A.meter = M
M.private = {snapshot = {}, tmp1 = {}}
local R = M.private
local H, HA = A.util.Highlight, A.util.HighlightAddon

-- This list is ordered by popularity.
M.SUPPORTED_ADDONS_DISPLAY_ORDER = {"Recount", "Skada", "TinyDPS", "Details!"}
-- This next list is ordered by minimalism. In case the player is running
-- multiple damage meter addons, pick whichever one we find first in this list.
local SUPPORTED_ADDONS_ORDER = {"TinyDPS", "Skada", "Recount", "Details"}
local SUPPORTED_ADDONS = {
	TinyDPS = {obj = "tdps"},
	Skada = {obj = "Skada"},
	Recount = {obj = "Recount"},
	Details = {obj = "Details"}
}
local DETAILS_SEGMENTS = {"overall", "current"}
local EMPTY = {}

local format, ipairs, pairs, select, tinsert, wipe = format, ipairs, pairs, select, tinsert, wipe
local GetUnitName, IsAddOnLoaded = GetUnitName, IsAddOnLoaded
-- GLOBALS: _G, tdps, tdpsPlayer, tdpsPet, Skada, Recount, Details

SUPPORTED_ADDONS.TinyDPS.getSnapshot = function()
	if not tdpsPlayer or not tdpsPet then
		return false
	end
	local found = false
	for _, player in pairs(tdpsPlayer) do
		if player.fight and player.fight[1] then
			found = true
			R.snapshot[player.name] = (player.fight[1].d or 0) + (player.fight[1].h or 0)
			for _, pet in ipairs(player.pet or EMPTY) do
				pet = tdpsPet[pet]
				if pet and pet.fight and pet.fight[1] then
					R.snapshot[player.name] = R.snapshot[player.name] + (pet.fight[1].d or 0) + (pet.fight[1].h or 0)
				end
			end
		end
	end
	return found
end

SUPPORTED_ADDONS.Skada.getSnapshot = function()
	if not Skada.total or not Skada.total.players then
		return false
	end
	-- TODO: revisit this. We want to grab all combatants, not just those in roster
	-- Skada strips the realm name.
	-- For simplicity's sake, we do not attempt to handle cases where two
	-- players with the same name from different realms are in the same raid.
	local fullPlayerNames = wipe(R.tmp1)
	for name, _ in pairs(A.group:GetRoster()) do
		fullPlayerNames[A.util:StripRealm(name)] = name
	end
	local found = false
	for _, p in pairs(Skada.total.players) do
		if fullPlayerNames[p.name] then
			found = true
			R.snapshot[fullPlayerNames[p.name]] = (p.damage or 0) + (p.heal or 0) + (p.healing or 0) + (p.absorb or 0)
		end
	end
	return found
end

SUPPORTED_ADDONS.Recount.getSnapshot = function()
	if not Recount.db2 or not Recount.db2.combatants or not Recount.db2.combatants[GetUnitName("player")] then
		return false
	end
	local found = false
	local c
	-- TODO: redo to grab all combatants, not just those in roster
	for name, _ in pairs(A.group:GetRoster()) do
		c = Recount.db2.combatants[name]
		if c and c.Fights and c.Fights.OverallData then
			found = true
			-- Recount stores healing and absorbs separately internally.
			R.snapshot[name] =
				(c.Fights.OverallData.Damage or 0) + (c.Fights.OverallData.Healing or 0) +
				(c.Fights.OverallData.Absorbs or 0)
		else
			R.snapshot[name] = 0
		end
	end
	-- Merge pet data.
	for _, c in pairs(Recount.db2.combatants) do
		if c.type == "Pet" and c.Fights and c.Fights.OverallData then
			if A.group:GetPlayer(c.Owner) then
				R.snapshot[c.Owner] =
					R.snapshot[c.Owner] + (c.Fights.OverallData.Damage or 0) + (c.Fights.OverallData.Healing or 0) +
					(c.Fights.OverallData.Absorbs or 0)
			end
		end
	end
	return found
end

SUPPORTED_ADDONS.Details.getSnapshot = function()
	-- Details! has a different concept of what "overall" means. Trash and even
	-- boss fights, except previous attempts on the current boss, are excluded by
	-- default. So it's entirely possible that there is a current segment but no
	-- overall segment. We check for both: some data is better than no data.
	-- TODO: revisit this, maybe just total all segments
	local found
	for _, segment in ipairs(DETAILS_SEGMENTS) do
		if not found and Details.GetActor and (Details:GetActor(segment, 1) or Details:GetActor(segment, 2)) then
			found = true
			local damage, healing
			-- TODO: redo to grab all combatants, not just those in roster
			for name, _ in pairs(A.group:GetRoster()) do
				damage = Details:GetActor(segment, 1, name)
				healing = Details:GetActor(segment, 2, name)
				R.snapshot[name] = (damage and damage.total or 0) + (healing and healing.total or 0)
			end
		end
	end
	return true
end

local function calculateAverages()
	local countDamage, totalDamage = 0, 0
	local countHealing, totalHealing = 0, 0
	for name, amount in pairs(R.snapshot) do
		-- Ignore tanks.
		if A.group:IsDamager(name) then
			countDamage = countDamage + 1
			totalDamage = totalDamage + amount
		elseif A.group:IsHealer(name) then
			countHealing = countHealing + 1
			totalHealing = totalHealing + amount
		end
	end
	R.snapshot["_averageDamage"] = (countDamage > 0) and (totalDamage / countDamage) or 0
	R.snapshot["_averageHealing"] = (countHealing > 0) and (totalHealing / countHealing) or 0
end

function M:GetSupportedAddonList()
	local addons = wipe(R.tmp1)
	for _, a in ipairs(M.SUPPORTED_ADDONS_DISPLAY_ORDER) do
		tinsert(addons, HA(a))
	end
	return A.util:LocaleTableConcat(addons, L["word.or"])
end

function M:TestInterop()
	for _, name in ipairs(SUPPORTED_ADDONS_ORDER) do
		if IsAddOnLoaded(name) and _G[SUPPORTED_ADDONS[name].obj] then
			return format(L["meter.print.usingDataFrom"], HA(A.util:GetAddonNameAndVersion(name)))
		end
	end
	return L["meter.print.noAddon"]
end

function M:BuildSnapshot(notifyIfNoAddon)
	wipe(R.snapshot)
	for _, name in ipairs(SUPPORTED_ADDONS_ORDER) do
		if IsAddOnLoaded(name) and _G[SUPPORTED_ADDONS[name].obj] then
			if SUPPORTED_ADDONS[name].getSnapshot() then
				A.console:Printf(L["meter.print.usingDataFrom"], HA(A.util:GetAddonNameAndVersion(name)))
			else
				A.console:Printf(L["meter.print.noDataFrom"], HA(A.util:GetAddonNameAndVersion(name)))
			end
			calculateAverages()
			if A.DEBUG >= 1 then
				M:DebugPrintMeterSnapshot()
			end
			return
		end
	end
	if notifyIfNoAddon then
		A.console:Printf(L["meter.print.noAddon"])
	end
end

function M:GetPlayerMeter(name)
	if not R.snapshot[name] then
		R.snapshot[name] = R.snapshot[A.group:IsHealer(name) and "_averageHealing" or "_averageDamage"] or 0
	end
	return R.snapshot[name]
end

function M:DebugPrintMeterSnapshot()
	A.console:Debug(M, "snapshot:")
	for _, name in ipairs(A.util:SortedKeys(R.snapshot, R.tmp1)) do
		A.console:DebugMore(M, "  " .. name .. "=" .. R.snapshot[name])
	end
end