
WD.TiersInfo = {}

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
