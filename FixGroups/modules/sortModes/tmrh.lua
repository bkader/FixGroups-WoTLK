--- Tanks > Melee > Ranged > Healers.
local A, L = unpack(select(2, ...))
local P = A.sortModes
local M = P:NewModule("tmrh", "AceEvent-3.0")
P.tmrh = M

-- Indexes correspond to A.group.ROLE constants (THMRU).
local ROLE_KEY = {1, 4, 2, 3, 3}
local PADDING_PLAYER = {role = 5, isDummy = true}

local format, sort, tinsert = format, sort, tinsert

local function getDefaultCompareFunc(sortMode, keys, players)
	local ra, rb
	return function(a, b)
		ra, rb = ROLE_KEY[players[a].role or 5] or 4, ROLE_KEY[players[b].role or 5] or 4
		if ra == rb then
			return a < b
		end
		return ra < rb
	end
end

function M:OnEnable()
	A.sortModes:Register({
		key = "tmrh",
		name = L["sorter.mode.tmrh"],
		desc = format("%s:|n%s.", L["tooltip.right.fixGroups"], L["sorter.mode.tmrh"]),
		getDefaultCompareFunc = getDefaultCompareFunc,
		onBeforeSort = function(sortMode, keys, players)
			if sortMode.isIncludingSitting then return end
			-- Insert dummy players for padding to keep the healers in the last group.
			local fixedSize = A.util:GetFixedInstanceSize()
			if fixedSize then
				local k
				while #keys < fixedSize do
					k = format("_pad%02d", #keys)
					tinsert(keys, k)
					players[k] = PADDING_PLAYER
				end
			end
		end,
		onSort = function(sortMode, keys, players)
			sort(keys, getDefaultCompareFunc(sortMode, keys, players))
		end
	})
end