--- Define all user-configurable options and a GUI to modify them, used in
-- WoW's Interface>Addons pane.
local A, L = unpack(select(2, ...))
local M = A:NewModule("options")
A.options = M
M.private = {
	optionsGUI = false,
	optionsTable = false,
	sysMsgPreviewWidgets = {false, false},
	defaults = {
		profile = {
			options = {
				-- Sorting tab
				announceChatAlways = false,
				announceChatPRN = true, -- ignored (implied false) if announceChatAlways == true
				sortMode = "tmrh", -- other valid values: "thmr", "nosort"
				splitOddEven = true,
				resumeAfterCombat = true,
				showExtraSortModes = false,
				coreRaiderRank = {}, -- key: guild+realm name, value: rank index
				-- Marking tab
				tankAssist = true,
				fixOfflineML = true,
				tankMark = true,
				tankMarkIcons = {4, 6, 1, 2, 3, 7, 9, 9},
				clearRaidMarks = false,
				tankMainTankAlways = false,
				tankMainTankPRN = true, -- ignored (implied false) if tankMainTankAlways == true
				openRaidTabPRN = true, -- ignored (implied false) if tankMainTankAlways == true and tankMainTankPRN = false
				partyMark = true,
				partyMarkIcons = {4, 6, 9, 9, 9},
				-- User Interface tab
				showMinimapIconAlways = true,
				showMinimapIconPRN = false, -- ignored (implied false) if showMinimapIconAlways == true
				minimapIcon = {}, -- handled by LibDBIcon
				addButtonToRaidTab = true,
				watchChat = true,
				notifyNewVersion = true,
				roleIconStyle = "default", -- other valid values: "hires", "lfgrole", "lfgrole_bw"
				roleIconSize = 16,
				sysMsg = {
					classColor = true,
					roleName = true,
					roleIcon = true,
					groupComp = true,
					groupCompHighlight = true
				},
				dataBrokerGroupCompStyle = 1
			}
		}
	}
}
local R = M.private
local H, HA, HD = A.util.Highlight, A.util.HighlightAddon, A.util.HighlightDim

-- The number next to each mark is how many times DBM uses that mark for
-- all Draenor content.
--
-- Skull, cross, and moon are used the least frequently. However those marks
-- usually mean "kill first", "kill second", and "keep cc'd", respectively.
--
-- Of the remaining marks, triangle and square are next. That's why they're the
-- default tank marks.
local MARKS = {
	A.util.TEXT_ICON.MARK.STAR, -- 16
	A.util.TEXT_ICON.MARK.CIRCLE, -- 16
	A.util.TEXT_ICON.MARK.DIAMOND, -- 14
	A.util.TEXT_ICON.MARK.TRIANGLE, -- 11
	A.util.TEXT_ICON.MARK.MOON, -- 9
	A.util.TEXT_ICON.MARK.SQUARE, -- 10
	A.util.TEXT_ICON.MARK.CROSS, -- 7
	A.util.TEXT_ICON.MARK.SKULL, -- 9
	L["options.value.noMark"]
}

local format, gsub, ipairs, min, max, tinsert = format, gsub, ipairs, min, max, tinsert
local tconcat = table.concat
local GetGuildInfo = GetGuildInfo
local ERR_RAID_MEMBER_ADDED_S, ERR_RAID_MEMBER_REMOVED_S, INLINE_TANK_ICON, ROLE_CHANGED_INFORM, TANK = ERR_RAID_MEMBER_ADDED_S, ERR_RAID_MEMBER_REMOVED_S, INLINE_TANK_ICON, ROLE_CHANGED_INFORM, TANK
-- GLOBALS: LibStub

local function paragraphs(lines)
	return tconcat(lines, "|n|n")
end

local function getOptionMark(arr, index)
	if arr[index] and arr[index] <= 8 then
		return arr[index]
	end
	return 9
end

local function setOptionMark(arr, index, value)
	if arr ~= A.options.partyMarkIcons then
		A.sorter:Stop()
	end
	if value <= 0 or value > 8 then
		value = 9
	end
	arr[index] = value
	-- Assume the user knows what they're doing.
	-- Don't bother fixing duplicates.
end

R.optionsTable = {
	type = "group",
	childGroups = "tab",
	name = HA(A.NAME) .. " " .. format(L["phrase.versionAuthor"], A.VERSION_PACKAGED, HA(A.AUTHOR)),
	args = {
		main = {
			order = 10,
			type = "group",
			name = L["options.tab.main"]
		},
		sort = {
			order = 20,
			type = "group",
			name = L["options.tab.sorting"]
		},
		ui = {
			order = 40,
			type = "group",
			name = L["options.tab.userInterface"]
		},
		mark = {
			order = 30,
			type = "group",
			name = L["options.tab.marking"]
		}
	}
}

R.optionsTable.args.main.args = {
	desc = {
		order = 0,
		type = "description",
		image = "Interface\\Addons\\" .. A.NAME .. "\\media\\cubeIcon1_classIcons_256.tga",
		imageWidth = 256,
		imageHeight = 256,
		name = format(L["options.widget.top.desc"], HA(A.NAME)),
		fontSize = "medium"
	},
	-- -------------------------------------------------------------------------
	spacerConsole = {
		order = 300,
		type = "description",
		name = "|n"
	},
	headerConsole = {
		order = 301,
		type = "header",
		name = L["options.header.console"]
	},
	buttonCommandFixGroupsHelp = {
		order = 310,
		type = "execute",
		name = "/fg",
		desc = format(L["gui.fixGroups.intro"], H("/fg"), H("/fixgroups")),
		func = function()
			A.utilGui:CloseConfig()
			A.fgCommand:Command("help")
		end
	},
	buttonCommandChoose = {
		order = 320,
		type = "execute",
		name = "/choose",
		desc = format(L["gui.choose.intro"], H("/choose")),
		func = function()
			A.utilGui:CloseConfig()
			A.chooseCommand:Command("choose", "")
		end
	},
	buttonCommandList = {
		order = 320,
		type = "execute",
		name = "/list",
		desc = format(L["gui.list.intro"], H("/list"), H("/choose")),
		func = function()
			A.utilGui:CloseConfig()
			A.chooseCommand:Command("list", "")
		end
	},
	-- -------------------------------------------------------------------------
	spacerReset = {
		order = 900,
		type = "description",
		name = "|n"
	},
	headerReset = {
		order = 901,
		type = "header",
		name = ""
	},
	buttonReset = {
		order = 910,
		type = "execute",
		width = "double",
		name = L["button.resetAllOptions.text"],
		func = function()
			-- Preserve the minimapIcon table. It's owned by LibDBIcon.
			local minimapIcon = A.options.minimapIcon
			A.db:ResetProfile()
			-- Update table reference.
			A.options = A.db.profile.options
			A.options.minimapIcon = minimapIcon
			A.console:Print(L["button.resetAllOptions.print"])
			A.buttonGui:Refresh()
		end
	}
}

R.optionsTable.args.sort.args = {
	announceChat = {
		order = 10,
		name = L["options.widget.announceChat.text"],
		type = "select",
		width = "double",
		style = "dropdown",
		values = {
			[1] = L["options.value.always"],
			[2] = L["options.value.announceChatLimited"],
			[3] = L["options.value.never"]
		},
		get = function(i)
			if A.options.announceChatAlways then
				return 1
			elseif A.options.announceChatPRN then
				return 2
			end
			return 3
		end,
		set = function(i, v)
			A.options.announceChatAlways, A.options.announceChatPRN = (v == 1), (v == 2)
			A.sorter:ResetAnnounced()
		end
	},
	sortMode = {
		order = 20,
		name = L["options.widget.sortMode.text"],
		type = "select",
		width = "double",
		style = "dropdown",
		values = {
			[1] = format(
				"%s > %s > %s > %s",
				L["word.tank.plural"],
				L["word.melee.plural"],
				L["word.ranged.plural"],
				L["word.healer.plural"]
			),
			[2] = format(
				"%s > %s > %s > %s",
				L["word.tank.plural"],
				L["word.healer.plural"],
				L["word.melee.plural"],
				L["word.ranged.plural"]
			),
			[3] = L["options.value.sortMode.nosort"]
		},
		get = function(i)
			if A.options.sortMode == "nosort" then
				return 3
			elseif A.options.sortMode == "thmr" then
				return 2
			else
				return 1
			end
		end,
		set = function(i, v)
			A.sorter:Stop()
			if v == 3 then
				A.options.sortMode = "nosort"
			elseif v == 2 then
				A.options.sortMode = "thmr"
			else
				A.options.sortMode = "tmrh"
			end
		end
	},
	damageMeterAddonDesc = {
		order = 30,
		type = "description",
		name = "", -- set in M:OnEnable
		fontSize = "medium"
	},
	splitOddEven = {
		order = 40,
		name = L["options.widget.splitOddEven.text"],
		desc = paragraphs({
			L["options.widget.splitOddEven.desc.1"],
			format(L["options.widget.splitOddEven.desc.2"], H("/fg split"), H(L["button.splitGroups.text"]))
		}),
		type = "toggle",
		width = "full",
		get = function(i)
			return A.options.splitOddEven
		end,
		set = function(i, v)
			A.sorter:Stop()
			A.options.splitOddEven = v
		end
	},
	resumeAfterCombat = {
		order = 50,
		name = L["options.widget.resumeAfterCombat.text"],
		type = "toggle",
		width = "full",
		get = function(i)
			return A.options.resumeAfterCombat
		end,
		set = function(i, v)
			A.sorter:Stop()
			A.options.resumeAfterCombat = v
		end
	},
	showExtraSortModes = {
		order = 60,
		name = L["options.widget.showExtraSortModes.text"],
		desc = L["sorter.print.notUseful"],
		type = "toggle",
		width = "full",
		get = function(i)
			return A.options.showExtraSortModes
		end,
		set = function(i, v)
			A.options.showExtraSortModes = v
		end
	},
	coreRaiderRank = {
		order = 70,
		name = L["options.widget.coreRaiderRank.text"],
		desc = "", -- dynamic
		type = "select",
		width = "double",
		style = "dropdown",
		values = {}, -- dynamic
		get = function(i)
			return A.sortModes.core:GetCoreRank()
		end,
		set = function(i, v)
			A.sortModes.core:SetCoreRank(v)
		end,
		hidden = function(i)
			local guildName = GetGuildInfo("player")
			if not guildName then
				return true
			end
			A.sortModes.core:UpdateGuildRanks()
			i.option.desc = format(L["options.widget.coreRaiderRank.desc"], H("core"), A.util:HighlightGuild(format("<%s>", guildName)))
			i.option.values = A.sortModes.core:GetGuildRanks()
		end
	}
}

R.optionsTable.args.mark.args = {
	headerRAIDLEAD = {
		order = 0,
		type = "header",
		name = L["options.header.raidLead"]
	},
	tankAssist = {
		order = 10,
		name = L["options.widget.tankAssist.text"],
		type = "toggle",
		width = "full",
		get = function(i)
			return A.options.tankAssist
		end,
		set = function(i, v)
			A.options.tankAssist = v
		end
	},
	fixOfflineML = {
		order = 20,
		name = L["options.widget.fixOfflineML.text"],
		desc = L["options.widget.fixOfflineML.desc"],
		type = "toggle",
		width = "full",
		get = function(i)
			return A.options.fixOfflineML
		end,
		set = function(i, v)
			A.options.fixOfflineML = v
		end
	},
	-- -------------------------------------------------------------------------
	headerRAIDASSIST = {
		order = 100,
		type = "header",
		name = L["options.header.raidAssist"]
	},
	tankMark = {
		order = 130,
		name = L["options.widget.tankMark.text"],
		type = "toggle",
		width = "full",
		get = function(i)
			return A.options.tankMark
		end,
		set = function(i, v)
			A.options.tankMark = v
		end
	},
	tankMarkIcon1 = {
		order = 131,
		name = format("%s %s 1", A.util:GetRoleIcon("TANK"), L["word.tank.singular"]),
		desc = L["options.widget.raidTank.desc"],
		type = "select",
		width = "half",
		style = "dropdown",
		values = MARKS,
		get = function(i)
			return getOptionMark(A.options.tankMarkIcons, 1)
		end,
		set = function(i, v)
			setOptionMark(A.options.tankMarkIcons, 1, v)
		end,
		disabled = function(i)
			return not A.options.tankMark
		end
	},
	tankMarkIcon2 = {
		order = 132,
		name = format("%s %s 2", A.util:GetRoleIcon("TANK"), L["word.tank.singular"]),
		desc = L["options.widget.raidTank.desc"],
		type = "select",
		width = "half",
		style = "dropdown",
		values = MARKS,
		get = function(i)
			return getOptionMark(A.options.tankMarkIcons, 2)
		end,
		set = function(i, v)
			setOptionMark(A.options.tankMarkIcons, 2, v)
		end,
		disabled = function(i)
			return not A.options.tankMark
		end
	},
	tankMarkIcon3 = {
		order = 133,
		name = format("%s %s 3", A.util:GetRoleIcon("TANK"), L["word.tank.singular"]),
		desc = L["options.widget.raidTank.desc"],
		type = "select",
		width = "half",
		style = "dropdown",
		values = MARKS,
		get = function(i)
			return getOptionMark(A.options.tankMarkIcons, 3)
		end,
		set = function(i, v)
			setOptionMark(A.options.tankMarkIcons, 3, v)
		end,
		disabled = function(i)
			return not A.options.tankMark
		end
	},
	tankMarkIcon4 = {
		order = 134,
		name = format("%s %s 4", A.util:GetRoleIcon("TANK"), L["word.tank.singular"]),
		desc = L["options.widget.raidTank.desc"],
		type = "select",
		width = "half",
		style = "dropdown",
		values = MARKS,
		get = function(i)
			return getOptionMark(A.options.tankMarkIcons, 4)
		end,
		set = function(i, v)
			setOptionMark(A.options.tankMarkIcons, 4, v)
		end,
		disabled = function(i)
			return not A.options.tankMark
		end
	},
	tankMarkIcon5 = {
		order = 135,
		name = format("%s %s 5", A.util:GetRoleIcon("TANK"), L["word.tank.singular"]),
		desc = L["options.widget.raidTank.desc"],
		type = "select",
		width = "half",
		style = "dropdown",
		values = MARKS,
		get = function(i)
			return getOptionMark(A.options.tankMarkIcons, 5)
		end,
		set = function(i, v)
			setOptionMark(A.options.tankMarkIcons, 5, v)
		end,
		disabled = function(i)
			return not A.options.tankMark
		end
	},
	tankMarkIcon6 = {
		order = 136,
		name = format("%s %s 6", A.util:GetRoleIcon("TANK"), L["word.tank.singular"]),
		desc = L["options.widget.raidTank.desc"],
		type = "select",
		width = "half",
		style = "dropdown",
		values = MARKS,
		get = function(i)
			return getOptionMark(A.options.tankMarkIcons, 6)
		end,
		set = function(i, v)
			setOptionMark(A.options.tankMarkIcons, 6, v)
		end,
		disabled = function(i)
			return not A.options.tankMark
		end
	},
	tankMarkIcon7 = {
		order = 137,
		name = format("%s %s 7", A.util:GetRoleIcon("TANK"), L["word.tank.singular"]),
		desc = L["options.widget.raidTank.desc"],
		type = "select",
		width = "half",
		style = "dropdown",
		values = MARKS,
		get = function(i)
			return getOptionMark(A.options.tankMarkIcons, 7)
		end,
		set = function(i, v)
			setOptionMark(A.options.tankMarkIcons, 7, v)
		end,
		disabled = function(i)
			return not A.options.tankMark
		end
	},
	tankMarkIcon8 = {
		order = 138,
		name = format("%s %s 8", A.util:GetRoleIcon("TANK"), L["word.tank.singular"]),
		desc = L["options.widget.raidTank.desc"],
		type = "select",
		width = "half",
		style = "dropdown",
		values = MARKS,
		get = function(i)
			return getOptionMark(A.options.tankMarkIcons, 8)
		end,
		set = function(i, v)
			setOptionMark(A.options.tankMarkIcons, 8, v)
		end,
		disabled = function(i)
			return not A.options.tankMark
		end
	},
	clearRaidMarks = {
		order = 140,
		name = L["options.widget.clearRaidMarks.text"],
		type = "toggle",
		width = "full",
		get = function(i)
			return A.options.clearRaidMarks
		end,
		set = function(i, v)
			A.sorter:Stop()
			A.options.clearRaidMarks = v
		end
	},
	tankMainTank = {
		order = 160,
		name = L["options.widget.tankMainTank.text"],
		desc = L["options.widget.tankMainTank.desc"],
		type = "select",
		width = "double",
		style = "dropdown",
		values = {
			[1] = L["options.value.always"],
			[2] = L["options.value.onlyInRaidInstances"],
			[3] = L["options.value.never"]
		},
		get = function(i)
			if A.options.tankMainTankAlways then
				return 1
			elseif A.options.tankMainTankPRN then
				return 2
			end
			return 3
		end,
		set = function(i, v)
			A.options.tankMainTankAlways, A.options.tankMainTankPRN = (v == 1), (v == 2)
		end
	},
	openRaidTab = {
		order = 170,
		name = L["options.widget.openRaidTab.text"],
		type = "toggle",
		width = "full",
		get = function(i)
			return A.options.openRaidTabPRN
		end,
		set = function(i, v)
			A.options.openRaidTabPRN = v
		end,
		disabled = function(i)
			return not A.options.tankMainTankAlways and not A.options.tankMainTankPRN
		end
	},
	-- -------------------------------------------------------------------------
	headerPARTY = {
		order = 200,
		type = "header",
		name = L["options.header.party"]
	},
	partyMark = {
		order = 210,
		name = L["options.widget.partyMark.text"],
		desc = format(L["options.widget.partyMark.desc"], H(L["button.fixGroups.text"])),
		type = "toggle",
		width = "full",
		get = function(i)
			return A.options.partyMark
		end,
		set = function(i, v)
			A.options.partyMark = v
		end
	},
	partyMarkIcon1 = {
		order = 211,
		name = format("%s %s", A.util:GetRoleIcon("TANK"), L["word.tank.singular"]),
		desc = paragraphs({
			L["options.widget.partyMarkIcon1.desc"],
			L["options.widget.partyMarkIcon.desc"]
		}),
		type = "select",
		width = "half",
		style = "dropdown",
		values = MARKS,
		get = function(i)
			return getOptionMark(A.options.partyMarkIcons, 1)
		end,
		set = function(i, v)
			setOptionMark(A.options.partyMarkIcons, 1, v)
		end,
		disabled = function(i)
			return not A.options.partyMark
		end
	},
	partyMarkIcon2 = {
		order = 212,
		name = format("%s %s", A.util:GetRoleIcon("HEALER"), L["word.healer.singular"]),
		desc = paragraphs({
			L["options.widget.partyMarkIcon2.desc"],
			L["options.widget.partyMarkIcon.desc"]
		}),
		type = "select",
		width = "half",
		style = "dropdown",
		values = MARKS,
		get = function(i)
			return getOptionMark(A.options.partyMarkIcons, 2)
		end,
		set = function(i, v)
			setOptionMark(A.options.partyMarkIcons, 2, v)
		end,
		disabled = function(i)
			return not A.options.partyMark
		end
	},
	partyMarkIcon3 = {
		order = 213,
		name = format("%s %s 1", A.util:GetRoleIcon("DAMAGER"), L["word.damager.singular"]),
		desc = L["options.widget.partyMarkIcon.desc"],
		type = "select",
		width = "half",
		style = "dropdown",
		values = MARKS,
		get = function(i)
			return getOptionMark(A.options.partyMarkIcons, 3)
		end,
		set = function(i, v)
			setOptionMark(A.options.partyMarkIcons, 3, v)
		end,
		disabled = function(i)
			return not A.options.partyMark
		end
	},
	partyMarkIcon4 = {
		order = 214,
		name = format("%s %s 2", A.util:GetRoleIcon("DAMAGER"), L["word.damager.singular"]),
		desc = L["options.widget.partyMarkIcon.desc"],
		type = "select",
		width = "half",
		style = "dropdown",
		values = MARKS,
		get = function(i)
			return getOptionMark(A.options.partyMarkIcons, 4)
		end,
		set = function(i, v)
			setOptionMark(A.options.partyMarkIcons, 4, v)
		end,
		disabled = function(i)
			return not A.options.partyMark
		end
	},
	partyMarkIcon5 = {
		order = 215,
		name = format("%s %s 3", A.util:GetRoleIcon("DAMAGER"), L["word.damager.singular"]),
		desc = L["options.widget.partyMarkIcon.desc"],
		type = "select",
		width = "half",
		style = "dropdown",
		values = MARKS,
		get = function(i)
			return getOptionMark(A.options.partyMarkIcons, 5)
		end,
		set = function(i, v)
			setOptionMark(A.options.partyMarkIcons, 5, v)
		end,
		disabled = function(i)
			return not A.options.partyMark
		end
	}
}

R.optionsTable.args.ui.args = {
	showMinimapIcon = {
		order = 10,
		name = L["options.widget.showMinimapIcon.text"],
		type = "select",
		width = "double",
		style = "dropdown",
		values = {
			[1] = L["options.value.always"],
			[2] = L["options.value.onlyWhenLeadOrAssist"],
			[3] = L["options.value.never"]
		},
		get = function(i)
			if A.options.showMinimapIconAlways then
				return 1
			elseif A.options.showMinimapIconPRN then
				return 2
			end
			return 3
		end,
		set = function(i, v)
			A.options.showMinimapIconAlways, A.options.showMinimapIconPRN = (v == 1), (v == 2)
			A.buttonGui:Refresh()
		end
	},
	addButtonToRaidTab = {
		order = 20,
		name = L["options.widget.addButtonToRaidTab.text"],
		desc = format(
			L["options.widget.addButtonToRaidTab.desc"],
			H(L["button.fixGroups.text"]),
			H(A.util:GetBindingKey("TOGGLESOCIAL", "O"))
		),
		type = "toggle",
		width = "full",
		get = function(i)
			return A.options.addButtonToRaidTab
		end,
		set = function(i, v)
			A.options.addButtonToRaidTab = v
			A.buttonGui:Refresh()
		end
	},
	watchChat = {
		order = 30,
		name = L["options.widget.watchChat.text"],
		desc = format(L["options.widget.watchChat.desc"], A.util:GetWatchChatKeywordList()),
		type = "toggle",
		width = "full",
		get = function(i)
			return A.options.watchChat
		end,
		set = function(i, v)
			A.options.watchChat = v
		end
	},
	notifyNewVersion = {
		order = 40,
		name = L["options.widget.notifyNewVersion.text"],
		desc = paragraphs({
			format(L["options.widget.notifyNewVersion.desc"], HA(A.NAME)),
			format(L["addonChannel.print.newerVersion"], A.NAME, H("9000.1"), A.VERSION_PACKAGED)
		}),
		type = "toggle",
		width = "full",
		get = function(i)
			return A.options.notifyNewVersion
		end,
		set = function(i, v)
			A.options.notifyNewVersion = v
		end
	},
	-- -------------------------------------------------------------------------
	roleIconStyle = {
		order = 110,
		name = L["options.widget.roleIconStyle.text"],
		type = "select",
		width = "double",
		style = "dropdown",
		values = A.util:GetRoleIconSamples(),
		get = function(i)
			return A.util:GetRoleIconIndex(A.options.roleIconStyle)
		end,
		set = function(i, v)
			A.options.roleIconStyle = A.util:GetRoleIconKey(v)
			M:UpdateRoleIcons()
		end
	},
	roleIconSize = {
		order = 120,
		name = L["options.widget.roleIconSize.text"],
		type = "range",
		softMin = 8,
		softMax = 24,
		min = 1,
		max = 64,
		step = 1,
		bigStep = 2,
		get = function(i)
			return A.options.roleIconSize or 16
		end,
		set = function(i, v)
			A.options.roleIconSize = v
			M:UpdateRoleIcons()
		end
	},
	headerSYSMSG = {
		order = 200,
		type = "header",
		name = L["options.header.sysMsg"]
	},
	sysMsgPreview1 = {
		order = 211,
		type = "description",
		width = "full",
		name = "",
		fontSize = "medium",
		hidden = function(i)
			M:UpdateSysMsgPreview(1, i.option)
		end
	},
	sysMsgPreview2 = {
		order = 212,
		type = "description",
		width = "full",
		name = "",
		fontSize = "medium",
		hidden = function(i)
			M:UpdateSysMsgPreview(2, i.option)
		end
	},
	sysMsgPreview3 = {
		order = 213,
		type = "description",
		width = "full",
		name = "",
		fontSize = "medium",
		hidden = function(i)
			M:UpdateSysMsgPreview(3, i.option)
		end
	},
	sysMsgClassColor = {
		order = 230,
		name = L["options.widget.sysMsgClassColor.text"],
		desc = L["options.widget.sysMsg.desc"],
		type = "toggle",
		width = "full",
		get = function(i)
			return A.options.sysMsg.classColor
		end,
		set = function(i, v)
			A.options.sysMsg.classColor = v
		end
	},
	sysMsgRoleName = {
		order = 240,
		name = L["options.widget.sysMsgRoleName.text"],
		desc = L["options.widget.sysMsg.desc"],
		type = "toggle",
		width = "full",
		get = function(i)
			return A.options.sysMsg.roleName
		end,
		set = function(i, v)
			A.options.sysMsg.roleName = v
		end
	},
	sysMsgRoleIcon = {
		order = 250,
		name = L["options.widget.sysMsgRoleIcon.text"],
		desc = L["options.widget.sysMsg.desc"],
		type = "toggle",
		width = "full",
		get = function(i)
			return A.options.sysMsg.roleIcon
		end,
		set = function(i, v)
			A.options.sysMsg.roleIcon = v
		end
	},
	sysMsgGroupComp = {
		order = 260,
		name = L["options.widget.sysMsgGroupComp.text"],
		desc = L["options.widget.sysMsg.desc"],
		type = "toggle",
		width = "full",
		get = function(i)
			return A.options.sysMsg.groupComp
		end,
		set = function(i, v)
			A.options.sysMsg.groupComp = v
			A.options.sysMsg.groupCompHighlight = v
		end
	},
	sysMsgGroupCompHighlight = {
		order = 270,
		name = L["options.widget.sysMsgGroupCompHighlight.text"],
		desc = L["options.widget.sysMsg.desc"],
		type = "toggle",
		width = "full",
		get = function(i)
			return A.options.sysMsg.groupCompHighlight
		end,
		set = function(i, v)
			A.options.sysMsg.groupCompHighlight = v
		end,
		disabled = function(i)
			return not A.options.sysMsg.groupComp
		end
	},
	-- -------------------------------------------------------------------------
	headerINTEROP = {
		order = 400,
		type = "header",
		name = L["options.header.interop"]
	},
	dataBrokerGroupCompStyle = {
		order = 410,
		name = format(L["options.widget.dataBrokerGroupCompStyle.text"], L["phrase.groupComp"]),
		desc = paragraphs({
			format(L["options.widget.dataBrokerGroupCompStyle.desc.1"], H(L["phrase.groupComp"])),
			format(L["options.widget.dataBrokerGroupCompStyle.desc.2"], A.util:LocaleTableConcat({HA("Titan Panel"), HA("ChocolateBar"), HA("Bazooka"), HA("NinjaPanel"), HA("ElvUI")}))
		}),
		type = "select",
		width = "double",
		style = "dropdown",
		values = {
			-- Indexes correspond to A.util.GROUP_COMP_STYLE.
			[1] = A.util:FormatGroupComp(1, 2, 4, 6, 8, 0, true),
			[2] = A.util:FormatGroupComp(2, 2, 4, 6, 8, 0, true),
			[3] = A.util:FormatGroupComp(3, 2, 4, 6, 8, 0, true),
			[4] = A.util:FormatGroupComp(4, 2, 4, 6, 8, 0, true),
			[5] = A.util:FormatGroupComp(5, 2, 4, 6, 8, 0, true),
			[6] = A.util:FormatGroupComp(6, 2, 4, 6, 8, 0, true)
		},
		get = function(i)
			return max(1, min(6, A.options.dataBrokerGroupCompStyle))
		end,
		set = function(i, v)
			A.options.dataBrokerGroupCompStyle = max(1, min(6, v))
			A.dataBroker:RefreshGroupComp()
		end
	}
}

function M:OnInitialize()
	A.db = LibStub("AceDB-3.0"):New("FixGroupsDB", R.defaults, true)
	-- Intentionally overwriting the module reference.
	-- Can always do A:GetModule("options") if needed.
	A.options = A.db.profile.options

	-- Cleanup from legacy version of addon: fix renamed/removed sort modes.
	if A.options.sortMode == "THMUR" or A.options.sortMode == "meter" then
		A.options.sortMode = "thmr"
	elseif A.options.sortMode == "TMURH" then
		A.options.sortMode = "tmrh"
	end

	LibStub("AceConfig-3.0"):RegisterOptionsTable(A.NAME, R.optionsTable)
	R.optionsGUI = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(A.NAME, A.NAME)
end

function M:OnEnable()
	-- Set a couple texts that couldn't be done earlier because various modules
	-- had not yet been initialized.
	R.optionsTable.args.sort.args.damageMeterAddonDesc.name = "|n" .. A.meter:TestInterop() .. "|n|n"
	M:UpdateRoleIcons()
end

function M:UpdateSysMsgPreview(which, option)
	local comp, player, msg
	if which == 1 then
		comp = A.util:FormatGroupComp(A.util.GROUP_COMP_STYLE.TEXT_FULL, 2, 4, 4, 6, 0)
		player = A.group.EXAMPLE_PLAYER1
		msg = format(ERR_RAID_MEMBER_ADDED_S, player.name)
	elseif which == 2 then
		comp = A.util:FormatGroupComp(A.util.GROUP_COMP_STYLE.TEXT_FULL, 2, 3, 4, 6, 0)
		player = A.group.EXAMPLE_PLAYER2
		msg = format(ERR_RAID_MEMBER_REMOVED_S, player.name)
	elseif which == 3 then
		comp = A.util:FormatGroupComp(A.util.GROUP_COMP_STYLE.TEXT_FULL, 2, 2, 5, 6, 0)
		player = A.group.EXAMPLE_PLAYER3
		msg = format(ROLE_CHANGED_INFORM, player.name, INLINE_TANK_ICON .. " " .. TANK)
	else
		return
	end
	if A.modJoinLeave then
		option.name = A.util:BlankInline(16, 24) .. A.util:ColorSystem(A.modJoinLeave:Modify(msg, comp, player))
	else
		option.name = UNKNOWN
	end
end

function M:UpdateRoleIcons()
	local t = R.optionsTable.args.mark.args
	for i = 1, 8 do
		t["tankMarkIcon" .. i].name = format("%s %s %d", A.util:GetRoleIcon("TANK"), L["word.tank.singular"], i)
	end
	t["partyMarkIcon1"].name = format("%s %s", A.util:GetRoleIcon("TANK"), L["word.tank.singular"])
	t["partyMarkIcon2"].name = format("%s %s", A.util:GetRoleIcon("HEALER"), L["word.healer.singular"])
	t["partyMarkIcon3"].name = format("%s %s 1", A.util:GetRoleIcon("DAMAGER"), L["word.damager.singular"])
	t["partyMarkIcon4"].name = format("%s %s 2", A.util:GetRoleIcon("DAMAGER"), L["word.damager.singular"])
	t["partyMarkIcon5"].name = format("%s %s 3", A.util:GetRoleIcon("DAMAGER"), L["word.damager.singular"])
	t = R.optionsTable.args.ui.args.dataBrokerGroupCompStyle.values
	for i = 1, #t do
		t[i] = A.util:FormatGroupComp(i, 2, 4, 6, 8, 0, true)
	end
	t = R.optionsTable.args.ui.args
	for i = 1, 3 do
		M:UpdateSysMsgPreview(i, t["sysMsgPreview" .. i])
	end
	A.util:UpdateRoleIconSamples()
end