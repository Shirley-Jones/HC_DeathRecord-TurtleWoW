-- Utils.lua
-- 工具函数和命令处理

-- 获取当前服务器键
function HCDR_GetRealmKey()
    local realmName = GetRealmName() or "UnknownRealm"
    return realmName
end

-- 时间格式化
function HCDR_FormatTime(timestamp)
    local dateTable = date("*t", timestamp)
    
    local month = string.format("%02d", dateTable.month)
    local day = string.format("%02d", dateTable.day)
    local hour = string.format("%02d", dateTable.hour)
    local min = string.format("%02d", dateTable.min)
    local sec = string.format("%02d", dateTable.sec)
    
    return dateTable.year.."-"..month.."-"..day.." "..hour..":"..min..":"..sec
end

-- 从消息中提取等级
function HCDR_ExtractLevelFromName(message)
    local level = string.match(message, "（等级 (%d+)）")
    if level then
        return tonumber(level)
    end
    
    level = string.match(message, "(%d+)级")
    if level then
        return tonumber(level)
    end
    
    level = string.match(message, "悲剧发生了。硬核角色 .+（等级 (%d+)）")
    if level then
        return tonumber(level)
    end
    
    return 0
end

-- 获取筛选后的数据
function HCDR_GetFilteredData()
    local realmKey = HCDR_GetRealmKey()
    local serverData = HCDR_Data[realmKey] or {}
    
    local filteredData = {}
    for i, data in ipairs(serverData) do
        if not data.level then
            data.level = HCDR_ExtractLevelFromName(data.rawMessage or data.charName or "")
        end
        
        -- 等级筛选
        local levelMatch = true
        if HCDR_CurrentLevelFilter then
            levelMatch = (data.level >= HCDR_CurrentLevelFilter.min and data.level <= HCDR_CurrentLevelFilter.max)
        end
        
        -- 搜索筛选
        local searchMatch = true
        if HCDR_IsSearching and HCDR_SearchTerm ~= "" then
            searchMatch = false
            local searchTermLower = string.lower(HCDR_SearchTerm)
            
            local fieldsToCheck = {
                data.rawMessage or "",
                data.charName or "",
                data.killer or "",
                data.zone or ""
            }
            
            for _, field in ipairs(fieldsToCheck) do
                if string.find(string.lower(field), searchTermLower) then
                    searchMatch = true
                    break
                end
            end
        end
        
        if levelMatch and searchMatch then
            table.insert(filteredData, data)
        end
    end
    
    return filteredData
end

-- 命令处理器
function HCDR_CommandHandler(msg)
    local command = string.lower(strtrim(msg or ""))
    
    if command == "show" then
        if HCDR_Frame then
            HCDR_Frame:Show()
        end
        if HCDR_UpdateDisplay then
            HCDR_UpdateDisplay()
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99硬核模式死亡讣告|r：界面已显示")
    elseif command == "hide" then
        if HCDR_Frame then
            HCDR_Frame:Hide()
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99硬核模式死亡讣告|r：界面已隐藏")
    elseif command == "reset" then
        local realmKey = HCDR_GetRealmKey()
        HCDR_Data[realmKey] = {}
        HCDR_CurrentPage = 1
        HCDR_SearchTerm = ""
        HCDR_IsSearching = false
        if HCDR_SearchEditBox then
            HCDR_SearchEditBox:SetText("")
        end
        if HCDR_UpdateDisplay then
            HCDR_UpdateDisplay()
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99硬核模式死亡讣告|r：所有数据已删除")
    elseif string.find(command, "search ") then
        local searchTerm = string.sub(command, 8)
        if HCDR_SearchEditBox then
            HCDR_SearchEditBox:SetText(searchTerm)
        end
        HCDR_PerformSearch(searchTerm)
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99硬核模式死亡讣告 命令用法：|r")
        DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99/hcdr show|r - 显示死亡讣告界面")
        DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99/hcdr hide|r - 隐藏死亡讣告界面")
        DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99/hcdr reset|r - 重置所有死亡讣告")
        DEFAULT_CHAT_FRAME:AddMessage("|cFF33FF99/hcdr search <关键词>|r - 搜索死亡记录")
    end
end

-- 注册Slash命令
SLASH_HCDR1 = "/hcdr"
SLASH_HCDR2 = "/hcdeath"
SlashCmdList["HCDR"] = HCDR_CommandHandler
