-- UI_CopyView.lua
-- 查看原始消息的弹窗

function HCDR_CreateCopyFrame()
    HCDR_CopyFrame = CreateFrame("Frame", "HCDR_CopyFrame", UIParent)
    HCDR_CopyFrame:SetFrameStrata("DIALOG")
    HCDR_CopyFrame:SetToplevel(true)
    HCDR_CopyFrame:SetWidth(600)
    HCDR_CopyFrame:SetHeight(150)
    HCDR_CopyFrame:SetPoint("CENTER", 0, 0)
    HCDR_CopyFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    HCDR_CopyFrame:SetMovable(true)
    HCDR_CopyFrame:EnableMouse(true)
    HCDR_CopyFrame:RegisterForDrag("LeftButton")
    HCDR_CopyFrame:SetScript("OnDragStart", function() 
        HCDR_CopyFrame:StartMoving() 
    end)
    HCDR_CopyFrame:SetScript("OnDragStop", function() 
        HCDR_CopyFrame:StopMovingOrSizing() 
    end)
    HCDR_CopyFrame:Hide()
    
    -- 标题
    local CopyTitleText = HCDR_CopyFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    CopyTitleText:SetPoint("TOP", 0, -15)
    CopyTitleText:SetText("|cFFFFD700查看原始死亡消息|r")
    
    -- 关闭按钮
    local CopyCloseButton = CreateFrame("Button", "HCDR_CopyCloseButton", HCDR_CopyFrame, "UIPanelCloseButton")
    CopyCloseButton:SetPoint("TOPRIGHT", HCDR_CopyFrame, "TOPRIGHT", -7, -7)
    CopyCloseButton:SetScript("OnClick", function()
        HCDR_CopyFrame:Hide()
    end)
    
    -- 创建多行编辑框
    HCDR_CopyEditBox = CreateFrame("EditBox", "HCDR_CopyEditBox", HCDR_CopyFrame)
    HCDR_CopyEditBox:SetWidth(550)
    HCDR_CopyEditBox:SetHeight(120)
    HCDR_CopyEditBox:SetMultiLine(true)
    HCDR_CopyEditBox:SetAutoFocus(false)
    HCDR_CopyEditBox:SetPoint("TOP", 0, -40)
    HCDR_CopyEditBox:SetFontObject(GameFontHighlight)
    HCDR_CopyEditBox:SetScript("OnEscapePressed", function() 
        this:ClearFocus() 
    end)
    
    -- 全选按钮
    local CopyButton = CreateFrame("Button", nil, HCDR_CopyFrame, "UIPanelButtonTemplate")
    CopyButton:SetWidth(100)
    CopyButton:SetHeight(22)
    CopyButton:SetPoint("BOTTOMLEFT", 100, 20)
    CopyButton:SetText("全选")
    CopyButton:SetScript("OnClick", function()
        HCDR_CopyEditBox:SetFocus()
        HCDR_CopyEditBox:HighlightText()
    end)
    
    -- 关闭按钮
    local CloseCopyButton = CreateFrame("Button", nil, HCDR_CopyFrame, "UIPanelButtonTemplate")
    CloseCopyButton:SetWidth(100)
    CloseCopyButton:SetHeight(22)
    CloseCopyButton:SetPoint("BOTTOMRIGHT", -100, 20)
    CloseCopyButton:SetText("关闭")
    CloseCopyButton:SetScript("OnClick", function()
        HCDR_CopyFrame:Hide()
    end)
end

-- 复制到剪贴板（显示弹窗）
function HCDR_CopyToClipboard(text)
    if HCDR_CopyFrame and HCDR_CopyEditBox then
        HCDR_CopyFrame:Show()
        HCDR_CopyEditBox:SetText(text)
        HCDR_CopyEditBox:SetFocus()
        HCDR_CopyEditBox:HighlightText()
    end
end

-- 初始化复制框架
HCDR_CreateCopyFrame()
