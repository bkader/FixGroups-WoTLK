--- Repeat the last sort mode.
local A, L = unpack(select(2, ...))
local P = A.sortModes
local M = P:NewModule("last", "AceEvent-3.0")
P.last = M

local format = format

function M:OnEnable()
	A.sortModes:Register({
		key = "last",
		name = L["sorter.mode.last"],
		aliases = {"again", "repeat", "^", '"', "previous", "prev"},
		desc = function(t)
			local last = A.sorter:GetLastSortModeName()
			if last then
				last = format("%s: %s.", L["sorter.print.last"], A.util:Highlight(last))
			else
				last = L["sorter.print.last"] .. "."
			end
			t:AddLine(last, 1, 1, 0, true)
		end,
		onBeforeStart = function()
			A.console:Errorf(M, "this func should never be called - the fgCommand module should be handling this sort mode")
			return true
		end
	})
end