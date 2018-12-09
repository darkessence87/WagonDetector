
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
    if not guid or not guid:match("Creature") then return nil end
    local npcId = getNpcId(guid)
    local holder = WDMF.tracker.npc[npcId]
    local index = findEntityIndex(holder, guid)
    if index then return holder[index] end
    return nil
end

local function findPet(guid)
    if not guid or not guid:match("Pet") then return nil end
    for k,v in pairs(WDMF.tracker.pet) do
        local index = findEntityIndex(v, guid)
        if index then return v[index] end
    end
    return nil
end

local function findPlayer(guid)
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
        pet.name = pet.name.."-"..(#holder + 1)
        holder[#holder+1] = pet
        return
    end
    if parentGuid then holder[index].parentGuid = pet.parentGuid end
    if parentName then holder[index].parentName = pet.parentName end
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
    if name == UNKNOWNOBJECT then
        --[[print('trying to find guid by name next time')
        if WDMF.tracker[UNKNOWNOBJECT] and WDMF.tracker[UNKNOWNOBJECT][guid] then
            WDMF.tracker[key] = WDMF.tracker[UNKNOWNOBJECT]
            WDMF.tracker[key][guid].name = name
            WDMF.tracker[UNKNOWNOBJECT] = nil
            return WDMF.tracker[key][guid]
        end
        ]]
        return nil
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

local function getEntities(src_guid, src_name, src_flags, src_raid_flags, dst_guid, dst_name, dst_flags, dst_raid_flags)
    local src = nil
    if WD:IsNpc(src_flags) then
        src = loadEntity(src_guid, src_name, "creature")
    elseif WD:IsPet(src_flags) then
        src = loadEntity(src_guid, src_name, "pet")
    elseif src_name then
        src_name = WdLib:getFullCharacterName(src_name)
        src = loadEntity(src_guid, src_name, "player")
    end
    local dst = nil
    if WD:IsNpc(dst_flags) then
        dst = loadEntity(dst_guid, dst_name, "creature")
    elseif WD:IsPet(dst_flags) then
        dst = loadEntity(dst_guid, dst_name, "pet")
    elseif dst_name then
        dst_name = WdLib:getFullCharacterName(dst_name)
        dst = loadEntity(dst_guid, dst_name, "player")
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
            local rules = WDMF.encounter.rules
            if rules[interrupter.role] and
               rules[interrupter.role]["EV_CAST_INTERRUPTED"] and
               rules[interrupter.role]["EV_CAST_INTERRUPTED"][target_spell_id]
            then
                local key = getNpcId(unit.guid)
                if not rules[interrupter.role]["EV_CAST_INTERRUPTED"][target_spell_id][key] then
                    key = WdLib:getShortCharacterName(unit_name, "ignoreRealm")
                end
                if rules[interrupter.role]["EV_CAST_INTERRUPTED"][target_spell_id][key] then
                    local p = rules[interrupter.role]["EV_CAST_INTERRUPTED"][target_spell_id][key].points
                    local dst_nameWithMark = unit.name
                    if unit.rt > 0 then dst_nameWithMark = WdLib:getRaidTargetTextureLink(unit.rt).." "..unit.name end
                    WDMF:AddSuccess(timestamp, interrupter.guid, interrupter.rt, string.format(WD_RULE_CAST_INTERRUPT, dst_nameWithMark, WdLib:getSpellLinkByIdWithTexture(target_spell_id)), p)
                end
            end

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
        local rules = WDMF.encounter.rules
        if rules[dispeller.role] and
           rules[dispeller.role]["EV_DISPEL"] and
           rules[dispeller.role]["EV_DISPEL"][target_aura_id]
        then
            local p = rules[dispeller.role]["EV_DISPEL"][target_aura_id].points
            self:AddSuccess(timestamp, dispeller.guid, dispeller.rt, string.format(WD_RULE_DISPEL, WdLib:getSpellLinkByIdWithTexture(target_aura_id)), p)
        end
    end

    for i=1, #unit.auras[target_aura_id] do
        local aura = unit.auras[target_aura_id][i]
        local diff = (timestamp - aura.applied) * 1000
        aura.dispelledAt = WdLib:getTimedDiff(self.encounter.startTime, timestamp)
        aura.dispelledIn = WdLib:float_round_to(diff / 1000, 2)
        aura.dispell_id = source_spell_id
        aura.dispeller = dispeller.guid

        if dispeller then
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

    WD:RefreshTrackedDispels()
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
    local rules = self.encounter.rules
    local arg = {...}
    local timestamp, event, src_name, dst_name, spell_id = arg[1], arg[2], arg[5], arg[9], tonumber(arg[12])
    if not src and src_name then return end
    if not dst and dst_name then return end
    -----------------------------------------------------------------------------------------------------------------------
    if event == "SPELL_AURA_APPLIED" then
        if dst then
            -- auras
            dst.auras[spell_id] = {}
            if src then
                dst.auras[spell_id][#dst.auras[spell_id]+1] = { caster = src.guid, applied = timestamp }
            else
                dst.auras[spell_id][#dst.auras[spell_id]+1] = { caster = "Environment", applied = timestamp }
            end

            -- interrupts
            if WD.Spells.knockbackEffects[spell_id] and not hasAnyAura(dst, WD.Spells.rootEffects) then
                interruptCast(self, dst, dst_name, timestamp, spell_id, dst.casts.current_spell_id, src)
            end
            if WD.Spells.controlEffects[spell_id] then
                interruptCast(self, dst, dst_name, timestamp, spell_id, dst.casts.current_spell_id, src)
            end

            if rules[dst.role] and
               rules[dst.role]["EV_AURA"] and
               rules[dst.role]["EV_AURA"][spell_id] and
               rules[dst.role]["EV_AURA"][spell_id]["apply"]
            then
                local p = rules[dst.role]["EV_AURA"][spell_id]["apply"].points
                self:AddFail(timestamp, dst.guid, dst.rt, string.format(WD_RULE_APPLY_AURA, WdLib:getSpellLinkByIdWithTexture(spell_id)), p)
            end
        end
    end
    -----------------------------------------------------------------------------------------------------------------------
    if event == "SPELL_AURA_REMOVED" then
        if dst then
            if dst.auras[spell_id] then
                local aura = findActiveAuraByCaster(dst, spell_id, src)
                if aura then
                    aura.removed = timestamp
                    aura.duration = WdLib:float_round_to((aura.removed - aura.applied) / 1000, 2)
                end
            end

            if rules[dst.role] and
               rules[dst.role]["EV_AURA"] and
               rules[dst.role]["EV_AURA"][spell_id] and
               rules[dst.role]["EV_AURA"][spell_id]["remove"]
            then
                local p = rules[dst.role]["EV_AURA"][spell_id]["remove"].points
                self:AddFail(timestamp, dst.guid, dst.rt, string.format(WD_RULE_REMOVE_AURA, WdLib:getSpellLinkByIdWithTexture(spell_id)), p)
            end

            -- potions
            if rules[dst.role] and
               rules[dst.role]["EV_POTIONS"]
            then
                if WD.Spells.potions[spell_id] then
                    local p = rules[dst.role]["EV_POTIONS"].points
                    self:AddSuccess(timestamp, dst.guid, dst.rt, WD_RULE_POTIONS, p)
                end
            end
        end
    end
    -----------------------------------------------------------------------------------------------------------------------
    if event == "SPELL_AURA_APPLIED_DOSE" then
        if dst and
           rules[dst.role] and
           rules[dst.role]["EV_AURA_STACKS"] and
           rules[dst.role]["EV_AURA_STACKS"][spell_id]
        then
            local stacks = tonumber(arg[16])
            if rules[dst.role]["EV_AURA_STACKS"][spell_id][stacks] then
                local p = rules[dst.role]["EV_AURA_STACKS"][spell_id][stacks].points
                self:AddFail(timestamp, dst.guid, dst.rt, string.format(WD_RULE_AURA_STACKS, stacks, WdLib:getSpellLinkByIdWithTexture(spell_id)), p)
            elseif rules[dst.role]["EV_AURA_STACKS"][spell_id][0] then
                local p = rules[dst.role]["EV_AURA_STACKS"][spell_id][0].points
                self:AddFail(timestamp, dst.guid, dst.rt, string.format(WD_RULE_AURA_STACKS_ANY, "("..stacks..")", WdLib:getSpellLinkByIdWithTexture(spell_id)), p)
            end
        end
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
        --print(event..' : '..WdLib:getSpellLinkByIdWithTexture(spell_id)..' caster:'..src.name)
        startCast(src, timestamp, spell_id)

        if rules[src.role] and
           rules[src.role]["EV_CAST_START"] and
           rules[src.role]["EV_CAST_START"][spell_id]
        then
            local key = getNpcId(src.guid)
            if not rules[src.role]["EV_CAST_START"][spell_id][key] then
                key = WdLib:getShortCharacterName(src_name)
            end
            if rules[src.role]["EV_CAST_START"][spell_id][key] then
                local p = rules[src.role]["EV_CAST_START"][spell_id][key].points
                if src.type ~= "player" then
                    self:AddSuccess(timestamp, "creature"..getNpcId(src.guid), src.rt, string.format(WD_RULE_CAST_START, WdLib:getShortCharacterName(src.name), WdLib:getSpellLinkByIdWithTexture(spell_id)), p)
                else
                    self:AddSuccess(timestamp, src.guid, src.rt, string.format(WD_RULE_CAST_START, WdLib:getShortCharacterName(src.name), WdLib:getSpellLinkByIdWithTexture(spell_id)), p)
                end
            end
        end
    end
    -----------------------------------------------------------------------------------------------------------------------
    if event == "SPELL_CAST_SUCCESS" then
        --print(event..' : '..WdLib:getSpellLinkByIdWithTexture(spell_id)..' caster:'..src.name)
        finishCast(self, src, timestamp, spell_id, "SUCCESS")

        if rules[src.role] and
           rules[src.role]["EV_CAST_END"] and
           rules[src.role]["EV_CAST_END"][spell_id]
        then
            local key = getNpcId(src.guid)
            if not rules[src.role]["EV_CAST_END"][spell_id][key] then
                key = WdLib:getShortCharacterName(src_name)
            end
            if rules[src.role]["EV_CAST_END"][spell_id][key] then
                local p = rules[src.role]["EV_CAST_END"][spell_id][key].points
                if src.type ~= "player" then
                    self:AddSuccess(timestamp, "creature"..getNpcId(src.guid), src.rt, string.format(WD_RULE_CAST, WdLib:getShortCharacterName(src.name), WdLib:getSpellLinkByIdWithTexture(spell_id)), p)
                else
                    self:AddSuccess(timestamp, src.guid, src.rt, string.format(WD_RULE_CAST, WdLib:getShortCharacterName(src.name), WdLib:getSpellLinkByIdWithTexture(spell_id)), p)
                end
            end
        end
    end
    -----------------------------------------------------------------------------------------------------------------------
    if event == "SPELL_MISS" then
        --print(event..' : '..WdLib:getSpellLinkByIdWithTexture(spell_id)..' caster:'..src.name)
        finishCast(self, src, timestamp, spell_id, "MISSED")
    end
    -----------------------------------------------------------------------------------------------------------------------
    if event == "SPELL_CAST_FAILED" then
        --print(event..' : '..WdLib:getSpellLinkByIdWithTexture(spell_id)..' caster:'..src.name)
        finishCast(self, src, timestamp, spell_id, "FAILED")
    end
    -----------------------------------------------------------------------------------------------------------------------
    if event == "SPELL_INTERRUPT" then
        local target_spell_id = tonumber(arg[15])
        --print(event..' : interrupted '..WdLib:getSpellLinkByIdWithTexture(target_spell_id)..' target:'..dst.name..' by '..WdLib:getSpellLinkByIdWithTexture(spell_id)..' caster:'..src.name)

        if dst then
            interruptCast(self, dst, dst_name, timestamp, spell_id, target_spell_id, src)
        end
    end
end

function WDMF:ProcessDamage(src, dst, ...)
    if not dst then return end
    local rules = self.encounter.rules
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

        if rules[dst.role] then
            local amount, overkill = tonumber(arg[15]), tonumber(arg[16])
            local total = amount + overkill
            if overkill == 0 then total = total + 1 end

            if overkill > -1 and rules[dst.role]["EV_DEATH"] and rules[dst.role]["EV_DEATH"][spell_id] then
                local p = rules[dst.role]["EV_DEATH"][spell_id].points
                self:AddFail(timestamp, dst.guid, dst.rt, string.format(WD_RULE_DEATH, WdLib:getSpellLinkByIdWithTexture(spell_id)), p)
            else
                if rules[dst.role]["EV_DAMAGETAKEN"] and rules[dst.role]["EV_DAMAGETAKEN"][spell_id] then
                    local damagetaken_rule = rules[dst.role]["EV_DAMAGETAKEN"][spell_id]
                    local p = damagetaken_rule.points
                    if damagetaken_rule.amount > 0 and total > damagetaken_rule.amount then
                        self:AddFail(timestamp, dst.guid, dst.rt, string.format(WD_RULE_DAMAGE_TAKEN_AMOUNT, damagetaken_rule.amount, WdLib:getSpellLinkByIdWithTexture(spell_id)), p)
                    elseif damagetaken_rule.amount == 0 and total > 0 then
                        self:AddFail(timestamp, dst.guid, dst.rt, string.format(WD_RULE_DAMAGE_TAKEN, WdLib:getSpellLinkByIdWithTexture(spell_id)), p)
                    end
                end
            end
        end
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
    local rules = self.encounter.rules
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

        if rules[dst.role] and
           rules[dst.role]["EV_DEATH_UNIT"]
        then
            local u = rules[dst.role]["EV_DEATH_UNIT"].unit
            if (tonumber(u) and u == getNpcId(dst.guid)) or (u == WdLib:getShortCharacterName(dst_name)) then
                local p = rules[dst.role]["EV_DEATH_UNIT"].points
                local dst_nameWithMark = dst.name
                if dst.rt > 0 then dst_nameWithMark = WdLib:getRaidTargetTextureLink(dst.rt).." "..dst.name end
                if dst.type ~= "player" then
                    self:AddSuccess(timestamp, "creature"..getNpcId(dst.guid), dst.rt, string.format(WD_RULE_DEATH_UNIT, dst_nameWithMark), p)
                else
                    self:AddSuccess(timestamp, dst.guid, dst.rt, string.format(WD_RULE_DEATH_UNIT, dst_nameWithMark), p)
                end
            end
        end
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

function WDMF:LoadStatRules()
    local function getActiveRules(encounterId)
        -- search journalId for encounter
        local journalId = WD.FindEncounterJournalIdByCombatId(encounterId)
        if not journalId then
            journalId = WD.FindEncounterJournalIdByName("ALL")
            print("Unknown name for encounterId:"..encounterId)
        end

        local rules = {}
        for i=1,#WD.db.profile.statRules do
            local r = WD.db.profile.statRules[i]
            if r.isActive == true and (r.journalId == journalId or r[i].journalId == -1) then
                if not rules[r.ruleType] then rules[r.ruleType] = {} end
                if not rules[r.ruleType][r.arg0] then rules[r.ruleType][r.arg0] = {} end
                if not rules[r.ruleType][r.arg0][r.arg1] then rules[r.ruleType][r.arg0][r.arg1] = {} end
                if r.ruleType == "RL_QUALITY" then
                    if r.arg0 == "QT_INTERRUPTS" then
                        rules["RL_QUALITY"]["QT_INTERRUPTS"][r.arg1].qualityPercent = r.qualityPercent
                    elseif r.arg0 == "QT_DISPELS" then
                        rules["RL_QUALITY"]["QT_DISPELS"][r.arg1].earlyDispel = r.earlyDispel
                        rules["RL_QUALITY"]["QT_DISPELS"][r.arg1].lateDispel = r.lateDispel
                    end
                end
            end
        end

        return rules
    end

    self.encounter.statRules = getActiveRules(self.encounter.id)
end

function WDMF:CheckConsumables(guid, unit)
    local rules = self.encounter.rules
    local role = WD:GetRole(guid)
    local noflask, nofood, norune = nil, nil, nil
    if rules[role] and rules[role]["EV_FLASKS"] then
        noflask = true
    end
    if rules[role] and rules[role]["EV_FOOD"] then
        nofood = true
    end
    if rules[role] and rules[role]["EV_RUNES"] then
        norune = true
    end

    for index=1,40 do
        local _, _, _, _, _, _, _, _, _, spellId = UnitBuff(unit, index)

        -- flasks
        if spellId and WD.Spells.flasks[spellId] then
            noflask = false
        end

        -- food
        if spellId and WD.Spells.food[spellId] then
            nofood = false
        end

        -- runes
        if spellId and WD.Spells.runes[spellId] then
            norune = false
        end
    end

    if noflask and noflask == true then
        self:AddFail(time(), guid, 0, WD_RULE_FLASKS, rules[role]["EV_FLASKS"].points)
    end
    if nofood and nofood == true then
        self:AddFail(time(), guid, 0, WD_RULE_FOOD, rules[role]["EV_FOOD"].points)
    end
    if norune and norune == true then
        self:AddFail(time(), guid, 0, WD_RULE_RUNES, rules[role]["EV_RUNES"].points)
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

        self:CheckConsumables(player.guid, player.unit)
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

    self:ProcessPull()

    WD:RefreshTrackerPulls()
    WD:RefreshTrackedCreatures()
end

function WDMF:Tracker_OnStopEncounter()
    local n = WD.db.profile.tracker[#WD.db.profile.tracker].pullName
    WD.db.profile.tracker[#WD.db.profile.tracker].pullName = n.." ("..WdLib:getTimedDiffShort(self.encounter.startTime, self.encounter.endTime)..")"

    WD:RefreshTrackerPulls()
    WD:RefreshTrackedCreatures()
end

function WDMF:Tracker_OnEvent(...)
    local _, event, _, src_guid, src_name, src_flags, src_raid_flags, dst_guid, dst_name, dst_flags, dst_raid_flags = ...
    local src, dst = getEntities(src_guid, src_name, src_flags, src_raid_flags, dst_guid, dst_name, dst_flags, dst_raid_flags)
    self:LoadStatRules()
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
