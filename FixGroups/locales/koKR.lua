local L = LibStub("AceLocale-3.0"):NewLocale(..., "koKR")
if not L then return end

ERR_INSTANCE_GROUP_ADDED_S = "%s 님이 인스턴스 파티에 합류했습니다."
ERR_INSTANCE_GROUP_REMOVED_S = "%s 님이 인스턴스 파티를 떠났습니다."
ROLE_CHANGED_INFORM = "%s 님은 이제 %s입니다."
ROLE_CHANGED_INFORM_WITH_SOURCE = "%s 님은 이제 %s입니다. (%s 님이 변경)"
ROLE_REMOVED_INFORM = "%s 님은 이제 선택된 역할이 없습니다."
ROLE_REMOVED_INFORM_WITH_SOURCE = "%s 님은 이제 선택된 역할이 없습니다. (%s 님이 변경)"

-- To fix any mistranslated or missing phrases:
-- http://wow.curseforge.com/addons/fixgroups/localization/

L["addonChannel.print.newerVersion"] = "현재 실행중인 버젼 %s.  %s 버젼 %s 을 사용 할수 있습니다." -- Needs review
-- L["button.close.text"] = ""
L["button.fixGroups.desc"] = "/fg argument list" -- Needs review
-- L["button.fixGroups.paused.text"] = ""
L["button.fixGroups.text"] = "그룹 수정" -- Needs review
-- L["button.fixGroups.working.text"] = ""
-- L["button.resetAllOptions.print"] = ""
L["button.resetAllOptions.text"] = "모든 옵션 기본값으로 재설정" -- Needs review
-- L["button.splitGroups.desc"] = ""
-- L["button.splitGroups.text"] = ""
-- L["character.chen"] = ""
-- L["character.liadrin"] = ""
-- L["character.thrall"] = ""
-- L["character.velen"] = ""
-- L["choose.choosing.print"] = ""
-- L["choose.choosing.tooltip"] = ""
-- L["choose.classAliases.deathknight"] = ""
-- L["choose.classAliases.druid"] = ""
-- L["choose.classAliases.hunter"] = ""
-- L["choose.classAliases.mage"] = ""
-- L["choose.classAliases.paladin"] = ""
-- L["choose.classAliases.priest"] = ""
-- L["choose.classAliases.rogue"] = ""
-- L["choose.classAliases.shaman"] = ""
-- L["choose.classAliases.warlock"] = ""
-- L["choose.classAliases.warrior"] = ""
-- L["choose.list.print"] = ""
-- L["choose.list.tooltip"] = ""
-- L["choose.modeAliases.agility"] = ""
-- L["choose.modeAliases.alive"] = ""
-- L["choose.modeAliases.any"] = ""
-- L["choose.modeAliases.anyIncludingSitting"] = ""
-- L["choose.modeAliases.cloth"] = ""
L["choose.modeAliases.conqueror"] = "정복자" -- Needs review
-- L["choose.modeAliases.damager"] = ""
-- L["choose.modeAliases.dead"] = ""
-- L["choose.modeAliases.fromGroup"] = ""
-- L["choose.modeAliases.group"] = ""
-- L["choose.modeAliases.gui"] = ""
-- L["choose.modeAliases.guildmate"] = ""
-- L["choose.modeAliases.healer"] = ""
-- L["choose.modeAliases.intellect"] = ""
-- L["choose.modeAliases.last"] = ""
-- L["choose.modeAliases.leather"] = ""
-- L["choose.modeAliases.mail"] = ""
-- L["choose.modeAliases.melee"] = ""
-- L["choose.modeAliases.notMe"] = ""
-- L["choose.modeAliases.plate"] = ""
L["choose.modeAliases.protector"] = "수호자" -- Needs review
-- L["choose.modeAliases.ranged"] = ""
-- L["choose.modeAliases.sitting"] = ""
-- L["choose.modeAliases.strength"] = ""
-- L["choose.modeAliases.tank"] = ""
L["choose.modeAliases.vanquisher"] = "제압자" -- Needs review
-- L["choose.print.busy"] = ""
-- L["choose.print.choosing.alive"] = ""
-- L["choose.print.choosing.any"] = ""
-- L["choose.print.choosing.anyIncludingSitting"] = ""
-- L["choose.print.choosing.armor"] = ""
-- L["choose.print.choosing.dead"] = ""
-- L["choose.print.choosing.fromGroup"] = ""
-- L["choose.print.choosing.group"] = ""
-- L["choose.print.choosing.guildmate"] = ""
-- L["choose.print.choosing.guildmate.noGuild"] = ""
-- L["choose.print.choosing.notMe"] = ""
-- L["choose.print.choosing.option"] = ""
-- L["choose.print.choosing.primaryStat"] = ""
-- L["choose.print.choosing.sitting"] = ""
-- L["choose.print.choosing.sitting.noGroups"] = ""
L["choose.print.chose.option"] = "선택 옵션 #%d: %s." -- Needs review
L["choose.print.chose.player"] = "선택 옵션 #%d: %s 그룹  %d." -- Needs review
-- L["choose.print.last"] = ""
-- L["choose.print.noLastCommand"] = ""
-- L["choose.print.noPlayers"] = ""
-- L["dataBroker.groupComp.groupQueued"] = ""
-- L["dataBroker.groupComp.linkFullComp"] = ""
-- L["dataBroker.groupComp.linkShortComp"] = ""
-- L["dataBroker.groupComp.notInGroup"] = ""
-- L["dataBroker.groupComp.sitting"] = ""
-- L["dataBroker.groupComp.toggleAddonWindow"] = ""
-- L["dataBroker.groupComp.toggleRaidTab"] = ""
L["gui.chatKeywords"] = "그룹 수정,탱커 징표" -- Needs review
-- L["gui.choose.intro"] = ""
-- L["gui.choose.note.multipleClasses"] = ""
-- L["gui.choose.note.option.1"] = ""
-- L["gui.choose.note.option.2"] = ""
L["gui.fixGroups.help.cancel"] = "플레이어 정리 중지."
-- L["gui.fixGroups.help.choose"] = ""
-- L["gui.fixGroups.help.clear1"] = ""
-- L["gui.fixGroups.help.clear2"] = ""
-- L["gui.fixGroups.help.config"] = ""
-- L["gui.fixGroups.help.list"] = ""
-- L["gui.fixGroups.help.listself"] = ""
-- L["gui.fixGroups.help.nosort"] = ""
-- L["gui.fixGroups.help.note.clearSkip"] = ""
-- L["gui.fixGroups.help.note.core.1"] = ""
-- L["gui.fixGroups.help.note.core.2"] = ""
-- L["gui.fixGroups.help.note.defaultMode"] = ""
-- L["gui.fixGroups.help.note.meter.1"] = ""
-- L["gui.fixGroups.help.note.meter.2"] = ""
-- L["gui.fixGroups.help.note.sameAsCommand"] = ""
-- L["gui.fixGroups.help.note.sameAsLeftClicking"] = ""
-- L["gui.fixGroups.help.skip1"] = ""
-- L["gui.fixGroups.help.skip2"] = ""
-- L["gui.fixGroups.help.sort"] = ""
-- L["gui.fixGroups.help.split"] = ""
-- L["gui.fixGroups.intro"] = ""
-- L["gui.header.buttons"] = ""
-- L["gui.header.examples"] = ""
-- L["gui.list.intro"] = ""
-- L["gui.title"] = ""
L["letter.1"] = "A"
L["letter.2"] = "B"
L["letter.3"] = "C"
-- L["marker.print.needClearMainTank.plural"] = ""
-- L["marker.print.needClearMainTank.singular"] = ""
L["marker.print.needSetMainTank.plural"] = "%s 메인 탱커로 설정 되어 있지 않습니다." -- Needs review
L["marker.print.needSetMainTank.singular"] = "%s 메인 탱커로 설정 되어 있지 않습니다." -- Needs review
-- L["marker.print.openRaidTab"] = ""
-- L["marker.print.useRaidTab"] = ""
-- L["meter.print.noAddon"] = ""
-- L["meter.print.noDataFrom"] = ""
-- L["meter.print.usingDataFrom"] = ""
-- L["options.header.console"] = ""
-- L["options.header.interop"] = ""
-- L["options.header.party"] = ""
-- L["options.header.raidAssist"] = ""
-- L["options.header.raidLead"] = ""
-- L["options.header.sysMsg"] = ""
-- L["options.tab.main"] = ""
-- L["options.tab.marking"] = ""
-- L["options.tab.sorting"] = ""
-- L["options.tab.userInterface"] = ""
L["options.value.always"] = "항상" -- Needs review
-- L["options.value.announceChatLimited"] = ""
-- L["options.value.never"] = ""
-- L["options.value.noMark"] = ""
-- L["options.value.onlyInRaidInstances"] = ""
-- L["options.value.onlyWhenLeadOrAssist"] = ""
L["options.value.sortMode.nosort"] = "플레이어를 다시 정렬하지 마십시오" -- Needs review
-- L["options.widget.addButtonToRaidTab.desc"] = ""
-- L["options.widget.addButtonToRaidTab.text"] = ""
-- L["options.widget.announceChat.text"] = ""
-- L["options.widget.clearRaidMarks.text"] = ""
-- L["options.widget.coreRaiderRank.desc"] = ""
-- L["options.widget.coreRaiderRank.text"] = ""
-- L["options.widget.dataBrokerGroupCompStyle.desc.1"] = ""
-- L["options.widget.dataBrokerGroupCompStyle.desc.2"] = ""
-- L["options.widget.dataBrokerGroupCompStyle.text"] = ""
-- L["options.widget.fixOfflineML.desc"] = ""
-- L["options.widget.fixOfflineML.text"] = ""
-- L["options.widget.notifyNewVersion.desc"] = ""
-- L["options.widget.notifyNewVersion.text"] = ""
-- L["options.widget.openRaidTab.text"] = ""
-- L["options.widget.partyMark.desc"] = ""
-- L["options.widget.partyMarkIcon1.desc"] = ""
-- L["options.widget.partyMarkIcon2.desc"] = ""
-- L["options.widget.partyMarkIcon.desc"] = ""
-- L["options.widget.partyMark.text"] = ""
-- L["options.widget.raidTank.desc"] = ""
-- L["options.widget.resumeAfterCombat.text"] = ""
-- L["options.widget.roleIconSize.text"] = ""
-- L["options.widget.roleIconStyle.text"] = ""
-- L["options.widget.showExtraSortModes.text"] = ""
L["options.widget.showMinimapIcon.text"] = "미니맵 아이콘 표시" -- Needs review
L["options.widget.sortMode.text"] = "플레이어 다시 정렬" -- Needs review
-- L["options.widget.splitOddEven.desc.1"] = ""
-- L["options.widget.splitOddEven.desc.2"] = ""
-- L["options.widget.splitOddEven.text"] = ""
-- L["options.widget.sysMsgClassColor.text"] = ""
-- L["options.widget.sysMsg.desc"] = ""
-- L["options.widget.sysMsgGroupCompHighlight.text"] = ""
-- L["options.widget.sysMsgGroupComp.text"] = ""
-- L["options.widget.sysMsgRoleIcon.text"] = ""
-- L["options.widget.sysMsgRoleName.text"] = ""
-- L["options.widget.tankAssist.text"] = ""
-- L["options.widget.tankMainTank.desc"] = ""
-- L["options.widget.tankMainTank.text"] = ""
L["options.widget.tankMark.text"] = "탱커에 넣어 대상 징표" -- Needs review
-- L["options.widget.top.desc"] = ""
-- L["options.widget.watchChat.desc"] = ""
-- L["options.widget.watchChat.text"] = ""
-- L["phrase.assumingRangedForNow.plural"] = ""
-- L["phrase.assumingRangedForNow.singular"] = ""
-- L["phrase.groupComp"] = ""
L["phrase.mouse.clickLeft"] = "왼쪽 클릭" -- Needs review
L["phrase.mouse.clickRight"] = "오른쪽 클릭" -- Needs review
L["phrase.mouse.ctrlClickLeft"] = "Ctrl + 왼쪽클릭" -- Needs review
L["phrase.mouse.ctrlClickRight"] = "Ctrl + 오른쪽클릭" -- Needs review
L["phrase.mouse.drag"] = "왼쪽 클릭 + 드래그" -- Needs review
L["phrase.mouse.shiftClickLeft"] = " Shift + 왼쪽 클릭" -- Needs review
L["phrase.mouse.shiftClickRight"] = " Shift + 오른쪽 클릭" -- Needs review
-- L["phrase.print.badArgument"] = ""
-- L["phrase.print.notInRaid"] = ""
L["phrase.versionAuthor"] = "v%s by %s" -- Needs review
-- L["phrase.waitingOnDataFromServerFor"] = ""
-- L["sorter.mode.alpha"] = ""
-- L["sorter.mode.class"] = ""
-- L["sorter.mode.clear1"] = ""
-- L["sorter.mode.clear2"] = ""
-- L["sorter.mode.core"] = ""
-- L["sorter.mode.default"] = ""
-- L["sorter.mode.last"] = ""
-- L["sorter.mode.meter"] = ""
-- L["sorter.mode.nosort"] = ""
-- L["sorter.mode.ralpha"] = ""
-- L["sorter.mode.random"] = ""
-- L["sorter.mode.skip1"] = ""
-- L["sorter.mode.skip2"] = ""
-- L["sorter.mode.split"] = ""
L["sorter.mode.thmr"] = "탱커>힐러>근딜>원딜" -- Needs review
L["sorter.mode.tmrh"] = "탱커>근딜>원딜>힐러" -- Needs review
-- L["sorter.print.alreadySorted"] = ""
-- L["sorter.print.alreadySplit"] = ""
-- L["sorter.print.combatCancelled"] = ""
-- L["sorter.print.combatPaused"] = ""
-- L["sorter.print.combatResumed"] = ""
-- L["sorter.print.excludedSitting.plural"] = ""
-- L["sorter.print.excludedSitting.singular"] = ""
-- L["sorter.print.groupDisbanding"] = ""
-- L["sorter.print.last"] = ""
-- L["sorter.print.manualCancel"] = ""
-- L["sorter.print.needRank"] = ""
-- L["sorter.print.nosortDone"] = ""
-- L["sorter.print.notActive"] = ""
-- L["sorter.print.notInGuild"] = ""
-- L["sorter.print.notUseful"] = ""
-- L["sorter.print.raidOfficer.cancel"] = ""
-- L["sorter.print.raidOfficer.yield"] = ""
L["sorter.print.sorted"] = "재배열 %s." -- Needs review
-- L["sorter.print.split"] = ""
-- L["sorter.print.timedOut"] = ""
-- L["sorter.print.tooLarge"] = ""
L["tooltip.right.config"] = "설정 열기" -- Needs review
-- L["tooltip.right.fixGroups"] = ""
-- L["tooltip.right.gui"] = ""
-- L["tooltip.right.meter.1"] = ""
-- L["tooltip.right.meter.2"] = ""
L["tooltip.right.moveMinimapIcon"] = "미니맵 아이콘 이동" -- Needs review
-- L["tooltip.right.nosort"] = ""
-- L["tooltip.right.split.1"] = ""
-- L["tooltip.right.split.2"] = ""
-- L["word.alias.plural"] = ""
-- L["word.alias.singular"] = ""
L["word.and"] = "과" -- Needs review
L["word.damager.plural"] = "딜러" -- Needs review
L["word.damager.singular"] = "딜러" -- Needs review
L["word.healer.plural"] = "힐러" -- Needs review
L["word.healer.singular"] = "힐러" -- Needs review
L["word.melee.plural"] = "근딜" -- Needs review
L["word.melee.singular"] = "근딜" -- Needs review
-- L["word.none"] = ""
L["word.or"] = "또는" -- Needs review
-- L["word.party"] = ""
-- L["word.raid"] = ""
L["word.ranged.plural"] = "원딜" -- Needs review
L["word.ranged.singular"] = "원딜" -- Needs review
L["word.tank.plural"] = "탱커" -- Needs review
L["word.tank.singular"] = "탱커" -- Needs review
-- L["word.total"] = ""
-- L["word.unknown.plural"] = ""
-- L["word.unknown.singular"] = ""