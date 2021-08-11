--- Define a GUI for the /choose, /list, and /listself console commands.
local A, L = unpack(select(2, ...))
local M = A:NewModule("chooseGui")
A.chooseGui = M
M.private = {
	window = false,
	cmd = false,
	texturedButtons = {},
	mockSession = false
}
local R = M.private
local H, HA, HD = A.util.Highlight, A.util.HighlightAddon, A.util.HighlightDim

local format, gsub, ipairs, strlower, tinsert, tostring = format, gsub, ipairs, strlower, tinsert, tostring
local tconcat = table.concat
local GameFontHighlight, GameTooltip, IsControlKeyDown, IsShiftKeyDown, UIParent =
	GameFontHighlight,
	GameTooltip,
	IsControlKeyDown,
	IsShiftKeyDown,
	UIParent
local CLASS_SORT_ORDER, LOCALIZED_CLASS_NAMES_MALE = CLASS_SORT_ORDER, LOCALIZED_CLASS_NAMES_MALE

local AceGUI = LibStub("AceGUI-3.0")

local function onLeaveButton(widget)
	GameTooltip:Hide()
	R.window:_SetStatusText("")
end

local function getCommand(cmd, mode, modeType, isShiftClick)
	local text = format("/%s %s", cmd, mode)
	if isShiftClick then
		return text
	elseif modeType == "option" then
		return H(text)
	end
	local m = A.chooseCommand.MODE_ALIAS[mode]
	if not m.secondary then
		return H(text)
	end
	text = format("%s %s %s", H(text), HD(L["word.or"]), H(format("/%s %s", cmd, m.secondary)))
	if m.isMore then
		return text .. " " .. HD(L["word.or"] .. "...")
	end
	return text
end

local function addButton(altColor, container, cmd, mode, modeType)
	local button = AceGUI:Create("Button")
	if altColor then
		A.utilGui:AddTexturedButton(R.texturedButtons, button, "Blue")
	end
	local label
	if mode == "option2" then
		mode = format("%s %s %s", L["letter.1"], L["word.or"], L["letter.2"])
		label = mode
	elseif mode == "option3+" then
		mode = format("%s, %s, %s", L["letter.1"], L["letter.2"], L["letter.3"])
		label = mode .. ", ..."
	else
		label = A.chooseCommand.MODE_ALIAS[mode].primary
		if modeType == "tierToken" then
			label = A.util:LocaleLowerNoun(label)
		end
	end
	button:SetText(label)
	button:SetCallback("OnClick", function(widget)
		if IsShiftKeyDown() then
			A.utilGui:InsertText(getCommand(cmd, mode, modeType, true))
			if IsControlKeyDown() then
				R.window:Hide()
			end
			return
		end
		A.chooseCommand:Command(cmd, mode)
		if IsControlKeyDown() then
			R.window:Hide()
		end
	end)
	button:SetCallback("OnEnter", function(widget) M:SetupTooltip(widget, cmd, mode, modeType) end)
	button:SetCallback("OnLeave", onLeaveButton)
	button:SetWidth(104)
	container:AddChild(button)
	return button
end

local function newRow(container)
	local padding = AceGUI:Create("Label")
	padding:SetText(" ")
	padding:SetFullWidth(true)
	container:AddChild(padding)
	return padding
end

local function onCloseWindow(widget)
	A.utilGui:CleanupWindow(R.window, R.texturedButtons)
	R.window = false
	R.cmd = false
	AceGUI:Release(widget)
end

local function resetWindowSize()
	R.window:ClearAllPoints()
	R.window:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	R.window:SetWidth(675)
	R.window:SetHeight(568)
end

function M:Close()
	if R.window then
		PlaySound("gsTitleOptionExit")
		R.window.frame:Hide()
	end
end

function M:Open(cmd)
	if A.DEBUG >= 1 then
		A.console:Debugf(M, "open cmd=%s", tostring(cmd))
	end
	if R.window then
		if cmd == R.cmd then
			resetWindowSize()
			return
		else
			R.window.frame:Hide()
		end
	end
	R.cmd = cmd
	R.window = AceGUI:Create("Window")
	R.window:SetTitle(A.NAME .. " " .. format(L["gui.title"], "/" .. cmd))
	resetWindowSize()
	R.window:SetCallback("OnClose", onCloseWindow)
	local c = A.utilGui:SetupWindow(R.window)

	local widget = AceGUI:Create("Label")
	if cmd == "choose" then
		widget:SetImage("Interface\\BUTTONS\\UI-GroupLoot-Dice-Up")
		widget:SetText(format(L["gui.choose.intro"], H("/" .. cmd)))
	elseif cmd == "list" then
		widget:SetImage("Interface\\BUTTONS\\UI-GuildButton-MOTD-Up")
		widget:SetText(L["gui.fixGroups.help.list"] .. " " .. format(L["gui.list.intro"], H("/" .. cmd), H("/choose")))
	elseif cmd == "listself" then
		widget:SetImage("Interface\\BUTTONS\\UI-GuildButton-MOTD-Disabled")
		widget:SetText(L["gui.fixGroups.help.listself"] .. " " .. format(L["gui.list.intro"], H("/" .. cmd), H("/choose")))
	else
		A.console:Errorf(M, "invalid cmd %s!", tostring(cmd))
		return
	end
	widget:SetImageSize(64, 64)
	widget:SetFontObject(GameFontHighlight)
	widget:SetFullWidth(true)
	c:AddChild(widget)

	widget = AceGUI:Create("Heading")
	widget:SetText(format(L["gui.header.buttons"], H("/" .. cmd)))
	widget:SetFullWidth(true)
	c:AddChild(widget)

	addButton(false, c, cmd, "any")
	addButton(false, c, cmd, "tank")
	addButton(false, c, cmd, "healer")
	addButton(false, c, cmd, "damager")
	addButton(false, c, cmd, "melee")
	addButton(false, c, cmd, "ranged")
	addButton(false, c, cmd, "notMe")
	addButton(false, c, cmd, "guildmate")
	addButton(false, c, cmd, "dead")
	addButton(false, c, cmd, "alive")
	newRow(c)

	for i, class in ipairs(CLASS_SORT_ORDER) do
		addButton(true, c, cmd, strlower(class), "class")
	end
	newRow(c)

	addButton(true, c, cmd, "conqueror", "tierToken")
	addButton(true, c, cmd, "protector", "tierToken")
	addButton(true, c, cmd, "vanquisher", "tierToken")
	newRow(c)

	addButton(false, c, cmd, "intellect", "primaryStat")
	addButton(false, c, cmd, "agility", "primaryStat")
	addButton(false, c, cmd, "strength", "primaryStat")
	newRow(c)

	addButton(false, c, cmd, "cloth", "armor")
	addButton(false, c, cmd, "leather", "armor")
	addButton(false, c, cmd, "mail", "armor")
	addButton(false, c, cmd, "plate", "armor")
	newRow(c)

	addButton(true, c, cmd, "g1", "fromGroup")
	addButton(true, c, cmd, "g2", "fromGroup")
	addButton(true, c, cmd, "g3", "fromGroup")
	addButton(true, c, cmd, "g4", "fromGroup")
	addButton(true, c, cmd, "g5", "fromGroup")
	addButton(true, c, cmd, "g6", "fromGroup")
	addButton(true, c, cmd, "g7", "fromGroup")
	addButton(true, c, cmd, "g8", "fromGroup")
	addButton(true, c, cmd, "sitting")
	addButton(true, c, cmd, "anyIncludingSitting")
	addButton(true, c, cmd, "group")
	newRow(c)

	addButton(false, c, cmd, "last")
	if cmd == "choose" then
		addButton(false, c, cmd, "option2", "option")
		addButton(false, c, cmd, "option3+", "option")
		newRow(c)

		widget = AceGUI:Create("Heading")
		widget:SetText(format(L["gui.header.examples"], "/" .. cmd))
		widget:SetFullWidth(true)
		c:AddChild(widget)
		newRow(c)

		if not R.mockSession then
			R.mockSession = {}
			A.chooseMockup:Mockup(function(line) tinsert(R.mockSession, line) end)
			R.mockSession = tconcat(R.mockSession, "|n")
		end
		widget = AceGUI:Create("Label")
		widget:SetFontObject(GameFontHighlight)
		widget:SetText(R.mockSession)
		widget:SetFullWidth(true)
		c:AddChild(widget)
	end
end

function M:SetupTooltip(widget, cmd, mode, modeType)
	R.window:_SetStatusText(getCommand(cmd, mode, modeType, false))
	local t = GameTooltip
	t:SetOwner(widget.frame, "ANCHOR_TOPRIGHT")
	t:ClearLines()
	-- Title, split into two lines if too long.
	local title
	if mode == "last" then
		local last = A.chooseCommand:GetLastCommand()
		if last then
			title = format("%s: %s.", L["choose.print.last"], H(format("/%s %s", cmd, last)))
		else
			title = L["choose.print.last"] .. "."
		end
	else
		title = A.chooseCommand:GetChoosingDesc(true, cmd, mode, modeType, true)
	end
	if modeType == "tierToken" or modeType == "armor" or modeType == "primaryStat" then
		title = gsub(title, " %(", "|n(")
	end
	t:AddLine(title)
	if modeType == "class" then
		t:AddLine(" ")
		local example = format("/%s %s/%s", cmd, A.util:LocaleLowerNoun(LOCALIZED_CLASS_NAMES_MALE["MAGE"]), A.util:LocaleLowerNoun(LOCALIZED_CLASS_NAMES_MALE["DRUID"]))
		t:AddLine(format(L["gui.choose.note.multipleClasses"], H(example)), 1, 1, 1, true)
	end
	if modeType == "option" then
		t:AddLine(" ")
		t:AddLine(format(L["gui.choose.note.option.1"], H("/" .. cmd)), 1, 1, 1, true)
		t:AddLine(" ")
		t:AddLine(L["gui.choose.note.option.2"], 1, 1, 1, true)
	elseif A.chooseCommand.MODE_ALIAS[mode].left then
		-- List aliases.
		t:AddLine(" ")
		t:AddDoubleLine(A.chooseCommand.MODE_ALIAS[mode].left, A.chooseCommand.MODE_ALIAS[mode].right, 1, 1, 1, 1, 1, 1)
	end
	t:Show()
end