--- General utility functions and constants. This module is loaded before all
-- others, so it's safe to use at any point in other modules.
local A, L = unpack(select(2, ...))
local M = A:NewModule("util")
A.util = M
M.private = {tmp1 = {}}
local R = M.private

M.TEXT_ICON = {
	MARK = {
		STAR = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:16:16:0:0|t",
		CIRCLE = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_2:16:16:0:0|t",
		DIAMOND = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_3:16:16:0:0|t",
		TRIANGLE = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_4:16:16:0:0|t",
		MOON = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_5:16:16:0:0|t",
		SQUARE = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_6:16:16:0:0|t",
		CROSS = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_7:16:16:0:0|t",
		SKULL = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_8:16:16:0:0|t"
	}
}
M.GROUP_COMP_STYLE = {
	ICONS_FULL = 1,
	ICONS_SHORT = 2,
	GROUP_TYPE_FULL = 3,
	GROUP_TYPE_SHORT = 4,
	TEXT_FULL = 5,
	TEXT_SHORT = 6,
	VERBOSE = 999
}

local floor, format, gmatch, gsub, ipairs, max, pairs, select, sort, strfind, strlower, strmatch, strsplit, strsub, strtrim, strupper, tinsert, tostring, tremove, wipe = floor, format, gmatch, gsub, ipairs, max, pairs, select, sort, strfind, strlower, strmatch, strsplit, strsub, strtrim, strupper, tinsert, tostring, tremove, wipe
local ChatTypeInfo, GetAddOnMetadata, GetBindingKey, GetInstanceInfo, GetRealmName, IsInInstance, UnitClass, UnitIsRaidOfficer, UnitName = ChatTypeInfo, GetAddOnMetadata, GetBindingKey, GetInstanceInfo, GetRealmName, IsInInstance, UnitClass, UnitIsRaidOfficer, UnitName
local RAID_CLASS_COLORS = RAID_CLASS_COLORS
local tconcat = table.concat

local LOCALE_SERIAL_COMMA = (GetLocale() == "enUS") and "," or ""
local LOCALE_UPPERCASE_NOUNS = (GetLocale() == "deDE")
-- Lazily built.
local WATCH_CHAT_KEYWORDS, WATCH_CHAT_KEYWORDS_LIST = false, false

function M:LocaleLowerNoun(noun)
	return LOCALE_UPPERCASE_NOUNS and noun or strlower(noun)
end

function M:LocaleTableConcat(t, conjunction)
	conjunction = conjunction or L["word.and"]
	local sz = #t
	if sz == 0 then
		return ""
	elseif sz == 1 then
		return t[1]
	elseif sz == 2 then
		return format("%s %s %s", t[1], conjunction, t[2])
	end
	-- Temporarily modify the table get the ", and " in, then restore.
	local saveY, saveZ = t[sz - 1], t[sz]
	t[sz - 1] = format("%s%s %s %s", t[sz - 1], LOCALE_SERIAL_COMMA, conjunction, t[sz])
	tremove(t)
	local result = tconcat(t, ", ")
	t[sz - 1], t[sz] = saveY, saveZ
	return result
end

function M:AutoConvertTableConcat(t, sep)
	local t2 = wipe(R.tmp1)
	for _, v in ipairs(t) do
		tinsert(t2, tostring(v))
	end
	return tconcat(t2, sep)
end

function M:Escape(text)
	text = gsub(text, "|", "||")
	return text
end

function M:InitCaps(text)
	local t = wipe(R.tmp1)
	for part in gmatch(strlower(text), "[%w]*[^%w]*") do
		tinsert(t, strupper(strsub(part, 1, 1)))
		tinsert(t, strsub(part, 2))
	end
	return tconcat(t, "")
end

function M:GetBindingKey(action, default)
	return M:InitCaps(GetBindingKey(action) or default or "?")
end

local function buildWatchChatKeywords()
	WATCH_CHAT_KEYWORDS = {}
	WATCH_CHAT_KEYWORDS_LIST = {}
	for kw in gmatch(L["gui.chatKeywords"], "[^,]+") do
		kw = strtrim(kw)
		if kw ~= "" then
			WATCH_CHAT_KEYWORDS[strlower(kw)] = true
			tinsert(WATCH_CHAT_KEYWORDS_LIST, M:Highlight(kw))
		end
	end
	WATCH_CHAT_KEYWORDS_LIST = M:LocaleTableConcat(WATCH_CHAT_KEYWORDS_LIST, L["word.or"])
end

function M:WatchChatKeywordMatches(messageLower)
	if not WATCH_CHAT_KEYWORDS then
		buildWatchChatKeywords()
	end
	for pattern, _ in pairs(WATCH_CHAT_KEYWORDS) do
		if strfind(messageLower, pattern) then
			return true
		end
	end
end

function M:GetWatchChatKeywordList()
	if not WATCH_CHAT_KEYWORDS_LIST then
		buildWatchChatKeywords()
	end
	return WATCH_CHAT_KEYWORDS_LIST
end

function M:SortedKeys(tbl, keys)
	keys = wipe(keys or {})
	for k, _ in pairs(tbl) do
		tinsert(keys, k)
	end
	sort(keys)
	return keys
end

function M:IsLeader()
	return A:IsInGroup() and A.UnitIsGroupLeader("player")
end

function M:IsLeaderOrAssist()
	if A:IsInRaid() then
		return UnitIsRaidOfficer("player") or A.UnitIsGroupLeader("player")
	end
	return A:IsInGroup()
end

function M:GetFirstSittingGroup()
	if not IsInInstance() then
		return 9
	end
	local difficulty, _, maxPlayers = select(3, GetInstanceInfo())
	if difficulty == 16 then -- FIXME: Remove
		-- Mythic: support up to 10 benched players in raid, groups 7 and 8.
		return 7
	elseif maxPlayers > 35 then
		-- 40 man instance: no bench.
		return 9
	end
	-- Other raid sizes: just group 8.
	return 8
end

function M:GetSittingGroupList()
	local g = M:GetFirstSittingGroup()
	if g == 9 then
		return false
	elseif g == 7 then
		return format("7 %s 8", L["word.or"])
	else
		return "8"
	end
end

function M:GetFixedInstanceSize()
	local difficulty = select(3, GetInstanceInfo())
	if difficulty == 16 then
		-- Mythic
		return 20
	elseif difficulty == 17 then
		-- Raid Finder: technically flex but for our purposes it's fixed.
		return 25
	end
end

function M:GetAddonNameAndVersion(name)
	local v = GetAddOnMetadata(name, "Version")
	if v then
		if strmatch(v, "v.*") then
			return name .. " " .. v
		end
		return name .. " v" .. v
	end
	return name
end

function M:GetGroupChannel()
	local zoneType = select(2, IsInInstance())
	if zoneType == "pvp" or zoneType == "arena" then
		return "BATTLEGROUND"
	elseif A:IsInRaid() then
		return "RAID"
	elseif A:IsInGroup() then
		return "PARTY"
	end
end

local function compMRU(m, r, u)
	if u > 0 then
		return format("%d+%d+%d", m, r, u)
	else
		return format("%d+%d", m, r)
	end
end

function M:FormatGroupComp(style, t, h, m, r, u, isInRaid)
	if style == M.GROUP_COMP_STYLE.ICONS_FULL then
		return format("%d%s %d%s %d%s%s", t, M:GetRoleIcon("TANK"), h, M:GetRoleIcon("HEALER"), m + r + u, M:GetRoleIcon("DAMAGER"), M:HighlightDim(compMRU(m, r, u)))
	elseif style == M.GROUP_COMP_STYLE.ICONS_SHORT then
		return format("%d%s %d%s %d%s", t, M:GetRoleIcon("TANK"), h, M:GetRoleIcon("HEALER"), m + r + u, M:GetRoleIcon("DAMAGER"))
	elseif style == M.GROUP_COMP_STYLE.GROUP_TYPE_FULL then
		return format("%s: %s", (isInRaid or A:IsInRaid()) and L["word.raid"] or L["word.party"], M:Highlight(format("%d/%d/%d (%s)", t, h, m + r + u, compMRU(m, r, u))))
	elseif style == M.GROUP_COMP_STYLE.GROUP_TYPE_SHORT then
		return format("%s: %s", (isInRaid or A:IsInRaid()) and L["word.raid"] or L["word.party"], M:Highlight(format("%d/%d/%d", t, h, m + r + u)))
	elseif style == M.GROUP_COMP_STYLE.TEXT_FULL then
		return format("%d/%d/%d (%s)", t, h, m + r + u, compMRU(m, r, u))
	elseif style == M.GROUP_COMP_STYLE.TEXT_SHORT then
		return format("%d/%d/%d", t, h, m + r + u)
	elseif style == M.GROUP_COMP_STYLE.VERBOSE then
		local unknown = (u > 0) and format(", %d %s", u, ((u == 1) and L["word.unknown.singular"] or L["word.unknown.plural"])) or ""
		return format(
			"%d %s / %d %s / %d %s (%d %s, %d %s%s)",
			t,
			((t == 1) and L["word.tank.singular"] or L["word.tank.plural"]),
			h,
			((h == 1) and L["word.healer.singular"] or L["word.healer.plural"]),
			m + r + u,
			((m + r + u == 1) and L["word.damager.singular"] or L["word.damager.plural"]),
			m,
			((m == 1) and L["word.melee.singular"] or L["word.melee.plural"]),
			r,
			((r == 1) and L["word.ranged.singular"] or L["word.ranged.plural"]),
			unknown
		)
	else
		return M:FormatGroupComp(M.GROUP_COMP_STYLE.ICONS_FULL, t, h, m, r, u)
	end
end

function M:Highlight(text)
	return "|cff1784d1" .. (text or self) .. "|r"
end

function M:HighlightAddon(text)
	return "|cff33ff99" .. (text or self) .. "|r"
end

function M:HighlightDim(text)
	return "|cff999999" .. (text or self) .. "|r"
end

function M:HighlightGuild(text)
	return "|cff40ff40" .. (text or self) .. "|r"
end

function M:ColorSystem(text)
	local c = format("|cff%02x%02x%02x", ChatTypeInfo["SYSTEM"].r * 0xff, ChatTypeInfo["SYSTEM"].g * 0xff, ChatTypeInfo["SYSTEM"].b * 0xff)
	return c .. gsub(text, "%|r", "%|r%" .. c) .. "|r"
end

function M:ClassColor(class)
	if class and RAID_CLASS_COLORS[class] then
		class = RAID_CLASS_COLORS[class].colorStr
	else
		class = false
	end
	return (class or "ff999999")
end

function M:UnitNameWithColor(unitID)
	return "|c" .. M:ClassColor(select(2, UnitClass(unitID))) .. (UnitName(unitID) or "Unknown") .. "|r"
end

function M:NameAndRealm(name)
	if strfind(name, "%-") then
		return name
	end
	local realm = select(2, A:UnitFullName(name))
	if not realm then
		realm = gsub(GetRealmName(), "[ %-]", "")
	end
	return realm and (name .. "-" .. realm) or name
end

function M:StripRealm(name)
	return strsplit("-", name, 2)
end

function M:BlankInline(height, width)
	return format("|TInterface\\AddOns\\%s\\media\\blank.blp:%d:%d:0:0|t", A.NAME, height or 8, width or 8)
end

local ROLE_ICONS = {
	TANK = {
		default = "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:%d:%d:0:0:64:64:0:19:22:41|t",
		hires = "|TInterface\\LFGFrame\\UI-LFG-ICON-ROLES:%d:%d:0:0:256:256:0:67:67:134|t",
		lfgrole = "|TInterface\\LFGFrame\\LFGROLE:%d:%d:0:0:64:16:32:48:0:16|t",
		lfgrole_bw = "|TInterface\\LFGFrame\\LFGROLE_BW:%d:%d:0:0:64:16:32:48:0:16|t"
	},
	HEALER = {
		default = "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES.blp:%d:%d:0:0:64:64:20:39:1:20|t",
		hires = "|TInterface\\LFGFrame\\UI-LFG-ICON-ROLES:%d:%d:0:0:256:256:67:134:0:67|t",
		lfgrole = "|TInterface\\LFGFrame\\LFGROLE:%d:%d:0:0:64:16:48:64:0:16|t",
		lfgrole_bw = "|TInterface\\LFGFrame\\LFGROLE_BW:%d:%d:0:0:64:16:48:64:0:16|t"
	},
	DAMAGER = {
		default = "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES.blp:%d:%d:0:0:64:64:20:39:22:41|t",
		hires = "|TInterface\\LFGFrame\\UI-LFG-ICON-ROLES:%d:%d:0:0:256:256:67:134:67:134|t",
		lfgrole = "|TInterface\\LFGFrame\\LFGROLE:%d:%d:0:0:64:16:16:32:0:16|t",
		lfgrole_bw = "|TInterface\\LFGFrame\\LFGROLE_BW:%d:%d:0:0:64:16:16:32:0:16|t"
	},
	indexes = {},
	keys = {},
	samples = {}
}
function M:GetRoleIcon(role, style, size)
	size = size or (A.options and A.options.roleIconSize) or 16
	return format(
		ROLE_ICONS[role][style or A.options.roleIconStyle or "default"] or ROLE_ICONS[role]["default"],
		size,
		size
	)
end
function M:GetRoleIconIndex(key)
	return ROLE_ICONS.indexes[key or "default"] or 1
end
function M:GetRoleIconKey(index)
	return ROLE_ICONS.keys[index] or "default"
end
function M:GetRoleIconSamples()
	return ROLE_ICONS.samples
end
function M:UpdateRoleIconSamples()
	for i, k in ipairs(ROLE_ICONS.keys) do
		ROLE_ICONS.samples[i] = format(
			"%s %s / %s %s / %s %s",
			M:GetRoleIcon("TANK", k),
			L["word.tank.singular"],
			M:GetRoleIcon("HEALER", k),
			L["word.healer.singular"],
			M:GetRoleIcon("DAMAGER", k),
			L["word.damager.singular"]
		)
	end
end
do
	for i, k in ipairs({"default", "hires", "lfgrole", "lfgrole_bw"}) do
		ROLE_ICONS.indexes[k] = i
		tinsert(ROLE_ICONS.keys, k)
	end
	M:UpdateRoleIconSamples()
end