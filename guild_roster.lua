
local WDGR = nil

if not WD.cache then WD.cache = {} end
WD.cache.roster = {}
WD.cache.rosterkeys = {}

function calculateCoef(points, pulls)
    return WdLib:float_round_to(points * 1.0 / pulls, 2)
end

local function parseOfficerNote(note)
    local points, pulls = string.match(note, "^(%w+),(%w+)$")
    local isAlt = "no"

    for i=1,GetNumGuildMembers() do
        local name, _, rankIndex = GetGuildRosterInfo(i)
        if note == WdLib:getShortName(name) and rankIndex <= WD.db.profile.minGuildRank.id then
            isAlt = "yes"
            break
        end
    end

    return tonumber(points) or 0, tonumber(pulls) or 0, isAlt
end

local function updateClassStatistics()
    -- update class members numbers
    local classMembers = {}
    local total = 0
    for k,v in pairs(WD.cache.roster) do
        if classMembers[v.class] then
            classMembers[v.class] = classMembers[v.class] + 1
        else
            classMembers[v.class] = 1
        end
        total = total + 1
    end
    for k,v in pairs(WDGR.classMembers) do
        if classMembers and classMembers[v.class] then
            v.column[7].txt:SetText(classMembers[v.class])
        elseif v.class then
            v.column[7].txt:SetText("0")
        else
            v.column[7].txt:SetText(total)
            v.column[7].t:SetColorTexture(.5, .5, .5, 1)
        end
    end
end

local function updateGuildRosterFrame()
    if #WD.cache.rosterkeys == 0 then
        if #WDGR.members then
            for i=1, #WDGR.members do
                WDGR.members[i]:Hide()
            end
        end
        return
    end

    local maxHeight = 545
    local topLeftPosition = { x = 30, y = -51 }
    local rowsN = #WD.cache.rosterkeys
    local columnsN = 5

    local function createFn(parent, row, index)
        local v = WD.cache.roster[WD.cache.rosterkeys[row]]
        if index == 1 then
            local f = WdLib:addNextColumn(WDGR, parent, index, "LEFT", WdLib:getColoredName(WdLib:getShortName(v.name), v.class))
            f:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -1)
            f:EnableMouse(true)
            f:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                local tooltip = "Alts:\n"
                for i=1,#v.alts do
                    tooltip = tooltip..WdLib:getShortName(v.alts[i]).."\n"
                end
                if #v.alts > 0 then
                    GameTooltip:SetText(tooltip, nil, nil, nil, nil, true)
                    GameTooltip:Show()
                end
            end)
            f:SetScript("OnLeave", function() GameTooltip_Hide() end)
            return f
        elseif index == 2 then
            return WdLib:addNextColumn(WDGR, parent, index, "CENTER", v.rank)
        elseif index == 3 then
            return WdLib:addNextColumn(WDGR, parent, index, "CENTER", v.points)
        elseif index == 4 then
            return WdLib:addNextColumn(WDGR, parent, index, "CENTER", v.pulls)
        elseif index == 5 then
            return WdLib:addNextColumn(WDGR, parent, index, "CENTER", v.coef)
        end
    end

    local function updateFn(frame, row, index)
        local v = WD.cache.roster[WD.cache.rosterkeys[row]]
        if index == 1 then
            frame.txt:SetText(WdLib:getColoredName(WdLib:getShortName(v.name), v.class))
            frame:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                local tooltip = "Alts:\n"
                for i=1,#v.alts do
                    tooltip = tooltip..WdLib:getShortName(v.alts[i]).."\n"
                end
                if #v.alts > 0 then
                    GameTooltip:SetText(tooltip, nil, nil, nil, nil, true)
                    GameTooltip:Show()
                end
            end)
        elseif index == 2 then
            frame.txt:SetText(v.rank)
        elseif index == 3 then
            frame.txt:SetText(v.points)
        elseif index == 4 then
            frame.txt:SetText(v.pulls)
        elseif index == 5 then
            frame.txt:SetText(v.coef)
        end
    end

    WdLib:updateScrollableTable(WDGR, maxHeight, topLeftPosition, rowsN, columnsN, createFn, updateFn)

    updateClassStatistics()
end

local function initClassRoster()
    local d = #WDGR.headers
    local x, y = 500, -30
    local h = WdLib:createTableHeader(WDGR, WD_BUTTON_CLASS, x, y,    125, 20)
    table.insert(WDGR.headers, h)
    h = WdLib:createTableHeaderNext(WDGR, h, WD_BUTTON_CLASS_NUMBER,   50, 20)
    table.insert(WDGR.headers, h)

    WDGR.classMembers = {}

    local prevFrame = nil
    for k=1,GetNumClasses() do
        local className, class = GetClassInfo(k)

        local member = CreateFrame("Frame", nil, WDGR.headers[d+1])
        member:SetSize(WDGR.headers[d+1]:GetSize())
        member.column = {}
        member.class = class

        local index = d + 1
        WdLib:addNextColumn(WDGR, member, index, "LEFT", WdLib:getColoredName(className, class))
        if k > 1 then
            member.column[index]:SetPoint("TOPLEFT", prevFrame, "BOTTOMLEFT", 0, -1)
            member:SetPoint("TOPLEFT", prevFrame, "BOTTOMLEFT", 0, -1)
        else
            member.column[index]:SetPoint("TOPLEFT", member, "TOPLEFT", 0, 0)
            member:SetPoint("TOPLEFT", WDGR.headers[d+1], "BOTTOMLEFT", 0, -3)
        end
        member.column[index]:EnableMouse(false)
        member.column[index].txt:SetPoint("LEFT", 5, 0)

        index = index + 1
        WdLib:addNextColumn(WDGR, member, index, "CENTER", 0)

        prevFrame = member
        table.insert(WDGR.classMembers, member)
    end

    local member = CreateFrame("Frame", nil, WDGR.headers[d+1])
    member:SetSize(WDGR.headers[d+1]:GetSize())
    member.column = {}

    local index = d + 1
    WdLib:addNextColumn(WDGR, member, index, "LEFT", WD_LABEL_TOTAL)
    member.column[index]:SetPoint("TOPLEFT", prevFrame, "BOTTOMLEFT", 0, -1)
    member:SetPoint("TOPLEFT", prevFrame, "BOTTOMLEFT", 0, -1)
    member.column[index]:EnableMouse(false)
    member.column[index].txt:SetPoint("LEFT", 5, 0)
    member.column[index].t:SetColorTexture(.5, .5, .5, 1)

    index = index + 1
    WdLib:addNextColumn(WDGR, member, index, "CENTER", 0)
    table.insert(WDGR.classMembers, member)
end

function WD:InitGuildRosterModule(parent)
    WDGR = parent

    local x, y = 1, -30
    WDGR.headers = {}
    WDGR.members = {}

    function headerButtonFunction(param)
        if WDGR.sorted == param then
            WD:SortGuildRoster(param, not WD.cache.rostersortinverse, function() updateGuildRosterFrame() end)
        else
            WD:SortGuildRoster(param, false, function() updateGuildRosterFrame() end)
        end
        WDGR.sorted = param
    end

    local h = WdLib:createTableHeader(WDGR, WD_BUTTON_NAME, x, y, 150, 20, function() headerButtonFunction("BY_NAME") end)
    table.insert(WDGR.headers, h)
    h = WdLib:createTableHeaderNext(WDGR, h, WD_BUTTON_RANK,      100, 20, function() headerButtonFunction("BY_RANK") end)
    table.insert(WDGR.headers, h)
    h = WdLib:createTableHeaderNext(WDGR, h, WD_BUTTON_POINTS,     65, 20, function() headerButtonFunction("BY_POINTS") end)
    table.insert(WDGR.headers, h)
    h = WdLib:createTableHeaderNext(WDGR, h, WD_BUTTON_PULLS,      65, 20, function() headerButtonFunction("BY_PULLS") end)
    table.insert(WDGR.headers, h)
    h = WdLib:createTableHeaderNext(WDGR, h, WD_BUTTON_COEF,       65, 20, function() headerButtonFunction("BY_RESULT") end)
    table.insert(WDGR.headers, h)

    initClassRoster()

    WD:OnGuildRosterUpdate()
    WD:SortGuildRoster("BY_NAME", false, function() updateGuildRosterFrame() end)

    WDGR:RegisterEvent("GUILD_ROSTER_UPDATE")
    WDGR:SetScript("OnEvent", function(self, event, ...)
        if event == "GUILD_ROSTER_UPDATE" then
            WD:OnGuildRosterUpdate()
        end
    end)

    function WDGR:OnUpdate()
        updateGuildRosterFrame()
    end
end

function WD:RefreshGuildRosterFrame()
    if WDGR then
        GuildRoster()
    end
end

function WD:FindMain(name)
    for _,v in pairs(WD.cache.roster) do
        for i=1,#v.alts do
            if v.alts[i] == name then
                return v.name
            end
        end
    end

    return name
end

function WD:OnGuildRosterUpdate()
    local gRanks = WD:GetGuildRanks()
    if WD.db.profile.minGuildRank and #gRanks ~= 0 then
        local needRankUpdate = true
        for k,v in pairs(gRanks) do
            if v.name == WD.db.profile.minGuildRank.name then
                needRankUpdate = false
                break
            end
        end
        if needRankUpdate == true then WD.db.profile.minGuildRank = nil end
    end
    if not WD.db.profile.minGuildRank or not WD.db.profile.minGuildRank.name then
        for k,v in pairs(gRanks) do
            if v.id == 0 then
                WD.db.profile.minGuildRank = v
                break
            end
        end
    end

    WD.cache.roster = {}
    WD.cache.rosterkeys = {}
    local altInfos = {}
    for i=1,GetNumGuildMembers() do
        local name, rank, rankIndex, _, _, _, _, officernote, _, _, class = GetGuildRosterInfo(i)
        if officernote and officernote == "" then
            officernote = "0,0"
        end
        if officernote and rankIndex <= WD.db.profile.minGuildRank.id then
            local info = {}
            info.index = i
            info.name, info.class, info.rank, info.rankIndex = name, class, rank, rankIndex
            info.points, info.pulls, info.isAlt = parseOfficerNote(officernote)
            info.alts = {}
            if info.isAlt == "no" then
                if info.pulls == 0 then
                    info.coef = info.points
                else
                    info.coef = calculateCoef(info.points, info.pulls)
                end

                if not WD.cache.roster[name] then
                    WD.cache.rosterkeys[#WD.cache.rosterkeys+1] = name
                end
                WD.cache.roster[name] = info
            else
                local altInfo = {}
                altInfo.index = i
                altInfo.name = info.name
                altInfo.main = officernote
                altInfos[#altInfos+1] = altInfo
            end
        end
    end

    for _,v in pairs(altInfos) do
        mainName = WdLib:getFullName(v.main)
        if WD.cache.roster[mainName] then
            table.insert(WD.cache.roster[mainName].alts, v.name)
        end
    end

    WD:SortGuildRoster(WD.cache.rostersort, WD.cache.rostersortinverse, function() updateGuildRosterFrame() end)
end

function WD:SortGuildRoster(param, inverse, callback)
    if not param then return end

    local func = nil
    if param == "BY_NAME" then
        func = function(a, b) if inverse == true then return a > b else return a < b end end
    elseif param == "BY_POINTS" then
        func = function(a, b) if inverse == true then return WD.cache.roster[a].points < WD.cache.roster[b].points else return WD.cache.roster[a].points > WD.cache.roster[b].points end end
    elseif param == "BY_PULLS" then
        func = function(a, b) if inverse == true then return WD.cache.roster[a].pulls < WD.cache.roster[b].pulls else return WD.cache.roster[a].pulls > WD.cache.roster[b].pulls end end
    elseif param == "BY_RANK" then
        func = function(a, b) if inverse == true then return WD.cache.roster[a].rankIndex > WD.cache.roster[b].rankIndex else return WD.cache.roster[a].rankIndex < WD.cache.roster[b].rankIndex end end
    elseif param == "BY_RESULT" then
        func = function(a, b) if inverse == true then return WD.cache.roster[a].coef < WD.cache.roster[b].coef else return WD.cache.roster[a].coef > WD.cache.roster[b].coef end end
    else
        print("Unsupported sort param:"..param)
        return
    end

    if not func then return end
    table.sort(WD.cache.rosterkeys, func)

    WD.cache.rostersort = param
    WD.cache.rostersortinverse = inverse

    if callback then
        callback()
    end
end

function WD:IsOfficer(name)
    local name = self:FindMain(name)
    if WD.cache.roster[name] then
        return true
    end

    return false
end

function WD:SavePullsToGuildRoster(v)
    local name = self:FindMain(v.name)
    if WD.cache.roster[name] then
        local info = WD.cache.roster[name]
        info.pulls = info.pulls + 1
        info.coef = calculateCoef(info.points, info.pulls)

        if WD.db.profile.enablePenalties == true then
            GuildRosterSetOfficerNote(info.index, info.points..","..info.pulls)
        end
    end
end

function WD:SavePenaltyPointsToGuildRoster(v, isRevert)
    local name = self:FindMain(WdLib:getFullName(v.name))
    if WD.cache.roster[name] then
        local info = WD.cache.roster[name]
        info.points = info.points + v.points
        if info.points < 0 then info.points = 0 end
        info.coef = calculateCoef(info.points, info.pulls)

        if WD.db.profile.enablePenalties == true then
            GuildRosterSetOfficerNote(info.index, info.points..","..info.pulls)
        end

        if not isRevert then
            WD:AddHistory(v)
        end
    end
end

function WD:ResetGuildStatistics()
    for i=1,GetNumGuildMembers() do
        local name, rank, rankIndex, _, _, _, _, officernote, _, _, class = GetGuildRosterInfo(i)
        if officernote and rankIndex <= WD.db.profile.minGuildRank.id then
            local info = {}
            info.index = i
            info.name, info.class, info.rank, info.rankIndex = name, class, rank, rankIndex
            info.points, info.pulls, info.isAlt = parseOfficerNote(officernote)
            info.alts = {}
            if info.isAlt == "no" then
                GuildRosterSetOfficerNote(info.index, "0,0")
            end
        end
    end

    self:OnGuildRosterUpdate()

    WdLib:sendMessage(WD_RESET_GUILD_ROSTER)
end

function WD:GetGuildRanks()
    local ranks = {}
    local temp = {}
    local tempKeys = {}
    for i=1,GetNumGuildMembers() do
        local _, rankName, rankIndex = GetGuildRosterInfo(i)
        local rank = { id = rankIndex, name = rankName }
        if not temp[rank.id] then
            temp[rank.id] = rank
            tempKeys[#tempKeys+1] = rank.id
        end
    end

    if #tempKeys > 1 then
        local fn = function(a, b) return temp[a].id < temp[b].id end
        table.sort(tempKeys, fn)
    end

    for _,k in pairs(tempKeys) do
        local v = temp[k]
        local rank = { id = v.id, name = v.name }
        table.insert(ranks, rank)
    end

    return ranks
end
