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
		-- 注册静态弹出框
		
		StaticPopupDialogs["HCDR_CONFIRM_FEAST"] = {
            text = "是否开启自动发送吃席消息到硬核频道？此功能可能会对别人造成骚扰。",
            button1 = "确定",
            button2 = "取消",
            OnAccept = function()
                local realmKey = HCDR_GetRealmKey()
                HCDR_Settings[realmKey].autoSendFeast = true
                HCDR_AutoSendCheckbox:SetChecked(true)
                DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99专家模式死亡讣告|r：已启用自动发送吃席消息")
            end,
            OnCancel = function()
                HCDR_AutoSendCheckbox:SetChecked(false)
            end,
            timeout = 0,
            whileDead = 1,
            hideOnEscape = 1
        }
		
        StaticPopupDialogs["HCDR_CONFIRM_CONDOLENCE"] = {
            text = "是否开启自动发送哀悼消息？此功能可能会对别人造成骚扰。",
            button1 = "确定",
            button2 = "取消",
            OnAccept = function()
                local realmKey = HCDR_GetRealmKey()
                HCDR_Settings[realmKey].autoSendCondolence = true
                HCDR_AutoSendCondolenceCheckbox:SetChecked(true)
                DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99专家模式死亡讣告|r：已启用自动发送哀悼消息")
            end,
            OnCancel = function()
                HCDR_AutoSendCondolenceCheckbox:SetChecked(false)
            end,
            timeout = 0,
            whileDead = 1,
            hideOnEscape = 1
        }
        
        StaticPopupDialogs["HCDR_CONFIRM_DELETE_ALL"] = {
            text = "是否删除所有数据？此操作不可撤销。",
            button1 = "确定",
            button2 = "取消",
            OnAccept = function()
                HCDR_CommandHandler("reset")
            end,
            timeout = 0,
            whileDead = 1,
            hideOnEscape = 1
        }
        -- 插件加载时初始化数据
        HCDR_InitializeData()
    elseif event == "PLAYER_LOGIN" then
        -- 玩家登录后确保界面更新
        HCDR_UpdateDisplay()
		-- 加载时自动执行 .hcm 命令 
        local realmKey = HCDR_GetRealmKey()
        -- 获取保存的等级，如果没有则使用默认值1
        local level = (HCDR_Settings[realmKey] and HCDR_Settings[realmKey].Receivedeathmessagelevel) or 1
        -- 执行命令
		SendChatMessage(".hcm "..level)
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
            feastMinLevel = 60, -- 吃席消息的默认等级限制
            condolenceMinLevel = 60, -- 默认自动给60级及以上的死亡玩家发送哀悼消息
            Receivedeathmessagelevel = 1,  -- 默认接收1级以上的死亡消息
            levelFilter = "all",  -- 等级筛选设置
            feastChannel = "world", -- 默认使用world频道
			customFeastText = "哦豁！哦豁！又嘎一个。上菜了，老板请客！", -- 默认吃席内容
			customCondolenceText = "你如星辰，虽已陨落，但光芒永存，照亮我们前行的道路.", -- 默认悼念内容
			shouldAtWithLevel = false,  -- 新增：默认开启艾特对方(包含等级)
        }
    end
    
	-- 确保艾特对方设置存在
    if HCDR_Settings[realmKey].shouldAtWithLevel == nil then
        HCDR_Settings[realmKey].shouldAtWithLevel = true
    end
	
    -- 确保频道设置存在
    if not HCDR_Settings[realmKey].feastChannel then
        HCDR_Settings[realmKey].feastChannel = "world"
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
        
        -- 更新哀悼等级输入框文本
        if HCDR_CondolenceLevelEditBox then
            HCDR_CondolenceLevelEditBox:SetText(tostring(HCDR_Settings[realmKey].condolenceMinLevel or 60))
        end
        
        -- 更新吃席等级输入框文本
        if HCDR_FeastLevelEditBox then
            HCDR_FeastLevelEditBox:SetText(tostring(HCDR_Settings[realmKey].feastMinLevel or 60))
        end
        
        -- 更接收死亡消息等级输入框文本
        if LevelFilterEditBox then
            LevelFilterEditBox:SetText(tostring(HCDR_Settings[realmKey].Receivedeathmessagelevel or 1))
        end
		
		-- 更接等级筛选按钮状态
        if LevelFilterButtons and LevelFilterButtons[1] then
            LevelFilterButtons[1]:SetChecked(1)
            HCDR_CurrentLevelFilter = levelRanges[1]
        end
		
		-- 在初始化时直接设置输入框内容
		if HCDR_CustomFeastEditBox then
			HCDR_CustomFeastEditBox:SetText(HCDR_Settings[realmKey].customFeastText or "哦豁！又嘎一个。上菜了，老板请客！")
		end
		
		if HCDR_CustomCondolenceEditBox then
			HCDR_CustomCondolenceEditBox:SetText(HCDR_Settings[realmKey].customCondolenceText or "你如星辰，虽已陨落，但光芒永存，照亮我们前行的道路")
		end
		
		if HCDR_ShouldAtCheckbox then
			HCDR_ShouldAtCheckbox:SetChecked(HCDR_Settings[realmKey].shouldAtWithLevel or false)
		end
    end
    
    -- DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99专家模式死亡讣告|r：数据已初始化 for " .. realmKey)
end

-- 修改死亡消息处理函数，使用正确的等级格式匹配
function HCDR_ProcessDeathMessage(msg)
    local realmKey = HCDR_GetRealmKey()
    local currentTime = time()
    
    -- 尝试匹配各种死亡消息格式
    local charName, level, killer, zone
    
    -- 尝试匹配PVP死亡消息
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
    
    -- 尝试匹配PVE死亡消息
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
    
    -- 尝试匹配溺亡消息
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
    
    -- 尝试匹配年老死亡消息
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
    
    -- 尝试匹配活活烧死消息
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
    -- 尝试匹配中文括号中的等级数字
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

-- 4. 修改消息发送函数，确保使用自定义文本
-- 修改消息发送函数 HCDR_Automaticallysendbanquetmessages
-- 根据设置决定是否在消息后追加"@角色名 LV等级"
function HCDR_Automaticallysendbanquetmessages(charName, charLevel)
    local realmKey = HCDR_GetRealmKey()
    local level = charLevel
    local pureName = charName
    
    -- 检查是否启用自动发送吃席消息并且角色等级达到设定值
    if HCDR_Settings[realmKey].autoSendFeast and level >= HCDR_Settings[realmKey].feastMinLevel then
        local channelSetting = HCDR_Settings[realmKey].feastChannel or "world"
        local message = HCDR_Settings[realmKey].customFeastText or "哦豁！又嘎一个。上菜了，老板请客！"
        
        -- 根据设置决定是否追加艾特和等级信息
        if HCDR_Settings[realmKey].shouldAtWithLevel then
            message = message.."  @"..pureName.." LV"..level
        end
        
        if channelSetting == "Hardcore" then
            SendChatMessage(message, "Hardcore")
        elseif channelSetting == "world" then
            for i=0, 10 do
                local id, name = GetChannelName(i);
                if name == "world" then
                    SendChatMessage(message, "CHANNEL", nil, id)
                end
            end
        end
    end
end

function HCDR_CheckAndSendCondolence(charName, charLevel)
    local realmKey = HCDR_GetRealmKey()
    
    -- 检查是否启用自动发送哀悼消息
    if HCDR_Settings[realmKey].autoSendCondolence then
        -- 直接从参数获取等级信息，不再需要从名称中解析
        local level = charLevel or 0
        local pureName = charName or ""
        
        -- 检查角色等级是否达到设定值
        if level >= HCDR_Settings[realmKey].condolenceMinLevel then
            local message = HCDR_Settings[realmKey].customCondolenceText or "你如星辰，虽已陨落，但光芒永存，照亮我们前行的道路"
            SendChatMessage(message, "WHISPER", nil, pureName)
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
    
	-- 设置复制按钮
    row.copyBtn:SetWidth(50)
    row.copyBtn:SetHeight(20)
    row.copyBtn:SetPoint("TOPLEFT", 920, yPos - 2)
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

-- 新增分页控件组件
local PagePrefixText = HCDR_Frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
PagePrefixText:SetPoint("BOTTOM", -50, 25)
PagePrefixText:SetText("第")

-- 创建页码输入框
local PageEditBox = CreateFrame("EditBox", "HCDR_PageEditBox", HCDR_Frame, "InputBoxTemplate")
PageEditBox:SetWidth(20)
PageEditBox:SetHeight(20)
PageEditBox:SetPoint("LEFT", PagePrefixText, "RIGHT", 5, 0)
PageEditBox:SetAutoFocus(false)
PageEditBox:SetNumeric(true)
PageEditBox:SetMaxLetters(4)
PageEditBox:SetText("1")

-- 页码输入框事件处理
PageEditBox:SetScript("OnEscapePressed", function()
    this:ClearFocus()
end)

PageEditBox:SetScript("OnEnterPressed", function()
    this:ClearFocus()
    local pageNum = tonumber(this:GetText()) or 1
    local realmKey = HCDR_GetRealmKey()
    local serverData = HCDR_Data[realmKey] or {}
    local totalEntries = table.getn(serverData)
    local totalPages = totalEntries > 0 and math.ceil(totalEntries / 10) or 1
    
    if pageNum < 1 then pageNum = 1 end
    if pageNum > totalPages then pageNum = totalPages end
    
    HCDR_CurrentPage = pageNum
    HCDR_UpdateDisplay()
end)

PageEditBox:SetScript("OnEditFocusLost", function()
    local pageNum = tonumber(this:GetText()) or 1
    local realmKey = HCDR_GetRealmKey()
    local serverData = HCDR_Data[realmKey] or {}
    local totalEntries = table.getn(serverData)
    local totalPages = totalEntries > 0 and math.ceil(totalEntries / 10) or 1
    
    if pageNum < 1 then pageNum = 1 end
    if pageNum > totalPages then pageNum = totalPages end
    
    this:SetText(tostring(pageNum))
    HCDR_CurrentPage = pageNum
    HCDR_UpdateDisplay()
end)

local PageSuffixText = HCDR_Frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
PageSuffixText:SetPoint("LEFT", PageEditBox, "RIGHT", 5, 0)
PageSuffixText:SetText("页 / 总 x 页")


-- 上一页按钮
local PrevButton = CreateFrame("Button", nil, HCDR_Frame, "UIPanelButtonTemplate")
PrevButton:SetWidth(60)
PrevButton:SetHeight(22)
PrevButton:SetPoint("BOTTOMLEFT", 350, 20)
PrevButton:SetText("上一页")
PrevButton:Disable()

-- 首页按钮
local FirstPageButton = CreateFrame("Button", nil, HCDR_Frame, "UIPanelButtonTemplate")
FirstPageButton:SetWidth(60)
FirstPageButton:SetHeight(22)
FirstPageButton:SetPoint("RIGHT", PrevButton, "LEFT", -10, 0)
FirstPageButton:SetText("首页")
FirstPageButton:Disable()

-- 下一页按钮
local NextButton = CreateFrame("Button", nil, HCDR_Frame, "UIPanelButtonTemplate")
NextButton:SetWidth(60)
NextButton:SetHeight(22)
NextButton:SetPoint("BOTTOMRIGHT", -350, 20)
NextButton:SetText("下一页")

-- 尾页按钮
local LastPageButton = CreateFrame("Button", nil, HCDR_Frame, "UIPanelButtonTemplate")
LastPageButton:SetWidth(60)
LastPageButton:SetHeight(22)
LastPageButton:SetPoint("LEFT", NextButton, "RIGHT", 10, 0)
LastPageButton:SetText("尾页")

-- Author
local AuthorText = HCDR_Frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
AuthorText:SetPoint("LEFT", LastPageButton, "RIGHT", 160, 0)
AuthorText:SetText("by Shirley.")


-- 添加设置按钮 
local OpenSettingsButton = CreateFrame("Button", nil, HCDR_Frame, "UIPanelButtonTemplate")
OpenSettingsButton:SetWidth(60)
OpenSettingsButton:SetHeight(22)
OpenSettingsButton:SetPoint("TOPRIGHT", -170, -20)
OpenSettingsButton:SetText("设置")
OpenSettingsButton:SetScript("OnClick", function()
	-- 点击设置后关闭主窗口
	HCDR_Frame:Hide()
    HCDR_SettingsFrame:Show()
end)

-- 添加删除所有数据按钮
local DeleteAllButton = CreateFrame("Button", nil, HCDR_Frame, "UIPanelButtonTemplate")
DeleteAllButton:SetWidth(120)
DeleteAllButton:SetHeight(22)
DeleteAllButton:SetPoint("TOPRIGHT", -50, -20)
DeleteAllButton:SetText("删除所有数据")

--  添加设置界面 
local HCDR_SettingsFrame = CreateFrame("Frame", "HCDR_SettingsFrame", UIParent)
-- 确保设置界面置顶
HCDR_SettingsFrame:SetFrameStrata("DIALOG")  -- 设置为对话框层级
HCDR_SettingsFrame:SetToplevel(true)         -- 设置为顶级窗口

HCDR_SettingsFrame:SetWidth(400)
HCDR_SettingsFrame:SetHeight(250) -- 增加高度以容纳新控件
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


-- 设置界面标题
local SettingsTitle = HCDR_SettingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
SettingsTitle:SetPoint("TOP", 0, -15)
SettingsTitle:SetText("|cFFFFD700专家模式死亡讣告 - 设置|r")

-- 设置界面关闭按钮
local SettingsCloseButton = CreateFrame("Button", "HCDR_SettingsCloseButton", HCDR_SettingsFrame, "UIPanelCloseButton")
SettingsCloseButton:SetPoint("TOPRIGHT", HCDR_SettingsFrame, "TOPRIGHT", -7, -7)
SettingsCloseButton:SetScript("OnClick", function()
    HCDR_SettingsFrame:Hide()
end)

-- 添加自动发送吃席复选框
local HCDR_AutoSendCheckbox = CreateFrame("CheckButton", "HCDR_AutoSendCheckbox", HCDR_SettingsFrame, "UICheckButtonTemplate")
HCDR_AutoSendCheckbox:SetWidth(20)
HCDR_AutoSendCheckbox:SetHeight(20)
HCDR_AutoSendCheckbox:SetPoint("TOPLEFT", 20, -50)

-- 添加复选框文本
local AutoSendText = HCDR_SettingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
AutoSendText:SetPoint("LEFT", HCDR_AutoSendCheckbox, "RIGHT", 5, 0)
AutoSendText:SetText("自动吃席")

-- 添加吃席消息等级输入框
local HCDR_FeastLevelEditBox = CreateFrame("EditBox", "HCDR_FeastLevelEditBox", HCDR_SettingsFrame, "InputBoxTemplate")
HCDR_FeastLevelEditBox:SetWidth(20)
HCDR_FeastLevelEditBox:SetHeight(20)
HCDR_FeastLevelEditBox:SetPoint("LEFT", AutoSendText, "RIGHT", 10, 0)
HCDR_FeastLevelEditBox:SetAutoFocus(false)
HCDR_FeastLevelEditBox:SetNumeric(true)
HCDR_FeastLevelEditBox:SetMaxLetters(2)
HCDR_FeastLevelEditBox:SetText("60")

-- 添加吃席等级文本
local FeastLevelText = HCDR_SettingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
FeastLevelText:SetPoint("LEFT", HCDR_FeastLevelEditBox, "RIGHT", 5, 0)
FeastLevelText:SetText("级及以上")

HCDR_AutoSendCheckbox:SetScript("OnClick", function()
    local realmKey = HCDR_GetRealmKey()
    local isChecked = this:GetChecked() and true or false
    
    -- 当用户勾选复选框时显示提示
    if isChecked then
        StaticPopup_Show("HCDR_CONFIRM_FEAST")
    else
        -- 直接保存禁用状态
        HCDR_Settings[realmKey].autoSendFeast = isChecked
        DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99专家模式死亡讣告|r：已禁用自动发送吃席消息")
    end
end)

-- 设置吃席等级输入框的事件处理
HCDR_FeastLevelEditBox:SetScript("OnEscapePressed", function()
	local realmKey = HCDR_GetRealmKey()
    local text = this:GetText()
    local level = tonumber(text) or 1
    
    -- 确保等级在有效范围内
    if level < 1 then
        level = 1
    elseif level > 60 then
        level = 60
    end
	
	DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99专家模式死亡讣告|r：自动发送吃席消息等级修改为"..level.."级及以上！")
	
	-- 失去焦点
    this:ClearFocus()
end)

HCDR_FeastLevelEditBox:SetScript("OnEnterPressed", function()
	local realmKey = HCDR_GetRealmKey()
    local text = this:GetText()
    local level = tonumber(text) or 1
    
    -- 确保等级在有效范围内
    if level < 1 then
        level = 1
    elseif level > 60 then
        level = 60
    end
	
	DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99专家模式死亡讣告|r：自动发送吃席消息等级修改为"..level.."级及以上！")
	
	-- 失去焦点
    this:ClearFocus()
end)

HCDR_FeastLevelEditBox:SetScript("OnTextChanged", function()
    local realmKey = HCDR_GetRealmKey()
    local text = this:GetText()
    local level = tonumber(text) or 1
    
    -- 确保等级在有效范围内
    if level < 1 then
        level = 1
    elseif level > 60 then
        level = 60
    end
	
    HCDR_Settings[realmKey].feastMinLevel = level
    this:SetText(tostring(level))
end)

HCDR_FeastLevelEditBox:SetScript("OnEditFocusLost", function()
    local realmKey = HCDR_GetRealmKey()
    local text = this:GetText()
    local level = tonumber(text) or 1
    
    -- 确保等级在有效范围内
    if level < 1 then
        level = 1
    elseif level > 60 then
        level = 60
    end
    
    HCDR_Settings[realmKey].feastMinLevel = level
    this:SetText(tostring(level))
end)



-- 创建下拉框
local channelDropdown = CreateFrame("Frame", "HCDR_ChannelDropdown", HCDR_SettingsFrame, "UIDropDownMenuTemplate")
channelDropdown:SetPoint("LEFT", FeastLevelText, "RIGHT", 0, -2)
channelDropdown:SetWidth(150)

-- 修改下拉框初始化函数
local function InitializeChannelDropdown(self, level, menuList)
    local realmKey = HCDR_GetRealmKey()
    local currentChannel = HCDR_Settings[realmKey].feastChannel or "Hardcore"
    
    local info = {}
    
    -- 硬核频道选项
    info.text = "硬核频道"
    info.value = "Hardcore"
    info.checked = (currentChannel == "Hardcore")
    info.func = function(button)
        -- 保存设置
        local realmKey = HCDR_GetRealmKey()
        HCDR_Settings[realmKey].feastChannel = "Hardcore"
        -- 更新显示文本
        UIDropDownMenu_SetText("硬核频道", channelDropdown)
    end
    UIDropDownMenu_AddButton(info)
    
    -- World频道选项
    info = {}
    info.text = "World频道"
    info.value = "world"
    info.checked = (currentChannel == "world")
    info.func = function(button)
        -- 保存设置
        local realmKey = HCDR_GetRealmKey()
        HCDR_Settings[realmKey].feastChannel = "world"
        -- 更新显示文本
        UIDropDownMenu_SetText("World频道", channelDropdown)
    end
    UIDropDownMenu_AddButton(info)
    
    -- 确保设置正确的选中状态
    UIDropDownMenu_SetSelectedValue(channelDropdown, currentChannel)
end

HCDR_SettingsFrame:SetScript("OnShow", function()
    -- 确保数据已经初始化
    HCDR_InitializeData()
    
    local realmKey = HCDR_GetRealmKey()
    
	-- 新增：更新是否艾特对方复选框状态
    if HCDR_ShouldAtCheckbox then
        HCDR_ShouldAtCheckbox:SetChecked(HCDR_Settings[realmKey].shouldAtWithLevel or false)
    end
	
    -- 更新复选框状态
    if HCDR_AutoSendCheckbox then
        HCDR_AutoSendCheckbox:SetChecked(HCDR_Settings[realmKey].autoSendFeast or false)
    end
    
    if HCDR_AutoSendCondolenceCheckbox then
        HCDR_AutoSendCondolenceCheckbox:SetChecked(HCDR_Settings[realmKey].autoSendCondolence or false)
    end
    
    if HCDR_FeastLevelEditBox then
        HCDR_FeastLevelEditBox:SetText(tostring(HCDR_Settings[realmKey].feastMinLevel or 60))
    end
    
    if HCDR_CondolenceLevelEditBox then
        HCDR_CondolenceLevelEditBox:SetText(tostring(HCDR_Settings[realmKey].condolenceMinLevel or 60))
    end
    
    if LevelFilterEditBox then
        LevelFilterEditBox:SetText(tostring(HCDR_Settings[realmKey].Receivedeathmessagelevel or 1))
    end
    
    -- 下拉框初始化
    local channelSetting = HCDR_Settings[realmKey].feastChannel or "Hardcore"
    UIDropDownMenu_Initialize(channelDropdown, InitializeChannelDropdown)
    if channelSetting == "Hardcore" then
        UIDropDownMenu_SetText("硬核频道", channelDropdown)
    else
        UIDropDownMenu_SetText("世界频道", channelDropdown)
    end
end)

-- 确保在插件加载时初始化下拉菜单
HCDR_SettingsFrame:SetScript("OnShow", function()
    UIDropDownMenu_Initialize(channelDropdown, InitializeChannelDropdown)
end)


-- 添加自动发送哀悼消息复选框
local HCDR_AutoSendCondolenceCheckbox = CreateFrame("CheckButton", "HCDR_AutoSendCondolenceCheckbox", HCDR_SettingsFrame, "UICheckButtonTemplate")
HCDR_AutoSendCondolenceCheckbox:SetWidth(20)
HCDR_AutoSendCondolenceCheckbox:SetHeight(20)
HCDR_AutoSendCondolenceCheckbox:SetPoint("TOPLEFT", 20, -80)

-- 添加哀悼复选框文本
local CondolenceText = HCDR_SettingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
CondolenceText:SetPoint("LEFT", HCDR_AutoSendCondolenceCheckbox, "RIGHT", 5, 0)
CondolenceText:SetText("自动悼念")

-- 添加哀悼等级输入框
local HCDR_CondolenceLevelEditBox = CreateFrame("EditBox", "HCDR_CondolenceLevelEditBox", HCDR_SettingsFrame, "InputBoxTemplate")
HCDR_CondolenceLevelEditBox:SetWidth(20)
HCDR_CondolenceLevelEditBox:SetHeight(20)
HCDR_CondolenceLevelEditBox:SetPoint("LEFT", CondolenceText, "RIGHT", 10, 0)
HCDR_CondolenceLevelEditBox:SetAutoFocus(false)
HCDR_CondolenceLevelEditBox:SetNumeric(true)
HCDR_CondolenceLevelEditBox:SetMaxLetters(2)
HCDR_CondolenceLevelEditBox:SetText("60")

-- 添加哀悼等级文本
local CondolenceLevelText = HCDR_SettingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
CondolenceLevelText:SetPoint("LEFT", HCDR_CondolenceLevelEditBox, "RIGHT", 5, 0)
CondolenceLevelText:SetText("级及以上")

-- 设置哀悼复选框的事件处理
HCDR_AutoSendCondolenceCheckbox:SetScript("OnClick", function()
    local realmKey = HCDR_GetRealmKey()
    local isChecked = this:GetChecked() and true or false
    
    -- 当用户勾选复选框时显示提示
    if isChecked then
        StaticPopup_Show("HCDR_CONFIRM_CONDOLENCE")
    else
        -- 直接保存禁用状态
        HCDR_Settings[realmKey].autoSendCondolence = isChecked
        DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99专家模式死亡讣告|r：已禁用自动发送哀悼消息")
    end
end)

-- 设置哀悼等级输入框的事件处理
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

-- 消息接收

-- 创建左侧文本
local ReceiveText = HCDR_SettingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
ReceiveText:SetPoint("TOPLEFT", HCDR_SettingsFrame, "TOPLEFT", 20, -110)
ReceiveText:SetText("接收")

-- 创建等级输入框
LevelFilterEditBox = CreateFrame("EditBox", "HC_LevelFilterEditBox", HCDR_SettingsFrame, "InputBoxTemplate")
LevelFilterEditBox:SetPoint("LEFT", ReceiveText, "RIGHT", 5, 0)
LevelFilterEditBox:SetWidth(20)
LevelFilterEditBox:SetHeight(20)
LevelFilterEditBox:SetAutoFocus(false)
LevelFilterEditBox:SetText("1")

-- 创建右侧文本
local RightText = HCDR_SettingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
RightText:SetPoint("LEFT", LevelFilterEditBox, "RIGHT", 5, 0)
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


-- 在设置界面代码中找到"接收X级以上死亡消息"控件后添加以下代码
-- 位置：在"接收X级以上死亡消息"控件下方（约Y坐标-140）

-- 自定义吃席内容标题
local CustomFeastText = HCDR_SettingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
CustomFeastText:SetPoint("TOPLEFT", 20, -140)
CustomFeastText:SetText("自定义吃席内容")

-- 新增：是否艾特对方复选框
local HCDR_ShouldAtCheckbox = CreateFrame("CheckButton", "HCDR_ShouldAtCheckbox", HCDR_SettingsFrame, "UICheckButtonTemplate")
HCDR_ShouldAtCheckbox:SetWidth(20)
HCDR_ShouldAtCheckbox:SetHeight(20)
HCDR_ShouldAtCheckbox:SetPoint("TOPLEFT", 150, -136)  -- 在自定义吃席内容下方

-- 添加复选框文本
local ShouldAtText = HCDR_SettingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
ShouldAtText:SetPoint("LEFT", HCDR_ShouldAtCheckbox, "RIGHT", 5, 0)
ShouldAtText:SetText("是否艾特对方")

-- 设置复选框点击事件
HCDR_ShouldAtCheckbox:SetScript("OnClick", function()
    local realmKey = HCDR_GetRealmKey()
    local isChecked = this:GetChecked() and true or false
    HCDR_Settings[realmKey].shouldAtWithLevel = isChecked
    
    if isChecked then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99专家模式死亡讣告|r：已启用发送吃席消息时艾特对方")
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99专家模式死亡讣告|r：已禁用发送吃席消息时艾特对方")
    end
end)

-- 自定义吃席内容输入框
local HCDR_CustomFeastEditBox = CreateFrame("EditBox", "HCDR_CustomFeastEditBox", HCDR_SettingsFrame, "InputBoxTemplate")
HCDR_CustomFeastEditBox:SetWidth(350)
HCDR_CustomFeastEditBox:SetHeight(20)
HCDR_CustomFeastEditBox:SetPoint("TOPLEFT", CustomFeastText, "BOTTOMLEFT", 0, -5)
HCDR_CustomFeastEditBox:SetAutoFocus(false)

-- 自定义悼念内容标题
local CustomCondolenceText = HCDR_SettingsFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
CustomCondolenceText:SetPoint("TOPLEFT", HCDR_CustomFeastEditBox, "BOTTOMLEFT", 0, -10)
CustomCondolenceText:SetText("自定义悼念内容")

-- 自定义悼念内容输入框
local HCDR_CustomCondolenceEditBox = CreateFrame("EditBox", "HCDR_CustomCondolenceEditBox", HCDR_SettingsFrame, "InputBoxTemplate")
HCDR_CustomCondolenceEditBox:SetWidth(350)
HCDR_CustomCondolenceEditBox:SetHeight(20)
HCDR_CustomCondolenceEditBox:SetPoint("TOPLEFT", CustomCondolenceText, "BOTTOMLEFT", 0, -5)
HCDR_CustomCondolenceEditBox:SetAutoFocus(false)

-- 增加设置界面高度以适应新控件
HCDR_SettingsFrame:SetHeight(300) -- 从250增加到300


-- 自定义吃席内容输入框事件处理
HCDR_CustomFeastEditBox:SetScript("OnEscapePressed", function()
    this:ClearFocus()
end)

HCDR_CustomFeastEditBox:SetScript("OnEnterPressed", function()
    this:ClearFocus()
end)

-- 自定义吃席内容输入框事件处理
HCDR_CustomFeastEditBox:SetScript("OnEditFocusLost", function()
    local realmKey = HCDR_GetRealmKey()
    local text = this:GetText()
    -- 确保设置表存在
    if not HCDR_Settings[realmKey] then
        HCDR_Settings[realmKey] = {}
    end
    HCDR_Settings[realmKey].customFeastText = text
    DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99专家模式死亡讣告|r：自定义吃席内容已保存")
end)

-- 自定义悼念内容输入框事件处理
HCDR_CustomCondolenceEditBox:SetScript("OnEscapePressed", function()
    this:ClearFocus()
end)

HCDR_CustomCondolenceEditBox:SetScript("OnEnterPressed", function()
    this:ClearFocus()
end)

-- 自定义悼念内容输入框事件处理
HCDR_CustomCondolenceEditBox:SetScript("OnEditFocusLost", function()
    local realmKey = HCDR_GetRealmKey()
    local text = this:GetText()
    -- 确保设置表存在
    if not HCDR_Settings[realmKey] then
        HCDR_Settings[realmKey] = {}
    end
    HCDR_Settings[realmKey].customCondolenceText = text
    DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99专家模式死亡讣告|r：自定义悼念内容已保存")
end)




-- 显示函数以支持等级筛选
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

    -- 分页文本
    PageSuffixText:SetText("页 / 总 "..totalPages.." 页")
	PageEditBox:SetText(tostring(HCDR_CurrentPage))
    
    -- 按钮状态
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
    
    -- 表格行
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

-- 创建复制面板
local HCDR_CopyFrame = CreateFrame("Frame", "HCDR_CopyFrame", UIParent)
-- 确保设置界面置顶
HCDR_CopyFrame:SetFrameStrata("DIALOG")  -- 设置为对话框层级
HCDR_CopyFrame:SetToplevel(true)         -- 设置为顶级窗口
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

-- 创建编辑框
local CopyEditBox = CreateFrame("EditBox", "HCDR_CopyEditBox", HCDR_CopyFrame)
CopyEditBox:SetWidth(550)
CopyEditBox:SetHeight(120)  -- 增加高度以容纳多行文本
CopyEditBox:SetMultiLine(true)  -- 设置为多行
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
	-- 点击复制后关闭主窗口
	HCDR_Frame:Hide()
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
    {text = "全部", min = 0, max = 100}
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
    StaticPopup_Show("HCDR_CONFIRM_DELETE_ALL")
end)

-- 初始隐藏框架
HCDR_Frame:Hide()

-- 在插件加载时立即初始化
HCDR_InitializeData()