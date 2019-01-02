
WdLib.timers = {}
local lib = WdLib.timers

function lib:CreateTimer(fn, delay, ...)
    local function executeFn(self) self.fn(unpack(self.args)) end

    local self = C_Timer.NewTimer(math.max(delay, 0.01), executeFn)
    self.args = {...}
    self.fn = fn

    return self
end

function lib:StopTimer(self)
    if self then
        self:Cancel()
    end
end

function lib:RestartTimer(self, fn, delay, ...)
    lib:StopTimer(self)
    return lib:CreateTimer(fn, delay, ...)
end

function lib:PostponeCall(fn, delay)
    C_Timer.After(delay, fn)
end
