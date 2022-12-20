
WdLib.gui = {}
local lib = WdLib.gui

lib.MAX_DROP_DOWN_MENUS = 40

local function make_border(f, cR, cG, cB, cA, size, offsetX, offsetY)
    offsetX = offsetX or 0
    offsetY = offsetY or 0

    f.bdTop = lib:createColorTexture(f, "BACKGROUND", cR, cG, cB, cA)
    f.bdTop:SetPoint("TOPLEFT", -size - offsetX, size + offsetY)
    f.bdTop:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", size + offsetX, offsetY)

    f.bdLeft = lib:createColorTexture(f, "BACKGROUND", cR, cG, cB, cA)
    f.bdLeft:SetPoint("TOPLEFT", -size - offsetX, offsetY)
    f.bdLeft:SetPoint("BOTTOMRIGHT", f, "BOTTOMLEFT", -offsetX, -offsetY)

    f.bdBottom = lib:createColorTexture(f, "BACKGROUND", cR, cG, cB, cA)
    f.bdBottom:SetPoint("BOTTOMLEFT", -size - offsetX, -size - offsetY)
    f.bdBottom:SetPoint("TOPRIGHT", f, "BOTTOMRIGHT", size + offsetX, -offsetY)

    f.bdRight = lib:createColorTexture(f, "BACKGROUND", cR, cG, cB, cA)
    f.bdRight:SetPoint("BOTTOMRIGHT", size + offsetX, offsetY)
    f.bdRight:SetPoint("TOPLEFT", f, "TOPRIGHT", offsetX, -offsetY)
end

local function createListButton(parent, name)
    local button = lib:createButton(parent)
    button.txt = lib:createFont(button, "LEFT", name)
    button.txt:SetPoint("LEFT", button, "LEFT", 5, 0)

    button.items = {}
    button.arrow = lib:createTexture(button, "Interface\\ChatFrame\\ChatFrameExpandArrow", "ARTWORK")
    button.arrow:SetSize(15, 15)
    button.arrow:SetPoint("RIGHT")
    return button
end

function lib:makeSpellLinkWithTexture(id, name)
    local _,_,icon = GetSpellInfo(id)
    if not icon then return " |cffffff00"..id.." "..name.."|r" end
    return "|cff71d5ff|Hspell:"..id.."|h "..lib:getTextureLinkByPath(icon, 18).." "..name.."|h|r"
end

function lib:getSpellLinkById(id)
    local name = GetSpellInfo(id)
    if not name then return "Unknown" end
    return "|cff71d5ff|Hspell:"..id.."|h["..name.."]|h|r"
end

function lib:getSpellLinkByIdWithTexture(id)
    local name,_,icon = GetSpellInfo(id)
    if not name or not icon then return "Unknown" end
    return "|cff71d5ff|Hspell:"..id.."|h "..lib:getTextureLinkByPath(icon, 18).." "..name.."|h|r"
end

function lib:getTextureLinkByPath(path, sz)
    if not path then return "" end
    return "|T"..path..":"..(sz or 0).."|t"
end

function lib:getRaidTargetTextureLink(rt)
    return lib:getTextureLinkByPath("Interface\\TargetingFrame\\UI-RaidTargetingIcon_"..rt, 20)
end

function lib:createColorTexture(parent, level, r, g, b, a, blendMode)
    local t = parent:CreateTexture()
    t:SetColorTexture(r, g, b, a)
    t:SetDrawLayer(level)
    if blendMode then
        t:SetBlendMode(blendMode)
    end
    return t
end

function lib:createTexture(parent, file, level)
    local t = parent:CreateTexture(nil, level)
    t:SetTexture(file)
    t:SetTexCoord(0,1,0,1)
    return t
end

function lib:createFontDefault(parent, hJustify, name)
    local font = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    font:SetSize(parent:GetSize())
    font:SetJustifyH(hJustify)
    font:SetJustifyV("MIDDLE")
    font:SetText(name)
    return font
end

function lib:createFont(parent, hJustify, name)
    local font = lib:createFontDefault(parent, hJustify, name)
    parent:SetFontString(font)
    return font
end

function lib:createCheckButton(parent)
    local button = CreateFrame("CheckButton", nil, parent)
    button:SetSize(20,20)

    make_border(button, .24, .25, .3, 1, 1)

    button.t = lib:createColorTexture(button, "BACKGROUND", 0, 0, 0, .3)
    button.t:SetAllPoints()

    button.ct = lib:createTexture(button, "Interface\\Buttons\\UI-CheckBox-Check", "ARTWORK")
    button.ct:SetAllPoints()
    button:SetCheckedTexture(button.ct)

    button.h = lib:createColorTexture(button, "OVERLAY", 1, 1, 1, .3)
    button.h:SetAllPoints()
    button:SetHighlightTexture(button.h)

    return button
end

function lib:createButton(parent)
    local button = CreateFrame("Button", nil, parent)
    button:EnableMouse(true)
    button:RegisterForClicks("LeftButtonUp")

    button.t = lib:createColorTexture(button, "BACKGROUND", .2, .2, .2, 1)
    button.t:SetAllPoints()

    button.h = lib:createColorTexture(button, "HIGHLIGHT", 0, 1, 0, .2, "MOD")
    button.h:SetAllPoints()
    button:SetHighlightTexture(button.h)

    return button
end

function lib:createSliderButton(parent, direction, width)
    local button = CreateFrame("Frame", nil, parent)
    button:EnableMouse(false)
    button:SetSize(width - 31, 12)

    button.t = lib:createTexture(button, [[Interface\AddOns\WagonDetector\media\textures\border]], "ARTWORK")
    button.t:SetAllPoints()

    if direction == "UP" then
        button:SetPoint("TOPLEFT", parent, "TOPLEFT", 30, -1)
    elseif direction == "DOWN" then
        button:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 30, -1)
        button.t:SetRotation(3.14159265359)
    end

    return button
end

function lib:updateScroller(self, lines)
    local minV = 50

    local deltaLines = lines - (self:GetHeight() - minV) / 21
    local maxV = deltaLines * 21
    if maxV < minV then maxV = minV end
    if maxV - minV < 1 then
        self.buttonUp:Hide()
        self.buttonDown:Hide()
    else
        self.buttonUp:Show()
        self.buttonDown:Show()
    end

    self:SetMinMaxValues(minV, maxV)
end

function lib:createScroller(parent, width, height, lines)
    local minV = 50

    local deltaLines = lines - (height - minV) / 21
    local maxV = deltaLines * 21
    if maxV < minV then maxV = minV end

    local function scrollFn(self, delta)
        delta = delta * self.slider:GetValueStep()
        local min,max = self.slider:GetMinMaxValues()
        local val = self.slider:GetValue()
        if (val - delta) < min then
            self.slider:SetValue(min)
        elseif (val - delta) > max then
            self.slider:SetValue(max)
        else
            self.slider:SetValue(val - delta)
        end
    end

    local scroller = CreateFrame("ScrollFrame", nil, parent)
    scroller.slider = CreateFrame("Slider", nil, scroller)
    scroller.slider:SetOrientation("VERTICAL")
    scroller.slider:SetValueStep(21)

    scroller.slider.buttonUp = lib:createSliderButton(scroller, "UP", width)
    scroller.slider.buttonDown = lib:createSliderButton(scroller, "DOWN", width)

    scroller:SetScript("OnMouseWheel", scrollFn)
    scroller.scrollerChild = CreateFrame("Frame", nil, scroller)
    scroller:SetScrollChild(scroller.scrollerChild)
    scroller:SetClipsChildren(true)

    scroller:SetSize(width, height)
    scroller:SetPoint("TOPLEFT", parent.headers[1], "BOTTOMLEFT", -30, -1)
    scroller:SetVerticalScroll(minV)
    scroller.slider:SetSize(16, height)
    scroller.slider:SetPoint("TOPLEFT", parent.headers[#parent.headers], "TOPRIGHT", 1, 1)
    scroller.slider:SetMinMaxValues(minV, maxV)
    scroller.slider:SetValue(minV)
    scroller.slider:SetScript("OnValueChanged", function (self, value)
        local minValue, maxValue = self:GetMinMaxValues()
        if value < minValue then
            value = minValue
        elseif value > maxValue then
            value = maxValue
        end
        self:GetParent():SetVerticalScroll(value)
    end)

    scroller.scrollerChild:SetSize(width, maxV)

    if maxV - minV < 1 then
        scroller.slider.buttonUp:Hide()
        scroller.slider.buttonDown:Hide()
    else
        scroller.slider.buttonUp:Show()
        scroller.slider.buttonDown:Show()
    end

    return scroller
end

function lib:createXButton(parent, xOffset)
    local xButton = lib:createButton(parent)
    xButton:SetFrameStrata("FULLSCREEN_DIALOG")
    xButton:SetPoint("TOPRIGHT", parent, "TOPRIGHT", xOffset, 0)
    xButton:SetSize(15, 15)
    xButton:SetScript("OnClick", function() parent:Hide() end)
    xButton.t:SetTexture([[Interface\AddOns\WagonDetector\media\textures\cross_button]])
    xButton.t:SetTexCoord(0, 1, 0, 1)
    xButton.h:SetTexture([[Interface\AddOns\WagonDetector\media\textures\cross_button]])
    xButton.h:SetTexCoord(0, 1, 0, 1)
    xButton.h:SetVertexColor(0, 1, 0, 1)
    xButton.h:SetBlendMode("DISABLE")
    return xButton
end

function lib:createListItemButton(parent, name, index)
    local button = lib:createButton(parent)
    button:SetPoint("TOPLEFT", parent, "TOPRIGHT", 1, index * -21)
    button:SetSize(200, 20)
    button.txt = lib:createFont(button, "LEFT", name)
    button.txt:SetPoint("LEFT", button, "LEFT", 5, 0)
    return button
end

function lib:createEditBox(parent)
    local input = CreateFrame("EditBox", nil, parent)
    input:EnableMouse(true)
    input:SetFrameStrata("DIALOG")
    input:SetAutoFocus(false)
    input:SetMaxLetters(50)
    input:SetJustifyH("CENTER")
    input:SetFontObject("GameFontNormal")
    input:SetHyperlinksEnabled(true)

    input.t = lib:createColorTexture(input, "BACKGROUND", .2, .2, .2, 1)
    input.t:SetAllPoints()
    return input
end

function lib:dropDownShow(self)
    if not self.items then return end
    for _,v in pairs(self.items) do
        if not v.locked then
            if v.item and not v.item.locked then
                v.item:Show()
            end
            if v.drop and not v.drop.locked then
                v.drop:Show()
            end
        end
    end
    self.isVisible = true

    if self.bg then
        self.bg:Show()
    end
end

function lib:dropDownHide(self)
    if not self.items then return end
    for _,v in pairs(self.items) do
        if v.item then
            v.item:Hide()
        end
        if v.drop then
            lib:dropDownHide(v.drop)
            v.drop:Hide()
        end
    end
    self.isVisible = false

    if self.bg then
        self.bg:Hide()
    end
end

function lib:onClickDropDown(self, v, onClick)
    local function click(item)
        self.selected = item
        self.txt:SetText(item.txt:GetText())
        lib:dropDownHide(self)
        if onClick then
            onClick(self, item.data)
        end
    end
    if v.item and not v.item.locked then
        click(v.item)
    end
    if v.drop and not v.drop.locked then
        click(v.drop)
    end
end

function lib:updateDropDownMenu(self, name, items, parent, callback)
    self.selected = nil
    self.txt:SetText(name)
    if #self.items > 0 then lib:dropDownHide(self) end

    if items and #items > 0 then
        if #items > lib.MAX_DROP_DOWN_MENUS then
            print("Too many drop frames requested")
            return
        end
        for i=1,#items do
            local v = items[i]
            if v.items then
                if not self.items[i] or not self.items[i].drop then
                    local item = lib:createDropDownMenu(self, v.name, v.items, parent)
                    item:SetSize(200, 20)
                    item:SetPoint("TOPLEFT", self, "TOPRIGHT", 1, (i - 1) * -21)
                    self.items[i] = {}
                    self.items[i].drop = item
                else
                    if self.items[i].item then self.items[i].item.locked = true end
                    self.items[i].drop.locked = nil
                    lib:updateDropDownMenu(self.items[i].drop, v.name, v.items, parent)
                end
            else
                if not self.items[i] or not self.items[i].item then
                    local item = lib:createListItemButton(self, v.name, i - 1)
                    item:SetSize(200, 20)
                    self.items[i] = {}
                    self.items[i].item = item
                end
                if self.items[i].drop then self.items[i].drop.locked = true end
                self.items[i].item.locked = nil
                self.items[i].item.data = v
                self.items[i].item.txt:SetText(v.name)
                self.items[i].item:SetScript("OnClick", function() lib:onClickDropDown(parent or self, self.items[i], v.func or callback) end)
                if v.hover then
                    lib:generateHover(self.items[i].item, v.hover)
                else
                    lib:clearHover(self.items[i].item)
                end
            end
        end
        if #items <= #self.items then
            for i=1, #items do
                self.items[i].locked = nil
            end
            for i=#items+1, #self.items do
                self.items[i].locked = true
            end
        end

        local frame = self.items[1].item or self.items[1].drop
        local width = frame:GetWidth() + 2
        local height = #items * frame:GetHeight() + #items + 1
        if not self.bg then
            self.bg = lib:createColorTexture(self, "BACKGROUND", 0, 0, 0, 1)
        end
        self.bg:SetSize(width, height)
        self.bg:SetPoint("TOPLEFT", frame, "TOPLEFT", -1, 1)
        self.bg:Hide()
    else
        for i=1, #self.items do
            self.items[i].locked = true
        end
        if self.bg then
            self.bg:SetSize(0, 0)
            self.bg:Hide()
        end
    end

    lib:dropDownHide(self)
end

function lib:resetDropDownMenu(self, name)
    self.selected = nil
    self.txt:SetText(name)
    lib:dropDownHide(self)
end

function lib:createDropDownMenu(parent, name, items, grandParent, callback)
    local dropFrame = createListButton(parent, name)
    dropFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    dropFrame:SetScript("OnClick", function(self)
        local parent = self:GetParent()
        if self.isVisible then
            lib:dropDownHide(self)
        else
            lib:dropDownHide(parent)
            lib:dropDownShow(parent)
            lib:dropDownShow(self)
        end
        if parent.menus then
            for _,v in pairs(parent.menus) do
                if v ~= self then
                    lib:dropDownHide(v)
                end
            end
        end
        if parent.hiddenMenus then
            for _,v in pairs(parent.hiddenMenus) do
                if v ~= self then
                    lib:dropDownHide(v)
                end
            end
        end
    end)
    dropFrame:SetScript("OnHide", function() lib:resetDropDownMenu(dropFrame, name) end)
    dropFrame.items = {}

    lib:updateDropDownMenu(dropFrame, name, items, grandParent or dropFrame, callback)
    lib:resetDropDownMenu(dropFrame, name)

    return dropFrame
end

function lib:findDropDownFrameByName(parent, name)
    local function getFrame(v)
        if v.item and not v.item.locked then return v.item end
        if v.drop and not v.drop.locked then return v.drop end
        return nil
    end
    for i=1,#parent.items do
        local f = getFrame(parent.items[i])
        if f and f.txt:GetText() == name then
            return f
        end

        if f.items then
            local frame = lib:findDropDownFrameByName(f, name)
            if frame then return frame end
        end
    end
    return nil
end

function lib:createTableHeader(self, name, x, y, xSize, ySize, onClick)
    local button = lib:createButton(self)
    button:EnableMouse(false)
    button:SetPoint("TOPLEFT", self, "TOPLEFT", x, y)
    button:SetSize(xSize, ySize)
    button.txt = lib:createFont(button, "CENTER", name)
    button.txt:SetSize(xSize, ySize)
    button.txt:SetPoint("LEFT", button, "LEFT", 0, 0)
    button.t:SetColorTexture(.5, .5, .5, 1)
    if onClick then button:EnableMouse(true); button:SetScript("OnClick", onClick) end
    return button
end

function lib:createTableHeaderNext(self, prev, name, xSize, ySize, onClick)
    local button = lib:createButton(self)
    button:EnableMouse(false)
    button:SetPoint("TOPLEFT", prev, "TOPRIGHT", 1, 0)
    button:SetSize(xSize, ySize)
    button.txt = lib:createFont(button, "CENTER", name)
    button.txt:SetSize(xSize, ySize)
    button.txt:SetPoint("LEFT", button, "LEFT", 0, 0)
    button.t:SetColorTexture(.5, .5, .5, 1)
    if onClick then button:EnableMouse(true); button:SetScript("OnClick", onClick) end
    return button
end

function lib:addNextColumn(self, parent, index, textOrientation, name)
    parent.column[index] = lib:createButton(parent)
    parent.column[index]:EnableMouse(false)
    parent.column[index]:SetSize(self.headers[index]:GetSize())
    if index > 1 then
        parent.column[index]:SetPoint("TOPLEFT", parent.column[index-1], "TOPRIGHT", 1, 0)
    end
    parent.column[index].t:SetColorTexture(.2, .2, .2, .5)
    parent.column[index].txt = lib:createFont(parent.column[index], textOrientation, name)
    if textOrientation == "LEFT" then
        parent.column[index].txt:SetPoint("LEFT", 5, 0)
    elseif textOrientation == "RIGHT" then
        parent.column[index].txt:SetPoint("RIGHT", -5, 0)
    else
        parent.column[index].txt:SetAllPoints()
    end
    return parent.column[index]
end

function lib:getTotalTableHeadersWidth(t, maxN)
    if not t or not t.headers or #t.headers < maxN then return 0 end
    local width = 0
    for i=1,maxN do
        width = width + t.headers[i]:GetWidth() + 1
    end
    return width - 1
end

function lib:convertTypesToItems(t, fn)
    local items = {}
    for i=1,#t do
        local item = { name = t[i], func = fn }
        table.insert(items, item)
    end
    return items
end

function lib:updateItemsByHoverInfo(needConversion, items, info, fn)
    if needConversion == true then
        items = lib:convertTypesToItems(items, fn)
    end
    for _,v in pairs(items) do
        if v.name and info[v.name] then
            v.hover = info[v.name]
        end
    end
    return items
end

function lib:createRuleWindow(parent)
    local r = CreateFrame("Frame", nil, parent)
    r.hiddenMenus = {}

    local totalWidth = 150
    local xSize = totalWidth - 2

    -- label
    r.label = lib:createFontDefault(r, "CENTER", "")
    r.label:SetSize(xSize, 20)
    r.label:SetPoint("TOPLEFT", r, "TOPLEFT", 1, -1)

    -- arg0
    r.hiddenMenus["arg0_edit"] = lib:createEditBox(r)
    r.hiddenMenus["arg0_edit"]:SetSize(xSize, 20)
    r.hiddenMenus["arg0_edit"]:SetPoint("TOPLEFT", r.label, "BOTTOMLEFT", 0, -1)
    r.hiddenMenus["arg0_edit"]:Hide()

    -- arg1
    r.hiddenMenus["arg1_edit"] = lib:createEditBox(r)
    r.hiddenMenus["arg1_edit"]:SetSize(xSize, 20)
    r.hiddenMenus["arg1_edit"]:SetPoint("TOPLEFT", r.hiddenMenus["arg0_edit"], "BOTTOMLEFT", 0, -1)
    r.hiddenMenus["arg1_edit"]:Hide()

    r.hiddenMenus["arg1_drop"] = lib:createDropDownMenu(r, "Select aura action", {{name = "apply"},{name = "remove"}})
    r.hiddenMenus["arg1_drop"].txt:SetJustifyH("CENTER")
    r.hiddenMenus["arg1_drop"]:SetSize(xSize, 20)
    r.hiddenMenus["arg1_drop"]:SetPoint("TOPLEFT", r.hiddenMenus["arg0_edit"], "BOTTOMLEFT", 0, -1)
    r.hiddenMenus["arg1_drop"]:Hide()

    r:SetScript("OnHide", function() for _,v in pairs(r.hiddenMenus) do v:Hide() end end)

    r:EnableMouse(true)
    r:SetSize(totalWidth, 3 * 21 + 1)
    r.bg = lib:createColorTexture(r, "BACKGROUND", 0, 0, 0, 1)
    r.bg:SetAllPoints()

    r:Hide()

    return r
end

function lib:showHiddenEditBox(parent, name, txt)
    parent.hiddenMenus[name]:EnableMouse(true)
    parent.hiddenMenus[name]:SetText(txt)
    parent.hiddenMenus[name]:SetScript("OnEscapePressed", function() parent.hiddenMenus[name]:SetText(txt); parent.hiddenMenus[name]:ClearFocus() end)
    parent.hiddenMenus[name]:SetScript("OnEditFocusGained", function() parent.hiddenMenus[name]:SetCursorPosition(0) end)
    parent.hiddenMenus[name]:Show()
end

function lib:generateSpellHover(frame, searchIn, textLines)
    frame:SetScript("OnEnter", function(self)
        local spells = {}
        for k in string.gmatch(searchIn, "|Hspell:(%d+)|h") do
            spells[#spells+1] = k
        end
        if #spells > 0 then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")

            if #spells == 1 then
                GameTooltip:SetHyperlink(lib:getSpellLinkById(spells[1]))
                GameTooltip:AddLine("id: "..spells[1].." "..lib:getSpellLinkByIdWithTexture(spells[1]), 1, 1, 1)
            else
                GameTooltip:SetHyperlink(lib:getSpellLinkById(spells[1]))
                for i=1,#spells do
                    GameTooltip:AddLine("id"..i..": "..spells[i].." "..lib:getSpellLinkByIdWithTexture(spells[i]), 1, 1, 1)
                end
            end

            if type(textLines) == "table" then
                for i=1,#textLines do
                    GameTooltip:AddLine(textLines[i], 1, 1, 1)
                end
            else
                GameTooltip:AddLine(textLines, 1, 1, 1)
            end

            GameTooltip:Show()
        end
    end)
    frame:SetScript("OnLeave", function() GameTooltip_Hide() end)
end

function lib:generateHover(frame, textLines)
    if not textLines then frame:SetScript("OnEnter", function() end) return end
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if type(textLines) == "table" then
            for i=1,#textLines do
                GameTooltip:AddLine(textLines[i], 1, 1, 1)
            end
        else
            GameTooltip:AddLine(textLines, 1, 1, 1)
        end
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip_Hide() end)
end

function lib:clearHover(frame)
    frame:SetScript("OnEnter", function() end)
    frame:SetScript("OnLeave", function() end)
end

function lib:updateScrollableTable(parent, maxHeight, topLeftPosition, rowsN, columnsN, createFn, updateFn)
    local maxWidth = lib:getTotalTableHeadersWidth(parent, columnsN) + 30

    local scroller = parent.scroller or lib:createScroller(parent, maxWidth, maxHeight, rowsN)
    if not parent.scroller then
        parent.scroller = scroller
    end

    for k=1,rowsN do
        if not parent.members[k] then
            local member = CreateFrame("Frame", nil, parent.scroller.scrollerChild)
            member:SetSize(parent.headers[1]:GetSize())
            member.column = {}
            if k > 1 then
                member:SetPoint("TOPLEFT", parent.members[k - 1], "BOTTOMLEFT", 0, -1)
            else
                member:SetPoint("TOPLEFT", parent.scroller.scrollerChild, "TOPLEFT", topLeftPosition.x, topLeftPosition.y)
            end

            for index=1,columnsN do
                member.column[index] = createFn(member, k, index)
                member.column[index].grandParent = member
            end

            table.insert(parent.members, member)
        else
            local member = parent.members[k]
            for index=1,columnsN do
                updateFn(member.column[index], k, index)
            end
            member:Show()
        end
    end

    lib:updateScroller(parent.scroller.slider, rowsN)

    if rowsN < #parent.members then
        for i=rowsN+1, #parent.members do
            parent.members[i]:Hide()
        end
    end
end
