
local WDHP = nil

WD.Help = {}

WD.Help.eventsInfo = {
    ["EV_AURA"]             = "|cffffffffchecks if any unit in encounter gains or loses specified aura|r",
    ["EV_AURA_STACKS"]      = "|cffffffffcheck if any unit in encounter gains specified number of stacks of specified aura|r",
    ["EV_DISPEL"]           = "|cffffffffcheck if any unit in encounter dispels or steals specified aura|r",
    ["EV_CAST_START"]       = "|cffffffffcheck if specified unit in encounter starts casting specified spell|r",
    ["EV_CAST_INTERRUPTED"] = "|cffffffffcheck if specified spell of specified unit in encounter is interrupted|r",
    ["EV_CAST_END"]         = "|cffffffffcheck if specified unit in encounter finished casting specified spell|r",
    ["EV_DAMAGETAKEN"]      = "|cffffffffcheck if any unit in encounter takes at least specified amount of damage by specified spell|r",
    ["EV_DEATH"]            = "|cffffffffcheck if any unit in encounter dies by specified spell|r",
    ["EV_DEATH_UNIT"]       = "|cffffffffcheck if specified unit in encounter dies|r",
    ["EV_POTIONS"]          = "|cffffffffcheck if any unit in encounter loses aura listed as potion buff|r",
    ["EV_FLASKS"]           = "|cffffffffcheck if any unit in raid has aura listed as flask buff at pull time|r",
    ["EV_FOOD"]             = "|cffffffffcheck if any unit in raid has aura listed as food buff at pull time|r",
    ["EV_RUNES"]            = "|cffffffffcheck if any unit in raid has aura listed as rune buff at pull time|r",
}

WD.Help.rulesInfo = {
    ["RL_RANGE_RULE"]   = "|cffffffffchecks if |cffffff00event_result |cffffffffapplied to unit during specified |cffffff00events_range |cffffffffrelated to that unit|r",
    ["RL_DEPENDENCY"]   = "|cffffffffchecks if |cffffff00event_result |cffffffffoccured (or not) after |cffffff00event_reason |cffffffffduring specified time|r",
    ["RL_STATISTICS"]   = "|cffffffffgathers information for unit based on specified |cffffff00statistic_mode |cffffffffrelated to that unit|r",
    ["RL_QUALITY"]      = "|cffffffffchecks if spell was dispelled/interrupted too early or too late based on |cffffff00quality_value(s)|r",
}

WD.Help.rangesInfo = {
    ["RT_AURA_EXISTS"]      = "|cffffffffrule works in range between |cffffff00gain |cffffffffand |cffffff00lose aura |cffffffffby the same unit|r",
    ["RT_AURA_NOT_EXISTS"]  = "|cffffffffrule |cffffff00does not |cffffffffwork in range between |cffffff00gain |cffffffffand |cffffff00lose |cffffffffaura by the same unit|r",
    ["RT_UNIT_CASTING"]     = "|cffffffffrule works in range between |cffffff00start cast |cffffffffand |cffffff00end (or interrupt or stop) cast |cffffffffby the same unit|r",
    ["RT_CUSTOM"]           = "|cffffffffrule works in range between |cffffff00two custom events |cffffffffby the same unit|r",
}

WD.Help.statisticInfo = {
    ["ST_TARGET_DAMAGE"]        = "|cffffffffcollects damage done to specified unit in |cffffff00events_range |cffffffffrelated to that unit|r",
    ["ST_TARGET_HEALING"]       = "|cffffffffcollects healing done to units in |cffffff00events_range |cffffffffrelated to those units|r",
    ["ST_TARGET_INTERRUPTS"]    = "|cffffffffcollects interrupts done to specified unit in |cffffff00events_range |cffffffffrelated to that units|r",
    ["ST_SOURCE_DAMAGE"]        = "|cffffffffcollects damage done by units in |cffffff00events_range |cffffffffrelated to those units|r",
    ["ST_SOURCE_HEALING"]       = "|cffffffffcollects healing done by units in |cffffff00events_range |cffffffffrelated to those units|r",
    ["ST_SOURCE_INTERRUPTS"]    = "|cffffffffcollects interrupts done by units in |cffffff00events_range |cffffffffrelated to those units|r",
}

function WD:InitHelpModule(parent)
    WDHP = parent

    WDHP.mainPage = CreateFrame("SimpleHTML", nil, WDHP)
    WDHP.mainPage:SetSize(WDHP:GetWidth() - 20, WDHP:GetHeight() - 40)
    WDHP.mainPage:SetPoint("TOPLEFT", WDHP, "TOPLEFT", 10, -10)

    WDHP.mainPage:SetFont("Fonts\\FRIZQT__.TTF", 12);
    local header = "<html><body>"
    local footer = "</body></html>"
    local version = "<p align=\"center\">Current version: |cff00ff00"..WD.version.."|r</p><br/>"
    local eventsHelp = "<h1>Events list:</h1>" .. table.tohtml(WD.Help.eventsInfo) .. "<br/>"
    local rulesHelp = "<h1>Rules list:</h1>" .. table.tohtml(WD.Help.rulesInfo) .. "<br/>"
    local statsHelp = "<h1>Statistic modes:</h1>" .. table.tohtml(WD.Help.statisticInfo) .. "<br/>"
    local rangesHelp = "<h1>Ranges list:</h1>" .. table.tohtml(WD.Help.rangesInfo) .. "<br/>"
    WDHP.mainPage:SetText(header .. version .. eventsHelp .. rulesHelp .. statsHelp .. rangesHelp .. footer)

    -- link button
    local link = "http://wow.curseforge.com/projects/wagon-detector/pages/rules"

    function WDHP:OnUpdate()
    end
end
