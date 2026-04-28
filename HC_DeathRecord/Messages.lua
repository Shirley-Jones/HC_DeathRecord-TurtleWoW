-- Messages.lua
-- 处理自动消息的发送（吃席、悼念）

-- 自动发送吃席消息
function HCDR_Automaticallysendbanquetmessages(charName, charLevel)
    local realmKey = HCDR_GetRealmKey()
    local level = charLevel
    local pureName = charName
    
    -- 检查冷却
    local currentTime = time()
    if currentTime < HCDR_CooldownEndTime then
        return
    end
    
    if HCDR_Settings[realmKey].autoSendFeast and level >= HCDR_Settings[realmKey].feastMinLevel then
        local channelSetting = HCDR_Settings[realmKey].feastChannel or HCDR_Constants.DEFAULT_FEAST_CHANNEL or "world"
        local message = HCDR_Settings[realmKey].customFeastText or HCDR_Constants.DEFAULT_CUSTOM_FEAST_TEXT or "风，带走了又一位勇士。酒，斟满了整个旅店。敬永不消逝的冒险精神！这席，我替大家先吃了！"
        
        if HCDR_Settings[realmKey].shouldAtWithLevel then
            message = message.."  @"..pureName.." LV"..level
        end
        
        -- 立即发送消息
        HCDR_SendFeastMessage(message, channelSetting, realmKey)
        
        -- 设置冷却
        local cooldownSeconds = HCDR_Settings[realmKey].feastCooldown or HCDR_Constants.DEFAULT_FEAST_COOLDOWN or 60
        HCDR_CooldownEndTime = currentTime + cooldownSeconds
    end
end

-- 实际发送吃席消息的函数
function HCDR_SendFeastMessage(message, channelSetting, realmKey)
    if channelSetting == "Hardcore" then
        SendChatMessage(message, "Hardcore")
    elseif channelSetting == "world" then
        for i=0, 10 do
            local id, name = GetChannelName(i);
            if name == "world" then
                SendChatMessage(message, "CHANNEL", nil, id)
                break
            end
        end
    end
end

-- 检查并发送悼念消息
function HCDR_CheckAndSendCondolence(charName, charLevel)
    local realmKey = HCDR_GetRealmKey()
    
    if HCDR_Settings[realmKey].autoSendCondolence then
        local level = charLevel or 0
        local pureName = charName or ""
        
        if level >= HCDR_Settings[realmKey].condolenceMinLevel then
            local message = HCDR_Settings[realmKey].customCondolenceText or HCDR_Constants.DEFAULT_CUSTOM_CONDOLENCE_TEXT or "你如星辰，虽已陨落，但光芒永存，照亮我们前行的道路"
            SendChatMessage(message, "WHISPER", nil, pureName)
        end
    end
end