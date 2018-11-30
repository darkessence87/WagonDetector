
WD.minRulesVersion = "v0.0.24"
WD.version = "v0.0.26"
WD.TiersInfo = {}

-- [encounterJournalId] = encounterCombatId, encounterName
WD.EncountersMapping = {
    [0]    = { journalId =    0, combatId = 0,    name = "Test"},
    [-1]   = { journalId =   -1, combatId = -1,   name = "ALL"},
    [2168] = { journalId = 2168, combatId = 2144, name = "UD_TALOC"},
    [2167] = { journalId = 2167, combatId = 2141, name = "UD_MOTHER"},
    [2169] = { journalId = 2169, combatId = 2136, name = "UD_ZEKVOZ"},
    [2166] = { journalId = 2166, combatId = 2134, name = "UD_VECTIS"},
    [2146] = { journalId = 2146, combatId = 2128, name = "UD_FETID"},
    [2195] = { journalId = 2195, combatId = 2145, name = "UD_ZUL"},
    [2194] = { journalId = 2194, combatId = 2135, name = "UD_MYTRAX"},
    [2147] = { journalId = 2147, combatId = 2122, name = "UD_GHUUN"},
}

WD.EncounterNames = {
    [0]  = "Test",
    [-1] = "ALL"
}

local function loadEncounters(instanceId)
    local encounters = {}

    EJ_SelectInstance(instanceId)

    local i = 1
    local encounterName, _, encounterJournalId = EJ_GetEncounterInfoByIndex(i, instanceId)
    while encounterName do
        local enc = {}
        enc.journalId = encounterJournalId
        if WD.EncountersMapping[encounterJournalId] then
            enc.combatId = WD.EncountersMapping[encounterJournalId].combatId
        else
            enc.combatId = -1
        end
        enc.name = encounterName
        encounters[#encounters+1] = enc

        -- cache
        WD.EncounterNames[encounterJournalId] = encounterName

        i = i + 1
        encounterName, _, encounterJournalId = EJ_GetEncounterInfoByIndex(i, instanceId);
    end

    return encounters
end

local function loadInstances(tierId)
    local instances = {}

    EJ_SelectTier(tierId)

    local i = 1
    local instanceId, instanceName = EJ_GetInstanceByIndex(i, true)
    while instanceId do
        local inst = {}
        inst.id = instanceId
        inst.name = instanceName
        inst.encounters = loadEncounters(instanceId)
        instances[#instances+1] = inst

        i = i + 1
        instanceId, instanceName = EJ_GetInstanceByIndex(i, true)
    end

    return instances
end

local function loadTier(id)
    local tier = {}
    tier.id = id
    tier.name = EJ_GetTierInfo(id)
    tier.instances = loadInstances(id)
    return tier
end

WD.FLASK_IDS = {
    [251837] = "/flask-of-endless-fathoms",
    [251839] = "/flask-of-the-undertow",
    [251836] = "/flask-of-the-currents",
    [251838] = "/flask-of-the-vast-horizon",
}

WD.FOOD_IDS = {
    [257408] = "Increases critical strike by 53 for 1 hour.",
    [257410] = "Increases critical strike by 70 for 1 hour.",
    [257413] = "Increases haste by 53 for 1 hour.",
    [257415] = "Increases haste by 70 for 1 hour.",
    [257418] = "Increases mastery by 53 for 1 hour.",
    [257420] = "Increases mastery by 70 for 1 hour.",
    [257422] = "Increases versatility by 53 for 1 hour.",
    [257424] = "Increases versatility by 70 for 1 hour.",
    [259448] = "Agility increased by 75.  Lasts 1 hour.",
    [259454] = "Agility increased by 100.  Lasts 1 hour.",
    [259449] = "Intellect increased by 75.  Lasts 1 hour.",
    [259455] = "Intellect increased by 100.  Lasts 1 hour.",
    [259452] = "Strength increased by 75.  Lasts 1 hour.",
    [259456] = "Strength increased by 100.  Lasts 1 hour.",
    [259453] = "Stamina increased by 113.  Lasts 1 hour.",
    [259457] = "Stamina increased by 150.  Lasts 1 hour.",
}

WD.RUNE_IDS = {
    [270058] = "/battle-scarred-augmentation",
}

WD.RuleTypes = {
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

function WD.LoadTiers()
    for i=1,EJ_GetNumTiers() do
        WD.TiersInfo[i] = loadTier(i)
    end
end

function WD.FindEncounterJournalIdByCombatId(combatId)
    for k,v in pairs(WD.EncountersMapping) do
        if v.combatId == combatId then
            return v.journalId
        end
    end
    return nil
end

function WD.FindEncounterJournalIdByName(name)
    for k,v in pairs(WD.EncounterNames) do
        if v == name then
            return k
        end
    end
    return -1
end

function WD.FindEncounterJournalIdByNameMigration(name)
    for _,v in pairs(WD.EncountersMapping) do
        if v.name == name then
            return v.journalId
        end
    end
    return nil
end

function WD.FindInstanceByJournalId(journalId)
    for _,tier in pairs(WD.TiersInfo) do
        for _,inst in pairs(tier.instances) do
            for _,enc in pairs(inst.encounters) do
                if enc.journalId == journalId then
                    return inst.name
                end
            end
        end
    end
    return nil
end
