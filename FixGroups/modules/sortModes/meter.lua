--- Sort by overall damage/healing done.
local A, L = unpack(select(2, ...))
local P = A.sortModes
local M = P:NewModule("meter", "AceEvent-3.0")
P.meter = M

local format, sort = format, sort
local TANK, HEALER = A.group.ROLE.TANK, A.group.ROLE.HEALER

function M:OnEnable()
	A.sortModes:Register({
		key = "meter",
		name = L["sorter.mode.meter"],
		aliases = {"dps"},
		desc = function(t)
			t:AddLine(format("%s: |n%s.", L["tooltip.right.fixGroups"], L["sorter.mode.meter"]), 1, 1, 0)
			t:AddLine(" ")
			t:AddLine(format(L["gui.fixGroups.help.note.meter.1"], A.meter:GetSupportedAddonList()), 1, 1, 1, true)
			t:AddLine(" ")
			t:AddLine(A.meter:TestInterop(), 1, 1, 1, true)
			t:AddLine(" ")
			t:AddLine(L["gui.fixGroups.help.note.meter.2"], 1, 1, 1, true)
		end,
		onStart = function()
			A.meter:BuildSnapshot(true)
		end,
		onSort = function(sortMode, keys, players)
			local defaultCompare = P:GetDefault().getDefaultCompareFunc(sortMode, keys, players)
			local pa, pb
			sort(keys, function(a, b)
				pa, pb = players[a], players[b]
				if pa.role ~= pb.role then
					if pa.role == HEALER or pb.role == HEALER or pa.role == TANK or pb.role == TANK then
						-- Tanks and healers are in their own brackets.
						return defaultCompare(a, b)
					end
				end
				pa, pb = A.meter:GetPlayerMeter(pa.name), A.meter:GetPlayerMeter(pb.name)
				if pa == pb then
					-- Tie, or no data. Fall back to default sort.
					return defaultCompare(a, b)
				end
				return pa > pb
			end)
		end
	})
end