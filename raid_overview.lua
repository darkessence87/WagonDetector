
local WDRO = nil

if not WD.cache then WD.cache = {} end
WD.cache.raidroster = {}
WD.cache.raidrosterkeys = {}

local currentRealmName = string.gsub(GetRealmName(), "%s+", "")
local playerName = UnitName("player") .. "-" .. currentRealmName

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
    parent.icon.t = createTexture(parent.icon, "Interface\\Icons\\INV_MISC_QUESTIONMARK", "ARTWORK")
    parent.icon.t:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    parent.icon.t:SetAllPoints()

    updateSpecIcon(parent, specId)
end

local function createBuffSlot(parent, index)
    if not parent.buffs then parent.buffs = {} end

    parent.buffs[index] = CreateFrame("Button", nil, parent)
    parent.buffs[index].t = createColorTexture(parent.buffs[index], "BACKGROUND", .2, .2, .2, 1)
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
            GameTooltip:SetHyperlink(getSpellLinkById(self.spellId))
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
end

local function getConsumables(unit)
    local flask, food, rune = nil, nil, nil
    for index=1,40 do
        local _, _, _, _, _, _, _, _, _, spellId = UnitBuff(unit, index)

        -- flasks
        if spellId and WD.FLASK_IDS[spellId] then
            flask = spellId
        end

        -- food
        if spellId and WD.FOOD_IDS[spellId] then
            food = spellId
        end

        -- runes
        if spellId and WD.RUNE_IDS[spellId] then
            rune = spellId
        end
    end

    return flask, food, rune
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
    for k,v in pairs(data) do
        if not parent.members[k] then
            local member = CreateFrame("Frame", nil, parent.headers[1])
            member.info = v
            member:SetSize(parent.headers[1]:GetSize())
            member:SetPoint("TOPLEFT", parent.headers[1], "BOTTOMLEFT", 0, y)
            member.column = {}

            local index = 1
            addNextColumn(parent, member, index, "LEFT", getShortCharacterName(v.name, "noRealm"))
            if k > 1 then
                member.column[index]:SetPoint("TOPLEFT", parent.members[k - 1], "BOTTOMLEFT", 0, -1)
                member:SetPoint("TOPLEFT", parent.members[k - 1], "BOTTOMLEFT", 0, -1)
            else
                member.column[index]:SetPoint("TOPLEFT", member, "TOPLEFT", 0, 0)
            end
            member.column[index]:EnableMouse(false)
            local r,g,b = GetClassColor(v.class)
            member.column[index].txt:SetTextColor(r, g, b, 1)
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
            member.column[1].txt:SetText(getShortCharacterName(v.name, "noRealm"))
            local r,g,b = GetClassColor(v.class)
            member.column[1].txt:SetTextColor(r, g, b, 1)

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
        if WD.cache.raidroster[a].name < WD.cache.raidroster[b].name then return true
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
            tanks[#tanks+1] = v
        elseif role == "Healer" then
            healers[#healers+1] = v
        elseif role == "Melee" then
            melees[#melees+1] = v
        elseif role == "Ranged" then
            ranged[#ranged+1] = v
        else
            unknown[#unknown+1] = v
        end
    end

    updateRaidOverviewMember(tanks, WDRO.tanks)
    updateRaidOverviewMember(healers, WDRO.healers)
    updateRaidOverviewMember(melees, WDRO.melees)
    updateRaidOverviewMember(ranged, WDRO.ranged)
    updateRaidOverviewMember(unknown, WDRO.unknown)
end

local function updateRaidSpec(inspected)
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

            if p.name == playerName then
                p.specId = getSpecialization(p.name, p.class, p.unit)
            else
                if not inspected then
                    NotifyInspect(unit)
                end
            end

            if WD.cache.raidroster[p.name] then
                WD.cache.raidroster[p.name].unit = p.unit
                if p.name == playerName then
                    WD.cache.raidroster[p.name].specId = p.specId
                end
            else
                WD.cache.raidrosterkeys[#WD.cache.raidrosterkeys+1] = p.name
                WD.cache.raidroster[p.name] = p
            end
        end

        for k,v in pairs(WD.cache.raidrosterkeys) do
            local data = WD.cache.raidroster[v]
            if UnitInRaid(data.unit) then
                local name, realm = UnitName(data.unit)
                if not realm or realm == "" then
                    realm = currentRealmName
                end
                name = name.."-"..realm

                if name ~= data.name then
                    WD.cache.raidroster[v] = nil
                    table.remove(WD.cache.raidrosterkeys, k)
                end
            else
                WD.cache.raidroster[v] = nil
                table.remove(WD.cache.raidrosterkeys, k)
            end
        end
    else
        table.wipe(WD.cache.raidrosterkeys)
        table.wipe(WD.cache.raidroster)

        local _,class = UnitClass("player")
        local p = {}
        p.name = playerName
        p.unit = "player"
        p.class = class
        p.specId = getSpecialization(p.name, p.class, p.unit)
        if not WD.cache.raidroster[p.name] then
            WD.cache.raidrosterkeys[#WD.cache.raidrosterkeys+1] = p.name
        end
        WD.cache.raidroster[p.name] = p
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

    table.insert(WDRO.tanks.headers,    createTableHeader(WDRO, "Tanks",    1,   -30, 160, 20))
    table.insert(WDRO.healers.headers,  createTableHeader(WDRO, "Healers",  162, -30, 160, 20))
    table.insert(WDRO.melees.headers,   createTableHeader(WDRO, "Melee",    323, -30, 160, 20))
    table.insert(WDRO.ranged.headers,   createTableHeader(WDRO, "Ranged",   484, -30, 160, 20))
    table.insert(WDRO.unknown.headers,   createTableHeader(WDRO, "Unknown", 645, -30, 160, 20))

    WDRO:RegisterEvent("GROUP_ROSTER_UPDATE")
    WDRO:RegisterEvent("INSPECT_READY")
    WDRO:RegisterEvent("PLAYER_ENTERING_WORLD")
    WDRO:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    WDRO:RegisterEvent("READY_CHECK")

    WDRO:SetScript("OnEvent", function(self, event, ...)
        if event == "GROUP_ROSTER_UPDATE" then
            updateRaidSpec()
        elseif event == "INSPECT_READY" then
            local guid = ...
            local _,_,_,race,_,name,realm = GetPlayerInfoByGUID(guid)
            if not realm or realm == "" then
                realm = currentRealmName
            end
            name = name.."-"..realm
            if WD.cache.raidroster[name] then
                WD.cache.raidroster[name].specId = getSpecialization(name, WD.cache.raidroster[name].class, WD.cache.raidroster[name].unit)
            end
            updateRaidSpec("inspected")
        elseif event == "PLAYER_ENTERING_WORLD" then
            updateRaidSpec()
        elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
            updateRaidSpec()
        elseif event == "READY_CHECK" then
            updateRaidSpec()
        end
    end)
    WDRO:SetScript("OnShow", function(self) updateRaidSpec() end)

    updateRaidSpec()

    function WDRO:OnUpdate()
        updateRaidSpec()
    end
end

function WD:GetRole(name)
    name = getFullCharacterName(name)
    local role = "Unknown"
    if not WD.cache.raidroster or not WD.cache.raidroster[name] then
        return role
    end

    local specId = WD.cache.raidroster[name].specId
    if specId == 0 then
        NotifyInspect(WD.cache.raidroster[name].unit)
        return role
    end

    return getRoleBySpecId(specId)
end
