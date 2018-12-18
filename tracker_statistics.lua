
local WDTS = nil

local function initPullsMenu()
    local function getPullName()
        if WD.db.profile.tracker.selected and
           WD.db.profile.tracker.selected > 0 and #WD.db.profile.tracker > 0 and
           WD.db.profile.tracker.selected <= #WD.db.profile.tracker
        then
            return WD.db.profile.tracker[WD.db.profile.tracker.selected].pullName
        elseif #WD.db.profile.tracker > 0 then
            WD.db.profile.tracker.selected = #WD.db.profile.tracker
            return WD.db.profile.tracker[#WD.db.profile.tracker].pullName
        end
        return "No pulls"
    end

    local function getPulls()
        local items = {}
        local function onSelect(frame, selected)
            WD.db.profile.tracker.selected = selected.index
        end
        local i = 1
        for k,v in pairs(WD.db.profile.tracker) do
            if type(v) == "table" then
                table.insert(items, {name = v.pullName, index = i, func = onSelect})
                i = i + 1
            end
        end
        return items
    end

    -- select pull button
    WDTS.buttons["select_pull"] = WdLib:createDropDownMenu(WDTS, getPullName(), getPulls())
    WDTS.buttons["select_pull"]:SetSize(200, 20)
    WDTS.buttons["select_pull"]:SetPoint("TOPLEFT", WDTS, "TOPLEFT", 1, -5)
    WDTS.buttons["select_pull"]:SetScript("OnShow", function(self) self.txt:SetText(getPullName()) end)
    local frame = WDTS.buttons["select_pull"]
    function frame:Refresh()
        WdLib:updateDropDownMenu(self, getPullName(), getPulls())
    end
end

function WD:InitTrackerStatisticsModule(parent)
    WDTS = parent

    WDTS.buttons = {}
    WDTS.data = {}

    initPullsMenu()

    function WDTS:OnUpdate()
    end
end
