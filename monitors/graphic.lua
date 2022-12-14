local WDGraphic = CreateFrame("Frame", 'WDGraphic', UIParent)
WDGraphic.bg = WdLib.gui:createColorTexture(WDGraphic, "BORDER", .1, .1, .1, .8)
WDGraphic.bg:SetAllPoints()
WDGraphic.txt = WdLib.gui:createFontDefault(WDGraphic, "CENTER", "")
WDGraphic.txt:SetFont([[Interface\AddOns\WagonDetector\media\fonts\Noto.ttf]], 9, "")
WDGraphic.txt:SetSize(300, 25)
WDGraphic.txt:SetPoint("TOP", 0, -2)

local DEFAULT_THICKNESS = 2

WDGraphic.allocated_lines = {}
WDGraphic.reserved_index = 0
WDGraphic:Hide()

local function allocateLine()
    local l = WDGraphic:CreateLine()
    l:SetThickness(DEFAULT_THICKNESS)
    l:SetColorTexture(1,1,1,1)
    l:Hide()
    WDGraphic.allocated_lines[#WDGraphic.allocated_lines + 1] = l
    return l
end

function WDGraphic:ReserveLines(n)
    if n <= #WDGraphic.allocated_lines then
        return
    end

    local required = n - #WDGraphic.allocated_lines
    for i=1,required do
        allocateLine()
    end
end

function WDGraphic:DrawLine(f, t)
    if not f or not t then
        return nil
    end

    return self:DrawLineXY(f.x or 0, f.y or 0, t.x or 0, t.y or 0)
end

function WDGraphic:DrawLineXY(fromX, fromY, toX, toY)
    if #self.allocated_lines == 0 or self.reserved_index >= #self.allocated_lines then
        print('please allocate more lines')
        return nil
    end

    local l = self.allocated_lines[self.reserved_index + 1]
    l:SetStartPoint("BOTTOMLEFT", self, fromX, fromY)
    l:SetEndPoint("BOTTOMLEFT", self, toX, toY)

    self.reserved_index = self.reserved_index + 1

    return l
end

function WDGraphic:DrawPolyline(points)
    if not points or type(points) ~= "table" then return nil end
    local resultLines = {}
    local prevPoint = nil
    for k,v in pairs(points) do
        -- draw [prevPoint, v] line
        if prevPoint then
            local line = self:DrawLineXY(prevPoint.x, prevPoint.y, v.x, v.y)
            if not line then
                return resultLines
            end
            resultLines[#resultLines+1] = line
        end
        prevPoint = v
    end
    return resultLines
end

function WDGraphic:OnUpdate()
    for k,v in pairs(WDGraphic.allocated_lines) do
        if k <= self.reserved_index then
            v:Show()
        else
            v:SetThickness(DEFAULT_THICKNESS)
            v:SetColorTexture(1,1,1,1)
            if v.txt then
                v.txt:SetText("")
            end
            v:Hide()
        end
    end
end

function WDGraphic:Reset()
    WDGraphic.reserved_index = 0
    self:OnUpdate()
    self.txt:SetText("")
    self:Hide()
    --collectgarbage("collect")
end

WD.Graphic = WDGraphic