﻿
WD.mainFrame = CreateFrame("Frame")
local WDMF = WD.mainFrame
WDMF.encounter = {}
WDMF.encounter.isBlockedByAnother = 0

local currentRealmName = string.gsub(GetRealmName(), "%s+", "")
local playerName = UnitName("player") .. "-" .. currentRealmName

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

local function getActiveRulesForEncounter(encounterId)
    -- search journalId for encounter
    local journalId = WD.FindEncounterJournalIdByCombatId(encounterId)
    if not journalId then
        journalId = WD.FindEncounterJournalIdByName("ALL")
        print("Unknown name for encounterId:"..encounterId)
    end

    local rules = {
        ["EV_DAMAGETAKEN"] = {},    -- done
        ["EV_DEATH"] = {},            -- done
        ["EV_AURA"] = {{{}}},        -- done
        ["EV_AURA_STACKS"] = {},    -- done
        ["EV_CAST_START"] = {},        -- done
        ["EV_CAST_END"] = {},            -- done
        ["EV_CAST_INTERRUPTED"] = {},    -- done
        ["EV_DEATH_UNIT"] = {},        -- done
        ["EV_DISPEL"] = {},         -- done
        ["EV_POTIONS"] = {},        -- done
        ["EV_FLASKS"] = {},            -- done
        ["EV_FOOD"] = {},            -- done
        ["EV_RUNES"] = {},            -- done
    }

    for i=1,#WD.db.profile.rules do
        if WD.db.profile.rules[i].isActive == true and (WD.db.profile.rules[i].journalId == journalId or WD.db.profile.rules[i].journalId == -1) then
            local roles = WD:GetAllowedRoles(WD.db.profile.rules[i].role)
            local rType = WD.db.profile.rules[i].type
            local arg0 = WD.db.profile.rules[i].arg0
            local arg1 = WD.db.profile.rules[i].arg1
            local p = WD.db.profile.rules[i].points
            for _,role in pairs(roles) do
                if not rules[role] then rules[role] = {} end
                if not rules[role][rType] then rules[role][rType] = {} end
                if rType == "EV_DAMAGETAKEN" then
                    rules[role][rType][arg0] = {}
                    rules[role][rType][arg0].amount = arg1
                    rules[role][rType][arg0].points = p
                elseif rType == "EV_DEATH" or rType == "EV_DISPEL" then
                    rules[role][rType][arg0] = {}
                    rules[role][rType][arg0].points = p
                elseif rType == "EV_DEATH_UNIT" then
                    rules[role][rType].unit = arg0
                    rules[role][rType].points = p
                elseif rType == "EV_POTIONS" or rType == "EV_FLASKS" or rType == "EV_FOOD" or rType == "EV_RUNES" then
                    rules[role][rType].points = p
                else
                    if not rules[role][rType][arg0] then
                        rules[role][rType][arg0] = {}
                    end
                    if not rules[role][rType][arg0][arg1] then
                        rules[role][rType][arg0][arg1] = {}
                    end
                    rules[role][rType][arg0][arg1].points = p
                end
            end
        end
    end

    return rules
end

local function printFuckups()
    for _,v in pairs(WDMF.encounter.fuckers) do
        if v.points >= 0 then
            local fuckerName = getShortCharacterName(v.name)
            if v.mark > 0 then fuckerName = getRaidTargetTextureLink(v.mark).." "..fuckerName end
            if v.points == 0 then
                local msg = string.format(WD_PRINT_INFO, v.timestamp, fuckerName, v.reason)
                sendMessage(msg)
            else
                local msg = string.format(WD_PRINT_FAILURE, v.timestamp, fuckerName, v.reason, v.points)
                sendMessage(msg)
            end
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

function WDMF:AddSuccess(timestamp, name, mark, msg, points)
    if WDMF.encounter.deaths > WD.db.profile.maxDeaths then
        local t = getTimedDiff(WDMF.encounter.startTime, timestamp)
        if mark > 0 then name = getRaidTargetTextureLink(mark).." "..name end
        local txt = t.." "..name.." [NICE] "..msg
        print("Ignored success: "..txt)
        return
    end

    local niceBro = {}
    niceBro.encounter = WDMF.encounter.name
    niceBro.timestamp = getTimedDiff(WDMF.encounter.startTime, timestamp)
    niceBro.name = getFullCharacterName(name)
    niceBro.mark = mark
    niceBro.reason = msg
    niceBro.points = points
    niceBro.role = WD:GetRole(niceBro.name)
    WDMF.encounter.fuckers[#WDMF.encounter.fuckers+1] = niceBro

    if WDMF.encounter.isBlockedByAnother == 0 then
        if WD.db.profile.sendFailImmediately == true then

            local broName = getShortCharacterName(niceBro.name)
            if niceBro.mark > 0 then broName = getRaidTargetTextureLink(niceBro.mark).." "..broName end
            if niceBro.points == 0 then
                local txt = string.format(WD_PRINT_INFO, niceBro.timestamp, broName, niceBro.reason)
                sendMessage(txt)
            end

            WD:SavePenaltyPointsToGuildRoster(niceBro)
        end
    end

    WD:RefreshLastEncounterFrame()
end

function WDMF:AddFail(timestamp, name, mark, msg, points)
    if WDMF.encounter.deaths > WD.db.profile.maxDeaths then
        local t = getTimedDiff(WDMF.encounter.startTime, timestamp)
        if mark > 0 then name = getRaidTargetTextureLink(mark).." "..name end
        local txt = t.." "..name.." [FAIL] "..msg
        print("Ignored fuckup: "..txt)
        return
    end

    local fucker = {}
    fucker.encounter = WDMF.encounter.name
    fucker.timestamp = getTimedDiff(WDMF.encounter.startTime, timestamp)
    fucker.name = getFullCharacterName(name)
    fucker.mark = mark
    fucker.reason = msg
    fucker.points = points
    fucker.role = WD:GetRole(fucker.name)
    WDMF.encounter.fuckers[#WDMF.encounter.fuckers+1] = fucker

    if WDMF.encounter.isBlockedByAnother == 0 then
        if WD.db.profile.sendFailImmediately == true then
            local fuckerName = getShortCharacterName(fucker.name)
            if fucker.mark > 0 then fuckerName = getRaidTargetTextureLink(fucker.mark).." "..fuckerName end
            if fucker.points == 0 then
                local txt = string.format(WD_PRINT_INFO, fucker.timestamp, fuckerName, fucker.reason)
                sendMessage(txt)
            else
                local txt = string.format(WD_PRINT_FAILURE, fucker.timestamp, fuckerName, fucker.reason, fucker.points)
                sendMessage(txt)
            end

            WD:SavePenaltyPointsToGuildRoster(fucker)
        end
    end

    WD:RefreshLastEncounterFrame()
end

function WDMF:CheckConsumables(timestamp, name, unit, rules)
    local role = WD:GetRole(name)
    local noflask, nofood, norune = nil, nil, nil
    if rules[role] and rules[role]["EV_FLASKS"] then
        noflask = true
    end
    if rules[role] and rules[role]["EV_FOOD"] then
        nofood = true
    end
    if rules[role] and rules[role]["EV_RUNES"] then
        norune = true
    end

    for index=1,40 do
        local _, _, _, _, _, _, _, _, _, spellId = UnitBuff(unit, index)

        -- flasks
        if spellId and WD.FLASK_IDS[spellId] then
            noflask = false
        end

        -- food
        if spellId and WD.FOOD_IDS[spellId] then
            nofood = false
        end

        -- runes
        if spellId and WD.RUNE_IDS[spellId] then
            norune = false
        end
    end

    if noflask and noflask == true then
        self:AddFail(timestamp, name, 0, WD_RULE_FLASKS, rules[role]["EV_FLASKS"].points)
    end
    if nofood and nofood == true then
        self:AddFail(timestamp, name, 0, WD_RULE_FOOD, rules[role]["EV_FOOD"].points)
    end
    if norune and norune == true then
        self:AddFail(timestamp, name, 0, WD_RULE_RUNES, rules[role]["EV_RUNES"].points)
    end
end

function WDMF:OnUpdate()
    if WD.db.profile.isEnabled == true then
        self:RegisterEvent("CHAT_MSG_ADDON")

        if WD.db.profile.autoTrack == true then
            self:StartPull()
        else
            self:StopPull()
        end
    else
        self:StopPull()
        self:UnregisterEvent("CHAT_MSG_ADDON")
    end
end

function WDMF:OnCombatEvent(...)
    if self.encounter.interrupted == 1 then
        return
    end

    if not WDMF.encounter.rules then return end

    self:Tracker_OnEvent(...)
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

        if WD.db.profile.autoTrack == false then
            self:StopPull()
        end
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        self:OnCombatEvent(CombatLogGetCurrentEventInfo())
    elseif event == "CHAT_MSG_ADDON" then
        self:OnAddonMessage(...)
    end
end

function WDMF:StartEncounter(encounterID, encounterName)
    local pullId = 1
    if WD.db.profile.encounters[encounterName] then pullId = WD.db.profile.encounters[encounterName] + 1 end

    if UnitInRaid("player") ~= nil then
        sendMessage(string.format(WD_ENCOUNTER_START, encounterName, pullId, encounterID))
        WD:AddPullHistory(encounterName)

        self.encounter.id = encounterID
        self.encounter.name = date("%d/%m").." "..encounterName.." ("..pullId..")"
        self.encounter.startTime = time()
        self.encounter.rules = getActiveRulesForEncounter(self.encounter.id)
        self.encounter.players = {}

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
            p.guid = UnitGUID(p.unit)

            if UnitIsVisible(p.unit) then
                if WD.cache.raidroster[p.name] then
                    p.specId = WD.cache.raidroster[p.name].specId
                else
                    NotifyInspect(p.unit)
                end
                self.encounter.players[#self.encounter.players+1] = p
                self:CheckConsumables(self.encounter.startTime, p.name, p.unit, self.encounter.rules)
            end
        end
    elseif encounterName == "Test" then
        sendMessage(string.format(WD_ENCOUNTER_START, encounterName, pullId, encounterID))
        WD:AddPullHistory(encounterName)

        self.encounter.id = encounterID
        self.encounter.name = date("%d/%m").." "..encounterName.." ("..pullId..")"
        self.encounter.startTime = time()
        self.encounter.rules = getActiveRulesForEncounter(self.encounter.id)
        self.encounter.players = {}

        local _,class = UnitClass("player")

        local p = {}
        p.name = playerName
        p.unit = "player"
        p.class = class
        p.guid = UnitGUID(p.unit)
        if WD.cache.raidroster[p.name] then
            p.specId = WD.cache.raidroster[p.name].specId
        end

        self.encounter.players[#self.encounter.players+1] = p

        self:CheckConsumables(self.encounter.startTime, p.name, p.unit, self.encounter.rules)
    end

    if self.encounter.players then
        self:Tracker_OnStartEncounter(self.encounter.players)
    end
end

function WDMF:StopEncounter()
    if not self.encounter.startTime or self.encounter.startTime == 0 then return end
    if self.encounter.stopped == 1 then return end
    self.encounter.endTime = time()

    if self.encounter.isBlockedByAnother == 0 then
        if WD.db.profile.sendFailImmediately == false then
            printFuckups()
            saveFuckups()
        end

        -- save pull information
        if self.encounter.players then
            for _,v in pairs(self.encounter.players) do
                WD:SavePullsToGuildRoster(v)
            end
        end
        WD:RefreshGuildRosterFrame()
    end

    self.encounter.stopped = 1
    sendMessage(string.format(WD_ENCOUNTER_STOP, self.encounter.name, getTimedDiffShort(self.encounter.startTime, self.encounter.endTime)))

    self:Tracker_OnStopEncounter()

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

function WDMF:StartPull()
    self:RegisterEvent("ENCOUNTER_START")
    self:RegisterEvent("ENCOUNTER_END")
end

function WDMF:StopPull()
    self:UnregisterEvent("ENCOUNTER_START")
    self:UnregisterEvent("ENCOUNTER_END")
end

function WDMF:OnAddonMessage(msgId, msg, channel, sender)
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
            if WD.db.profile.autoTrack == false then
                WDMF:StartPull()
            end
        elseif cmd == "reset_encounter" then
            self.encounter.isBlockedByAnother = 0
            if WD.db.profile.autoTrack == false then
                WDMF:StopPull()
            end
        elseif cmd == "request_share_encounter" then
            WD:ReceiveSharedEncounter(sender, data)
        elseif cmd == "response_share_encounter" then
            WD:SendSharedEncounter(sender, data)
        elseif cmd == "receive_rule" then
            WD:ReceiveRequestedRule(sender, data)
        elseif cmd == "share_rule" then
            WD:ReceiveSharedRule(sender, data)
        end
    end
end

function WD:SendAddonMessage(cmd, data, target)
    if not cmd then return end
    if not data then data = "" end

    local channelType = "GUILD"
    if cmd == "block_encounter" or cmd == "reset_encounter" then
        WDMF.encounter.isBlockedByAnother = 0
        channelType = "RAID"
    end

    local msgId = "WDCM"
    local msg = cmd..":"..data
    if target then
        C_ChatInfo.SendAddonMessage(msgId, msg, "WHISPER", target)
    else
        C_ChatInfo.SendAddonMessage(msgId, msg, channelType)
    end
end

function WD:EnableConfig()
    if WD.db.profile.isEnabled == false then
        WDMF:RegisterEvent("CHAT_MSG_ADDON")

        if WD.db.profile.autoTrack == true then
            WDMF:StartPull()
        end

        WD.db.profile.isEnabled = true
        sendMessage(WD_ENABLED)
    else
        WDMF:StopPull()
        WDMF:UnregisterEvent("CHAT_MSG_ADDON")

        WD.db.profile.isEnabled = false
        sendMessage(WD_DISABLED)
    end
end
