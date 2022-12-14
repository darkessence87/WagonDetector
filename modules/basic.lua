
local WDModule = {}
WDModule.__index = WDModule
setmetatable(WDModule, {
    __call = function(v, ...)
        local self = setmetatable({}, v)
        self:init(...)
        return self
    end,
})

function WDModule:init(buttonName, parent, yOffset)
    self.frame = CreateFrame("Frame", nil, parent)
    self.frame:SetSize(1000, 600)
    self.frame:ClearAllPoints()
    self.frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 161, 0)
    self.frame:SetFrameStrata("HIGH")

    self.button = WdLib.gui:createButton(parent)
    self.button:SetPoint("TOPLEFT", parent, "TOPLEFT", 1, yOffset)
    self.button:SetSize(158, 20)
    self.button:SetScript("OnClick", function()
        if not self.frame:IsVisible() then
            parent:HideModules()
            self.frame:Show()
            self.button.t:SetColorTexture(.2, .6, .2, 1);
        end
    end)
    self.button.txt = WdLib.gui:createFont(self.button, "LEFT", buttonName)
    self.button.txt:SetSize(150, 20)
    self.button.txt:SetPoint("LEFT", self.button, "LEFT", 5, 0)
    self.button.t:SetColorTexture(.2, .2, .2, 1)
end

WD.Module = WDModule
