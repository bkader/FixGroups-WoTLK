--- Alphabetic sort.
local A, L = unpack(select(2, ...))
local P = A.sortModes
local M = P:NewModule("alpha", "AceEvent-3.0")
P.alpha = M

local format, sort = format, sort

function M:OnEnable()
	A.sortModes:Register({
		key = "alpha",
		name = L["sorter.mode.alpha"],
		desc = function(t)
			t:AddLine(format("%s:|n%s.", L["tooltip.right.fixGroups"], L["sorter.mode.alpha"]), 1, 1, 0, true)
			t:AddLine(" ")
			t:AddLine(L["sorter.print.notUseful"], 1, 1, 1, true)
		end,
		aliases = {"az"},
		getDefaultCompareFunc = true,
		onSort = function(sortMode, keys, players)
			sort(keys, function(a, b) return players[a].name < players[b].name end)
		end
	})
	A.sortModes:Register({
		key = "ralpha",
		name = L["sorter.mode.ralpha"],
		desc = function(t)
			t:AddLine(format("%s:|n%s.", L["tooltip.right.fixGroups"], L["sorter.mode.ralpha"]), 1, 1, 0, true)
			t:AddLine(" ")
			t:AddLine(L["sorter.print.notUseful"], 1, 1, 1, true)
		end,
		aliases = {"za"},
		getDefaultCompareFunc = true,
		onSort = function(sortMode, keys, players)
			sort(keys, function(a, b) return players[a].name > players[b].name end)
		end
	})
end