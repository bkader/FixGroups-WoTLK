--- Tanks > Healers > Melee > Ranged.
local A, L = unpack(select(2, ...))
local P = A.sortModes
local M = P:NewModule("clearSkip", "AceEvent-3.0")
P.clearSkip = M

local format, pairs, wipe = format, pairs, wipe

local function isRaidTooBig(sortMode, groupOffset, skipFirstGroups)
	-- Count the number of players eligible for sorting.
	local numPlayers = 0
	for _, p in pairs(A.group:GetRoster()) do
		if not p.isSitting and p.group > skipFirstGroups then
			numPlayers = numPlayers + 1
		end
	end
	-- Too many?
	local maxPlayers = (A.util:GetFirstSittingGroup() - groupOffset - 1) * 5
	if A.DEBUG >= 2 then
		A.console:Debugf(M, "sortMode=%s groupOffset=%d skipFirstGroups=%d numPlayers=%d maxPlayers=%d", sortMode, groupOffset, skipFirstGroups, numPlayers, maxPlayers)
	end
	if numPlayers > maxPlayers then
		A.console:Printf(L["sorter.print.tooLarge"], A.util:Highlight(sortMode))
		return true
	end
end

local function getDescFunc(key)
	return function(t)
		t:AddLine(L["gui.fixGroups.help." .. key], 1, 1, 0, true)
		t:AddLine(" ")
		t:AddLine(L["gui.fixGroups.help.sort"], 1, 1, 0, true)
		t:AddLine(" ")
		t:AddLine(format(L["gui.fixGroups.help.note.defaultMode"], A.util:Highlight(A.sortModes:GetDefault().name)), 1, 1, 1, true)
		t:AddLine(" ")
		t:AddLine(L["gui.fixGroups.help.note.clearSkip"], 1, 1, 1, true)
	end
end

function M:OnEnable()
	A.sortModes:Register({
		key = "clear1",
		name = L["sorter.mode.clear1"],
		desc = getDescFunc("clear1"),
		aliases = {"c1"},
		doesNameIncludesDefault = true,
		groupOffset = 1,
		onBeforeStart = function()
			return isRaidTooBig("clear1", 1, 0)
		end,
		onBeforeSort = function()
			return isRaidTooBig("clear1", 1, 0)
		end
	})
	A.sortModes:Register({
		key = "clear2",
		name = L["sorter.mode.clear2"],
		desc = getDescFunc("clear2"),
		aliases = {"c2"},
		doesNameIncludesDefault = true,
		groupOffset = 2,
		onBeforeStart = function()
			return isRaidTooBig("clear2", 2, 0)
		end,
		onBeforeSort = function()
			return isRaidTooBig("clear2", 2, 0)
		end
	})
	A.sortModes:Register({
		key = "skip1",
		name = L["sorter.mode.skip1"],
		desc = getDescFunc("skip1"),
		aliases = {"s1"},
		doesNameIncludesDefault = true,
		groupOffset = 1,
		skipFirstGroups = 1,
		onBeforeStart = function()
			return isRaidTooBig("skip1", 1, 1)
		end,
		onBeforeSort = function()
			return isRaidTooBig("skip1", 1, 1)
		end
	})
	A.sortModes:Register({
		key = "skip2",
		name = L["sorter.mode.skip2"],
		desc = getDescFunc("skip2"),
		aliases = {"s2"},
		doesNameIncludesDefault = true,
		groupOffset = 2,
		skipFirstGroups = 2,
		onBeforeStart = function()
			return isRaidTooBig("skip2", 2, 2)
		end,
		onBeforeSort = function()
			return isRaidTooBig("skip2", 2, 2)
		end
	})
end