
local WDRO = nil

local WDRaidRosterModule = {}
WDRaidRosterModule.__index = WDRaidRosterModule

setmetatable(WDRaidRosterModule, {
    __index = WD.Module,
    __call = function (v, ...)
        local self = setmetatable({}, v)
        self:init(...)
        return self
    end,
})

if not WD.cache then WD.cache = {} end
WD.cache.raidroster = {}
WD.cache.raidrosterkeys = {}
WD.cache.raidrosterinspected = {}

local inspectProcessing = {}

local playerName = UnitName("player") .. "-" .. WD.CurrentRealmName

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
    ["EVOKER"]      = {1467, 1468},
}

local RoleSpecializations = {
    ["TANK"]    = {250, 581, 104, 268, 66, 73},        -- 6
    ["HEALER"]  = {105, 270, 65, 256, 257, 264, 1468}, -- 7
    ["MELEE"]   = {251, 252, 577, 103, 255, 269, 70, 259, 260, 261, 263, 71, 72},   -- 13
    ["RANGED"]  = {102, 253, 254, 62, 63, 64, 258, 262, 265, 266, 267, 1467},       -- 12
}

local function updateSpecIcon(parent, specId)
    if specId and specId ~= 0 then
        local _,_,_,icon = GetSpecializationInfoByID(specId)
        parent.icon.t:SetTexture(icon)
    end
end

local function createSpecIcon(parent, specId)
    parent.icon = CreateFrame("Button", nil, parent)
    parent.icon:SetSize(16, 16)
    parent.icon:SetPoint("TOPLEFT", parent, "TOPLEFT", 1, -2)
    parent.icon.t = WdLib.gui:createTexture(parent.icon, "Interface\\Icons\\INV_MISC_QUESTIONMARK", "ARTWORK")
    parent.icon.t:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    parent.icon.t:SetAllPoints()

    updateSpecIcon(parent, specId)
end

local function createBuffSlot(parent, index)
    if not parent.buffs then parent.buffs = {} end

    parent.buffs[index] = CreateFrame("Button", nil, parent)
    parent.buffs[index].t = WdLib.gui:createColorTexture(parent.buffs[index], "BACKGROUND", .2, .2, .2, 1)
    parent.buffs[index]:SetSize(16, 16)
    parent.buffs[index].t:SetAllPoints()
    parent.buffs[index].t:SetColorTexture(1, 0, 0, 1)
    parent.buffs[index].t:SetDrawLayer("ARTWORK")
    if index > 0 then
        parent.buffs[index]:SetPoint("TOPRIGHT", parent.buffs[index-1], "TOPLEFT", -1, 0)
    else
        parent.buffs[index]:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -1, -2)
    end
    parent.buffs[index]:SetScript("OnEnter", function(self)
        if self.spellId then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(WdLib.gui:getSpellLinkById(self.spellId))
            GameTooltip:AddLine('id: '..self.spellId, 1, 1, 1)
            GameTooltip:Show()
        end
    end)
    parent.buffs[index]:SetScript("OnLeave", function() GameTooltip_Hide() end)
end

local function setBuffSlotSpell(parent, index, spellId)
    parent.buffs[index].spellId = spellId
    if spellId then
        local _, _, icon = GetSpellInfo(spellId)
        parent.buffs[index].t:SetTexture(icon)
        parent.buffs[index].t:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    else
        parent.buffs[index].t:SetColorTexture(1, 0, 0, 1)
    end
    parent.buffs[index]:SetScript("OnEnter", function(self)
        if self.spellId then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(WdLib.gui:getSpellLinkById(self.spellId))
            GameTooltip:AddLine('id: '..self.spellId, 1, 1, 1)
            GameTooltip:Show()
        end
    end)
end

local function getConsumables(unit)
    local flask, food, rune = nil, nil, nil
    for index=1,40 do
        local _, _, _, _, _, _, _, _, _, spellId = UnitBuff(unit, index)

        -- flasks
        if spellId and WD.Spells.flasks[spellId] then
            flask = spellId
        end

        -- food
        if spellId and WD.Spells.food[spellId] then
            food = spellId
        end

        -- runes
        if spellId and WD.Spells.runes[spellId] then
            rune = spellId
        end
    end

    return flask, food, rune
end

local function requestInspect(p)
    if WdLib.gen:getShortName(p.name) == UNKNOWNOBJECT then return end
    NotifyInspect(p.name)
    if WD.cache.raidrosterinspected[p.guid] then
        WD.cache.raidrosterinspected[p.guid].lastTime = time()
    end

    inspectProcessing[p.guid] = {}
end

local function updateSpecialization(p)
    if not p then return end

    local specIndex = nil
    if p.name == playerName then
        specIndex = GetSpecialization()
        if specIndex then
            p.specId = GetSpecializationInfo(specIndex)
        end
    else
        local currTime = time()
        if WD.cache.raidrosterinspected[p.guid] then
            p.specId = WD.cache.raidrosterinspected[p.guid].specId
        else
            WD.cache.raidrosterinspected[p.guid] = {}
            WD.cache.raidrosterinspected[p.guid].lastTime = currTime - 5
            WD.cache.raidrosterinspected[p.guid].specId = 0
        end
        if (not p.specId or p.specId == 0) and CanInspect(p.unit) then
            if (currTime - WD.cache.raidrosterinspected[p.guid].lastTime) > 2 then
                if inspectProcessing[p.guid] then
                    return
                end
                requestInspect(p)
            end
        end
    end
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

local function updateRaidOverviewMember(data, parent)
    for k,n in pairs(data) do
        local v = WD.cache.raidroster[n]
        if not parent.members[k] then
            local member = CreateFrame("Frame", nil, parent.headers[1])
            member.info = v
            member:SetSize(parent.headers[1]:GetSize())
            member:SetPoint("TOPLEFT", parent.headers[1], "BOTTOMLEFT", 0, -1)
            member.column = {}

            local index = 1
            WdLib.gui:addNextColumn(parent, member, index, "LEFT", WdLib.gen:getColoredName(WdLib.gen:getShortName(v.name, "noRealm"), v.class))
            if k > 1 then
                member.column[index]:SetPoint("TOPLEFT", parent.members[k - 1], "BOTTOMLEFT", 0, -1)
                member:SetPoint("TOPLEFT", parent.members[k - 1], "BOTTOMLEFT", 0, -1)
            else
                member.column[index]:SetPoint("TOPLEFT", member, "TOPLEFT", 0, 0)
            end
            member.column[index]:EnableMouse(false)
            member.column[index].txt:SetPoint("LEFT", 20, 0)

            -- add buff frames
            createBuffSlot(member, 0)
            createBuffSlot(member, 1)
            createBuffSlot(member, 2)
            local flask, food, rune = getConsumables(v.unit)
            setBuffSlotSpell(member, 0, flask)
            setBuffSlotSpell(member, 1, food)
            setBuffSlotSpell(member, 2, rune)

            -- add specialization icon
            createSpecIcon(member, v.specId)

            parent.members[k] = member
        else
            local member = parent.members[k]
            member.info = v
            member.column[1].txt:SetText(WdLib.gen:getColoredName(WdLib.gen:getShortName(v.name, "noRealm"), v.class))

            -- update buff frames
            local flask, food, rune = getConsumables(v.unit)
            setBuffSlotSpell(member, 0, flask)
            setBuffSlotSpell(member, 1, food)
            setBuffSlotSpell(member, 2, rune)

            -- update specialization icon
            updateSpecIcon(member, v.specId)

            member:Show()
        end
    end

    if #data < #parent.members then
        for i=#data+1, #parent.members do
            parent.members[i]:Hide()
        end
    end
end

local function updateRaidOverviewFrame()
    -- sort by name
    local func = function(a, b)
        if not WD.cache.raidroster[a] or not WD.cache.raidroster[b] then return false end
        if WD.cache.raidroster[a].class and WD.cache.raidroster[b].class and WD.cache.raidroster[a].class < WD.cache.raidroster[b].class then
            return true
        elseif WD.cache.raidroster[a].class and WD.cache.raidroster[b].class and WD.cache.raidroster[a].class > WD.cache.raidroster[b].class then
            return false
        elseif WD.cache.raidroster[a].specId and WD.cache.raidroster[b].specId and WD.cache.raidroster[a].specId < WD.cache.raidroster[b].specId then
            return true
        elseif WD.cache.raidroster[a].specId and WD.cache.raidroster[b].specId and WD.cache.raidroster[a].specId > WD.cache.raidroster[b].specId then
            return false
        elseif WD.cache.raidroster[a].name < WD.cache.raidroster[b].name then
            return true
        elseif WD.cache.raidroster[a].name > WD.cache.raidroster[b].name then
            return false
        else
            return false
        end
    end

    table.sort(WD.cache.raidrosterkeys, func)

    local tanks, healers, melees, ranged, unknown = {}, {}, {}, {}, {}
    for k=1,#WD.cache.raidrosterkeys do
        local v = WD.cache.raidroster[WD.cache.raidrosterkeys[k]]
        local role = getRoleBySpecId(v.specId)
        if role == "TANK" then
            tanks[#tanks+1] = WD.cache.raidrosterkeys[k]
        elseif role == "HEALER" then
            healers[#healers+1] = WD.cache.raidrosterkeys[k]
        elseif role == "MELEE" then
            melees[#melees+1] = WD.cache.raidrosterkeys[k]
        elseif role == "RANGED" then
            ranged[#ranged+1] = WD.cache.raidrosterkeys[k]
        else
            unknown[#unknown+1] = WD.cache.raidrosterkeys[k]
        end
    end

    updateRaidOverviewMember(tanks, WDRO.tanks)
    updateRaidOverviewMember(healers, WDRO.healers)
    updateRaidOverviewMember(melees, WDRO.melees)
    updateRaidOverviewMember(ranged, WDRO.ranged)
    updateRaidOverviewMember(unknown, WDRO.unknown)
end

local function checkGroup(unitBase)
    for i=1, GetNumGroupMembers() do
        local unit = unitBase..i
        local guid = UnitGUID(unit)
        if not guid then return end
        local name = WdLib.gen:getUnitName(unit)
        local _,class = UnitClass(unit)

        if WD.cache.raidroster[guid] then
            WD.cache.raidroster[guid].name = name
            WD.cache.raidroster[guid].unit = unit
            WD.cache.raidroster[guid].class = class
        else
            local p = {}
            p.name = name
            p.unit = unit
            p.class = class
            p.guid = guid
            WD.cache.raidroster[p.guid] = p
            WD.cache.raidrosterkeys[#WD.cache.raidrosterkeys+1] = p.guid
        end
        updateSpecialization(WD.cache.raidroster[guid])
    end

    local onCompare = function(i,guid)
        local v = WD.cache.raidroster[guid]
        local unitNotInRaid = unitBase == "raid" and UnitInRaid(v.unit) == nil
        local unitNotInParty = unitBase == "party" and UnitInParty(v.unit) == false
        local unitIsOutdated = UnitGUID(v.unit) ~= guid
        if (unitNotInRaid and unitNotInParty) or unitIsOutdated then return true end
        return nil
    end
    local onErase = function(i,guid)
        WD.cache.raidroster[guid] = nil
        WD.cache.raidrosterinspected[guid] = nil
        inspectProcessing[guid] = nil
    end
    WdLib.table:erase(WD.cache.raidrosterkeys, onCompare, onErase)
end

local function checkSolo()
    local _,class = UnitClass("player")
    local p = {}
    p.name = playerName
    p.unit = "player"
    p.class = class
    p.guid = UnitGUID(p.unit)

    if not WD.cache.raidroster[p.guid] then
        WD.cache.raidrosterkeys[#WD.cache.raidrosterkeys+1] = p.guid
    end
    WD.cache.raidroster[p.guid] = p
    updateSpecialization(WD.cache.raidroster[p.guid])
end

local function resetRaidRoster()
    WdLib.table:wipe(WD.cache.raidrosterkeys)
    WdLib.table:wipe(WD.cache.raidroster)
    WdLib.table:wipe(inspectProcessing)
end

local function updateRaidRoster()
    if UnitInRaid("player") then
        checkGroup("raid")
    elseif UnitInParty("player") ~= false then
        checkGroup("party")
        checkSolo()
    else
        resetRaidRoster()
        checkSolo()
    end

    updateRaidOverviewFrame()
end

function WDRaidRosterModule:init(parent, yOffset)
    WD.Module.init(self, WD_BUTTON_RAID_OVERVIEW_MODULE, parent, yOffset)

    WDRO = self.frame

    WDRO.tanks = {}
    WDRO.tanks.headers = {}
    WDRO.tanks.members = {}
    WDRO.healers = {}
    WDRO.healers.headers = {}
    WDRO.healers.members = {}
    WDRO.melees = {}
    WDRO.melees.headers = {}
    WDRO.melees.members = {}
    WDRO.ranged = {}
    WDRO.ranged.headers = {}
    WDRO.ranged.members = {}
    WDRO.unknown = {}
    WDRO.unknown.headers = {}
    WDRO.unknown.members = {}

    table.insert(WDRO.tanks.headers,    WdLib.gui:createTableHeader(WDRO, "Tanks",      0, -30, 200, 20))
    table.insert(WDRO.healers.headers,  WdLib.gui:createTableHeader(WDRO, "Healers",  201, -30, 200, 20))
    table.insert(WDRO.melees.headers,   WdLib.gui:createTableHeader(WDRO, "Melee",    402, -30, 200, 20))
    table.insert(WDRO.ranged.headers,   WdLib.gui:createTableHeader(WDRO, "Ranged",   603, -30, 200, 20))
    table.insert(WDRO.unknown.headers,  WdLib.gui:createTableHeader(WDRO, "Unknown",  804, -30, 200, 20))

    WDRO:RegisterEvent("GROUP_ROSTER_UPDATE")
    WDRO:RegisterEvent("INSPECT_READY")
    WDRO:RegisterEvent("PLAYER_ENTERING_WORLD")
    WDRO:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    WDRO:RegisterEvent("READY_CHECK")
    WDRO:RegisterEvent("UNIT_NAME_UPDATE")

    WDRO:SetScript("OnEvent", function(self, event, ...)
        if event == "GROUP_ROSTER_UPDATE" then
            updateRaidRoster()
        elseif event == "UNIT_NAME_UPDATE" then
            local unit = ...
            for k,v in pairs(WD.cache.raidroster) do
                if v.unit == unit then
                    WD.cache.raidroster[v.guid].name = WdLib.gen:getUnitName(unit)
                    requestInspect(WD.cache.raidroster[v.guid])
                    break
                end
            end
            updateRaidOverviewFrame()
        elseif event == "INSPECT_READY" then
            local guid = ...
            if WD.cache.raidroster[guid] and WD.cache.raidrosterinspected[guid] then
                inspectProcessing[guid] = nil

                local t = WD.cache.raidroster[guid]
                WD.cache.raidrosterinspected[guid].specId = GetInspectSpecialization(t.unit)

                updateSpecialization(WD.cache.raidroster[guid])
                updateRaidOverviewFrame()
            end
        elseif event == "PLAYER_ENTERING_WORLD" then
            updateRaidRoster()
        elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
            updateRaidRoster()
        elseif event == "READY_CHECK" then
            updateRaidRoster()
        end
    end)
    WDRO:SetScript("OnShow", function(self) updateRaidRoster() end)

    function WDRO:OnUpdate()
        updateRaidRoster()
    end
end

function WD:GetRole(guid)
    local role = "Unknown"
    if not WD.cache.raidroster or not WD.cache.raidroster[guid] then
        return role
    end

    local specId = WD.cache.raidroster[guid].specId
    if specId == 0 then
        return role
    end

    return getRoleBySpecId(specId)
end

WD.RaidRosterModule = WDRaidRosterModule