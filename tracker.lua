
local WDMF = WD.mainFrame
WD.cache.tracker = {}

local potionSpellIds = {
    [279151] = "/battle-potion-of-intellect",
    [279152] = "/battle-potion-of-agility",
    [279153] = "/battle-potion-of-strength",
    [229206] = "/potion-of-prolonged-power",
    [251316] = "/potion-of-bursting-blood",
    [269853] = "/potion-of-rising-death",
    [279154] = "/battle-potion-of-stamina",
}

local function createNpc(guid, name)
    if not name or not guid or guid == "" then return nil end
    local p = WD.cache.tracker[name]
    if not p then
        local v = {}
        v.name = name
        v.unit = ""
        v.class = 0
        v.guid = guid
        v.type = "creature"
        v.auras = {}
        v.casts = {}
        WD.cache.tracker[v.name] = {}
        local t = WD.cache.tracker[v.name]
        t[guid] = v
        t.count = 1
        return v
    elseif not p[guid] then
        if p.count == 1 then
            for _,v in pairs(p) do
                if type(v) == "table" then
                    v.name = name.."-"..p.count
                end
            end
        end
        p.count = p.count + 1
        local v = {}
        v.name = name.."-"..p.count
        v.unit = ""
        v.class = 0
        v.guid = guid
        v.type = "creature"
        v.auras = {}
        v.casts = {}
        p[guid] = v
        return v
    end

    return p[guid]
end

local function getEntities(src_guid, src_name, src_flags, src_raid_flags, dst_guid, dst_name, dst_flags, dst_raid_flags)
    local src = nil
    if WD:IsNpc(src_flags) then
        src = createNpc(src_guid, src_name)
    elseif src_name then
        src_name = getFullCharacterName(src_name)
        if WD.cache.tracker[src_name] then
            src = WD.cache.tracker[src_name][src_guid]
        end
    end
    local dst = nil
    if WD:IsNpc(dst_flags) then
        dst = createNpc(dst_guid, dst_name)
    elseif dst_name then
        dst_name = getFullCharacterName(dst_name)
        if WD.cache.tracker[dst_name] then
            dst = WD.cache.tracker[dst_name][dst_guid]
        end
    end

    local src_role, dst_role = "", ""
    local src_rt, dst_rt = 0, 0
    if src and not src.role then src.role = WD:GetRole(src_name) end
    if dst and not dst.role then dst.role = WD:GetRole(dst_name) end

    if src then src.rt = WD:GetRaidTarget(src_raid_flags) end
    if dst then dst.rt = WD:GetRaidTarget(dst_raid_flags) end

    return src, dst
end

local function hasAura(unit, auraId)
    if unit.auras[auraId] then return true end
    return nil
end

local function hasNotAura(unit, auraId)
    if not unit.auras[auraId] then return true end
    return nil
end

local function isCasting(unit, spellId)
    if unit.casts[spellId] and unit.casts[spellId].state == "STARTED" then return true end
    return nil
end

function WDMF:ProcessCasts(src, dst, ...)
    local rules = self.encounter.rules
    local arg = {...}
    local timestamp, event, src_name, dst_name, spell_id = arg[1], arg[2], arg[5], arg[9], tonumber(arg[12])
    if event ~= "SPELL_CAST_START" and event ~= "SPELL_CAST_SUCCESS" and event ~= "SPELL_MISS" and event ~= "SPELL_CAST_FAILED" then return end
    -----------------------------------------------------------------------------------------------------------------------
    if event == "SPELL_CAST_START" then
        print(event..' : '..getSpellLinkByIdWithTexture(spell_id)..' caster:'..src.name)
        if src then
            local i = 1
            if src.casts[spell_id] then
                i = src.casts[spell_id].count + 1
            else
                src.casts[spell_id] = {}
            end
            src.casts[spell_id].count = i
            src.casts[spell_id][i] = {}
            src.casts[spell_id][i].status = "STARTED"

            if rules[src.role] and
               rules[src.role]["EV_CAST_START"] and
               rules[src.role]["EV_CAST_START"][spell_id] and
               rules[src.role]["EV_CAST_START"][spell_id][src_name]
            then
                local p = rules[src.role]["EV_CAST_START"][spell_id][src_name].points
                self:AddSuccess(timestamp, src.name, src.rt, string.format(WD_RULE_CAST_START, src.name, getSpellLinkByIdWithTexture(spell_id)), p)
            end
        end
    end
    -----------------------------------------------------------------------------------------------------------------------
    if event == "SPELL_CAST_SUCCESS" then
        print(event..' : '..getSpellLinkByIdWithTexture(spell_id)..' caster:'..src.name)
        if src then
            if src.casts[spell_id] then
                local i = src.casts[spell_id].count
                src.casts[spell_id][i].status = "SUCCESS"
            end

            if rules[src.role] and
               rules[src.role]["EV_CAST_END"] and
               rules[src.role]["EV_CAST_END"][spell_id] and
               rules[src.role]["EV_CAST_END"][spell_id][src_name]
            then
                local p = rules[src.role]["EV_CAST_END"][spell_id][src_name].points
                self:AddSuccess(timestamp, src.name, src.rt, string.format(WD_RULE_CAST, src.name, getSpellLinkByIdWithTexture(spell_id)), p)
            end
        end
    end
    -----------------------------------------------------------------------------------------------------------------------
    if event == "SPELL_MISS" then
        print(event..' : '..getSpellLinkByIdWithTexture(spell_id)..' caster:'..src.name)
        if src then
            if src.casts[spell_id] then
                local i = src.casts[spell_id].count
                if src.casts[spell_id][i].status == "STARTED" then
                    src.casts[spell_id][i].status = "MISSED"
                end
            else
                print('unknown cast missed:'..spell_id.." caster: "..src.name.." "..src.guid)
            end
        end
    end
    -----------------------------------------------------------------------------------------------------------------------
    if event == "SPELL_CAST_FAILED" then
        print(event..' : '..getSpellLinkByIdWithTexture(spell_id)..' caster:'..src.name)
        if src then
            if src.casts[spell_id] then
                local i = src.casts[spell_id].count
                if src.casts[spell_id][i].status == "STARTED" then
                    src.casts[spell_id][i].status = "FAILED"
                end
            end
        end
    end
    -----------------------------------------------------------------------------------------------------------------------
    if event == "SPELL_INTERRUPT" then
        local target_spell_id = tonumber(arg[15])
        print(event..' : interrupted '..getSpellLinkByIdWithTexture(target_spell_id)..' target:'..dst.name..' by '..getSpellLinkByIdWithTexture(spell_id)..' caster:'..src.name)
        if src then
            if rules[src.role] and
               rules[src.role]["EV_CAST_INTERRUPTED"] and
               rules[src.role]["EV_CAST_INTERRUPTED"][target_spell_id] and
               rules[src.role]["EV_CAST_INTERRUPTED"][target_spell_id][dst_name]
            then
                local p = rules[src.role]["EV_CAST_INTERRUPTED"][target_spell_id][dst_name].points
                local dst_nameWithMark = dst.name
                if dst.rt > 0 then dst_nameWithMark = getRaidTargetTextureLink(dst.rt).." "..dst.name end
                self:AddSuccess(timestamp, src.name, src.rt, string.format(WD_RULE_CAST_INTERRUPT, dst_nameWithMark, getSpellLinkByIdWithTexture(target_spell_id)), p)
            end
        end

        if dst then
            if dst.casts[target_spell_id] then
                local i = dst.casts[target_spell_id].count
                if dst.casts[target_spell_id][i].status == "STARTED" then
                    dst.casts[target_spell_id][i].status = "INTERRUPTED"
                    dst.casts[target_spell_id][i].interrupter = src.name
                end
            else
                print('unknown cast interrupted:'..target_spell_id.." caster: "..dst.name.." "..dst.guid)
            end
        end
    end
end

function WDMF:Tracker_OnStartEncounter(raiders)
    table.wipe(WD.cache.tracker)

    for k,v in pairs(raiders) do
        v.type = "player"
        v.auras = {}
        v.casts = {}
        WD.cache.tracker[v.name] = {}
        local t = WD.cache.tracker[v.name]
        t[v.guid] = v
    end
end

function WDMF:Tracker_OnStopEncounter()
end

function WDMF:Tracker_OnEvent(...)
    local rules = self.encounter.rules
    local arg = {...}
    local timestamp, event, _, src_guid, src_name, src_flags, src_raid_flags, dst_guid, dst_name, dst_flags, dst_raid_flags, spell_id = ...

    local src, dst = getEntities(src_guid, src_name, src_flags, src_raid_flags, dst_guid, dst_name, dst_flags, dst_raid_flags)
    if not src and src_name then return end
    if not dst and dst_name then return end


    self:ProcessCasts(src, dst, ...)

    -----------------------------------------------------------------------------------------------------------------------
    if event == "SPELL_AURA_APPLIED" then
        if src then
            src.auras[spell_id] = true
        end

        if dst then
            dst.auras[spell_id] = true

            if rules[dst.role] and
               rules[dst.role]["EV_AURA"] and
               rules[dst.role]["EV_AURA"][spell_id] and
               rules[dst.role]["EV_AURA"][spell_id]["apply"]
            then
                local p = rules[dst.role]["EV_AURA"][spell_id]["apply"].points
                self:AddFail(timestamp, dst.name, dst.rt, string.format(WD_RULE_APPLY_AURA, getSpellLinkByIdWithTexture(spell_id)), p)
            end
        end
    end
    -----------------------------------------------------------------------------------------------------------------------
    if event == "SPELL_AURA_REMOVED" then
        if src then
            src.auras[spell_id] = nil
        end

        if dst then
            dst.auras[spell_id] = nil

            if rules[dst.role] and
               rules[dst.role]["EV_AURA"] and
               rules[dst.role]["EV_AURA"][spell_id] and
               rules[dst.role]["EV_AURA"][spell_id]["remove"]
            then
                local p = rules[dst.role]["EV_AURA"][spell_id]["remove"].points
                self:AddFail(timestamp, dst.name, dst.rt, string.format(WD_RULE_REMOVE_AURA, getSpellLinkByIdWithTexture(spell_id)), p)
            end

            -- potions
            if rules[dst.role] and
               rules[dst.role]["EV_POTIONS"]
            then
                if potionSpellIds[spell_id] then
                    local p = rules[dst.role]["EV_POTIONS"].points
                    self:AddSuccess(timestamp, dst.name, dst.rt, WD_RULE_POTIONS, p)
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
                self:AddFail(timestamp, dst.name, dst.rt, string.format(WD_RULE_AURA_STACKS, stacks, getSpellLinkByIdWithTexture(spell_id)), p)
            elseif rules[dst.role]["EV_AURA_STACKS"][spell_id][0] then
                local p = rules[dst.role]["EV_AURA_STACKS"][spell_id][0].points
                self:AddFail(timestamp, dst.name, dst.rt, string.format(WD_RULE_AURA_STACKS_ANY, "("..stacks..")", getSpellLinkByIdWithTexture(spell_id)), p)
            end
        end
    end
    -----------------------------------------------------------------------------------------------------------------------
    if event == "SPELL_DISPEL" or event == "SPELL_STOLEN" then
        if src and
           rules[src.role] and
           rules[src.role]["EV_DISPEL"] and
           rules[src.role]["EV_DISPEL"][target_spell_id]
        then
            local p = rules[src.role]["EV_DISPEL"][target_spell_id].points
            self:AddSuccess(timestamp, src.name, src.rt, string.format(WD_RULE_DISPEL, getSpellLinkByIdWithTexture(target_spell_id)), p)
        end
    end
    -----------------------------------------------------------------------------------------------------------------------
    if event == "SPELL_DAMAGE" and
        dst and
        rules[dst.role]
    then
        local amount, overkill = tonumber(arg[15]), tonumber(arg[16])
        local total = amount + overkill
        if overkill == 0 then total = total + 1 end

        if overkill > -1 and rules[dst.role]["EV_DEATH"] and rules[dst.role]["EV_DEATH"][spell_id] then
            local p = rules[dst.role]["EV_DEATH"][spell_id].points
            self:AddFail(timestamp, dst.name, dst.rt, string.format(WD_RULE_DEATH, getSpellLinkByIdWithTexture(spell_id)), p)
        else
            if rules[dst.role]["EV_DAMAGETAKEN"] and rules[dst.role]["EV_DAMAGETAKEN"][spell_id] then
                local damagetaken_rule = rules[dst.role]["EV_DAMAGETAKEN"][spell_id]
                local p = damagetaken_rule.points
                if damagetaken_rule.amount > 0 and total > damagetaken_rule.amount then
                    self:AddFail(timestamp, dst.name, dst.rt, string.format(WD_RULE_DAMAGE_TAKEN_AMOUNT, damagetaken_rule.amount, getSpellLinkByIdWithTexture(spell_id)), p)
                elseif damagetaken_rule.amount == 0 and total > 0 then
                    self:AddFail(timestamp, dst.name, dst.rt, string.format(WD_RULE_DAMAGE_TAKEN, getSpellLinkByIdWithTexture(spell_id)), p)
                end
            end
        end
    end
    -----------------------------------------------------------------------------------------------------------------------
    if event == "UNIT_DIED" and dst then
        for i=1,#self.encounter.players do
            if getFullCharacterName(self.encounter.players[i].name) == getFullCharacterName(dst.name) then
                self.encounter.deaths = self.encounter.deaths + 1
                break
            end
        end

        if rules[dst.role] and
           rules[dst.role]["EV_DEATH_UNIT"] and
           rules[dst.role]["EV_DEATH_UNIT"].unit == getShortCharacterName(dst.name)
        then
            local p = rules[dst.role]["EV_DEATH_UNIT"].points
            local dst_nameWithMark = dst.name
            if dst.rt > 0 then dst_nameWithMark = getRaidTargetTextureLink(dst.rt).." "..dst.name end
            self:AddSuccess(timestamp, dst.name, dst.rt, string.format(WD_RULE_DEATH_UNIT, dst_nameWithMark), p)
        end
    end
end

function WD:IsNpc(flags)
    local f = bit.band(flags, COMBATLOG_OBJECT_TYPE_MASK)
    if f == COMBATLOG_OBJECT_TYPE_NPC then return true end
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
