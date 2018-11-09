
WD.mainFrame = CreateFrame("Frame")
local WDMF = WD.mainFrame
WDMF.encounter = {}

encounterIDs = {
	[0] = 'Test',
	[2144] = 'UD_TALOC',
	[2141] = 'UD_MOTHER',
	[2136] = 'UD_ZEKVOZ',
	[0] = 'UD_VECTIS',
	[0] = 'UD_FETID',
	[0] = 'UD_ZUL',
	[0] = 'UD_MYTRAX',
	[2122] = 'UD_GHUUN',
}

local currentRealmName = string.gsub(GetRealmName(), "%s+", "")

function getTimedDiff(startTime, endTime)
	if startTime == nil or endTime == nil then return end
	local dt = endTime - startTime
	if startTime > endTime then dt = -dt end
	local m = floor(dt / 60)
	dt = dt - m * 60
	local s = floor(dt)
	dt = dt - s
	local ms = dt * 1000
	local MIN = string.format("%02d", m)
	local SEC = string.format("%02d", s)
	local MSC = string.format("%003d", ms)
	return MIN .. ":" .. SEC .. "." .. MSC
end

function getTimedDiffShort(startTime, endTime)
	local dt = endTime - startTime
	local m = floor(dt / 60)
	dt = dt - m * 60
	local s = floor(dt)
	local MIN = string.format("%02d", m)
	local SEC = string.format("%02d", s)
	return MIN .. ":" .. SEC
end

local function getActiveRulesForEncounter(encounterId)
	local encounterName = encounterIDs[encounterId]
	if not encounterName then 
		print('Unknown name for encounterId:'..encounterId)
	end
	
	local rules = {
		['EV_DAMAGETAKEN'] = {},	-- done
		['EV_DEATH'] = {},			-- done
		['EV_AURA'] = {{{}}},		-- done
		['EV_AURA_STACKS'] = {},	-- done
		['EV_START_CAST'] = {},		-- done
		['EV_CAST'] = {},			-- done
		['EV_INTERRUPTED_CAST'] = {},	-- done
		['EV_DEATH_UNIT'] = {},		-- done
	}
	
	for i=1,#WD.db.profile.rules do
		if WD.db.profile.rules[i].isActive == true --[[and WD.db.profile.rules[i].encounter == encounterName]] then
			local rType = WD.db.profile.rules[i].type
			local arg0 = WD.db.profile.rules[i].arg0
			local arg1 = WD.db.profile.rules[i].arg1
			local p = WD.db.profile.rules[i].points
			if rType == 'EV_DAMAGETAKEN' then
				rules[rType][arg0] = {}
				rules[rType][arg0].amount = arg1
				rules[rType][arg0].points = p
			elseif rType == 'EV_DEATH' then
				rules[rType][arg0] = p
			elseif rType == 'EV_DEATH_UNIT' then
				rules[rType].unit = arg0
				rules[rType].points = p
			else
				if not rules[rType][arg0] then
					rules[rType][arg0] = {}
				end
				rules[rType][arg0][arg1] = p
			end
		end
	end
	
	return rules
end

local function printFuckups()
	for _,v in pairs(WDMF.encounter.fuckers) do
		local msg = string.format(WD_PRINT_FAILURE, v.timestamp, getShortCharacterName(v.name), v.reason, v.points)
		sendMessage(msg)
	end
end

local function saveFuckups()
	if WD.cache.roster then
		for _,v in pairs(WDMF.encounter.fuckers) do
			WD:SavePenaltyPointsToGuildRoster(v)
		end
	end
	WD:RefreshGuildRosterFrame()
end

local function addSuccess(timestamp, name, rule, points)
	print(timestamp..' success:'..name.." rule: "..rule.." points:"..points)
end

local function addFail(timestamp, name, msg, points)
	if WDMF.encounter.deaths > WD.db.profile.maxDeaths then
		local t = getTimedDiff(WDMF.encounter.startTime, timestamp)
		local txt = t.." "..name.." [FAIL] "..msg
		print('Ignored fuckup: '..txt)
		return
	end
	
	local fucker = {}
	fucker.encounter = WDMF.encounter.name
	fucker.timestamp = getTimedDiff(WDMF.encounter.startTime, timestamp)
	fucker.name = name
	fucker.reason = msg
	fucker.points = points
	WDMF.encounter.fuckers[#WDMF.encounter.fuckers+1] = fucker
	
	if WD.db.profile.sendFailImmediately == true then
		local txt = string.format(WD_PRINT_FAILURE, fucker.timestamp, getShortCharacterName(fucker.name), fucker.reason, fucker.points)
		sendMessage(txt)

		WD:SavePenaltyPointsToGuildRoster(fucker)
	end
	
	WD:RefreshLastEncounterFrame()
end

function WDMF:OnCombatEvent(...)
	if self.encounter.interrupted == 1 then
		return
	end

    local arg = {...}
    local timestamp, event, _, src_guid, src_name, src_flags, src_raid_flags, dst_guid, dst_name, dst_flags, dst_raid_flags, spell_id, spell_name, spell_school = ...

	local rules = WDMF.encounter.rules
	
	if event == 'SPELL_AURA_APPLIED' and rules['EV_AURA'][spell_id] and rules['EV_AURA'][spell_id]["apply"] then
		local p = rules['EV_AURA'][spell_id]["apply"]
		addFail(timestamp, dst_name, string.format(WD_RULE_APPLY_AURA, getSpellLinkById(spell_id)), p)
	end

	if event == 'SPELL_AURA_REMOVED' and rules['EV_AURA'][spell_id] and rules['EV_AURA'][spell_id]["remove"] then
		local p = rules['EV_AURA'][spell_id]["remove"]
		addFail(timestamp, dst_name, string.format(WD_RULE_REMOVE_AURA, getSpellLinkById(spell_id)), p)
	end
	
	if event == 'SPELL_AURA_APPLIED_DOSE' then
		local stacks = tonumber(arg[16])
		if rules['EV_AURA_STACKS'][spell_id] and rules['EV_AURA_STACKS'][spell_id][stacks] then
			local p = rules['EV_AURA'][spell_id]["remove"][stacks]
			addFail(timestamp, dst_name, string.format(WD_RULE_AURA_STACKS, stacks, getSpellLinkById(spell_id)), p)
		end
	end
	
	if event == 'SPELL_CAST_START' and rules['EV_START_CAST'][spell_id] and rules['EV_START_CAST'][spell_id][src_name] then
		local p = rules['EV_START_CAST'][spell_id][src_name]
		addSuccess(timestamp, src_name, string.format(WD_RULE_CAST_START, src_name, getSpellLinkById(spell_id)), p)
	end
	
	if event == 'SPELL_CAST_SUCCESS' and rules['EV_CAST'][spell_id] and rules['EV_CAST'][spell_id][src_name] then
		local p = rules['EV_CAST'][spell_id][src_name]
		addSuccess(timestamp, src_name, string.format(WD_RULE_CAST, src_name, getSpellLinkById(spell_id)), p)
	end
	
	if event == 'SPELL_INTERRUPT' then
		local target_spell_id = tonumber(arg[14])
		if rules['EV_INTERRUPTED_CAST'][target_spell_id] and rules['EV_INTERRUPTED_CAST'][target_spell_id][dst_name] then
			local p = rules['EV_CAST'][spell_id][dst_name]
			addSuccess(timestamp, src_name, string.format(WD_RULE_CAST_INTERRUPT, getSpellLinkById(spell_id)), src_name, p)
		end
	end
	
	if event == 'SPELL_DAMAGE' then
        local death_rule = rules["EV_DEATH"][spell_id]
        local damagetaken_rule = rules["EV_DAMAGETAKEN"][spell_id]
        local amount, overkill = tonumber(arg[15]), tonumber(arg[16])

        local total = amount + overkill
        if overkill == 0 then total = total + 1 end
        
        if death_rule and overkill > -1 then
			local p = death_rule
            addFail(timestamp, dst_name, string.format(WD_RULE_DEATH, getSpellLinkById(spell_id)), p)
        elseif damagetaken_rule then
			local p = damagetaken_rule.points
			if damagetaken_rule.amount > 0 and total > damagetaken_rule.amount then 
				addFail(timestamp, dst_name, string.format(WD_RULE_DAMAGE_TAKEN_AMOUNT, damagetaken_rule.amount, getSpellLinkById(spell_id)), p)
			elseif damagetaken_rule.amount == 0 and total > 0 then
				addFail(timestamp, dst_name, string.format(WD_RULE_DAMAGE_TAKEN, getSpellLinkById(spell_id)), p)
			end
        end
	end
	
	if event == 'UNIT_DIED' then
		for i=1,#self.encounter.players do
			if self.encounter.players[i] == getFullCharacterName(dst_name) then
				self.encounter.deaths = self.encounter.deaths + 1
				break
			end
		end
	
		if rules['EV_DEATH_UNIT'].unit == dst_name then
			addSuccess(timestamp, dst_name, string.format(WD_RULE_DEATH_UNIT, dst_name), rules['EV_DEATH_UNIT'].points)
		end
	end
end

function WDMF:OnEvent(event, ...)
	if event == 'ENCOUNTER_START' then
		local encounterID, name = ...
		self:ResetEncounter()
		self:StartEncounter(encounterID, name)
		self:RegisterEvent('COMBAT_LOG_EVENT_UNFILTERED')
	elseif event == 'ENCOUNTER_END' then
		self:UnregisterEvent('COMBAT_LOG_EVENT_UNFILTERED')
		self:StopEncounter()
	elseif event == 'COMBAT_LOG_EVENT_UNFILTERED' then
		self:OnCombatEvent(CombatLogGetCurrentEventInfo())
	elseif event == 'CHAT_MSG_ADDON' then
		self:OnAddonMessage(...)
	end
end

function WDMF:StartEncounter(encounterID, encounterName)
	local pullId = 1
	if WD.db.profile.encounters[encounterName] then pullId = WD.db.profile.encounters[encounterName] + 1 end
	
	sendMessage(string.format(WD_ENCOUNTER_START, encounterName, pullId, encounterID))
	self.encounter.id = encounterID
	self.encounter.name = date("%d/%m").." "..encounterName..' ('..pullId..')'
	self.encounter.startTime = time()
	self.encounter.rules = getActiveRulesForEncounter(self.encounter.id)
	self.encounter.players = {}
	
	if UnitInRaid('player') ~= nil then
		for i=1,40 do
			local unit = 'raid'..i
			if UnitIsVisible(unit) then
				local name, realm = UnitName(unit)
				realm = realm or currentRealmName
				self.encounter.players[#self.encounter.players+1] = name.."-"..realm
			end
		end
	else
		local name, realm = UnitName('player')
		realm = realm or currentRealmName
		self.encounter.players[#self.encounter.players+1] = name.."-"..realm
	end

	-- save pull information
	if WD.cache.roster then
		for _,v in pairs(self.encounter.players) do
			WD:SavePullsToGuildRoster(v)
		end
	end
	WD:RefreshGuildRosterFrame()

	WD:AddPullHistory(encounterName)
end

function WDMF:StopEncounter()
	if self.encounter.stopped == 1 then return end
	self.encounter.endTime = time()
	
	if WD.db.profile.sendFailImmediately == false then
		printFuckups()
		saveFuckups()
	end

	self.encounter.stopped = 1
	sendMessage(string.format(WD_ENCOUNTER_STOP, self.encounter.name, getTimedDiffShort(self.encounter.startTime, self.encounter.endTime)))
end

function WDMF:ResetEncounter()
	self.encounter.name = ""
	self.encounter.startTime = 0
	self.encounter.endTime = 0
	self.encounter.fuckers = {}
	self.encounter.players = {}
	self.encounter.deaths = 0
	self.encounter.interrupted = 0
	self.encounter.stopped = 0
end

function WDMF:OnAddonMessage(msgId, msg)
	if msgId == 'ping' then
		print(msgId)
		WD:SendAddonMessage('pong', msg)
	elseif msgId == 'pong' then
		print(msgId)
	end
end

function WD:EnableConfig()
	if WD.db.profile.isEnabled == false then
		WDMF:RegisterEvent('CHAT_MSG_ADDON')
		WDMF:RegisterEvent('ENCOUNTER_START')
		WDMF:RegisterEvent('ENCOUNTER_END')
		
		WD.db.profile.isEnabled = true
		sendMessage(WD_ENABLED)
	else
		WDMF:UnregisterEvent('CHAT_MSG_ADDON')
		WDMF:UnregisterEvent('ENCOUNTER_START')
		WDMF:UnregisterEvent('ENCOUNTER_END')
		WD.db.profile.isEnabled = false
		sendMessage(WD_DISABLED)
	end
end

function WD:SendAddonMessage(msgId, msg)
	if not msgId or not msg then return end
	C_ChatInfo.SendAddonMessage(msgId, msg, 'GUILD')
end
