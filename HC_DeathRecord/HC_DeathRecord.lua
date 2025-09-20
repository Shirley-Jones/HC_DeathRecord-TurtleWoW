--
-- 项目使用DeepSeek AI制作的
-- 代码开源 随意修改
--
-- 2025.09.20
--



-- 定义全局存储变量 - 按服务器独立存储
HCDR_Data = HCDR_Data or {}
HCDR_CurrentPage = HCDR_CurrentPage or 1
-- 初始化 HCDR_Settings，确保它是按服务器分层的表
HCDR_Settings = HCDR_Settings or {}

-- 获取当前服务器名称用于数据隔离
local function HCDR_GetRealmKey()
    local realmName = GetRealmName() or "UnknownRealm"
    return realmName
end

-- 时间格式化函数 
function HCDR_FormatTime(timestamp)
    local dateTable = date("*t", timestamp)
    
    -- 确保两位数格式
    local month = string.format("%02d", dateTable.month)
    local day = string.format("%02d", dateTable.day)
    local hour = string.format("%02d", dateTable.hour)
    local min = string.format("%02d", dateTable.min)
    local sec = string.format("%02d", dateTable.sec)
    
    return dateTable.year.."-"..month.."-"..day.." "..hour..":"..min..":"..sec
end

-- 主框架创建
local HCDR_Frame = CreateFrame("Frame", "HCDR_Frame", UIParent)
HCDR_Frame:SetWidth(1000)
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

-- 注册事件
HCDR_Frame:RegisterEvent("CHAT_MSG_SYSTEM")
HCDR_Frame:RegisterEvent("ADDON_LOADED")
HCDR_Frame:RegisterEvent("PLAYER_LOGIN")

-- 设置事件处理函数
HCDR_Frame:SetScript("OnEvent", function()
    if event == "CHAT_MSG_SYSTEM" then
        local message = arg1
        if string.find(message, "悲剧发生了。") then
            HCDR_ProcessDeathMessage(message)
        end
    elseif event == "ADDON_LOADED" and arg1 == "HC_DeathRecord" then
        -- 插件加载时初始化数据
        HCDR_InitializeData()
    elseif event == "PLAYER_LOGIN" then
        -- 玩家登录后确保界面更新
        HCDR_UpdateDisplay()
		-- +++ 新增：加载时自动执行 .hcm 命令 +++
        local realmKey = HCDR_GetRealmKey()
        -- 获取保存的等级，如果没有则使用默认值1
        local level = (HCDR_Settings[realmKey] and HCDR_Settings[realmKey].Receivedeathmessagelevel) or 1
        -- 执行命令
		SendChatMessage(".hcm "..level)
        -- 可选：输出调试信息
        -- DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99专家模式死亡讣告|r：已自动设置接收等级为 " .. level .. " 级的死亡消息")
    end
end)

-- 初始化数据函数
function HCDR_InitializeData()
    local realmKey = HCDR_GetRealmKey()
    
    -- 初始化服务器特定数据
    if not HCDR_Data[realmKey] then
        HCDR_Data[realmKey] = {}
    end
    
    -- 初始化服务器特定设置
    if not HCDR_Settings[realmKey] then
        HCDR_Settings[realmKey] = { 
            autoSendFeast = false, 
            autoSendCondolence = false,
            condolenceMinLevel = 60, -- 默认的值，默认自动给60级及以上的死亡玩家发送哀悼消息
            Receivedeathmessagelevel = 1,  -- 默认的值，默认接收1级以上的死亡消息
			levelFilter = "all"  -- 新增等级筛选设置
        }
    end
    
    -- 确保UI元素已创建后再更新它们
    if HCDR_Frame then
        -- 更新复选框状态
        if HCDR_AutoSendCheckbox then
            HCDR_AutoSendCheckbox:SetChecked(HCDR_Settings[realmKey].autoSendFeast or false)
        end
        
        -- 更新哀悼消息复选框状态
        if HCDR_AutoSendCondolenceCheckbox then
            HCDR_AutoSendCondolenceCheckbox:SetChecked(HCDR_Settings[realmKey].autoSendCondolence or false)
        end
        
        -- 更新哀悼等级输入框文本 (修正前的HCDR_CondolenceLevelEditBox)
        if HCDR_CondolenceLevelEditBox then
            HCDR_CondolenceLevelEditBox:SetText(tostring(HCDR_Settings[realmKey].condolenceMinLevel or 59))
        end
        
        -- 更新接收死亡消息等级输入框文本 (新增的LevelFilterEditBox)
        if LevelFilterEditBox then
            LevelFilterEditBox:SetText(tostring(HCDR_Settings[realmKey].Receivedeathmessagelevel or 1))
        end
		
		-- 设置等级筛选按钮状态
        if LevelFilterButtons and LevelFilterButtons[1] then
            LevelFilterButtons[1]:SetChecked(1)
            HCDR_CurrentLevelFilter = levelRanges[1]
        end
		
    end
    
    DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99专家模式死亡讣告|r：数据已初始化 for " .. realmKey)
end

-- 修改死亡消息处理函数，使用正确的等级格式匹配
function HCDR_ProcessDeathMessage(msg)
    local realmKey = HCDR_GetRealmKey()
    local currentTime = time()
    
    -- 尝试匹配各种死亡消息格式
    local charName, level, killer, zone
    
    -- 尝试匹配PVP死亡消息（使用正确的等级格式）
    charName, level, killer, zone = string.match(msg, "悲剧发生了。硬核角色 (.+)（等级 (%d+)）在 PvP 中落败于 (.+)。这件事发生在 (.+)。愿这一牺牲不会被忘记。")
    if charName then
        level = tonumber(level)
        table.insert(HCDR_Data[realmKey], 1, {
            charName = charName,
            deathType = "PVP",
            killer = killer,
            zone = zone,
            time = currentTime,
            rawMessage = msg,
            level = level
        })
        DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99专家模式死亡讣告：|r已记录PVP死亡: "..charName.." (等级 "..level..")")
        HCDR_Automaticallysendbanquetmessages(charName, level)
        HCDR_CheckAndSendCondolence(charName, level)
        HCDR_UpdateDisplay()
        return
    end
    
    -- 尝试匹配PVE死亡消息（使用正确的等级格式）
    charName, level, killer, zone = string.match(msg, "悲剧发生了。硬核角色 (.+)（等级 (%d+)）被 (.+)击杀。这发生在 (.+)。愿这一牺牲不会被忘记。")
    if charName then
        level = tonumber(level)
        table.insert(HCDR_Data[realmKey], 1, {
            charName = charName,
            deathType = "PVE",
            killer = killer,
            zone = zone,
            time = currentTime,
            rawMessage = msg,
            level = level
        })
        DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99专家模式死亡讣告：|r已记录PVE死亡: "..charName.." (等级 "..level..")")
        HCDR_Automaticallysendbanquetmessages(charName, level)
        HCDR_CheckAndSendCondolence(charName, level)
        HCDR_UpdateDisplay()
        return
    end
    
    -- 尝试匹配溺亡消息（使用正确的等级格式）
    charName, level, zone = string.match(msg, "悲剧发生了。硬核角色 (.+)（等级 (%d+)）已在 (.+) 中溺亡。愿这一牺牲永不被遗忘。")
    if charName then
        level = tonumber(level)
        table.insert(HCDR_Data[realmKey], 1, {
            charName = charName,
            deathType = "其他",
            killer = "溺亡",
            zone = zone,
            time = currentTime,
            rawMessage = msg,
            level = level
        })
        DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99专家模式死亡讣告：|r已记录溺水死亡: "..charName.." (等级 "..level..")")
        HCDR_Automaticallysendbanquetmessages(charName, level)
        HCDR_CheckAndSendCondolence(charName, level)
        HCDR_UpdateDisplay()
        return
    end
    
    -- 尝试匹配年老死亡消息（使用正确的等级格式）
    charName, level, zone = string.match(msg, "悲剧发生了。硬核角色 (.+)（等级 (%d+)）于 (.+) 年因年老而去世。愿这一牺牲不会被忘记。")
    if charName then
        level = tonumber(level)
        table.insert(HCDR_Data[realmKey], 1, {
            charName = charName,
            deathType = "其他",
            killer = "年老死亡(DOT)",
            zone = zone,
            time = currentTime,
            rawMessage = msg,
            level = level
        })
        DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99专家模式死亡讣告：|r已记录年老死亡: "..charName.." (等级 "..level..")")
        HCDR_Automaticallysendbanquetmessages(charName, level)
        HCDR_CheckAndSendCondolence(charName, level)
        HCDR_UpdateDisplay()
        return
    end
    
    -- 尝试匹配活活烧死消息（使用正确的等级格式）
    charName, level, zone = string.match(msg, "悲剧发生了。硬核角色 (.+)（等级 (%d+)）在 (.+) 被活活烧死。愿这一牺牲永不被遗忘。")
    if charName then
        level = tonumber(level)
        table.insert(HCDR_Data[realmKey], 1, {
            charName = charName,
            deathType = "其他",
            killer = "活活烧死",
            zone = zone,
            time = currentTime,
            rawMessage = msg,
            level = level
        })
        DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99专家模式死亡讣告：|r已记录活活烧死: "..charName.." (等级 "..level..")")
        HCDR_Automaticallysendbanquetmessages(charName, level)
        HCDR_CheckAndSendCondolence(charName, level)
        HCDR_UpdateDisplay()
        return
    end
    
    DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99专家模式死亡讣告：|r检测到死亡消息但未匹配具体格式,如果可以,请复制这个死亡消息并发送给开发添加匹配~")
end

-- 修改等级提取函数，使用正确的等级格式
function HCDR_ExtractLevelFromName(message)
    -- 尝试匹配中文括号中的等级数字（正确的格式）
    local level = string.match(message, "（等级 (%d+)）")
    if level then
        return tonumber(level)
    end
    
    -- 尝试匹配其他格式的等级信息
    level = string.match(message, "(%d+)级")
    if level then
        return tonumber(level)
    end
    
    -- 尝试匹配死亡消息中的等级
    level = string.match(message, "悲剧发生了。硬核角色 .+（等级 (%d+)）")
    if level then
        return tonumber(level)
    end
    
    -- 如果无法提取，返回0表示未知等级
    return 0
end

-- 在硬核频道发送吃席消息
function HCDR_Automaticallysendbanquetmessages(charName, charLevel)
    local realmKey = HCDR_GetRealmKey()
	local level = charLevel
    local pureName = charName
    if HCDR_Settings[realmKey].autoSendFeast then
        SendChatMessage("哦豁！又嘎一个。上菜了，老板请客！！！  @"..pureName.." LV"..level, "Hardcore")
    end
end

-- 修改后的检查并发送哀悼消息函数
function HCDR_CheckAndSendCondolence(charName, charLevel)
    local realmKey = HCDR_GetRealmKey()
    
    -- 检查是否启用自动发送哀悼消息
    if HCDR_Settings[realmKey].autoSendCondolence then
        -- 直接从参数获取等级信息，不再需要从名称中解析
        local level = charLevel or 0
        local pureName = charName or ""
        
        -- 检查角色等级是否达到设定值
        if level >= HCDR_Settings[realmKey].condolenceMinLevel then
            -- 发送哀悼消息
            SendChatMessage("你如星辰，虽已陨落，但光芒永存，照亮我们前行的道路", "WHISPER", nil, pureName)
            DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99专家模式死亡讣告|r：已向 "..pureName.." (等级 "..level..") 发送哀悼消息")
        end
    end
end




-- 添加右上角关闭按钮
local CloseButton = CreateFrame("Button", "HCDR_CloseButton", HCDR_Frame, "UIPanelCloseButton")
CloseButton:SetPoint("TOPRIGHT", HCDR_Frame, "TOPRIGHT", -7, -7)
CloseButton:SetScript("OnClick", function()
    HCDR_Frame:Hide()
end)

-- 标题文本
local TitleText = HCDR_Frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
TitleText:SetPoint("TOP", 0, -20)
TitleText:SetText("|cFFFFD700专家模式死亡讣告|r")

-- 列标题
local function CreateColumnHeader(text, xOffset)
    local header = HCDR_Frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    header:SetPoint("TOPLEFT", 50 + xOffset, -80)
    header:SetText(text)
    return header
end
CreateColumnHeader("角色名字", 20)
CreateColumnHeader("死亡类型", 135)
CreateColumnHeader("被谁击杀", 280)
CreateColumnHeader("死亡区域", 480)
CreateColumnHeader("死亡时间", 650)
CreateColumnHeader("操作", 830)

-- 表格分隔线
local Line = HCDR_Frame:CreateTexture(nil, "ARTWORK")
Line:SetWidth(750)
Line:SetHeight(2)
Line:SetPoint("TOP",  0, -75)
Line:SetTexture("Interface\\Tooltips\\UI-Tooltip-BBorder")
Line:SetTexCoord(0, 1, 0, 0.125)

-- 数据行创建 (10行)
local DataRows = {}
for i = 1, 10 do
    local row = {
        charName = HCDR_Frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"),
        deathType = HCDR_Frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"),
        killer = HCDR_Frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"),
        zone = HCDR_Frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"),
        time = HCDR_Frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"),
        whisperBtn = CreateFrame("Button", "HCDR_WhisperBtn"..i, HCDR_Frame, "UIPanelButtonTemplate"),
        deleteBtn = CreateFrame("Button", "HCDR_DeleteBtn"..i, HCDR_Frame, "UIPanelButtonTemplate"),
		copyBtn = CreateFrame("Button", "HCDR_CopyBtn"..i, HCDR_Frame, "UIPanelButtonTemplate")  -- 新增复制按钮
    }
    
    local yPos = -85 - (i * 25)
    row.charName:SetPoint("TOPLEFT", 30, yPos)
    row.deathType:SetPoint("TOPLEFT", 200, yPos)
    row.killer:SetPoint("TOPLEFT", 280, yPos)
    row.zone:SetPoint("TOPLEFT", 500, yPos)
    row.time:SetPoint("TOPLEFT", 650, yPos)
    
    -- 设置私聊按钮
    row.whisperBtn:SetWidth(50)
    row.whisperBtn:SetHeight(20)
    row.whisperBtn:SetPoint("TOPLEFT", 820, yPos - 2)
    row.whisperBtn:SetText("私聊")
    
    -- 设置删除按钮
    row.deleteBtn:SetWidth(50)
    row.deleteBtn:SetHeight(20)
    row.deleteBtn:SetPoint("TOPLEFT", 870, yPos - 2)
    row.deleteBtn:SetText("删除")
    
	-- 设置复制按钮（放在删除按钮右边）
    row.copyBtn:SetWidth(50)
    row.copyBtn:SetHeight(20)
    row.copyBtn:SetPoint("TOPLEFT", 920, yPos - 2)  -- 调整位置
    row.copyBtn:SetText("复制")
	
    -- 初始化隐藏按钮
    row.whisperBtn:Hide()
    row.deleteBtn:Hide()
    
    -- 初始化空数据
    row.charName:SetText("")
    row.deathType:SetText("")
    row.killer:SetText("")
    row.zone:SetText("")
    row.time:SetText("")
    
    DataRows[i] = row
end

-- 分页控件
local PageText = HCDR_Frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
PageText:SetPoint("BOTTOM", 0, 25)
PageText:SetText("第 1 页")

-- 上一页按钮
local PrevButton = CreateFrame("Button", nil, HCDR_Frame, "UIPanelButtonTemplate")
PrevButton:SetWidth(60)
PrevButton:SetHeight(22)
PrevButton:SetPoint("BOTTOMLEFT", 350, 20)
PrevButton:SetText("上一页")
PrevButton:Disable()

-- 新增：首页按钮
local FirstPageButton = CreateFrame("Button", nil, HCDR_Frame, "UIPanelButtonTemplate")
FirstPageButton:SetWidth(60)
FirstPageButton:SetHeight(22)
FirstPageButton:SetPoint("RIGHT", PrevButton, "LEFT", -10, 0) -- 放在上一页按钮的左边
FirstPageButton:SetText("首页")
FirstPageButton:Disable() -- 初始在第1页时禁用

-- 下一页按钮
local NextButton = CreateFrame("Button", nil, HCDR_Frame, "UIPanelButtonTemplate")
NextButton:SetWidth(60)
NextButton:SetHeight(22)
NextButton:SetPoint("BOTTOMRIGHT", -350, 20)
NextButton:SetText("下一页")

-- 新增：尾页按钮
local LastPageButton = CreateFrame("Button", nil, HCDR_Frame, "UIPanelButtonTemplate")
LastPageButton:SetWidth(60)
LastPageButton:SetHeight(22)
LastPageButton:SetPoint("LEFT", NextButton, "RIGHT", 10, 0) -- 放在下一页按钮的右边
LastPageButton:SetText("尾页")
-- 添加删除所有数据按钮
local DeleteAllButton = CreateFrame("Button", nil, HCDR_Frame, "UIPanelButtonTemplate")
DeleteAllButton:SetWidth(120)
DeleteAllButton:SetHeight(22)
DeleteAllButton:SetPoint("BOTTOMRIGHT", -50, 380)
DeleteAllButton:SetText("删除所有数据")

-- 创建左侧文本
local LeftText = HCDR_Frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
LeftText:SetPoint("TOPLEFT", HCDR_Frame, "TOPLEFT", 650, -20) -- 根据需要调整位置
LeftText:SetText("接收")

-- 创建等级输入框
LevelFilterEditBox = CreateFrame("EditBox", "HC_LevelFilterEditBox", HCDR_Frame, "InputBoxTemplate")
LevelFilterEditBox:SetPoint("LEFT", LeftText, "RIGHT", 5, 0) -- 紧接在"接收"后面
LevelFilterEditBox:SetWidth(20)
LevelFilterEditBox:SetHeight(20)
LevelFilterEditBox:SetAutoFocus(false)
LevelFilterEditBox:SetText("1") -- 默认值

-- 创建右侧文本
local RightText = HCDR_Frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
RightText:SetPoint("LEFT", LevelFilterEditBox, "RIGHT", 5, 0) -- 紧接在输入框后面
RightText:SetText("级以上死亡消息")


-- 设置等级输入框的事件处理
LevelFilterEditBox:SetScript("OnEscapePressed", function()
	local level = tonumber(LevelFilterEditBox:GetText()) or 1
    if level < 1 then level = 1 end
    if level > 60 then level = 60 end
    LevelFilterEditBox:SetText(tostring(level))
    
    -- 执行命令
    SendChatMessage(".hcm "..level)
	DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99专家模式死亡讣告|r：接收死亡消息等级修改为"..level.."级以上！")
	-- 失去焦点
    LevelFilterEditBox:ClearFocus()
end)

LevelFilterEditBox:SetScript("OnEnterPressed", function()
    local level = tonumber(LevelFilterEditBox:GetText()) or 1
    if level < 1 then level = 1 end
    if level > 60 then level = 60 end
    LevelFilterEditBox:SetText(tostring(level))
    
    -- 执行命令
    SendChatMessage(".hcm "..level)
    DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99专家模式死亡讣告|r：接收死亡消息等级修改为"..level.."级以上！")
    -- 失去焦点
    LevelFilterEditBox:ClearFocus()
end)



LevelFilterEditBox:SetScript("OnTextChanged", function()
	local realmKey = HCDR_GetRealmKey()
    local level = tonumber(LevelFilterEditBox:GetText()) or 1
    if level < 1 then level = 1 end
    if level > 60 then level = 60 end
	HCDR_Settings[realmKey].Receivedeathmessagelevel = level
    this:SetText(tostring(level))
end)




LevelFilterEditBox:SetScript("OnEditFocusLost", function()
	local realmKey = HCDR_GetRealmKey()
    local level = tonumber(LevelFilterEditBox:GetText()) or 1
    if level < 1 then level = 1 end
    if level > 60 then level = 60 end
	HCDR_Settings[realmKey].Receivedeathmessagelevel = level
    this:SetText(tostring(level))
end)


-- 添加自动发送吃席复选框
local AutoSendCheckbox = CreateFrame("CheckButton", "HCDR_AutoSendCheckbox", HCDR_Frame, "UICheckButtonTemplate")
AutoSendCheckbox:SetWidth(20)
AutoSendCheckbox:SetHeight(20)
AutoSendCheckbox:SetPoint("BOTTOMLEFT", 20, 20)

-- 添加复选框文本
local AutoSendText = HCDR_Frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
AutoSendText:SetPoint("LEFT", AutoSendCheckbox, "RIGHT", 5, 0)
AutoSendText:SetText("自动发送吃席消息到硬核频道")

AutoSendCheckbox:SetScript("OnClick", function()
    local realmKey = HCDR_GetRealmKey()
    -- 直接使用函数传入的第一个参数（通常为self）来获取复选框状态
    local isChecked = this:GetChecked() and true or false -- 确保为布尔值

    -- 立即保存状态到全局变量
    HCDR_Settings[realmKey].autoSendFeast = isChecked

    -- 提供一些反馈
    if isChecked then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99专家模式死亡讣告|r：已启用自动发送吃席消息")
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99专家模式死亡讣告|r：已禁用自动发送吃席消息")
    end
    -- 调试输出，确认保存的值
    -- DEFAULT_CHAT_FRAME:AddMessage("Debug: Check state saved as "..tostring(HCDR_Settings[realmKey].autoSendFeast))
end)

-- 添加自动发送哀悼消息复选框
local HCDR_AutoSendCondolenceCheckbox = CreateFrame("CheckButton", "HCDR_AutoSendCondolenceCheckbox", HCDR_Frame, "UICheckButtonTemplate")
HCDR_AutoSendCondolenceCheckbox:SetWidth(20)
HCDR_AutoSendCondolenceCheckbox:SetHeight(20)
HCDR_AutoSendCondolenceCheckbox:SetPoint("LEFT", NextButton, "RIGHT", 80, 0)

-- 添加哀悼复选框文本
local CondolenceText = HCDR_Frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
CondolenceText:SetPoint("LEFT", HCDR_AutoSendCondolenceCheckbox, "RIGHT", 5, 0)
CondolenceText:SetText("自动发送哀悼消息")

-- 添加等级输入框
local HCDR_CondolenceLevelEditBox = CreateFrame("EditBox", "HCDR_CondolenceLevelEditBox", HCDR_Frame, "InputBoxTemplate")
HCDR_CondolenceLevelEditBox:SetWidth(30)
HCDR_CondolenceLevelEditBox:SetHeight(20)
HCDR_CondolenceLevelEditBox:SetPoint("LEFT", CondolenceText, "RIGHT", 10, 0)
HCDR_CondolenceLevelEditBox:SetAutoFocus(false)
HCDR_CondolenceLevelEditBox:SetNumeric(true)
HCDR_CondolenceLevelEditBox:SetMaxLetters(2)
HCDR_CondolenceLevelEditBox:SetText("60")

-- 添加等级文本
local LevelText = HCDR_Frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
LevelText:SetPoint("LEFT", HCDR_CondolenceLevelEditBox, "RIGHT", 5, 0)
LevelText:SetText("级及以上")

-- 设置哀悼复选框的事件处理
HCDR_AutoSendCondolenceCheckbox:SetScript("OnClick", function()
    local realmKey = HCDR_GetRealmKey()
    local isChecked = this:GetChecked() and true or false
    HCDR_Settings[realmKey].autoSendCondolence = isChecked

    if isChecked then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99专家模式死亡讣告|r：已启用自动发送哀悼消息")
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99专家模式死亡讣告|r：已禁用自动发送哀悼消息")
    end
end)

-- 设置等级输入框的事件处理
HCDR_CondolenceLevelEditBox:SetScript("OnEscapePressed", function()
	local realmKey = HCDR_GetRealmKey()
    local text = this:GetText()
    local level = tonumber(text) or 1
    
    -- 确保等级在有效范围内
    if level < 1 then
        level = 1
    elseif level > 60 then
        level = 60
    end
	
	DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99专家模式死亡讣告|r：自动发送哀悼消息等级修改为"..level.."级及以上！")
	
	-- 失去焦点
    this:ClearFocus()
end)

HCDR_CondolenceLevelEditBox:SetScript("OnEnterPressed", function()
	local realmKey = HCDR_GetRealmKey()
    local text = this:GetText()
    local level = tonumber(text) or 1
    
    -- 确保等级在有效范围内
    if level < 1 then
        level = 1
    elseif level > 60 then
        level = 60
    end
	
	DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99专家模式死亡讣告|r：自动发送哀悼消息等级修改为"..level.."级及以上！")
	
	-- 失去焦点
    this:ClearFocus()
end)

HCDR_CondolenceLevelEditBox:SetScript("OnTextChanged", function()
    local realmKey = HCDR_GetRealmKey()
    local text = this:GetText()
    local level = tonumber(text) or 1
    
    -- 确保等级在有效范围内
    if level < 1 then
        level = 1
    elseif level > 60 then
        level = 60
    end
	
    HCDR_Settings[realmKey].condolenceMinLevel = level
    this:SetText(tostring(level))
end)

HCDR_CondolenceLevelEditBox:SetScript("OnEditFocusLost", function()
    local realmKey = HCDR_GetRealmKey()
    local text = this:GetText()
    local level = tonumber(text) or 1
    
    -- 确保等级在有效范围内
    if level < 1 then
        level = 1
    elseif level > 60 then
        level = 60
    end
    
    HCDR_Settings[realmKey].condolenceMinLevel = level
    this:SetText(tostring(level))
end)

-- 更新显示函数以支持等级筛选
function HCDR_UpdateDisplay()
    local realmKey = HCDR_GetRealmKey()
    local serverData = HCDR_Data[realmKey] or {}
    
    -- 应用等级筛选
    local filteredData = {}
    for i, data in ipairs(serverData) do
        -- 确保数据有等级信息
        if not data.level then
            data.level = HCDR_ExtractLevelFromName(data.rawMessage or data.charName or "")
        end
        
        -- 应用筛选条件
        if HCDR_CurrentLevelFilter then
            if data.level >= HCDR_CurrentLevelFilter.min and data.level <= HCDR_CurrentLevelFilter.max then
                table.insert(filteredData, data)
            end
        else
            table.insert(filteredData, data)
        end
    end
    
    local totalEntries = table.getn(filteredData)
    local totalPages = totalEntries > 0 and math.ceil(totalEntries / 10) or 1

    -- 更新分页文本
    PageText:SetText("第 "..HCDR_CurrentPage.." 页 / 总 "..totalPages.." 页")
    
    -- 更新按钮状态
    if HCDR_CurrentPage <= 1 then
        FirstPageButton:Disable()
        PrevButton:Disable()
    else
        FirstPageButton:Enable()
        PrevButton:Enable()
    end
    
    if HCDR_CurrentPage >= totalPages then
        NextButton:Disable()
        LastPageButton:Disable()
    else
        NextButton:Enable()
        LastPageButton:Enable()
    end
    
    -- 计算当前页的数据范围
    local startIndex = (HCDR_CurrentPage - 1) * 10 + 1
    local endIndex = math.min(startIndex + 9, totalEntries)
    
    -- 更新表格行
    for i = 1, 10 do
        local dataIndex = startIndex + i - 1
        local row = DataRows[i]
        
        if dataIndex <= totalEntries then
            local data = filteredData[dataIndex]
            -- 在角色名后显示等级
            row.charName:SetText((data.charName or "") .. " (" .. (data.level or 0) .. "级)")
            row.deathType:SetText(data.deathType or "")
            row.killer:SetText(data.killer or "")
            row.zone:SetText(data.zone or "")
            row.time:SetText(data.time and HCDR_FormatTime(data.time) or "")
            
            -- 显示操作按钮
            row.whisperBtn:Show()
            row.deleteBtn:Show()
            row.copyBtn:Show()
            
            -- 为复制按钮设置事件处理
            row.copyBtn:SetScript("OnClick", function()
                if data.rawMessage then
                    HCDR_CopyToClipboard(data.rawMessage)
                    DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99专家模式死亡讣告|r：原始死亡消息已显示，请按Ctrl+C复制")
                else
                    DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99专家模式死亡讣告|r：错误，没有保存原始死亡消息")
                end
            end)
            
            -- 为按钮设置事件处理函数
            row.whisperBtn:SetScript("OnClick", function()
                local nameWithLevel = data.charName or ""
                local pureName = nameWithLevel
                
                -- 移除等级部分
                local pos = string.find(pureName, "%(")
                if pos then
                    pureName = string.sub(pureName, 1, pos - 1)
                end
                
                pureName = strtrim(pureName)
                
                -- 打开私聊窗口
                ChatFrame_SendTell(pureName)
            end)
            
            row.deleteBtn:SetScript("OnClick", function()
                -- 从原始数据中删除而不仅仅是从筛选后的数据中删除
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
            -- 清空数据并隐藏按钮
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

-- 首页按钮点击事件
FirstPageButton:SetScript("OnClick", function()
    if HCDR_CurrentPage > 1 then
        HCDR_CurrentPage = 1
        HCDR_UpdateDisplay()
    end
end)

-- 尾页按钮点击事件
LastPageButton:SetScript("OnClick", function()
    local realmKey = HCDR_GetRealmKey()
    local serverData = HCDR_Data[realmKey] or {}
    local totalEntries = table.getn(serverData)
    local totalPages = totalEntries > 0 and math.ceil(totalEntries / 10) or 1
    if HCDR_CurrentPage < totalPages then
        HCDR_CurrentPage = totalPages
        HCDR_UpdateDisplay()
    end
end)

-- 分页按钮事件
PrevButton:SetScript("OnClick", function()
    if HCDR_CurrentPage > 1 then
        HCDR_CurrentPage = HCDR_CurrentPage - 1
        HCDR_UpdateDisplay()
    end
end)

NextButton:SetScript("OnClick", function()
    local realmKey = HCDR_GetRealmKey()
    local serverData = HCDR_Data[realmKey] or {}
    local totalEntries = table.getn(serverData)
    local totalPages = totalEntries > 0 and math.ceil(totalEntries / 10) or 1
    if HCDR_CurrentPage < totalPages then
        HCDR_CurrentPage = HCDR_CurrentPage + 1
        HCDR_UpdateDisplay()
    end
end)

-- 在文件末尾添加以下代码（在HCDR_InitializeData()调用之前）

-- 创建复制面板（可见）
local HCDR_CopyFrame = CreateFrame("Frame", "HCDR_CopyFrame", UIParent)
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

-- 标题文本
local CopyTitleText = HCDR_CopyFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
CopyTitleText:SetPoint("TOP", 0, -15)
CopyTitleText:SetText("|cFFFFD700死亡消息复制|r")

-- 关闭按钮
local CopyCloseButton = CreateFrame("Button", "HCDR_CopyCloseButton", HCDR_CopyFrame, "UIPanelCloseButton")
CopyCloseButton:SetPoint("TOPRIGHT", HCDR_CopyFrame, "TOPRIGHT", -7, -7)
CopyCloseButton:SetScript("OnClick", function()
    HCDR_CopyFrame:Hide()
end)

-- 创建编辑框 - 修改为多行编辑框
local CopyEditBox = CreateFrame("EditBox", "HCDR_CopyEditBox", HCDR_CopyFrame)
CopyEditBox:SetWidth(550)
CopyEditBox:SetHeight(120)  -- 增加高度以容纳多行文本
CopyEditBox:SetMultiLine(true)  -- 关键：设置为多行
CopyEditBox:SetAutoFocus(false)
CopyEditBox:SetPoint("TOP", 0, -40)
CopyEditBox:SetFontObject(GameFontHighlight)

-- 添加滚动条
CopyEditBox:SetScript("OnEscapePressed", function() 
    this:ClearFocus() 
end)

-- 全选按钮
local CopyButton = CreateFrame("Button", nil, HCDR_CopyFrame, "UIPanelButtonTemplate")
CopyButton:SetWidth(100)
CopyButton:SetHeight(22)
CopyButton:SetPoint("BOTTOMLEFT", 100, 20)
CopyButton:SetText("全选")
CopyButton:SetScript("OnClick", function()
    CopyEditBox:SetFocus()
    CopyEditBox:HighlightText()
    DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99专家模式死亡讣告|r：文本已全选,请按Ctrl+C复制")
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

-- 修改全选函数
function HCDR_CopyToClipboard(text)
    HCDR_CopyFrame:Show()
    CopyEditBox:SetText(text)
    CopyEditBox:SetFocus()
    CopyEditBox:HighlightText()
end


-- 创建等级筛选复选框组 - 调整为两行布局
local LevelFilterFrame = CreateFrame("Frame", "HCDR_LevelFilterFrame", HCDR_Frame)
LevelFilterFrame:SetWidth(400)
LevelFilterFrame:SetHeight(60) -- 增加高度以容纳两行
LevelFilterFrame:SetPoint("TOPLEFT", HCDR_Frame, "TOPLEFT", 10, -18)

local LevelFilterButtons = {}
local levelRanges = {
    {text = "1-10", min = 1, max = 10},
    {text = "10-20", min = 10, max = 20},
    {text = "20-30", min = 20, max = 30},
    {text = "30-40", min = 30, max = 40},
    {text = "40-50", min = 40, max = 50},
    {text = "50-60", min = 50, max = 60},
    {text = "全部", min = 0, max = 100} -- 将"全部"移到最后一个
}

-- 为每个按钮单独设置位置（分两行布局）
local function CreateLevelFilterButton(i, range, xOffset, yOffset)
    local button = CreateFrame("CheckButton", "HCDR_LevelFilter"..i, LevelFilterFrame, "UICheckButtonTemplate")
    button:SetWidth(20)
    button:SetHeight(20)
    button:SetPoint("TOPLEFT", LevelFilterFrame, "TOPLEFT", xOffset, yOffset)
    
    -- 存储范围信息
    button.range = range
    
    -- 添加文本标签
    local text = LevelFilterFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    text:SetPoint("LEFT", button, "RIGHT", 2, 0)
    text:SetText(range.text)
    
    -- 设置点击事件
    button:SetScript("OnClick", function()
        HCDR_LevelFilterButton_OnClick(button)
    end)
    
    LevelFilterButtons[i] = button
    return button
end

-- 创建第一行：等级范围按钮 (1-10 到 50-60)
CreateLevelFilterButton(1, levelRanges[1], 10, 0)     -- 1-10
CreateLevelFilterButton(2, levelRanges[2], 65, 0)    -- 10-20
CreateLevelFilterButton(3, levelRanges[3], 130, 0)    -- 20-30
CreateLevelFilterButton(4, levelRanges[4], 200, 0)    -- 30-40
CreateLevelFilterButton(5, levelRanges[5], 270, 0)    -- 40-50
CreateLevelFilterButton(6, levelRanges[6], 340, 0)    -- 50-60

-- 创建第二行：只有"全部"按钮，居中显示
CreateLevelFilterButton(7, levelRanges[7], 10, -20) -- 全部 (第二行居中)

-- 设置"全部"按钮为默认选中
LevelFilterButtons[7]:SetChecked(true)
HCDR_CurrentLevelFilter = levelRanges[7]

-- 复选框点击处理函数
function HCDR_LevelFilterButton_OnClick(button)
    if button:GetChecked() then
        -- 取消其他所有复选框的选中状态
        for i, btn in ipairs(LevelFilterButtons) do
            if btn ~= button then
                btn:SetChecked(0)
            end
        end
        -- 设置当前筛选范围
        HCDR_CurrentLevelFilter = button.range
    else
        -- 确保至少有一个按钮被选中
        button:SetChecked(1)
    end
    
    -- 更新显示
    HCDR_UpdateDisplay()
end

-- =====================================================================
-- 添加命令控制系统
-- =====================================================================

function HCDR_CommandHandler(msg)
    local command = string.lower(strtrim(msg or ""))
    
    if command == "show" then
        HCDR_Frame:Show()
        HCDR_UpdateDisplay()  -- 确保显示时更新数据
        DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99专家模式死亡讣告|r：界面已显示")
    elseif command == "hide" then
        HCDR_Frame:Hide()
        DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99专家模式死亡讣告|r：界面已隐藏")
    elseif command == "reset" then
        local realmKey = HCDR_GetRealmKey()
        HCDR_Data[realmKey] = {}
        HCDR_CurrentPage = 1
        HCDR_UpdateDisplay()
        DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99专家模式死亡讣告|r：所有数据已删除")
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99专家模式死亡讣告 命令用法：|r")
        DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99/hcdr show|r - 显示死亡讣告界面")
        DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99/hcdr hide|r - 隐藏死亡讣告界面")
        DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99/hcdr reset|r - 重置所有死亡讣告")
    end
end

-- 注册Slash命令
SLASH_HCDR1 = "/hcdr"
SLASH_HCDR2 = "/hcdeath"

SlashCmdList["HCDR"] = HCDR_CommandHandler

-- =====================================================================
-- 结束命令控制系统
-- =====================================================================

DeleteAllButton:SetScript("OnClick", function()
    HCDR_CommandHandler("reset")
end)

-- 初始隐藏框架
HCDR_Frame:Hide()

-- 在插件加载时立即初始化
HCDR_InitializeData()