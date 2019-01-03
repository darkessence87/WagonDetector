
WdLib.table = {}
local lib = WdLib.table

local function table_val_to_str(v)
    if "string" == type(v) then
        v = string.gsub(v, "\n", "\\n")
        if string.match(string.gsub(v,"[^'\"]",""), '^"+$') then
            return "'" .. v .. "'"
        end
        return '"' .. string.gsub(v,'"', '\\"' ) .. '"'
    else
        return "table" == type(v) and lib:tostring(v) or tostring(v)
    end
end

local function table_key_to_str(k)
    if "string" == type(k) and string.match( k, "^[_%a][_%a%d]*$") then
        return k
    else
        return "[" .. table_val_to_str(k) .. "]"
    end
end

function lib:erase(t, predFn, resFn)
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

function lib:wipe(t)
    for k in pairs(t) do
        t[k] = nil
    end
end

function lib:deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == "table" then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[lib:deepcopy(orig_key)] = lib:deepcopy(orig_value)
        end
        setmetatable(copy, lib:deepcopy(getmetatable(orig)))
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

function lib:tostring(tbl)
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

function lib:tohtml(x)
    if type(x) ~= "table" then return "unsupported type" end

    local s = "<p>"
    for k,v in pairs(x) do
        s = s .. "|cffffff00" .. k .. "|r - " .. v .. "<br/>"
    end
    s = s .. "</p>"

    return s
end

