
function calculateCoef(points, pulls)
	local mult = 10^2
	return math.floor((points * 1.0 / pulls) * mult + 0.5) / mult
end

local function parseOfficerNote(note)
	local points, pulls = string.match(note, "^(%w+),(%w+)$")
	local isAlt = "no"

	for i=1,GetNumGuildMembers() do
		local name, _, rankIndex = GetGuildRosterInfo(i)
		if note == getShortCharacterName(name) and rankIndex < 6 then
			isAlt = "yes"
			break
		end
	end
	
	return tonumber(points) or 0, tonumber(pulls) or 0, isAlt
end

function WD:FindMain(name)
	for _,v in pairs(WD.cache.roster) do
		for i=1,#v.alts do
			if v.alts[i] == name then
				return v.name
			end
		end
	end
	
	return name
end

function WD:OnGuildRosterUpdate()
	if not WD.db.profile.minGuildRank then
		local gRanks = WD:GetGuildRanks()
		for k,v in pairs(gRanks) do
			if v.id == 0 then
				WD.db.profile.minGuildRank = v
				break
			end
		end
	end
	
	WD.cache.roster = {}
	WD.cache.rosterkeys = {}
	local altInfos = {}
	for i=1,GetNumGuildMembers() do
		local name, rank, rankIndex, _, _, _, _, officernote, _, _, class = GetGuildRosterInfo(i)
		if officernote and (rankIndex == 0 or rankIndex <= WD.db.profile.minGuildRank.id) then
			local info = {}
			info.index = i
			info.name, info.class, info.rank = name, class, rank
			info.points, info.pulls, info.isAlt = parseOfficerNote(officernote)
			info.alts = {}
			if info.isAlt == "no" then
				if info.pulls == 0 then
					info.coef = info.points
				else
					info.coef = calculateCoef(info.points, info.pulls)
				end
				
				if not WD.cache.roster[name] then
					WD.cache.rosterkeys[#WD.cache.rosterkeys+1] = name
				end
				WD.cache.roster[name] = info
			else
				local altInfo = {}
				altInfo.index = i
				altInfo.name = info.name
				altInfo.main = officernote
				altInfos[#altInfos+1] = altInfo
			end
		end
	end
	
	for _,v in pairs(altInfos) do
		mainName = getFullCharacterName(v.main)
		if WD.cache.roster[mainName] then
			table.insert(WD.cache.roster[mainName].alts, v.name)
		end
	end
	
	WD:SortGuildRoster(WD.cache.rostersort, WD.cache.rostersortinverse)
end

function WD:SortGuildRoster(param, inverse, callback)
	if not param then return end
	
	local func = nil
	if param == "BY_NAME" then
		func = function(a, b) if inverse == true then return a > b else return a < b end end
	elseif param == "BY_POINTS" then
		func = function(a, b) if inverse == true then return WD.cache.roster[a].points < WD.cache.roster[b].points else return WD.cache.roster[a].points > WD.cache.roster[b].points end end
	elseif param == "BY_PULLS" then
		func = function(a, b) if inverse == true then return WD.cache.roster[a].pulls < WD.cache.roster[b].pulls else return WD.cache.roster[a].pulls > WD.cache.roster[b].pulls end end
	elseif param == "BY_RANK" then
		func = function(a, b) if inverse == true then return WD.cache.roster[a].rank < WD.cache.roster[b].rank else return WD.cache.roster[a].rank > WD.cache.roster[b].rank end end
	elseif param == "BY_RESULT" then
		func = function(a, b) if inverse == true then return WD.cache.roster[a].coef < WD.cache.roster[b].coef else return WD.cache.roster[a].coef > WD.cache.roster[b].coef end end
	else
		print("Unsupported sort param:"..param)
		return
	end
	
	if not func then return end
	table.sort(WD.cache.rosterkeys, func)

	WD.cache.rostersort = param
	WD.cache.rostersortinverse = inverse

	if callback then
		callback()
	end
end

function WD:SavePullsToGuildRoster(v)
	local name = self:FindMain(v)
	if WD.cache.roster[name] then
		local info = WD.cache.roster[name]
		info.pulls = info.pulls + 1
		info.coef = calculateCoef(info.points, info.pulls)

		if WD.db.profile.enablePenalties == true then
			GuildRosterSetOfficerNote(info.index, info.points..","..info.pulls)
		end
	end
end

function WD:SavePenaltyPointsToGuildRoster(v)
	local name = self:FindMain(getFullCharacterName(v.name))
	if WD.cache.roster[name] then
		local info = WD.cache.roster[name]
		info.points = info.points + v.points
		if info.points < 0 then info.points = 0 end
		info.coef = calculateCoef(info.points, info.pulls)
		
		if WD.db.profile.enablePenalties == true then
			GuildRosterSetOfficerNote(info.index, info.points..","..info.pulls)
		end
		
		WD:AddHistory(v)
	end
end

function WD:ResetGuildStatistics()
	for i=1,GetNumGuildMembers() do
		local name, rank, rankIndex, _, _, _, _, officernote, _, _, class = GetGuildRosterInfo(i)
		if officernote and rankIndex < 6 then
			local info = {}
			info.index = i
			info.name, info.class, info.rank = name, class, rank
			info.points, info.pulls, info.isAlt = parseOfficerNote(officernote)
			info.alts = {}
			if info.isAlt == "no" then
				GuildRosterSetOfficerNote(info.index, "0,0")
			end
		end
	end
	
	self:OnGuildRosterUpdate()
	
	sendMessage(WD_RESET_GUILD_ROSTER)
end

function WD:GetGuildRanks()
	local ranks = {}
	local temp = {}
	for i=1,GetNumGuildMembers() do
		local _, rank, rankIndex = GetGuildRosterInfo(i)
		temp[rankIndex] = rank
	end
	
	for k,v in pairs(temp) do
		local rank = { id = k, name = v }
		table.insert(ranks, rank)

	end
	
	return ranks
end
