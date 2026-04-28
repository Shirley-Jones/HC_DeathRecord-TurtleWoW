-- UI_Main.lua
-- 主界面：表格、分页、搜索、等级筛选

-- 搜索相关函数
function HCDR_SearchEditBox_OnEscapePressed()
    HCDR_SearchEditBox:ClearFocus()
end

function HCDR_SearchEditBox_OnEnterPressed()
    local searchText = HCDR_SearchEditBox:GetText()
    HCDR_SearchEditBox:ClearFocus()
    HCDR_PerformSearch(searchText)
end

function HCDR_SearchEditBox_OnEditFocusLost()
    -- 什么都不做，避免递归调用
end

function HCDR_PerformSearch(searchText)
    searchText = strtrim(searchText or "")
    HCDR_SearchTerm = searchText
    HCDR_IsSearching = (searchText ~= "")
    
    HCDR_CurrentPage = 1
    HCDR_UpdateDisplay()
end

-- 创建主框架
function HCDR_CreateMainFrame()
    HCDR_Frame = CreateFrame("Frame", "HCDR_Frame", UIParent)
    HCDR_Frame:SetWidth(1020)
    HCDR_Frame:SetHeight(420)
    HCDR_Frame:SetPoint("CENTER", 0, 0)
    HCDR_Frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    HCDR_Frame:SetMovable(true)
    HCDR_Frame:EnableMouse(true)
    HCDR_Frame:RegisterForDrag("LeftButton")
    HCDR_Frame:SetScript("OnDragStart", function() 
        HCDR_Frame:StartMoving() 
    end)
    HCDR_Frame:SetScript("OnDragStop", function() 
        HCDR_Frame:StopMovingOrSizing() 
    end)
    
    -- 关闭按钮
    local CloseButton = CreateFrame("Button", "HCDR_CloseButton", HCDR_Frame, "UIPanelCloseButton")
    CloseButton:SetPoint("TOPRIGHT", HCDR_Frame, "TOPRIGHT", -7, -7)
    CloseButton:SetScript("OnClick", function()
        HCDR_Frame:Hide()
    end)
    
    -- 标题
    local TitleText = HCDR_Frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    TitleText:SetPoint("TOP", 0, -20)
    TitleText:SetText("硬核模式死亡讣告")
    
    -- 搜索区域
    HCDR_CreateSearchArea()
    
    -- 等级筛选区域
    HCDR_CreateLevelFilterArea()
    
    -- 表格标题
    HCDR_CreateTableHeaders()
    
    -- 数据行
    HCDR_CreateDataRows()
    
    -- 分页控件
    HCDR_CreatePagination()
    
    -- 底部按钮
    HCDR_CreateBottomButtons()
    
    HCDR_Frame:Hide()
end

function HCDR_CreateSearchArea()
    -- 搜索输入框
    HCDR_SearchEditBox = CreateFrame("EditBox", "HCDR_SearchEditBox", HCDR_Frame, "InputBoxTemplate")
    HCDR_SearchEditBox:SetWidth(140)
    HCDR_SearchEditBox:SetHeight(20)
    HCDR_SearchEditBox:SetPoint("TOPRIGHT", -220, -20)
    HCDR_SearchEditBox:SetAutoFocus(false)
    HCDR_SearchEditBox:SetText("")
    HCDR_SearchEditBox:SetScript("OnEscapePressed", HCDR_SearchEditBox_OnEscapePressed)
    HCDR_SearchEditBox:SetScript("OnEnterPressed", HCDR_SearchEditBox_OnEnterPressed)
    HCDR_SearchEditBox:SetScript("OnEditFocusLost", HCDR_SearchEditBox_OnEditFocusLost)
    
    -- 搜索按钮
    local SearchButton = CreateFrame("Button", nil, HCDR_Frame, "UIPanelButtonTemplate")
    SearchButton:SetWidth(55)
    SearchButton:SetHeight(22)
    SearchButton:SetPoint("RIGHT", HCDR_SearchEditBox, "RIGHT", 60, 0)
    SearchButton:SetText("搜索")
    SearchButton:SetScript("OnClick", function()
        HCDR_SearchEditBox:ClearFocus()
        HCDR_PerformSearch(HCDR_SearchEditBox:GetText())
    end)
    
    -- 清除搜索按钮
    local ClearSearchButton = CreateFrame("Button", nil, HCDR_Frame, "UIPanelButtonTemplate")
    ClearSearchButton:SetWidth(90)
    ClearSearchButton:SetHeight(22)
    ClearSearchButton:SetPoint("RIGHT", HCDR_SearchEditBox, "RIGHT", 155, 0)
    ClearSearchButton:SetText("清除搜索")
    ClearSearchButton:SetScript("OnClick", function()
        HCDR_SearchEditBox:SetText("")
        HCDR_SearchTerm = ""
        HCDR_IsSearching = false
        HCDR_CurrentPage = 1
        HCDR_UpdateDisplay()
    end)
    
    local SearchHintsText = HCDR_Frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    SearchHintsText:SetPoint("TOPRIGHT", -250, -40)
    SearchHintsText:SetText("支持模糊搜索")
end

function HCDR_CreateLevelFilterArea()
    local LevelFilterFrame = CreateFrame("Frame", "HCDR_LevelFilterFrame", HCDR_Frame)
    LevelFilterFrame:SetWidth(400)
    LevelFilterFrame:SetHeight(60)
    LevelFilterFrame:SetPoint("TOPLEFT", HCDR_Frame, "TOPLEFT", 10, -18)
    
    HCDR_LevelFilterButtons = {}
    local ranges = HCDR_LevelRanges
    
    local function CreateLevelFilterButton(i, range, xOffset, yOffset)
        local button = CreateFrame("CheckButton", "HCDR_LevelFilter"..i, LevelFilterFrame, "UICheckButtonTemplate")
        button:SetWidth(20)
        button:SetHeight(20)
        button:SetPoint("TOPLEFT", LevelFilterFrame, "TOPLEFT", xOffset, yOffset)
        button.range = range
        
        local text = LevelFilterFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        text:SetPoint("LEFT", button, "RIGHT", 2, 0)
        text:SetText(range.text)
        
        button:SetScript("OnClick", function()
            HCDR_LevelFilterButton_OnClick(button)
        end)
        
        HCDR_LevelFilterButtons[i] = button
        return button
    end
    
    -- 第一行
    CreateLevelFilterButton(1, ranges[1], 10, 0)   -- 1-10
    CreateLevelFilterButton(2, ranges[2], 65, 0)  -- 10-20
    CreateLevelFilterButton(3, ranges[3], 130, 0) -- 20-30
    CreateLevelFilterButton(4, ranges[4], 200, 0) -- 30-40
    CreateLevelFilterButton(5, ranges[5], 10, -20) -- 40-50
    CreateLevelFilterButton(6, ranges[6], 85, -20) -- 50-60
    CreateLevelFilterButton(7, ranges[7], 160, -20) -- 全部
    
    -- 默认选中"全部"
    HCDR_LevelFilterButtons[7]:SetChecked(true)
    HCDR_CurrentLevelFilter = ranges[7]
end

function HCDR_LevelFilterButton_OnClick(button)
    if button:GetChecked() then
        for i, btn in ipairs(HCDR_LevelFilterButtons) do
            if btn ~= button then
                btn:SetChecked(0)
            end
        end
        HCDR_CurrentLevelFilter = button.range
    else
        button:SetChecked(1)
    end
    HCDR_UpdateDisplay()
end

function HCDR_CreateTableHeaders()
    local function CreateColumnHeader(text, xOffset)
        local header = HCDR_Frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        header:SetPoint("TOPLEFT", 50 + xOffset, -80)
        header:SetText(text)
        return header
    end
    CreateColumnHeader("角色名字", 30)
    CreateColumnHeader("死亡类型", 155)
    CreateColumnHeader("被谁击杀", 300)
    CreateColumnHeader("死亡区域", 500)
    CreateColumnHeader("死亡时间", 670)
    CreateColumnHeader("操作", 850)
    
    local Line = HCDR_Frame:CreateTexture(nil, "ARTWORK")
    Line:SetWidth(750)
    Line:SetHeight(2)
    Line:SetPoint("TOP",  0, -75)
    Line:SetTexture("Interface\\Tooltips\\UI-Tooltip-BBorder")
    Line:SetTexCoord(0, 1, 0, 0.125)
end

function HCDR_CreateDataRows()
    HCDR_DataRows = {}
    for i = 1, 10 do
        local row = {
            charName = HCDR_Frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"),
            deathType = HCDR_Frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"),
            killer = HCDR_Frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"),
            zone = HCDR_Frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"),
            time = HCDR_Frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"),
            whisperBtn = CreateFrame("Button", "HCDR_WhisperBtn"..i, HCDR_Frame, "UIPanelButtonTemplate"),
            deleteBtn = CreateFrame("Button", "HCDR_DeleteBtn"..i, HCDR_Frame, "UIPanelButtonTemplate"),
            copyBtn = CreateFrame("Button", "HCDR_CopyBtn"..i, HCDR_Frame, "UIPanelButtonTemplate")  
        }
        
        local yPos = -85 - (i * 25)
        row.charName:SetPoint("TOPLEFT", 30, yPos)
        row.deathType:SetPoint("TOPLEFT", 220, yPos)
        row.killer:SetPoint("TOPLEFT", 300, yPos)
        row.zone:SetPoint("TOPLEFT", 520, yPos)
        row.time:SetPoint("TOPLEFT", 670, yPos)
        
        row.whisperBtn:SetWidth(50)
        row.whisperBtn:SetHeight(20)
        row.whisperBtn:SetPoint("TOPLEFT", 840, yPos - 2)
        row.whisperBtn:SetText("私聊")
        
        row.deleteBtn:SetWidth(50)
        row.deleteBtn:SetHeight(20)
        row.deleteBtn:SetPoint("TOPLEFT", 890, yPos - 2)
        row.deleteBtn:SetText("删除")
        
        row.copyBtn:SetWidth(50)
        row.copyBtn:SetHeight(20)
        row.copyBtn:SetPoint("TOPLEFT", 940, yPos - 2)
        row.copyBtn:SetText("查看")
        
        row.whisperBtn:Hide()
        row.deleteBtn:Hide()
        row.copyBtn:Hide()
        
        row.charName:SetText("")
        row.deathType:SetText("")
        row.killer:SetText("")
        row.zone:SetText("")
        row.time:SetText("")
        
        HCDR_DataRows[i] = row
    end
end

function HCDR_CreatePagination()
    -- 首页
    HCDR_FirstPageButton = CreateFrame("Button", nil, HCDR_Frame, "UIPanelButtonTemplate")
    HCDR_FirstPageButton:SetWidth(60)
    HCDR_FirstPageButton:SetHeight(22)
    HCDR_FirstPageButton:SetPoint("BOTTOMLEFT", 250, 20)
    HCDR_FirstPageButton:SetText("首页")
    HCDR_FirstPageButton:Disable()
    HCDR_FirstPageButton:SetScript("OnClick", function()
        if HCDR_CurrentPage > 1 then
            HCDR_CurrentPage = 1
            HCDR_UpdateDisplay()
        end
    end)
    
    -- 上一页
    HCDR_PrevButton = CreateFrame("Button", nil, HCDR_Frame, "UIPanelButtonTemplate")
    HCDR_PrevButton:SetWidth(60)
    HCDR_PrevButton:SetHeight(22)
    HCDR_PrevButton:SetPoint("LEFT", HCDR_FirstPageButton, "RIGHT", 10, 0)
    HCDR_PrevButton:SetText("上一页")
    HCDR_PrevButton:Disable()
    HCDR_PrevButton:SetScript("OnClick", function()
        if HCDR_CurrentPage > 1 then
            HCDR_CurrentPage = HCDR_CurrentPage - 1
            HCDR_UpdateDisplay()
        end
    end)
    
    -- 页码显示
    local PagePrefixText = HCDR_Frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    PagePrefixText:SetPoint("BOTTOM", -110, 25)
    PagePrefixText:SetText("第")
    
    HCDR_PageEditBox = CreateFrame("EditBox", "HCDR_PageEditBox", HCDR_Frame, "InputBoxTemplate")
    HCDR_PageEditBox:SetWidth(60)
    HCDR_PageEditBox:SetHeight(20)
    HCDR_PageEditBox:SetPoint("LEFT", PagePrefixText, "RIGHT", 10, 0)
    HCDR_PageEditBox:SetAutoFocus(false)
    HCDR_PageEditBox:SetNumeric(true)
    HCDR_PageEditBox:SetMaxLetters(4)
    HCDR_PageEditBox:SetText("1")
    HCDR_PageEditBox:SetScript("OnEscapePressed", function()
        this:ClearFocus()
    end)
    HCDR_PageEditBox:SetScript("OnEnterPressed", function()
        this:ClearFocus()
        local pageNum = tonumber(this:GetText()) or 1
        local filteredData = HCDR_GetFilteredData()
        local totalEntries = table.getn(filteredData)
        local totalPages = totalEntries > 0 and math.ceil(totalEntries / 10) or 1
        
        if pageNum < 1 then pageNum = 1 end
        if pageNum > totalPages then pageNum = totalPages end
        
        HCDR_CurrentPage = pageNum
        HCDR_UpdateDisplay()
    end)
    HCDR_PageEditBox:SetScript("OnEditFocusLost", function()
        local pageNum = tonumber(this:GetText()) or 1
        local filteredData = HCDR_GetFilteredData()
        local totalEntries = table.getn(filteredData)
        local totalPages = totalEntries > 0 and math.ceil(totalEntries / 10) or 1
        
        if pageNum < 1 then pageNum = 1 end
        if pageNum > totalPages then pageNum = totalPages end
        
        this:SetText(tostring(pageNum))
        HCDR_CurrentPage = pageNum
        HCDR_UpdateDisplay()
    end)
    
    HCDR_PageSuffixText = HCDR_Frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    HCDR_PageSuffixText:SetPoint("LEFT", HCDR_PageEditBox, "RIGHT", 5, 0)
    HCDR_PageSuffixText:SetText("页 / 总 x 页")
    
    -- 下一页
    HCDR_NextButton = CreateFrame("Button", nil, HCDR_Frame, "UIPanelButtonTemplate")
    HCDR_NextButton:SetWidth(60)
    HCDR_NextButton:SetHeight(22)
    HCDR_NextButton:SetPoint("BOTTOMRIGHT", -350, 20)
    HCDR_NextButton:SetText("下一页")
    HCDR_NextButton:SetScript("OnClick", function()
        local filteredData = HCDR_GetFilteredData()
        local totalEntries = table.getn(filteredData)
        local totalPages = totalEntries > 0 and math.ceil(totalEntries / 10) or 1
        if HCDR_CurrentPage < totalPages then
            HCDR_CurrentPage = HCDR_CurrentPage + 1
            HCDR_UpdateDisplay()
        end
    end)
    
    -- 尾页
    HCDR_LastPageButton = CreateFrame("Button", nil, HCDR_Frame, "UIPanelButtonTemplate")
    HCDR_LastPageButton:SetWidth(60)
    HCDR_LastPageButton:SetHeight(22)
    HCDR_LastPageButton:SetPoint("LEFT", HCDR_NextButton, "RIGHT", 10, 0)
    HCDR_LastPageButton:SetText("尾页")
    HCDR_LastPageButton:SetScript("OnClick", function()
        local filteredData = HCDR_GetFilteredData()
        local totalEntries = table.getn(filteredData)
        local totalPages = totalEntries > 0 and math.ceil(totalEntries / 10) or 1
        if HCDR_CurrentPage < totalPages then
            HCDR_CurrentPage = totalPages
            HCDR_UpdateDisplay()
        end
    end)
end

function HCDR_CreateBottomButtons()
    -- 设置按钮
    local OpenSettingsButton = CreateFrame("Button", nil, HCDR_Frame, "UIPanelButtonTemplate")
    OpenSettingsButton:SetWidth(60)
    OpenSettingsButton:SetHeight(22)
    OpenSettingsButton:SetPoint("BOTTOMLEFT", 20, 20)
    OpenSettingsButton:SetText("设置")
    OpenSettingsButton:SetScript("OnClick", function()
        HCDR_Frame:Hide()
        if HCDR_SettingsFrame then
            HCDR_SettingsFrame:Show()
        end
    end)
    
    -- 删除所有数据按钮
    local DeleteAllButton = CreateFrame("Button", nil, HCDR_Frame, "UIPanelButtonTemplate")
    DeleteAllButton:SetWidth(120)
    DeleteAllButton:SetHeight(22)
    DeleteAllButton:SetPoint("BOTTOMLEFT", 90, 20)
    DeleteAllButton:SetText("删除所有数据")
    DeleteAllButton:SetScript("OnClick", function()
        StaticPopup_Show("HCDR_CONFIRM_DELETE_ALL")
    end)
    
    -- 作者信息
    local AuthorText = HCDR_Frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	AuthorText:SetTextColor(1, 0.5, 0)  -- 橙色文字，更显眼
    AuthorText:SetPoint("BOTTOMRIGHT", -40, 25)
    AuthorText:SetText("by Shirley.")
end

-- 更新显示
function HCDR_UpdateDisplay()
    if not HCDR_Frame or not HCDR_DataRows then return end
    
    local filteredData = HCDR_GetFilteredData()
    local totalEntries = table.getn(filteredData)
    local totalPages = totalEntries > 0 and math.ceil(totalEntries / 10) or 1
    
    -- 更新分页文本
    if HCDR_IsSearching and HCDR_SearchTerm ~= "" then
        HCDR_PageSuffixText:SetText("页 / 总 "..totalPages.." 页 (搜索中)")
    else
        HCDR_PageSuffixText:SetText("页 / 总 "..totalPages.." 页")
    end
    
    HCDR_PageEditBox:SetText(tostring(HCDR_CurrentPage))
    
    -- 按钮状态
    if HCDR_CurrentPage <= 1 then
        HCDR_FirstPageButton:Disable()
        HCDR_PrevButton:Disable()
    else
        HCDR_FirstPageButton:Enable()
        HCDR_PrevButton:Enable()
    end
    
    if HCDR_CurrentPage >= totalPages then
        HCDR_NextButton:Disable()
        HCDR_LastPageButton:Disable()
    else
        HCDR_NextButton:Enable()
        HCDR_LastPageButton:Enable()
    end
    
    -- 填充数据行
    local startIndex = (HCDR_CurrentPage - 1) * 10 + 1
    local endIndex = math.min(startIndex + 9, totalEntries)
    
    for i = 1, 10 do
        local dataIndex = startIndex + i - 1
        local row = HCDR_DataRows[i]
        
        if dataIndex <= totalEntries then
            local data = filteredData[dataIndex]
            row.charName:SetText((data.charName or "") .. " (等级 " .. (data.level or 0) .. ")")
            row.deathType:SetText(data.deathType or "")
            row.killer:SetText(data.killer or "")
            row.zone:SetText(data.zone or "")
            row.time:SetText(data.time and HCDR_FormatTime(data.time) or "")
            
            row.whisperBtn:Show()
            row.deleteBtn:Show()
            row.copyBtn:Show()
            
            -- 查看按钮
            row.copyBtn:SetScript("OnClick", function()
                if data.rawMessage then
                    HCDR_CopyToClipboard(data.rawMessage)
                else
                    DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99硬核模式死亡讣告|r：错误，没有保存原始死亡消息")
                end
            end)
            
            -- 私聊按钮
            row.whisperBtn:SetScript("OnClick", function()
                local nameWithLevel = data.charName or ""
                local pureName = nameWithLevel
                local pos = string.find(pureName, "%(")
                if pos then
                    pureName = string.sub(pureName, 1, pos - 1)
                end
                pureName = strtrim(pureName)
                ChatFrame_SendTell(pureName)
            end)
            
            -- 删除按钮
            row.deleteBtn:SetScript("OnClick", function()
                local realmKey = HCDR_GetRealmKey()
                local serverData = HCDR_Data[realmKey] or {}
                for j, originalData in ipairs(serverData) do
                    if originalData == data then
                        table.remove(serverData, j)
                        break
                    end
                end
                
                if HCDR_CurrentPage > 1 and table.getn(filteredData) <= (HCDR_CurrentPage - 1) * 10 then
                    HCDR_CurrentPage = HCDR_CurrentPage - 1
                end
                
                HCDR_UpdateDisplay()
            end)
        else
            row.charName:SetText("")
            row.deathType:SetText("")
            row.killer:SetText("")
            row.zone:SetText("")
            row.time:SetText("")
            row.whisperBtn:Hide()
            row.deleteBtn:Hide()
            row.copyBtn:Hide()
        end
    end
end

-- 初始化主界面
HCDR_CreateMainFrame()
