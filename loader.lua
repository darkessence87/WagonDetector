
WdLib = {}
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

local function loadDefaultSpells(self)
    local sz = 0
    for _ in pairs(self.db.profile.spell_db) do
        sz = sz + 1
    end

    if sz == 0 then
        self.db.profile.spell_db = {
            [307496] = {["id"] = 307496,["group"] = "POTION",["category"] = "General",},
            [853] = {["id"] = 853,["group"] = "CONTROL",["category"] = "PALADIN",},
            [307497] = {["id"] = 307497,["group"] = "POTION",["category"] = "General",},
            [360806] = {["id"] = 360806,["group"] = "CONTROL",["category"] = "EVOKER",},
            [308514] = {["id"] = 308514,["group"] = "FOOD",["category"] = "General",},
            [20066] = {["id"] = 20066,["group"] = "CONTROL",["category"] = "PALADIN",},
            [157980] = {["id"] = 157980,["group"] = "KNOCKBACK",["category"] = "MAGE",},
            [115078] = {["id"] = 115078,["group"] = "CONTROL",["category"] = "MONK",},
            [24394] = {["id"] = 24394,["group"] = "CONTROL",["category"] = "HUNTER",},
            [111673] = {["id"] = 111673,["group"] = "CONTROL",["category"] = "DEATHKNIGHT",},
            [5211] = {["id"] = 5211,["group"] = "CONTROL",["category"] = "DRUID",},
            [157981] = {["id"] = 157981,["group"] = "KNOCKBACK",["category"] = "MAGE",},
            [157997] = {["id"] = 157997,["group"] = "ROOT",["category"] = "MAGE",},
            [31661] = {["id"] = 31661,["group"] = "CONTROL",["category"] = "MAGE",},
            [221562] = {["id"] = 221562,["group"] = "CONTROL",["category"] = "DEATHKNIGHT",},
            [211004] = {["id"] = 211004,["group"] = "CONTROL",["category"] = "SHAMAN",},
            [89766] = {["id"] = 89766,["group"] = "CONTROL",["category"] = "WARLOCK",},
            [277784] = {["id"] = 277784,["group"] = "CONTROL",["category"] = "SHAMAN",},
            [368970] = {["id"] = 368970,["group"] = "KNOCKBACK",["category"] = "EVOKER",},
            [307185] = {["id"] = 307185,["group"] = "FLASK",["category"] = "General",},
            [307495] = {["id"] = 307495,["group"] = "POTION",["category"] = "General",},
            [1098] = {["id"] = 1098,["group"] = "CONTROL",["category"] = "WARLOCK",},
            [3355] = {["id"] = 3355,["group"] = "CONTROL",["category"] = "HUNTER",},
            [198813] = {["id"] = 198813,["group"] = "KNOCKBACK",["category"] = "DEMONHUNTER",},
            [308488] = {["id"] = 308488,["group"] = "FOOD",["category"] = "General",},
            [277778] = {["id"] = 277778,["group"] = "CONTROL",["category"] = "SHAMAN",},
            [710] = {["id"] = 710,["group"] = "CONTROL",["category"] = "WARLOCK",},
            [307187] = {["id"] = 307187,["group"] = "FLASK",["category"] = "General",},
            [6358] = {["id"] = 6358,["group"] = "CONTROL",["category"] = "WARLOCK",},
            [217832] = {["id"] = 217832,["group"] = "CONTROL",["category"] = "DEMONHUNTER",},
            [51490] = {["id"] = 51490,["group"] = "KNOCKBACK",["category"] = "SHAMAN",},
            [200196] = {["id"] = 200196,["group"] = "CONTROL",["category"] = "PRIEST",},
            [210873] = {["id"] = 210873,["group"] = "CONTROL",["category"] = "SHAMAN",},
            [108199] = {["id"] = 108199,["group"] = "KNOCKBACK",["category"] = "DEATHKNIGHT",},
            [207167] = {["id"] = 207167,["group"] = "CONTROL",["category"] = "DEATHKNIGHT",},
            [322302] = {["id"] = 322302,["group"] = "POTION",["category"] = "General",},
            [372245] = {["id"] = 372245,["group"] = "CONTROL",["category"] = "EVOKER",},
            [107079] = {["id"] = 107079,["group"] = "CONTROL",["category"] = "General",},
            [190925] = {["id"] = 190925,["group"] = "ROOT",["category"] = "HUNTER",},
            [1513] = {["id"] = 1513,["group"] = "CONTROL",["category"] = "HUNTER",},
            [117526] = {["id"] = 117526,["group"] = "CONTROL",["category"] = "HUNTER",},
            [327701] = {["id"] = 327701,["group"] = "FOOD",["category"] = "General",},
            [307159] = {["id"] = 307159,["group"] = "POTION",["category"] = "General",},
            [383121] = {["id"] = 383121,["group"] = "CONTROL",["category"] = "MAGE",},
            [393456] = {["id"] = 393456,["group"] = "ROOT",["category"] = "HUNTER",},
            [152175] = {["id"] = 152175,["group"] = "KNOCKBACK",["category"] = "MONK",},
            [211881] = {["id"] = 211881,["group"] = "CONTROL",["category"] = "DEMONHUNTER",},
            [307192] = {["id"] = 307192,["group"] = "POTION",["category"] = "General",},
            [213691] = {["id"] = 213691,["group"] = "CONTROL",["category"] = "HUNTER",},
            [105421] = {["id"] = 105421,["group"] = "CONTROL",["category"] = "PALADIN",},
            [307161] = {["id"] = 307161,["group"] = "POTION",["category"] = "General",},
            [307193] = {["id"] = 307193,["group"] = "POTION",["category"] = "General",},
            [339] = {["id"] = 339,["group"] = "ROOT",["category"] = "DRUID",},
            [20549] = {["id"] = 20549,["group"] = "CONTROL",["category"] = "General",},
            [307162] = {["id"] = 307162,["group"] = "POTION",["category"] = "General",},
            [307194] = {["id"] = 307194,["group"] = "POTION",["category"] = "General",},
            [186387] = {["id"] = 186387,["group"] = "KNOCKBACK",["category"] = "HUNTER",},
            [51399] = {["id"] = 51399,["group"] = "KNOCKBACK",["category"] = "DEATHKNIGHT",},
            [307163] = {["id"] = 307163,["group"] = "POTION",["category"] = "General",},
            [1833] = {["id"] = 1833,["group"] = "CONTROL",["category"] = "ROGUE",},
            [327704] = {["id"] = 327704,["group"] = "FOOD",["category"] = "General",},
            [378760] = {["id"] = 378760,["group"] = "ROOT",["category"] = "MAGE",},
            [308434] = {["id"] = 308434,["group"] = "FOOD",["category"] = "General",},
            [211010] = {["id"] = 211010,["group"] = "CONTROL",["category"] = "SHAMAN",},
            [347008] = {["id"] = 347008,["group"] = "CONTROL",["category"] = "WARLOCK",},
            [327707] = {["id"] = 327707,["group"] = "FOOD",["category"] = "General",},
            [307165] = {["id"] = 307165,["group"] = "POTION",["category"] = "General",},
            [228600] = {["id"] = 228600,["group"] = "ROOT",["category"] = "MAGE",},
            [327706] = {["id"] = 327706,["group"] = "FOOD",["category"] = "General",},
            [347901] = {["id"] = 347901,["group"] = "RUNE",["category"] = "General",},
            [200200] = {["id"] = 200200,["group"] = "CONTROL",["category"] = "PRIEST",},
            [377048] = {["id"] = 377048,["group"] = "CONTROL",["category"] = "DEATHKNIGHT",},
            [255941] = {["id"] = 255941,["group"] = "CONTROL",["category"] = "PALADIN",},
            [327709] = {["id"] = 327709,["group"] = "FOOD",["category"] = "General",},
            [2637] = {["id"] = 2637,["group"] = "CONTROL",["category"] = "DRUID",},
            [64044] = {["id"] = 64044,["group"] = "CONTROL",["category"] = "PRIEST",},
            [327708] = {["id"] = 327708,["group"] = "FOOD",["category"] = "General",},
            [33786] = {["id"] = 33786,["group"] = "CONTROL",["category"] = "DRUID",},
            [236777] = {["id"] = 236777,["group"] = "KNOCKBACK",["category"] = "HUNTER",},
            [5246] = {["id"] = 5246,["group"] = "CONTROL",["category"] = "WARRIOR",},
            [118345] = {["id"] = 118345,["group"] = "CONTROL",["category"] = "SHAMAN",},
            [118699] = {["id"] = 118699,["group"] = "CONTROL",["category"] = "WARLOCK",},
            [102359] = {["id"] = 102359,["group"] = "ROOT",["category"] = "DRUID",},
            [307164] = {["id"] = 307164,["group"] = "POTION",["category"] = "General",},
            [197214] = {["id"] = 197214,["group"] = "CONTROL",["category"] = "SHAMAN",},
            [269352] = {["id"] = 269352,["group"] = "CONTROL",["category"] = "SHAMAN",},
            [203123] = {["id"] = 203123,["group"] = "CONTROL",["category"] = "DRUID",},
            [51514] = {["id"] = 51514,["group"] = "CONTROL",["category"] = "SHAMAN",},
            [15487] = {["id"] = 15487,["group"] = "CONTROL",["category"] = "PRIEST",},
            [385149] = {["id"] = 385149,["group"] = "CONTROL",["category"] = "PALADIN",},
            [179057] = {["id"] = 179057,["group"] = "CONTROL",["category"] = "DEMONHUNTER",},
            [605] = {["id"] = 605,["group"] = "CONTROL",["category"] = "PRIEST",},
            [9484] = {["id"] = 9484,["group"] = "CONTROL",["category"] = "PRIEST",},
            [119381] = {["id"] = 119381,["group"] = "CONTROL",["category"] = "MONK",},
            [30283] = {["id"] = 30283,["group"] = "CONTROL",["category"] = "WARLOCK",},
            [358385] = {["id"] = 358385,["group"] = "ROOT",["category"] = "EVOKER",},
            [308506] = {["id"] = 308506,["group"] = "FOOD",["category"] = "General",},
            [99] = {["id"] = 99,["group"] = "CONTROL",["category"] = "DRUID",},
            [118] = {["id"] = 118,["group"] = "CONTROL",["category"] = "MAGE",},
            [2094] = {["id"] = 2094,["group"] = "CONTROL",["category"] = "ROGUE",},
            [82691] = {["id"] = 82691,["group"] = "CONTROL",["category"] = "MAGE",},
            [408] = {["id"] = 408,["group"] = "CONTROL",["category"] = "ROGUE",},
            [307166] = {["id"] = 307166,["group"] = "FLASK",["category"] = "General",},
            [211015] = {["id"] = 211015,["group"] = "CONTROL",["category"] = "SHAMAN",},
            [10326] = {["id"] = 10326,["group"] = "CONTROL",["category"] = "PALADIN",},
            [327705] = {["id"] = 327705,["group"] = "FOOD",["category"] = "General",},
            [78675] = {["id"] = 78675,["group"] = "CONTROL",["category"] = "DRUID",},
            [205364] = {["id"] = 205364,["group"] = "CONTROL",["category"] = "PRIEST",},
            [91800] = {["id"] = 91800,["group"] = "CONTROL",["category"] = "DEATHKNIGHT",},
            [5484] = {["id"] = 5484,["group"] = "CONTROL",["category"] = "WARLOCK",},
            [357214] = {["id"] = 357214,["group"] = "KNOCKBACK",["category"] = "EVOKER",},
            [1776] = {["id"] = 1776,["group"] = "CONTROL",["category"] = "ROGUE",},
            [307494] = {["id"] = 307494,["group"] = "POTION",["category"] = "General",},
            [122] = {["id"] = 122,["group"] = "ROOT",["category"] = "MAGE",},
            [22703] = {["id"] = 22703,["group"] = "CONTROL",["category"] = "WARLOCK",},
            [61391] = {["id"] = 61391,["group"] = "KNOCKBACK",["category"] = "DRUID",},
            [8122] = {["id"] = 8122,["group"] = "CONTROL",["category"] = "PRIEST",},
            [6789] = {["id"] = 6789,["group"] = "CONTROL",["category"] = "WARLOCK",},
            [91797] = {["id"] = 91797,["group"] = "CONTROL",["category"] = "DEATHKNIGHT",},
            [163505] = {["id"] = 163505,["group"] = "CONTROL",["category"] = "DRUID",},
        }
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
        loadDefaultSpells(self)
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
            spell_db = {},
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

function WD:getChatType(toSay)
	local isInInstance = IsInGroup(LE_PARTY_CATEGORY_INSTANCE)
	local isInParty = IsInGroup()
	local isInRaid = IsInRaid()
	local playerName = nil
	local chat_type = (isInInstance and "INSTANCE_CHAT") or (isInRaid and "RAID") or (isInParty and "PARTY")
	if not chat_type and not toSay then
		chat_type = "WHISPER"
		playerName = UnitName("player")
	elseif not chat_type then
		chat_type = "SAY"
	end
	return chat_type, playerName
end

function WD:SlashHandler(msg, box)
    msg = string.lower(msg)
    cmd, tail = string.match(msg, "^%s*(%a+)%s*(.*)$")

    if cmd == "config" then
        self:OpenConfig()
    elseif cmd == "starttest" then
        self:OnGuildRosterUpdate()
        self.mainFrame:Init()
        self.mainFrame:OnEvent("ENCOUNTER_START", 0, "Test", 10, 10)
    elseif cmd == "stoptest" then
        self.mainFrame:OnEvent("ENCOUNTER_END", 0, "Test", 10, 10, 1)
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
    elseif cmd == "requestmrtdata" then
        C_ChatInfo.SendAddonMessage("EXRTADD", "raidcheckreq\tREQ\t1", self.getChatType(false))
    else
        print(WD_HELP)
        self:OpenConfig()
    end
end