
WdLib = {}

function WdLib:float_round_to(v, n)
    local mult = 10^n
    return math.floor(v * mult + 0.5) / mult
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

function WdLib:table_val_to_str(v)
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

function WdLib:table_key_to_str(k)
    if "string" == type(k) and string.match( k, "^[_%a][_%a%d]*$") then
        return k
    else
        return "[" .. WdLib:table_val_to_str(k) .. "]"
    end
end

function WdLib:table_tostring(tbl)
    local result, done = {}, {}
    for k, v in ipairs(tbl) do
        table.insert(result, WdLib:table_val_to_str(v))
        done[k] = true
    end
    for k, v in pairs( tbl ) do
        if not done[k] then
            table.insert(result, WdLib:table_key_to_str(k) .. "=" .. WdLib:table_val_to_str(v) )
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

function WdLib:isNonZero(text)
    if not tonumber(text) or tonumber(text) == 0 then return false end
    return true
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
    return "|cff71d5ff|Hspell:"..id.."|h "..WdLib:getTextureLinkByPath(icon, 20).." "..name.."|h|r"
end

function WdLib:getTextureLinkByPath(path, sz)
    return "|T"..path..":"..(sz or 0).."|t"
end

function WdLib:getRaidTargetTextureLink(rt)
    return WdLib:getTextureLinkByPath("Interface\\TargetingFrame\\UI-RaidTargetingIcon_"..rt, 20)
end

function WdLib:getFullCharacterName(name)
    if not name then return nil end
    if string.find(name, "%-") then
        return name;
    else
        return name .. "-" .. WD.CurrentRealmName;
    end
end

function WdLib:getShortCharacterName(name, noRealm)
    local dashIndex = string.find(name, "%-")
    if not dashIndex then
        return name
    end

    if noRealm or WD.CurrentRealmName == string.sub(name, dashIndex + 1) then
        return string.sub(name, 1, dashIndex - 1)
    else
        return name
    end
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

function WdLib:make_border(f, cR, cG, cB, cA, size, offsetX, offsetY)
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

    WdLib:make_border(button, .24, .25, .3, 1, 1)

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

function WdLib:createSliderButton(parent, direction)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(16, 16)
    button:EnableMouse(true)
    button:RegisterForClicks("LeftButtonUp")

    button.t = WdLib:createTexture(button, [[Interface\AddOns\WagonDetector\media\textures\scroll_arrow]], "ARTWORK")
    button.t:SetAllPoints()

    if direction == "UP" then
        button:SetPoint("TOP", parent, "TOP", 0, -2)
    elseif direction == "DOWN" then
        button:SetPoint("BOTTOM", parent, "BOTTOM", 0, 2)
        button.t:SetRotation(3.14)
    end

    return button
end

function WdLib:updateScroller(self, lines)
    local minV = 50

    local deltaLines = lines - (self:GetHeight() - minV) / 21
    local maxV = deltaLines * 21
    if maxV < minV then maxV = minV end

    self:SetMinMaxValues(minV, maxV)
end

function WdLib:createScroller(parent, width, height, lines)
    local minV = 50

    local deltaLines = lines - (height - minV) / 21
    local maxV = deltaLines * 21
    if maxV < minV then maxV = minV end

    local scroller = CreateFrame("ScrollFrame", nil, parent)
    scroller.slider = CreateFrame("Slider", nil, scroller)
    scroller.slider:SetOrientation("VERTICAL")
    scroller.slider:SetValueStep(21)
    scroller.slider.t = WdLib:createColorTexture(scroller.slider, "BACKGROUND", .2, .2, .2, .2)
    scroller.slider.t:SetAllPoints()

    scroller.slider.buttonUp = WdLib:createSliderButton(scroller.slider, "UP")
    scroller.slider.buttonUp:SetScript("OnClick", function() scroller.slider:SetValue(scroller.slider:GetValue()-1) end)
    scroller.slider.buttonDown = WdLib:createSliderButton(scroller.slider, "DOWN")
    scroller.slider.buttonDown:SetScript("OnClick", function() scroller.slider:SetValue(scroller.slider:GetValue()+1) end)

    scroller:SetScript("OnMouseWheel", function(self, delta)
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
    end)
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

function WdLib:createListButton(parent, name)
    local button = WdLib:createButton(parent)
    button.txt = WdLib:createFont(button, "LEFT", name)
    button.txt:SetPoint("LEFT", button, "LEFT", 5, 0)

    button.items = {}
    button.arrow = WdLib:createTexture(button, "Interface\\ChatFrame\\ChatFrameExpandArrow", "ARTWORK")
    button.arrow:SetSize(15, 15)
    button.arrow:SetPoint("RIGHT")
    return button
end

function WdLib:createListItemButton(parent, name, index)
    local button = WdLib:createButton(parent, name)
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
    for _,v in pairs(self.items) do v:Show() end
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
    if #self.items > 0 then WdLib:table_wipe(self.items) end
    if items then
        for k,v in pairs(items) do
            if v.items then
                local item = WdLib:createDropDownMenu(self, v.name, v.items, parent)
                item:SetSize(175, 20)
                item:SetPoint("TOPLEFT", self, "TOPRIGHT", 1, (k - 1) * -21)
                table.insert(self.items, item)
            else
                local item = WdLib:createListItemButton(self, v.name, k - 1)
                item.data = v
                item:SetScript("OnClick", function() WdLib:onClickDropDown(parent or self, item, v.func) end)
                if v.hover then
                    item:SetScript("OnEnter", function(self)
                        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        GameTooltip:SetText(v.hover, nil, nil, nil, nil, true)
                        GameTooltip:Show()
                    end)
                    item:SetScript("OnLeave", function() GameTooltip_Hide() end)
                end
                table.insert(self.items, item)
            end
        end
    end

    if #self.items > 1 then
        local width = self.items[1]:GetWidth() + 1
        local height = #self.items * self.items[1]:GetHeight()
        self.bg = WdLib:createColorTexture(self, "BACKGROUND", 0, 0, 0, 1)
        self.bg:SetSize(width, height)
        self.bg:SetPoint("TOPLEFT", self, "TOPRIGHT", 1, 0)
        self.bg:Hide()
    end

    WdLib:dropDownHide(self)
end

function WdLib:updateDropDownMenu(self, name)
    self.selected = nil
    self.txt:SetText(name)
    WdLib:dropDownHide(self)
end

function WdLib:createDropDownMenu(parent, name, items, grandParent)
    local dropFrame = WdLib:createListButton(parent, name)
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
    dropFrame:SetScript("OnHide", function() WdLib:updateDropDownMenu(dropFrame, name) end)
    dropFrame.items = {}

    WdLib:updateDropDownMenu(dropFrame, name, items, grandParent or dropFrame)
    WdLib:updateDropDownMenu(dropFrame, name)

    return dropFrame
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
end

function WdLib:convertTypesToItems(t, fn)
    local items = {}
    for i=1,#t do
        local item = { name = t[i], func = fn }
        table.insert(items, item)
    end
    return items
end

function WdLib:updateItemsByHoverInfo(items, info)
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

function WdLib:generateSpellHover(frame, searchIn)
    frame:SetScript("OnEnter", function(self)
        local _, _, spellId = string.find(searchIn, "|Hspell:(.+)|h ")
        if spellId then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(WdLib:getSpellLinkById(spellId))
            GameTooltip:AddLine('id: '..spellId, 1, 1, 1)
            GameTooltip:Show()
        end
    end)
    frame:SetScript("OnLeave", function() GameTooltip_Hide() end)
end

function WdLib:generateHover(frame, text)
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(text, 1, 1, 1)
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
