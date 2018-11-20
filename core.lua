
WD.mainFrame = CreateFrame("Frame")
local WDMF = WD.mainFrame
WDMF.encounter = {}
WDMF.encounter.isBlockedByAnother = 0

if not WD.cache then WD.cache = {} end
WD.cache.raidroster = {}

local currentRealmName = string.gsub(GetRealmName(), "%s+", "")
local playerName = UnitName("player") .. "-" .. currentRealmName

encounterIDs = {
    [0] = "Test",
    [-1] = "ALL",
    [2144] = "UD_TALOC",
    [2141] = "UD_MOTHER",
    [2136] = "UD_ZEKVOZ",
    [-1] = "UD_VECTIS",
    [-1] = "UD_FETID",
    [-1] = "UD_ZUL",
    [-1] = "UD_MYTRAX",
    [2122] = "UD_GHUUN",
}

local ClassSpecializations = {
	["DEATHKNIGHT"] = {250, 251, 252},
	["DEMONHUNTER"] = {577, 581},
	["DRUID"]       = {102, 103, 104, 105},
	["HUNTER"]      = {253, 254, 255},
	["MAGE"]        = {62, 63, 64},
	["MONK"]        = {268, 269, 270},
	["PALADIN"]     = {65, 66, 70},
	["PRIEST"]      = {256, 257, 258},
	["ROGUE"]       = {259, 260, 261},
	["SHAMAN"]      = {262, 263, 264},
	["WARLOCK"]     = {265, 266, 267},
	["WARRIOR"]     = {71, 72, 73},
}

local RoleSpecializations = {
    ["TANK"]    = {250, 581, 104, 268, 66, 73},     -- 6
    ["HEALER"]  = {105, 270, 65, 256, 257, 264},    -- 6
    ["MELEE"]   = {251, 252, 577, 103, 255, 269, 70, 259, 260, 261, 263, 71, 72},   -- 13
    ["RANGED"]  = {102, 253, 254, 62, 63, 64, 258, 262, 265, 266, 267},             -- 11
}

local potionSpellIds = {
    [279151] = "/battle-potion-of-intellect",
    [279152] = "/battle-potion-of-agility",
    [279153] = "/battle-potion-of-strength",
    [229206] = "/potion-of-prolonged-power",
    [251316] = "/potion-of-bursting-blood",
    [269853] = "/potion-of-rising-death",
    [279154] = "/battle-potion-of-stamina",
}

local flaskSpellIds = {
    [251837] = "/flask-of-endless-fathoms",
    [251839] = "/flask-of-the-undertow",
    [251836] = "/flask-of-the-currents",
    [251838] = "/flask-of-the-vast-horizon",
}

local foodSpellIds = {
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

local runeSpellIds = {
    [270058] = "/battle-scarred-augmentation",
}

function getTimedDiff(startTime, endTime)
    if startTime == nil or endTime == nil then return end
    local dt = endTime - startTime
    if startTime > endTime then dt = -dt end
    local m = floor(dt / 60)
    dt = dt - m * 60
    local s = floor(dt)
    dt = dt - s
    local ms = dt * 1000
    local MIN = string.format("%02d", m)
    local SEC = string.format("%02d", s)
    local MSC = string.format("%003d", ms)
    return MIN .. ":" .. SEC .. "." .. MSC
end

function getTimedDiffShort(startTime, endTime)
    local dt = endTime - startTime
    local m = floor(dt / 60)
    dt = dt - m * 60
    local s = floor(dt)
    local MIN = string.format("%02d", m)
    local SEC = string.format("%02d", s)
    return MIN .. ":" .. SEC
end

local function getRoleBySpecId(specId)

    function isRoleEqual(specId, category)
        local t = RoleSpecializations[category]
        if not t then return false end
        for i=1,#t do
            if t[i] == specId then return true end
        end
        return false
    end

    if isRoleEqual(specId, "TANK") == true   then return "TANK" end
    if isRoleEqual(specId, "HEALER") == true then return "HEALER" end
    if isRoleEqual(specId, "MELEE") == true  then return "MELEE" end
    if isRoleEqual(specId, "RANGED") == true then return "RANGED" end

    return "Unknown"
end

local function getRole(name)
    local role = "Unknown"
    if not WD.cache.raidroster or not WD.cache.raidroster[name] then
        return role
    end

    local specId = WD.cache.raidroster[name].specId
    if specId == 0 then return role end

    return getRoleBySpecId(specId)
end

local function getActiveRulesForEncounter(encounterId)
    local encounterName = encounterIDs[encounterId]
    if not encounterName then
        print("Unknown name for encounterId:"..encounterId)
    end

    local rules = {
        ["EV_DAMAGETAKEN"] = {},    -- done
        ["EV_DEATH"] = {},            -- done
        ["EV_AURA"] = {{{}}},        -- done
        ["EV_AURA_STACKS"] = {},    -- done
        ["EV_START_CAST"] = {},        -- done
        ["EV_CAST"] = {},            -- done
        ["EV_INTERRUPTED_CAST"] = {},    -- done
        ["EV_DEATH_UNIT"] = {},        -- done
        ["EV_POTIONS"] = {},        -- done
        ["EV_FLASKS"] = {},            -- done
        ["EV_FOOD"] = {},            -- done
        ["EV_RUNES"] = {},            -- done
    }

    for i=1,#WD.db.profile.rules do
        if WD.db.profile.rules[i].isActive == true and (WD.db.profile.rules[i].encounter == encounterName or WD.db.profile.rules[i].encounter == "ALL") then
            local rType = WD.db.profile.rules[i].type
            local arg0 = WD.db.profile.rules[i].arg0
            local arg1 = WD.db.profile.rules[i].arg1
            local p = WD.db.profile.rules[i].points
            if rType == "EV_DAMAGETAKEN" then
                rules[rType][arg0] = {}
                rules[rType][arg0].amount = arg1
                rules[rType][arg0].points = p
            elseif rType == "EV_DEATH" then
                rules[rType][arg0] = p
            elseif rType == "EV_DEATH_UNIT" then
                rules[rType].unit = arg0
                rules[rType].points = p
            elseif rType == "EV_POTIONS" or rType == "EV_FLASKS" or rType == "EV_FOOD" or rType == "EV_RUNES" then
                rules[rType].points = p
            else
                if not rules[rType][arg0] then
                    rules[rType][arg0] = {}
                end
                rules[rType][arg0][arg1] = p
            end
        end
    end

    return rules
end

local function printFuckups()
    for _,v in pairs(WDMF.encounter.fuckers) do
        if v.points > 0 then
            local msg = string.format(WD_PRINT_FAILURE, v.timestamp, getShortCharacterName(v.name), v.reason, v.points)
            sendMessage(msg)
        end
    end
end

local function saveFuckups()
    if WD.cache.roster then
        for _,v in pairs(WDMF.encounter.fuckers) do
            WD:SavePenaltyPointsToGuildRoster(v)
        end
    end
    WD:RefreshGuildRosterFrame()
end

local function addSuccess(timestamp, name, msg, points)
    if WDMF.encounter.deaths > WD.db.profile.maxDeaths then
        local t = getTimedDiff(WDMF.encounter.startTime, timestamp)
        local txt = t.." "..name.." [NICE] "..msg
        print("Ignored success: "..txt)
        return
    end

    local niceBro = {}
    niceBro.encounter = WDMF.encounter.name
    niceBro.timestamp = getTimedDiff(WDMF.encounter.startTime, timestamp)
    niceBro.name = getFullCharacterName(name)
    niceBro.reason = msg
    niceBro.points = points
    niceBro.role = getRole(niceBro.name)
    WDMF.encounter.fuckers[#WDMF.encounter.fuckers+1] = niceBro

    if WDMF.encounter.isBlockedByAnother == 0 then
        if WD.db.profile.sendFailImmediately == true then
            WD:SavePenaltyPointsToGuildRoster(niceBro)
        end
    end

    WD:RefreshLastEncounterFrame()
end

local function addFail(timestamp, name, msg, points)
    if WDMF.encounter.deaths > WD.db.profile.maxDeaths then
        local t = getTimedDiff(WDMF.encounter.startTime, timestamp)
        local txt = t.." "..name.." [FAIL] "..msg
        print("Ignored fuckup: "..txt)
        return
    end

    local fucker = {}
    fucker.encounter = WDMF.encounter.name
    fucker.timestamp = getTimedDiff(WDMF.encounter.startTime, timestamp)
    fucker.name = getFullCharacterName(name)
    fucker.reason = msg
    fucker.points = points
    fucker.role = getRole(fucker.name)
    WDMF.encounter.fuckers[#WDMF.encounter.fuckers+1] = fucker

    if WDMF.encounter.isBlockedByAnother == 0 then
        if WD.db.profile.sendFailImmediately == true then
            local txt = string.format(WD_PRINT_FAILURE, fucker.timestamp, getShortCharacterName(fucker.name), fucker.reason, fucker.points)
            sendMessage(txt)

            WD:SavePenaltyPointsToGuildRoster(fucker)
        end
    end

    WD:RefreshLastEncounterFrame()
end

local function checkConsumables(timestamp, name, unit, rules)
    local noflask, nofood, norune = nil, nil, nil
    if rules["EV_FLASKS"].points then
        noflask = true
    end
    if rules["EV_FOOD"].points then
        nofood = true
    end
    if rules["EV_RUNES"].points then
        norune = true
    end

    for index=1,40 do
        local _, _, _, _, _, _, _, _, _, spellId = UnitBuff(unit, index)

        -- flasks
        if spellId and flaskSpellIds[spellId] then
            noflask = false
        end

        -- food
        if spellId and foodSpellIds[spellId] then
            nofood = false
        end

        -- runes
        if spellId and runeSpellIds[spellId] then
            norune = false
        end
    end

    if noflask and noflask == true then
        addFail(timestamp, name, WD_RULE_FLASKS, rules["EV_FLASKS"].points)
    end
    if nofood and nofood == true then
        addFail(timestamp, name, WD_RULE_FOOD, rules["EV_FOOD"].points)
    end
    if norune and norune == true then
        addFail(timestamp, name, WD_RULE_RUNES, rules["EV_RUNES"].points)
    end
end

local function getSpecialization(name, class, unit)
    local specId = nil
    if name == playerName then
        specId = GetSpecialization()
        if specId and ClassSpecializations[class][specId] then
            return ClassSpecializations[class][specId]
        end
    else
        return GetInspectSpecialization(unit)
    end

    return 0
end

local function updateRaidSpec()
    if UnitInRaid("player") ~= nil then
        for i=1, GetNumGroupMembers() do
            local unit = "raid"..i
            local name, realm = UnitName(unit)
            if not realm or realm == "" then
                realm = currentRealmName
            end
            local _,class = UnitClass(unit)

            local p = {}
            p.name = name.."-"..realm
            p.unit = unit
            p.class = class
            WD.cache.raidroster[p.name] = p

            if p.name == playerName then
                WD.cache.raidroster[p.name].specId = getSpecialization(p.name, p.class, p.unit)
            else
                NotifyInspect(unit)
            end
        end
    end
end

function WDMF:OnCombatEvent(...)
    if self.encounter.interrupted == 1 then
        return
    end

    local arg = {...}
    local timestamp, event, _, src_guid, src_name, src_flags, src_raid_flags, dst_guid, dst_name, dst_flags, dst_raid_flags, spell_id, spell_name, spell_school = ...

    local rules = WDMF.encounter.rules

    if event == "SPELL_AURA_APPLIED" and rules["EV_AURA"][spell_id] and rules["EV_AURA"][spell_id]["apply"] then
        local p = rules["EV_AURA"][spell_id]["apply"]
        addFail(timestamp, dst_name, string.format(WD_RULE_APPLY_AURA, getSpellLinkById(spell_id)), p)
    end

    if event == "SPELL_AURA_REMOVED" then
        if rules["EV_AURA"][spell_id] and rules["EV_AURA"][spell_id]["remove"] then
            local p = rules["EV_AURA"][spell_id]["remove"]
            addFail(timestamp, dst_name, string.format(WD_RULE_REMOVE_AURA, getSpellLinkById(spell_id)), p)
        end

        -- potions
        if rules["EV_POTIONS"].points then
            local role = getRole(dst_name)
            if (role == "DAMAGE" or role == "Unknown") and potionSpellIds[spell_id] then
                addSuccess(timestamp, dst_name, WD_RULE_POTIONS, rules["EV_POTIONS"].points)
            end
        end
    end

    if event == "SPELL_AURA_APPLIED_DOSE" then
        local stacks = tonumber(arg[16])
        if rules["EV_AURA_STACKS"][spell_id] and rules["EV_AURA_STACKS"][spell_id][stacks] then
            local p = rules["EV_AURA"][spell_id]["remove"][stacks]
            addFail(timestamp, dst_name, string.format(WD_RULE_AURA_STACKS, stacks, getSpellLinkById(spell_id)), p)
        end
    end

    if event == "SPELL_CAST_START" and rules["EV_START_CAST"][spell_id] and rules["EV_START_CAST"][spell_id][src_name] then
        local p = rules["EV_START_CAST"][spell_id][src_name]
        addSuccess(timestamp, src_name, string.format(WD_RULE_CAST_START, src_name, getSpellLinkById(spell_id)), p)
    end

    if event == "SPELL_CAST_SUCCESS" and rules["EV_CAST"][spell_id] and rules["EV_CAST"][spell_id][src_name] then
        local p = rules["EV_CAST"][spell_id][src_name]
        addSuccess(timestamp, src_name, string.format(WD_RULE_CAST, src_name, getSpellLinkById(spell_id)), p)
    end

    if event == "SPELL_INTERRUPT" then
        local target_spell_id = tonumber(arg[14])
        if rules["EV_INTERRUPTED_CAST"][target_spell_id] and rules["EV_INTERRUPTED_CAST"][target_spell_id][dst_name] then
            local p = rules["EV_CAST"][spell_id][dst_name]
            addSuccess(timestamp, src_name, string.format(WD_RULE_CAST_INTERRUPT, getSpellLinkById(spell_id)), src_name, p)
        end
    end

    if event == "SPELL_DAMAGE" then
        local death_rule = rules["EV_DEATH"][spell_id]
        local damagetaken_rule = rules["EV_DAMAGETAKEN"][spell_id]
        local amount, overkill = tonumber(arg[15]), tonumber(arg[16])

        local total = amount + overkill
        if overkill == 0 then total = total + 1 end

        if death_rule and overkill > -1 then
            local p = death_rule
            addFail(timestamp, dst_name, string.format(WD_RULE_DEATH, getSpellLinkById(spell_id)), p)
        elseif damagetaken_rule then
            local p = damagetaken_rule.points
            if damagetaken_rule.amount > 0 and total > damagetaken_rule.amount then
                addFail(timestamp, dst_name, string.format(WD_RULE_DAMAGE_TAKEN_AMOUNT, damagetaken_rule.amount, getSpellLinkById(spell_id)), p)
            elseif damagetaken_rule.amount == 0 and total > 0 then
                addFail(timestamp, dst_name, string.format(WD_RULE_DAMAGE_TAKEN, getSpellLinkById(spell_id)), p)
            end
        end
    end

    if event == "UNIT_DIED" then
        for i=1,#self.encounter.players do
            if self.encounter.players[i].name == getFullCharacterName(dst_name) then
                self.encounter.deaths = self.encounter.deaths + 1
                break
            end
        end

        if rules["EV_DEATH_UNIT"].unit == dst_name then
            addSuccess(timestamp, dst_name, string.format(WD_RULE_DEATH_UNIT, dst_name), rules["EV_DEATH_UNIT"].points)
        end
    end
end

function WDMF:OnEvent(event, ...)
    if event == "ENCOUNTER_START" then
        local encounterID, name = ...
        self:ResetEncounter()
        self:StartEncounter(encounterID, name)
        self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    elseif event == "ENCOUNTER_END" then
        self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        self:StopEncounter()
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        self:OnCombatEvent(CombatLogGetCurrentEventInfo())
    elseif event == "CHAT_MSG_ADDON" then
        self:OnAddonMessage(...)
    elseif event == "GROUP_ROSTER_UPDATE" then
        updateRaidSpec()
    elseif event == "PLAYER_ENTERING_WORLD" then
        updateRaidSpec()
    elseif event == "INSPECT_READY" then
        if not WD.cache.raidroster then return end
        local guid = ...
        local _,_,_,race,_,name,realm = GetPlayerInfoByGUID(guid)
        if not realm or realm == "" then
            realm = currentRealmName
        end
        name = name.."-"..realm
        if WD.cache.raidroster[name] then
            WD.cache.raidroster[name].specId = getSpecialization(name, WD.cache.raidroster[name].class, WD.cache.raidroster[name].unit)
        end
    end
end

function WDMF:StartEncounter(encounterID, encounterName)
    local pullId = 1
    if WD.db.profile.encounters[encounterName] then pullId = WD.db.profile.encounters[encounterName] + 1 end

    sendMessage(string.format(WD_ENCOUNTER_START, encounterName, pullId, encounterID))
    WD:AddPullHistory(encounterName)

    self.encounter.id = encounterID
    self.encounter.name = date("%d/%m").." "..encounterName.." ("..pullId..")"
    self.encounter.startTime = time()
    self.encounter.rules = getActiveRulesForEncounter(self.encounter.id)
    self.encounter.players = {}

    if UnitInRaid("player") ~= nil then
        for i=1, GetNumGroupMembers() do
            local unit = "raid"..i
            local name, realm = UnitName(unit)
            if not realm or realm == "" then
                realm = currentRealmName
            end
            local _,class = UnitClass(unit)

            local p = {}
            p.name = name.."-"..realm
            p.unit = unit
            p.class = class

            if UnitIsVisible(p.unit) then
                if WD.cache.raidroster[p.name] then
                    p.specId = WD.cache.raidroster[p.name].specId
                else
                    NotifyInspect(p.unit)
                end
                self.encounter.players[#self.encounter.players+1] = p
                checkConsumables(self.encounter.startTime, p.name, p.unit, self.encounter.rules)
            end
        end
    else
        local _,class = UnitClass("player")

        local p = {}
        p.name = playerName
        p.unit = "player"
        p.class = class
        WD.cache.raidroster[p.name] = p
        WD.cache.raidroster[p.name].specId = getSpecialization(p.name, p.class, p.unit)

        self.encounter.players[#self.encounter.players+1] = p

        checkConsumables(self.encounter.startTime, p.name, p.unit, self.encounter.rules)
    end
end

function WDMF:StopEncounter()
    if self.encounter.stopped == 1 then return end
    self.encounter.endTime = time()

    if self.encounter.isBlockedByAnother == 0 then
        if WD.db.profile.sendFailImmediately == false then
            printFuckups()
            saveFuckups()
        end

        -- save pull information
        if WD.cache.roster then
            for _,v in pairs(self.encounter.players) do
                WD:SavePullsToGuildRoster(v)
            end
        end
        WD:RefreshGuildRosterFrame()
    end

    self.encounter.stopped = 1
    sendMessage(string.format(WD_ENCOUNTER_STOP, self.encounter.name, getTimedDiffShort(self.encounter.startTime, self.encounter.endTime)))

    self.encounter.isBlockedByAnother = 0
end

function WDMF:ResetEncounter()
    self.encounter.name = ""
    self.encounter.startTime = 0
    self.encounter.endTime = 0
    self.encounter.fuckers = {}
    self.encounter.players = {}
    self.encounter.deaths = 0
    self.encounter.interrupted = 0
    self.encounter.stopped = 0
end

function WDMF:OnAddonMessage(msgId, msg, channel, sender)
    -- /dump WD:SendAddonMessage("cmd1", "data1")
    if msgId ~= "WDCM" then return end

    local cmd, data = string.match(msg, "^(.*):(.*)$")
    local receiver = playerName

    sender = getFullCharacterName(sender)

    if WD:IsOfficer(receiver) == false then
        print("You are not officer to receive message")
        return
    end

    if sender == receiver then
        --print("Testing purpose, will be ignored in release")
        return
    end

    if cmd then
        if cmd == "block_encounter" then
            self.encounter.isBlockedByAnother = 1
            print(string.format(WD_LOCKED_BY, sender))
        elseif cmd == "share_encounter" then
            local encounterName, str = string.match(data, "^(.*)$(.*)$")
            WD:ReceiveSharedEncounter(sender, encounterName, str)
        elseif cmd == "share_rule" then
            WD:ReceiveSharedRule(sender, data)
        end
    end
end

function WD:EnableConfig()
    if WD.db.profile.isEnabled == false then
        WDMF:RegisterEvent("CHAT_MSG_ADDON")
        WDMF:RegisterEvent("ENCOUNTER_START")
        WDMF:RegisterEvent("ENCOUNTER_END")
        WDMF:RegisterEvent("INSPECT_READY")
        WDMF:RegisterEvent("GROUP_ROSTER_UPDATE")

        WD.db.profile.isEnabled = true
        sendMessage(WD_ENABLED)
    else
        WDMF:UnregisterEvent("CHAT_MSG_ADDON")
        WDMF:UnregisterEvent("ENCOUNTER_START")
        WDMF:UnregisterEvent("ENCOUNTER_END")
        WDMF:UnregisterEvent("INSPECT_READY")
        WDMF:UnregisterEvent("GROUP_ROSTER_UPDATE")

        WD.db.profile.isEnabled = false
        sendMessage(WD_DISABLED)
    end
end

function WD:SendAddonMessage(cmd, data)
    if not cmd then return end
    if not data then data = "" end

    if cmd == "block_encounter" then
        WDMF.encounter.isBlockedByAnother = 0
    end

    local msgId = "WDCM"
    local msg = cmd..":"..data
    C_ChatInfo.SendAddonMessage(msgId, msg, "GUILD")
end
