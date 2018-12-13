
local WDMF = WD.mainFrame

local callbacks = {}
local function registerCallback(callback, ...)
    local events = {...}
    for _,v in pairs(events) do
        callbacks[v] = callback
    end
end

local function getNpcId(guid)
    return select(6, strsplit("-", guid))
end

local function createEntity(guid, name, unit_type, parentGuid, parentName)
    local v = {}
    v.guid = guid
    v.name = name
    v.type = unit_type
    v.parentGuid = parentGuid
    v.parentName = parentName
    v.auras = {}
    v.casts = {}
    v.casts.current_spell_id = 0
    return v
end

local function createExistingEntity(v)
    v.auras = {}
    v.casts = {}
    v.casts.current_spell_id = 0
    return v
end

local function findEntityIndex(holder, guid)
    if not holder then return nil end
    for i=1,#holder do
        if holder[i] and holder[i].guid == guid then return i end
    end
    return nil
end

local function findNpc(guid)
    if not WDMF.tracker.npc then return nil end
    if not guid or not guid:match("Creature") then return nil end
    local npcId = getNpcId(guid)
    local holder = WDMF.tracker.npc[npcId]
    local index = findEntityIndex(holder, guid)
    if index then return holder[index] end
    return nil
end

local function findPet(guid)
    if not WDMF.tracker.pet then return nil end
    if not guid then return nil end
    for k,v in pairs(WDMF.tracker.pet) do
        local index = findEntityIndex(v, guid)
        if index then return v[index] end
    end
    return nil
end

local function findPlayer(guid)
    if not WDMF.tracker.players then return nil end
    return WDMF.tracker.players[guid]
end

local function findParent(v)
    if v.type ~= "pet" or not v.parentGuid or not v.parentName then return nil end
    local parent = findPlayer(v.parentGuid)
    if parent then return parent end
    return findNpc(v.parentGuid)
end

local function loadNpc(guid, name)
    local npcId = getNpcId(guid)
    local holder = WDMF.tracker.npc[npcId]
    if not holder then
        WDMF.tracker.npc[npcId] = {}
        holder = WDMF.tracker.npc[npcId]
        holder[#holder+1] = createEntity(guid, name, "creature")
        return holder[1]
    end

    local index = findEntityIndex(holder, guid)
    if not index then
        if #holder == 1 then
            holder[1].name = holder[1].name.."-1"
        end
        local npc = createEntity(guid, name.."-"..(#holder + 1), "creature")
        holder[#holder+1] = npc
        return npc
    end
    holder[index].type = "creature"
    return holder[index]
end

local function loadPet(guid, name, parentGuid, parentName)
    local holder = WDMF.tracker.pets[name]
    if not holder then
        WDMF.tracker.pets[name] = {}
        holder = WDMF.tracker.pets[name]
        holder[#holder+1] = createEntity(guid, name, "pet", parentGuid, parentName)
        return holder[1]
    end

    local index = findEntityIndex(holder, guid)
    if not index then
        if #holder == 1 then
            holder[1].name = holder[1].name.."-1"
        end
        local pet = createEntity(guid, name.."-"..(#holder + 1), "pet", parentGuid, parentName)
        holder[#holder+1] = pet
        return pet
    end
    if parentGuid then holder[index].parentGuid = parentGuid end
    if parentName then holder[index].parentName = parentName end
    holder[index].type = "pet"
    return holder[index]
end

local function loadExistingPet(pet)
    local holder = WDMF.tracker.pets[pet.name]
    if not holder then
        WDMF.tracker.pets[pet.name] = {}
        holder = WDMF.tracker.pets[pet.name]
        holder[#holder+1] = createExistingEntity(pet)
        return
    end

    local index = findEntityIndex(holder, pet.guid)
    if not index then
        if #holder == 1 then
            holder[1].name = holder[1].name.."-1"
        end
        pet = createExistingEntity(pet)
        pet.name = pet.name.."-"..(#holder + 1)
        holder[#holder+1] = pet
        return
    end
    if parentGuid then holder[index].parentGuid = pet.parentGuid end
    if parentName then holder[index].parentName = pet.parentName end
    holder[index].type = "pet"
end

local function loadPlayer(guid, name)
    if not WDMF.tracker.players[guid] then
        WDMF.tracker.players[guid] = {}
        WDMF.tracker.players[guid] = createEntity(guid, name, "player")
    end
    return WDMF.tracker.players[guid]
end

local function loadExistingPlayer(v)
    if not WDMF.tracker.players[v.guid] then
        WDMF.tracker.players[v.guid] = {}
        WDMF.tracker.players[v.guid] = createExistingEntity(v)
    end
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

    if unit_type == "creature" then
        return loadNpc(guid, name)
    elseif unit_type == "pet" then
        return loadPet(guid, name)
    elseif unit_type == "player" then
        return loadPlayer(guid, name)
    end

    return nil
end

local function getEntities(src_guid, src_name, src_flags, src_raid_flags, dst_guid, dst_name, dst_flags, dst_raid_flags)
    local src = WD:FindEntityByGUID(src_guid)
    if not src then
        if WD:IsNpc(src_flags) then
            src = loadEntity(src_guid, src_name, "creature")
        elseif WD:IsPet(src_flags) then
            src = loadEntity(src_guid, src_name, "pet")
        elseif src_name then
            src_name = WdLib:getFullCharacterName(src_name)
            src = loadEntity(src_guid, src_name, "player")
        end
    end
    local dst = WD:FindEntityByGUID(dst_guid)
    if not dst then
        if WD:IsNpc(dst_flags) then
            dst = loadEntity(dst_guid, dst_name, "creature")
        elseif WD:IsPet(dst_flags) then
            dst = loadEntity(dst_guid, dst_name, "pet")
        elseif dst_name then
            dst_name = WdLib:getFullCharacterName(dst_name)
            dst = loadEntity(dst_guid, dst_name, "player")
        end
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
    if unit.casts.current_spell_id == spell_id then return true end
    return nil
end

local function findRuleInRange(eventType, unit)
    local rules = WDMF.encounter.statRules
    if not unit then return nil end

    if rules["RL_RANGE_RULE"] and rules["RL_RANGE_RULE"]["RT_AURA_EXISTS"] then
        for auraId, eventRule in pairs(rules["RL_RANGE_RULE"]["RT_AURA_EXISTS"]) do
            if hasAura(unit, auraId) then return eventRule[eventType] end
        end
    end

    if rules["RL_RANGE_RULE"] and rules["RL_RANGE_RULE"]["RT_AURA_NOT_EXISTS"] then
        for auraId, eventRule in pairs(rules["RL_RANGE_RULE"]["RT_AURA_NOT_EXISTS"]) do
            if not hasAura(unit, auraId) then return eventRule[eventType] end
        end
    end

    if rules["RL_RANGE_RULE"] and rules["RL_RANGE_RULE"]["RT_UNIT_CASTING"] then
        for spellId, eventRule in pairs(rules["RL_RANGE_RULE"]["RT_UNIT_CASTING"]) do
            if isCasting(unit, spellId) then return eventRule[eventType] end
        end
    end

    return nil
end

local function findRuleByRole(eventType, role)
    local rules = WDMF.encounter.rules
    if rules[role] then return rules[role][eventType] end
    return nil
end

local function startCast(unit, timestamp, spell_id)
    unit.casts.current_spell_id = spell_id
    local haste = 1
    if unit.guid ~= UnitGUID("player") then
        haste = haste + UnitSpellHaste("player") / 100.0
    end
    unit.casts.current_cast_time = haste * select(4, GetSpellInfo(spell_id))
    unit.casts.current_timestamp = timestamp
end

local function interruptCast(self, unit, unit_name, timestamp, source_spell_id, target_spell_id, interrupter)
    if unit.casts.current_spell_id == 0 then return end
    if unit.casts.current_spell_id == target_spell_id then
        local parent = findParent(interrupter)
        if parent then
            interrupter = parent
        end

        local i = 1
        if unit.casts[target_spell_id] then
            i = unit.casts[target_spell_id].count + 1
        else
            unit.casts[target_spell_id] = {}
        end
        local diff = (timestamp - unit.casts.current_timestamp) * 1000
        unit.casts[target_spell_id].count = i
        unit.casts[target_spell_id][i] = {}
        unit.casts[target_spell_id][i].timestamp = WdLib:getTimedDiff(self.encounter.startTime, timestamp)
        unit.casts[target_spell_id][i].timediff = WdLib:float_round_to(diff / 1000, 2)
        unit.casts[target_spell_id][i].percent = WdLib:float_round_to(diff / unit.casts.current_cast_time, 2) * 100
        unit.casts[target_spell_id][i].status = "INTERRUPTED"
        unit.casts[target_spell_id][i].interrupter = interrupter.guid
        unit.casts[target_spell_id][i].spell_id = source_spell_id

        if interrupter then
            local function processRule(rule)
                if rule and rule[target_spell_id] then
                    local key = getNpcId(unit.guid)
                    if not rule[target_spell_id][key] then
                        key = WdLib:getShortCharacterName(unit_name, "ignoreRealm")
                    end
                    if rule[target_spell_id][key] then
                        local p = rule[target_spell_id][key].points
                        local dst_nameWithMark = unit.name
                        if unit.rt > 0 then dst_nameWithMark = WdLib:getRaidTargetTextureLink(unit.rt).." "..unit.name end
                        local msg = WD.GetEventDescription("EV_CAST_INTERRUPTED", target_spell_id, dst_nameWithMark)
                        if rule.range then
                            msg = msg.." "..WD.GetRangeRuleDescription(rule.range[1], rule.range[2])
                        end
                        WDMF:AddSuccess(timestamp, interrupter.guid, interrupter.rt, msg, p)
                    end
                end
            end
            -- regular rules
            local rule = findRuleByRole("EV_CAST_INTERRUPTED", interrupter.role)
            processRule(rule)
            -- range rules
            local rangeRule = findRuleInRange("EV_CAST_INTERRUPTED", unit)
            processRule(rangeRule)

            -- quality rules
            local statRules = WDMF.encounter.statRules
            if statRules["RL_QUALITY"] and
               statRules["RL_QUALITY"]["QT_INTERRUPTS"] and
               statRules["RL_QUALITY"]["QT_INTERRUPTS"][target_spell_id]
            then
                local actualQuality = unit.casts[target_spell_id][i].percent
                local expectedQuality = statRules["RL_QUALITY"]["QT_INTERRUPTS"][target_spell_id].qualityPercent
                if actualQuality < expectedQuality then
                    self:AddFail(timestamp, interrupter.guid, interrupter.rt, string.format(WD_TRACKER_QT_INTERRUPTS_DESC, expectedQuality, WdLib:getSpellLinkByIdWithTexture(target_spell_id)), 0)
                end
            end
        end

        WD:RefreshTrackedCreatures()
    end

    unit.casts.current_spell_id = 0
end

local function finishCast(self, unit, timestamp, spell_id, result)
    if unit.casts.current_spell_id == 0 then return end
    if unit.casts.current_spell_id == spell_id and result ~= "FAILED" then
        local diff = (timestamp - unit.casts.current_timestamp) * 1000
        if diff >= WD.MIN_CAST_TIME_TRACKED then
            local i = 1
            if unit.casts[spell_id] then
                i = unit.casts[spell_id].count + 1
            else
                unit.casts[spell_id] = {}
            end
            unit.casts[spell_id].count = i
            unit.casts[spell_id][i] = {}
            unit.casts[spell_id][i].status = result
            unit.casts[spell_id][i].timestamp = WdLib:getTimedDiff(self.encounter.startTime, timestamp)
            unit.casts[spell_id][i].timediff = WdLib:float_round_to(diff / 1000, 2)

            WD:RefreshTrackedCreatures()
        end
    end
    unit.casts.current_spell_id = 0
end

local function dispelAura(self, unit, unit_name, timestamp, source_spell_id, target_aura_id, dispeller)
    local parent = findParent(dispeller)
    if parent then
        dispeller = parent
    end

    if not unit.auras[target_aura_id] then
        local aura = {}
        aura.applied = self.encounter.startTime
        aura.removed = timestamp
        aura.caster = unit.guid
        aura.dispelledAt = WdLib:getTimedDiff(self.encounter.startTime, timestamp)
        aura.dispelledIn = WdLib:float_round_to(timestamp - aura.applied, 2)
        aura.dispell_id = source_spell_id
        aura.dispeller = dispeller.guid
        unit.auras[target_aura_id] = {}
        unit.auras[target_aura_id][1] = aura
    end

    if dispeller then
        local function processRule(rule)
            if rule and rule[target_aura_id] then
                local p = rule[target_aura_id].points
                local msg = WD.GetEventDescription("EV_DISPEL", target_aura_id)
                if rule.range then
                    msg = msg.." "..WD.GetRangeRuleDescription(rule.range[1], rule.range[2])
                end
                self:AddSuccess(timestamp, dispeller.guid, dispeller.rt, msg, p)
            end
        end
        -- regular rules
        local rule = findRuleByRole("EV_DISPEL", dispeller.role)
        processRule(rule)
        -- range rules
        local rangeRule = findRuleInRange("EV_DISPEL", unit)
        processRule(rangeRule)
    end

    for i=1, #unit.auras[target_aura_id] do
        local aura = unit.auras[target_aura_id][i]
        local diff = (timestamp - aura.applied) * 1000
        diff = WdLib:float_round_to(diff / 1000, 2)
        if not aura.duration then
            local t = (timestamp - aura.applied) / 1000
            aura.duration = WdLib:float_round_to(t * 1000, 2)
        end
        if diff <= aura.duration + 0.01 then
            aura.dispelledAt = WdLib:getTimedDiff(self.encounter.startTime, timestamp)
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
                        self:AddFail(timestamp, dispeller.guid, dispeller.rt, string.format(WD_TRACKER_QT_DISPELS_FULL_RANGE, earlyTime, lateTime, WdLib:getSpellLinkByIdWithTexture(target_aura_id)), 0)
                    elseif earlyTime > 0 and lateTime == 0 and dispelledIn < earlyTime then
                        self:AddFail(timestamp, dispeller.guid, dispeller.rt, string.format(WD_TRACKER_QT_DISPELS_LEFT_RANGE, earlyTime, WdLib:getSpellLinkByIdWithTexture(target_aura_id)), 0)
                    elseif earlyTime == 0 and lateTime > 0 and dispelledIn > lateTime then
                        self:AddFail(timestamp, dispeller.guid, dispeller.rt, string.format(WD_TRACKER_QT_DISPELS_RIGHT_RANGE, lateTime, WdLib:getSpellLinkByIdWithTexture(target_aura_id)), 0)
                    end
                end
            end
        end
    end

    WD:RefreshTrackedDispels()
end

local function applyAura(self, unit, timestamp, spell_id, action)
    if action ~= "apply" and action ~= "remove" then return end

    local function processRule(rule)
        if rule and rule[spell_id] and rule[spell_id][action] then
            local p = rule[spell_id][action].points
            local msg = WD.GetEventDescription("EV_AURA", spell_id, action)
            if rule.range then
                msg = msg.." "..WD.GetRangeRuleDescription(rule.range[1], rule.range[2])
            end
            self:AddFail(timestamp, unit.guid, unit.rt, msg, p)
        end
    end

    -- regular rules
    local rule = findRuleByRole("EV_AURA", unit.role)
    processRule(rule)
    -- range rules
    local rangeRule = findRuleInRange("EV_AURA", unit)
    processRule(rangeRule)
end

local function applyAuraStack(self, unit, timestamp, spell_id, stacks)
    local function processRule(rule)
        if rule and rule[spell_id] and rule[spell_id][stacks] then
            local p = rule[spell_id][stacks].points
            local msg = WD.GetEventDescription("EV_AURA_STACKS", spell_id, stacks)
            if rule.range then
                msg = msg.." "..WD.GetRangeRuleDescription(rule.range[1], rule.range[2])
            end
            self:AddFail(timestamp, unit.guid, unit.rt, msg, p)
        elseif rule and rule[spell_id] and rule[spell_id][0] then
            local p = rule[spell_id][0].points
            local msg = string.format(WD_RULE_AURA_STACKS_ANY, "("..stacks..")", WdLib:getSpellLinkByIdWithTexture(spell_id))
            if rule.range then
                msg = msg.." "..WD.GetRangeRuleDescription(rule.range[1], rule.range[2])
            end
            self:AddFail(timestamp, unit.guid, unit.rt, msg, p)
        end
    end

    -- regular rules
    local rule = findRuleByRole("EV_AURA_STACKS", unit.role)
    processRule(rule)
    -- range rules
    local rangeRule = findRuleInRange("EV_AURA_STACKS", unit)
    processRule(rangeRule)
end

function WDMF:ProcessSummons(src, dst, ...)
    if not src then return end
    local arg = {...}
    local timestamp, event, src_name, dst_guid, dst_name, spell_id = arg[1], arg[2], arg[5], arg[8], arg[9], tonumber(arg[12])
    if not dst_name then return end
    -----------------------------------------------------------------------------------------------------------------------
    if event == "SPELL_SUMMON" then
        loadPet(dst_guid, dst_name, src.guid, src.name)
    end
end

function WDMF:ProcessAuras(src, dst, ...)
    if not dst then return end
    local arg = {...}
    local timestamp, event, src_name, dst_name, spell_id = arg[1], arg[2], arg[5], arg[9], tonumber(arg[12])
    if not src and src_name then return end
    if not dst and dst_name then return end
    -----------------------------------------------------------------------------------------------------------------------
    if event == "SPELL_AURA_APPLIED" then
        -- auras
        if not dst.auras[spell_id] then dst.auras[spell_id] = {} end
        local auras = dst.auras[spell_id]
        if src then
            auras[#auras+1] = { caster = src.guid, applied = timestamp }
        else
            auras[#auras+1] = { caster = "Environment", applied = timestamp }
        end

        -- interrupts
        if WD.Spells.knockbackEffects[spell_id] and not hasAnyAura(dst, WD.Spells.rootEffects) then
            interruptCast(self, dst, dst_name, timestamp, spell_id, dst.casts.current_spell_id, src)
        end
        if WD.Spells.controlEffects[spell_id] then
            interruptCast(self, dst, dst_name, timestamp, spell_id, dst.casts.current_spell_id, src)
        end

        applyAura(self, dst, timestamp, spell_id, "apply")

        -- potions
        local potionRule = findRuleByRole("EV_POTIONS", dst.role)
        if potionRule then
            if WD.Spells.potions[spell_id] then
                local msg = WD.GetEventDescription("EV_POTIONS")
                self:AddSuccess(timestamp, dst.guid, dst.rt, msg, potionRule.points)
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
                aura.duration = WdLib:float_round_to(t * 1000, 2)
            end
        end

        applyAura(self, dst, timestamp, spell_id, "remove")
    end
    -----------------------------------------------------------------------------------------------------------------------
    if event == "SPELL_AURA_APPLIED_DOSE" then
        local stacks = tonumber(arg[16])
        applyAuraStack(self, dst, timestamp, spell_id, stacks)
    end
end

function WDMF:ProcessCasts(src, dst, ...)
    if not src then return end
    local rules = self.encounter.rules
    local arg = {...}
    local timestamp, event, src_name, dst_name, spell_id = arg[1], arg[2], arg[5], arg[9], tonumber(arg[12])
    if not src and src_name then return end
    if not dst and dst_name then return end

    if src.type ~= "player" then
        local parent = findParent(src)
        if parent then
            src_name = WdLib:getShortCharacterName(src.parentName)
            src = parent
        end
    end

    -----------------------------------------------------------------------------------------------------------------------
    if event == "SPELL_CAST_START" then
        startCast(src, timestamp, spell_id)

        local function processRule(rule)
            if rule and rule[spell_id] then
                local key = getNpcId(src.guid)
                if not rule[spell_id][key] then
                    key = WdLib:getShortCharacterName(src_name)
                end
                if rule[spell_id][key] then
                    local p = rule[spell_id][key].points
                    local msg = WD.GetEventDescription("EV_CAST_START", spell_id, WdLib:getShortCharacterName(src.name))
                    if rule.range then
                        msg = msg.." "..WD.GetRangeRuleDescription(rule.range[1], rule.range[2])
                    end
                    if src.type ~= "player" then
                        self:AddSuccess(timestamp, "creature"..getNpcId(src.guid), src.rt, msg, p)
                    else
                        self:AddSuccess(timestamp, src.guid, src.rt, msg, p)
                    end
                end
            end
        end
        -- regular rules
        local rule = findRuleByRole("EV_CAST_START", src.role)
        processRule(rule)
        -- range rules
        local rangeRule = findRuleInRange("EV_CAST_START", src)
        processRule(rangeRule)
    end
    -----------------------------------------------------------------------------------------------------------------------
    if event == "SPELL_CAST_SUCCESS" then
        finishCast(self, src, timestamp, spell_id, "SUCCESS")

        local function processRule(rule)
            if rule and rule[spell_id] then
                local key = getNpcId(src.guid)
                if not rule[spell_id][key] then
                    key = WdLib:getShortCharacterName(src_name)
                end
                if rule[spell_id][key] then
                    local p = rule[spell_id][key].points
                    local msg = WD.GetEventDescription("EV_CAST_END", spell_id, WdLib:getShortCharacterName(src.name))
                    if rule.range then
                        msg = msg.." "..WD.GetRangeRuleDescription(rule.range[1], rule.range[2])
                    end
                    if src.type ~= "player" then
                        self:AddSuccess(timestamp, "creature"..getNpcId(src.guid), src.rt, msg, p)
                    else
                        self:AddSuccess(timestamp, src.guid, src.rt, msg, p)
                    end
                end
            end
        end
        -- regular rules
        local rule = findRuleByRole("EV_CAST_END", src.role)
        processRule(rule)
        -- range rules
        local rangeRule = findRuleInRange("EV_CAST_END", src)
        processRule(rangeRule)
    end
    -----------------------------------------------------------------------------------------------------------------------
    if event == "SPELL_MISS" then
        finishCast(self, src, timestamp, spell_id, "MISSED")
    end
    -----------------------------------------------------------------------------------------------------------------------
    if event == "SPELL_CAST_FAILED" then
        finishCast(self, src, timestamp, spell_id, "FAILED")
    end
    -----------------------------------------------------------------------------------------------------------------------
    if event == "SPELL_INTERRUPT" then
        if dst then
            local target_spell_id = tonumber(arg[15])
            interruptCast(self, dst, dst_name, timestamp, spell_id, target_spell_id, src)
        end
    end
end

function WDMF:ProcessDamage(src, dst, ...)
    if not dst then return end
    local arg = {...}
    local timestamp, event, src_name, dst_name, spell_id = arg[1], arg[2], arg[5], arg[9], tonumber(arg[12])
    if not src and src_name then return end
    if not dst and dst_name then return end
    -----------------------------------------------------------------------------------------------------------------------
    if event == "SPELL_DAMAGE" then
        -- interrupts
        if WD.Spells.knockbackEffects[spell_id] and not hasAnyAura(dst, WD.Spells.rootEffects) then
            interruptCast(self, dst, dst_name, timestamp, spell_id, dst.casts.current_spell_id, src)
        end

        local function processRules(deathRule, damageTakenRule)
            if deathRule or damageTakenRule then
                local amount, overkill = tonumber(arg[15]), tonumber(arg[16])
                local total = amount + overkill
                if overkill == 0 then total = total + 1 end

                if overkill > -1 and deathRule and deathRule[spell_id] then
                    local p = deathRule[spell_id].points
                    local msg = WD.GetEventDescription("EV_DEATH", spell_id)
                    if deathRule.range then
                        msg = msg.." "..WD.GetRangeRuleDescription(deathRule.range[1], deathRule.range[2])
                    end
                    self:AddFail(timestamp, dst.guid, dst.rt, msg, p)
                else
                    if damageTakenRule and damageTakenRule[spell_id] then
                        local p = damageTakenRule[spell_id].points
                        if (damageTakenRule[spell_id].amount > 0 and total > damageTakenRule[spell_id].amount) or
                           (damageTakenRule[spell_id].amount == 0 and total > 0)
                        then
                            local msg = WD.GetEventDescription("EV_DAMAGETAKEN", spell_id, damageTakenRule[spell_id].amount)
                            if damageTakenRule.range then
                                msg = msg.." "..WD.GetRangeRuleDescription(damageTakenRule.range[1], damageTakenRule.range[2])
                            end
                            self:AddFail(timestamp, dst.guid, dst.rt, msg, p)
                        end
                    end
                end
            end
        end

        -- regular rules
        local deathRule = findRuleByRole("EV_DEATH", dst.role)
        local damageTakenRule = findRuleByRole("EV_DAMAGETAKEN", dst.role)
        processRules(deathRule, damageTakenRule)
        -- range rules
        local deathRangeRule = findRuleInRange("EV_DEATH", dst)
        local damageTakenRangeRule = findRuleInRange("EV_DAMAGETAKEN", dst)
        processRules(deathRangeRule, damageTakenRangeRule)
    end
end

function WDMF:ProcessHealing(src, dst, ...)
    local rules = self.encounter.rules
    local arg = {...}
    local timestamp, event, src_name, dst_name, spell_id = arg[1], arg[2], arg[5], arg[9], tonumber(arg[12])
    if not src and src_name then return end
    if not dst and dst_name then return end
end

function WDMF:ProcessDeaths(src, dst, ...)
    if not dst then return end
    local arg = {...}
    local timestamp, event, dst_name, spell_id = arg[1], arg[2], arg[9], tonumber(arg[12])
    if not dst and dst_name then return end
    -----------------------------------------------------------------------------------------------------------------------
    if event == "UNIT_DIED" then
        for guid in pairs(self.tracker.players) do
            if guid == dst.guid then
                self.encounter.deaths = self.encounter.deaths + 1
                break
            end
        end

        local function processRule(rule)
            if rule then
                local u = rule.unit
                if (tonumber(u) and u == getNpcId(dst.guid)) or (u == WdLib:getShortCharacterName(dst_name)) then
                    local p = rule.points
                    local dst_nameWithMark = dst.name
                    if dst.rt > 0 then dst_nameWithMark = WdLib:getRaidTargetTextureLink(dst.rt).." "..dst.name end
                    local msg = WD.GetEventDescription("EV_DEATH_UNIT", dst_nameWithMark)
                    if rule.range then
                        msg = msg.." "..WD.GetRangeRuleDescription(rule.range[1], rule.range[2])
                    end
                    if dst.type ~= "player" then
                        self:AddSuccess(timestamp, "creature"..getNpcId(dst.guid), dst.rt, msg, p)
                    else
                        self:AddSuccess(timestamp, dst.guid, dst.rt, msg, p)
                    end
                end
            end
        end

        -- regular rules
        local rule = findRuleByRole("EV_DEATH_UNIT", dst.role)
        processRule(rule)
        -- range rules
        local rangeRule = findRuleInRange("EV_DEATH_UNIT", dst)
        processRule(rangeRule)
    end
end

function WDMF:ProcessDispels(src, dst, ...)
    if not src then return end
    local rules = self.encounter.rules
    local arg = {...}
    local timestamp, event, src_name, dst_name, spell_id = arg[1], arg[2], arg[5], arg[9], tonumber(arg[12])
    if not src and src_name then return end
    if not dst and dst_name then return end
    -----------------------------------------------------------------------------------------------------------------------
    if event == "SPELL_DISPEL" or event == "SPELL_STOLEN" then
        local target_aura_id = tonumber(arg[15])
        dispelAura(self, dst, dst_name, timestamp, spell_id, target_aura_id, src)
    end
end

function WDMF:LoadRules()
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
        elseif rType == "EV_POTIONS" or rType == "EV_FLASKS" or rType == "EV_FOOD" or rType == "EV_RUNES" then
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
        for i=1,#WD.db.profile.statRules do
            local r = WD.db.profile.statRules[i]
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
                        print(rangeType.." tracking not yet implemented")
                    end
                end
            end
        end

        return rules
    end

    -- search journalId for encounter
    local journalId = WD.FindEncounterJournalIdByCombatId(self.encounter.id)
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
        self:AddFail(time(), guid, 0, WD.GetEventDescription("EV_FLASKS"), rules[role]["EV_FLASKS"].points)
    end
    if rules[role] and rules[role]["EV_FOOD"] and not hasAnyAura(player, WD.Spells.food) then
        self:AddFail(time(), guid, 0, WD.GetEventDescription("EV_FOOD"), rules[role]["EV_FOOD"].points)
    end
    if rules[role] and rules[role]["EV_RUNES"] and not hasAnyAura(player, WD.Spells.runes) then
        self:AddFail(time(), guid, 0, WD.GetEventDescription("EV_RUNES"), rules[role]["EV_RUNES"].points)
    end
    if rules[role] and rules[role]["EV_POTIONS"] and hasAnyAura(player, WD.Spells.potions) then
        self:AddSuccess(time(), guid, 0, WD.GetEventDescription("EV_POTIONS"), rules[role]["EV_POTIONS"].points)
    end
end

function WDMF:Init()
    WdLib:table_wipe(callbacks)
    registerCallback(self.ProcessSummons,   "SPELL_SUMMON")
    registerCallback(self.ProcessAuras,     "SPELL_AURA_APPLIED", "SPELL_AURA_REMOVED", "SPELL_AURA_APPLIED_DOSE")
    registerCallback(self.ProcessCasts,     "SPELL_CAST_START", "SPELL_CAST_SUCCESS", "SPELL_MISS", "SPELL_CAST_FAILED", "SPELL_INTERRUPT")
    registerCallback(self.ProcessDamage,    "SPELL_DAMAGE")
    --registerCallback(self.ProcessHealing, "SPELL_HEAL")
    registerCallback(self.ProcessDeaths,    "UNIT_DIED")
    registerCallback(self.ProcessDispels,   "SPELL_DISPEL", "SPELL_STOLEN")
end

function WDMF:CreateRaidMember(unit, petUnit)
    local function createInternalEntity(unit)
        if not UnitIsVisible(unit) then return nil end
        local name = WdLib:getUnitName(unit)
        if name == UNKNOWNOBJECT then return nil end
        local _,class = UnitClass(unit)

        local p = {}
        p.name = name
        p.unit = unit
        p.class = class
        p.guid = UnitGUID(p.unit)
        p.rt = 0
        return p
    end

    local player = createInternalEntity(unit)
    local pet = createInternalEntity(petUnit)

    if player then
        if WD.cache.raidroster[player.name] then
            player.specId = WD.cache.raidroster[player.guid].specId
        elseif player.unit ~= "player" then
            NotifyInspect(player.unit)
        end

        player.type = "player"
        loadExistingPlayer(player)

        -- load auras
        for index=1,40 do
            local _, _, _, _, duration, expirationTime, _, _, _, spellId = UnitBuff(player.unit, index)
            if spellId then
                if not player.auras[spellId] then player.auras[spellId] = {} end
                local appliedAt = expirationTime - duration
                player.auras[spellId][#player.auras[spellId]+1] = { caster = player.guid, applied = appliedAt }
            end
        end

        self:CheckConsumables(player)
    end

    if pet then
        pet.type = "pet"
        pet.name = WdLib:getShortCharacterName(pet.name)
        pet.parentGuid = player.guid
        pet.parentName = player.name
        loadExistingPet(pet)

        if not player.pets then player.pets = {} end
        player.pets[#player.pets+1] = pet.guid
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
end

function WDMF:Tracker_OnStartEncounter()
    self.tracker = {}
    self.tracker.pullName = self.encounter.pullName
    self.tracker.npc = {}
    self.tracker.pets = {}
    self.tracker.players = {}
    if WD.db.profile.tracker.npc then WD.db.profile.tracker.npc = nil end
    if WD.db.profile.tracker.pets then WD.db.profile.tracker.pets = nil end
    if WD.db.profile.tracker.players then WD.db.profile.tracker.players = nil end

    if #WD.db.profile.tracker == WD.MaxPullsToBeSaved then
        table.remove(WD.db.profile.tracker, 1)
    end
    WD.db.profile.tracker[#WD.db.profile.tracker+1] = self.tracker
    WD.db.profile.tracker.selected = #WD.db.profile.tracker

    self:LoadRules()
    self:ProcessPull()

    WD:RefreshTrackerPulls()
    WD:RefreshTrackedCreatures()
end

function WDMF:Tracker_OnStopEncounter()
    if not WD.db.profile.tracker then return end
    local n = WD.db.profile.tracker[#WD.db.profile.tracker].pullName
    WD.db.profile.tracker[#WD.db.profile.tracker].pullName = n.." ("..WdLib:getTimedDiffShort(self.encounter.startTime, self.encounter.endTime)..")"

    WD:RefreshTrackerPulls()
    WD:RefreshTrackedCreatures()
end

function WDMF:Tracker_OnEvent(...)
    local _, event, _, src_guid, src_name, src_flags, src_raid_flags, dst_guid, dst_name, dst_flags, dst_raid_flags = ...
    local src, dst = getEntities(src_guid, src_name, src_flags, src_raid_flags, dst_guid, dst_name, dst_flags, dst_raid_flags)
    if callbacks[event] then
        callbacks[event](self, src, dst, ...)
    end
end

function WD:IsNpc(flags)
    local f = bit.band(flags, COMBATLOG_OBJECT_TYPE_MASK)
    if f == COMBATLOG_OBJECT_TYPE_NPC then return true end
    return nil
end

function WD:IsPet(flags)
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

function WD:FindEntityByGUID(guid)
    local result = findPlayer(guid)
    if result then return result end
    result = findPet(guid)
    if result then return result end
    result = findNpc(guid)
    if result then return result end
    return nil
end
