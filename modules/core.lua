
-- init core frame
WD.mainFrame = CreateFrame("Frame")
local WDMF = WD.mainFrame
WDMF.isActive = 0
WDMF.isBlockedByAnother = 0
WDMF.encounter = {}
WDMF.MRTCache = {}
WDMF.MRTCache.armorkits = {}
WDMF.MRTCache.oils = {}
WDMF.MRTCache.oils2 = {}

-- init pet's owner scanner
CreateFrame("GameTooltip", "WdPetScanner", nil, "GameTooltipTemplate")
WDMF.scanner = _G.WdPetScanner
WDMF.scanner.line1 = _G["WdPetScannerTextLeft1"]
WDMF.scanner.line2 = _G["WdPetScannerTextLeft2"]

CreateFrame("GameTooltip", "WdItemScanner", nil, "GameTooltipTemplate")
WDMF.itemScanner = _G.WdItemScanner
WDMF.itemScanner:SetOwner(UIParent, "ANCHOR_NONE")

local playerName = UnitName("player") .. "-" .. WD.CurrentRealmName

local function printFuckups()
    for _,v in pairs(WDMF.encounter.fuckers) do
        if v.points >= 0 then
            local fuckerName = WdLib.gen:getShortName(v.name)
            if v.mark > 0 then fuckerName = WdLib.gui:getRaidTargetTextureLink(v.mark).." "..fuckerName end
            if v.points == 0 then
                local msg = string.format(WD_PRINT_INFO, v.timestamp, fuckerName, v.reason)
                WdLib.gen:sendMessage(msg)
            else
                local msg = string.format(WD_PRINT_FAILURE, v.timestamp, fuckerName, v.reason, v.points)
                WdLib.gen:sendMessage(msg)
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

local function debugEvent(event, ...)
    if WD.DebugEnabled == false then return end
    local info = ChatTypeInfo["COMBAT_MISC_INFO"];
    local message = event
    for i = 1, select("#", ...) do
        message = message..", "..tostring(select(i, ...));
    end
    ChatFrame1:AddMessage(message, info.r, info.g, info.b);
end

function WDMF:AddSuccess(timestamp, guid, mark, msg, points)
    if not WD.cache.raidroster[guid] then return end
    local name = WD.cache.raidroster[guid].name
    if self.encounter.deaths > WD.db.profile.maxDeaths then
        local t = WdLib.gen:getTimedDiff(self.encounter.startTime, timestamp)
        if mark > 0 then name = WdLib.gui:getRaidTargetTextureLink(mark).." "..name end
        local txt = t.." "..name.." [NICE] "..msg
        print("Ignored success: "..txt)
        return
    end

    local niceBro = {}
    niceBro.encounter = self.encounter.name
    niceBro.timestamp = WdLib.gen:getTimedDiff(self.encounter.startTime, timestamp)
    niceBro.name = WdLib.gen:getFullName(name)
    niceBro.mark = mark
    niceBro.reason = msg
    niceBro.points = tonumber(points) or 0
    niceBro.role = WD:GetRole(guid)
    self.encounter.fuckers[#self.encounter.fuckers+1] = niceBro

    if self.isBlockedByAnother == 0 then
        if WD.db.profile.sendFailImmediately == true then

            local broName = WdLib.gen:getShortName(niceBro.name)
            if niceBro.mark > 0 then broName = WdLib.gui:getRaidTargetTextureLink(niceBro.mark).." "..broName end
            if niceBro.points == 0 then
                local txt = string.format(WD_PRINT_INFO, niceBro.timestamp, broName, niceBro.reason)
                WdLib.gen:sendMessage(txt)
            end

            WD:SavePenaltyPointsToGuildRoster(niceBro)
        end
    end

    WD:RefreshLastEncounterFrame()
end

function WDMF:AddFail(timestamp, guid, mark, msg, points)
    if not WD.cache.raidroster[guid] then return end
    local name = WD.cache.raidroster[guid].name
    if self.encounter.deaths > WD.db.profile.maxDeaths then
        local t = WdLib.gen:getTimedDiff(self.encounter.startTime, timestamp)
        if mark > 0 then name = WdLib.gui:getRaidTargetTextureLink(mark).." "..name end
        local txt = t.." "..name.." [FAIL] "..msg
        print("Ignored fuckup: "..txt)
        return
    end

    local fucker = {}
    fucker.encounter = self.encounter.name
    fucker.timestamp = WdLib.gen:getTimedDiff(self.encounter.startTime, timestamp)
    fucker.name = WdLib.gen:getFullName(name)
    fucker.mark = mark
    fucker.reason = msg
    fucker.points = tonumber(points) or 0
    fucker.role = WD:GetRole(guid)
    self.encounter.fuckers[#self.encounter.fuckers+1] = fucker

    if self.isBlockedByAnother == 0 then
        if WD.db.profile.sendFailImmediately == true then
            local fuckerName = WdLib.gen:getShortName(fucker.name)
            if fucker.mark > 0 then fuckerName = WdLib.gui:getRaidTargetTextureLink(fucker.mark).." "..fuckerName end
            if fucker.points == 0 then
                local txt = string.format(WD_PRINT_INFO, fucker.timestamp, fuckerName, fucker.reason)
                WdLib.gen:sendMessage(txt)
            else
                local txt = string.format(WD_PRINT_FAILURE, fucker.timestamp, fuckerName, fucker.reason, fucker.points)
                WdLib.gen:sendMessage(txt)
            end

            WD:SavePenaltyPointsToGuildRoster(fucker)
        end
    end

    WD:RefreshLastEncounterFrame()
end

function WDMF:OnUpdate()
    if #WD.db.profile.tracker > 0 and WD.db.profile.tracker.selected and WD.db.profile.tracker.selected > 0 then
        WDMF.tracker = WD.db.profile.tracker[WD.db.profile.tracker.selected]
    end

    if WD.db.profile.isEnabled == true then
        self:RegisterEvent("CHAT_MSG_ADDON")

        if WD.db.profile.autoTrack == true or WD.db.profile.autoTrackCombat == true then
            self:StartPull(WD.db.profile.autoTrackCombat)
        else
            self:StopPull()
        end
    else
        self:StopPull()
        self:UnregisterEvent("CHAT_MSG_ADDON")
    end
end

local NAMEPLATE_EVENTS = {
    ["NAME_PLATE_CREATED"] = "",
    ["FORBIDDEN_NAME_PLATE_CREATED"] = "",
    ["NAME_PLATE_UNIT_ADDED"] = "",
    ["FORBIDDEN_NAME_PLATE_UNIT_ADDED"] = "",
    ["NAME_PLATE_UNIT_REMOVED"] = "",
    ["FORBIDDEN_NAME_PLATE_UNIT_REMOVED"] = ""
}

function WDMF:OnEvent(event, ...)
    if event == "ENCOUNTER_START" then
        debugEvent(event, ...)
        local encounterID, name, difficulty = ...
        self:ResetEncounter()
        self:StartEncounter(encounterID, name, difficulty)
        self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        self:RegisterEvent("UNIT_PET")
        for ev in pairs(NAMEPLATE_EVENTS) do
            self:RegisterEvent(ev)
        end
    elseif event == "ENCOUNTER_END" then
        debugEvent(event, ...)
        local _,_,_,_,isKill = ...
        for ev in pairs(NAMEPLATE_EVENTS) do
            self:UnregisterEvent(ev)
        end
        self:UnregisterEvent("UNIT_PET")
        self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        self:StopEncounter(isKill)

        if WD.db.profile.autoTrack == false then
            self:StopPull()
        end
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        if self.encounter.interrupted == 0 and self.isActive == 1 then
            self:Tracker_OnEvent(CombatLogGetCurrentEventInfo())
        end
    elseif event == "CHAT_MSG_ADDON" then
        self:OnAddonMessage(...)
    elseif event == "UNIT_PET" then
        local petUnitId = ...
        self:UpdateRaidMember(petUnitId)
    elseif NAMEPLATE_EVENTS[event] then
        self:Tracker_OnNameplateEvent(event, ...)
    elseif event == "PLAYER_REGEN_DISABLED" then
        debugEvent(event, ...)
        self:ResetEncounter()
        self:StartEncounter(0, "Combat", 10)
        self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        self:RegisterEvent("UNIT_PET")
        for ev in pairs(NAMEPLATE_EVENTS) do
            self:RegisterEvent(ev)
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        debugEvent(event, ...)
        for ev in pairs(NAMEPLATE_EVENTS) do
            self:UnregisterEvent(ev)
        end
        self:UnregisterEvent("UNIT_PET")
        self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
        self:StopEncounter()

        if WD.db.profile.autoTrackCombat == false then
            self:StopPull()
        end
    end
end

function WDMF:IsEncounterValid(encounterId)
    if WD.DebugEnabled == true then return true end
    if UnitInRaid("player") == nil and UnitInParty("player") == false and encounterId ~= 0 then return nil end
    return true
end

function WDMF:StartEncounter(encounterID, encounterName, difficulty)
    local pullId = 1
    if WD.db.profile.encounters[encounterName] and
       type(WD.db.profile.encounters[encounterName]) == "table" and
       WD.db.profile.encounters[encounterName][difficulty]
    then
        pullId = WD.db.profile.encounters[encounterName][difficulty] + 1
    end

    if self:IsEncounterValid(encounterID) then
        WdLib.gen:sendMessage(string.format(WD_ENCOUNTER_START, encounterName, pullId, encounterID))
        WD:AddPullHistory(encounterName, difficulty)

        self.isActive = 1

        self.encounter.id = encounterID
        self.encounter.encounterName = encounterName

        local mode = WdLib.gen:getDifficultyName(difficulty)
        if mode then
            encounterName = "("..mode..") "..encounterName
        end
        self.encounter.pullName = encounterName.."-"..pullId
        self.encounter.name = date("%d/%m").." "..encounterName.." ("..pullId..")"
        self.encounter.startTime = GetTime()

        self:Tracker_OnStartEncounter()
    end
end

function WDMF:StopEncounter()
    if self.isActive == 0 then return end

    self.encounter.endTime = GetTime()

    if self.isBlockedByAnother == 0 then
        if WD.db.profile.sendFailImmediately == false then
            printFuckups()
            saveFuckups()
        end

        -- save pull information
        if WD.db.profile.tracker.players then
            for _,v in pairs(WD.db.profile.tracker.players) do
                WD:SavePullsToGuildRoster(v)
            end
        end
        WD:RefreshGuildRosterFrame()
    end

    self:Tracker_OnStopEncounter()

    self.isActive = 0
    self.isBlockedByAnother = 0

    WdLib.gen:sendMessage(string.format(WD_ENCOUNTER_STOP, self.encounter.name, WdLib.gen:getTimedDiffShort(self.encounter.startTime, self.encounter.endTime)))

    WD.db.profile.MRTCache = self.MRTCache
end

function WDMF:ResetEncounter()
    WdLib.table:wipe(self.encounter)

    self.encounter.rules = {}
    self.encounter.statRules = {}
    self.encounter.fuckers = {}
    self.isActive = 0

    self.encounter.name = ""
    self.encounter.startTime = 0
    self.encounter.endTime = 0
    self.encounter.deaths = 0
    self.encounter.interrupted = 0
end

function WDMF:StartPull(isCombatTrack)
    self:Init()
    if not isCombatTrack or isCombatTrack == false then
        self:RegisterEvent("ENCOUNTER_START")
        self:RegisterEvent("ENCOUNTER_END")
        self:UnregisterEvent("PLAYER_REGEN_ENABLED")
        self:UnregisterEvent("PLAYER_REGEN_DISABLED")
    else
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
        self:RegisterEvent("PLAYER_REGEN_DISABLED")
        self:UnregisterEvent("ENCOUNTER_START")
        self:UnregisterEvent("ENCOUNTER_END")
    end
end

function WDMF:StopPull()
    self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    self:UnregisterEvent("ENCOUNTER_START")
    self:UnregisterEvent("ENCOUNTER_END")
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    self:UnregisterEvent("PLAYER_REGEN_DISABLED")
end

function WDMF:OnMRTMessage(sender, cmd, type, ver, ...)
    if cmd == "raidcheck" and type == "DUR" then
        if sender then
            local val = ...
            val = tonumber(val or "100") or 100

            --local shortName = WdLib.gen:getShortName(sender)
            for i=2, select('#', ...), 2 do
                local key,val = select(i, ...)
                if key == "KIT" then
                    self.MRTCache.armorkits[sender] = 0
                elseif key == "KITT" then
                    if self.MRTCache.armorkits[sender] then
                        self.MRTCache.armorkits[sender] = val
                    end
                elseif key == "OIL" then
                    self.MRTCache.oils[sender] = val
                elseif key == "OIL2" then
                    self.MRTCache.oils2[sender] = val
                end
            end
        end
    end

    if cmd == "raidcheckreq" and sender and playerName == sender then
        function OilCheck()
            local OIL_SLOTS = {
                16,	--INVSLOT_MAINHAND
                17,	--INVSLOT_OFFHAND
            }
            local oilTypes = {
                {GetSpellInfo(320798),320798},
                {GetSpellInfo(321389),321389},
                {GetSpellInfo(322762),322762},
                {GetSpellInfo(322763),322763},
                {GetSpellInfo(295623),33757},
                {GetSpellInfo(194084),318038},
                {WD_RaidCheckOilSharpen,322762},
                {WD_RaidCheckOilSharpen2,322763},
            }

            for i=#oilTypes,1,-1 do
                if not oilTypes[i][1] then
                    tremove(oilTypes,i)
                end
            end

            local oilMH, oilOH = 0, 0
            for _,itemSlotId in pairs(OIL_SLOTS) do
                self.itemScanner:SetInventoryItem("player", itemSlotId)
                for j=2, self.itemScanner:NumLines() do
                    local tooltipLine = _G["WdItemScannerTextLeft"..j]
                    local text = tooltipLine:GetText()
                    local isBreak
                    if text and text ~= "" then
                        for i=1,#oilTypes do
                            if text:find("^"..oilTypes[i][1]) then
                                if itemSlotId == 16 then
                                    oilMH = oilTypes[i][2]
                                elseif itemSlotId == 17 then
                                    oilOH = oilTypes[i][2]
                                end
                                isBreak = true
                                break
                            end
                        end
                    end
                    if isBreak then
                        break
                    end
                end
                self.itemScanner:ClearLines()
            end
            return oilMH, oilOH
        end

        function ArmorKitCheck()
            local KitSlots = {
                5,	--INVSLOT_CHEST
                --7,	--INVSLOT_LEGS
                --10,	--INVSLOT_HAND
                --8,	--INVSLOT_FEET
            }
            local L_EncName = "^"..WD_RaidCheckReinforced
            local locale = GetLocale()
            if locale ~= "ruRU" and locale ~= "enGB" and locale ~= "enUS" then
                L_EncName = "%(%+%d+[^%)]+%) %(%d+"
            end

            local kitType = 0
            for _,itemSlotId in pairs(KitSlots) do
                self.itemScanner:SetInventoryItem("player", itemSlotId)
                for j=2, self.itemScanner:NumLines() do
                    local tooltipLine = _G["WdItemScannerTextLeft"..j]
                    local text = tooltipLine:GetText()
                    if text and text ~= "" then
                        if text:find(L_EncName) then
                            local stats = text:match("%d+")
                            if stats == "32" then
                                kitType = 172347
                            elseif stats == "16" then
                                kitType = 172346
                            elseif stats == "24" then
                                kitType = 180709
                            end
                            break
                        end
                    end
                end
                self.itemScanner:ClearLines()
            end
            return kitType
        end

        local oilMH, oilOH = OilCheck()
        local kitType = ArmorKitCheck()
        self.MRTCache.oils[playerName] = oilMH
        self.MRTCache.oils2[playerName] = oilOH
        self.MRTCache.armorkits[playerName] = kitType
    end
end

function WDMF:OnAddonMessage(msgId, msg, channel, sender)
    if msgId == "EXRTADD" then
        self:OnMRTMessage(sender, strsplit("\t", msg))
        return
    end
    if msgId ~= "WDCM" then return end

    local cmd, data = string.match(msg, "^(.*):(.*)$")
    local receiver = playerName

    sender = WdLib.gen:getFullName(sender)

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
            self.isBlockedByAnother = 1
            print(string.format(WD_LOCKED_BY, sender))
            if WD.db.profile.autoTrack == false and WD.db.profile.autoTrackCombat == false then
                self:StartPull(false)
            end
        elseif cmd == "reset_encounter" then
            self.isBlockedByAnother = 0
            if WD.db.profile.autoTrack == false and WD.db.profile.autoTrackCombat == false then
                self:StopPull()
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
        WDMF.isBlockedByAnother = 0
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

        if WD.db.profile.autoTrack == true or WD.db.profile.autoTrackCombat == true then
            WDMF:StartPull(WD.db.profile.autoTrackCombat)
        end

        WD.db.profile.isEnabled = true
        WdLib.gen:sendMessage(WD_ENABLED)
    else
        WDMF:StopPull()
        WDMF:UnregisterEvent("CHAT_MSG_ADDON")

        WD.db.profile.isEnabled = false
        WdLib.gen:sendMessage(WD_DISABLED)
    end
end
