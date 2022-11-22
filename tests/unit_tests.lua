
local function log(data)
    --if WD.DebugEnabled ~= true then return end
    if type(data) == "table" then
        print(WdLib.table:tostring(data))
    else
        print(data or "nil")
    end
end

local core = WD.mainFrame

local function onEndTest(testObject)
    core:OnEvent("ENCOUNTER_END", 0, testObject.name, 10, 10)
    local errorMsg = testObject.validate(testObject)
    local headerMsg = "|cffffffff["..testObject.name.."] |cffffff00finished, result:|r"
    if errorMsg then
        print(headerMsg.." |cffff0000[FAILED]|r:")
        print(" - "..errorMsg)
    else
        print(headerMsg.." |cff00ff00[PASSED]|r")
    end
end

local function sendEvent(currTime, timeDiff, event, ...)
    local timestamp = currTime + timeDiff
    local args = {...}
    core:Tracker_OnEvent(timestamp, event, nil, unpack(args))
end

local function startTest(testObject, timeout)
    core:OnEvent("ENCOUNTER_START", 0, testObject.name, 10, 10)
    testObject.startFn(testObject)
    local currTime = GetTime()
    for i=1,#testObject.events do
        local v = testObject.events[i]
        sendEvent(currTime, unpack(v))
    end
    WdLib.timers:CreateTimer(onEndTest, timeout, testObject)
end

local Tests = {
    ["interrupts"] = {name="interrupts"},
    ["unknown_pets"] = {name="unknown_pets"},
}

Tests["interrupts"].events = {
    -- 2 creatures spawned and started cast, 2 players interrupted their casts
    {1,"SPELL_CAST_START","Creature-0-3151-1861-23835-139381-00009C17EC","Caster 1",0xa18,0x0,0000000000000000,nil,0x80000000,0x80000000,273944,"Spell 1",0x20},
    {2,"SPELL_CAST_START","Creature-0-3151-1861-23835-139381-00001C17EC","Caster 1",0x10a48,0x0,0000000000000000,nil,0x80000000,0x80000000,273944,"Spell 1",0x20},
    {3,"SPELL_INTERRUPT","Player-1615-071F8EA","Interrupter 1",0x514,0x0,"Creature-0-3151-1861-23835-139381-00009C17EC","Caster 1",0xa48,0x0,47528,"Spell 2",0x10,273944,"Spell 1",32},
    {4,"SPELL_INTERRUPT","Player-1615-08F2F7C","Interrupter 2",0x514,0x0,"Creature-0-3151-1861-23835-139381-00001C17EC","Caster 1",0x10a48,0x0,183752,"Spell 3",0x7c,273944,"Spell 1",32},
    -- 2 creatures started cast again, only 1 cast was interrupted
    {5,"SPELL_CAST_START","Creature-0-3151-1861-23835-139381-00009C17EC","Caster 1",0xa48,0x0,0000000000000000,nil,0x80000000,0x80000000,273944,"Spell 1",0x20},
    {6,"SPELL_CAST_START","Creature-0-3151-1861-23835-139381-00001C17EC","Caster 1",0x10a48,0x0,0000000000000000,nil,0x80000000,0x80000000,273944,"Spell 1",0x20},
    {7,"SPELL_INTERRUPT","Player-1929-0A3C63F","Interrupter 3",0x514,0x0,"Creature-0-3151-1861-23835-139381-00009C17EC","Caster 1",0xa48,0x0,47528,"Spell 2",0x10,273944,"Spell 1",32},
    {9,"SPELL_CAST_SUCCESS","Creature-0-3151-1861-23835-139381-00001C17EC","Caster 1",0xa48,0x0,"Player-1602-0AC4520","Player 1",0x514,0x0,273945,"Spell 1",0x20},
    {9,"SPELL_CAST_SUCCESS","Creature-0-3151-1861-23835-139381-00001C17EC","Caster 1",0x10a48,0x0,0000000000000000,nil,0x80000000,0x80000000,273944,"Spell 1",0x20},
    -- 1 creature started cast again, interrupted
    {9,"SPELL_CAST_START","Creature-0-3151-1861-23835-139381-00001C17EC","Caster 1",0x10a48,0x0,0000000000000000,nil,0x80000000,0x80000000,273944,"Spell 1",0x20},
    {10,"SPELL_INTERRUPT","Player-1615-08F2F7C","Interrupter 2",0x514,0x0,"Creature-0-3151-1861-23835-139381-00001C17EC","Caster 1",0x10a48,0x0,183752,"Spell 3",0x7c,273944,"Spell 1",32},

    -- 2 new creatures spawned and started cast, 2 players interrupted their casts
    {11,"SPELL_CAST_START","Creature-0-3151-1861-23835-139381-00009C1877","Caster 1",0xa48,0x0,0000000000000000,nil,0x80000000,0x80000000,273944,"Spell 1",0x20},
    {12,"SPELL_CAST_START","Creature-0-3151-1861-23835-139381-00001C1877","Caster 1",0x10a48,0x0,0000000000000000,nil,0x80000000,0x80000000,273944,"Spell 1",0x20},
    {13,"SPELL_INTERRUPT","Player-1615-071F8EA","Interrupter 1",0x514,0x0,"Creature-0-3151-1861-23835-139381-00009C1877","Caster 1",0xa48,0x0,47528,"Spell 2",0x10,273944,"Spell 1",32},
    {14,"SPELL_INTERRUPT","Player-1615-0755C1B","Interrupter 4",0x40511,0x0,"Creature-0-3151-1861-23835-139381-00001C1877","Caster 1",0x10a48,0x0,93985,"Spell 4",0x1,273944,"Spell 1",32},
    -- 2 creatures started cast again, no interrupts
    {15,"SPELL_CAST_START","Creature-0-3151-1861-23835-139381-00009C1877","Caster 1",0xa48,0x0,0000000000000000,nil,0x80000000,0x80000000,273944,"Spell 1",0x20},
    {15,"SPELL_CAST_START","Creature-0-3151-1861-23835-139381-00001C1877","Caster 1",0x10a48,0x0,0000000000000000,nil,0x80000000,0x80000000,273944,"Spell 1",0x20},
    {18,"SPELL_CAST_SUCCESS","Creature-0-3151-1861-23835-139381-00009C1877","Caster 1",0xa48,0x0,"Player-1602-0AC4520","Player 1",0x514,0x0,273945,"Spell 1",0x20},
    {18,"SPELL_CAST_SUCCESS","Creature-0-3151-1861-23835-139381-00009C1877","Caster 1",0xa48,0x0,0000000000000000,nil,0x80000000,0x80000000,273944,"Spell 1",0x20},
    {18,"SPELL_CAST_SUCCESS","Creature-0-3151-1861-23835-139381-00001C1877","Caster 1",0x10a48,0x0,"Player-1602-0AC4520","Player 1",0x514,0x0,273945,"Spell 1",0x20},
    {18,"SPELL_CAST_SUCCESS","Creature-0-3151-1861-23835-139381-00001C1877","Caster 1",0x10a48,0x0,0000000000000000,nil,0x80000000,0x80000000,273944,"Spell 1",0x20},
}
Tests["interrupts"].expectations = {
    ["Creature-0-3151-1861-23835-139381-00009C17EC"] = {casts = 0, interrupted = 2},
    ["Creature-0-3151-1861-23835-139381-00001C17EC"] = {casts = 1, interrupted = 2},
    ["Creature-0-3151-1861-23835-139381-00009C1877"] = {casts = 1, interrupted = 1},
    ["Creature-0-3151-1861-23835-139381-00001C1877"] = {casts = 1, interrupted = 1},
}
Tests["interrupts"].startFn = function(self)
end
Tests["interrupts"].validate = function(self)
    if not core.tracker then return "No active encounter" end
    for guid,expected in pairs(self.expectations) do
        local npcId = WdLib.gen:getNpcId(guid)
        if not npcId then return "Not found npcId for unit with guid:"..guid end
        if not core.tracker.npc[npcId] then return "Not found unit for npcId:"..npcId end
        local index = WdLib.gen:findEntityIndex(core.tracker.npc[npcId], guid)
        if not index then return "Not found unit for guid:"..guid end
        local unit = core.tracker.npc[npcId][index]
        local casted, interrupted = 0, 0
        for k,v in pairs(unit.casts) do
            if type(v) == "table" then
                for _,data in pairs(v) do
                    if type(data) == "table" then
                        if data.status == "SUCCESS" then
                            casted = casted + 1
                        elseif data.status == "INTERRUPTED" then
                            interrupted = interrupted + 1
                        end
                    end
                end
            end
        end
        if casted ~= expected.casts then
            return "Incorrect casts number. Actual:"..casted..". Expected:"..expected.casts.."."
        end
        if interrupted ~= expected.interrupted then
            return "Incorrect interrupted casts number. Actual:"..interrupted..". Expected:"..expected.interrupted.."."
        end
    end
    return nil
end

Tests["unknown_pets"].events = {
    -- old pet aura and start cast
    {1,"SPELL_AURA_APPLIED","Player-1603-0AF2B92","Another player",0x512,0x0,"Pet-0-3773-1861-25197-78116-010265753E",UNKNOWNOBJECT,0x1114,0x0,210320,"Aura 1",0x2,"BUFF"},
    {2,"SPELL_AURA_REMOVED","Player-1603-0AF2B92","Another player",0x512,0x0,"Pet-0-3773-1861-25197-78116-010265753E","Mob 1",0x1114,0x0,210320,"Aura 1",0x2,"BUFF"},
    {3,"SPELL_CAST_START","Pet-0-3773-1861-25197-78116-010265753E","Mob 1",0x1114,0x0,0000000000000000,nil,0x80000000,0x80000000,31707,"Spell 1",0x10},
    -- new unknown pet events
    {4,"SPELL_CAST_SUCCESS","Pet-0-3773-1861-25197-78116-020265753E",UNKNOWNOBJECT,0x1114,0x0,"Vehicle-0-3773-1861-25197-134546-00001D50B9","Enemy",0x10a48,0x0,31707,"Spell 1",0x10},
    {4,"TEST_UNIT_PET", "raidpet1", "Pet-0-3773-1861-25197-78116-020265753E"},
    {5,"SPELL_AURA_APPLIED","Player-1603-0AF2B92","Another player",0x512,0x0,"Pet-0-3773-1861-25197-78116-020265753E","Mob 1",0x1114,0x0,210320,"Aura 1",0x2,"BUFF"},
    {6,"SPELL_AURA_REMOVED","Player-1603-0AF2B92","Another player",0x512,0x0,"Pet-0-3773-1861-25197-78116-020265753E","Mob 1",0x1114,0x0,210320,"Aura 1",0x2,"BUFF"},
    {7,"SPELL_CAST_START","Pet-0-3773-1861-25197-78116-020265753E","Mob 1",0x1114,0x0,0000000000000000,nil,0x80000000,0x80000000,31707,"Spell 1",0x10},
    {8,"SPELL_CAST_SUCCESS","Pet-0-3773-1861-25197-78116-020265753E","Mob 1",0x1114,0x0,"Vehicle-0-3773-1861-25197-134546-00001D50B9","Enemy",0x10a48,0x0,31707,"Spell 1",0x10},
    {11,"SPELL_DAMAGE","Pet-0-3773-1861-25197-78116-020265753E","Mob 1",0x1114,0x0,"Vehicle-0-3773-1861-25197-134546-00001D50B9","Enemy",0x10a48,0x0,31707,"Spell 1",0x10,1000,0},
}
Tests["unknown_pets"].expectations = {
    ["Player-1604-0AD575A"] = {petGuid = "Pet-0-3773-1861-25197-78116-020265753E", casts = 1},
}
Tests["unknown_pets"].startFn = function(self)
    local parentPlayer = {}
    parentPlayer.name = "Parent player"
    parentPlayer.unit = "raid1"
    parentPlayer.class = 1
    parentPlayer.guid = "Player-1604-0AD575A"
    parentPlayer.rt = 0
    parentPlayer.type = "player"
    core:LoadExistingPlayer(parentPlayer)

    local pet = {}
    pet.name = "Mob 1"
    pet.unit = "raidpet1"
    pet.class = 0
    pet.guid = "Pet-0-3773-1861-25197-78116-010265753E"
    pet.rt = 0
    pet.type = "pet"
    pet.parentGuid = parentPlayer.guid
    pet.parentName = parentPlayer.name
    core:LoadExistingPet(pet)

    parentPlayer.pets = {}
    parentPlayer.pets[#parentPlayer.pets+1] = pet.guid
end
Tests["unknown_pets"].validate = function(self)
    if not core.tracker then return "No active encounter" end
    for parentGuid,expected in pairs(self.expectations) do
        if not core.tracker.pets[parentGuid] then return "Not found parent with guid:"..parentGuid end
        local npcId = WdLib.gen:getNpcId(expected.petGuid)
        if not npcId then return "Not found npcId for unit with guid:"..expected.petGuid end
        if not core.tracker.pets[parentGuid][npcId] then return "Not found unit for npcId:"..npcId end
        local index = WdLib.gen:findEntityIndex(core.tracker.pets[parentGuid][npcId], expected.petGuid)
        if not index then return "Not found unit for guid:"..expected.petGuid end
        local unit = core.tracker.pets[parentGuid][npcId][index]
        local casted = 0
        for k,v in pairs(unit.casts) do
            if type(v) == "table" then
                for _,data in pairs(v) do
                    if type(data) == "table" then
                        if data.status == "SUCCESS" then
                            casted = casted + 1
                        end
                    end
                end
            end
        end
        if casted ~= expected.casts then
            return "Incorrect casts number. Actual:"..casted..". Expected:"..expected.casts.."."
        end
    end
    return nil
end

function WD:_StartUnitTest(testName)
    if testName and testName ~= "" then
        if Tests[testName] then
            print("|cffffff00Starting unit test|r ["..testName.."]")
            startTest(Tests[testName], 2)
        else
            print("|cffff0000Not found unit test ["..testName.."]|r")
        end
    else
        print("|cffff0000Please specify unit test name|r")
    end
end