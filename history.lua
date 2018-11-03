
function WD:AddHistory(v)
	WD.db.profile.history[#WD.db.profile.history+1] = v
	v.index = #WD.db.profile.history
	
	WD:RefreshHistoryFrame()
end

function WD:RevertHistory(v)
	WD:DeleteHistory(v)
	
	if v.isReverted == true then
		v.reason = string.match(v.reason, '%[REVERT%]%s(.*)')
		v.isReverted = false
	else
		v.reason = '[REVERT] '..v.reason
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
