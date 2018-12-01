
local WDMF = WD.mainFrame
WD.cache.tracker = {}

local function getRaidTarget(src_raid_flags)
    local rt = bit.band(src_raid_flags, COMBATLOG_OBJECT_RAIDTARGET_MASK)
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

function WD:Tracker_OnEvent(...)
    local arg = {...}
    local timestamp, event, _, src_guid, src_name, _, src_raid_flags, dst_guid, dst_name, dst_flags, dst_raid_flags, spell_id, spell_name, spell_school = ...

    local rt = getRaidTarget(src_raid_flags)
    if rt > 0 then
        --print(getTextureLinkByPath("Interface\\TargetingFrame\\UI-RaidTargetingIcon_"..rt))
    end

    return true
end