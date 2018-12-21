
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

    self:OnUpdate()
end

local function loadDefaultRules(self)
    if #self.db.profile.rules == 0 then
        self:ReceiveRequestedRule("default", "e3R5cGU9IkVWX1JVTkVTIixqb3VybmFsSWQ9LTEsZW5jb3VudGVyPSJBTEwiLGlzQWN0aXZlPXRydWUscm9sZT0iQU5ZIix2ZXJzaW9uPSJ2MC4wLjI0IixhcmcxPSIiLHBvaW50cz0xLGFyZzA9IiJ9")
        self:ReceiveRequestedRule("default", "e3R5cGU9IkVWX0ZPT0QiLGpvdXJuYWxJZD0tMSxlbmNvdW50ZXI9IkFMTCIsaXNBY3RpdmU9dHJ1ZSxyb2xlPSJBTlkiLHZlcnNpb249InYwLjAuMjQiLGFyZzE9IiIscG9pbnRzPTEsYXJnMD0iIn0=")
        self:ReceiveRequestedRule("default", "e3R5cGU9IkVWX0ZMQVNLUyIsam91cm5hbElkPS0xLGVuY291bnRlcj0iQUxMIixpc0FjdGl2ZT10cnVlLHJvbGU9IkFOWSIsdmVyc2lvbj0idjAuMC4yNCIsYXJnMT0iIixwb2ludHM9MSxhcmcwPSIifQ==")
        self:ReceiveRequestedRule("default", "e3R5cGU9IkVWX1BPVElPTlMiLGpvdXJuYWxJZD0tMSxlbmNvdW50ZXI9IkFMTCIsaXNBY3RpdmU9dHJ1ZSxyb2xlPSJBTlkiLHZlcnNpb249InYwLjAuMjQiLGFyZzE9IiIscG9pbnRzPS0xLGFyZzA9IiJ9")
    end
end

function WD:OnUpdate()
    WD:LoadTiers()

    -- reload history
    for i=1, #self.db.profile.history do
        self.db.profile.history[i].index = i
    end

    -- reload rules
    for i=1, #self.db.profile.rules do
        if not self.db.profile.rules[i].role then self.db.profile.rules[i].role = "ANY" end
        if not self.db.profile.rules[i].journalId or not tonumber(self.db.profile.rules[i].journalId) then
            local journalId = -1
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
        self.mainFrame:SetScript("OnEvent", function(self, ...) self:OnEvent(...); end)
        self.mainFrame:OnUpdate()
    end
end

function WD:LoadDefaults()
    self.defaults = {
        profile = {
            isEnabled = false,
            isLocked = false,
            rules = {},
            statRules = {},
            chat = "PRINT",
            history = {},
            sendFailImmediately = true,
            enablePenalties = false,
            maxDeaths = 5,
            encounters = {},
            autoTrack = true,
            tracker = {
                selected = 0,
                selectedRule = "TOTAL_DONE",
            },
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
    elseif cmd == "startunittest" then
        WD:_StartUnitTest(tail)
    else
        print(WD_HELP)
        self:OpenConfig()
    end
end