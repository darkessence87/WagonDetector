
function WD:AddHistory(v)
    WD.db.profile.history[#WD.db.profile.history+1] = v
    v.index = #WD.db.profile.history

    WD:RefreshHistoryFrame()
end

function WD:RevertHistory(v)
    WD:DeleteHistory(v)

    if v.isReverted == true then
        v.reason = string.match(v.reason, "%["..WD_REVERT_STR.."%]%s(.*)")
        v.isReverted = false
    else
        v.reason = "["..WD_REVERT_STR.."] "..v.reason
        v.isReverted = true
    end

    v.points = -v.points
    WD:SavePenaltyPointsToGuildRoster(v)
end

function WD:DeleteHistory(v)
    local index = v.index
    table.remove(WD.db.profile.history, v.index)
    for i=index, #WD.db.profile.history do
        WD.db.profile.history[i].index = i
    end

    WD:RefreshHistoryFrame()
end

function WD:AddPullHistory(encounter)
    if WD.db.profile.encounters[encounter] then
        WD.db.profile.encounters[encounter] = WD.db.profile.encounters[encounter] + 1
    else
        WD.db.profile.encounters[encounter] = 1
    end
end

function WD:ExportHistory()
    local r = WD.guiFrame.module["history"].exportWindow
    local history = deepcopy(WD.db.profile.history)
    for k,v in pairs(history) do
        local _, _, spellString = string.find(v.reason, "|c%x+|H(.+)|h%[.*%]")
        if spellString then
            v.reason = string.gsub(v.reason, "|", "||")
        end
    end
    local txt = encode64(table.tostring(history))

    r.editBox:SetText(txt)
    r.editBox:SetScript("OnChar", function() r.editBox:SetText(txt); r.editBox:HighlightText(); end)
    r.editBox:HighlightText()
    r.editBox:SetAutoFocus(true)
    r.editBox:SetCursorPosition(0)

    r:Show()
end
