
WD.MinRulesVersion = "v0.0.24"
WD.Version = "v0.0.65"
WD.MaxPullsToBeSaved = 25
WD.DebugEnabled = false

WD.CurrentRealmName = string.gsub(GetRealmName(), "%s+", "")

WD.EventTypes = {
    "EV_AURA",
    "EV_AURA_STACKS",
    "EV_DISPEL",
    "EV_CAST_START",
    "EV_CAST_INTERRUPTED",
    "EV_CAST_END",
    "EV_DAMAGETAKEN",
    "EV_DEATH",
    "EV_DEATH_UNIT",
}

WD.RoleTypes = {
    "ANY",
    "TANK",
    "HEALER",
    "MELEE",
    "RANGED",
    "DPS",
    "NOT_TANK"
}

WD.MIN_CAST_TIME_TRACKED = 150 -- in msec

WD.Spells = {}

WD.Spells.ignoreDispelEffects = {
    [166646] = "Windwalking",
}
