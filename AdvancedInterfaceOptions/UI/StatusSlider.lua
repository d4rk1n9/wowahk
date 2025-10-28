local addon, ns = ...
local AdvancedInterfaceOptions = _G[addon]
local log = ns.logger;

-- 初始化保存变量
if not AdvancedInterfaceOptionsProDB then
    AdvancedInterfaceOptionsProDB = {}
end

-- 位置存储表
if not AdvancedInterfaceOptionsProDB.compactPos then
    AdvancedInterfaceOptionsProDB.compactPos = nil
end

-- 确保所有必要字段都存在
if AdvancedInterfaceOptionsProDB.uiMode == nil then
    AdvancedInterfaceOptionsProDB.uiMode = "compact"     -- 只保留精简模式
end


-- 确保AdvancedInterfaceOptions数据库中的override字段存在
C_Timer.After(0.1, function()
    if AdvancedInterfaceOptions and AdvancedInterfaceOptions.DB and AdvancedInterfaceOptions.DB.profile and AdvancedInterfaceOptions.DB.profile.toggles and AdvancedInterfaceOptions.DB.profile.toggles.essences then
        if AdvancedInterfaceOptions.DB.profile.toggles.essences.override == nil then
            AdvancedInterfaceOptions.DB.profile.toggles.essences.override = false -- 次要爆发联动状态
        end
    end
end)


-- UI显示模式：只保留compact(精简)
local uiMode = "compact"

-- 精简模式按钮全局变量
local compactBtnPause, compactBtnCD, compactBtnMinorCD, compactBtnInterrupt, compactBtnDefensives, compactBtnPotion, compactBtnMode



-- 创建精简模式UI
local cpCompact = CreateFrame('Frame', 'AdvancedInterfaceOptions_Pro_Compact', UIParent)

-- 位置保存/加载
local function SaveCompactPosition()
	local point, relativeTo, relativePoint, xOfs, yOfs = cpCompact:GetPoint(1)
	local relativeName = relativeTo and relativeTo:GetName() or "UIParent"
	AdvancedInterfaceOptionsProDB.compactPos = {
		point = point,
		relativeTo = relativeName,
		relativePoint = relativePoint,
		x = xOfs,
		y = yOfs,
	}
end

local function LoadCompactPosition()
	cpCompact:ClearAllPoints()
	local pos = AdvancedInterfaceOptionsProDB.compactPos
	if pos and pos.point and pos.relativePoint then
		local rel = _G[pos.relativeTo] or UIParent
		cpCompact:SetPoint(pos.point, rel, pos.relativePoint, pos.x or 0, pos.y or 0)
		return
	end
	-- 默认定位：在 AdvancedInterfaceOptions 上方
	if AdvancedInterfaceOptionsDisplayPrimary then
		cpCompact:SetPoint('BOTTOMLEFT', AdvancedInterfaceOptionsDisplayPrimary, 'TOPLEFT', 0, 1)
	else
		cpCompact:SetPoint('TOPLEFT', MultiBarBottomLeft or UIParent, 'BOTTOMLEFT', 0, 50)
	end
end

-- 精简模式位置设置
C_Timer.After(1, function()
	LoadCompactPosition()
	-- 在定位完成后创建按钮
	createCompactButtons()
end)


cpCompact:SetSize(178, 24)  -- 增加宽度，为右侧拖拽手柄预留空间
-- 启用拖拽移动
cpCompact:SetMovable(true)
cpCompact:EnableMouse(true)  -- 支持按钮点击与拖拽
cpCompact:SetClampedToScreen(true)
cpCompact:RegisterForDrag("LeftButton")
cpCompact:SetScript('OnDragStart', function(self)
	self:StartMoving()
end)
cpCompact:SetScript('OnDragStop', function(self)
	self:StopMovingOrSizing()
	SaveCompactPosition()
end)
-- 不调用 SetUserPlaced()，避免与系统布局冲突

-- 添加ndui风格的背景
local bg = cpCompact:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints(cpCompact)
bg:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
bg:SetVertexColor(0, 0, 0, 0.3)  -- 半透明黑色背景

-- 添加边框效果
local border = CreateFrame("Frame", nil, cpCompact, "BackdropTemplate")
border:SetAllPoints(cpCompact)
border:SetBackdrop({
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
})
border:SetBackdropBorderColor(0, 0, 0, 1)  -- 深灰色边框

cpCompact:SetFrameStrata("MEDIUM")
cpCompact:Show()  -- 默认显示精简模式
cpCompact:SetAlpha(1)

-- 右侧拖拽手柄（仅作为拖拽提示与操作柄）
local dragHandle = CreateFrame("Button", nil, cpCompact)
dragHandle:SetSize(12, 20)
dragHandle:SetPoint("RIGHT", cpCompact, "RIGHT", -2, 0)
dragHandle:RegisterForDrag("LeftButton")

-- 三条竖向握把纹理
local grip1 = dragHandle:CreateTexture(nil, "ARTWORK")
grip1:SetColorTexture(1, 1, 1, 0.6)
grip1:SetSize(1, 12)
grip1:SetPoint("CENTER", dragHandle, "CENTER", -3, 0)

local grip2 = dragHandle:CreateTexture(nil, "ARTWORK")
grip2:SetColorTexture(1, 1, 1, 0.6)
grip2:SetSize(1, 12)
grip2:SetPoint("CENTER", dragHandle, "CENTER", 0, 0)

local grip3 = dragHandle:CreateTexture(nil, "ARTWORK")
grip3:SetColorTexture(1, 1, 1, 0.6)
grip3:SetSize(1, 12)
grip3:SetPoint("CENTER", dragHandle, "CENTER", 3, 0)

dragHandle:SetScript("OnDragStart", function()
    cpCompact:StartMoving()
end)
dragHandle:SetScript("OnDragStop", function()
    cpCompact:StopMovingOrSizing()
    SaveCompactPosition()
end)
dragHandle:SetScript("OnEnter", function()
    GameTooltip:SetOwner(dragHandle, "ANCHOR_TOP")
    GameTooltip:SetText("按住左键拖拽移动\n按住Ctrl + 左键隐藏提示")
    GameTooltip:Show()
end)
--添加Ctrl + 鼠标左键事件
dragHandle:SetScript("OnMouseDown", function(self, button)
    if button == "LeftButton" and IsControlKeyDown() then
        AdvancedInterfaceOptions.DB.profile.displays.Primary.states.enabled = false
    end
end)
dragHandle:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

-- 模式切换按钮字典
local AdvancedInterfaceOptions_mode_dict = {
    ["automatic"] = "自",
    ["single"] = "单",
    ["aoe"] = "群",
}

-- 精简模式按钮配置
local compactButtonConfigs = {
    {
        var = "compactBtnPause",
        name = "CompactPauseButton",
        text = "启",
        getter = function() return not AdvancedInterfaceOptions.Pause end,
        onClick = function() AdvancedInterfaceOptions.Pause = not AdvancedInterfaceOptions.Pause end,
        anchor = { "TOPLEFT", cpCompact, "TOPLEFT", 3, -2 },

        tip = function()
            local keyText = AdvancedInterfaceOptions.DB.profile.toggles.pause.key or "未设置"
            local linkText = (AdvancedInterfaceOptions.DB.profile.toggles.essences and AdvancedInterfaceOptions.DB.profile.toggles.essences.override) and "|cff00ff00开启|r" or "|cffff0000关闭|r"
            return string.format("开启/暂停\n快捷键: %s\n右键点击打开主界面", keyText)
        end
    },
    {
        var = "compactBtnCD",
        name = "CompactCDButton",
        text = function()
            return "爆"
        end,
        getter = function() return AdvancedInterfaceOptions.DB.profile.toggles.cooldowns.value end,
        setter = function(v) 
            AdvancedInterfaceOptions:FireToggle('cooldowns') 
            -- 检查是否需要联动次要爆发
            if AdvancedInterfaceOptions.DB.profile.toggles.cooldowns.value and 
               AdvancedInterfaceOptions.DB.profile.toggles.essences and 
               AdvancedInterfaceOptions.DB.profile.toggles.essences.override then
                -- 如果主要爆发开启且设置了联动，同时开启次要爆发
                if not AdvancedInterfaceOptions.DB.profile.toggles.essences.value then
                    AdvancedInterfaceOptions:FireToggle('essences')
                end
            end

                -- 检查是否需要联动次要爆发
            if (not AdvancedInterfaceOptions.DB.profile.toggles.cooldowns.value) and 
               AdvancedInterfaceOptions.DB.profile.toggles.essences and 
               AdvancedInterfaceOptions.DB.profile.toggles.essences.override then
                -- 如果主要爆发开启且设置了联动，同时关闭次要爆发
                if AdvancedInterfaceOptions.DB.profile.toggles.essences.value then
                    AdvancedInterfaceOptions:FireToggle('essences')
                end
            end
        end,
        anchor = { "LEFT", "compactBtnPause", "RIGHT", 3, 0 },
        tip = function()
            local keyText = AdvancedInterfaceOptions.DB.profile.toggles.cooldowns.key or "未设置"
            local autoText = AdvancedInterfaceOptions.DB.profile.toggles.autoCooldown.value and "|cff00ff00开启|r" or "|cffff0000关闭|r"
            local linkText = (AdvancedInterfaceOptions.DB.profile.toggles.essences and AdvancedInterfaceOptions.DB.profile.toggles.essences.override) and "|cff00ff00开启|r" or "|cffff0000关闭|r"
            return string.format("主要爆发\n快捷键: %s\n摆烂模式: %s\n右键点击开关摆烂模式\n", keyText, autoText, linkText)
        end
    },
    {
        var = "compactBtnMinorCD",
        name = "CompactMinorCDButton",
        text = function()
            local isLinked = (AdvancedInterfaceOptions.DB.profile.toggles.essences and AdvancedInterfaceOptions.DB.profile.toggles.essences.override)
            return isLinked and "次" or "次"
        end,
        getter = function() return AdvancedInterfaceOptions.DB.profile.toggles.essences.value end,
        setter = function(v) AdvancedInterfaceOptions:FireToggle('essences') end,
        anchor = { "LEFT", "compactBtnCD", "RIGHT", 3, 0 },
        tip = function()
            local keyText = AdvancedInterfaceOptions.DB.profile.toggles.essences.key or "未设置"
            local isLinked = (AdvancedInterfaceOptions.DB.profile.toggles.essences and AdvancedInterfaceOptions.DB.profile.toggles.essences.override)
            local linkText = isLinked and "|cff00ff00开启|r" or "|cffff0000关闭|r"
            return string.format("次要爆发\n快捷键: %s\n主次爆发联动: %s\n\n右键切换主次爆发联动", keyText, linkText)
        end
    },
    {
        var = "compactBtnInterrupt",
        name = "CompactInterruptButton",
        text = "D",
        getter = function()  
            local specialization = GetSpecialization()
            local specID = specialization and GetSpecializationInfo(specialization)
            local spec = rawget(AdvancedInterfaceOptions.DB.profile.specs, specID)
            return spec.cycle
        end,
        setter = function(v) AdvancedInterfaceOptions:DOTSCAN() end,
        anchor = { "LEFT", "compactBtnMinorCD", "RIGHT", 3, 0 },
        tip = function()
            return "Dot扫描\n开启后部分职业会自动切换目标上Dot"
        end
    },
    {
        var = "compactBtnCrazyDog",
        name = "CompactDefensivesButton",
        text = "疯",
        getter = function() return AdvancedInterfaceOptions.DB.profile.toggles.crazyDog.value end,
        setter = function(v) AdvancedInterfaceOptions:FireToggle('crazyDog') end,
        anchor = { "LEFT", "compactBtnInterrupt", "RIGHT", 3, 0 },
        tip = function()
            return "疯狗\n快捷键" .. (AdvancedInterfaceOptions.DB.profile.toggles.crazyDog.key or "未设置")
        end
    },
    {
        var = "compactBtnPotion",
        name = "CompactPotionButton",
        text = "药",
        getter = function() return AdvancedInterfaceOptions.DB.profile.toggles.potions.value end,
        setter = function(v) AdvancedInterfaceOptions:FireToggle('potions') end,
        anchor = { "LEFT", "compactBtnCrazyDog", "RIGHT", 3, 0 },
        tip = function()
            return "药剂\n" .. (AdvancedInterfaceOptions.DB.profile.toggles.potions.key or "未设置")
        end
    },
    {
        var = "compactBtnMode",
        name = "CompactModeButton",
        text = function() return AdvancedInterfaceOptions_mode_dict[AdvancedInterfaceOptions.DB.profile.toggles.mode.value] or "自" end,
        getter = function() return true end,  -- 模式按钮始终显示为激活状态
        onClick = function()
            -- 直接调用AdvancedInterfaceOptions内置的模式切换功能
            AdvancedInterfaceOptions:FireToggle('mode')
        end,
        anchor = { "LEFT", "compactBtnPotion", "RIGHT", 3, 0 },
        tip = function()
             return "当前模式: " .. (AdvancedInterfaceOptions_mode_dict[AdvancedInterfaceOptions.DB.profile.toggles.mode.value] or "自动") .. "\n快捷键:" .. (AdvancedInterfaceOptions.DB.profile.toggles.mode.key or "未设置")
        end
    }
}

-- 精简模式按钮创建函数
function createCompactButtons()
    for _, config in ipairs(compactButtonConfigs) do
        -- 处理anchor中的字符串引用
        if type(config.anchor[2]) == "string" then
            config.anchor[2] = _G[config.anchor[2]]
        end
        
        -- 创建按钮并赋值给全局变量
        local buttonConfig = {
            name = config.name,
            text = config.text,
            getter = config.getter,
            setter = config.setter,
            onClick = config.onClick,
            width = 20,
            height = 20,
            anchor = config.anchor,
            tip = config.tip
        }
        
        _G[config.var] = ns.createCompactButton(buttonConfig)
    end
end


-- 精简模式按钮创建函数
function ns.createCompactButton(config)
    local button = CreateFrame("Button", config.name, cpCompact)
    button:SetSize(config.width or 20, config.height or 20)
    
    if config.anchor then
        button:SetPoint(unpack(config.anchor))
    end
    
    -- 处理text参数，支持函数类型
    local buttonText = config.text or ""
    if type(buttonText) == "function" then
        buttonText = buttonText()
    end
    button:SetText(buttonText)
    button:SetNormalFontObject("GameFontNormalSmall")
    
    -- 放大字体：在现有字体基础上增大2号，保持原字体族与描边
    do
        local fs = button:GetFontString()
        if fs then
            local fontPath, fontSize, fontFlags = fs:GetFont()
            fs:SetFont(fontPath, (fontSize or 10) + 4, fontFlags)
        end
    end
    
    -- 设置初始状态颜色
    local isActive = config.getter()
    local r, g, b = 0.2, 0.2, 0.2  -- 默认灰色
    if isActive then
        r, g, b = 0, 1, 0  -- 绿色表示激活
    end
    button:GetFontString():SetTextColor(r, g, b)
    
    -- 点击事件处理
    button:SetScript("OnClick", function(self, mouseButton)
        if mouseButton == "RightButton" and config.name == "CompactCDButton" then
            AdvancedInterfaceOptions.DB.profile.toggles.cooldown_safe.value = true
            AdvancedInterfaceOptions:FireToggle("cooldown_safe"); ns.UI.Minimap:RefreshDataText()
            AdvancedInterfaceOptions:FireToggle("autoCooldown"); ns.UI.Minimap:RefreshDataText()
            -- 立即刷新提示信息
            if GameTooltip:IsOwned(button) then
                local tipText = type(config.tip) == "function" and config.tip() or config.tip
                GameTooltip:SetText(tipText)
                GameTooltip:Show()
            end
        elseif mouseButton == "RightButton" and config.name == "CompactMinorCDButton" then
            -- 右键点击次要爆发按钮：切换联动选项
            if AdvancedInterfaceOptions.DB.profile.toggles.essences then
                AdvancedInterfaceOptions.DB.profile.toggles.essences.override = not AdvancedInterfaceOptions.DB.profile.toggles.essences.override
                -- 更新按钮文字
                if type(config.text) == "function" then
                    button:SetText(config.text())
                end
                -- 立即刷新提示信息
                if GameTooltip:IsOwned(button) then
                    local tipText = type(config.tip) == "function" and config.tip() or config.tip
                    GameTooltip:SetText(tipText)
                    GameTooltip:Show()
                end
            end
        elseif mouseButton == "RightButton" and config.name == "CompactPauseButton" then
            AdvancedInterfaceOptions:CmdLine()
        else
            -- 左键点击：正常功能
            if config.onClick then
                config.onClick()
            else
                local newValue = not config.getter()
                config.setter(newValue)
            end
        end
        
        -- 更新按钮文本（支持动态文本）
        if config.text and type(config.text) == "function" then
            button:SetText(config.text())
        end

    end)
    
    -- 注册右键点击
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    
    -- 鼠标悬停提示
    if config.tip then
        button:SetScript("OnEnter", function()
            GameTooltip:SetOwner(button, "ANCHOR_TOP")
            local tipText = type(config.tip) == "function" and config.tip() or config.tip
            GameTooltip:SetText(tipText)
            GameTooltip:Show()
        end)
        
        button:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end
    
    return button
end


local function SetDisplayMode(mode)
    AdvancedInterfaceOptions.DB.profile.toggles.mode.value = mode
    if WeakAuras and WeakAuras.ScanEvents then
        WeakAuras.ScanEvents('AdvancedInterfaceOptions_TOGGLE', 'mode', mode)
    end
    AdvancedInterfaceOptions:UpdateDisplayVisibility()
    AdvancedInterfaceOptions:ForceUpdate('AdvancedInterfaceOptions_TOGGLE', true)
end


-- 根据当前字体大小与文本动态调整按钮和容器宽度，避免重叠
local function UpdateCompactLayout()
    if not cpCompact or not _G.compactBtnPause then return end

    local horizontalGap = 3
    local leftPadding = 3
    local rightHandlePadding = 6 -- 拖拽手柄与按钮组之间的额外留白

    local buttonsInOrder = {
        _G.compactBtnPause,
        _G.compactBtnCD,
        _G.compactBtnMinorCD,
        _G.compactBtnInterrupt,
        _G.compactBtnCrazyDog,
        _G.compactBtnPotion,
        _G.compactBtnMode,
    }

    local totalWidth = leftPadding
    for index, btn in ipairs(buttonsInOrder) do
        if btn and btn:GetFontString() then
            local fs = btn:GetFontString()
            local textWidth = fs:GetStringWidth() or 0
            local desiredWidth = math.max(math.ceil(textWidth + 10), 20) -- 文本左右各留白
            btn:SetWidth(desiredWidth)

            if index > 1 then
                totalWidth = totalWidth + horizontalGap
            end
            totalWidth = totalWidth + desiredWidth
        end
    end

    -- 预留拖拽手柄与少量边距
    local handleWidth = 12
    local finalWidth = totalWidth + rightHandlePadding + handleWidth + 2 -- 再加1px边框余量
    cpCompact:SetWidth(finalWidth)
end


-- 更新精简模式按钮状态的函数
local function UpdateCompactButtonStates()
    if AdvancedInterfaceOptionsDisplayPrimary and cpCompact and cpCompact:IsVisible() and _G.compactBtnPause then
        -- 红色渐变色彩定义（从左到右渐变）- 从深红到亮红
        local gradientColors = {
            {0.20, 0.80, 0.20},    -- 深绿色（最左）
            {0.25, 0.85, 0.25},    -- 深绿过渡色1
            {0.30, 0.90, 0.30},    -- 深绿过渡色2
            {0.35, 0.95, 0.35},    -- 中绿色
            {0.40, 1.00, 0.40},    -- 亮绿色
            {0.45, 1.00, 0.45},    -- 更亮绿色
            {0.50, 1.00, 0.50}     -- 最亮绿色（最右）
        }
        local inactiveGray = {0.3, 0.3, 0.3}     -- 未激活灰色
            local specialization = GetSpecialization()
        local specID = specialization and GetSpecializationInfo(specialization)
        local spec = rawget(AdvancedInterfaceOptions.DB.profile.specs, specID)
        local tempSp = function()
            if spec then
                return spec.cycle
            end
            return false
        end
        local buttons = {
            {btn = _G.compactBtnPause, active = not AdvancedInterfaceOptions.Pause, colorIndex = 1},
            {btn = _G.compactBtnCD, active = AdvancedInterfaceOptions.DB.profile.toggles.cooldowns.value, colorIndex = 2},
            {btn = _G.compactBtnMinorCD, active = AdvancedInterfaceOptions.DB.profile.toggles.essences.value, colorIndex = 3},
            {btn = _G.compactBtnInterrupt, active = tempSp(), colorIndex = 4},
            
            {btn = _G.compactBtnCrazyDog, active = AdvancedInterfaceOptions.DB.profile.toggles.crazyDog.value, colorIndex = 5},
            {btn = _G.compactBtnPotion, active = AdvancedInterfaceOptions.DB.profile.toggles.potions.value, colorIndex = 6},
            {btn = _G.compactBtnMode, active = true, colorIndex = 7}  -- 模式按钮总是激活
        }
        
        -- 更新每个按钮的颜色
        for _, buttonInfo in ipairs(buttons) do
            local r, g, b
            if buttonInfo.active then
                r, g, b = unpack(gradientColors[buttonInfo.colorIndex])
            else
                r, g, b = unpack(inactiveGray)
            end
            buttonInfo.btn:GetFontString():SetTextColor(r, g, b)

            do
                local fs = buttonInfo.btn:GetFontString()
                if fs then
                    local fontPath, fontSize, fontFlags = fs:GetFont()
                    fs:SetFont(fontPath, (AdvancedInterfaceOptions.DB.profile.displays.Primary.states.fontSize or 14), fontFlags) 
                end
            end
        end
        
        -- 特殊处理模式按钮颜色（根据模式显示不同颜色）
        local currentMode = AdvancedInterfaceOptions.DB.profile.toggles.mode.value
        local modeR, modeG, modeB
        if currentMode == "automatic" then
            modeR, modeG, modeB = 0, 1, 0  -- 自：绿色
        elseif currentMode == "aoe" then
            modeR, modeG, modeB = 0, 0.5, 1  -- 群：蓝色
        elseif currentMode == "single" then
            modeR, modeG, modeB = 1, 0, 0  -- 单：红色
        else
            modeR, modeG, modeB = unpack(gradientColors[7])  -- 其他模式：使用渐变色
        end
        _G.compactBtnMode:GetFontString():SetTextColor(modeR, modeG, modeB)
        
        -- 特殊处理启停按钮文字
        _G.compactBtnPause:SetText(AdvancedInterfaceOptions.Pause and "停" or "启")
        
        _G.compactBtnCD:SetText("爆")
        
        -- 特殊处理次要爆发按钮文字（联动状态显示）
        local isLinked = (AdvancedInterfaceOptions.DB.profile.toggles.essences and AdvancedInterfaceOptions.DB.profile.toggles.essences.override)
        _G.compactBtnMinorCD:SetText(isLinked and "次" or "次")
        
        -- 特殊处理模式按钮文字
        _G.compactBtnMode:SetText(AdvancedInterfaceOptions_mode_dict[AdvancedInterfaceOptions.DB.profile.toggles.mode.value] or "自")
        
        -- 根据最新字体与文本宽度调整按钮与容器布局
        UpdateCompactLayout()
    end
end


-- 创建一个帧来持续更新按钮状态
local updateFrame = CreateFrame("Frame")
updateFrame:SetScript("OnUpdate", function()
    UpdateCompactButtonStates()
end)

-- 爆发状态监控系统
local lastCooldownsState = false
local monitorFrame = CreateFrame("Frame")

local function monitorCooldownsState()
    if not AdvancedInterfaceOptions or not AdvancedInterfaceOptions.DB or not AdvancedInterfaceOptions.DB.profile or not AdvancedInterfaceOptions.DB.profile.toggles then
        return
    end
    
    local currentState = AdvancedInterfaceOptions.DB.profile.toggles.cooldowns.value
    
    -- 检测状态变化
    if currentState ~= lastCooldownsState then
        lastCooldownsState = currentState
        
        if currentState then
            -- 检查是否需要联动次要爆发
            if AdvancedInterfaceOptions.DB.profile.toggles.essences and 
               AdvancedInterfaceOptions.DB.profile.toggles.essences.override and
               not AdvancedInterfaceOptions.DB.profile.toggles.essences.value then
                AdvancedInterfaceOptions:FireToggle('essences')
            end
        else
            -- 检查是否需要联动次要爆发
            if AdvancedInterfaceOptions.DB.profile.toggles.essences and 
               AdvancedInterfaceOptions.DB.profile.toggles.essences.override and
               AdvancedInterfaceOptions.DB.profile.toggles.essences.value then
                    AdvancedInterfaceOptions:FireToggle('essences')
            end
        end
    end


    if AdvancedInterfaceOptions.DB.profile.displays.Primary.states.enabled and cpCompact  then
        if not cpCompact:IsShown() then
            cpCompact:Show()
        end
    else
        if  cpCompact:IsShown() then
            cpCompact:Hide()
        end
    end

end

-- 设置监控帧的OnUpdate脚本，每0.1秒检查一次状态
local lastCheck = 0
monitorFrame:SetScript("OnUpdate", function(self, elapsed)
    lastCheck = lastCheck + elapsed
    if lastCheck >= 0.1 then
        monitorCooldownsState()
        lastCheck = 0
    end
end)

-- 初始化监控系统
C_Timer.After(1, function()
    if AdvancedInterfaceOptions and AdvancedInterfaceOptions.DB and AdvancedInterfaceOptions.DB.profile and AdvancedInterfaceOptions.DB.profile.toggles then
        lastCooldownsState = AdvancedInterfaceOptions.DB.profile.toggles.cooldowns.value
    end
end)

-- UI模式初始化：只显示精简模式
C_Timer.After(2, function()
    cpCompact:Show()
end)