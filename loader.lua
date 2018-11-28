
WD = LibStub("AceAddon-3.0"):NewAddon("Wagon Detector", "AceEvent-3.0", "AceConsole-3.0")

WD.cache = {}

-- basic menu
WD.options = {
    name = "Wagon Detector",
    handler = WD,
    type = "group",
    get = function(key) return self.db.profile[key[1]] end,
    set = function(key, value) self.db.profile[key[1]] = value; end,
    args = {},
}

function WD:OnInitialize()
    self:LoadDefaults()

    LibStub("AceConfig-3.0"):RegisterOptionsTable("WD", self.options)
    self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("WD", "Wagon Detector")

    self.db = LibStub("AceDB-3.0"):New("WD_DB", self.defaults, true)
    self.db.RegisterCallback(self, "OnProfileChanged", "OnProfileChanged")
    self.db.RegisterCallback(self, "OnProfileCopied", "OnProfileCopied")
    self.db.RegisterCallback(self, "OnProfileReset", "OnProfileReset")

    LibStub("AceConfig-3.0"):RegisterOptionsTable("WD-Profiles", LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db))
    self.profileFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("WD-Profiles", "Profiles", "Wagon Detector")

    SLASH_WD1 = "/wd"
    SlashCmdList["WD"] = function(...) self:SlashHandler(...) end

    self:CreateGuiFrame()
    C_ChatInfo.RegisterAddonMessagePrefix("WDCM")

    if self.mainFrame then
        if WD.db.profile.isEnabled == true then
            self.mainFrame:RegisterEvent("CHAT_MSG_ADDON")

            if WD.db.profile.autoTrack == true then
                self.mainFrame:StartPull()
            end
        end

        self.mainFrame:SetScript("OnEvent", function(self, ...) self:OnEvent(...); end)
    end

    self:OnUpdate()
end

local function loadDefaultRules(self)
    if #self.db.profile.rules == 0 then
        self:ReceiveRequestedRule("default", "e3R5cGU9IkVWX0ZPT0QiLHJvbGU9IkFOWSIsYXJnMT0iIixlbmNvdW50ZXI9IkFMTCIscG9pbnRzPTEsaXNBY3RpdmU9dHJ1ZSxhcmcwPSIifQ==")
        self:ReceiveRequestedRule("default", "e3R5cGU9IkVWX0ZMQVNLUyIscm9sZT0iQU5ZIixhcmcxPSIiLGVuY291bnRlcj0iQUxMIixwb2ludHM9MSxpc0FjdGl2ZT10cnVlLGFyZzA9IiJ9")
        self:ReceiveRequestedRule("default", "e3R5cGU9IkVWX1JVTkVTIixyb2xlPSJBTlkiLGFyZzE9IiIsZW5jb3VudGVyPSJBTEwiLHBvaW50cz0xLGlzQWN0aXZlPXRydWUsYXJnMD0iIn0=")
        self:ReceiveRequestedRule("default", "e3R5cGU9IkVWX1BPVElPTlMiLHJvbGU9IkFOWSIsYXJnMT0iIixlbmNvdW50ZXI9IkFMTCIscG9pbnRzPS0xLGlzQWN0aXZlPXRydWUsYXJnMD0iIn0=")
    end
end

function WD:OnUpdate()

    -- reload history
    for i=1, #self.db.profile.history do
        self.db.profile.history[i].index = i
    end

    -- reload rules
    for i=1, #self.db.profile.rules do
        if not self.db.profile.rules[i].role then self.db.profile.rules[i].role = "ANY" end
        if not self.db.profile.rules[i].journalId or not tonumber(self.db.profile.rules[i].journalId) then
            local journalId = WD.FindEncounterJournalIdByNameMigration(self.db.profile.rules[i].encounter) or -1
            self.db.profile.rules[i].journalId = journalId
            self.db.profile.rules[i].encounter = WD.EncounterNames[journalId]
        else
            self.db.profile.rules[i].encounter = WD.EncounterNames[self.db.profile.rules[i].journalId]
        end
    end

    if self.guiFrame then
        loadDefaultRules(self)
        self.guiFrame:OnUpdate()
    end
    if self.mainFrame then
        self.mainFrame:OnUpdate()
    end
end

function WD:LoadDefaults()
    self.defaults = {
        profile = {
            isEnabled = false,
            isLocked = false,
            rules = {},
            chat = "PRINT",
            history = {},
            sendFailImmediately = true,
            enablePenalties = false,
            maxDeaths = 5,
            encounters = {},
            autoTrack = true,
        }
    }
end

function WD:OnProfileChanged()
    self:OnUpdate()
end

function WD:OnProfileCopied()
    self:OnUpdate()
end

function WD:OnProfileReset()
    self:LoadDefaults()
    self.db.profile = self.defaults.profile
    self:OnUpdate()
end

function WD:SlashHandler(msg, box)
    msg = string.lower(msg)
    cmd, tail = string.match(msg, "^%s*(%a+)%s*(.*)$");

    if cmd == "config" then
        self:OpenConfig()
    elseif cmd == "starttest" then
        self.mainFrame:OnEvent("ENCOUNTER_START", 0, "Test")
    elseif cmd == "stoptest" then
        self.mainFrame:OnEvent("ENCOUNTER_END")
    elseif cmd == "wipe" then
        self:ResetGuildStatistics()
    elseif cmd == "interrupt" then
        self.mainFrame.encounter.interrupted = 1
        print(WD_ENCOUNTER_INTERRUPTED)
    elseif cmd == "pull" then
        if WD.db.profile.autoTrack == false then
            self.mainFrame:StartPull()
        end
        WD:SendAddonMessage("block_encounter")
    elseif cmd == "pullstop" then
        if WD.db.profile.autoTrack == false then
            self.mainFrame:StopPull()
        end
        WD:SendAddonMessage("reset_encounter")
    elseif cmd == "clear" then
        WD:ClearHistory()
    else
        print(WD_HELP)
        self:OpenConfig()
    end
end