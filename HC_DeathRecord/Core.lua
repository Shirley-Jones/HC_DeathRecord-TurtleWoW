-- Core.lua
-- 插件核心：变量定义、事件处理、数据初始化、死亡消息解析
HCDR_Constants = HCDR_Constants or {}
-- 全局存储变量 - 按服务器独立存储
HCDR_Data = HCDR_Data or {}
HCDR_Settings = HCDR_Settings or {}
HCDR_CooldownEndTime = HCDR_CooldownEndTime or 0
HCDR_CurrentPage = HCDR_CurrentPage or 1
HCDR_SearchTerm = HCDR_SearchTerm or ""
HCDR_IsSearching = HCDR_IsSearching or false
HCDR_CurrentLevelFilter = HCDR_CurrentLevelFilter or {min=0, max=100, text="全部"} -- 默认筛选全部等级

-- 主框架和设置框架引用（在其他文件中创建）
HCDR_Frame = nil
HCDR_SettingsFrame = nil
HCDR_CopyFrame = nil

-- 等级筛选范围定义
HCDR_LevelRanges = {
    {text = "1-10", min = 1, max = 10},
    {text = "10-20", min = 10, max = 20},
    {text = "20-30", min = 20, max = 30},
    {text = "30-40", min = 30, max = 40},
    {text = "40-50", min = 40, max = 50},
    {text = "50-60", min = 50, max = 60},
    {text = "全部", min = 0, max = 100}
}

-- 死亡消息匹配模式
HCDR_DeathPatterns = {
    -- PVP死亡
    {pattern = "悲剧发生了。硬核角色 (.+)（等级 (%d+)）在 PvP 中落败于 (.+)。这件事发生在 (.+)。愿这一牺牲不会被忘记。", deathType = "PVP"},
    -- PVE死亡
    {pattern = "悲剧发生了。硬核角色 (.+)（等级 (%d+)）被 (.+)击杀。这发生在 (.+)。愿这一牺牲不会被忘记。", deathType = "PVE"},
    -- 溺亡
    {pattern = "悲剧发生了。硬核角色 (.+)（等级 (%d+)）已在 (.+) 中溺亡。愿这一牺牲永不被遗忘。", deathType = "其他", killer = "溺亡"},
    -- 年老死亡
    {pattern = "悲剧发生了。硬核角色 (.+)（等级 (%d+)）于 (.+) 年因年老而去世。愿这一牺牲不会被忘记。", deathType = "其他", killer = "年老死亡(DOT)"},
    -- 活活烧死
    {pattern = "悲剧发生了。硬核角色 (.+)（等级 (%d+)）在 (.+) 被活活烧死。愿这一牺牲永不被遗忘。", deathType = "其他", killer = "活活烧死"}
}

-- 主事件处理框架
local HCDR_CoreFrame = CreateFrame("Frame")
HCDR_CoreFrame:RegisterEvent("CHAT_MSG_SYSTEM")
HCDR_CoreFrame:RegisterEvent("ADDON_LOADED")
HCDR_CoreFrame:RegisterEvent("PLAYER_LOGIN")

HCDR_CoreFrame:SetScript("OnEvent", function()
    if event == "CHAT_MSG_SYSTEM" then
        local message = arg1
        if string.find(message, "悲剧发生了。") then
            HCDR_ProcessDeathMessage(message)
        end
    elseif event == "ADDON_LOADED" and arg1 == "HC_DeathRecord" then
        HCDR_InitializeStaticPopups()
        HCDR_InitializeData()
    elseif event == "PLAYER_LOGIN" then
        if HCDR_UpdateDisplay then
            HCDR_UpdateDisplay()
        end
        HCDR_AutoSetDeathMessageLevel()
    end
end)

-- 初始化静态对话框
function HCDR_InitializeStaticPopups()
    StaticPopupDialogs["HCDR_CONFIRM_FEAST"] = {
        text = "是否开启自动发送吃席消息到硬核频道？此功能可能会对别人造成骚扰。",
        button1 = "接受",
        button2 = "取消",
        OnAccept = function()
            local realmKey = HCDR_GetRealmKey()
            HCDR_Settings[realmKey].autoSendFeast = true
            if HCDR_AutoSendCheckbox then
                HCDR_AutoSendCheckbox:SetChecked(true)
            end
        end,
        OnCancel = function()
            if HCDR_AutoSendCheckbox then
                HCDR_AutoSendCheckbox:SetChecked(false)
            end
        end,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1
    }
    
    StaticPopupDialogs["HCDR_CONFIRM_CONDOLENCE"] = {
        text = "是否开启自动发送悼念消息？此功能可能会对别人造成骚扰。",
        button1 = "接受",
        button2 = "取消",
        OnAccept = function()
            local realmKey = HCDR_GetRealmKey()
            HCDR_Settings[realmKey].autoSendCondolence = true
            if HCDR_AutoSendCondolenceCheckbox then
                HCDR_AutoSendCondolenceCheckbox:SetChecked(true)
            end
        end,
        OnCancel = function()
            if HCDR_AutoSendCondolenceCheckbox then
                HCDR_AutoSendCondolenceCheckbox:SetChecked(false)
            end
        end,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1
    }
    
    StaticPopupDialogs["HCDR_CONFIRM_DELETE_ALL"] = {
        text = "是否删除所有数据？此操作不可撤销。",
        button1 = "接受",
        button2 = "取消",
        OnAccept = function()
            HCDR_CommandHandler("reset")
        end,
        timeout = 0,
        whileDead = 1,
        hideOnEscape = 1
    }
end

-- 初始化数据
function HCDR_InitializeData()
    local realmKey = HCDR_GetRealmKey()
    
    if not HCDR_Data[realmKey] then
        HCDR_Data[realmKey] = {}
    end
    
    if not HCDR_Settings[realmKey] then
        HCDR_Settings[realmKey] = { 
            autoSendFeast = false, 
            autoSendCondolence = false,
            feastMinLevel = HCDR_Constants.DEFAULT_FEAST_MIN_LEVEL or 60,
            condolenceMinLevel = HCDR_Constants.DEFAULT_CONDOLENCE_MIN_LEVEL or 60,
            Receivedeathmessagelevel = HCDR_Constants.DEFAULT_RECEIVE_LEVEL or 1,
            feastChannel = HCDR_Constants.DEFAULT_FEAST_CHANNEL or "world",
            customFeastText = HCDR_Constants.DEFAULT_CUSTOM_FEAST_TEXT or "风，带走了又一位勇士。酒，斟满了整个旅店。敬永不消逝的冒险精神！这席，我替大家先吃了！",
            customCondolenceText = HCDR_Constants.DEFAULT_CUSTOM_CONDOLENCE_TEXT or "你如星辰，虽已陨落，但光芒永存，照亮我们前行的道路",
            shouldAtWithLevel = false,
            feastCooldown = HCDR_Constants.DEFAULT_FEAST_COOLDOWN or 60,
        }
    end
    
    -- 确保关键设置存在
    local defaults = {
        shouldAtWithLevel = true,
        feastCooldown = HCDR_Constants.DEFAULT_FEAST_COOLDOWN or 60,
        feastChannel = HCDR_Constants.DEFAULT_FEAST_CHANNEL or "world",
    }
    for key, val in pairs(defaults) do
        if HCDR_Settings[realmKey][key] == nil then
            HCDR_Settings[realmKey][key] = val
        end
    end
end

-- 处理死亡消息
function HCDR_ProcessDeathMessage(msg)
    local realmKey = HCDR_GetRealmKey()
    local currentTime = time()
    
    for _, patternInfo in ipairs(HCDR_DeathPatterns) do
        local charName, level, killer, zone
        
        if patternInfo.killer then -- 有固定killer的模式（溺亡、年老、烧死）
            charName, level, zone = string.match(msg, patternInfo.pattern)
            killer = patternInfo.killer
        else -- 需要捕获killer的模式（PVP, PVE）
            charName, level, killer, zone = string.match(msg, patternInfo.pattern)
        end
        
        if charName then
            level = tonumber(level)
            table.insert(HCDR_Data[realmKey], 1, {
                charName = charName,
                deathType = patternInfo.deathType,
                killer = killer or "未知",
                zone = zone or "未知区域",
                time = currentTime,
                rawMessage = msg,
                level = level
            })
            
            -- 触发消息发送
            HCDR_Automaticallysendbanquetmessages(charName, level)
            HCDR_CheckAndSendCondolence(charName, level)
            
            if HCDR_UpdateDisplay then
                HCDR_UpdateDisplay()
            end
            return
        end
    end
    
    -- 没有匹配到任何已知格式
    DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99硬核模式死亡讣告：|r检测到死亡消息但未匹配具体格式,如果可以,请复制这个死亡消息并发送给开发添加匹配~")
end

-- 自动设置接收死亡消息等级
function HCDR_AutoSetDeathMessageLevel()
    local realmKey = HCDR_GetRealmKey()
    local level = (HCDR_Settings[realmKey] and HCDR_Settings[realmKey].Receivedeathmessagelevel) or 1
    SendChatMessage(".hcm "..level)
end
