
local WDMonitor2Module = {}
WDMonitor2Module.__index = WDMonitor2Module

setmetatable(WDMonitor2Module, {
    __index = WD.Module,
    __call = function (v, ...)
        local self = setmetatable({}, v)
        self:init(...)
        return self
    end,
})

function WDMonitor2Module:init(parent, yOffset)
    WD.Module.init(self, WD_BUTTON_TRACKING_OVERVIEW_MODULE, parent, yOffset)
    WD:InitBasicMonitorModule(self.frame, "dispel", "interrupt")
end

WD.Monitor2Module = WDMonitor2Module