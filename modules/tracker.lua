
local WDMF = WD.mainFrame

local function log(data)
    if type(data) == "table" then
        print(WdLib.table:tostring(data))
    else
        print(data or "nil")
    end
end

local function hookUnitFrameCastBar(f, unit)
    if not f or (f.hooked and f.hooked == true) then
        return
    end

    --print('hooked '..unit)
    f.hooked = true
    hooksecurefunc(f, "OnEvent", function(self, event, ...)
        WDMF:Tracker_OnUnitEvent(self, event, ...)
    end)
end

local callbacks = {}
local function registerCallback(callback, ...)
    local events = {...}
    for _,v in pairs(events) do
        callbacks[v] = callback
    end
end

local function createEntity(guid, name, unit_type, parentGuid, parentName)
    local v = {}
    v.guid = guid
    v.name = name
    v.unit = "Unknown"
    v.class = 0
    v.type = unit_type
    v.parentGuid = parentGuid
    v.parentName = parentName
    v.auras = {}
    v.casts = {}
    v.stats = {}
    v.spawnedAt = WDMF.tracker.startTime
    return v
end

local function createExistingEntity(v)
    v.auras = {}
    v.casts = {}
    v.stats = {}
    v.spawnedAt = WDMF.tracker.startTime
    return v
end

local function createInternalEntity(unitId)
    if not UnitIsVisible(unitId) then return nil end
    local name = WdLib.gen:getUnitName(unitId)
    if name == UNKNOWNOBJECT then return nil end
    local _,class = UnitClass(unitId)

    local p = {}
    p.name = name
    p.unit = unitId
    p.class = class
    p.guid = UnitGUID(p.unit)
    p.rt = 0

    return p
end

local function findNpc(guid)
    if not WDMF.tracker or not WDMF.tracker.npc then return nil end
    if not guid or tonumber(guid) then return nil end
    local npcId = WdLib.gen:getNpcId(guid)
    local holder = WDMF.tracker.npc[npcId]
    local index = WdLib.gen:findEntityIndex(holder, guid)
    if index then return holder[index] end
    return nil
end

local function findPet(guid)
    if not WDMF.tracker or not WDMF.tracker.pets then return nil end
    if not guid then return nil end
    for parentGuid,infoByNpcId in pairs(WDMF.tracker.pets) do
        for name,infoByGuid in pairs(infoByNpcId) do
            local index = WdLib.gen:findEntityIndex(infoByGuid, guid)
            if index then return infoByGuid[index] end
        end
    end
    return nil
end

local function findPlayer(guid)
    if not WDMF.tracker or not WDMF.tracker.players then return nil end
    return WDMF.tracker.players[guid]
end

local function findParent(v)
    if not v or v.type ~= "pet" or not v.parentGuid or not v.parentName then return nil end
    local parent = findPlayer(v.parentGuid)
    if parent then return parent end
    return findNpc(v.parentGuid)
end

local function findEntityByGUID(guid)
    if not guid then return nil end
    local result = findPlayer(guid)
    if result then return result end
    result = findPet(guid)
    if result then return result end
    result = findNpc(guid)
    if result then return result end
    return nil
end

local function findNameplate(guid)
    for k,v in pairs(WDMF.cache_nameplates) do
        if v.guid and v.unit and v.guid == guid then
            return v
        end
    end
end

local function findUnitFrame(guid)
    for k,v in pairs(WDMF.cache_unitframes) do
        if v.guid and v.unit and v.guid == guid then
            return v
        end
    end
end

local function scanPetOwners(petGuid)
    WDMF.scanner:SetOwner(WorldFrame, "ANCHOR_NONE")
    WDMF.scanner:SetHyperlink("unit:" .. petGuid or "")

    local function scanLine(lineObj)
        local txt = lineObj:GetText()
        if not txt or txt == "" then return nil end
        for ownerGuid, owner in pairs(WDMF.tracker.players) do
            local name = WdLib.gen:getShortName(owner.name)
            if txt:find(name) then
                return ownerGuid, owner.name
            end
        end
        return nil
    end

    local ownerGuid, ownerName = scanLine(WDMF.scanner.line1)
    if not ownerGuid then
        ownerGuid, ownerName = scanLine(WDMF.scanner.line2)
    end
    return ownerGuid, ownerName
end

local function updateUnitClass(unit)
    if unit.type == "player" and unit.class == 0 then
        local _, classId = GetPlayerInfoByGUID(unit.guid)
        if classId then
            unit.class = classId
        end
    end
end

local function updateUnitName(unit, name)
    if not unit or not name then return end
    local currName = WdLib.gen:getShortName(unit.name, "noRealm")
    if currName == UNKNOWNOBJECT and name ~= UNKNOWNOBJECT then
        local newName = name
        local currId = WdLib.gen:getUnitNumber(unit.name)
        if currId then
            newName = newName.."-"..currId
        end
        unit.name = newName
    end
end

local function loadAuras(p)
    for index=1,40 do
        local _, _, _, _, duration, expirationTime, casterUnitId, _, _, spellId = UnitBuff(p.unit, index)
        if spellId then
            if not p.auras[spellId] then p.auras[spellId] = {} end
            local appliedAt = expirationTime - duration
            if appliedAt < WDMF.tracker.startTime then
                appliedAt = WDMF.tracker.startTime
            end
            local guid = p.guid
            if casterUnitId then guid = UnitGUID(casterUnitId) end
            p.auras[spellId][#p.auras[spellId]+1] = { caster = guid, applied = appliedAt, isBuff = true }
        end
    end
    for index=1,40 do
        local _, _, _, _, duration, expirationTime, casterUnitId, _, _, spellId = UnitDebuff(p.unit, index)
        if spellId then
            if not p.auras[spellId] then p.auras[spellId] = {} end
            local appliedAt = expirationTime - duration
            if appliedAt < WDMF.tracker.startTime then
                appliedAt = WDMF.tracker.startTime
            end
            local guid = p.guid
            if casterUnitId then guid = UnitGUID(casterUnitId) end
            p.auras[spellId][#p.auras[spellId]+1] = { caster = guid, applied = appliedAt, isBuff = false }
        end
    end
end

local function loadNpc(guid, name)
    local npcId = WdLib.gen:getNpcId(guid)
    local holder = WDMF.tracker.npc[npcId]
    if not holder then
        WDMF.tracker.npc[npcId] = {}
        holder = WDMF.tracker.npc[npcId]
        holder[#holder+1] = createEntity(guid, name, "creature")
        return holder[1]
    end

    local index = WdLib.gen:findEntityIndex(holder, guid)
    if not index then
        if #holder == 1 then
            holder[1].name = holder[1].name.."-1"
        end
        local npc = createEntity(guid, name.."-"..(#holder + 1), "creature")
        holder[#holder+1] = npc
        return npc
    end
    return holder[index]
end

local function loadPet(guid, name, parentGuid, parentName)
    if not parentGuid then
        parentGuid, parentName = scanPetOwners(guid)
        if not parentGuid then
            return nil
        end
    end

    local petNpcId = WdLib.gen:getNpcId(guid)
    local holder = WDMF.tracker.pets[parentGuid]
    if not holder then
        WDMF.tracker.pets[parentGuid] = {}
        WDMF.tracker.pets[parentGuid][petNpcId] = {}
        holder = WDMF.tracker.pets[parentGuid][petNpcId]
        holder[#holder+1] = createEntity(guid, name, "pet", parentGuid, parentName)
        return holder[1]
    elseif not holder[petNpcId] then
        WDMF.tracker.pets[parentGuid][petNpcId] = {}
        holder = WDMF.tracker.pets[parentGuid][petNpcId]
        holder[#holder+1] = createEntity(guid, name, "pet", parentGuid, parentName)
        return holder[1]
    else
        holder = holder[petNpcId]
    end

    local index = WdLib.gen:findEntityIndex(holder, guid)
    if not index then
        if #holder == 1 then
            holder[1].name = holder[1].name.."-1"
        end
        local pet = createEntity(guid, name.."-"..(#holder + 1), "pet", parentGuid, parentName)
        holder[#holder+1] = pet
        return pet
    end
    return holder[index]
end

local function loadPlayer(guid, name)
    if not WDMF.tracker.players[guid] then
        WDMF.tracker.players[guid] = {}
        WDMF.tracker.players[guid] = createEntity(guid, name, "player")
    end
    return WDMF.tracker.players[guid]
end

local function loadEntity(guid, name, unit_type)
    if not name or not guid or guid == "" then
        --print('no name or no guid')
        return nil
    end
    --[[if name == UNKNOWNOBJECT then
        print('trying to find guid by name next time')
        if WDMF.tracker[UNKNOWNOBJECT] and WDMF.tracker[UNKNOWNOBJECT][guid] then
            WDMF.tracker[key] = WDMF.tracker[UNKNOWNOBJECT]
            WDMF.tracker[key][guid].name = name
            WDMF.tracker[UNKNOWNOBJECT] = nil
            return WDMF.tracker[key][guid]
        end
        return nil
    end]]

    -- try to find unit as pet summoned before pull
    local parentGuid, parentName = scanPetOwners(guid)
    if parentGuid then
        return loadPet(guid, name, parentGuid, parentName)
    end

    if unit_type == "creature" then
        return loadNpc(guid, name)
    elseif unit_type == "pet" then
        return loadPet(guid, name)
    elseif unit_type == "player" then
        return loadPlayer(guid, name)
    end

    return nil
end

local function updatePet(pet, newGuid)
    if pet.guid ~= newGuid then
        if pet.parentGuid and WDMF.tracker.players[pet.parentGuid] then
            if not WDMF.tracker.players[pet.parentGuid].pets then WDMF.tracker.players[pet.parentGuid].pets = {} end
            local t = WDMF.tracker.players[pet.parentGuid].pets
            if #t == 0 then
                t[1] = newGuid
            else
                for i=1,#t do
                    if t[i] == pet.guid then
                        t[i] = newGuid
                        --print("updated pet's guid from "..pet.guid.." to "..newGuid)
                        break
                    end
                end
            end
        end
        pet.guid = newGuid
    end
end

local function updatePlayer(playerData, unitId)
    if playerData.unit == unitId then
        local newGuid = UnitGUID(unitId)
        local name = WdLib.gen:getUnitName(unitId)
        if name ~= UNKNOWNOBJECT then
            playerData.name = name
        end
        if playerData.guid ~= newGuid then
            playerData.guid = newGuid
        end
    end
end

local function getEntities(timestamp, src_guid, src_name, src_flags, src_raid_flags, dst_guid, dst_name, dst_flags, dst_raid_flags)
    if not src_name then
        src_guid = "Environment-0-0-0-0-0-0000000000"
    end
    local src = findEntityByGUID(src_guid)
    if not src then
        if not src_name then
            src_name = "Environment"
            src = loadEntity(src_guid, src_name, "creature")
        elseif WD:IsNpc(src_flags) then
            src = loadEntity(src_guid, src_name, "creature")
        elseif WD:IsPet(src_flags) then
            src = loadEntity(src_guid, src_name, "pet")
        elseif src_name then
            src_name = WdLib.gen:getFullName(src_name)
            src = loadEntity(src_guid, src_name, "player")
        end
        if src then
            src.spawnedAt = timestamp
        end
    else
        updateUnitName(src, src_name)
        updateUnitClass(src)
    end
    local dst = findEntityByGUID(dst_guid)
    if not dst then
        if WD:IsNpc(dst_flags) then
            dst = loadEntity(dst_guid, dst_name, "creature")
        elseif WD:IsPet(dst_flags) then
            dst = loadEntity(dst_guid, dst_name, "pet")
        elseif dst_name then
            dst_name = WdLib.gen:getFullName(dst_name)
            dst = loadEntity(dst_guid, dst_name, "player")
        end
        if dst then
            dst.spawnedAt = timestamp
        end
    else
        updateUnitName(dst, dst_name)
        updateUnitClass(dst)
    end

    local src_role, dst_role = "", ""
    local src_rt, dst_rt = 0, 0
    if src and not src.role then src.role = WD:GetRole(src_guid) end
    if dst and not dst.role then dst.role = WD:GetRole(dst_guid) end

    if src then src.rt = WD:GetRaidTarget(src_raid_flags) end
    if dst then dst.rt = WD:GetRaidTarget(dst_raid_flags) end

    return src, dst
end

local function findActiveAuras(unit, auraId)
    if not unit.auras[auraId] or #unit.auras[auraId] == 0 then return {} end
    local auras = {}
    for i=1,#unit.auras[auraId] do
        if not unit.auras[auraId][i].removed then
            auras[#auras+1] = unit.auras[auraId][i]
        end
    end
    return auras
end

local function hasAura(unit, auraId)
    if #findActiveAuras(unit, auraId) > 0 then return true end
    return nil
end

local function hasAnyAura(unit, auras)
    for k,v in pairs(auras) do
        if hasAura(unit, k) then return true end
    end
    return nil
end

local function findActiveAuraByCaster(unit, auraId, caster)
    local auras = findActiveAuras(unit, auraId)
    if not caster then caster = "Environment" else caster = caster.guid end
    for i=1,#auras do
        if auras[i].caster == caster then
            return auras[i]
        end
    end
    return nil
end

local function findLastAuraByCaster(unit, auraId, caster)
    if not unit.auras[auraId] or #unit.auras[auraId] == 0 then return {} end
    if not caster then caster = "Environment" else caster = caster.guid end
    for i=#unit.auras[auraId],1,-1 do
        if unit.auras[auraId][i].caster == caster then
            return unit.auras[auraId][i]
        end
    end
    return nil
end

local function isCasting(unit, spell_id)
    if unit.current_cast then
        if not spell_id then
            return unit.current_cast
        end
        if unit.current_cast.spell_id == spell_id then
            return unit.current_cast
        end
    end
    return nil
end

local function compareWithEvent(event, rType, arg0, arg1)
    if not event then return nil end
    if rType == "EV_DAMAGETAKEN" or rType == "EV_DEATH" or rType == "EV_DISPEL" then
        if event[arg0] then return true end
    elseif rType == "EV_DEATH_UNIT" then
        if event.unit == arg0 then return true end
    else
        if arg0 and arg1 and event[arg0] and event[arg0][arg1] then
            return true
        end
    end
    return nil
end

local function findRulesInRange(eventType, unit, ...)
    local rules = WDMF.encounter.statRules
    if not unit then return nil end

    local results = {}

    if rules["RL_RANGE_RULE"] and rules["RL_RANGE_RULE"]["RT_AURA_EXISTS"] then
        for auraId, eventRule in pairs(rules["RL_RANGE_RULE"]["RT_AURA_EXISTS"]) do
            if hasAura(unit, auraId) then
                results[#results+1] = eventRule[eventType]
            end
        end
    end

    if rules["RL_RANGE_RULE"] and rules["RL_RANGE_RULE"]["RT_AURA_NOT_EXISTS"] then
        for auraId, eventRule in pairs(rules["RL_RANGE_RULE"]["RT_AURA_NOT_EXISTS"]) do
            if not hasAura(unit, auraId) then
                results[#results+1] = eventRule[eventType]
            end
        end
    end

    if rules["RL_RANGE_RULE"] and rules["RL_RANGE_RULE"]["RT_UNIT_CASTING"] then
        for spellId, eventRule in pairs(rules["RL_RANGE_RULE"]["RT_UNIT_CASTING"]) do
            if isCasting(unit, spellId) then
                results[#results+1] = eventRule[eventType]
            end
        end
    end

    if rules["RL_RANGE_RULE"] and rules["RL_RANGE_RULE"]["RT_CUSTOM"] then
        for _,v in pairs(rules["RL_RANGE_RULE"]["RT_CUSTOM"]) do
            -- register start range tracking
            if compareWithEvent(v.startEv[eventType], eventType, ...) == true then
                v.isActiveForGUID[unit.guid] = 1
            end

            -- register stop range tracking
            if compareWithEvent(v.endEv[eventType], eventType, ...) == true then
                v.isActiveForGUID[unit.guid] = nil
            end

            if v.isActiveForGUID[unit.guid] and v.isActiveForGUID[unit.guid] == 1 then
                results[#results+1] = v.resultEv[eventType]
            end
        end
    end

    if rules["RL_DEPENDENCY"] then
        local function expireDependency(rule, guid)
            rule.isActiveForGUID[guid] = nil
        end
        for _,v in pairs(rules["RL_DEPENDENCY"]) do
            -- register start and stop range tracking
            if compareWithEvent(v.reasonEv[eventType], eventType, ...) == true then
                v.isActiveForGUID[unit.guid] = 1
                local timeoutInSec = v.timeout / 1000
                if v.timer then
                    v.timer = WdLib.timers:RestartTimer(v.timer, expireDependency, timeoutInSec, v, unit.guid)
                else
                    v.timer = WdLib.timers:CreateTimer(expireDependency, timeoutInSec, v, unit.guid)
                end
            end

            if v.isActiveForGUID[unit.guid] and v.isActiveForGUID[unit.guid] == 1 and v.resultEv[eventType] then
                results[#results+1] = v.resultEv[eventType]
            end
        end
    end

    local function processStatRule(statType, ...)
        if rules[statType] and rules[statType]["RT_CUSTOM"] then
            for _,v in pairs(rules[statType]["RT_CUSTOM"]) do
                -- register start range tracking
                if compareWithEvent(v.startEv[eventType], eventType, ...) == true then
                    --local statRule = WDMF.encounter.statRules[v.ruleId]
                    v.isActiveForGUID[unit.guid] = 1
                end

                -- register stop range tracking
                if compareWithEvent(v.endEv[eventType], eventType, ...) == true then
                    --local statRule = WDMF.encounter.statRules[v.ruleId]
                    v.isActiveForGUID[unit.guid] = nil
                end
            end
        end
    end
    processStatRule("ST_TARGET_HEALING", ...)
    processStatRule("ST_TARGET_DAMAGE", ...)
    --"ST_TARGET_INTERRUPTS"
    processStatRule("ST_SOURCE_HEALING", ...)
    processStatRule("ST_SOURCE_DAMAGE", ...)
    --"ST_SOURCE_INTERRUPTS"

    return results
end

local function findRuleByRole(eventType, role)
    local rules = WDMF.encounter.rules
    if rules[role] then return rules[role][eventType] end
    return nil
end

local function updateByRangeDescription(rule, originMsg)
    if not rule then return originMsg end
    if rule.range then
        originMsg = originMsg.." "..WD.GetRangeRuleDescription(rule.range[1], rule.range[2])
    elseif rule.reason then
        local reasonName, reasonArg0, reasonArg1 = rule.reason[1], rule.reason[2], rule.reason[3]
        local reasonMsg = WD.GetEventDescription(reasonName, reasonArg0, reasonArg1)
        originMsg = string.format(WD_TRACKER_RT_DEPENDENCY_DESC_SHORT, originMsg, reasonMsg)
    end
    return originMsg
end

local function processRuleByEvent(rule, timestamp, unit, eventType, ...)
    if not rule or not unit then return end
    local args = {...}
    if eventType == "EV_AURA" then
        local spell_id, action = args[1], args[2]
        if rule[spell_id] and rule[spell_id][action] then
            local p = rule[spell_id][action].points
            local msg = WD.GetEventDescription(eventType, spell_id, action)
            msg = updateByRangeDescription(rule, msg)
            WDMF:AddFail(timestamp, unit.guid, unit.rt, msg, p)
        end
    elseif eventType == "EV_AURA_STACKS" then
        local spell_id, stacks = args[1], args[2]
        if rule[spell_id] and rule[spell_id][stacks] then
            local p = rule[spell_id][stacks].points
            local msg = WD.GetEventDescription(eventType, spell_id, stacks)
            msg = updateByRangeDescription(rule, msg)
            WDMF:AddFail(timestamp, unit.guid, unit.rt, msg, p)
        elseif rule[spell_id] and rule[spell_id][0] then
            local p = rule[spell_id][0].points
            local msg = string.format(WD_RULE_AURA_STACKS_ANY, "("..stacks..")", WdLib.gui:getSpellLinkByIdWithTexture(spell_id))
            msg = updateByRangeDescription(rule, msg)
            WDMF:AddFail(timestamp, unit.guid, unit.rt, msg, p)
        end
    elseif eventType == "EV_CAST_START" or eventType == "EV_CAST_END" then
        local spell_id, unit_name = args[1], args[2]
        if rule[spell_id] then
            local key = WdLib.gen:getNpcId(unit.guid)
            if not rule[spell_id][key] then
                key = unit_name
            end
            if rule[spell_id][key] then
                local p = rule[spell_id][key].points
                local msg = WD.GetEventDescription(eventType, spell_id, unit_name)
                msg = updateByRangeDescription(rule, msg)
                if unit.type ~= "player" then
                    WDMF:AddSuccess(timestamp, "creature"..WdLib.gen:getNpcId(unit.guid), unit.rt, msg, p)
                else
                    WDMF:AddSuccess(timestamp, unit.guid, unit.rt, msg, p)
                end
            end
        end
    elseif eventType == "EV_CAST_INTERRUPTED" then
        local target_spell_id, target, target_name = args[1], args[2], args[3]
        if rule[target_spell_id] then
            local key = WdLib.gen:getNpcId(target.guid)
            if not rule[target_spell_id][key] then
                key = target_name
            end
            if rule[target_spell_id][key] then
                local p = rule[target_spell_id][key].points
                local dst_nameWithMark = target.name
                if target.rt > 0 then dst_nameWithMark = WdLib.gui:getRaidTargetTextureLink(target.rt).." "..target.name end
                local msg = WD.GetEventDescription(eventType, target_spell_id, dst_nameWithMark)
                msg = updateByRangeDescription(rule, msg)
                WDMF:AddSuccess(timestamp, unit.guid, unit.rt, msg, p)
            end
        end
    elseif eventType == "EV_DISPEL" then
        local target_aura_id = args[1]
        if rule[target_aura_id] then
            local p = rule[target_aura_id].points
            local msg = WD.GetEventDescription(eventType, target_aura_id)
            msg = updateByRangeDescription(rule, msg)
            WDMF:AddSuccess(timestamp, unit.guid, unit.rt, msg, p)
        end
    elseif eventType == "EV_UNIT_DEATH" then
        local u = rule.unit
        local unit_name = args[1]
        if (tonumber(u) and u == WdLib.gen:getNpcId(unit.guid)) or (u == unit_name) then
            local p = rule.points
            local dst_nameWithMark = unit.name
            if unit.rt > 0 then dst_nameWithMark = WdLib.gui:getRaidTargetTextureLink(dst.rt).." "..unit.name end
            local msg = WD.GetEventDescription("EV_DEATH_UNIT", dst_nameWithMark)
            msg = updateByRangeDescription(rule, msg)
            if unit.type ~= "player" then
                WDMF:AddSuccess(timestamp, "creature"..WdLib.gen:getNpcId(unit.guid), unit.rt, msg, p)
            else
                WDMF:AddSuccess(timestamp, unit.guid, unit.rt, msg, p)
            end
        end
    end
end

local function processRulesByEventType(timestamp, unit, eventType, ...)
    if not unit then return end
    local rule = findRuleByRole(eventType, unit.role)
    processRuleByEvent(rule, timestamp, unit, eventType, ...)
    local rangeRules = findRulesInRange(eventType, unit, ...)
    for _,v in pairs(rangeRules) do
        processRuleByEvent(v, timestamp, unit, eventType, ...)
    end
end

local function onCastStart(unit, startedAt, castTimeInMsec, spell_id, notInterruptible, isChannelled)
    processRulesByEventType(startedAt, unit, "EV_CAST_START", spell_id, WdLib.gen:getShortName(unit.name))

    if castTimeInMsec >= WD.MIN_CAST_TIME_TRACKED then
        local cast = {}
        cast.spell_id = spell_id
        cast.castTimeInMsec = castTimeInMsec
        cast.notInterruptible = notInterruptible
        cast.startedAt = startedAt
        cast.result = ""
        cast.isChannelled = isChannelled
        unit.current_cast = cast
    end
end

local function onCastFinish(unit, finishedAt, spell_id, result, interrupter, interrupt_spell_id)
    local cast = isCasting(unit)
    if not cast then return end

    if cast.spell_id ~= spell_id then
        --print(spell_id..' finished, but current spell is: '..cast.spell_id)
        return
    end

    local i = 1
    if unit.casts[spell_id] then
        if cast.result == "CANCELLING" then
            i = unit.casts[spell_id].count
        else
            i = unit.casts[spell_id].count + 1
        end
    else
        unit.casts[spell_id] = {}
    end

    local actualCastTimeInMsec = (finishedAt - cast.startedAt) * 1000
    --print('finished', spell_id, result)
    unit.casts[spell_id].count = i
    unit.casts[spell_id][i] = {}
    unit.casts[spell_id][i].status = result
    unit.casts[spell_id][i].timestamp = WdLib.gen:getTimedDiff(WDMF.tracker.startTime, finishedAt)
    unit.casts[spell_id][i].timediff = WdLib.gen:float_round_to(actualCastTimeInMsec / 1000, 2)
    unit.casts[spell_id][i].isChannelled = cast.isChannelled

    if result == "CANCELLED" then
        unit.casts[spell_id][i].cancelReason = interrupter
        unit.casts[spell_id][i].percent = 100
    elseif result == "SUCCESS" then
        processRulesByEventType(finishedAt, unit, "EV_CAST_END", spell_id, WdLib.gen:getShortName(unit.name))

        -- potions
        local potionRule = findRuleByRole("EV_POTIONS", unit.role)
        if potionRule then
            if WD.Spells.potions[spell_id] then
                local msg = WD.GetEventDescription("EV_POTIONS")
                WDMF:AddSuccess(timestamp, unit.guid, unit.rt, msg, potionRule.points)
            end
        end
    end

    if result == "INTERRUPTED" and interrupter then
        local parent = findParent(interrupter)
        if parent then
            interrupter = parent
        end
        --print('interrupted')

        unit.casts[spell_id][i].percent = WdLib.gen:float_round_to(actualCastTimeInMsec / cast.castTimeInMsec, 2) * 100
        if cast.isChannelled then
            unit.casts[spell_id][i].percent = 100 - unit.casts[spell_id][i].percent
        end

        unit.casts[spell_id][i].interrupter = interrupter.guid
        unit.casts[spell_id][i].spell_id = interrupt_spell_id

        -- regular rules
        local rule = findRuleByRole("EV_CAST_INTERRUPTED", interrupter.role)
        processRuleByEvent(rule, finishedAt, interrupter, "EV_CAST_INTERRUPTED", spell_id, unit, WdLib.gen:getShortName(unit.name, "ignoreRealm"))
        -- range rules
        local rangeRules = findRulesInRange("EV_CAST_INTERRUPTED", unit, spell_id, WdLib.gen:getShortName(unit.name, "ignoreRealm"))
        for _,v in pairs(rangeRules) do
            processRuleByEvent(v, finishedAt, interrupter, "EV_CAST_INTERRUPTED", spell_id, unit, WdLib.gen:getShortName(unit.name, "ignoreRealm"))
        end
        -- quality rules
        local statRules = WDMF.encounter.statRules
        if statRules["RL_QUALITY"] and
           statRules["RL_QUALITY"]["QT_INTERRUPTS"] and
           statRules["RL_QUALITY"]["QT_INTERRUPTS"][spell_id]
        then
            local actualQuality = unit.casts[spell_id][i].percent
            local expectedQuality = statRules["RL_QUALITY"]["QT_INTERRUPTS"][spell_id].qualityPercent
            if actualQuality < expectedQuality then
                WDMF:AddFail(finishedAt, interrupter.guid, interrupter.rt, string.format(WD_TRACKER_QT_INTERRUPTS_DESC, expectedQuality, WdLib.gui:getSpellLinkByIdWithTexture(spell_id)), 0)
            end
        end
    end

    if result ~= "CANCELLING" then
        unit.current_cast = nil
    else
        cast.result = result
    end
end

local function startCast(unit, startedAt, spell_id, isChannelling)
    local cast = isCasting(unit)
    if cast and unit.unit ~= "Unknown" then
        if spell_id ~= cast.spell_id then
            onCastFinish(unit, cast.startedAt, cast.spell_id, "CANCELLED", "another spell cast or movement")
        else
            local actualEndTime = nil
            if not isChannelling then
                local _,_,_,startTime,endTime,_,_,notInterruptible,spellId = UnitCastingInfo(unit.unit)
                actualEndTime = endTime / 1000
            else
                local _,_,_,startTimeMS,endTimeMS,_,_,spellId = UnitChannelInfo(unit.unit)
                actualEndTime = endTimeMS / 1000
            end
            local expectedEndTime = cast.startedAt + cast.castTimeInMsec / 1000
            if not actualEndTime or expectedEndTime < actualEndTime then
                onCastFinish(unit, cast.startedAt, cast.spell_id, "CANCELLED", "another spell cast or movement")
            else
                return
            end
        end
    end

    local nameplate = findNameplate(unit.guid)
    if nameplate and not isChannelling then
        local _,_,_,startTime,endTime,_,_,notInterruptible = UnitCastingInfo(nameplate.unit)
        local castTimeInMsec = endTime - startTime
        local startedAtInSec = startTime / 1000
        --print('findNameplate, UnitCastingInfo:', unitFrame.unit)
        onCastStart(unit, startedAtInSec, castTimeInMsec, spell_id, notInterruptible)
        return
    end

    local unitFrame = findUnitFrame(unit.guid)
    if unitFrame and not isChannelling then
        local _,_,_,startTime,endTime,_,_,notInterruptible,spellId = UnitCastingInfo(unitFrame.unit)
        if spellId then
            local castTimeInMsec = endTime - startTime
            local startedAtInSec = startTime / 1000
            --print('findUnitFrame, UnitCastingInfo:', unitFrame.unit)
            onCastStart(unit, startedAtInSec, castTimeInMsec, spell_id, notInterruptible)
            return
        end
    end

    local haste = 1
    if unit.guid ~= UnitGUID("player") then
        haste = haste + UnitSpellHaste("player") / 100.0
    end
    local castTimeInMsec = haste * select(4, GetSpellInfo(spell_id))
    --print('SPELL_CAST_START:', unit.guid)
    onCastStart(unit, startedAt, castTimeInMsec, spell_id, false, isChannelling)
end

local function onDeath(timestamp, unit)
    if not unit or unit.diedAt then return end

    unit.diedAt = timestamp

    for guid in pairs(WDMF.tracker.players) do
        if guid == unit.guid then
            WDMF.encounter.deaths = WDMF.encounter.deaths + 1
            break
        end
    end

    local cast = isCasting(unit)
    if cast and cast.result == "CANCELLING" then
        onCastFinish(unit, cast.startedAt, cast.spell_id, "CANCELLED", "death")
    end

    processRulesByEventType(timestamp, unit, "EV_DEATH_UNIT", WdLib.gen:getShortName(dst_name))
end

local function dispelAura(unit, unit_name, timestamp, source_spell_id, target_aura_id, dispeller)
    local parent = findParent(dispeller)
    if parent then
        dispeller = parent
    end

    if not unit.auras[target_aura_id] then
        local aura = {}
        aura.applied = WDMF.tracker.startTime
        aura.removed = timestamp
        aura.caster = unit.guid
        aura.dispelledAt = WdLib.gen:getTimedDiff(WDMF.tracker.startTime, timestamp)
        aura.dispelledIn = WdLib.gen:float_round_to(timestamp - aura.applied, 2)
        aura.dispell_id = source_spell_id
        aura.dispeller = dispeller.guid
        unit.auras[target_aura_id] = {}
        unit.auras[target_aura_id][1] = aura
    end

    if dispeller then
        -- regular rules
        local rule = findRuleByRole("EV_DISPEL", dispeller.role)
        processRuleByEvent(rule, timestamp, dispeller, "EV_DISPEL", target_aura_id)
        -- range rules
        local rangeRules = findRulesInRange("EV_DISPEL", unit, target_aura_id)
        for _,v in pairs(rangeRules) do
            processRuleByEvent(v, timestamp, dispeller, "EV_DISPEL", target_aura_id)
        end
    end

    for i=1, #unit.auras[target_aura_id] do
        local aura = unit.auras[target_aura_id][i]
        local diff = (timestamp - aura.applied) * 1000
        diff = WdLib.gen:float_round_to(diff / 1000, 2)
        if not aura.duration then
            local t = (timestamp - aura.applied) / 1000
            aura.duration = WdLib.gen:float_round_to(t * 1000, 2)
        end
        if diff <= aura.duration + 0.01 then
            aura.dispelledAt = WdLib.gen:getTimedDiff(WDMF.encounter.startTime, timestamp)
            aura.dispelledIn = diff
            aura.dispell_id = source_spell_id
            aura.dispeller = dispeller.guid

            if dispeller then
                -- quality rules
                local statRules = WDMF.encounter.statRules
                if statRules["RL_QUALITY"] and
                   statRules["RL_QUALITY"]["QT_DISPELS"] and
                   statRules["RL_QUALITY"]["QT_DISPELS"][target_aura_id]
                then
                    local earlyTime = statRules["RL_QUALITY"]["QT_DISPELS"][target_aura_id].earlyDispel
                    local lateTime = statRules["RL_QUALITY"]["QT_DISPELS"][target_aura_id].lateDispel
                    local dispelledIn = aura.dispelledIn * 1000
                    if earlyTime > 0 and lateTime > 0 and (dispelledIn < earlyTime or dispelledIn > lateTime) then
                        WDMF:AddFail(timestamp, dispeller.guid, dispeller.rt, string.format(WD_TRACKER_QT_DISPELS_FULL_RANGE, earlyTime, lateTime, WdLib.gui:getSpellLinkByIdWithTexture(target_aura_id)), 0)
                    elseif earlyTime > 0 and lateTime == 0 and dispelledIn < earlyTime then
                        WDMF:AddFail(timestamp, dispeller.guid, dispeller.rt, string.format(WD_TRACKER_QT_DISPELS_LEFT_RANGE, earlyTime, WdLib.gui:getSpellLinkByIdWithTexture(target_aura_id)), 0)
                    elseif earlyTime == 0 and lateTime > 0 and dispelledIn > lateTime then
                        WDMF:AddFail(timestamp, dispeller.guid, dispeller.rt, string.format(WD_TRACKER_QT_DISPELS_RIGHT_RANGE, lateTime, WdLib.gui:getSpellLinkByIdWithTexture(target_aura_id)), 0)
                    end
                end
            end
        end
    end
end

local function trackHeal(src, dst, event, spell_id, amount, overheal)
    if not WD.RulesModule then return end
    if not src or not dst then return end

    local function validateHealStatsHolders(srcTable, dstTable, event, spell_id)
        if not srcTable[dst.guid] then srcTable[dst.guid] = {} end
        if not dstTable[src.guid] then dstTable[src.guid] = {} end

        if not srcTable[dst.guid].healDone then srcTable[dst.guid].healDone = {} srcTable[dst.guid].healDone.total = 0 end
        if not srcTable[dst.guid].overhealDone then srcTable[dst.guid].overhealDone = {} srcTable[dst.guid].overhealDone.total = 0 end
        if not dstTable[src.guid].healTaken then dstTable[src.guid].healTaken = {} dstTable[src.guid].healTaken.total = 0 end
        if not dstTable[src.guid].overhealTaken then dstTable[src.guid].overhealTaken = {} dstTable[src.guid].overhealTaken.total = 0 end

        if not srcTable[dst.guid].healDone[spell_id] then srcTable[dst.guid].healDone[spell_id] = {total=0} end
        if not srcTable[dst.guid].overhealDone[spell_id] then srcTable[dst.guid].overhealDone[spell_id] = {total=0} end
        if not dstTable[src.guid].healTaken[spell_id] then dstTable[src.guid].healTaken[spell_id] = {total=0} end
        if not dstTable[src.guid].overhealTaken[spell_id] then dstTable[src.guid].overhealTaken[spell_id] = {total=0} end

        if not srcTable[dst.guid].healDone[spell_id][event] then srcTable[dst.guid].healDone[spell_id][event] = {amount = 0} end
        if not srcTable[dst.guid].overhealDone[spell_id][event] then srcTable[dst.guid].overhealDone[spell_id][event] = {amount = 0} end
        if not dstTable[src.guid].healTaken[spell_id][event] then dstTable[src.guid].healTaken[spell_id][event] = {amount = 0} end
        if not dstTable[src.guid].overhealTaken[spell_id][event] then dstTable[src.guid].overhealTaken[spell_id][event] = {amount = 0} end
    end

    local function saveHealToTable(srcTable, dstTable)
        srcTable[dst.guid].healDone.total = srcTable[dst.guid].healDone.total + amount
        srcTable[dst.guid].overhealDone.total = srcTable[dst.guid].overhealDone.total + overheal
        dstTable[src.guid].healTaken.total = dstTable[src.guid].healTaken.total + amount
        dstTable[src.guid].overhealTaken.total = dstTable[src.guid].overhealTaken.total + overheal

        srcTable[dst.guid].healDone[spell_id].total = srcTable[dst.guid].healDone[spell_id].total + amount
        srcTable[dst.guid].overhealDone[spell_id].total = srcTable[dst.guid].overhealDone[spell_id].total + overheal
        dstTable[src.guid].healTaken[spell_id].total = dstTable[src.guid].healTaken[spell_id].total + amount
        dstTable[src.guid].overhealTaken[spell_id].total = dstTable[src.guid].overhealTaken[spell_id].total + overheal

        srcTable[dst.guid].healDone[spell_id][event].amount = srcTable[dst.guid].healDone[spell_id][event].amount + amount
        srcTable[dst.guid].overhealDone[spell_id][event].amount = srcTable[dst.guid].overhealDone[spell_id][event].amount + overheal
        dstTable[src.guid].healTaken[spell_id][event].amount = dstTable[src.guid].healTaken[spell_id][event].amount + amount
        dstTable[src.guid].overhealTaken[spell_id][event].amount = dstTable[src.guid].overhealTaken[spell_id][event].amount + overheal
    end

    validateHealStatsHolders(src.stats, dst.stats, event, spell_id)
    saveHealToTable(src.stats, dst.stats)

    local rules = WDMF.encounter.statRules
    -- target related stat rules
    if rules["ST_TARGET_HEALING"] then
        local t = rules["ST_TARGET_HEALING"]
        if t["RT_AURA_EXISTS"] then
            for auraId,ruleId in pairs(t["RT_AURA_EXISTS"]) do
                if hasAura(dst, auraId) then
                    if not src.ruleStats then src.ruleStats = {} end
                    if not dst.ruleStats then dst.ruleStats = {} end
                    if not src.ruleStats[ruleId] then src.ruleStats[ruleId] = {} src.ruleStats[ruleId].stats = {} end
                    if not dst.ruleStats[ruleId] then dst.ruleStats[ruleId] = {} dst.ruleStats[ruleId].stats = {} end
                    validateHealStatsHolders(src.ruleStats[ruleId].stats, dst.ruleStats[ruleId].stats, event, spell_id)
                    saveHealToTable(src.ruleStats[ruleId].stats, dst.ruleStats[ruleId].stats)
                end
            end
        end
        if t["RT_AURA_NOT_EXISTS"] then
            for auraId,ruleId in pairs(t["RT_AURA_NOT_EXISTS"]) do
                if not hasAura(dst, auraId) then
                    if not src.ruleStats then src.ruleStats = {} end
                    if not dst.ruleStats then dst.ruleStats = {} end
                    if not src.ruleStats[ruleId] then src.ruleStats[ruleId] = {} src.ruleStats[ruleId].stats = {} end
                    if not dst.ruleStats[ruleId] then dst.ruleStats[ruleId] = {} dst.ruleStats[ruleId].stats = {} end
                    validateHealStatsHolders(src.ruleStats[ruleId].stats, dst.ruleStats[ruleId].stats, event, spell_id)
                    saveHealToTable(src.ruleStats[ruleId].stats, dst.ruleStats[ruleId].stats)
                end
            end
        end
        if t["RT_UNIT_CASTING"] then
            for targetSpellId,ruleId in pairs(t["RT_UNIT_CASTING"]) do
                if isCasting(dst, targetSpellId) then
                    if not src.ruleStats then src.ruleStats = {} end
                    if not dst.ruleStats then dst.ruleStats = {} end
                    if not src.ruleStats[ruleId] then src.ruleStats[ruleId] = {} src.ruleStats[ruleId].stats = {} end
                    if not dst.ruleStats[ruleId] then dst.ruleStats[ruleId] = {} dst.ruleStats[ruleId].stats = {} end
                    validateHealStatsHolders(src.ruleStats[ruleId].stats, dst.ruleStats[ruleId].stats, event, spell_id)
                    saveHealToTable(src.ruleStats[ruleId].stats, dst.ruleStats[ruleId].stats)
                end
            end
        end
        if t["RT_CUSTOM"] then
            for _,v in pairs(t["RT_CUSTOM"]) do
                if v.isActiveForGUID[dst.guid] and v.isActiveForGUID[dst.guid] == 1 then
                    local ruleId = v.ruleId
                    if not src.ruleStats then src.ruleStats = {} end
                    if not dst.ruleStats then dst.ruleStats = {} end
                    if not src.ruleStats[ruleId] then src.ruleStats[ruleId] = {} src.ruleStats[ruleId].stats = {} end
                    if not dst.ruleStats[ruleId] then dst.ruleStats[ruleId] = {} dst.ruleStats[ruleId].stats = {} end
                    validateHealStatsHolders(src.ruleStats[ruleId].stats, dst.ruleStats[ruleId].stats, event, spell_id)
                    saveHealToTable(src.ruleStats[ruleId].stats, dst.ruleStats[ruleId].stats)
                end
            end
        end
    end
    -- source related stat rules
    if rules["ST_SOURCE_HEALING"] then
        local t = rules["ST_SOURCE_HEALING"]
        if t["RT_AURA_EXISTS"] then
            for auraId,ruleId in pairs(t["RT_AURA_EXISTS"]) do
                if hasAura(src, auraId) then
                    if not src.ruleStats then src.ruleStats = {} end
                    if not dst.ruleStats then dst.ruleStats = {} end
                    if not src.ruleStats[ruleId] then src.ruleStats[ruleId] = {} src.ruleStats[ruleId].stats = {} end
                    if not dst.ruleStats[ruleId] then dst.ruleStats[ruleId] = {} dst.ruleStats[ruleId].stats = {} end
                    validateHealStatsHolders(src.ruleStats[ruleId].stats, dst.ruleStats[ruleId].stats, event, spell_id)
                    saveHealToTable(src.ruleStats[ruleId].stats, dst.ruleStats[ruleId].stats)
                end
            end
        end
        if t["RT_AURA_NOT_EXISTS"] then
            for auraId,ruleId in pairs(t["RT_AURA_NOT_EXISTS"]) do
                if not hasAura(src, auraId) then
                    if not src.ruleStats then src.ruleStats = {} end
                    if not dst.ruleStats then dst.ruleStats = {} end
                    if not src.ruleStats[ruleId] then src.ruleStats[ruleId] = {} src.ruleStats[ruleId].stats = {} end
                    if not dst.ruleStats[ruleId] then dst.ruleStats[ruleId] = {} dst.ruleStats[ruleId].stats = {} end
                    validateHealStatsHolders(src.ruleStats[ruleId].stats, dst.ruleStats[ruleId].stats, event, spell_id)
                    saveHealToTable(src.ruleStats[ruleId].stats, dst.ruleStats[ruleId].stats)
                end
            end
        end
        if t["RT_UNIT_CASTING"] then
            for targetSpellId,ruleId in pairs(t["RT_UNIT_CASTING"]) do
                if isCasting(src, targetSpellId) then
                    if not src.ruleStats then src.ruleStats = {} end
                    if not dst.ruleStats then dst.ruleStats = {} end
                    if not src.ruleStats[ruleId] then src.ruleStats[ruleId] = {} src.ruleStats[ruleId].stats = {} end
                    if not dst.ruleStats[ruleId] then dst.ruleStats[ruleId] = {} dst.ruleStats[ruleId].stats = {} end
                    validateHealStatsHolders(src.ruleStats[ruleId].stats, dst.ruleStats[ruleId].stats, event, spell_id)
                    saveHealToTable(src.ruleStats[ruleId].stats, dst.ruleStats[ruleId].stats)
                end
            end
        end
        if t["RT_CUSTOM"] then
            for _,v in pairs(t["RT_CUSTOM"]) do
                if v.isActiveForGUID[src.guid] and v.isActiveForGUID[src.guid] == 1 then
                    local ruleId = v.ruleId
                    if not src.ruleStats then src.ruleStats = {} end
                    if not dst.ruleStats then dst.ruleStats = {} end
                    if not src.ruleStats[ruleId] then src.ruleStats[ruleId] = {} src.ruleStats[ruleId].stats = {} end
                    if not dst.ruleStats[ruleId] then dst.ruleStats[ruleId] = {} dst.ruleStats[ruleId].stats = {} end
                    validateHealStatsHolders(src.ruleStats[ruleId].stats, dst.ruleStats[ruleId].stats, event, spell_id)
                    saveHealToTable(src.ruleStats[ruleId].stats, dst.ruleStats[ruleId].stats)
                end
            end
        end
    end
end

local function trackDamage(src, dst, event, spell_id, amount, overdmg)
    if not WD.RulesModule then return end
    if not src or not dst then return end

    if overdmg > 0 then
        onDeath(GetTime(), dst)
    end

    local function validateDmgStatsHolders(srcTable, dstTable, event, spell_id)
        if not srcTable[dst.guid] then srcTable[dst.guid] = {} end
        if not dstTable[src.guid] then dstTable[src.guid] = {} end

        if not srcTable[dst.guid].dmgDone then srcTable[dst.guid].dmgDone = {} srcTable[dst.guid].dmgDone.total = 0 end
        if not srcTable[dst.guid].overdmgDone then srcTable[dst.guid].overdmgDone = {} srcTable[dst.guid].overdmgDone.total = 0 end
        if not dstTable[src.guid].dmgTaken then dstTable[src.guid].dmgTaken = {} dstTable[src.guid].dmgTaken.total = 0 end
        if not dstTable[src.guid].overdmgTaken then dstTable[src.guid].overdmgTaken = {} dstTable[src.guid].overdmgTaken.total = 0 end

        if not srcTable[dst.guid].dmgDone[spell_id] then srcTable[dst.guid].dmgDone[spell_id] = {total=0} end
        if not srcTable[dst.guid].overdmgDone[spell_id] then srcTable[dst.guid].overdmgDone[spell_id] = {total=0} end
        if not dstTable[src.guid].dmgTaken[spell_id] then dstTable[src.guid].dmgTaken[spell_id] = {total=0} end
        if not dstTable[src.guid].overdmgTaken[spell_id] then dstTable[src.guid].overdmgTaken[spell_id] = {total=0} end

        if not srcTable[dst.guid].dmgDone[spell_id][event] then srcTable[dst.guid].dmgDone[spell_id][event] = {amount = 0} end
        if not srcTable[dst.guid].overdmgDone[spell_id][event] then srcTable[dst.guid].overdmgDone[spell_id][event] = {amount = 0} end
        if not dstTable[src.guid].dmgTaken[spell_id][event] then dstTable[src.guid].dmgTaken[spell_id][event] = {amount = 0} end
        if not dstTable[src.guid].overdmgTaken[spell_id][event] then dstTable[src.guid].overdmgTaken[spell_id][event] = {amount = 0} end
    end

    local function saveDmgToTable(srcTable, dstTable)
        srcTable[dst.guid].dmgDone.total = srcTable[dst.guid].dmgDone.total + amount
        srcTable[dst.guid].overdmgDone.total = srcTable[dst.guid].overdmgDone.total + overdmg
        dstTable[src.guid].dmgTaken.total = dstTable[src.guid].dmgTaken.total + amount
        dstTable[src.guid].overdmgTaken.total = dstTable[src.guid].overdmgTaken.total + overdmg

        srcTable[dst.guid].dmgDone[spell_id].total = srcTable[dst.guid].dmgDone[spell_id].total + amount
        srcTable[dst.guid].overdmgDone[spell_id].total = srcTable[dst.guid].overdmgDone[spell_id].total + overdmg
        dstTable[src.guid].dmgTaken[spell_id].total = dstTable[src.guid].dmgTaken[spell_id].total + amount
        dstTable[src.guid].overdmgTaken[spell_id].total = dstTable[src.guid].overdmgTaken[spell_id].total + overdmg

        srcTable[dst.guid].dmgDone[spell_id][event].amount = srcTable[dst.guid].dmgDone[spell_id][event].amount + amount
        srcTable[dst.guid].overdmgDone[spell_id][event].amount = srcTable[dst.guid].overdmgDone[spell_id][event].amount + overdmg
        dstTable[src.guid].dmgTaken[spell_id][event].amount = dstTable[src.guid].dmgTaken[spell_id][event].amount + amount
        dstTable[src.guid].overdmgTaken[spell_id][event].amount = dstTable[src.guid].overdmgTaken[spell_id][event].amount + overdmg
    end

    validateDmgStatsHolders(src.stats, dst.stats, event, spell_id)
    saveDmgToTable(src.stats, dst.stats)

    local rules = WDMF.encounter.statRules
    -- target related stat rules
    if rules["ST_TARGET_DAMAGE"] then
        local t = rules["ST_TARGET_DAMAGE"]
        local targetName = WdLib.gen:getShortName(dst.name, "norealm")
        if t["RT_AURA_EXISTS"] and t["RT_AURA_EXISTS"][targetName] then
            for auraId,ruleId in pairs(t["RT_AURA_EXISTS"][targetName]) do
                if hasAura(dst, auraId) then
                    if not src.ruleStats then src.ruleStats = {} end
                    if not dst.ruleStats then dst.ruleStats = {} end
                    if not src.ruleStats[ruleId] then src.ruleStats[ruleId] = {} src.ruleStats[ruleId].stats = {} end
                    if not dst.ruleStats[ruleId] then dst.ruleStats[ruleId] = {} dst.ruleStats[ruleId].stats = {} end
                    validateDmgStatsHolders(src.ruleStats[ruleId].stats, dst.ruleStats[ruleId].stats, event, spell_id)
                    saveDmgToTable(src.ruleStats[ruleId].stats, dst.ruleStats[ruleId].stats)
                end
            end
        end
        if t["RT_AURA_NOT_EXISTS"] and t["RT_AURA_NOT_EXISTS"][targetName] then
            for auraId,ruleId in pairs(t["RT_AURA_NOT_EXISTS"][targetName]) do
                if not hasAura(dst, auraId) then
                    if not src.ruleStats then src.ruleStats = {} end
                    if not dst.ruleStats then dst.ruleStats = {} end
                    if not src.ruleStats[ruleId] then src.ruleStats[ruleId] = {} src.ruleStats[ruleId].stats = {} end
                    if not dst.ruleStats[ruleId] then dst.ruleStats[ruleId] = {} dst.ruleStats[ruleId].stats = {} end
                    validateDmgStatsHolders(src.ruleStats[ruleId].stats, dst.ruleStats[ruleId].stats, event, spell_id)
                    saveDmgToTable(src.ruleStats[ruleId].stats, dst.ruleStats[ruleId].stats)
                end
            end
        end
        if t["RT_UNIT_CASTING"] and t["RT_UNIT_CASTING"][targetName] then
            for targetSpellId,ruleId in pairs(t["RT_UNIT_CASTING"][targetName]) do
                if isCasting(dst, targetSpellId) then
                    if not src.ruleStats then src.ruleStats = {} end
                    if not dst.ruleStats then dst.ruleStats = {} end
                    if not src.ruleStats[ruleId] then src.ruleStats[ruleId] = {} src.ruleStats[ruleId].stats = {} end
                    if not dst.ruleStats[ruleId] then dst.ruleStats[ruleId] = {} dst.ruleStats[ruleId].stats = {} end
                    validateDmgStatsHolders(src.ruleStats[ruleId].stats, dst.ruleStats[ruleId].stats, event, spell_id)
                    saveDmgToTable(src.ruleStats[ruleId].stats, dst.ruleStats[ruleId].stats)
                end
            end
        end
        if t["RT_CUSTOM"] then
            for _,v in pairs(t["RT_CUSTOM"]) do
                if v.isActiveForGUID[dst.guid] and v.isActiveForGUID[dst.guid] == 1 then
                    local ruleId = v.ruleId
                    if not src.ruleStats then src.ruleStats = {} end
                    if not dst.ruleStats then dst.ruleStats = {} end
                    if not src.ruleStats[ruleId] then src.ruleStats[ruleId] = {} src.ruleStats[ruleId].stats = {} end
                    if not dst.ruleStats[ruleId] then dst.ruleStats[ruleId] = {} dst.ruleStats[ruleId].stats = {} end
                    validateDmgStatsHolders(src.ruleStats[ruleId].stats, dst.ruleStats[ruleId].stats, event, spell_id)
                    saveDmgToTable(src.ruleStats[ruleId].stats, dst.ruleStats[ruleId].stats)
                end
            end
        end
    end
    -- source related stat rules
    if rules["ST_SOURCE_DAMAGE"] then
        local t = rules["ST_SOURCE_DAMAGE"]
        if t["RT_AURA_EXISTS"] then
            for auraId,ruleId in pairs(t["RT_AURA_EXISTS"]) do
                if hasAura(src, auraId) then
                    if not src.ruleStats then src.ruleStats = {} end
                    if not dst.ruleStats then dst.ruleStats = {} end
                    if not src.ruleStats[ruleId] then src.ruleStats[ruleId] = {} src.ruleStats[ruleId].stats = {} end
                    if not dst.ruleStats[ruleId] then dst.ruleStats[ruleId] = {} dst.ruleStats[ruleId].stats = {} end
                    validateDmgStatsHolders(src.ruleStats[ruleId].stats, dst.ruleStats[ruleId].stats, event, spell_id)
                    saveDmgToTable(src.ruleStats[ruleId].stats, dst.ruleStats[ruleId].stats)
                end
            end
        end
        if t["RT_AURA_NOT_EXISTS"] then
            for auraId,ruleId in pairs(t["RT_AURA_NOT_EXISTS"]) do
                if not hasAura(src, auraId) then
                    if not src.ruleStats then src.ruleStats = {} end
                    if not dst.ruleStats then dst.ruleStats = {} end
                    if not src.ruleStats[ruleId] then src.ruleStats[ruleId] = {} src.ruleStats[ruleId].stats = {} end
                    if not dst.ruleStats[ruleId] then dst.ruleStats[ruleId] = {} dst.ruleStats[ruleId].stats = {} end
                    validateDmgStatsHolders(src.ruleStats[ruleId].stats, dst.ruleStats[ruleId].stats, event, spell_id)
                    saveDmgToTable(src.ruleStats[ruleId].stats, dst.ruleStats[ruleId].stats)
                end
            end
        end
        if t["RT_UNIT_CASTING"] then
            for targetSpellId,ruleId in pairs(t["RT_UNIT_CASTING"]) do
                if isCasting(src, targetSpellId) then
                    if not src.ruleStats then src.ruleStats = {} end
                    if not dst.ruleStats then dst.ruleStats = {} end
                    if not src.ruleStats[ruleId] then src.ruleStats[ruleId] = {} src.ruleStats[ruleId].stats = {} end
                    if not dst.ruleStats[ruleId] then dst.ruleStats[ruleId] = {} dst.ruleStats[ruleId].stats = {} end
                    validateDmgStatsHolders(src.ruleStats[ruleId].stats, dst.ruleStats[ruleId].stats, event, spell_id)
                    saveDmgToTable(src.ruleStats[ruleId].stats, dst.ruleStats[ruleId].stats)
                end
            end
        end
        if t["RT_CUSTOM"] then
            for _,v in pairs(t["RT_CUSTOM"]) do
                if v.isActiveForGUID[src.guid] and v.isActiveForGUID[src.guid] == 1 then
                    local ruleId = v.ruleId
                    if not src.ruleStats then src.ruleStats = {} end
                    if not dst.ruleStats then dst.ruleStats = {} end
                    if not src.ruleStats[ruleId] then src.ruleStats[ruleId] = {} src.ruleStats[ruleId].stats = {} end
                    if not dst.ruleStats[ruleId] then dst.ruleStats[ruleId] = {} dst.ruleStats[ruleId].stats = {} end
                    validateDmgStatsHolders(src.ruleStats[ruleId].stats, dst.ruleStats[ruleId].stats, event, spell_id)
                    saveDmgToTable(src.ruleStats[ruleId].stats, dst.ruleStats[ruleId].stats)
                end
            end
        end
    end
end

local function debugEvent(...)
    if WD.DebugEnabled == false then return end
    local info = ChatTypeInfo["COMBAT_MISC_INFO"];
    local t, event, hideCaster, srcGUID, srcName, srcFlags, srcRaidFlags, dstGUID, dstName, dstFlags, dstRaidFlags = ...
    local message = format("%s, %s, %s, 0x%x, 0x%x, %s, %s, 0x%x, 0x%x", event, srcGUID, srcName or "nil", srcFlags, srcRaidFlags, dstGUID, dstName or "nil", dstFlags, dstRaidFlags);
    for i = 11, select("#", ...) do
        message = message..", "..tostring(select(i, ...));
    end
    ChatFrame1:AddMessage(message, info.r, info.g, info.b);
end

local function synchNameplates(self, frame, removedUnit)
    if not self.cache_nameplates then self.cache_nameplates = {} end

    local function updateNameplate(f)
        local unit = f.namePlateUnitToken
        if not unit then return end
        if not self.cache_nameplates[unit] then
            local data = {}
            data.frame = f
            data.guid = UnitGUID(unit)
            data.unit = unit
            hookUnitFrameCastBar(f.unitFrame.castBar, unit)
            self.cache_nameplates[data.unit] = data
        else
            local data = self.cache_nameplates[unit]
            data.frame = f
            data.guid = UnitGUID(unit)
            data.unit = unit
            hookUnitFrameCastBar(f.unitFrame.castBar, unit)
        end
        local guid = self.cache_nameplates[unit].guid
        if not findEntityByGUID(guid) then
            local e = loadEntity(guid, UnitName(unit), "creature")
            if e then
                e.spawnedAt = GetTime()
                e.rt = GetRaidTargetIndex(unit) or 0
            end
        end
    end

    if frame then
        updateNameplate(frame)
    elseif removedUnit then
        local data = self.cache_nameplates[removedUnit]
        if data then
            data.guid = nil
        end
    else
        WdLib.table:wipe(self.cache_nameplates)
        for i, f in ipairs(C_NamePlate.GetNamePlates(issecure())) do
            if f.namePlateUnitToken then
                updateNameplate(f)
            end
        end
    end
end

local function synchUnitFrames(self, frame, removedUnit)
    if not self.cache_unitframes then self.cache_unitframes = {} end

    local function registerUnitFrame(f, unit)
        if not f or (f.registered and f.registered == true) then
            return
        end

        --print('registered '..unit)
        f.registered = true
        f:SetScript("OnEvent", function(self, event, ...)
            --print(event, ...)
            WDMF:Tracker_OnUnitEvent(self, event, ...)
        end)
    end

    local function updateUnitFrame(f)
        local unit = f.unitToken
        if not unit then return end
        if self.cache_unitframes[unit] then
            local data = self.cache_unitframes[unit]
            data.frame = f
            data.guid = UnitGUID(unit)
            data.unit = unit
            registerUnitFrame(f, unit)
        end
        local guid = self.cache_unitframes[unit].guid
        if not findEntityByGUID(guid) then
            local e = loadEntity(guid, UnitName(unit), "creature")
            if e then
                e.spawnedAt = GetTime()
                e.rt = GetRaidTargetIndex(unit) or 0
            end
        end
    end

    if frame then
        updateUnitFrame(frame)
    elseif removedUnit then
        local data = self.cache_unitframes[removedUnit]
        if data then
            data.guid = nil
        end
    else
        local function createUnitFrame(unitToken, frameName)
            if self.cache_unitframes[unitToken] then
                return
            end

            local f = CreateFrame("Frame", frameName)
            f.unit = unitToken
            local data = {}
            data.frame = f
            data.guid = UnitGUID(unitToken)
            data.unit = unitToken
            registerUnitFrame(f, unitToken)
            self.cache_unitframes[data.unit] = data
        end

        for i=1,8 do
            createUnitFrame("boss"..i, "WD_BossFrame_"..i)
        end

        if UnitInRaid("player") ~= nil then
            for i=1, GetNumGroupMembers() do
                createUnitFrame("raid"..i, "WD_RaidFrame_"..i)
                createUnitFrame("raidpet"..i, "WD_RaidPetFrame_"..i)
            end
        elseif UnitInParty("player") ~= false then
            for i=1, GetNumGroupMembers() do
                createUnitFrame("party"..i, "WD_PartyFrame_"..i)
                createUnitFrame("partypet"..i, "WD_PartyPetFrame_"..i)
            end
        else
            createUnitFrame("player", "WD_PlayerFrame")
            createUnitFrame("pet", "WD_PlayerPetFrame")
        end
    end
end

function WDMF:ProcessSummons(src, dst, ...)
    if not src then return end
    local arg = {...}
    local _, event, src_name, dst_guid, dst_name, spell_id = arg[1], arg[2], arg[5], arg[8], arg[9], tonumber(arg[12])
    if not dst_name then return end
    -----------------------------------------------------------------------------------------------------------------------
    if event == "SPELL_SUMMON" then
        local pet = loadPet(dst_guid, dst_name, src.guid, src.name)
        pet.spawnedAt = GetTime()
        if not src.pets then src.pets = {} end
        src.pets[#src.pets+1] = pet.guid
    end
end

function WDMF:ProcessAuras(src, dst, ...)
    if not dst then return end
    local arg = {...}
    local _, event, src_name, dst_name, spell_id, auraType = arg[1], arg[2], arg[5], arg[9], tonumber(arg[12]), arg[15]
    local timestamp = GetTime()
    if not src and src_name then return end
    if not dst and dst_name then return end
    -----------------------------------------------------------------------------------------------------------------------
    if event == "SPELL_AURA_APPLIED" then
        -- auras
        if not dst.auras[spell_id] then dst.auras[spell_id] = {} end
        local auras = dst.auras[spell_id]
        if src then
            auras[#auras+1] = { caster = src.guid, applied = timestamp, isBuff = auraType == "BUFF", stacks = 1 }
        else
            auras[#auras+1] = { caster = "Environment", applied = timestamp, isBuff = auraType == "BUFF", stacks = 1 }
        end

        -- interrupts
        if dst.current_cast then
            if WD.Spells.knockbackEffects[spell_id] --[[and not hasAnyAura(dst, WD.Spells.rootEffects)]] then
                onCastFinish(dst, timestamp, dst.current_cast.spell_id, "INTERRUPTED", src, spell_id)
            end
            if WD.Spells.controlEffects[spell_id] then
                onCastFinish(dst, timestamp, dst.current_cast.spell_id, "INTERRUPTED", src, spell_id)
            end
            if WD.Spells.silenceEffects[spell_id] then
                local nameplate = findNameplate(dst.guid)
                if nameplate then
                    local name,_,_,_,_,_,castId,notInterruptible = UnitCastingInfo(nameplate.unit)
                    if name and notInterruptible == false then
                        onCastFinish(dst, timestamp, dst.current_cast.spell_id, "INTERRUPTED", src, spell_id)
                    elseif dst.current_cast.notInterruptible == false then
                        onCastFinish(dst, timestamp, dst.current_cast.spell_id, "INTERRUPTED", src, spell_id)
                    end
                end
            end
        end

        processRulesByEventType(timestamp, dst, "EV_AURA", spell_id, "apply")

        -- potions
        local potionRule = findRuleByRole("EV_POTIONS", dst.role)
        if potionRule then
            if WD.Spells.potions[spell_id] then
                local msg = WD.GetEventDescription("EV_POTIONS")
                WDMF:AddSuccess(timestamp, dst.guid, dst.rt, msg, potionRule.points)
            end
        end
    end
    -----------------------------------------------------------------------------------------------------------------------
    if event == "SPELL_AURA_REMOVED" then
        if dst.auras[spell_id] then
            local aura = findActiveAuraByCaster(dst, spell_id, src)
            if aura then
                aura.removed = timestamp
                local t = (aura.removed - aura.applied) / 1000
                aura.duration = WdLib.gen:float_round_to(t * 1000, 2)
            end
        end

        processRulesByEventType(timestamp, dst, "EV_AURA", spell_id, "remove")
    end
    -----------------------------------------------------------------------------------------------------------------------
    if event == "SPELL_AURA_APPLIED_DOSE" then
        local stacks = tonumber(arg[16])

        if dst.auras[spell_id] then
            local aura = findActiveAuraByCaster(dst, spell_id, src)
            if aura then
                aura.stacks = stacks
            end
        end

        processRulesByEventType(timestamp, dst, "EV_AURA_STACKS", spell_id, stacks)
    end
    -----------------------------------------------------------------------------------------------------------------------
    if event == "SPELL_AURA_REMOVED_DOSE" then
        local stacks = tonumber(arg[16])

        if dst.auras[spell_id] then
            local aura = findActiveAuraByCaster(dst, spell_id, src)
            if aura then
                aura.stacks = stacks
            end
        end
    end
end

function WDMF:ProcessCasts(src, dst, ...)
    if not src then return end
    local rules = self.encounter.rules
    local arg = {...}
    local serverTime, event, src_guid, src_name, dst_name, spell_id = arg[1], arg[2], arg[4], arg[5], arg[9], tonumber(arg[12])
    local timestamp = GetTime()
    if not src and src_name then return end
    if not dst and dst_name then return end

    -----------------------------------------------------------------------------------------------------------------------
    if event == "SPELL_CAST_START" then
        startCast(src, timestamp, spell_id)
    end
    -----------------------------------------------------------------------------------------------------------------------
    if event == "SPELL_CAST_SUCCESS" then
        --print('SPELL_CAST_SUCCESS:', src.guid, spell_id)
        local _,_,_,startTimeMS,endTimeMS,_,notInterruptible,spellId = UnitChannelInfo(src.unit)
        if not spellId then
            onCastFinish(src, timestamp, spell_id, "SUCCESS")
        elseif spellId == spell_id then
            startCast(src, timestamp, spell_id, true)
        end
    end
    -----------------------------------------------------------------------------------------------------------------------
    if event == "SPELL_INTERRUPT" then
        if dst then
            --print('SPELL_INTERRUPT')
            local target_spell_id = tonumber(arg[15])
            onCastFinish(dst, timestamp, target_spell_id, "INTERRUPTED", src, spell_id)
        end
    end
end

function WDMF:ProcessEnvironmentDamage(src, dst, ...)
    if not dst then return end
    local arg = {...}
    local _, event, src_name, dst_name = arg[1], arg[2], arg[5], arg[9]
    if not src and src_name then return end
    if not dst and dst_name then return end
    -----------------------------------------------------------------------------------------------------------------------
    --debugEvent(...)
    -----------------------------------------------------------------------------------------------------------------------
    local environmentType, amount = arg[12], arg[13]
    local spell_id = "Environment: "..environmentType
    trackDamage(src, dst, event, spell_id, amount, 0)
end

function WDMF:ProcessWhiteDamage(src, dst, ...)
    if not dst then return end
    local arg = {...}
    local _, event, src_name, dst_name = arg[1], arg[2], arg[5], arg[9]
    if not src and src_name then return end
    if not dst and dst_name then return end
    -----------------------------------------------------------------------------------------------------------------------
    --debugEvent(...)
    -----------------------------------------------------------------------------------------------------------------------
    local amount, overkill, spell_id
    if event == "SWING_DAMAGE" then
        amount, overkill, spell_id = tonumber(arg[12]), tonumber(arg[13]), ACTION_SWING
    end
    if event == "RANGE_DAMAGE" then
        amount, overkill, spell_id = tonumber(arg[15]), tonumber(arg[16]), tonumber(arg[12])
    end

    if overkill > 0 then amount = amount - overkill end
    if overkill == -1 then overkill = 0 end
    trackDamage(src, dst, event, spell_id, amount, overkill)
end

function WDMF:ProcessSpellDamage(src, dst, ...)
    if not src or not dst then return end
    local arg = {...}
    local _, event, src_name, dst_name = arg[1], arg[2], arg[5], arg[9]
    local timestamp = GetTime()
    if not src and src_name then return end
    if not dst and dst_name then return end
    -----------------------------------------------------------------------------------------------------------------------
    --debugEvent(...)
    -----------------------------------------------------------------------------------------------------------------------
    local spell_id, amount, overkill = tonumber(arg[12]), tonumber(arg[15]), tonumber(arg[16])
    if overkill > 0 then amount = amount - overkill end
    if overkill == -1 then overkill = 0 end
    trackDamage(src, dst, event, spell_id, amount, overkill)

    if event == "SPELL_DAMAGE" then
        -- interrupts
        --[[if WD.Spells.knockbackEffects[spell_id] and not hasAnyAura(dst, WD.Spells.rootEffects) then
            onCastFinish(dst, timestamp, dst.current_cast.spell_id, "INTERRUPTED", src, spell_id)
        end]]

        local function processRules(deathRule, damageTakenRule)
            if deathRule or damageTakenRule then
                local total = amount + overkill
                if overkill == 0 then total = total + 1 end

                if overkill > -1 and deathRule and deathRule[spell_id] then
                    local p = deathRule[spell_id].points
                    local msg = WD.GetEventDescription("EV_DEATH", spell_id)
                    msg = updateByRangeDescription(deathRule, msg)
                    WDMF:AddFail(timestamp, dst.guid, dst.rt, msg, p)
                else
                    if damageTakenRule and damageTakenRule[spell_id] then
                        local p = damageTakenRule[spell_id].points
                        if (damageTakenRule[spell_id].amount > 0 and total > damageTakenRule[spell_id].amount) or
                           (damageTakenRule[spell_id].amount == 0 and total > 0)
                        then
                            local msg = WD.GetEventDescription("EV_DAMAGETAKEN", spell_id, damageTakenRule[spell_id].amount)
                            msg = updateByRangeDescription(damageTakenRule, msg)
                            WDMF:AddFail(timestamp, dst.guid, dst.rt, msg, p)
                        end
                    end
                end
            end
        end
        local function processRangeRules(deathRules, damageRules)
            if deathRules and #deathRules > 0 and damageRules and #damageRules > 0 then
                local pairedRulesByRange = {}
                for _,v1 in pairs(deathRules) do
                    for _,v2 in pairs(damageRules) do
                        if v1.range == v2.range then
                            pairedRulesByRange[#pairedRulesByRange+1] = {v1,v2}
                        else
                            pairedRulesByRange[#pairedRulesByRange+1] = {v1,nil}
                            pairedRulesByRange[#pairedRulesByRange+1] = {nil,v2}
                        end
                    end
                end
                for i=1,#pairedRulesByRange do
                    local v = pairedRulesByRange[i]
                    processRules(v[1], v[2])
                end
            elseif deathRules and #deathRules > 0 then
                for _,v in pairs(deathRules) do
                    processRules(v, nil)
                end
            elseif damageRules and #damageRules > 0 then
                for _,v in pairs(damageRules) do
                    processRules(nil, v)
                end
            end
        end

        -- regular rules
        local deathRule = findRuleByRole("EV_DEATH", dst.role)
        local damageTakenRule = findRuleByRole("EV_DAMAGETAKEN", dst.role)
        processRules(deathRule, damageTakenRule)
        -- range rules
        local deathRangeRules = findRulesInRange("EV_DEATH", dst, spell_id)
        local damageTakenRangeRules = findRulesInRange("EV_DAMAGETAKEN", dst, spell_id)
        processRangeRules(deathRangeRules, damageTakenRangeRules)
    end
end

function WDMF:ProcessHealing(src, dst, ...)
    if not src or not dst then return end
    local rules = self.encounter.rules
    local arg = {...}
    local _, event, src_name, dst_name, spell_id = arg[1], arg[2], arg[5], arg[9], tonumber(arg[12])
    if not src and src_name then return end
    if not dst and dst_name then return end
    -----------------------------------------------------------------------------------------------------------------------
    --debugEvent(...)
    -----------------------------------------------------------------------------------------------------------------------
    local amount, overheal, absorb = tonumber(arg[15]), tonumber(arg[16]), tonumber(arg[17])
    amount = amount - overheal

    trackHeal(src, dst, event, spell_id, amount, overheal)
end

function WDMF:ProcessLeechEffects(src, dst, ...)
    if not src or not dst then return end
    local rules = self.encounter.rules
    local arg = {...}
    local _, event, src_name, dst_name, spell_id = arg[1], arg[2], arg[5], arg[9], tonumber(arg[12])
    if not src and src_name then return end
    if not dst and dst_name then return end
    -----------------------------------------------------------------------------------------------------------------------
    debugEvent(...)
end

function WDMF:ProcessAbsorbs(src, dst, ...)
    if not dst then return end
    local rules = self.encounter.rules
    local arg = {...}
    local _, event, src_name, dst_name = arg[1], arg[2], arg[5], arg[9]
    local timestamp = GetTime()
    if not src and src_name then return end
    if not dst and dst_name then return end
    -------------------------------------------------------------------

    -- non-spell atacks
    local aura_caster_guid, aura_caster_name, aura_caster_flags, aura_caster_raid_flags, aura_id, _, _, amount = select(12, ...)
    if tonumber(aura_caster_guid) then
        -- spell attacks
        local spell_id = arg[12]
        aura_caster_guid, aura_caster_name, aura_caster_flags, aura_caster_raid_flags, aura_id, _, _, amount = select(15, ...)
    end
    local aura_caster = getEntities(timestamp, aura_caster_guid, aura_caster_name, aura_caster_flags, aura_caster_raid_flags)
    if not aura_caster then return end

    trackHeal(aura_caster, dst, event, aura_id, amount, 0)
end

function WDMF:ProcessDeaths(src, dst, ...)
    if not dst then return end
    local arg = {...}
    local _, event, dst_name, spell_id = arg[1], arg[2], arg[9], tonumber(arg[12])
    local timestamp = GetTime()
    if not dst and dst_name then return end
    -----------------------------------------------------------------------------------------------------------------------
    if event == "UNIT_DIED" then
        onDeath(timestamp, dst)
    end
    -----------------------------------------------------------------------------------------------------------------------
    if event == "SPELL_INSTAKILL" then
        if src then
            trackDamage(src, dst, event, spell_id, 0, 1)
        end
        debugEvent(...)
    end
end

function WDMF:ProcessDispels(src, dst, ...)
    if not src then return end
    local rules = self.encounter.rules
    local arg = {...}
    local _, event, src_name, dst_name, spell_id = arg[1], arg[2], arg[5], arg[9], tonumber(arg[12])
    local timestamp = GetTime()
    if not src and src_name then return end
    if not dst and dst_name then return end
    -----------------------------------------------------------------------------------------------------------------------
    if event == "SPELL_DISPEL" or event == "SPELL_STOLEN" then
        local target_aura_id = tonumber(arg[15])
        if WD.Spells.ignoreDispelEffects[target_aura_id] then return end
        dispelAura(dst, dst_name, timestamp, spell_id, target_aura_id, src)
    end
end

function WDMF:ProcessTests(...)
    local _, event = ...
    if event == "TEST_UNIT_PET" then
        local args = {...}
        local unitId, newGuid = args[4], args[5]
        if unitId:match("pet") then
            for parentGuid,npcData in pairs(self.tracker.pets) do
                for npcId,dataByNpcId in pairs(npcData) do
                    for _,petData in pairs(dataByNpcId) do
                        if petData.unit == unitId then
                            updatePet(petData, newGuid)
                        end
                    end
                end
            end
        end
    end
end

function WDMF:LoadRules()
    local function getStatRuleDescription(rule)
        local function getRangeRuleDescription(rangeRule, data)
            if rangeRule == "RT_AURA_EXISTS" then
                return string.format(WD_TRACKER_RT_AURA_EXISTS_DESC, WdLib.gui:getSpellLinkByIdWithTexture(data))
            elseif rangeRule == "RT_AURA_NOT_EXISTS" then
                return string.format(WD_TRACKER_RT_AURA_NOT_EXISTS_DESC, WdLib.gui:getSpellLinkByIdWithTexture(data))
            elseif rangeRule == "RT_UNIT_CASTING" then
                return string.format(WD_TRACKER_RT_UNIT_CASTING_DESC, WdLib.gui:getSpellLinkByIdWithTexture(data))
            elseif rangeRule == "RT_CUSTOM" then
                local startEventMsg = WD.GetEventDescription(data.startEvent[1], data.startEvent[2][1], data.startEvent[2][2])
                local endEventMsg = WD.GetEventDescription(data.endEvent[1], data.endEvent[2][1], data.endEvent[2][2])
                return string.format(WD_TRACKER_RT_CUSTOM_DESC, startEventMsg, endEventMsg)
            end
        end

        if rule.arg0 == "ST_TARGET_DAMAGE" then
            local msg = string.format(WD_RULE_ST_TARGET_DAMAGE, rule.targetUnit)
            return msg.." "..getRangeRuleDescription(rule.arg1[1], rule.arg1[2])
        elseif rule.arg0 == "ST_TARGET_HEALING" then
            return WD_RULE_ST_TARGET_HEALING.." "..getRangeRuleDescription(rule.arg1[1], rule.arg1[2])
        elseif rule.arg0 == "ST_TARGET_INTERRUPTS" then
            return WD_RULE_ST_TARGET_INTERRUPTS.." "..getRangeRuleDescription(rule.arg1[1], rule.arg1[2])
        elseif rule.arg0 == "ST_SOURCE_DAMAGE" then
            return WD_RULE_ST_SOURCE_DAMAGE.." "..getRangeRuleDescription(rule.arg1[1], rule.arg1[2])
        elseif rule.arg0 == "ST_SOURCE_HEALING" then
            return WD_RULE_ST_SOURCE_HEALING.." "..getRangeRuleDescription(rule.arg1[1], rule.arg1[2])
        elseif rule.arg0 == "ST_SOURCE_INTERRUPTS" then
            return WD_RULE_ST_SOURCE_INTERRUPTS.." "..getRangeRuleDescription(rule.arg1[1], rule.arg1[2])
        end
    end

    local function fillEventByType(event, rType, arg0, arg1, p)
        if rType == "EV_DAMAGETAKEN" then
            event[arg0] = {}
            event[arg0].amount = arg1
            event[arg0].points = p
        elseif rType == "EV_DEATH" or rType == "EV_DISPEL" then
            event[arg0] = {}
            event[arg0].points = p
        elseif rType == "EV_DEATH_UNIT" then
            event.unit = arg0
            event.points = p
        elseif rType == "EV_POTIONS" or rType == "EV_FLASKS" or rType == "EV_FOOD" or rType == "EV_RUNES" or rType == "EV_ARMORKIT" or rType == "EV_OILS" then
            event.points = p
        else
            if not event[arg0] then
                event[arg0] = {}
            end
            if not event[arg0][arg1] then
                event[arg0][arg1] = {}
            end
            event[arg0][arg1].points = p
        end
    end

    local function getActiveRules(journalId)
        local rules = {
            ["EV_DAMAGETAKEN"] = {},    -- done
            ["EV_DEATH"] = {},            -- done
            ["EV_AURA"] = {{{}}},        -- done
            ["EV_AURA_STACKS"] = {},    -- done
            ["EV_CAST_START"] = {},        -- done
            ["EV_CAST_END"] = {},            -- done
            ["EV_CAST_INTERRUPTED"] = {},    -- done
            ["EV_DEATH_UNIT"] = {},        -- done
            ["EV_DISPEL"] = {},         -- done
            ["EV_POTIONS"] = {},        -- done
            ["EV_FLASKS"] = {},            -- done
            ["EV_FOOD"] = {},            -- done
            ["EV_RUNES"] = {},            -- done
            ["EV_ARMORKIT"] = {},   -- todo
            ["EV_OILS"] = {},       -- todo
        }

        for i=1,#WD.db.profile.rules do
            if WD.db.profile.rules[i].isActive == true and (WD.db.profile.rules[i].journalId == journalId or WD.db.profile.rules[i].journalId == -1) then
                local roles = WD:GetAllowedRoles(WD.db.profile.rules[i].role)
                local rType = WD.db.profile.rules[i].type
                local arg0 = WD.db.profile.rules[i].arg0
                local arg1 = WD.db.profile.rules[i].arg1
                local p = WD.db.profile.rules[i].points
                for _,role in pairs(roles) do
                    if not rules[role] then rules[role] = {} end
                    if not rules[role][rType] then rules[role][rType] = {} end
                    fillEventByType(rules[role][rType], rType, arg0, arg1, p)
                end
            end
        end

        return rules
    end

    local function getActiveStatRules(journalId)
        local rules = {}
        for rule_id=1,#WD.db.profile.statRules do
            local r = WD.db.profile.statRules[rule_id]
            if r.isActive == true and (r.journalId == journalId or r.journalId == -1) then
                if not rules[r.ruleType] then rules[r.ruleType] = {} end
                if r.ruleType == "RL_QUALITY" then
                    if not rules["RL_QUALITY"][r.arg0] then rules["RL_QUALITY"][r.arg0] = {} end
                    if not rules["RL_QUALITY"][r.arg0][r.arg1] then rules["RL_QUALITY"][r.arg0][r.arg1] = {} end
                    if r.arg0 == "QT_INTERRUPTS" then
                        rules["RL_QUALITY"]["QT_INTERRUPTS"][r.arg1].qualityPercent = r.qualityPercent
                    elseif r.arg0 == "QT_DISPELS" then
                        rules["RL_QUALITY"]["QT_DISPELS"][r.arg1].earlyDispel = r.earlyDispel
                        rules["RL_QUALITY"]["QT_DISPELS"][r.arg1].lateDispel = r.lateDispel
                    end
                elseif r.ruleType == "RL_RANGE_RULE" then
                    local rangeType = r.arg0[1]
                    if not rules["RL_RANGE_RULE"][rangeType] then rules["RL_RANGE_RULE"][rangeType] = {} end
                    if rangeType == "RT_AURA_EXISTS" or
                       rangeType == "RT_AURA_NOT_EXISTS" or
                       rangeType == "RT_UNIT_CASTING"
                    then
                        local spellId = r.arg0[2]
                        if not rules["RL_RANGE_RULE"][rangeType][spellId] then rules["RL_RANGE_RULE"][rangeType][spellId] = {} end
                        local eventType = r.arg1[1]
                        if not rules["RL_RANGE_RULE"][rangeType][spellId][eventType] then rules["RL_RANGE_RULE"][rangeType][spellId][eventType] = {} end
                        local eventData = rules["RL_RANGE_RULE"][rangeType][spellId][eventType]
                        fillEventByType(eventData, eventType, r.arg1[2][1], r.arg1[2][2], 0)
                        eventData.range = {rangeType, spellId}
                    elseif rangeType == "RT_CUSTOM" then
                        local data = rules["RL_RANGE_RULE"][rangeType]
                        local eventData = { startEv = {}, endEv = {}, resultEv = {}, isActiveForGUID = {} }
                        local sEvName, eEvName, rEvName = r.arg0[2].startEvent[1], r.arg0[2].endEvent[1], r.arg1[1]
                        eventData.startEv[sEvName] = {}
                        eventData.endEv[eEvName] = {}
                        eventData.resultEv[rEvName] = {}
                        fillEventByType(eventData.startEv[sEvName], sEvName, r.arg0[2].startEvent[2][1], r.arg0[2].startEvent[2][2], 0)
                        fillEventByType(eventData.endEv[eEvName], eEvName, r.arg0[2].endEvent[2][1], r.arg0[2].endEvent[2][2], 0)
                        fillEventByType(eventData.resultEv[rEvName], rEvName, r.arg1[2][1], r.arg1[2][2], 0)
                        eventData.resultEv[rEvName].range = {rangeType, {
                            {sEvName, r.arg0[2].startEvent[2][1], r.arg0[2].startEvent[2][2]},
                            {eEvName, r.arg0[2].endEvent[2][1], r.arg0[2].endEvent[2][2]}
                        }}
                        data[#data+1] = eventData
                    end
                elseif r.ruleType == "RL_DEPENDENCY" then
                    local data = rules["RL_DEPENDENCY"]
                    local reasonName, reasonArg0, reasonArg1 = r.arg0[1], r.arg0[2][1], r.arg0[2][2]
                    local resultName, resultArg0, resultArg1 = r.arg1[1], r.arg1[2][1], r.arg1[2][2]
                    local eventData = { reasonEv = {}, resultEv = {}, timeout = r.timeout, isActiveForGUID = {} }
                    eventData.reasonEv[reasonName] = {}
                    eventData.resultEv[resultName] = {}
                    fillEventByType(eventData.reasonEv[reasonName], reasonName, reasonArg0, reasonArg1, 0)
                    fillEventByType(eventData.resultEv[resultName], resultName, resultArg0, resultArg1, 0)
                    eventData.resultEv[resultName].reason = {reasonName, reasonArg0, reasonArg1}
                    data[#data+1] = eventData
                elseif r.ruleType == "RL_STATISTICS" then
                    local statType = r.arg0
                    if not rules[statType] then rules[statType] = {} end
                    local rangeType = r.arg1[1]
                    if not rules[statType][rangeType] then rules[statType][rangeType] = {} end
                    if rangeType == "RT_AURA_EXISTS" or
                       rangeType == "RT_AURA_NOT_EXISTS" or
                       rangeType == "RT_UNIT_CASTING"
                    then
                        local spellId = r.arg1[2]
                        if not self.tracker.statRules then self.tracker.statRules = {} end
                        if statType == "ST_TARGET_DAMAGE" then
                            local unitName = r.targetUnit
                            if not rules[statType][rangeType][unitName] then rules[statType][rangeType][unitName] = {} end
                            if not rules[statType][rangeType][unitName][spellId] then rules[statType][rangeType][unitName][spellId] = rule_id end
                        else
                            if not rules[statType][rangeType][spellId] then rules[statType][rangeType][spellId] = rule_id end
                        end
                        self.tracker.statRules[rule_id] = { id = rule_id, data = r, description = getStatRuleDescription(r) }
                    elseif rangeType == "RT_CUSTOM" then
                        if not self.tracker.statRules then self.tracker.statRules = {} end
                        local data = rules[statType][rangeType]
                        local eventData = { startEv = {}, endEv = {}, ruleId = rule_id, isActiveForGUID = {} }
                        local sEvName, eEvName = r.arg1[2].startEvent[1], r.arg1[2].endEvent[1]
                        eventData.startEv[sEvName] = {}
                        eventData.endEv[eEvName] = {}
                        fillEventByType(eventData.startEv[sEvName], sEvName, r.arg1[2].startEvent[2][1], r.arg1[2].startEvent[2][2], 0)
                        fillEventByType(eventData.endEv[eEvName], eEvName, r.arg1[2].endEvent[2][1], r.arg1[2].endEvent[2][2], 0)
                        data[#data+1] = eventData
                        self.tracker.statRules[rule_id] = { id = rule_id, data = r, description = getStatRuleDescription(r) }
                    end
                end
            end
        end

        return rules
    end

    -- search journalId for encounter
    local journalId = WD.FindEncounterJournalIdByName(self.encounter.encounterName)
    if not journalId then
        journalId = WD.FindEncounterJournalIdByName("ALL")
        print("Unknown name for encounterId:"..self.encounter.id)
    end

    self.encounter.rules = getActiveRules(journalId)
    self.encounter.statRules = getActiveStatRules(journalId)
end

function WDMF:CheckConsumables(player)
    local guid = player.guid
    local rules = self.encounter.rules
    local role = WD:GetRole(guid)
    local noflask, nofood, norune = nil, nil, nil
    if rules[role] and rules[role]["EV_FLASKS"] and not hasAnyAura(player, WD.Spells.flasks) then
        WDMF:AddFail(GetTime(), guid, 0, WD.GetEventDescription("EV_FLASKS"), rules[role]["EV_FLASKS"].points)
    end
    if rules[role] and rules[role]["EV_FOOD"] and not hasAnyAura(player, WD.Spells.food) then
        WDMF:AddFail(GetTime(), guid, 0, WD.GetEventDescription("EV_FOOD"), rules[role]["EV_FOOD"].points)
    end
    if rules[role] and rules[role]["EV_RUNES"] and not hasAnyAura(player, WD.Spells.runes) then
        WDMF:AddFail(GetTime(), guid, 0, WD.GetEventDescription("EV_RUNES"), rules[role]["EV_RUNES"].points)
    end
    if rules[role] and rules[role]["EV_POTIONS"] and hasAnyAura(player, WD.Spells.potions) then
        WDMF:AddSuccess(GetTime(), guid, 0, WD.GetEventDescription("EV_POTIONS"), rules[role]["EV_POTIONS"].points)
    end

    if rules[role] and rules[role]["EV_ARMORKIT"] then
        local kits = self.MRTCache.armorkits[player.name]
        if not kits or kits == 0 then
            WDMF:AddFail(GetTime(), guid, 0, WD.GetEventDescription("EV_ARMORKIT"), rules[role]["EV_ARMORKIT"].points)
        end
    end
    if rules[role] and rules[role]["EV_OILS"] then
        local oils = self.MRTCache.oils[player.name]
        local oils2 = self.MRTCache.oils2[player.name]
        if not oils or oils == 0 then
            WDMF:AddFail(GetTime(), guid, 0, WD.GetEventDescription("EV_OILS"), rules[role]["EV_OILS"].points)
        end
    end
end

function WDMF:Init()
    WdLib.table:wipe(callbacks)
    registerCallback(self.ProcessSummons,           "SPELL_SUMMON")
    registerCallback(self.ProcessAuras,             "SPELL_AURA_APPLIED", "SPELL_AURA_REMOVED", "SPELL_AURA_APPLIED_DOSE", "SPELL_AURA_REMOVED_DOSE")
    registerCallback(self.ProcessCasts,             "SPELL_CAST_START", "SPELL_CAST_SUCCESS", "SPELL_INTERRUPT")
    registerCallback(self.ProcessEnvironmentDamage, "ENVIRONMENTAL_DAMAGE")
    registerCallback(self.ProcessWhiteDamage,       "SWING_DAMAGE", "RANGE_DAMAGE")
    registerCallback(self.ProcessSpellDamage,       "SPELL_DAMAGE", "DAMAGE_SHIELD", "SPELL_PERIODIC_DAMAGE", "SPELL_BUILDING_DAMAGE")
    registerCallback(self.ProcessHealing,           "SPELL_HEAL", "SPELL_BUILDING_HEAL", "SPELL_PERIODIC_HEAL")
    registerCallback(self.ProcessAbsorbs,           "SPELL_ABSORBED")
    --registerCallback(self.ProcessLeaching,          "SPELL_LEECH", "SPELL_PERIODIC_LEECH", "SPELL_DRAIN", "SPELL_PERIODIC_DRAIN")
    registerCallback(self.ProcessDispels,           "SPELL_DISPEL", "SPELL_STOLEN")
    registerCallback(self.ProcessDeaths,            "UNIT_DIED", "UNIT_DESTROYED", "UNIT_DISSIPATES", "SPELL_INSTAKILL")

    -- internal events
    registerCallback(self.ProcessTests,             "TEST_UNIT_PET")
end

function WDMF:CreateRaidMember(unitId, petUnitId)
    local player = createInternalEntity(unitId)
    local pet = createInternalEntity(petUnitId)

    if player then
        if WD.cache.raidroster[player.name] then
            player.specId = WD.cache.raidroster[player.guid].specId
        elseif player.unit ~= "player" then
            NotifyInspect(player.unit)
        end

        player.type = "player"
        self:LoadExistingPlayer(player)

        self:CheckConsumables(player)
    end

    if pet then
        pet.type = "pet"
        pet.name = WdLib.gen:getShortName(pet.name)
        pet.parentGuid = player.guid
        pet.parentName = player.name
        self:LoadExistingPet(pet)

        if not player.pets then player.pets = {} end
        player.pets[#player.pets+1] = pet.guid
    end
end

function WDMF:UpdateRaidMember(unitId)
    local function updateByUnitId(unitId)
        if unitId:match("pet") then
            for parentGuid,npcData in pairs(self.tracker.pets) do
                for npcId,petData in pairs(npcData) do
                    if petData.unit == unitId then
                        local newGuid = UnitGUID(unitId)
                        local name = WdLib.gen:getUnitName(unitId)
                        if name ~= UNKNOWNOBJECT then
                            petData.name = name
                        end
                        updatePet(petData, newGuid)
                    end
                end
            end
        else
            for guid,playerData in pairs(self.tracker.players) do
                if playerData.unit == unitId then
                    updatePlayer(playerData, unitId)
                end
            end
        end
        return nil
    end

    updateByUnitId(unitId)
end

function WDMF:CreateBoss(unitId)
    local boss = createInternalEntity(unitId)
    if boss then
        boss.type = "creature"
        self:LoadExistingNpc(boss)
    end
end

function WDMF:ProcessPull()
    if UnitInRaid("player") ~= nil then
        for i=1, GetNumGroupMembers() do
            self:CreateRaidMember("raid"..i, "raidpet"..i)
        end
    elseif UnitInParty("player") ~= false then
        for i=1, GetNumGroupMembers() do
            self:CreateRaidMember("party"..i, "partypet"..i)
        end
    else
        self:CreateRaidMember("player", "pet")
    end

    -- load bosses
    for i=1,8 do
        self:CreateBoss("boss"..i)
    end
end

function WDMF:Tracker_OnStartEncounter()
    self.tracker = {}
    self.tracker.pullName = self.encounter.pullName
    self.tracker.startTime = self.encounter.startTime
    self.tracker.npc = {}
    self.tracker.pets = {}
    self.tracker.players = {}

    if #WD.db.profile.tracker == WD.MaxPullsToBeSaved then
        table.remove(WD.db.profile.tracker, 1)
    end
    WD.db.profile.tracker[#WD.db.profile.tracker+1] = self.tracker
    WD.db.profile.tracker.selected = #WD.db.profile.tracker

    self:LoadRules()
    self:ProcessPull()

    synchNameplates(self)
    --[[synchUnitFrames(self)
    for k,v in pairs(self.cache_unitframes) do
        if v.frame then
            v.frame:RegisterEvent("PLAYER_ENTERING_WORLD")
            v.frame:RegisterUnitEvent("UNIT_SPELLCAST_START", k)
            v.frame:RegisterUnitEvent("UNIT_SPELLCAST_STOP", k)
            v.frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", k)
            v.frame:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", k)
        end
    end]]

    WD:RefreshTrackerPulls()
    WD:RefreshBasicMonitors()
    WD:RefreshBasicStatsMonitors()
end

function WDMF:Tracker_OnStopEncounter()
    -- finish auras and casts
    for _,npcHolder in pairs(self.tracker.npc) do
        for k=1,#npcHolder do
            local src = npcHolder[k]
            for i=1,#src.auras do
                local aura = src.auras[i]
                aura.removed = timestamp
                local t = (aura.removed - aura.applied) / 1000
                aura.duration = WdLib.gen:float_round_to(t * 1000, 2)
            end
            local cast = isCasting(src)
            if cast then
                onCastFinish(src, cast.startedAt, cast.spell_id, "CANCELLED", "stop encounter")
            end
        end
    end

    --[[for k,v in pairs(self.cache_unitframes) do
        if v.frame then
            v.frame:UnregisterAllEvents()
        end
    end]]

    if not WD.db.profile.tracker or #WD.db.profile.tracker == 0 then return end
    local n = WD.db.profile.tracker[#WD.db.profile.tracker].pullName
    WD.db.profile.tracker[#WD.db.profile.tracker].endTime = self.encounter.endTime
    WD.db.profile.tracker[#WD.db.profile.tracker].pullName = n.." ("..WdLib.gen:getTimedDiffShort(self.tracker.startTime, self.tracker.endTime)..")"

    WD:RefreshTrackerPulls()
    WD:RefreshBasicMonitors()
    WD:RefreshBasicStatsMonitors()
end

function WDMF:Tracker_OnEvent(...)
    --debugEvent(...)
    local _, event, _, src_guid, src_name, src_flags, src_raid_flags, dst_guid, dst_name, dst_flags, dst_raid_flags = ...
    if callbacks[event] then
        if event == "SPELL_SUMMON" then
            local src = getEntities(GetTime(), src_guid, src_name, src_flags, src_raid_flags)
            callbacks[event](self, src, nil, ...)
        elseif event:match("TEST_") then
            callbacks[event](self, ...)
        else
            local src, dst = getEntities(GetTime(), src_guid, src_name, src_flags, src_raid_flags, dst_guid, dst_name, dst_flags, dst_raid_flags)
            callbacks[event](self, src, dst, ...)
        end
    end
end

function WDMF:Tracker_OnUnitEvent(frame, event, ...)
    if self.isActive == 0 then return end

    local arg1 = ...
    local unit = frame.unit
    --print(event, unit)
    if event == "PLAYER_ENTERING_WORLD" then
        if UnitChannelInfo(unit) then
            event = "UNIT_SPELLCAST_CHANNEL_START"
            arg1 = unit
        elseif UnitCastingInfo(unit) then
            event = "UNIT_SPELLCAST_START"
            arg1 = unit
        else
            return
        end
    end

	if arg1 ~= unit then
		return
	end

    if event == "UNIT_SPELLCAST_START"
    or event == "UNIT_SPELLCAST_STOP"
    or event == "UNIT_SPELLCAST_CHANNEL_START"
    or event == "UNIT_SPELLCAST_CHANNEL_STOP"
    --or event == "UNIT_SPELLCAST_CHANNEL_UPDATE"
    then
        if self.cache_nameplates[unit] or self.cache_unitframes[unit] then
            local data = self.cache_nameplates[unit] or self.cache_unitframes[unit]
            if data.guid then
                local src = findEntityByGUID(data.guid)
                if not src then return end

                if event == "UNIT_SPELLCAST_START" then
                    if not frame.spellID then
                        local _,_,_,startTimeMS,endTimeMS,_,_,notInterruptible,spellId = UnitCastingInfo(unit)
                        frame.spellStartTime = startTimeMS / 1000
                        frame.spellEndTime = endTimeMS / 1000
                        frame.notInterruptible = notInterruptible
                        frame.spellID = spellId
                    end
                    local cast = isCasting(src)
                    if cast then
                        local _,_,_,startTimeMS,endTimeMS,_,_,spellId = UnitChannelInfo(unit)
                        if not spellId then
                            --print(event, 'onCastFinish', 'CANCELLED')
                            onCastFinish(src, cast.startedAt, cast.spell_id, "CANCELLED", "another spell cast or movement")
                        end
                    end
                    if not isCasting(src) then
                        local castTimeInMsec = (frame.spellEndTime - frame.spellStartTime) * 1000
                        --print(event, data.guid, frame.spellID, 'onCastStart')
                        onCastStart(src, frame.spellStartTime, castTimeInMsec, frame.spellID, frame.notInterruptible)
                    end
                elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
                    if not frame.spellID then
                        local _,_,_,startTimeMS,endTimeMS,_,notInterruptible,spellId = UnitChannelInfo(unit)
                        frame.spellStartTime = startTimeMS / 1000
                        frame.spellEndTime = endTimeMS / 1000
                        frame.notInterruptible = notInterruptible
                        frame.spellID = spellId
                    end
                    local cast = isCasting(src)
                    if cast then
                        local _,_,_,startTimeMS,endTimeMS,_,_,spellId = UnitChannelInfo(unit)
                        if not spellId or spellId ~= frame.spellID then
                            onCastFinish(src, cast.startedAt, cast.spell_id, "CANCELLED", "another spell cast or movement")
                        end
                    end
                    if not isCasting(src) then
                        local castTimeInMsec = (frame.spellEndTime - frame.spellStartTime) * 1000
                        --print(event, data.guid, frame.spellID, castTimeInMsec)
                        onCastStart(src, frame.spellStartTime, castTimeInMsec, frame.spellID, frame.notInterruptible, true)
                    end
                elseif event == "UNIT_SPELLCAST_STOP" then
                    local _,_,spell_id = ...
                    local cast = isCasting(src, spell_id)
                    if cast then
                        --print(event, data.guid, spell_id, 'CANCELLING')
                        onCastFinish(src, cast.startedAt, cast.spell_id, "CANCELLING")
                    end
                    if frame.spellID then
                        frame.spellID = nil
                    end
                elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
                    local _,_,spell_id = ...
                    local cast = isCasting(src, spell_id)
                    if cast then
                        --print(event, data.guid, spell_id, cast.castTimeInMsec)
                        onCastFinish(src, GetTime(), cast.spell_id, "SUCCESS")
                    end
                    if frame.spellID then
                        frame.spellID = nil
                    end
                --[[
                else
                    print(event, data.guid)]]
                end
            end
        end
    end
end

function WDMF:Tracker_OnNameplateEvent(event, ...)
    --print(event, ...)
    if event == "NAME_PLATE_CREATED" or event == "FORBIDDEN_NAME_PLATE_CREATED" then
        synchNameplates(self, ...)
    elseif event == "NAME_PLATE_UNIT_ADDED" or event == "FORBIDDEN_NAME_PLATE_UNIT_ADDED" then
        local f = C_NamePlate.GetNamePlateForUnit(...)
        synchNameplates(self, f)
    elseif event == "NAME_PLATE_UNIT_REMOVED" or event == "FORBIDDEN_NAME_PLATE_UNIT_REMOVED" then
        synchNameplates(self, nil, ...)
    end
end

function WDMF:LoadExistingPet(pet)
    if not pet or not pet.parentGuid then return end
    local petNpcId = WdLib.gen:getNpcId(pet.guid)
    local holder = WDMF.tracker.pets[pet.parentGuid]
    if not holder then
        WDMF.tracker.pets[pet.parentGuid] = {}
        WDMF.tracker.pets[pet.parentGuid][petNpcId] = {}
        holder = WDMF.tracker.pets[pet.parentGuid][petNpcId]
        holder[#holder+1] = createExistingEntity(pet)
        loadAuras(pet)
        return
    elseif not holder[petNpcId] then
        WDMF.tracker.pets[pet.parentGuid][petNpcId] = {}
        holder = WDMF.tracker.pets[pet.parentGuid][petNpcId]
        holder[#holder+1] = createExistingEntity(pet)
        loadAuras(pet)
        return
    else
        holder = holder[petNpcId]
    end

    local index = WdLib.gen:findEntityIndex(holder, pet.guid)
    if not index then
        if #holder == 1 then
            holder[1].name = holder[1].name.."-1"
        end
        pet = createExistingEntity(pet)
        pet.name = pet.name.."-"..(#holder + 1)
        holder[#holder+1] = pet
        loadAuras(pet)
        return
    end
end

function WDMF:LoadExistingPlayer(v)
    if not WDMF.tracker.players[v.guid] then
        WDMF.tracker.players[v.guid] = {}
        WDMF.tracker.players[v.guid] = createExistingEntity(v)
        loadAuras(v)
    end
end

function WDMF:LoadExistingNpc(npc)
    if not npc then return end
    local npcId = WdLib.gen:getNpcId(npc.guid)
    local holder = WDMF.tracker.npc[npcId]
    if not holder then
        WDMF.tracker.npc[npcId] = {}
        holder = WDMF.tracker.npc[npcId]
        holder[#holder+1] = createExistingEntity(npc)
        loadAuras(npc)
        return
    end

    local index = WdLib.gen:findEntityIndex(holder, npc.guid)
    if not index then
        if #holder == 1 then
            holder[1].name = holder[1].name.."-1"
        end
        npc = createExistingEntity(npc)
        holder[#holder+1] = npc
        loadAuras(npc)
        return
    end
end

function WD:IsNpc(flags)
    if not flags then return nil end
    local f = bit.band(flags, COMBATLOG_OBJECT_TYPE_MASK)
    if f == COMBATLOG_OBJECT_TYPE_NPC then return true end
    return nil
end

function WD:IsPet(flags)
    if not flags then return nil end
    local f = bit.band(flags, COMBATLOG_OBJECT_TYPE_MASK)
    if f == COMBATLOG_OBJECT_TYPE_PET or f == COMBATLOG_OBJECT_TYPE_GUARDIAN or f == COMBATLOG_OBJECT_TYPE_OBJECT then return true end
    return nil
end

function WD:GetRaidTarget(flags)
    local rt = bit.band(flags, COMBATLOG_OBJECT_RAIDTARGET_MASK)
    if rt > 0 then
        if rt == COMBATLOG_OBJECT_RAIDTARGET1 then return 1
        elseif rt == COMBATLOG_OBJECT_RAIDTARGET2 then return 2
        elseif rt == COMBATLOG_OBJECT_RAIDTARGET3 then return 3
        elseif rt == COMBATLOG_OBJECT_RAIDTARGET4 then return 4
        elseif rt == COMBATLOG_OBJECT_RAIDTARGET5 then return 5
        elseif rt == COMBATLOG_OBJECT_RAIDTARGET6 then return 6
        elseif rt == COMBATLOG_OBJECT_RAIDTARGET7 then return 7
        elseif rt == COMBATLOG_OBJECT_RAIDTARGET8 then return 8
        end
    end
    return 0
end
