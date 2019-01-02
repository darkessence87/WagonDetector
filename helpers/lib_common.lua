
WdLib.gen = {}
local lib = WdLib.gen

local function table_val_to_str(v)
    if "string" == type(v) then
        v = string.gsub(v, "\n", "\\n")
        if string.match(string.gsub(v,"[^'\"]",""), '^"+$') then
            return "'" .. v .. "'"
        end
        return '"' .. string.gsub(v,'"', '\\"' ) .. '"'
    else
        return "table" == type(v) and lib:table_tostring(v) or tostring(v)
    end
end

local function table_key_to_str(k)
    if "string" == type(k) and string.match( k, "^[_%a][_%a%d]*$") then
        return k
    else
        return "[" .. table_val_to_str(k) .. "]"
    end
end

function lib:float_round_to(v, n)
    local mult = 10^n
    return math.floor(v * mult + 0.5) / mult
end

function lib:table_erase(t, predFn, resFn)
    local r = 0
    for i=1,#t do
        local v = t[i-r]
        if predFn(i,v) then
            resFn(i,v)
            table.remove(t, i-r)
            r = r + 1
        end
    end
end

function lib:table_wipe(t)
    for k in pairs(t) do
        t[k] = nil
    end
end

function lib:table_deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == "table" then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[lib:table_deepcopy(orig_key)] = lib:table_deepcopy(orig_value)
        end
        setmetatable(copy, lib:table_deepcopy(getmetatable(orig)))
    else
        copy = orig
    end
    return copy
end

function lib:string_totable(str)
    local t = {}
    str:gsub(".", function(c) table.insert(t,c) end)
    return t
end

function lib:table_tostring(tbl)
    if not tbl then return "nil" end
    local result, done = {}, {}
    for k, v in ipairs(tbl) do
        table.insert(result, table_val_to_str(v))
        done[k] = true
    end
    for k, v in pairs( tbl ) do
        if not done[k] then
            table.insert(result, table_key_to_str(k) .. "=" .. table_val_to_str(v) )
        end
    end
    return "{" .. table.concat(result, ",") .. "}"
end

function lib:table_tohtml(x)
    if type(x) ~= "table" then return "unsupported type" end

    local s = "<p>"
    for k,v in pairs(x) do
        s = s .. "|cffffff00" .. k .. "|r - " .. v .. "<br/>"
    end
    s = s .. "</p>"

    return s
end

local b="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
function lib:encode64(data)
    return ((data:gsub('.', function(x)
        local r,b='',x:byte()
        for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
        return r;
    end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c=0
        for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
        return b:sub(c+1,c+1)
    end)..({ '', '==', '=' })[#data%3+1])
end

function lib:decode64(data)
    data = string.gsub(data, '[^'..b..'=]', '')
    return (data:gsub('.', function(x)
        if (x == '=') then return '' end
        local r,f='',(b:find(x)-1)
        for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
        return r;
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if (#x ~= 8) then return '' end
        local c=0
        for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
        return string.char(c)
    end))
end

function lib:shortNumber(v)
    if v >= 1000000 then
        return lib:float_round_to(v/1000000, 2).."M"
    elseif v >= 1000 then
        return lib:float_round_to(v/1000, 1).."K"
    end
    return v
end

function lib:sendMessage(msg)
    local chatType = WD.db.profile.chat
    if not chatType or chatType == "PRINT" then
        print(msg)
    else
        SendChatMessage(msg, chatType, nil, 0)
    end
end

function lib:getFullName(name)
    if not name then return nil end
    if string.find(name, "-[^-]*$") then
        return name;
    else
        return name .. "-" .. WD.CurrentRealmName;
    end
end

function lib:getShortName(name, noRealm)
    if not name then return nil end
    local dashIndex = string.find(name, "-[^-]*$")
    if not dashIndex then
        return name
    end

    if noRealm or WD.CurrentRealmName == string.sub(name, dashIndex + 1) then
        return string.sub(name, 1, dashIndex - 1)
    else
        return name
    end
end

function lib:getUnitNumber(name)
    local i = name:find("-[^-]*$")
    if not i then return nil end
    return tonumber(name:sub(i + 1))
end

function lib:getColoredName(name, class)
    if class then
        local c = select(4, GetClassColor(class))
        return "|c"..c..name.."|r"
    end
    return name
end

function lib:getTimedDiff(startTime, endTime)
    if startTime == nil or endTime == nil then return end
    local dt = endTime - startTime
    if startTime > endTime then dt = -dt end
    local m = floor(dt / 60)
    dt = dt - m * 60
    local s = floor(dt)
    dt = dt - s
    local ms = dt * 1000
    local MIN = string.format("%02d", m)
    local SEC = string.format("%02d", s)
    local MSC = string.format("%003d", ms)
    return MIN .. ":" .. SEC .. "." .. MSC
end

function lib:getTimedDiffShort(startTime, endTime)
    local dt = endTime - startTime
    local m = floor(dt / 60)
    dt = dt - m * 60
    local s = floor(dt)
    local MIN = string.format("%02d", m)
    local SEC = string.format("%02d", s)
    return MIN .. ":" .. SEC
end

function lib:findEntityIndex(holder, guid)
    if not holder then return nil end
    for i=1,#holder do
        if holder[i] and holder[i].guid == guid then return i end
    end
    return nil
end

function lib:getUnitName(unit)
    local name, realm = UnitName(unit)
    if not name then return UNKNOWNOBJECT end
    if not realm or realm == "" then
        realm = WD.CurrentRealmName
    end
    return name.."-"..realm
end

function lib:getNpcId(guid)
    return select(6, strsplit("-", guid))
end

function lib:getDifficultyName(id)
    local normal = {1,3,4,9,12,14}
    local heroic = {2,5,6,11,15}
    local mythic = {16,23}
    local lfr    = {7,17}
    local challenge = {8}
    local event  = {18,19,20,30}
    local timewalk = {24,33}
    local function inTable(id, t)
        for i=1,#t do
            if t[i] == id then return true end
        end
        return nil
    end
    if inTable(id, mythic) then
        return "M"
    elseif inTable(id, heroic) then
        return "H"
    elseif inTable(id, normal) then
        return "N"
    elseif inTable(id, lfr) then
        return "LFR"
    elseif inTable(id, challenge) then
        return "CM"
    elseif inTable(id, event) then
        return "E"
    elseif inTable(id, timewalk) then
        return "TW"
    end
    return nil
end
