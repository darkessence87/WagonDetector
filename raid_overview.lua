
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
            addNextColumn(parent, member, index, "LEFT", getShortCharacterName(v.name))
            if k > 1 then
                member.column[index]:SetPoint("TOPLEFT", parent.members[k - 1], "BOTTOMLEFT", 0, -1)
                member:SetPoint("TOPLEFT", parent.members[k - 1], "BOTTOMLEFT", 0, -1)
            else
                member.column[index]:SetPoint("TOPLEFT", member, "TOPLEFT", 0, 0)
            end
            member.column[index]:EnableMouse(false)
            local r,g,b = GetClassColor(v.class)
            member.column[index].txt:SetTextColor(r, g, b, 1)

            parent.members[k] = member
        else
            local member = parent.members[k]
            member.info = v
            member.column[1].txt:SetText(getShortCharacterName(v.name))
            local r,g,b = GetClassColor(v.class)
            member.column[1].txt:SetTextColor(r, g, b, 1)
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

    table.insert(WDRO.tanks.headers,    createTableHeader(WDRO, "Tanks",    1,   -30, 150, 20))
    table.insert(WDRO.healers.headers,  createTableHeader(WDRO, "Healers",  152, -30, 150, 20))
    table.insert(WDRO.melees.headers,   createTableHeader(WDRO, "Melee",    303, -30, 150, 20))
    table.insert(WDRO.ranged.headers,   createTableHeader(WDRO, "Ranged",   454, -30, 150, 20))
    table.insert(WDRO.unknown.headers,   createTableHeader(WDRO, "Unknown",   605, -30, 150, 20))

    WDRO:RegisterEvent("GROUP_ROSTER_UPDATE")
    WDRO:RegisterEvent("INSPECT_READY")
    WDRO:RegisterEvent("PLAYER_ENTERING_WORLD")
    WDRO:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")

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
        end
    end)

    updateRaidSpec()
end

function WD:GetRole(name)
    local role = "Unknown"
    if not WD.cache.raidroster or not WD.cache.raidroster[name] then
        return role
    end

    local specId = WD.cache.raidroster[name].specId
    if specId == 0 then return role end

    return getRoleBySpecId(specId)
end

