
WD.TiersInfo = {}

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
