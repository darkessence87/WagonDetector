
local WDRO = nil

if not WD.cache then WD.cache = {} end
WD.cache.raidroster = {}
WD.cache.raidrosterkeys = {}
WD.cache.raidrosterinspected = {}

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
}

local RoleSpecializations = {
    ["TANK"]    = {250, 581, 104, 268, 66, 73},     -- 6
    ["HEALER"]  = {105, 270, 65, 256, 257, 264},    -- 6
    ["MELEE"]   = {251, 252, 577, 103, 255, 269, 70, 259, 260, 261, 263, 71, 72},   -- 13
    ["RANGED"]  = {102, 253, 254, 62, 63, 64, 258, 262, 265, 266, 267},             -- 11
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
    parent.icon.t = WdLib:createTexture(parent.icon, "Interface\\Icons\\INV_MISC_QUESTIONMARK", "ARTWORK")
    parent.icon.t:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    parent.icon.t:SetAllPoints()

    updateSpecIcon(parent, specId)
end

local function createBuffSlot(parent, index)
    if not parent.buffs then parent.buffs = {} end

    parent.buffs[index] = CreateFrame("Button", nil, parent)
    parent.buffs[index].t = WdLib:createColorTexture(parent.buffs[index], "BACKGROUND", .2, .2, .2, 1)
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
            GameTooltip:SetHyperlink(WdLib:getSpellLinkById(self.spellId))
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
            GameTooltip:SetHyperlink(WdLib:getSpellLinkById(self.spellId))
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

local function updateSpecialization(p)
    if not p then return end

    local specId = nil
    if p.name == playerName then
        specId = GetSpecialization()
        if specId and ClassSpecializations[p.class][specId] then
            p.specId = ClassSpecializations[p.class][specId]
        end
    else
        if WD.cache.raidrosterinspected[p.guid] then
            p.specId = WD.cache.raidrosterinspected[p.guid]
        end
        if (not p.specId or p.specId == 0) and CanInspect(p.unit) then
            print("NotifyInspect "..p.unit)
            NotifyInspect(p.unit)
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

    if isRoleEqual(specId, "TANK") == true   then return "Tank" end
    if isRoleEqual(specId, "HEALER") == true then return "Healer" end
    if isRoleEqual(specId, "MELEE") == true  then return "Melee" end
    if isRoleEqual(specId, "RANGED") == true then return "Ranged" end

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
            WdLib:addNextColumn(parent, member, index, "LEFT", WdLib:getColoredName(WdLib:getShortCharacterName(v.name, "noRealm"), v.class))
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
            member.column[1].txt:SetText(WdLib:getColoredName(WdLib:getShortCharacterName(v.name, "noRealm"), v.class))

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
        if role == "Tank" then
            tanks[#tanks+1] = WD.cache.raidrosterkeys[k]
        elseif role == "Healer" then
            healers[#healers+1] = WD.cache.raidrosterkeys[k]
        elseif role == "Melee" then
            melees[#melees+1] = WD.cache.raidrosterkeys[k]
        elseif role == "Ranged" then
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
        local name = WdLib:getUnitName(unit)
        local _,class = UnitClass(unit)

        local p = {}
        p.name = name
        p.unit = unit
        p.class = class
        p.guid = guid

        if not WD.cache.raidroster[p.guid] then
            WD.cache.raidrosterkeys[#WD.cache.raidrosterkeys+1] = p.guid
        end
        WD.cache.raidroster[p.guid] = p
        updateSpecialization(WD.cache.raidroster[p.guid])
    end
    
    for i=1,#WD.cache.raidrosterkeys do
        local guid = WD.cache.raidrosterkeys[i]
        local v = WD.cache.raidroster[guid]
        if unitBase == "raid" and UnitInRaid(v.unit) == nil then
            WD.cache.raidroster[guid] = nil
            WD.cache.raidrosterinspected[guid] = nil
            table.remove(WD.cache.raidrosterkeys, i)
            i = i - 1
        elseif unitBase == "party" and UnitInParty(v.unit) == false then
            WD.cache.raidrosterinspected[guid] = nil
            WD.cache.raidroster[guid] = nil
            table.remove(WD.cache.raidrosterkeys, i)
            i = i - 1
        end
    end
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
    WdLib:table_wipe(WD.cache.raidrosterkeys)
    WdLib:table_wipe(WD.cache.raidroster)
end

local function updateRaidRoster()
    if UnitInRaid("player") then
        checkGroup("raid")
    elseif UnitInParty("player") ~= false then
        checkGroup("party")
        checkSolo()
    else
        checkSolo()
    end
    
    updateRaidOverviewFrame()
end

function WD:InitRaidOverviewModule(parent)
    WDRO = parent

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

    table.insert(WDRO.tanks.headers,    WdLib:createTableHeader(WDRO, "Tanks",    0,   -30, 200, 20))
    table.insert(WDRO.healers.headers,  WdLib:createTableHeader(WDRO, "Healers",  201, -30, 200, 20))
    table.insert(WDRO.melees.headers,   WdLib:createTableHeader(WDRO, "Melee",    402, -30, 200, 20))
    table.insert(WDRO.ranged.headers,   WdLib:createTableHeader(WDRO, "Ranged",   603, -30, 200, 20))
    table.insert(WDRO.unknown.headers,   WdLib:createTableHeader(WDRO, "Unknown", 804, -30, 200, 20))

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
            print("UNIT_NAME_UPDATE "..unit)
            for k,v in pairs(WD.cache.raidroster) do
                if v.unit == unit then
                    WD.cache.raidroster[v.guid].name = WdLib:getUnitName(unit)
                    print("UNIT_NAME_UPDATE updated")
                    break
                end
            end
            updateRaidOverviewFrame()
        elseif event == "INSPECT_READY" then
            local guid = ...
            print("INSPECT_READY "..guid)
            if WD.cache.raidroster[guid] then
                local t = WD.cache.raidroster[guid]
                WD.cache.raidrosterinspected[guid] = GetInspectSpecialization(t.unit)
                updateSpecialization(WD.cache.raidroster[guid])
                print("INSPECT_READY updated")
            end
            updateRaidOverviewFrame()
        elseif event == "PLAYER_ENTERING_WORLD" then
            updateRaidRoster()
        elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
            updateRaidRoster()
        elseif event == "READY_CHECK" then
            updateRaidRoster()
        end
    end)
    WDRO:SetScript("OnShow", function(self) updateRaidRoster() end)

    --updateRaidRoster()

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
        NotifyInspect(WD.cache.raidroster[guid].unit)
        return role
    end

    return getRoleBySpecId(specId)
end
