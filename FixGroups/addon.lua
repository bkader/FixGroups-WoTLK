local addonName, addonTable = ...
local A = LibStub("AceAddon-3.0"):NewAddon(addonName, "LibCompat-1.0")

A.NAME = addonName
A.VERSION_RELEASED = GetAddOnMetadata(A.NAME, "Version")
A.VERSION_PACKAGED = gsub(GetAddOnMetadata(A.NAME, "X-Curse-Packaged-Version") or A.VERSION_RELEASED, "^v", "")
A.AUTHOR = GetAddOnMetadata(A.NAME, "Author")
A.DEBUG = 0 -- 0=off 1=on 2=verbose
A.DEBUG_MODULES = "*" -- use comma-separated module names to filter
A.L = LibStub("AceLocale-3.0"):GetLocale(A.NAME)
addonTable[1] = A
addonTable[2] = A.L
_G[A.NAME] = A

INLINE_TANK_ICON = "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES.blp:16:16:0:0:64:64:0:19:22:41|t"
INLINE_HEALER_ICON = "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES.blp:16:16:0:0:64:64:20:39:1:20|t"
INLINE_DAMAGER_ICON = "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES.blp:16:16:0:0:64:64:20:39:22:41|t"