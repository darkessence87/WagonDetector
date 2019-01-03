
WD.MinRulesVersion = "v0.0.24"
WD.Version = "v0.0.58"
WD.TiersInfo = {}
WD.MaxPullsToBeSaved = 25
WD.DebugEnabled = false

WD.CurrentRealmName = string.gsub(GetRealmName(), "%s+", "")

-- [encounterJournalId] = encounterCombatId, encounterName
WD.EncountersMapping = {
       [0] = { journalId =    0, combatId =    0 },
      [-1] = { journalId =   -1, combatId =   -1 },
    [2168] = { journalId = 2168, combatId = 2144 },
    [2167] = { journalId = 2167, combatId = 2141 },
    [2169] = { journalId = 2169, combatId = 2136 },
    [2166] = { journalId = 2166, combatId = 2134 },
    [2146] = { journalId = 2146, combatId = 2128 },
    [2195] = { journalId = 2195, combatId = 2145 },
    [2194] = { journalId = 2194, combatId = 2135 },
    [2147] = { journalId = 2147, combatId = 2122 },
}

WD.EncounterNames = {
    [0]  = "Test",
    [-1] = "ALL"
}

local function loadSectionInfo(holder, sectionId)
    local v = C_EncounterJournal.GetSectionInfo(sectionId)
    if not v then return end
    if v.spellID ~= 0 then
        local str = "|cffffff00SpellID:|r "..v.spellID.." "..WdLib.gui:getSpellLinkByIdWithTexture(v.spellID)
        if not holder[v.spellID] then
            holder[v.spellID] = str
        end
    end
    if v.siblingSectionID then
        loadSectionInfo(holder, v.siblingSectionID)
    end
    if v.firstChildSectionID then
        loadSectionInfo(holder, v.firstChildSectionID)
    end
end

local function loadEncounters(instanceId)
    local encounters = {}

    EJ_SelectInstance(instanceId)

    local i = 1
    local encounterName, _, encounterJournalId, rootSectionId = EJ_GetEncounterInfoByIndex(i, instanceId)
    while encounterName do
        local enc = {}
        enc.journalId = encounterJournalId
        if WD.EncountersMapping[encounterJournalId] then
            enc.combatId = WD.EncountersMapping[encounterJournalId].combatId
        else
            enc.combatId = -1
        end
        enc.name = encounterName
        enc.spells = {}

        EJ_SelectEncounter(encounterJournalId)

        loadSectionInfo(enc.spells, rootSectionId)
        encounters[#encounters+1] = enc

        -- cache
        WD.EncounterNames[encounterJournalId] = encounterName

        i = i + 1
        encounterName, _, encounterJournalId, rootSectionId = EJ_GetEncounterInfoByIndex(i, instanceId);
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

    local j = 1
    local instanceId, instanceName = EJ_GetInstanceByIndex(j, false)
    while instanceId do
        local inst = {}
        inst.id = instanceId
        inst.name = instanceName
        inst.encounters = loadEncounters(instanceId)
        instances[#instances+1] = inst

        j = j + 1
        instanceId, instanceName = EJ_GetInstanceByIndex(j, false)
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
WD.Spells.flasks = {
    [251837] = "/flask-of-endless-fathoms",
    [251839] = "/flask-of-the-undertow",
    [251836] = "/flask-of-the-currents",
    [251838] = "/flask-of-the-vast-horizon",
}

WD.Spells.food = {
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

WD.Spells.runes = {
    [270058] = "/battle-scarred-augmentation",
}

WD.Spells.potions = {
    [279151] = "/battle-potion-of-intellect",
    [279152] = "/battle-potion-of-agility",
    [279153] = "/battle-potion-of-strength",
    [229206] = "/potion-of-prolonged-power",
    [251316] = "/potion-of-bursting-blood",
    [269853] = "/potion-of-rising-death",
    [279154] = "/battle-potion-of-stamina",
}

WD.Spells.rootEffects = {
       [339] = "Druid - entangling-roots",
    [102359] = "Druid - talent mass-entanglement",
    [117526] = "Hunter - binding-shot",
     [33395] = "Mage - freeze",
       [122] = "Mage - frost-nova",
    [157997] = "Mage - talent ice-nova",
}

WD.Spells.controlEffects = {
    [179057] = "DH - chaos-nova",
    [217832] = "DH - prison",
    [211881] = "DH - talent fel-eruption",
    [207167] = "DK - talent blinding-sleet",
     [91800] = "DK - pet gnaw",
     [91797] = "DK - pet monstrous-blow",
    [212337] = "DK - pet powerful-smash",
    [212332] = "DK - pet smash",
      [2637] = "Druid - hibernate",
        [99] = "Druid - incapacitating-roar",
      [5211] = "Druid - mighty-bash",
    [236748] = "Druid - talent intimidating-roar",
    [187650] = "Hunter - trap",
     [24394] = "Hunter - intimidation",
     [31661] = "Mage - dragon breath",
       [118] = "Mage - poly",
     [28271] = "Mage - poly",
     [28272] = "Mage - poly",
     [61305] = "Mage - poly",
     [61721] = "Mage - poly",
     [61780] = "Mage - poly",
    [126819] = "Mage - poly",
    [161353] = "Mage - poly",
    [161354] = "Mage - poly",
    [161355] = "Mage - poly",
    [161372] = "Mage - poly",
    [277787] = "Mage - poly",
    [277792] = "Mage - poly",
    [119381] = "Monk - leg-sweep",
    [115078] = "Monk - paralysis",
     [31935] = "Paladin - avengers-shield",
       [853] = "Paladin - hammer-of-justice",
     [20066] = "Paladin - talent",
    [115750] = "Paladin - talent",
       [605] = "Priest - mind control",
      [8122] = "Priest - psychic-scream",
      [9484] = "Priest - shackles",
     [15487] = "Priest - silence",
     [64044] = "Priest - talent psychic-horror",
    [199804] = "Rogue - between-the-eyes",
      [2094] = "Rogue - blind",
      [1833] = "Rogue - cheap-shot",
      [1776] = "Rogue - gouge",
       [408] = "Rogue - kidney-shot",
     [51514] = "Shaman - hex",
    [210873] = "Shaman - hex",
    [211004] = "Shaman - hex",
    [211010] = "Shaman - hex",
    [211015] = "Shaman - hex",
    [269352] = "Shaman - hex",
    [277778] = "Shaman - hex",
    [277784] = "Shaman - hex",
    [118345] = "Shaman - pet pulverize",
    [197214] = "Shaman - talent sundering",
       [710] = "Warlock - banish",
    [171017] = "Warlock - pet meteor-strike",
    [171018] = "Warlock - pet meteor-strike",
      [6358] = "Warlock - pet seduction",
     [89766] = "Warlock - pet axe-toss",
    [118699] = "Warlock - fear",
      [6789] = "Warlock - talent mortal-coil",
     [30283] = "Warlock - shadowfury",
      [5246] = "Warrior - intimidating-shout",
    [107079] = "Racial Pandaren - quaking-palm",
     [20549] = "Racial Tauren - war-stomp",
}

WD.Spells.knockbackEffects = {
    [198813] = "DH - triggerred by 198793",
     [49576] = "DK - grip",
     [61391] = "Druid - Aura",                              --tested
    [186387] = "Hunter - bursting-shot",
    [157980] = "Mage - talent supernova",
    [152175] = "Monk - TODO check whirling-dragon-punch",
    [204263] = "Priest - talent shining-force",
     [51490] = "Shaman - thunderstorm",
}

WD.Spells.ignoreDispelEffects = {
    [166646] = "Windwalking",
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

function WD.FindSpellsByJournalId(journalId)
    for _,tier in pairs(WD.TiersInfo) do
        for _,inst in pairs(tier.instances) do
            for _,enc in pairs(inst.encounters) do
                if enc.journalId == journalId then
                    return enc.spells
                end
            end
        end
    end
    return nil
end

function WD.GetEventDescription(eventName, ...)
    local args = {...}
    if eventName == "EV_DAMAGETAKEN" then
        if args[2] > 0 then
            return string.format(WD_RULE_DAMAGE_TAKEN_AMOUNT, args[2], WdLib.gui:getSpellLinkByIdWithTexture(args[1]))
        else
            return string.format(WD_RULE_DAMAGE_TAKEN, WdLib.gui:getSpellLinkByIdWithTexture(args[1]))
        end
    elseif eventName == "EV_DEATH" then
        return string.format(WD_RULE_DEATH, WdLib.gui:getSpellLinkByIdWithTexture(args[1]))
    elseif eventName == "EV_AURA" then
        if args[2] == "apply" then
            return string.format(WD_RULE_APPLY_AURA, WdLib.gui:getSpellLinkByIdWithTexture(args[1]))
        else
            return string.format(WD_RULE_REMOVE_AURA, WdLib.gui:getSpellLinkByIdWithTexture(args[1]))
        end
    elseif eventName == "EV_AURA_STACKS" then
        if args[2] > 0 then
            return string.format(WD_RULE_AURA_STACKS, args[2], WdLib.gui:getSpellLinkByIdWithTexture(args[1]))
        else
            return string.format(WD_RULE_AURA_STACKS_ANY, "", WdLib.gui:getSpellLinkByIdWithTexture(args[1]))
        end
    elseif eventName == "EV_CAST_START" then
        return string.format(WD_RULE_CAST_START, args[2], WdLib.gui:getSpellLinkByIdWithTexture(args[1]))
    elseif eventName == "EV_CAST_END" then
        return string.format(WD_RULE_CAST, args[2], WdLib.gui:getSpellLinkByIdWithTexture(args[1]))
    elseif eventName == "EV_CAST_INTERRUPTED" then
        return string.format(WD_RULE_CAST_INTERRUPT, args[2], WdLib.gui:getSpellLinkByIdWithTexture(args[1]))
    elseif eventName == "EV_DISPEL" then
        return string.format(WD_RULE_DISPEL, WdLib.gui:getSpellLinkByIdWithTexture(args[1]))
    elseif eventName == "EV_DEATH_UNIT" then
        return string.format(WD_RULE_DEATH_UNIT, args[1])
    elseif eventName == "EV_POTIONS" then
        return string.format(WD_RULE_POTIONS)
    elseif eventName == "EV_FLASKS" then
        return string.format(WD_RULE_FLASKS)
    elseif eventName == "EV_FOOD" then
        return string.format(WD_RULE_FOOD)
    elseif eventName == "EV_RUNES" then
        return string.format(WD_RULE_RUNES)
    end

    return eventName..": unsupported rule"
end

function WD.GetRangeRuleDescription(ruleName, ...)
    local args = {...}
    if ruleName == "RT_AURA_EXISTS" then
        return string.format(WD_TRACKER_RT_AURA_EXISTS_DESC, WdLib.gui:getSpellLinkByIdWithTexture(args[1]))
    elseif ruleName == "RT_AURA_NOT_EXISTS" then
        return string.format(WD_TRACKER_RT_AURA_NOT_EXISTS_DESC, WdLib.gui:getSpellLinkByIdWithTexture(args[1]))
    elseif ruleName == "RT_UNIT_CASTING" then
        return string.format(WD_TRACKER_RT_UNIT_CASTING_DESC, WdLib.gui:getSpellLinkByIdWithTexture(args[1]))
    elseif ruleName == "RT_CUSTOM" then
        local startEvent, endEvent = args[1][1], args[1][2]
        local startEventMsg = WD.GetEventDescription(startEvent[1], startEvent[2], startEvent[3])
        local endEventMsg = WD.GetEventDescription(endEvent[1], endEvent[2], endEvent[3])
        return string.format(WD_TRACKER_RT_CUSTOM_DESC, startEventMsg, endEventMsg)
    end
    return ruleName..": not yet implemented"
end
