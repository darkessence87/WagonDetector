
local WDGF = nil

WD.options.args.configButton = {
    name = "/cd config",
    type = "execute",
    func = function() WD:OpenConfig() end,
}

local modulesMap = {
    {"main",                    WD.MainModule},
    {"guild_roster",            WD.GuildRosterModule},
    {"raid_roster",             WD.RaidRosterModule},
    {"simple_rules",            WD.SimpleRulesModule},
    {"rules",                   WD.RulesModule},
    {"tracker_auras",           WD.Monitor1Module},
    {"tracker_casts",           WD.Monitor2Module},
    {"tracker_statistics",      WD.Monitor3Module},
    {"last_encounter",          WD.LastEncounterModule},
    {"history",                 WD.HistoryModule},
    {"help",                    WD.HelpModule},
}

function WD:CreateGuiFrame()
    -- gui frame
    self.guiFrame = CreateFrame("Frame", "WD.guiFrame", UIParent)
    WDGF = self.guiFrame
    WDGF.module = {}
    WDGF:SetSize(1200, 600)
    WDGF:SetPoint("CENTER", 0, 0)
    WDGF:SetFrameStrata("HIGH")
    -- default drag mode
    WDGF:EnableMouse(true)
    WDGF:SetScript("OnDragStart", WDGF.StartMoving)
    WDGF:SetScript("OnDragStop", WDGF.StopMovingOrSizing)
    -- WDGF background
    WDGF.bg = WdLib.gui:createColorTexture(WDGF, "BACKGROUND", .1, .1, .1, .99)
    WDGF.bg:SetAllPoints()
    -- icon
    WDGF.icon = WdLib.gui:createTexture(WDGF, [[Interface\AddOns\WagonDetector\media\textures\facepalm]], "ARTWORK")
    WDGF.icon:SetPoint("TOPLEFT", WDGF, "TOPLEFT", 1, -1)
    WDGF.icon:SetSize(33, 33)
    WDGF.icon:SetVertexColor(0, 1, 0, 1)

    -- temp, santa hat
    WDGF.iconex = WdLib.gui:createTexture(WDGF, [[Interface\AddOns\WagonDetector\media\textures\santa_hat]], "ARTWORK")
    WDGF.iconex:SetPoint("BOTTOM", WDGF.icon, "TOP", 4, -13)
    WDGF.iconex:SetSize(35, 35)
    WDGF.iconex:SetVertexColor(1, 0, 0, 1)

    -- text1
    WDGF.txt1 = WdLib.gui:createFontDefault(WDGF, "LEFT", "Wagon Detector")
    WDGF.txt1:SetFont([[Interface\AddOns\WagonDetector\media\fonts\ShadowsIntoLight.ttf]], 17, "")
    WDGF.txt1:SetPoint("LEFT", WDGF.icon, "RIGHT", 5, -5)
    WDGF.txt1:SetSize(200, 33)
    WDGF.txt1:SetVertexColor(0, 1, 0, 1)
    -- text2
    WDGF.txt2 = WdLib.gui:createFontDefault(WDGF, "LEFT", WD.Version)
    WDGF.txt2:SetFont([[Interface\AddOns\WagonDetector\media\fonts\ShadowsIntoLight.ttf]], 14, "")
    WDGF.txt2:SetPoint("LEFT", WDGF.icon, "RIGHT", 45, 10)
    WDGF.txt2:SetSize(200, 33)
    WDGF.txt2:SetVertexColor(1, 1, 1, 1)
    -- x button
    WDGF.xButton = WdLib.gui:createXButton(WDGF, 0)

    WDGF:RegisterEvent("PLAYER_ENTERING_WORLD")
    WDGF:RegisterEvent("GUILD_ROSTER_UPDATE")
    WDGF:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_ENTERING_WORLD" then
            WD:OnUpdate()

            -- modules frames
            local i, y, dy = 0, -35, -21
            for k,v in ipairs(modulesMap) do
                local moduleName, moduleCtor = v[1], v[2]
                WDGF.module[moduleName] = moduleCtor(WDGF, y + i * dy)
                i = i + 1
            end

            WDGF:HideModules()
            WDGF:UnregisterEvent("PLAYER_ENTERING_WORLD")
        elseif event == "GUILD_ROSTER_UPDATE" then
            if #WD.cache.guildranks ~= 0 then
                WDGF:UnregisterEvent("GUILD_ROSTER_UPDATE")
            end
            WDGF:OnUpdate()
        end
    end)
    WDGF:SetScript("OnShow", function(self)
        if self:IsEventRegistered("GUILD_ROSTER_UPDATE") then
            C_GuildInfo.GuildRoster()
        end
    end)

    C_GuildInfo.GuildRoster()
    WDGF:Hide()

    if WD.db.profile.isLocked == false then
        WDGF:RegisterForDrag("LeftButton")
        WDGF:SetMovable(true)
    else
        WDGF:RegisterForDrag()
        WDGF:SetMovable(false)
    end

    function WDGF:HideModules()
        for _,v in pairs(WDGF.module) do
            v.button.t:SetColorTexture(.2, .2, .2, 1)
            v.frame:Hide()
        end
    end

    function WDGF:OnUpdate()
        for _,v in pairs(WDGF.module) do
            v.frame:OnUpdate()
        end
    end
end

function WD:OpenConfig()
    WDGF:Show()
end
