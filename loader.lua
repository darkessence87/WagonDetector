
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

function WD:LoadDefaultSpells(reload)
    local sz = 0
    for _ in pairs(self.db.profile.spell_db) do
        sz = sz + 1
    end

    if sz == 0 or reload then
        self.db.profile.spell_db = {
            [22703] = {["id"] = 22703,["group"] = "CONTROL",["category"] = "WARLOCK",},
            [368970] = {["id"] = 368970,["group"] = "KNOCKBACK",["category"] = "EVOKER",},
            [61391] = {["id"] = 61391,["group"] = "KNOCKBACK",["category"] = "DRUID",},
            [117952] = {["id"] = 117952,["group"] = "KNOCKBACK",["category"] = "MONK",},
            [111673] = {["id"] = 111673,["group"] = "CONTROL",["category"] = "DEATHKNIGHT",},
            [108199] = {["id"] = 108199,["group"] = "KNOCKBACK",["category"] = "DEATHKNIGHT",},
            [46968] = {["id"] = 46968,["group"] = "CONTROL",["category"] = "WARRIOR",},
            [393456] = {["id"] = 393456,["group"] = "ROOT",["category"] = "HUNTER",},
            [118] = {["id"] = 118,["group"] = "CONTROL",["category"] = "MAGE",},
            [122] = {["id"] = 122,["group"] = "ROOT",["category"] = "MAGE",},
            [91800] = {["id"] = 91800,["group"] = "CONTROL",["category"] = "DEATHKNIGHT",},
            [51399] = {["id"] = 51399,["group"] = "KNOCKBACK",["category"] = "DEATHKNIGHT",},
            [221562] = {["id"] = 221562,["group"] = "CONTROL",["category"] = "DEATHKNIGHT",},
            [20066] = {["id"] = 20066,["group"] = "CONTROL",["category"] = "PALADIN",},
            [371339] = {["id"] = 371339,["group"] = "FLASK",["category"] = "General",},
            [10326] = {["id"] = 10326,["group"] = "CONTROL",["category"] = "PALADIN",},
            [213691] = {["id"] = 213691,["group"] = "CONTROL",["category"] = "HUNTER",},
            [408] = {["id"] = 408,["group"] = "CONTROL",["category"] = "ROGUE",},
            [2094] = {["id"] = 2094,["group"] = "CONTROL",["category"] = "ROGUE",},
            [371152] = {["id"] = 371152,["group"] = "POTION",["category"] = "General",},
            [373257] = {["id"] = 373257,["group"] = "FLASK",["category"] = "General",},
            [31661] = {["id"] = 31661,["group"] = "CONTROL",["category"] = "MAGE",},
            [197214] = {["id"] = 197214,["group"] = "CONTROL",["category"] = "SHAMAN",},
            [371028] = {["id"] = 371028,["group"] = "POTION",["category"] = "General",},
            [117526] = {["id"] = 117526,["group"] = "CONTROL",["category"] = "HUNTER",},
            [5211] = {["id"] = 5211,["group"] = "CONTROL",["category"] = "DRUID",},
            [99] = {["id"] = 99,["group"] = "CONTROL",["category"] = "DRUID",},
            [371033] = {["id"] = 371033,["group"] = "POTION",["category"] = "General",},
            [5484] = {["id"] = 5484,["group"] = "CONTROL",["category"] = "WARLOCK",},
            [372245] = {["id"] = 372245,["group"] = "CONTROL",["category"] = "EVOKER",},
            [20549] = {["id"] = 20549,["group"] = "CONTROL",["category"] = "General",},
            [370652] = {["id"] = 370652,["group"] = "FLASK",["category"] = "General",},
            [316593] = {["id"] = 316593,["group"] = "CONTROL",["category"] = "WARRIOR",},
            [157980] = {["id"] = 157980,["group"] = "KNOCKBACK",["category"] = "MAGE",},
            [211881] = {["id"] = 211881,["group"] = "CONTROL",["category"] = "DEMONHUNTER",},
            [30283] = {["id"] = 30283,["group"] = "CONTROL",["category"] = "WARLOCK",},
            [5246] = {["id"] = 5246,["group"] = "CONTROL",["category"] = "WARRIOR",},
            [157981] = {["id"] = 157981,["group"] = "KNOCKBACK",["category"] = "MAGE",},
            [396092] = {["id"] = 396092,["group"] = "FOOD",["category"] = "General",},
            [198909] = {["id"] = 198909,["group"] = "CONTROL",["category"] = "MONK",},
            [1513] = {["id"] = 1513,["group"] = "CONTROL",["category"] = "HUNTER",},
            [236777] = {["id"] = 236777,["group"] = "KNOCKBACK",["category"] = "HUNTER",},
            [2637] = {["id"] = 2637,["group"] = "CONTROL",["category"] = "DRUID",},
            [6789] = {["id"] = 6789,["group"] = "CONTROL",["category"] = "WARLOCK",},
            [1833] = {["id"] = 1833,["group"] = "CONTROL",["category"] = "ROGUE",},
            [347008] = {["id"] = 347008,["group"] = "CONTROL",["category"] = "WARLOCK",},
            [9484] = {["id"] = 9484,["group"] = "CONTROL",["category"] = "PRIEST",},
            [207167] = {["id"] = 207167,["group"] = "CONTROL",["category"] = "DEATHKNIGHT",},
            [51490] = {["id"] = 51490,["group"] = "KNOCKBACK",["category"] = "SHAMAN",},
            [371172] = {["id"] = 371172,["group"] = "FLASK",["category"] = "General",},
            [204490] = {["id"] = 204490,["group"] = "SILENCE",["category"] = "DEMONHUNTER",},
            [51514] = {["id"] = 51514,["group"] = "CONTROL",["category"] = "SHAMAN",},
            [82691] = {["id"] = 82691,["group"] = "CONTROL",["category"] = "MAGE",},
            [378760] = {["id"] = 378760,["group"] = "ROOT",["category"] = "MAGE",},
            [78675] = {["id"] = 78675,["group"] = "SILENCE",["category"] = "DRUID",},
            [1776] = {["id"] = 1776,["group"] = "CONTROL",["category"] = "ROGUE",},
            [1330] = {["id"] = 1330,["group"] = "SILENCE",["category"] = "ROGUE",},
            [186387] = {["id"] = 186387,["group"] = "KNOCKBACK",["category"] = "HUNTER",},
            [102359] = {["id"] = 102359,["group"] = "ROOT",["category"] = "DRUID",},
            [179057] = {["id"] = 179057,["group"] = "CONTROL",["category"] = "DEMONHUNTER",},
            [605] = {["id"] = 605,["group"] = "CONTROL",["category"] = "PRIEST",},
            [203123] = {["id"] = 203123,["group"] = "CONTROL",["category"] = "DRUID",},
            [118345] = {["id"] = 118345,["group"] = "CONTROL",["category"] = "SHAMAN",},
            [119381] = {["id"] = 119381,["group"] = "CONTROL",["category"] = "MONK",},
            [255941] = {["id"] = 255941,["group"] = "CONTROL",["category"] = "PALADIN",},
            [8122] = {["id"] = 8122,["group"] = "CONTROL",["category"] = "PRIEST",},
            [377048] = {["id"] = 377048,["group"] = "CONTROL",["category"] = "DEATHKNIGHT",},
            [163505] = {["id"] = 163505,["group"] = "CONTROL",["category"] = "DRUID",},
            [370970] = {["id"] = 370970,["group"] = "ROOT",["category"] = "DEMONHUNTER",},
            [105421] = {["id"] = 105421,["group"] = "CONTROL",["category"] = "PALADIN",},
            [6358] = {["id"] = 6358,["group"] = "CONTROL",["category"] = "WARLOCK",},
            [370607] = {["id"] = 370607,["group"] = "POTION",["category"] = "General",},
            [370816] = {["id"] = 370816,["group"] = "POTION",["category"] = "General",},
            [207685] = {["id"] = 207685,["group"] = "CONTROL",["category"] = "DEMONHUNTER",},
            [371024] = {["id"] = 371024,["group"] = "POTION",["category"] = "General",},
            [385149] = {["id"] = 385149,["group"] = "CONTROL",["category"] = "PALADIN",},
            [107079] = {["id"] = 107079,["group"] = "CONTROL",["category"] = "General",},
            [77505] = {["id"] = 77505,["group"] = "CONTROL",["category"] = "SHAMAN",},
            [383121] = {["id"] = 383121,["group"] = "CONTROL",["category"] = "MAGE",},
            [305485] = {["id"] = 305485,["group"] = "CONTROL",["category"] = "SHAMAN",},
            [208674] = {["id"] = 208674,["group"] = "KNOCKBACK",["category"] = "DEMONHUNTER",},
            [393438] = {["id"] = 393438,["group"] = "RUNE",["category"] = "General",},
            [118905] = {["id"] = 118905,["group"] = "CONTROL",["category"] = "SHAMAN",},
            [64695] = {["id"] = 64695,["group"] = "ROOT",["category"] = "SHAMAN",},
            [200196] = {["id"] = 200196,["group"] = "CONTROL",["category"] = "PRIEST",},
            [324382] = {["id"] = 324382,["group"] = "CONTROL",["category"] = "MONK",},
            [200200] = {["id"] = 200200,["group"] = "CONTROL",["category"] = "PRIEST",},
            [316595] = {["id"] = 316595,["group"] = "CONTROL",["category"] = "WARRIOR",},
            [105771] = {["id"] = 105771,["group"] = "ROOT",["category"] = "WARRIOR",},
            [15487] = {["id"] = 15487,["group"] = "SILENCE",["category"] = "PRIEST",},
            [33786] = {["id"] = 33786,["group"] = "CONTROL",["category"] = "DRUID",},
            [64044] = {["id"] = 64044,["group"] = "CONTROL",["category"] = "PRIEST",},
            [228600] = {["id"] = 228600,["group"] = "ROOT",["category"] = "MAGE",},
            [116844] = {["id"] = 116844,["group"] = "KNOCKBACK",["category"] = "MONK",},
            [339] = {["id"] = 339,["group"] = "ROOT",["category"] = "DRUID",},
            [385954] = {["id"] = 385954,["group"] = "CONTROL",["category"] = "WARRIOR",},
            [118699] = {["id"] = 118699,["group"] = "CONTROL",["category"] = "WARLOCK",},
            [115078] = {["id"] = 115078,["group"] = "CONTROL",["category"] = "MONK",},
            [371386] = {["id"] = 371386,["group"] = "FLASK",["category"] = "General",},
            [374000] = {["id"] = 374000,["group"] = "FLASK",["category"] = "General",},
            [89766] = {["id"] = 89766,["group"] = "CONTROL",["category"] = "WARLOCK",},
            [3355] = {["id"] = 3355,["group"] = "CONTROL",["category"] = "HUNTER",},
            [357214] = {["id"] = 357214,["group"] = "KNOCKBACK",["category"] = "EVOKER",},
            [91797] = {["id"] = 91797,["group"] = "CONTROL",["category"] = "DEATHKNIGHT",},
            [217832] = {["id"] = 217832,["group"] = "CONTROL",["category"] = "DEMONHUNTER",},
            [360806] = {["id"] = 360806,["group"] = "CONTROL",["category"] = "EVOKER",},
            [157997] = {["id"] = 157997,["group"] = "ROOT",["category"] = "MAGE",},
            [710] = {["id"] = 710,["group"] = "CONTROL",["category"] = "WARLOCK",},
            [1098] = {["id"] = 1098,["group"] = "CONTROL",["category"] = "WARLOCK",},
            [358385] = {["id"] = 358385,["group"] = "ROOT",["category"] = "EVOKER",},
            [205364] = {["id"] = 205364,["group"] = "CONTROL",["category"] = "PRIEST",},
            [853] = {["id"] = 853,["group"] = "CONTROL",["category"] = "PALADIN",},
            [132169] = {["id"] = 132169,["group"] = "CONTROL",["category"] = "WARRIOR",},
            [190925] = {["id"] = 190925,["group"] = "ROOT",["category"] = "HUNTER",},
            [24394] = {["id"] = 24394,["group"] = "CONTROL",["category"] = "HUNTER",},
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
        WD:LoadDefaultSpells()
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
            autoTrackCombat = false,
            tracker = {
                selected = 0,
                selectedRule = "TOTAL_DONE",
            },
            spell_db = {},
            minGuildRank = {
                ["id"] = 0,
                ["name"] = "Unknown",
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
        if WD.db.profile.autoTrack == false and WD.db.profile.autoTrackCombat == false then
            self.mainFrame:StartPull()
        end
        WD:SendAddonMessage("block_encounter")
    elseif cmd == "pullstop" then
        if WD.db.profile.autoTrack == false and WD.db.profile.autoTrackCombat == false then
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