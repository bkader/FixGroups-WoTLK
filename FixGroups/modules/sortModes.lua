--- Sort mode registry.
local A, L = unpack(select(2, ...))
local M = A:NewModule("sortModes")
A.sortModes = M
M.private = {modes = {}}
local R = M.private

local format, ipairs, sort, tinsert, tostring = format, ipairs, sort, tinsert, tostring

--- @param sortMode expected to be a table with the following keys:
-- key = "example",                   -- (required) string
-- name = "by whatever",              -- (required) string
-- aliases = {"whatever"},            -- array of strings
-- desc = "Do an example sort.",      -- string or function(t)
-- doesNameIncludesDefault = false,   -- boolean
-- isSplit = false,                   -- boolean
-- isIncludingSitting = false,        -- boolean
-- groupOffset = 0,                   -- number
-- skipFirstGroups = 0,               -- number
-- getDefaultCompareFunc = someFunc,  -- function(sortMode, keys, players) or boolean
-- onBeforeStart = someFunc,          -- function() -> return true to cancel sort
-- onStart = someFunc,                -- function()
-- onBeforeSort = someFunc,           -- function(sortMode, keys, players) -> return true to cancel sort
-- onSort = someFunc,                 -- function(sortMode, keys, players)
function M:Register(sortMode)
	if not sortMode then
		A.console:Errorf(M, "attempting to register a nil sortMode")
		return
	end
	local key = sortMode.key
	if not key then
		A.console:Errorf(M, "missing key for sortMode")
		return
	end
	if not sortMode.name then
		A.console:Errorf(M, "missing name for sortMode %s", key)
		return
	end
	R.modes[key] = sortMode
	if sortMode.aliases then
		for _, alias in ipairs(sortMode.aliases) do
			if not alias or R.modes[alias] then
				A.console:Errorf(M, "invalid or duplicate alias %s for sortMode %s", tostring(alias), key)
			else
				R.modes[alias] = sortMode
			end
		end
	end
	if sortMode.getDefaultCompareFunc then
		sortMode.getFullKey = function()
			return sortMode.key
		end
		sortMode.getFullName = function()
			return sortMode.name
		end
	else
		sortMode.getFullKey = function()
			return format("%s:%s", sortMode.key, M:GetDefault().key)
		end
		sortMode.getFullName = function()
			local d = M:GetDefault()
			if sortMode.doesNameIncludesDefault and d.key ~= "nosort" then
				return format("%s, %s", d.name, sortMode.name)
			end
			return sortMode.name
		end
	end
end

function M:GetMode(alias)
	return R.modes[alias]
end

function M:GetDefault()
	return A.options.sortMode and R.modes[A.options.sortMode] or R.modes.tmrh
end