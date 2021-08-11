--- Stub for nosort.
local A, L = unpack(select(2, ...))
local P = A.sortModes
local M = P:NewModule("nosort", "AceEvent-3.0")
P.nosort = M

function M:OnEnable()
	A.sortModes:Register({
		key = "nosort",
		name = L["sorter.mode.nosort"],
		desc = L["gui.fixGroups.help.nosort"],
		getDefaultCompareFunc = function(sortMode, keys, players)
			return function(a, b)
				return a < b
			end
		end,
		onBeforeStart = function()
			A.console:Print(L["sorter.print.nosortDone"])
			return true
		end
	})
end