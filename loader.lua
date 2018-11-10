
WD = LibStub("AceAddon-3.0"):NewAddon("Wagon Detector", "AceEvent-3.0", "AceConsole-3.0")

-- basic menu
WD.options = {
	name = "Wagon Detector",
	handler = WD,
	type = "group",
	get = function(key) return self.db.profile[key[1]] end,
	set = function(key, value) self.db.profile[key[1]] = value; end,
	args = {},
}

function WD:OnInitialize()
	self:LoadDefaults()
	
	LibStub("AceConfig-3.0"):RegisterOptionsTable("WD", self.options)
	self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("WD", "Wagon Detector")

	self.db = LibStub("AceDB-3.0"):New("WD_DB", self.defaults, true)
	self.db.RegisterCallback(self, "OnProfileChanged", "ReloadProfile")
	self.db.RegisterCallback(self, "OnProfileCopied", "ReloadProfile")
	self.db.RegisterCallback(self, "OnProfileReset", "ReloadProfile")
	
	LibStub("AceConfig-3.0"):RegisterOptionsTable("WD-Profiles", LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db))
	self.profileFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("WD-Profiles", "Profiles", "WD")
	
	SLASH_WD1 = '/wd';
    SlashCmdList["WD"] = function(...) self:SlashHandler(...) end

	self:CreateGuiFrame()

	if self.mainFrame then
		self.mainFrame:RegisterEvent('VARIABLES_LOADED')

		if WD.db.profile.isEnabled == true then
			self.mainFrame:RegisterEvent('CHAT_MSG_ADDON')
			self.mainFrame:RegisterEvent('ENCOUNTER_START')
			self.mainFrame:RegisterEvent('ENCOUNTER_END')
		end

		self.mainFrame:SetScript('OnEvent', function(self, ...) self:OnEvent(...); end)
	end
	
	-- reload history
	for i=1, #WD.db.profile.history do
		WD.db.profile.history[i].index = i
	end
end

function WD:LoadDefaults()
	WD.defaults = {
		profile = {
			isEnabled = false,
			isLocked = true,
			rules = {},
			chat = "PRINT",
			history = {},
			sendFailImmediately = false,
			enablePenalties = true,
			maxDeaths = 5,
			encounters = {},
		}
	}
end

function WD:ReloadProfile()
end

function WD:SlashHandler(msg, box)
    msg = string.lower(msg)
    cmd, tail = string.match(msg, '^%s*(%a+)%s*(.*)$');
	
	if cmd == 'config' then
		self:OpenConfig()
	elseif cmd == 'starttest' then
		self.mainFrame:OnEvent('ENCOUNTER_START', 0, 'Test')
	elseif cmd == 'stoptest' then
		self.mainFrame:OnEvent('ENCOUNTER_END')
	elseif cmd == 'wipe' then
		self:ResetGuildStatistics()
	elseif cmd == 'interrupt' then
		self.mainFrame.encounter.interrupted = 1
		print(WD_ENCOUNTER_INTERRUPTED)
	elseif cmd == 'pull' then
		WD:SendAddonMessage('block_encounter')
	else
		print(WD_HELP)
	end
end