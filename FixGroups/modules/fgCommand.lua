--- Implement the /fg (/fixgroups) console command.
local A, L = unpack(select(2, ...))
local M = A:NewModule("fgCommand")
A.fgCommand = M
local H, HA = A.util.Highlight, A.util.HighlightAddon

local format, gsub, print, strlen, strlower, strmatch, strsub, strtrim = format, gsub, print, strlen, strlower, strmatch, strsub, strtrim

function M:OnEnable()
	A.console:RegisterSlashCommand({"fixgroups", "fixgroup", "fg"}, function(args) M:Command(args) end)
end

local function handleBasicCommands(cmd, args)
	if cmd == "" or cmd == "gui" or cmd == "ui" or cmd == "window" or cmd == "about" or cmd == "help" then
		A.fgGui:Open()
	elseif cmd == "config" or cmd == "options" then
		A.utilGui:OpenConfig()
	elseif cmd == "cancel" then
		A.sorter:StopManual()
		A.addonChannel:Broadcast("f:cancel")
	elseif cmd == "reannounce" or cmd == "reann" then
		A.sorter:ResetAnnounced()
	elseif cmd == "choose" or strmatch(cmd, "^choose ") then
		A.chooseCommand:Command("choose", strsub(args, strlen("choose") + 1))
	elseif cmd == "list" or strmatch(cmd, "^list ") then
		A.chooseCommand:Command("list", strsub(args, strlen("list") + 1))
	elseif cmd == "listself" or strmatch(cmd, "^listself ") then
		A.chooseCommand:Command("listself", strsub(args, strlen("listself") + 1))
	else
		return true
	end
end

function M:Command(args)
	local cmd = strlower(strtrim(args))
	if not handleBasicCommands(cmd, args) then
		return
	end

	-- Stop the current sort, if any.
	A.sorter:Stop()

	-- Determine sort mode.
	cmd = gsub(cmd, "%s+", "")
	local sortMode = A.sortModes:GetMode(cmd)
	if sortMode then
		if sortMode.key == "sort" then
			sortMode = A.sortModes:GetDefault()
		elseif sortMode.key == "last" then
			sortMode = A.sorter:GetLastOrDefaultSortMode()
		end
	else
		A.console:Printf(L["phrase.print.badArgument"], H(args), H("/fg help"))
		return
	end

	-- Set tank marks and such.
	if A:IsInGroup() and not A:IsInRaid() then
		A.marker:FixParty()
		if sortMode.key ~= "nosort" and sortMode.key ~= "sort" then
			A.console:Print(L["phrase.print.notInRaid"])
		end
		return
	end
	A.marker:FixRaid(false)

	-- Start sort.
	local cancelled = A.sorter:Start(sortMode)

	if not cancelled or A.sorter:IsPaused() then
		-- Notify other people running this addon that we've started a new sort.
		A.addonChannel:Broadcast("f:" .. A.sorter:GetKey())
	end
end