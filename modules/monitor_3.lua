
local WDMonitor3Module = {}
WDMonitor3Module.__index = WDMonitor3Module

setmetatable(WDMonitor3Module, {
    __index = WD.Module,
    __call = function (v, ...)
        local self = setmetatable({}, v)
        self:init(...)
        return self
    end,
})

function WDMonitor3Module:init(parent, yOffset)
    WD.Module.init(self, WD_BUTTON_TRACKING_STATS_MODULE, parent, yOffset)
    WD:InitBasicStatsMonitorModule(self.frame)
end

WD.Monitor3Module = WDMonitor3Module