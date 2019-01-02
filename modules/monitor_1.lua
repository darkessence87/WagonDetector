
local WDMonitor1Module = {}
WDMonitor1Module.__index = WDMonitor1Module

setmetatable(WDMonitor1Module, {
    __index = WD.Module,
    __call = function (v, ...)
        local self = setmetatable({}, v)
        self:init(...)
        return self
    end,
})

function WDMonitor1Module:init(parent, yOffset)
    WD.Module.init(self, WD_BUTTON_TRACKING_AURAS_MODULE, parent, yOffset)
    WD:InitBasicMonitorModule(self.frame, "buffs", "debuffs")
end

WD.Monitor1Module = WDMonitor1Module