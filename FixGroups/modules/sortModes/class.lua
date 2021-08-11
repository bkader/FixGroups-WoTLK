--- Sort by class, keeping each group as homogeneous as possible.
local A, L = unpack(select(2, ...))
local P = A.sortModes
local M = P:NewModule("class", "AceEvent-3.0")
P.class = M
local R = {assignedGroup = {}, classCounts = {}}
M.private = R

local format, ipairs, pairs, sort, wipe = format, ipairs, pairs, sort, wipe
local CLASS_SORT_ORDER = CLASS_SORT_ORDER

function M:OnEnable()
	A.sortModes:Register({
		key = "class",
		name = L["sorter.mode.class"],
		desc = function(t)
			t:AddLine(format("%s:|n%s.", L["tooltip.right.fixGroups"], L["sorter.mode.class"]), 1, 1, 0, true)
			t:AddLine(" ")
			t:AddLine(L["sorter.print.notUseful"], 1, 1, 1, true)
		end,
		isIncludingSitting = true,
		getDefaultCompareFunc = true,
		onSort = M.onSort
	})
end

local function assignClassToGroups(curGroup, curGroupSize, keys, players, class)
	for _, k in ipairs(keys) do
		if (class == "unknown" and not players[k].class) or players[k].class == class then
			R.assignedGroup[k] = curGroup
			curGroupSize = curGroupSize + 1
			if curGroupSize % 5 == 0 then
				curGroup, curGroupSize = curGroup + 1, 0
			end
		end
	end
	R.classCounts[class] = nil
	return curGroup, curGroupSize
end

function M.onSort(sortMode, keys, players)
	-- Perform an initial sort by name.
	sort(keys)

	-- Count the number of players for each class.
	local counts = wipe(R.classCounts)
	for _, p in pairs(players) do
		counts[p.class or "unknown"] = (counts[p.class or "unknown"] or 0) + 1
	end

	-- Assign groups, class-by-class.
	wipe(R.assignedGroup)
	local curGroup, curGroupSize = 1, 0

	-- First pass: classes with exactly 5/10/15/etc. players.
	for _, class in ipairs(CLASS_SORT_ORDER) do
		if counts[class] and counts[class] % 5 == 0 then
			curGroup, curGroupSize = assignClassToGroups(curGroup, curGroupSize, keys, players, class)
		end
	end

	-- Second pass: classes with some other number of players.
	for _, class in ipairs(CLASS_SORT_ORDER) do
		if counts[class] then
			curGroup, curGroupSize = assignClassToGroups(curGroup, curGroupSize, keys, players, class)

			-- Attempt to find another class to share the last group with.
			local found
			-- First pass: try to find a perfect match.
			for _, otherClass in ipairs(CLASS_SORT_ORDER) do
				if not found and counts[otherClass] and curGroupSize + (counts[otherClass] % 5) == 5 then
					found = true
					curGroup, curGroupSize = assignClassToGroups(curGroup, curGroupSize, keys, players, otherClass)
				end
			end
			if not found then
				-- Second and third passes: add in an under-represented class,
				-- then try to find a perfect match again.
				for _, smallClass in ipairs(CLASS_SORT_ORDER) do
					if not found and counts[smallClass] and curGroupSize + counts[smallClass] < 5 then
						found = true
						curGroup, curGroupSize = assignClassToGroups(curGroup, curGroupSize, keys, players, smallClass)
					end
				end
				if found then
					found = false
					for _, otherClass in ipairs(CLASS_SORT_ORDER) do
						if not found and counts[otherClass] and curGroupSize + (counts[otherClass] % 5) == 5 then
							found = true
							curGroup, curGroupSize =
								assignClassToGroups(curGroup, curGroupSize, keys, players, otherClass)
						end
					end
				end
			end
		end
	end

	-- Add leftovers.
	if counts["unknown"] then
		for _, k in ipairs(keys) do
			curGroup, curGroupSize = assignClassToGroups(curGroup, curGroupSize, keys, players, "unknown")
		end
	end

	-- Sort again, this time referencing the assignedGroup table.
	local ga, gb
	sort(keys, function(a, b)
		ga, gb = R.assignedGroup[a], R.assignedGroup[b]
		if ga == gb then
			return a < b
		end
		return ga < gb
	end)
end