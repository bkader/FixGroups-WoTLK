--- Implement the /choose, /list, and /listself console commands.
local A, L = unpack(select(2, ...))
local M = A:NewModule("chooseCommand", "AceEvent-3.0")
A.chooseCommand = M
M.private = {
	options = {},
	optionsArePlayers = false,
	requestTimestamp = false,
	expectNumChatMsgs = false,
	expectSystemMsgPrefix = false,
	lastCommand = false,
	tmp1 = {},
	tmp2 = {}
}
local R = M.private
local H, HA, HD = A.util.Highlight, A.util.HighlightAddon, A.util.HighlightDim

-- Actually it's 255, but we'll be conservative.
local MAX_CHAT_LINE_LEN = 200
local SERVER_TIMEOUT = 5.0
local DELAY_GROUP_ROLL = 0.5
local SPACE_OR_SPACE = "%s+" .. strlower(L["word.or"]) .. "%s+"
-- DISPATCH, CLASS_ALIAS, LOCALE_GROUP, and M.MODE_ALIAS are lazily populated.
local DISPATCH = false
local CLASS_ALIAS = false
local LOCALE_GROUP = false
M.MODE_ALIAS = false

L["choose.print.choosing.armor"] = L["choose.print.choosing.armor"] .. " (%s)"
L["choose.print.choosing.primaryStat"] = L["choose.print.choosing.primaryStat"] .. " (%s)"
L["choose.print.choosing.class"] = "%s"
L["choose.print.choosing.tierToken"] = "%s (%s)"
L["choose.print.choosing.tank"] = A.util:LocaleLowerNoun(L["word.tank.singular"])
L["choose.print.choosing.healer"] = A.util:LocaleLowerNoun(L["word.healer.singular"])
L["choose.print.choosing.damager"] = A.util:LocaleLowerNoun(L["word.damager.singular"])
L["choose.print.choosing.ranged"] = A.util:LocaleLowerNoun(L["word.ranged.singular"])
L["choose.print.choosing.melee"] = A.util:LocaleLowerNoun(L["word.melee.singular"])

local format, gmatch, gsub, ipairs, pairs, select, sort, strfind, strlen, strlower, strmatch, strsplit, strsub, strtrim, time, tinsert, tonumber, tostring, unpack, wipe = format, gmatch, gsub, ipairs, pairs, select, sort, strfind, strlen, strlower, strmatch, strsplit, strsub, strtrim, time, tinsert, tonumber, tostring, unpack, wipe
local GetGuildInfo, RandomRoll, SendChatMessage, UnitClass, UnitExists, UnitIsDeadOrGhost, UnitIsInMyGuild, UnitIsUnit, UnitName, UnitGroupRolesAssigned = GetGuildInfo, RandomRoll, SendChatMessage, UnitClass, UnitExists, UnitIsDeadOrGhost, UnitIsInMyGuild, UnitIsUnit, UnitName, UnitGroupRolesAssigned
local tconcat = table.concat
local CLASS_SORT_ORDER, LOCALIZED_CLASS_NAMES_FEMALE, LOCALIZED_CLASS_NAMES_MALE, RANDOM_ROLL_RESULT = CLASS_SORT_ORDER, LOCALIZED_CLASS_NAMES_FEMALE, LOCALIZED_CLASS_NAMES_MALE, RANDOM_ROLL_RESULT

local function startExpecting(numChatMsgs, systemMsgPrefix)
	R.requestTimestamp = time()
	R.expectNumChatMsgs = numChatMsgs
	R.expectSystemMsgPrefix = systemMsgPrefix
	if A.DEBUG >= 1 then
		A.console:Debugf(M, "startExpecting numChatMsgs=%s systemMsgPrefix=[%s]", tostring(numChatMsgs), tostring(systemMsgPrefix))
	end
end

local function stopExpecting()
	R.requestTimestamp = false
	R.expectNumChatMsgs = false
	R.expectSystemMsgPrefix = false
	if A.DEBUG >= 1 then
		A.console:Debugf(M, "stopExpecting")
	end
end

local function isExpecting(quiet)
	if R.requestTimestamp then
		if R.requestTimestamp + SERVER_TIMEOUT - time() < 0 then
			if A.DEBUG >= 1 then
				A.console:Debugf(M, "isExpecting timed out")
			end
			stopExpecting()
		else
			if not quiet then
				A.console:Print(L["choose.print.busy"])
			end
			return true
		end
	end
end

local function startRoll()
	local rollPrefix = format(RANDOM_ROLL_RESULT, UnitName("player"), 867, 530, 9)
	rollPrefix = strsub(rollPrefix, 1, strfind(rollPrefix, "867") - 1)
	startExpecting(false, rollPrefix)
	if A:IsInGroup() then
		-- Slow your roll some more.
		-- See comment in the announceChoicesAndRoll method for why.
		A.After(DELAY_GROUP_ROLL, function() RandomRoll(1, #R.options) end)
	else
		RandomRoll(1, #R.options)
	end
end

local function watchChat(event, message, sender)
	if not R.expectNumChatMsgs or not isExpecting(true) or not message then
		return
	end
	if A.DEBUG >= 1 then
		A.console:Debugf(M, "watchChat event=%s message=[%s] sender=%s expectNumChatMsgs=[%s]", event, A.util:Escape(message), sender, R.expectNumChatMsgs)
	end
	if not UnitExists(sender) then
		sender = A.util:StripRealm(sender)
	end
	if sender ~= UnitName("player") then
		return
	end
	R.expectNumChatMsgs = R.expectNumChatMsgs - 1
	if R.expectNumChatMsgs <= 0 then
		if A.DEBUG >= 1 then
			A.console:Debugf(M, "received all expectNumChatMsgs, starting roll")
		end
		stopExpecting()
		startRoll()
	end
end

function M:OnEnable()
	-- "/pick" would be better, but that's already an emote.
	-- "/fg choose <args>" works as well, defined in the console module.
	A.console:RegisterSlashCommand({"choose", "chose", "choo", "cho"}, function(args) M:Command("choose", args) end)
	A.console:RegisterSlashCommand({"list"}, function(args) M:Command("list", args) end)
	A.console:RegisterSlashCommand({"listself"}, function(args) M:Command("listself", args) end)
	M:RegisterEvent("CHAT_MSG_SYSTEM")
	M:RegisterEvent("CHAT_MSG_RAID", watchChat)
	M:RegisterEvent("CHAT_MSG_RAID_LEADER", watchChat)
	M:RegisterEvent("CHAT_MSG_PARTY", watchChat)
	M:RegisterEvent("CHAT_MSG_PARTY_LEADER", watchChat)
end

local function sendMessage(cmd, message, localOnly, addPrefix)
	if localOnly or not A:IsInGroup() or cmd == "listself" then
		A.console:Print(message)
	elseif addPrefix then
		SendChatMessage(format("[%s] %s", A.NAME, message), A.util:GetGroupChannel())
	else
		SendChatMessage(message, A.util:GetGroupChannel())
	end
end

function M:CHAT_MSG_SYSTEM(event, message)
	local prefix = R.expectSystemMsgPrefix
	if A.DEBUG >= 2 then
		A.console:Debugf(M, "event=%s message=[%s] prefix=[%s]", event, message, tostring(prefix))
	end
	if not prefix or not isExpecting(true) then
		return
	end
	local i = strfind(message, prefix)
	if not i then
		-- Some other system message.
		return
	end

	-- We have a match. Reset for the next /choose command and parse it.
	stopExpecting()
	local v = strsub(message, i + strlen(prefix))
	v = strsub(v, 1, strfind(v, "%s"))
	local choseIndex = tonumber(strtrim(v))
	local choseValue = choseIndex > 0 and choseIndex <= #R.options and R.options[choseIndex] or "?"

	-- Announce the winner.
	if R.optionsArePlayers then
		local player = A.group:FindPlayer(choseValue)
		if player and player.group then
			sendMessage("choose", format(L["choose.print.chose.player"], choseIndex, choseValue, player.group), false, true)
			return
		end
	end
	sendMessage("choose", format(L["choose.print.chose.option"], choseIndex, choseValue), false, true)
end

local function announceChoicesAndRoll(cmd, shouldRoll, line)
	-- Announce exactly what we'll be rolling on.
	-- Use on multiple lines if needed.
	local localOnly = not shouldRoll and cmd ~= "list"
	local addPrefix = localOnly
	local numOptions = #R.options
	local numLines = 0
	for i, option in ipairs(R.options) do
		option = tostring(i) .. "=" .. tostring(option) .. ((i < numOptions and numOptions > 1) and "," or ".")
		if line and strlen(line) + 1 + strlen(option) >= MAX_CHAT_LINE_LEN then
			sendMessage(cmd, line, localOnly, addPrefix)
			numLines = numLines + 1
			line = false
			addPrefix = false
		end
		if line then
			line = line .. " " .. option
		else
			line = option
		end
	end
	if line then
		numLines = numLines + 1
		sendMessage(cmd, line, localOnly, addPrefix)
	end
	if numOptions == 0 then
		sendMessage(cmd, L["choose.print.noPlayers"], localOnly, false)
	end
	if shouldRoll then
		if A:IsInGroup() then
			-- Wait until our announcement of the options to chat gets echoed back to
			-- us before we /roll. If we don't, thanks to lag it's possible the /roll
			-- result will reach everyone BEFORE the announcement, which defeats the
			-- entire purpose of the /choose command.
			--
			-- We only trigger off the NUMBER of lines we're sending, not the actual
			-- content of the lines. The content could be modified by an addon, the
			-- mature language filter, or if the player is drunk.
			startExpecting(numLines, false)
		else
			startRoll()
		end
	end
end

local function getValidClasses(mode, modeType)
	if modeType == "class" then
		local c = wipe(R.tmp1)
		local class, found
		for alias in gmatch(gsub(strlower(mode), "%s+", ""), "[^/%+%|]+") do
			class = CLASS_ALIAS[alias]
			if not class then
				return false
			end
			found = true
			c[class] = true
		end
		return found and c or false
	elseif modeType == "tierToken" then
		local c = wipe(R.tmp1)
		if mode == "conqueror" then
			c["PALADIN"] = true
			c["PRIEST"] = true
			c["WARLOCK"] = true
		elseif mode == "protector" then
			c["WARRIOR"] = true
			c["SHAMAN"] = true
			c["HUNTER"] = true
		elseif mode == "vanquisher" then
			c["DEATHKNIGHT"] = true
			c["MAGE"] = true
			c["DRUID"] = true
			c["ROGUE"] = true
		else
			A.console:Errorf(M, "invalid %s %s!", modeType, tostring(mode))
		end
		return c
	elseif modeType == "armor" then
		local c = wipe(R.tmp1)
		if mode == "cloth" then
			c["PRIEST"] = true
			c["MAGE"] = true
			c["WARLOCK"] = true
		elseif mode == "leather" then
			c["DRUID"] = true
			c["ROGUE"] = true
		elseif mode == "mail" then
			c["SHAMAN"] = true
			c["HUNTER"] = true
		elseif mode == "plate" then
			c["WARRIOR"] = true
			c["DEATHKNIGHT"] = true
			c["PALADIN"] = true
		else
			A.console:Errorf(M, "invalid %s %s!", modeType, tostring(mode))
		end
		return c
	elseif modeType == "primaryStat" then
		local c = wipe(R.tmp1)
		if mode == "intellect" then
			c["PALADIN"] = true
			c["DRUID"] = true
			c["PRIEST"] = true
			c["MAGE"] = true
			c["WARLOCK"] = true
			c["SHAMAN"] = true
		elseif mode == "agility" then
			c["DRUID"] = true
			c["ROGUE"] = true
			c["SHAMAN"] = true
			c["HUNTER"] = true
		elseif mode == "strength" then
			c["WARRIOR"] = true
			c["DEATHKNIGHT"] = true
			c["PALADIN"] = true
		else
			A.console:Errorf(M, "invalid %s %s!", modeType, tostring(mode))
		end
		return c
	end
end

local function choosePlayer(cmd, mode, modeType)
	if A.DEBUG >= 1 then
		A.console:Debugf(M, "choosePlayer mode=%s modeType=%s", tostring(mode), tostring(modeType))
	end
	if isExpecting() then
		return
	end

	local validClasses = getValidClasses(mode, modeType)
	R.optionsArePlayers = true
	wipe(R.options)
	local include
	A.group:ForceBuildRoster(M, "choosePlayer")
	A.group:BuildUniqueNames()
	for _, player in pairs(A.group:GetRoster()) do
		if not player.isUnknown then
			if modeType == "fromGroup" then
				include = ("g" .. player.group == mode)
			elseif mode == "anyIncludingSitting" then
				include = true
			elseif mode == "sitting" then
				include = player.isSitting
			elseif player.isSitting or mode == "sitting" then
				include = false
			elseif mode == "any" then
				include = true
			elseif mode == "notMe" then
				include = not UnitIsUnit(player.unitID, "player")
			elseif mode == "dead" then
				include = UnitIsDeadOrGhost(player.unitID)
			elseif mode == "alive" then
				include = not UnitIsDeadOrGhost(player.unitID)
			elseif mode == "guildmate" then
				include = UnitIsInMyGuild(player.unitID)
			elseif mode == "damager" then
				include = player.isDamager
			elseif mode == "tank" or mode == "healer" or mode == "melee" then
				include = (A.group.ROLE_NAME[player.role] == mode)
			elseif mode == "ranged" then
				include = (A.group.ROLE_NAME[player.role] == "ranged" or A.group.ROLE_NAME[player.role] == "unknown")
			else
				include = validClasses[player.class]
			end
			if include then
				tinsert(R.options, player.uniqueName)
			end
		end
	end
	sort(R.options)

	if mode == "melee" or mode == "ranged" then
		A.group:PrintIfThereAreUnknowns()
	end

	local shouldRoll = #R.options > 0 and cmd == "choose"
	local line = M:GetChoosingDesc(false, cmd, mode, modeType, (not A:IsInGroup()), validClasses)
	announceChoicesAndRoll(cmd, shouldRoll, line)
end

local function formatCmd(isTooltip, cmd, arg)
	local fmt
	if cmd == "choose" then
		fmt = isTooltip and L["choose.choosing.tooltip"] or L["choose.choosing.print"]
	else
		fmt = isTooltip and L["choose.list.tooltip"] or L["choose.list.print"]
	end
	return format(fmt, arg)
end

function M:GetChoosingDesc(isTooltip, cmd, mode, modeType, useColor, validClasses)
	local arg1 = mode
	local arg2
	validClasses = validClasses or getValidClasses(mode, modeType)
	if validClasses then
		local localClasses = wipe(R.tmp2)
		local c, cMale, cFemale
		for _, class in ipairs(CLASS_SORT_ORDER) do
			if validClasses[class] then
				cMale, cFemale = LOCALIZED_CLASS_NAMES_MALE[class], LOCALIZED_CLASS_NAMES_FEMALE[class]
				c = (modeType == "class") and A.util:LocaleLowerNoun(cMale) or cMale
				c = useColor and format("|c%s%s|r", A.util:ClassColor(class), c) or c
				tinsert(localClasses, c)
				if cMale ~= cFemale then
					c = (modeType == "class") and A.util:LocaleLowerNoun(cFemale) or cFemale
					c = useColor and format("|c%s%s|r", A.util:ClassColor(class), c) or c
					tinsert(localClasses, c)
				end
			end
		end
		if modeType == "class" then
			arg1 = A.util:LocaleTableConcat(localClasses, L["word.or"])
		else
			arg1 = strtrim(tostring(strsplit(",", L["choose.modeAliases." .. mode])))
			arg2 = tconcat(localClasses, "/")
		end
	elseif modeType == "fromGroup" then
		arg1 = tonumber(strsub(mode, 2))
	elseif mode == "sitting" then
		arg1 = A.util:GetSittingGroupList()
		if not arg1 then
			return formatCmd(isTooltip, cmd, L["choose.print.choosing.sitting.noGroups"])
		end
	elseif mode == "notMe" then
		if A:IsInRaid() then
			A.group.BuildUniqueNames()
			arg1 = A.group:GetPlayer(UnitName("player")).uniqueName
		else
			arg1 = A.group:GetUniqueNameParty("player")
		end
		if useColor then
			arg1 = format("|c%s%s|r", A.util:ClassColor(select(2, UnitClass("player"))), arg1)
		end
	elseif mode == "guildmate" then
		arg1 = GetGuildInfo("player")
		if not arg1 then
			return formatCmd(isTooltip, cmd, L["choose.print.choosing.guildmate.noGuild"])
		end
		arg1 = format("<%s>", arg1)
		if useColor then
			arg1 = A.util:HighlightGuild(arg1)
		end
	elseif mode == "last" then
		arg1 = H("/" .. cmd)
	end
	return formatCmd(isTooltip, cmd, format(L["choose.print.choosing." .. (modeType or mode)], arg1, arg2))
end

local function chooseClasses(cmd, args)
	if getValidClasses(args, "class") then
		choosePlayer(cmd, args, "class")
		return true
	end
end

local function chooseGroup(cmd)
	if isExpecting() then
		return
	end

	wipe(R.options)
	if A:IsInRaid() then
		for g = 1, 8 do
			if A.group:GetGroupSize(g) > 0 then
				tinsert(R.options, format("%s %d", LOCALE_GROUP or "group", g))
			end
		end
	else
		tinsert(R.options, format("%s %d", LOCALE_GROUP or "group", 1))
	end

	announceChoicesAndRoll(cmd, cmd == "choose", formatCmd(false, cmd, L["choose.print.choosing.group"]))
end

local function chooseOption(cmd, sep, args)
	if isExpecting() then
		return
	end

	R.optionsArePlayers = false
	wipe(R.options)
	for option in gmatch(args, "[^" .. sep .. "]+") do
		option = strtrim(option)
		if option ~= "" then
			tinsert(R.options, option)
		end
	end

	announceChoicesAndRoll(cmd, cmd == "choose", formatCmd(false, cmd, L["choose.print.choosing.option"]))
end

local function chooseLast(cmd)
	if R.lastCommand then
		M:Command(cmd, R.lastCommand)
	else
		A.console:Printf(L["choose.print.noLastCommand"], H("/" .. cmd))
	end
end

local function buildDispatchTable()
	if DISPATCH then
		return
	end

	DISPATCH = {}
	CLASS_ALIAS = {}
	local aliasLocal, aliasNonLocal = {}, {}

	local function clean(mode)
		return gsub(strlower(mode), "%s+", "")
	end

	local function add(mode, d, okayToOverwrite)
		local cmd = clean(mode)
		if DISPATCH[cmd] and not okayToOverwrite then
			A.console:Errorf(M, "duplicate definition for [%s] mode", mode)
		end
		DISPATCH[cmd] = d
		aliasLocal[mode] = aliasLocal[mode] or {}
		aliasNonLocal[mode] = aliasNonLocal[mode] or {mode}
		d.primary = mode
		local addAlias = function(aliasTable, alias)
			alias = gsub(alias, "%s+", "")
			cmd = strlower(alias)
			-- First come first serve
			if not DISPATCH[cmd] then
				DISPATCH[cmd] = d
			end
			if DISPATCH[cmd] == d then
				tinsert(aliasTable[mode], alias)
			end
		end
		d.alias = function(isLocalized, alias)
			addAlias(isLocalized and aliasLocal or aliasNonLocal, alias)
		end
		d.aliasN = function(aliases)
			for _, alias in ipairs(aliases) do
				addAlias(aliasNonLocal, alias)
			end
		end
		return d
	end

	local c, d, classLower

	-- Basic modes and non-localized aliases.
	add("gui", {A.chooseGui.Open}).aliasN({"ui", "window", "", "help", "about", "example", "examples"})
	add("group", {chooseGroup}).aliasN({"party"})
	add("guildmate", {choosePlayer, "guildmate"}).aliasN({"guildie", "guildy", "guild"})
	add("any", {choosePlayer, "any"}).aliasN({"anyone", "anybody", "someone", "somebody", "player"})
	add("sitting", {choosePlayer, "sitting"}).aliasN({"benched", "bench", "standby", "inactive", "idle"})
	add("anyIncludingSitting", {choosePlayer, "anyIncludingSitting"}).aliasN({"any+sitting", "any|sitting", "*"})
	add("notMe", {choosePlayer, "notMe"}).alias(false, "somebodyElse")
	add("dead", {choosePlayer, "dead"})
	add("alive", {choosePlayer, "alive"}).aliasN({"live", "living"})
	add("tank", {choosePlayer, "tank"})
	add("healer", {choosePlayer, "healer"}).alias(false, "heal")
	add("damager", {choosePlayer, "damager"}).aliasN({"damage", "dps", "dd"})
	add("melee", {choosePlayer, "melee"})
	add("ranged", {choosePlayer, "ranged"}).alias(false, "range")
	add("conqueror", {choosePlayer, "conqueror", "tierToken"}).alias(false, "conq")
	add("protector", {choosePlayer, "protector", "tierToken"}).alias(false, "prot")
	add("vanquisher", {choosePlayer, "vanquisher", "tierToken"}).alias(false, "vanq")
	add("intellect", {choosePlayer, "intellect", "primaryStat"}).aliasN({"intel", "int"})
	add("agility", {choosePlayer, "agility", "primaryStat"}).alias(false, "agi")
	add("strength", {choosePlayer, "strength", "primaryStat"}).alias(false, "str")
	add("cloth", {choosePlayer, "cloth", "armor"})
	add("leather", {choosePlayer, "leather", "armor"})
	add("mail", {choosePlayer, "mail", "armor"})
	add("plate", {choosePlayer, "plate", "armor"})
	add("last", {chooseLast}).aliasN({"again", "repeat", "^", '"', "previous", "prev"})

	-- Localized aliases for basic modes.
	for _, d in pairs(DISPATCH) do
		if d.primary then
			for alias in gmatch(L["choose.modeAliases." .. d.primary], "[^,]+") do
				if alias ~= "" then
					if d.primary == "group" and not LOCALE_GROUP then
						LOCALE_GROUP = alias
					end
					d.alias(true, alias)
				end
			end
		end
	end
	-- Just in case they got missed in the locale file:
	for _, role in ipairs({"tank", "healer", "damager", "melee", "ranged"}) do
		DISPATCH[role].alias(true, strtrim((L["word." .. role .. ".singular"])))
	end

	-- group1, group2, etc., and their localized aliases.
	for i = 1, 8 do
		d = {choosePlayer, "g" .. i, "fromGroup"}
		add("g" .. i, d, true).alias(false, "group" .. i, "party" .. i)
		for alias in gmatch(L["choose.modeAliases.fromGroup"], "[^,]+") do
			alias = strtrim(alias)
			if alias ~= "" then
				d.alias(false, alias .. i)
			end
		end
	end

	-- Non-localized class names.
	for _, class in ipairs(CLASS_SORT_ORDER) do
		c = clean(class)
		CLASS_ALIAS[c] = class
		add(c, {choosePlayer, c, "class"}, true)
	end
	-- Non-localized shorthand class aliases.
	CLASS_ALIAS["warr"] = "WARRIOR"
	CLASS_ALIAS["dk"] = "DEATHKNIGHT"
	CLASS_ALIAS["pal"] = "PALADIN"
	CLASS_ALIAS["pala"] = "PALADIN"
	CLASS_ALIAS["pally"] = "PALADIN"
	CLASS_ALIAS["lock"] = "WARLOCK"
	CLASS_ALIAS["sham"] = "SHAMAN"
	CLASS_ALIAS["shammy"] = "SHAMAN"
	-- Load non-localized class aliases to the dispatch table.
	for alias, class in pairs(CLASS_ALIAS) do
		d = DISPATCH[strlower(class)]
		if d then
			d.alias(false, alias)
		end
	end
	-- Localized class names.
	for class, alias in pairs(LOCALIZED_CLASS_NAMES_MALE) do
		CLASS_ALIAS[clean(alias)] = class
		DISPATCH[strlower(class)].alias(true, A.util:LocaleLowerNoun(alias))
	end
	for class, alias in pairs(LOCALIZED_CLASS_NAMES_FEMALE) do
		CLASS_ALIAS[clean(alias)] = class
		DISPATCH[strlower(class)].alias(true, A.util:LocaleLowerNoun(alias))
	end
	-- Localized shorthand class aliases.
	for _, class in ipairs(CLASS_SORT_ORDER) do
		for alias in gmatch(L["choose.classAliases." .. strlower(class)], "[^,]+") do
			alias = strtrim(alias)
			if alias ~= "" then
				CLASS_ALIAS[clean(alias)] = class
				DISPATCH[strlower(class)].alias(true, alias)
			end
		end
	end

	-- Populate M.MODE_ALIAS.
	M.MODE_ALIAS = {}
	local ma, key, keyAlt, aliasSet, aliasList
	for mode, _ in pairs(aliasLocal) do
		-- Initialize the table entry.
		ma = {primary = false}
		M.MODE_ALIAS[mode] = ma

		-- Move the aliases to a set, decorating with a prefix for sorting.
		aliasSet = wipe(R.tmp1)
		for i, alias in ipairs(aliasLocal[mode]) do
			key = "a" .. clean(alias)
			if not aliasSet[key] then
				if not ma.primary then
					ma.primary = alias
				end
				aliasSet[key] = alias
			end
		end
		wipe(aliasLocal[mode])
		for i, alias in ipairs(aliasNonLocal[mode]) do
			keyAlt = "a" .. clean(alias)
			key = "b" .. clean(alias)
			if not aliasSet[keyAlt] and not aliasSet[key] then
				if not ma.primary then
					ma.primary = alias
				end
				aliasSet[key] = alias
			end
		end
		wipe(aliasNonLocal[mode])

		-- Remove the primary alias.
		aliasSet["a" .. clean(ma.primary)] = nil
		aliasSet["b" .. clean(ma.primary)] = nil

		-- Copy the decorated aliases to a list and sort.
		-- The decorating ensures localized aliases get listed first.
		aliasList = wipe(R.tmp2)
		for key, _ in pairs(aliasSet) do
			tinsert(aliasList, key)
		end
		sort(aliasList)

		-- Get a reference to the first alias (after excluding the primary).
		if #aliasList > 0 then
			ma.secondary = aliasSet[aliasList[1]]
		end

		-- Undecorate. Add highlighting.
		for i, key in ipairs(aliasList) do
			aliasList[i] = H(aliasSet[key])
		end

		-- Convert to a flat string.
		if #aliasList == 1 then
			M.MODE_ALIAS[mode].left = L["word.alias.singular"] .. ":"
			M.MODE_ALIAS[mode].right = aliasList[1]
		elseif #aliasList > 1 then
			M.MODE_ALIAS[mode].left = L["word.alias.plural"] .. ":"
			M.MODE_ALIAS[mode].right = tconcat(aliasList, ", ")
			M.MODE_ALIAS[mode].isMore = true
		end
	end
	wipe(aliasLocal)
	wipe(aliasNonLocal)
end

function M:Command(cmd, args)
	buildDispatchTable()
	args = strtrim(args)
	local dispatch = DISPATCH[strlower(args)]
	if dispatch then
		local func, mode, args = unpack(dispatch)
		if func == A.chooseGui.Open then
			mode = cmd
			cmd = A.chooseGui
		end
		func(cmd, mode, args)
		if func == chooseLast then
			return
		end
	elseif strfind(args, SPACE_OR_SPACE) then
		chooseOption(cmd, ",", gsub(args, SPACE_OR_SPACE, ","))
	elseif strfind(args, ",") then
		chooseOption(cmd, ",", args)
	elseif strfind(args, "%s") then
		chooseOption(cmd, "%s", args)
	elseif strfind(args, "[/%+%|]") and chooseClasses(cmd, args) then
		-- Do nothing. The action is in the if clause above.
	else
		A.console:Printf(L["phrase.print.badArgument"], H(args), H("/" .. cmd))
		return
	end
	if args ~= "" then
		R.lastCommand = args
	end
end

function M:GetLastCommand()
	return R.lastCommand
end

function M:DebugPrintDispatchTable()
	buildDispatchTable()
	A.console:Debug(M, "DISPATCH:")
	for _, cmd in pairs(A.util:SortedKeys(DISPATCH, R.tmp1)) do
		A.console:DebugMore(M, format("  %s={%s}", cmd, A.util:AutoConvertTableConcat(DISPATCH[cmd], ",")))
	end
end

function M:DebugPrintClassAliases()
	buildDispatchTable()
	A.console:Debug(M, "CLASS_ALIAS:")
	for _, alias in pairs(A.util:SortedKeys(CLASS_ALIAS, R.tmp1)) do
		A.console:DebugMore(M, format("  %s=%s", alias, CLASS_ALIAS[alias]))
	end
end