--- Utility functions to output text to the console (i.e., default chat frame).
local A, L = unpack(select(2, ...))
local M = A:NewModule("console")
A.console = M

local PREFIX = A.util:HighlightAddon(A.NAME) .. ":"

local date, format, ipairs, print, select, strfind, strlower, strupper, tinsert, tostring, type = date, format, ipairs, print, select, strfind, strlower, strupper, tinsert, tostring, type
local tconcat = table.concat
local _G = _G
-- GLOBALS: SlashCmdList

function M:RegisterSlashCommand(cmds, func)
	for _, cmd in ipairs(cmds) do
		local name = strlower(cmd)--, A.NAME .. strupper(cmd) -- FIXME
		SlashCmdList[name] = func
		_G["SLASH_" .. name .. "1"] = "/" .. strlower(cmd)
	end
end

function M:Print(...)
	print(PREFIX, ...)
end

function M:Printf(...)
	print(PREFIX, format(...))
end

function M:Errorf(module, ...)
	local message
	if type(module) == "string" then
		message = format(module, ...)
		module = false
	else
		message = format(...)
	end
	module = module and module.GetName and format(" in %s module", module:GetName()) or ""
	print(format("%s: |cffff3333internal error%s:|r", A.util:HighlightAddon(A.NAME .. " v" .. A.VERSION_PACKAGED), module), message)
end

local function isDebuggingModule(module)
	return not module or A.DEBUG_MODULES == "*" or strfind(A.DEBUG_MODULES, module:GetName())
end

function M:Debug(module, ...)
	if isDebuggingModule(module) then
		print("|cff999999[" .. date("%H:%M:%S") .. " " .. tostring(module or A.NAME) .. "]|r|cffffcc99", ..., "|r")
	end
end

function M:Debugf(module, ...)
	if isDebuggingModule(module) then
		print("|cff999999[" .. date("%H:%M:%S") .. " " .. tostring(module or A.NAME) .. "]|r|cffffcc99", format(...), "|r")
	end
end

function M:DebugMore(module, ...)
	if isDebuggingModule(module) then
		print("|cffffcc99", ..., "|r")
	end
end

function M:DebugDump(module, ...)
	local t = {}
	for i = 1, select("#", ...) do
		tinsert(t, tostring(select(i, ...)))
	end
	M:Debug(module, tconcat(t, ", "))
end