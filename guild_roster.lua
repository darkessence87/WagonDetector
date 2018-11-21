
local WDGR = nil

if not WD.cache then WD.cache = {} end
WD.cache.roster = {}
WD.cache.rosterkeys = {}

function calculateCoef(points, pulls)
    local mult = 10^2
    return math.floor((points * 1.0 / pulls) * mult + 0.5) / mult
end

local function parseOfficerNote(note)
    local points, pulls = string.match(note, "^(%w+),(%w+)$")
    local isAlt = "no"

    for i=1,GetNumGuildMembers() do
        local name, _, rankIndex = GetGuildRosterInfo(i)
        if note == getShortCharacterName(name) and rankIndex <= WD.db.profile.minGuildRank.id then
            isAlt = "yes"
            break
        end
    end

    return tonumber(points) or 0, tonumber(pulls) or 0, isAlt
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

    local maxWidth = 30
    local maxHeight = 545
    for i=1,#WDGR.headers do
        maxWidth = maxWidth + WDGR.headers[i]:GetWidth() + 1
    end

    local scroller = WDGR.scroller or createScroller(WDGR, maxWidth, maxHeight, #WD.cache.rosterkeys)
    if not WDGR.scroller then
        WDGR.scroller = scroller
    end

    local x, y = 30, -51
    for k=1,#WD.cache.rosterkeys do
        local v = WD.cache.roster[WD.cache.rosterkeys[k]]
        if not WDGR.members[k] then
            local member = CreateFrame("Frame", nil, WDGR.scroller.scrollerChild)
            member.info = v
            member:SetSize(maxWidth, 20)
            member:SetPoint("TOPLEFT", WDGR.scroller.scrollerChild, "TOPLEFT", x, y)
            member.column = {}

            local index = 1
            addNextColumn(WDGR, member, index, "LEFT", getShortCharacterName(v.name))
            member.column[index]:SetPoint("TOPLEFT", member, "TOPLEFT", 0, -1)
            member.column[index]:EnableMouse(true)
            local r,g,b = GetClassColor(v.class)
            member.column[index].txt:SetTextColor(r, g, b, 1)
            member.column[index]:SetScript("OnEnter", function(WDGR)
                GameTooltip:SetOwner(WDGR, "ANCHOR_RIGHT")
                local tooltip = "Alts:\n"
                for i=1,#v.alts do
                    tooltip = tooltip..getShortCharacterName(v.alts[i]).."\n"
                end
                if #v.alts > 0 then
                    GameTooltip:SetText(tooltip, nil, nil, nil, nil, true)
                    GameTooltip:Show()
                end
            end)
            member.column[index]:SetScript("OnLeave", function(WDGR) GameTooltip_Hide() end)

            index = index + 1
            addNextColumn(WDGR, member, index, "CENTER", v.rank)
            index = index + 1
            addNextColumn(WDGR, member, index, "CENTER", v.points)
            index = index + 1
            addNextColumn(WDGR, member, index, "CENTER", v.pulls)
            index = index + 1
            addNextColumn(WDGR, member, index, "CENTER", v.coef)

            table.insert(WDGR.members, member)
        else
            local member = WDGR.members[k]
            member.column[1].txt:SetText(getShortCharacterName(v.name))
            local r,g,b = GetClassColor(v.class)
            member.column[1].txt:SetTextColor(r, g, b, 1)
            member.column[1]:SetScript("OnEnter", function(WDGR)
                GameTooltip:SetOwner(WDGR, "ANCHOR_RIGHT")
                local tooltip = "Alts:\n"
                for i=1,#v.alts do
                    tooltip = tooltip..getShortCharacterName(v.alts[i]).."\n"
                end
                if #v.alts > 0 then
                    GameTooltip:SetText(tooltip, nil, nil, nil, nil, true)
                    GameTooltip:Show()
                end
            end)
            member.column[2].txt:SetText(v.rank)
            member.column[3].txt:SetText(v.points)
            member.column[4].txt:SetText(v.pulls)
            member.column[5].txt:SetText(v.coef)
            member:Show()
            updateScroller(WDGR.scroller.slider, #WD.cache.rosterkeys)
        end

        y = y - 21
    end

    if #WD.cache.rosterkeys < #WDGR.members then
        for i=#WD.cache.rosterkeys+1, #WDGR.members do
            WDGR.members[i]:Hide()
        end
    end
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

    local h = createTableHeader(WDGR, WD_BUTTON_NAME, x, y, 150, 20, function() headerButtonFunction("BY_NAME") end)
    table.insert(WDGR.headers, h)
    h = createTableHeaderNext(WDGR, h, WD_BUTTON_RANK, 75, 20, function() headerButtonFunction("BY_RANK") end)
    table.insert(WDGR.headers, h)
    h = createTableHeaderNext(WDGR, h, WD_BUTTON_POINTS, 75, 20, function() headerButtonFunction("BY_POINTS") end)
    table.insert(WDGR.headers, h)
    h = createTableHeaderNext(WDGR, h, WD_BUTTON_PULLS, 75, 20, function() headerButtonFunction("BY_PULLS") end)
    table.insert(WDGR.headers, h)
    h = createTableHeaderNext(WDGR, h, WD_BUTTON_COEF, 75, 20, function() headerButtonFunction("BY_RESULT") end)
    table.insert(WDGR.headers, h)

    WD:OnGuildRosterUpdate()
    WD:SortGuildRoster("BY_NAME", false, function() updateGuildRosterFrame() end)

    WDGR:RegisterEvent("GUILD_ROSTER_UPDATE")
    WDGR:SetScript("OnEvent", function(self, event, ...)
        if event == "GUILD_ROSTER_UPDATE" then
            WD:OnGuildRosterUpdate()
        end
    end)
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
    if not WD.db.profile.minGuildRank then
        local gRanks = WD:GetGuildRanks()
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
            info.name, info.class, info.rank = name, class, rank
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
        mainName = getFullCharacterName(v.main)
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
        func = function(a, b) if inverse == true then return WD.cache.roster[a].rank < WD.cache.roster[b].rank else return WD.cache.roster[a].rank > WD.cache.roster[b].rank end end
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
    local name = self:FindMain(getFullCharacterName(v.name))
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
        if officernote and rankIndex < 6 then
            local info = {}
            info.index = i
            info.name, info.class, info.rank = name, class, rank
            info.points, info.pulls, info.isAlt = parseOfficerNote(officernote)
            info.alts = {}
            if info.isAlt == "no" then
                GuildRosterSetOfficerNote(info.index, "0,0")
            end
        end
    end

    self:OnGuildRosterUpdate()

    sendMessage(WD_RESET_GUILD_ROSTER)
end

function WD:GetGuildRanks()
    local ranks = {}
    local temp = {}
    for i=1,GetNumGuildMembers() do
        local _, rank, rankIndex = GetGuildRosterInfo(i)
        temp[rankIndex] = rank
    end

    for k,v in pairs(temp) do
        local rank = { id = k, name = v }
        table.insert(ranks, rank)

    end

    return ranks
end
