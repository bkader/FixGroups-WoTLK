--- Define a GUI for the /fg (/fixgroups) console command.
local A, L = unpack(select(2, ...))
local M = A:NewModule("fgGui")
A.fgGui = M
M.private = {window = false, label = false, texturedButtons = {}}
local R = M.private
local H, HA, HD = A.util.Highlight, A.util.HighlightAddon, A.util.HighlightDim

local ceil, format, ipairs, min, time, type = ceil, format, ipairs, min, time, type
local GameFontHighlight, GameTooltip, IsControlKeyDown, IsShiftKeyDown, UIParent = GameFontHighlight, GameTooltip, IsControlKeyDown, IsShiftKeyDown, UIParent

local AceGUI = LibStub("AceGUI-3.0")

local CUBE_ICON_0 = "Interface\\Addons\\" .. A.NAME .. "\\media\\cubeIcon0_64.tga"
local CUBE_ICON_1 = "Interface\\Addons\\" .. A.NAME .. "\\media\\cubeIcon1_64.tga"
local CUBE_ICON_BW = "Interface\\Addons\\" .. A.NAME .. "\\media\\cubeIconBW_64.tga"

local function newRow(container)
	local padding = AceGUI:Create("Label")
	padding:SetText(" ")
	padding:SetFullWidth(true)
	container:AddChild(padding)
	return padding
end

local function onLeaveButton(widget)
	GameTooltip:Hide()
	R.window:_SetStatusText("")
end

local function getCommand(cmd, aliases, isShiftClick)
	if isShiftClick then
		return "/fg " .. cmd
	elseif aliases and #aliases > 0 then
		local text = format("%s %s %s", H("/fg " .. cmd), HD(L["word.or"]), H("/fg " .. aliases[1]))
		if #aliases > 1 then
			return text .. " " .. HD(L["word.or"] .. "...")
		end
		return text
	else
		return H("/fg " .. cmd)
	end
end

local function addButton(altColor, container, cmd, forceClose, aliases)
	local button = AceGUI:Create("Button")
	if altColor then
		A.utilGui:AddTexturedButton(R.texturedButtons, button, "Blue")
	end
	button:SetText(cmd)
	button:SetCallback("OnClick", function(widget)
		if IsShiftKeyDown() then
			A.utilGui:InsertText(getCommand(cmd, aliases, true))
			if IsControlKeyDown() then
				R.window:Hide()
			end
			return
		end
		A.fgCommand:Command(cmd)
		if IsControlKeyDown() or forceClose then
			R.window:Hide()
		end
	end)
	if not aliases then
		local sortMode = A.sortModes:GetMode(cmd)
		if sortMode then
			aliases = sortMode.aliases
		end
	end
	button:SetCallback("OnEnter", function(widget) M:SetupTooltip(widget, cmd, aliases) end)
	button:SetCallback("OnLeave", onLeaveButton)
	button:SetWidth(104)
	container:AddChild(button)
	return button
end

local function onCloseWindow(widget)
	A.utilGui:CleanupWindow(R.window, R.texturedButtons)
	R.window = false
	R.label = false
	AceGUI:Release(widget)
end

local function resetWindowSize()
	R.window:ClearAllPoints()
	R.window:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	R.window:SetWidth(490)
	R.window:SetHeight(A.options.showExtraSortModes and 415 or 375)
end

function M:Toggle()
	if R.window then
		R.window:_CloseWithSound()
	else
		M:Open()
	end
end

function M:Open()
	if A.DEBUG >= 1 then
		A.console:Debugf(M, "open")
	end
	if R.window then
		resetWindowSize()
		return
	end
	R.window = AceGUI:Create("Window")
	R.window:SetTitle(A.NAME .. " " .. format(L["gui.title"], "/fg"))
	resetWindowSize()
	R.window:SetCallback("OnClose", onCloseWindow)
	local c = A.utilGui:SetupWindow(R.window)

	R.label = AceGUI:Create("Label")
	M:Refresh()
	R.label:SetImageSize(64, 64)
	R.label:SetFontObject(GameFontHighlight)
	R.label:SetText(format(L["gui.fixGroups.intro"], H("/fg"), H("/fixgroups")))
	R.label:SetFullWidth(true)
	c:AddChild(R.label)

	local header = AceGUI:Create("Heading")
	header:SetText(format(L["gui.header.buttons"], H("/fg")))
	header:SetFullWidth(true)
	c:AddChild(header)

	addButton(false, c, "sort")
	addButton(false, c, "split")
	addButton(false, c, "last")
	addButton(false, c, "cancel")
	newRow(c)
	addButton(true, c, "clear1")
	addButton(true, c, "clear2")
	addButton(true, c, "skip1")
	addButton(true, c, "skip2")
	newRow(c)
	addButton(true, c, "tmrh")
	addButton(true, c, "thmr")
	addButton(true, c, "nosort")
	newRow(c)
	addButton(true, c, "core")
	addButton(true, c, "meter")
	newRow(c)
	if A.options.showExtraSortModes then
		addButton(true, c, "alpha")
		addButton(true, c, "ralpha")
		addButton(true, c, "class")
		addButton(true, c, "random")
		newRow(c)
	end
	addButton(false, c, "config", true, {"options"})
	addButton(false, c, "choose", true)
	addButton(false, c, "list", true)
	addButton(false, c, "listself", true)
end

local function addTooltipLines(t, cmd)
	if cmd == "config" then
		t:AddLine(format(L["gui.fixGroups.help.config"], A.util:GetBindingKey("TOGGLEGAMEMENU", "ESCAPE"), A.NAME), 1, 1, 0, false)
	elseif cmd == "choose" or cmd == "list" or cmd == "listself" or cmd == "cancel" then
		t:AddLine(L["gui.fixGroups.help." .. cmd], 1, 1, 0, true)
	else
		local sortMode = A.sortModes:GetMode(cmd)
		if sortMode.desc then
			if type(sortMode.desc) == "function" then
				sortMode.desc(t)
			else
				t:AddLine(sortMode.desc, 1, 1, 0, true)
			end
		end
	end
end

function M:SetupTooltip(widget, cmd, aliases)
	R.window:_SetStatusText(getCommand(cmd, aliases, false))
	local t = GameTooltip
	t:SetOwner(widget.frame, "ANCHOR_TOPRIGHT")
	t:ClearLines()
	addTooltipLines(t, cmd)

	-- List aliases, if any.
	if aliases and #aliases > 0 then
		local left, right
		if #aliases == 1 then
			left = L["word.alias.singular"] .. ":"
		else
			left = L["word.alias.plural"] .. ":"
		end
		for _, a in ipairs(aliases) do
			right = (right and (right .. ", ") or "") .. H(a)
		end
		t:AddLine(" ")
		t:AddDoubleLine(left, right, 1, 1, 1, 1, 1, 1)
	end
	t:Show()
end

function M:Refresh()
	if R.label then
		if A.sorter:IsPaused() then
			R.label:SetImage(CUBE_ICON_BW)
		elseif A.sorter:IsProcessing() and time() % 2 == 0 then
			R.label:SetImage(CUBE_ICON_0)
		else
			R.label:SetImage(CUBE_ICON_1)
		end
	end
end