
local WDHP = nil

function WD:InitHelpModule(parent)
    WDHP = parent
    
    WDHP.mainPage = CreateFrame("SimpleHTML", nil, WDHP)
    WDHP.mainPage:SetSize(WDHP:GetWidth() - 20, WDHP:GetHeight() - 20)
    WDHP.mainPage:SetPoint("TOPLEFT", WDHP, "TOPLEFT", 10, -10)
    
    WDHP.mainPage:SetFont("Fonts\\FRIZQT__.TTF", 11);
    WDHP.mainPage:SetText("\
        <html><body>\
        <h1>Current version: "..WD.version.."</h1>\
        <p>TBD</p>\
        </body></html>"
    );
    
    WDHP.t = createColorTexture(WDHP.mainPage, "BACKGROUND", .15, .15, .15, 1)
    WDHP.t:SetAllPoints()

    function WDHP:OnUpdate()
    end
end
