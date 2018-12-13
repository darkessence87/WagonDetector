
WdLib = {}

WdLib.MAX_DROP_DOWN_MENUS = 25

function WdLib:CreateTimer(fn, delay, ...)
    local function executeFn(self) self.fn(unpack(self.args)) end

    local self = nil
    if delay > 0 then
        self = C_Timer_NewTicker(delay, executeFn, 1)
    else
        self = C_Timer_NewTicker(-delay, executeFn)
    end
    self.args = {...}
    self.fn = fn

    return self
end

function WdLib:StopTimer(self)
    if self then
        self:Cancel()
    end
end

function WdLib:RestartTimer(self, fn, delay, ...)
    WdLib:StopTimer(self)
    WdLib:CreateTimer(fn, delay, ...)
end

local function table_val_to_str(v)
    if "string" == type(v) then
        v = string.gsub(v, "\n", "\\n")
        if string.match(string.gsub(v,"[^'\"]",""), '^"+$') then
            return "'" .. v .. "'"
        end
        return '"' .. string.gsub(v,'"', '\\"' ) .. '"'
    else
        return "table" == type(v) and WdLib:table_tostring(v) or tostring(v)
    end
end

local function table_key_to_str(k)
    if "string" == type(k) and string.match( k, "^[_%a][_%a%d]*$") then
        return k
    else
        return "[" .. table_val_to_str(k) .. "]"
    end
end

local function make_border(f, cR, cG, cB, cA, size, offsetX, offsetY)
    offsetX = offsetX or 0
    offsetY = offsetY or 0

    f.bdTop = WdLib:createColorTexture(f, "BACKGROUND", cR, cG, cB, cA)
    f.bdTop:SetPoint("TOPLEFT", -size - offsetX, size + offsetY)
    f.bdTop:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", size + offsetX, offsetY)

    f.bdLeft = WdLib:createColorTexture(f, "BACKGROUND", cR, cG, cB, cA)
    f.bdLeft:SetPoint("TOPLEFT", -size - offsetX, offsetY)
    f.bdLeft:SetPoint("BOTTOMRIGHT", f, "BOTTOMLEFT", -offsetX, -offsetY)

    f.bdBottom = WdLib:createColorTexture(f, "BACKGROUND", cR, cG, cB, cA)
    f.bdBottom:SetPoint("BOTTOMLEFT", -size - offsetX, -size - offsetY)
    f.bdBottom:SetPoint("TOPRIGHT", f, "BOTTOMRIGHT", size + offsetX, -offsetY)

    f.bdRight = WdLib:createColorTexture(f, "BACKGROUND", cR, cG, cB, cA)
    f.bdRight:SetPoint("BOTTOMRIGHT", size + offsetX, offsetY)
    f.bdRight:SetPoint("TOPLEFT", f, "TOPRIGHT", offsetX, -offsetY)
end

local function createListButton(parent, name)
    local button = WdLib:createButton(parent)
    button.txt = WdLib:createFont(button, "LEFT", name)
    button.txt:SetPoint("LEFT", button, "LEFT", 5, 0)

    button.items = {}
    button.arrow = WdLib:createTexture(button, "Interface\\ChatFrame\\ChatFrameExpandArrow", "ARTWORK")
    button.arrow:SetSize(15, 15)
    button.arrow:SetPoint("RIGHT")
    return button
end

function WdLib:float_round_to(v, n)
    local mult = 10^n
    return math.floor(v * mult + 0.5) / mult
end

function WdLib:table_erase(t, predFn, resFn)
    local r = 0
    for i=1,#t do
        local v = t[i-r]
        if predFn(i,v) then
            resFn(i,v)
            table.remove(t, i-r)
            r = r + 1
        end
    end
end

function WdLib:table_wipe(t)
    for k in pairs(t) do
        t[k] = nil
    end
end

function WdLib:table_deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == "table" then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[WdLib:table_deepcopy(orig_key)] = WdLib:table_deepcopy(orig_value)
        end
        setmetatable(copy, WdLib:table_deepcopy(getmetatable(orig)))
    else
        copy = orig
    end
    return copy
end

function WdLib:string_totable(str)
    local t = {}
    str:gsub(".", function(c) table.insert(t,c) end)
    return t
end

function WdLib:table_tostring(tbl)
    if not tbl then return "nil" end
    local result, done = {}, {}
    for k, v in ipairs(tbl) do
        table.insert(result, table_val_to_str(v))
        done[k] = true
    end
    for k, v in pairs( tbl ) do
        if not done[k] then
            table.insert(result, table_key_to_str(k) .. "=" .. table_val_to_str(v) )
        end
    end
    return "{" .. table.concat(result, ",") .. "}"
end

function WdLib:table_tohtml(x)
    if type(x) ~= "table" then return "unsupported type" end

    local s = "<p>"
    for k,v in pairs(x) do
        s = s .. "|cffffff00" .. k .. "|r - " .. v .. "<br/>"
    end
    s = s .. "</p>"

    return s
end

local b="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
function WdLib:encode64(data)
    return ((data:gsub('.', function(x)
        local r,b='',x:byte()
        for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
        return r;
    end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c=0
        for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
        return b:sub(c+1,c+1)
    end)..({ '', '==', '=' })[#data%3+1])
end

function WdLib:decode64(data)
    data = string.gsub(data, '[^'..b..'=]', '')
    return (data:gsub('.', function(x)
        if (x == '=') then return '' end
        local r,f='',(b:find(x)-1)
        for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
        return r;
    end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
        if (#x ~= 8) then return '' end
        local c=0
        for i=1,8 do c=c+(x:sub(i,i)=='1' and 2^(8-i) or 0) end
        return string.char(c)
    end))
end

function WdLib:sendMessage(msg)
    local chatType = WD.db.profile.chat
    if not chatType or chatType == "PRINT" then
        print(msg)
    else
        SendChatMessage(msg, chatType, nil, 0)
    end
end

function WdLib:getSpellLinkById(id)
    local name = GetSpellInfo(id)
    if not name then return "Unknown" end
    return "|cff71d5ff|Hspell:"..id.."|h["..name.."]|h|r"
end

function WdLib:getSpellLinkByIdWithTexture(id)
    local name,_,icon = GetSpellInfo(id)
    if not name then return "Unknown" end
    return "|cff71d5ff|Hspell:"..id.."|h "..WdLib:getTextureLinkByPath(icon, 18).." "..name.."|h|r"
end

function WdLib:getTextureLinkByPath(path, sz)
    return "|T"..path..":"..(sz or 0).."|t"
end

function WdLib:getRaidTargetTextureLink(rt)
    return WdLib:getTextureLinkByPath("Interface\\TargetingFrame\\UI-RaidTargetingIcon_"..rt, 20)
end

function WdLib:getFullName(name)
    if not name then return nil end
    if string.find(name, "-[^-]*$") then
        return name;
    else
        return name .. "-" .. WD.CurrentRealmName;
    end
end

function WdLib:getShortName(name, noRealm)
    local dashIndex = string.find(name, "-[^-]*$")
    if not dashIndex then
        return name
    end

    if noRealm or WD.CurrentRealmName == string.sub(name, dashIndex + 1) then
        return string.sub(name, 1, dashIndex - 1)
    else
        return name
    end
end

function WdLib:getUnitNumber(name)
    local i = name:find("-[^-]*$")
    if not i then return nil end
    return tonumber(name:sub(i + 1))
end

function WdLib:createColorTexture(parent, level, r, g, b, a, blendMode)
    local t = parent:CreateTexture(nil, level)
    t:SetColorTexture(r, g, b, a)
    if blendMode then
        t:SetBlendMode(blendMode)
    end
    return t
end

function WdLib:createTexture(parent, file, level)
    local t = parent:CreateTexture(nil, level)
    t:SetTexture(file)
    t:SetTexCoord(0,1,0,1)
    return t
end

function WdLib:createFontDefault(parent, hJustify, name)
    local font = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    font:SetSize(parent:GetSize())
    font:SetJustifyH(hJustify)
    font:SetJustifyV("MIDDLE")
    font:SetText(name)
    return font
end

function WdLib:createFont(parent, hJustify, name)
    local font = WdLib:createFontDefault(parent, hJustify, name)
    parent:SetFontString(font)
    return font
end

function WdLib:createCheckButton(parent)
    local button = CreateFrame("CheckButton", nil, parent)
    button:SetSize(20,20)

    make_border(button, .24, .25, .3, 1, 1)

    button.t = WdLib:createColorTexture(button, "BACKGROUND", 0, 0, 0, .3)
    button.t:SetAllPoints()

    button.ct = WdLib:createTexture(button, "Interface\\Buttons\\UI-CheckBox-Check", "ARTWORK")
    button.ct:SetAllPoints()
    button:SetCheckedTexture(button.ct)

    button.h = WdLib:createColorTexture(button, "TEXTURE", 1, 1, 1, .3)
    button.h:SetAllPoints()
    button:SetHighlightTexture(button.h)

    return button
end

function WdLib:createButton(parent)
    local button = CreateFrame("Button", nil, parent)
    button:EnableMouse(true)
    button:RegisterForClicks("LeftButtonUp")

    button.t = WdLib:createColorTexture(button, "BACKGROUND", .2, .2, .2, 1)
    button.t:SetAllPoints()

    button.h = WdLib:createColorTexture(button, "BACKGROUND", 0, 1, 0, .2, "MOD")
    button.h:SetAllPoints()
    button:SetHighlightTexture(button.h)

    return button
end

function WdLib:createSliderButton(parent, direction, width)
    local button = CreateFrame("Frame", nil, parent)
    button:EnableMouse(false)
    button:SetSize(width - 31, 12)

    button.t = WdLib:createTexture(button, [[Interface\AddOns\WagonDetector\media\textures\border]], "ARTWORK")
    button.t:SetAllPoints()

    if direction == "UP" then
        button:SetPoint("TOPLEFT", parent, "TOPLEFT", 30, -1)
    elseif direction == "DOWN" then
        button:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 30, -1)
        button.t:SetRotation(3.14159265359)
    end

    return button
end

function WdLib:updateScroller(self, lines)
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

function WdLib:createScroller(parent, width, height, lines)
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

    scroller.slider.buttonUp = WdLib:createSliderButton(scroller, "UP", width)
    scroller.slider.buttonDown = WdLib:createSliderButton(scroller, "DOWN", width)

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

function WdLib:createXButton(parent, xOffset)
    local xButton = WdLib:createButton(parent)
    xButton:SetPoint("TOPRIGHT", parent, "TOPRIGHT", xOffset, 0)
    xButton:SetSize(15, 15)
    xButton:SetScript("OnClick", function() parent:Hide() end)
    xButton.t:SetTexture([[Interface\AddOns\WagonDetector\media\textures\cross_button]])
    xButton.t:SetTexCoord(0, 1, 0, 1)
    xButton.h:SetColorTexture(0, .5, 0, 1)
    return xButton
end

function WdLib:createListItemButton(parent, name, index)
    local button = WdLib:createButton(parent)
    button:SetPoint("TOPLEFT", parent, "TOPRIGHT", 1, index * -21)
    button:SetSize(175, 20)
    button.txt = WdLib:createFont(button, "LEFT", name)
    button.txt:SetPoint("LEFT", button, "LEFT", 5, 0)
    return button
end

function WdLib:createEditBox(parent)
    local input = CreateFrame("EditBox", nil, parent)
    input:EnableMouse(true)
    input:SetFrameStrata("DIALOG")
    input:SetAutoFocus(false)
    input:SetMaxLetters(50)
    input:SetJustifyH("CENTER")
    input:SetFontObject("GameFontNormal")
    input:SetHyperlinksEnabled(true)

    input.t = WdLib:createColorTexture(input, "BACKGROUND", .2, .2, .2, 1)
    input.t:SetAllPoints()
    return input
end

function WdLib:dropDownShow(self)
    if not self.items then return end
    for _,v in pairs(self.items) do
        if not v.locked then
            v:Show()
        end
    end
    self.isVisible = true

    if self.bg then
        self.bg:Show()
    end
end

function WdLib:dropDownHide(self)
    if not self.items then return end
    for _,v in pairs(self.items) do
        if v.items then
            WdLib:dropDownHide(v)
        end
        v:Hide()
    end
    self.isVisible = false

    if self.bg then
        self.bg:Hide()
    end
end

function WdLib:onClickDropDown(self, item, onClick)
    self.selected = item
    self.txt:SetText(item.txt:GetText())
    WdLib:dropDownHide(self)
    if onClick then
        onClick(self, item.data)
    end
end

function WdLib:updateDropDownMenu(self, name, items, parent)
    self.selected = nil
    self.txt:SetText(name)
    if #self.items > 0 then WdLib:dropDownHide(self) end

    if items and #items > 0 then
        if #items > WdLib.MAX_DROP_DOWN_MENUS then
            print("Too many drop frames requested")
            return
        end
        for i=1,#items do
            local v = items[i]
            if v.items then
                if not self.items[i] then
                    local item = WdLib:createDropDownMenu(self, v.name, v.items, parent)
                    item:SetSize(175, 20)
                    item:SetPoint("TOPLEFT", self, "TOPRIGHT", 1, (i - 1) * -21)
                    self.items[i] = item
                else
                    WdLib:updateDropDownMenu(self, v.name, v.items, parent)
                end
            else
                if not self.items[i] then
                    local item = WdLib:createListItemButton(self, v.name, i - 1)
                    self.items[i] = item
                end
                self.items[i].data = v
                self.items[i].txt:SetText(v.name)
                self.items[i]:SetScript("OnClick", function() WdLib:onClickDropDown(parent or self, self.items[i], v.func) end)
                if v.hover then
                    WdLib:generateHover(self.items[i], v.hover)
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

        local width = self.items[1]:GetWidth() + 2
        local height = #items * self.items[1]:GetHeight() + #items + 1
        if not self.bg then
            self.bg = WdLib:createColorTexture(self, "BACKGROUND", 0, 0, 0, 1)
        end
        self.bg:SetSize(width, height)
        self.bg:SetPoint("TOPLEFT", self, "TOPRIGHT", 0, 1)
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

    WdLib:dropDownHide(self)
end

function WdLib:resetDropDownMenu(self, name)
    self.selected = nil
    self.txt:SetText(name)
    WdLib:dropDownHide(self)
end

function WdLib:createDropDownMenu(parent, name, items, grandParent)
    local dropFrame = createListButton(parent, name)
    dropFrame:SetFrameStrata("TOOLTIP")
    dropFrame:SetScript("OnClick", function(self)
        local parent = self:GetParent()
        if self.isVisible then
            WdLib:dropDownHide(self)
        else
            WdLib:dropDownHide(parent)
            WdLib:dropDownShow(parent)
            WdLib:dropDownShow(self)
        end
        if parent.menus then
            for _,v in pairs(parent.menus) do
                if v ~= self then
                    WdLib:dropDownHide(v)
                end
            end
        end
        if parent.hiddenMenus then
            for _,v in pairs(parent.hiddenMenus) do
                if v ~= self then
                    WdLib:dropDownHide(v)
                end
            end
        end
    end)
    dropFrame:SetScript("OnHide", function() WdLib:resetDropDownMenu(dropFrame, name) end)
    dropFrame.items = {}

    WdLib:updateDropDownMenu(dropFrame, name, items, grandParent or dropFrame)
    WdLib:resetDropDownMenu(dropFrame, name)

    return dropFrame
end

function WdLib:findDropDownFrameByName(parent, name)
    for i=1,#parent.items do
        if parent.items[i].txt:GetText() == name then
            return parent.items[i]
        end

        if parent.items[i].items then
            local frame = WdLib:findDropDownFrameByName(parent.items[i], name)
            if frame then return frame end
        end
    end
    return nil
end

function WdLib:createTableHeader(self, name, x, y, xSize, ySize, onClick)
    local button = WdLib:createButton(self)
    button:EnableMouse(false)
    button:SetPoint("TOPLEFT", self, "TOPLEFT", x, y)
    button:SetSize(xSize, ySize)
    button.txt = WdLib:createFont(button, "CENTER", name)
    button.txt:SetSize(xSize, ySize)
    button.txt:SetPoint("LEFT", button, "LEFT", 0, 0)
    button.t:SetColorTexture(.5, .5, .5, 1)
    if onClick then button:EnableMouse(true); button:SetScript("OnClick", onClick) end
    return button
end

function WdLib:createTableHeaderNext(self, prev, name, xSize, ySize, onClick)
    local button = WdLib:createButton(self)
    button:EnableMouse(false)
    button:SetPoint("TOPLEFT", prev, "TOPRIGHT", 1, 0)
    button:SetSize(xSize, ySize)
    button.txt = WdLib:createFont(button, "CENTER", name)
    button.txt:SetSize(xSize, ySize)
    button.txt:SetPoint("LEFT", button, "LEFT", 0, 0)
    button.t:SetColorTexture(.5, .5, .5, 1)
    if onClick then button:EnableMouse(true); button:SetScript("OnClick", onClick) end
    return button
end

function WdLib:addNextColumn(self, parent, index, textOrientation, name)
    parent.column[index] = WdLib:createButton(parent)
    parent.column[index]:EnableMouse(false)
    parent.column[index]:SetSize(self.headers[index]:GetSize())
    if index > 1 then
        parent.column[index]:SetPoint("TOPLEFT", parent.column[index-1], "TOPRIGHT", 1, 0)
    end
    parent.column[index].t:SetColorTexture(.2, .2, .2, .5)
    parent.column[index].txt = WdLib:createFont(parent.column[index], textOrientation, name)
    if textOrientation == "LEFT" then
        parent.column[index].txt:SetPoint("LEFT", 5, 0)
    elseif textOrientation == "RIGHT" then
        parent.column[index].txt:SetPoint("RIGHT", -5, 0)
    else
        parent.column[index].txt:SetAllPoints()
    end
    return parent.column[index]
end

function WdLib:getTotalTableHeadersWidth(t, maxN)
    if not t or not t.headers or #t.headers < maxN then return 0 end
    local width = 0
    for i=1,maxN do
        width = width + t.headers[i]:GetWidth() + 1
    end
    return width - 1
end

function WdLib:convertTypesToItems(t, fn)
    local items = {}
    for i=1,#t do
        local item = { name = t[i], func = fn }
        table.insert(items, item)
    end
    return items
end

function WdLib:updateItemsByHoverInfo(needConversion, items, info, fn)
    if needConversion == true then
        items = WdLib:convertTypesToItems(items, fn)
    end
    for _,v in pairs(items) do
        if v.name and info[v.name] then
            v.hover = info[v.name]
        end
    end
    return items
end

function WdLib:createRuleWindow(parent)
    local r = CreateFrame("Frame", nil, parent)
    r.hiddenMenus = {}

    local totalWidth = 150
    local xSize = totalWidth - 2

    -- label
    r.label = WdLib:createFontDefault(r, "CENTER", "")
    r.label:SetSize(xSize, 20)
    r.label:SetPoint("TOPLEFT", r, "TOPLEFT", 1, -1)

    -- arg0
    r.hiddenMenus["arg0_edit"] = WdLib:createEditBox(r)
    r.hiddenMenus["arg0_edit"]:SetSize(xSize, 20)
    r.hiddenMenus["arg0_edit"]:SetPoint("TOPLEFT", r.label, "BOTTOMLEFT", 0, -1)
    r.hiddenMenus["arg0_edit"]:Hide()

    -- arg1
    r.hiddenMenus["arg1_edit"] = WdLib:createEditBox(r)
    r.hiddenMenus["arg1_edit"]:SetSize(xSize, 20)
    r.hiddenMenus["arg1_edit"]:SetPoint("TOPLEFT", r.hiddenMenus["arg0_edit"], "BOTTOMLEFT", 0, -1)
    r.hiddenMenus["arg1_edit"]:Hide()

    r.hiddenMenus["arg1_drop"] = WdLib:createDropDownMenu(r, "Select aura action", {{name = "apply"},{name = "remove"}})
    r.hiddenMenus["arg1_drop"].txt:SetJustifyH("CENTER")
    r.hiddenMenus["arg1_drop"]:SetSize(xSize, 20)
    r.hiddenMenus["arg1_drop"]:SetPoint("TOPLEFT", r.hiddenMenus["arg0_edit"], "BOTTOMLEFT", 0, -1)
    r.hiddenMenus["arg1_drop"]:Hide()

    r:SetScript("OnHide", function() for _,v in pairs(r.hiddenMenus) do v:Hide() end end)

    r:EnableMouse(true)
    r:SetSize(totalWidth, 3 * 21 + 1)
    r.bg = WdLib:createColorTexture(r, "TEXTURE", 0, 0, 0, 1)
    r.bg:SetAllPoints()

    r:Hide()

    return r
end

function WdLib:showHiddenEditBox(parent, name, txt)
    parent.hiddenMenus[name]:EnableMouse(true)
    parent.hiddenMenus[name]:SetText(txt)
    parent.hiddenMenus[name]:SetScript("OnEscapePressed", function() parent.hiddenMenus[name]:SetText(txt); parent.hiddenMenus[name]:ClearFocus() end)
    parent.hiddenMenus[name]:SetScript("OnEditFocusGained", function() parent.hiddenMenus[name]:SetCursorPosition(0) end)
    parent.hiddenMenus[name]:Show()
end

function WdLib:generateSpellHover(frame, searchIn, textLines)
    frame:SetScript("OnEnter", function(self)
        local spells = {}
        for k in string.gmatch(searchIn, "|Hspell:(%d+)|h") do
            spells[#spells+1] = k
        end
        if #spells > 0 then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")

            if #spells == 1 then
                GameTooltip:SetHyperlink(WdLib:getSpellLinkById(spells[1]))
                GameTooltip:AddLine("id: "..spells[1].." "..WdLib:getSpellLinkByIdWithTexture(spells[1]), 1, 1, 1)
            else
                GameTooltip:SetHyperlink(WdLib:getSpellLinkById(spells[1]))
                for i=1,#spells do
                    GameTooltip:AddLine("id"..i..": "..spells[i].." "..WdLib:getSpellLinkByIdWithTexture(spells[i]), 1, 1, 1)
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

function WdLib:generateHover(frame, textLines)
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

function WdLib:getColoredName(name, class)
    if class then
        local c = select(4, GetClassColor(class))
        return "|c"..c..name.."|r"
    end
    return name
end

function WdLib:getTimedDiff(startTime, endTime)
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

function WdLib:getTimedDiffShort(startTime, endTime)
    local dt = endTime - startTime
    local m = floor(dt / 60)
    dt = dt - m * 60
    local s = floor(dt)
    local MIN = string.format("%02d", m)
    local SEC = string.format("%02d", s)
    return MIN .. ":" .. SEC
end

function WdLib:getUnitName(unit)
    local name, realm = UnitName(unit)
    if not name then return UNKNOWNOBJECT end
    if not realm or realm == "" then
        realm = WD.CurrentRealmName
    end
    return name.."-"..realm
end

function WdLib:getNpcId(guid)
    return select(6, strsplit("-", guid))
end

function WdLib:updateScrollableTable(parent, maxHeight, topLeftPosition, rowsN, columnsN, createFn, updateFn)
    local maxWidth = WdLib:getTotalTableHeadersWidth(parent, columnsN) + 30

    local scroller = parent.scroller or WdLib:createScroller(parent, maxWidth, maxHeight, rowsN)
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

    WdLib:updateScroller(parent.scroller.slider, rowsN)

    if rowsN < #parent.members then
        for i=rowsN+1, #parent.members do
            parent.members[i]:Hide()
        end
    end
end

function WdLib:findEntityIndex(holder, guid)
    if not holder then return nil end
    for i=1,#holder do
        if holder[i] and holder[i].guid == guid then return i end
    end
    return nil
end
