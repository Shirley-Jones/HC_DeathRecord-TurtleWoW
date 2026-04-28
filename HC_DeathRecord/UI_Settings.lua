-- UI_Settings.lua
-- 设置界面

function HCDR_CreateSettingsFrame()
    HCDR_SettingsFrame = CreateFrame("Frame", "HCDR_SettingsFrame", UIParent)
    HCDR_SettingsFrame:SetFrameStrata("DIALOG")
    HCDR_SettingsFrame:SetToplevel(true)
    HCDR_SettingsFrame:SetWidth(650)
    HCDR_SettingsFrame:SetHeight(330)
    HCDR_SettingsFrame:SetPoint("CENTER", 0, 0)
    HCDR_SettingsFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    HCDR_SettingsFrame:SetMovable(true)
    HCDR_SettingsFrame:EnableMouse(true)
    HCDR_SettingsFrame:RegisterForDrag("LeftButton")
    HCDR_SettingsFrame:SetScript("OnDragStart", function() 
        HCDR_SettingsFrame:StartMoving() 
    end)
    HCDR_SettingsFrame:SetScript("OnDragStop", function() 
        HCDR_SettingsFrame:StopMovingOrSizing() 
    end)
    HCDR_SettingsFrame:Hide()
    
    -- 标题
    local SettingsTitle = HCDR_SettingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    SettingsTitle:SetPoint("TOP", 0, -15)
    SettingsTitle:SetText("硬核模式死亡讣告 - 设置")
    
    -- 关闭按钮
    local SettingsCloseButton = CreateFrame("Button", "HCDR_SettingsCloseButton", HCDR_SettingsFrame, "UIPanelCloseButton")
    SettingsCloseButton:SetPoint("TOPRIGHT", HCDR_SettingsFrame, "TOPRIGHT", -7, -7)
    SettingsCloseButton:SetScript("OnClick", function()
        HCDR_SettingsFrame:Hide()
    end)
    
    -- 创建各个设置部件
    HCDR_CreateFeastSettings()
    HCDR_CreateCondolenceSettings()
    HCDR_CreateCooldownSettings()
    HCDR_CreateMessageReceiveSettings()
    HCDR_CreateCustomTextSettings()
	HCDR_CreateBottomReminder()
    
    -- 设置界面显示时的初始化
    HCDR_SettingsFrame:SetScript("OnShow", HCDR_SettingsFrame_OnShow)
end

function HCDR_CreateFeastSettings()
    -- 自动吃席复选框
    HCDR_AutoSendCheckbox = CreateFrame("CheckButton", "HCDR_AutoSendCheckbox", HCDR_SettingsFrame, "UICheckButtonTemplate")
    HCDR_AutoSendCheckbox:SetWidth(20)
    HCDR_AutoSendCheckbox:SetHeight(20)
    HCDR_AutoSendCheckbox:SetPoint("TOPLEFT", 20, -45)
    HCDR_AutoSendCheckbox:SetScript("OnClick", function()
        local realmKey = HCDR_GetRealmKey()
        local isChecked = this:GetChecked() and true or false
        if isChecked then
            StaticPopup_Show("HCDR_CONFIRM_FEAST")
        else
            HCDR_Settings[realmKey].autoSendFeast = isChecked
        end
    end)
    
    local AutoSendText = HCDR_SettingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    AutoSendText:SetPoint("LEFT", HCDR_AutoSendCheckbox, "RIGHT", 5, 0)
    AutoSendText:SetText("自动吃席")
    
    -- 吃席等级
    HCDR_FeastLevelEditBox = CreateFrame("EditBox", "HCDR_FeastLevelEditBox", HCDR_SettingsFrame, "InputBoxTemplate")
    HCDR_FeastLevelEditBox:SetWidth(20)
    HCDR_FeastLevelEditBox:SetHeight(20)
    HCDR_FeastLevelEditBox:SetPoint("LEFT", AutoSendText, "RIGHT", 10, 0)
    HCDR_FeastLevelEditBox:SetAutoFocus(false)
    HCDR_FeastLevelEditBox:SetNumeric(true)
    HCDR_FeastLevelEditBox:SetMaxLetters(2)
    HCDR_FeastLevelEditBox:SetText("60")
    HCDR_SetupLevelEditBox(HCDR_FeastLevelEditBox, "feastMinLevel")
    
    local FeastLevelText = HCDR_SettingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    FeastLevelText:SetPoint("LEFT", HCDR_FeastLevelEditBox, "RIGHT", 5, 0)
    FeastLevelText:SetText("级及以上")
    
    local ChannelSelectionText = HCDR_SettingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ChannelSelectionText:SetPoint("LEFT", FeastLevelText, "RIGHT", 0, 0)
    ChannelSelectionText:SetText("并发送到")
    
    -- 频道下拉框
    HCDR_ChannelDropdown = CreateFrame("Frame", "HCDR_ChannelDropdown", HCDR_SettingsFrame, "UIDropDownMenuTemplate")
    HCDR_ChannelDropdown:SetPoint("LEFT", ChannelSelectionText, "RIGHT", -10, -2)
    HCDR_ChannelDropdown:SetWidth(150)
    -- 移除立即初始化，延迟到设置界面显示时
    -- UIDropDownMenu_Initialize(HCDR_ChannelDropdown, HCDR_InitializeChannelDropdown)
    
    -- 是否艾特对方
    HCDR_ShouldAtCheckbox = CreateFrame("CheckButton", "HCDR_ShouldAtCheckbox", HCDR_SettingsFrame, "UICheckButtonTemplate")
    HCDR_ShouldAtCheckbox:SetWidth(20)
    HCDR_ShouldAtCheckbox:SetHeight(20)
    HCDR_ShouldAtCheckbox:SetPoint("TOPLEFT", 420, -45)
    HCDR_ShouldAtCheckbox:SetScript("OnClick", function()
        local realmKey = HCDR_GetRealmKey()
        local isChecked = this:GetChecked() and true or false
        HCDR_Settings[realmKey].shouldAtWithLevel = isChecked
    end)
    
    local ShouldAtText = HCDR_SettingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ShouldAtText:SetPoint("LEFT", HCDR_ShouldAtCheckbox, "RIGHT", 5, 0)
    ShouldAtText:SetText("是否艾特对方")
end

function HCDR_CreateCondolenceSettings()
    -- 自动悼念复选框
    HCDR_AutoSendCondolenceCheckbox = CreateFrame("CheckButton", "HCDR_AutoSendCondolenceCheckbox", HCDR_SettingsFrame, "UICheckButtonTemplate")
    HCDR_AutoSendCondolenceCheckbox:SetWidth(20)
    HCDR_AutoSendCondolenceCheckbox:SetHeight(20)
    HCDR_AutoSendCondolenceCheckbox:SetPoint("TOPLEFT", 20, -75)
    HCDR_AutoSendCondolenceCheckbox:SetScript("OnClick", function()
        local realmKey = HCDR_GetRealmKey()
        local isChecked = this:GetChecked() and true or false
        if isChecked then
            StaticPopup_Show("HCDR_CONFIRM_CONDOLENCE")
        else
            HCDR_Settings[realmKey].autoSendCondolence = isChecked
        end
    end)
    
    local CondolenceText = HCDR_SettingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    CondolenceText:SetPoint("LEFT", HCDR_AutoSendCondolenceCheckbox, "RIGHT", 5, 0)
    CondolenceText:SetText("自动悼念")
    
    -- 悼念等级
    HCDR_CondolenceLevelEditBox = CreateFrame("EditBox", "HCDR_CondolenceLevelEditBox", HCDR_SettingsFrame, "InputBoxTemplate")
    HCDR_CondolenceLevelEditBox:SetWidth(20)
    HCDR_CondolenceLevelEditBox:SetHeight(20)
    HCDR_CondolenceLevelEditBox:SetPoint("LEFT", CondolenceText, "RIGHT", 10, 0)
    HCDR_CondolenceLevelEditBox:SetAutoFocus(false)
    HCDR_CondolenceLevelEditBox:SetNumeric(true)
    HCDR_CondolenceLevelEditBox:SetMaxLetters(2)
    HCDR_CondolenceLevelEditBox:SetText("60")
    HCDR_SetupLevelEditBox(HCDR_CondolenceLevelEditBox, "condolenceMinLevel")
    
    local CondolenceLevelText = HCDR_SettingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    CondolenceLevelText:SetPoint("LEFT", HCDR_CondolenceLevelEditBox, "RIGHT", 5, 0)
    CondolenceLevelText:SetText("级及以上 (自动私聊)")
end

function HCDR_CreateCooldownSettings()
    local CooldownText = HCDR_SettingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    CooldownText:SetPoint("TOPLEFT", HCDR_SettingsFrame, "TOPLEFT", 20, -105)
    CooldownText:SetText("自动发送吃席消息冷却")
    
    HCDR_CooldownEditBox = CreateFrame("EditBox", "HCDR_CooldownEditBox", HCDR_SettingsFrame, "InputBoxTemplate")
    HCDR_CooldownEditBox:SetPoint("LEFT", CooldownText, "RIGHT", 10, 0)
    HCDR_CooldownEditBox:SetWidth(30)
    HCDR_CooldownEditBox:SetHeight(20)
    HCDR_CooldownEditBox:SetAutoFocus(false)
    HCDR_CooldownEditBox:SetNumeric(true)
    HCDR_CooldownEditBox:SetMaxLetters(4)
    HCDR_CooldownEditBox:SetText("60")
    HCDR_SetupCooldownEditBox()
    
    local CooldownUnitText = HCDR_SettingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    CooldownUnitText:SetPoint("LEFT", HCDR_CooldownEditBox, "RIGHT", 5, 0)
    CooldownUnitText:SetText("秒")
end

function HCDR_CreateMessageReceiveSettings()
    local ReceiveText = HCDR_SettingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ReceiveText:SetPoint("TOPLEFT", HCDR_SettingsFrame, "TOPLEFT", 20, -135)
    ReceiveText:SetText("接收")
    
    LevelFilterEditBox = CreateFrame("EditBox", "HC_LevelFilterEditBox", HCDR_SettingsFrame, "InputBoxTemplate")
    LevelFilterEditBox:SetPoint("LEFT", ReceiveText, "RIGHT", 5, 0)
    LevelFilterEditBox:SetWidth(20)
    LevelFilterEditBox:SetHeight(20)
    LevelFilterEditBox:SetAutoFocus(false)
    LevelFilterEditBox:SetText("1")
    HCDR_SetupReceiveLevelEditBox()
    
    local RightText = HCDR_SettingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    RightText:SetPoint("LEFT", LevelFilterEditBox, "RIGHT", 5, 0)
    RightText:SetText("级以上死亡消息")
end

function HCDR_CreateCustomTextSettings()
    -- 自定义吃席内容
    local CustomFeastText = HCDR_SettingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    CustomFeastText:SetPoint("TOPLEFT", HCDR_SettingsFrame, "TOPLEFT", 20, -165)
    CustomFeastText:SetText("自定义吃席内容")
    
    HCDR_CustomFeastEditBox = CreateFrame("EditBox", "HCDR_CustomFeastEditBox", HCDR_SettingsFrame, "InputBoxTemplate")
    HCDR_CustomFeastEditBox:SetWidth(550)
    HCDR_CustomFeastEditBox:SetHeight(20)
    HCDR_CustomFeastEditBox:SetPoint("TOPLEFT", CustomFeastText, "BOTTOMLEFT", 0, -5)
    HCDR_CustomFeastEditBox:SetAutoFocus(false)
    HCDR_SetupCustomEditBox(HCDR_CustomFeastEditBox, "customFeastText")
    
    -- 自定义悼念内容
    local CustomCondolenceText = HCDR_SettingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    CustomCondolenceText:SetPoint("TOPLEFT", HCDR_SettingsFrame, "TOPLEFT", 20, -215)
    CustomCondolenceText:SetText("自定义悼念内容")
    
    HCDR_CustomCondolenceEditBox = CreateFrame("EditBox", "HCDR_CustomCondolenceEditBox", HCDR_SettingsFrame, "InputBoxTemplate")
    HCDR_CustomCondolenceEditBox:SetWidth(550)
    HCDR_CustomCondolenceEditBox:SetHeight(20)
    HCDR_CustomCondolenceEditBox:SetPoint("TOPLEFT", CustomCondolenceText, "BOTTOMLEFT", 0, -5)
    HCDR_CustomCondolenceEditBox:SetAutoFocus(false)
    HCDR_SetupCustomEditBox(HCDR_CustomCondolenceEditBox, "customCondolenceText")
end

function HCDR_CreateBottomReminder()
    -- 温馨提醒文本
    local ReminderText = HCDR_SettingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    ReminderText:SetPoint("BOTTOM", 0, 30)  -- 在底部居中，距离底边10像素
    ReminderText:SetTextColor(1, 0.5, 0)  -- 橙色文字，更显眼
    ReminderText:SetText("请合理使用自动消息功能，避免对其他玩家造成干扰，也可能会被禁言!!!")
    
end
	
-- 设置界面显示时的回调
function HCDR_SettingsFrame_OnShow()
    HCDR_InitializeData() -- 确保数据已初始化
    local realmKey = HCDR_GetRealmKey()
    
    -- 更新所有控件状态
    if HCDR_AutoSendCheckbox then
        HCDR_AutoSendCheckbox:SetChecked(HCDR_Settings[realmKey].autoSendFeast or false)
    end
    if HCDR_AutoSendCondolenceCheckbox then
        HCDR_AutoSendCondolenceCheckbox:SetChecked(HCDR_Settings[realmKey].autoSendCondolence or false)
    end
    if HCDR_ShouldAtCheckbox then
        HCDR_ShouldAtCheckbox:SetChecked(HCDR_Settings[realmKey].shouldAtWithLevel or false)
    end
    if HCDR_FeastLevelEditBox then
        HCDR_FeastLevelEditBox:SetText(tostring(HCDR_Settings[realmKey].feastMinLevel or HCDR_Constants.DEFAULT_FEAST_MIN_LEVEL or 60))
    end
    if HCDR_CondolenceLevelEditBox then
        HCDR_CondolenceLevelEditBox:SetText(tostring(HCDR_Settings[realmKey].condolenceMinLevel or HCDR_Constants.DEFAULT_CONDOLENCE_MIN_LEVEL or 60))
    end
    if LevelFilterEditBox then
        LevelFilterEditBox:SetText(tostring(HCDR_Settings[realmKey].Receivedeathmessagelevel or HCDR_Constants.DEFAULT_RECEIVE_LEVEL or 1))
    end
    if HCDR_CooldownEditBox then
        HCDR_CooldownEditBox:SetText(tostring(HCDR_Settings[realmKey].feastCooldown or HCDR_Constants.DEFAULT_FEAST_COOLDOWN or 60))
    end
    if HCDR_CustomFeastEditBox then
        HCDR_CustomFeastEditBox:SetText(HCDR_Settings[realmKey].customFeastText or HCDR_Constants.DEFAULT_CUSTOM_FEAST_TEXT or "风，带走了又一位勇士。酒，斟满了整个旅店。敬永不消逝的冒险精神！这席，我替大家先吃了！")
    end
    if HCDR_CustomCondolenceEditBox then
        HCDR_CustomCondolenceEditBox:SetText(HCDR_Settings[realmKey].customCondolenceText or HCDR_Constants.DEFAULT_CUSTOM_CONDOLENCE_TEXT or "你如星辰，虽已陨落，但光芒永存，照亮我们前行的道路")
    end
    
    -- 更新下拉框（确保在数据初始化后）
    if HCDR_ChannelDropdown then
        -- 初始化下拉菜单
        UIDropDownMenu_Initialize(HCDR_ChannelDropdown, HCDR_InitializeChannelDropdown)
    end
end

-- 工具函数：设置等级输入框
function HCDR_SetupLevelEditBox(editBox, settingKey)
    editBox:SetScript("OnEscapePressed", function()
        HCDR_SaveLevelSetting(this:GetText(), settingKey)
        this:ClearFocus()
    end)
    editBox:SetScript("OnEnterPressed", function()
        HCDR_SaveLevelSetting(this:GetText(), settingKey)
        this:ClearFocus()
    end)
    editBox:SetScript("OnTextChanged", function()
        HCDR_SaveLevelSetting(this:GetText(), settingKey, true)
    end)
    editBox:SetScript("OnEditFocusLost", function()
        HCDR_SaveLevelSetting(this:GetText(), settingKey)
    end)
end

function HCDR_SaveLevelSetting(text, settingKey, isTextChanged)
    local realmKey = HCDR_GetRealmKey()
    local level = tonumber(text) or 1
    if level < 1 then level = 1 end
    if level > 60 then level = 60 end
    HCDR_Settings[realmKey][settingKey] = level
    if not isTextChanged then
        this:SetText(tostring(level))
    end
end

-- 工具函数：设置冷却时间输入框
function HCDR_SetupCooldownEditBox()
    HCDR_CooldownEditBox:SetScript("OnEscapePressed", function()
        HCDR_SaveCooldownSetting(this:GetText())
        this:ClearFocus()
    end)
    HCDR_CooldownEditBox:SetScript("OnEnterPressed", function()
        HCDR_SaveCooldownSetting(this:GetText())
        this:ClearFocus()
    end)
    HCDR_CooldownEditBox:SetScript("OnTextChanged", function()
        HCDR_SaveCooldownSetting(this:GetText(), true)
    end)
    HCDR_CooldownEditBox:SetScript("OnEditFocusLost", function()
        HCDR_SaveCooldownSetting(this:GetText())
    end)
end

function HCDR_SaveCooldownSetting(text, isTextChanged)
    local realmKey = HCDR_GetRealmKey()
    local seconds = tonumber(text) or 60
    if seconds < 1 then seconds = 1 end
    if seconds > 3600 then seconds = 3600 end
    HCDR_Settings[realmKey].feastCooldown = seconds
    if not isTextChanged then
        this:SetText(tostring(seconds))
    end
end

-- 工具函数：设置接收等级输入框
function HCDR_SetupReceiveLevelEditBox()
    LevelFilterEditBox:SetScript("OnEscapePressed", function()
        HCDR_SaveReceiveLevelSetting(this:GetText())
        this:ClearFocus()
    end)
    LevelFilterEditBox:SetScript("OnEnterPressed", function()
        HCDR_SaveReceiveLevelSetting(this:GetText())
        this:ClearFocus()
    end)
    LevelFilterEditBox:SetScript("OnTextChanged", function()
        HCDR_SaveReceiveLevelSetting(this:GetText(), true)
    end)
    LevelFilterEditBox:SetScript("OnEditFocusLost", function()
        HCDR_SaveReceiveLevelSetting(this:GetText())
    end)
end

function HCDR_SaveReceiveLevelSetting(text, isTextChanged)
    local realmKey = HCDR_GetRealmKey()
    local level = tonumber(text) or 1
    if level < 1 then level = 1 end
    if level > 60 then level = 60 end
    HCDR_Settings[realmKey].Receivedeathmessagelevel = level
    if not isTextChanged then
        this:SetText(tostring(level))
        SendChatMessage(".hcm "..level)
    end
end

-- 工具函数：设置自定义文本输入框
function HCDR_SetupCustomEditBox(editBox, settingKey)
    editBox:SetScript("OnEscapePressed", function()
        this:ClearFocus()
    end)
    editBox:SetScript("OnEnterPressed", function()
        this:ClearFocus()
    end)
    editBox:SetScript("OnEditFocusLost", function()
        local realmKey = HCDR_GetRealmKey()
        local text = this:GetText()
        if not HCDR_Settings[realmKey] then
            HCDR_Settings[realmKey] = {}
        end
        HCDR_Settings[realmKey][settingKey] = text
    end)
end

-- 频道下拉框初始化
function HCDR_InitializeChannelDropdown()
    local realmKey = HCDR_GetRealmKey()
    local currentChannel = HCDR_Settings[realmKey].feastChannel or "world"
    local info = {}
    
    -- 硬核频道选项
    info.text = "硬核频道"
    info.value = "Hardcore"
    info.checked = (currentChannel == "Hardcore")
    info.func = function(button)
        local realmKey = HCDR_GetRealmKey()
        HCDR_Settings[realmKey].feastChannel = "Hardcore"
        UIDropDownMenu_SetText("硬核频道", HCDR_ChannelDropdown)
    end
    UIDropDownMenu_AddButton(info)
    
    -- World频道选项
    info = {}  -- 重新创建新的表
    info.text = "World频道"
    info.value = "world"
    info.checked = (currentChannel == "world")
    info.func = function(button)
        local realmKey = HCDR_GetRealmKey()
        HCDR_Settings[realmKey].feastChannel = "world"
        UIDropDownMenu_SetText("World频道", HCDR_ChannelDropdown)
    end
    UIDropDownMenu_AddButton(info)
    
    -- 设置下拉框的显示文本
    if currentChannel == "Hardcore" then
        UIDropDownMenu_SetText("硬核频道", HCDR_ChannelDropdown)
    else
        UIDropDownMenu_SetText("World频道", HCDR_ChannelDropdown)
    end
end

-- 初始化设置界面
HCDR_CreateSettingsFrame()
