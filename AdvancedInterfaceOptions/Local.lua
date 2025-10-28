local addon, ns = ...
local AdvancedInterfaceOptions = _G[addon]
AdvancedInterfaceOptions.Local = {}

if GetLocale() == "zhTW" then

AdvancedInterfaceOptions.Local["zztc"] = "(種族特長)"
AdvancedInterfaceOptions.Local["notify"] = "通知欄"
AdvancedInterfaceOptions.Local["spellQueueTip"] = "技能提示"

AdvancedInterfaceOptions.Local["Leave Fighting"] = "先脫戰"
AdvancedInterfaceOptions.Local["Start"] = "開始"
AdvancedInterfaceOptions.Local["Pause"] = "暫停"

AdvancedInterfaceOptions.Local["Start Root"] = "開啟迴圈"
AdvancedInterfaceOptions.Local["Pause Root"] = "暫停迴圈"

AdvancedInterfaceOptions.Local["Burst"] = "爆發"
AdvancedInterfaceOptions.Local["Normal"] = "常規"
AdvancedInterfaceOptions.Local["Crazy Dog"] = "瘋狗"
AdvancedInterfaceOptions.Local["Crazy Dog Mode"] = "瘋狗模式"

AdvancedInterfaceOptions.Local["Auto Target"] = "自動"
AdvancedInterfaceOptions.Local["Single Target"] = "單體"
AdvancedInterfaceOptions.Local["AOE Target"] = "群體"

AdvancedInterfaceOptions.Local["Auto Target Mode"] = "|cFF00FF00自動識別|r"
AdvancedInterfaceOptions.Local["Single Target Mode"] = "|cFFFF0000強制單體|r"
AdvancedInterfaceOptions.Local["AOE Target Mode"] = "強制AOE"

AdvancedInterfaceOptions.Local["Change Mode To"] = "切換識別模式為："



AdvancedInterfaceOptions.Local["Turn On"] = "|cFF00FF00開|r"
AdvancedInterfaceOptions.Local["Turn Off"] = "|cFFFF0000關|r"

AdvancedInterfaceOptions.Local["Make CMDMarco Success"] = "|cFF00FF00成功！！！ 去專用宏裡面看看|r"

AdvancedInterfaceOptions.Local["No Loading"] = "還沒有加載任何職業專精模塊，留意群裏更新資訊"

AdvancedInterfaceOptions.Local["Level Error"] = "當等級低於50級的時候，挿件或多或少會有一些問題，適當昇陞級就好了~"

AdvancedInterfaceOptions.Local["Debuff Scan"] = "目標defBuff掃描:"

AdvancedInterfaceOptions.Local["Range Check"] = "目標距離檢測:"

AdvancedInterfaceOptions.Local["Clearn Marco Noty"] = "該操作將清理全部的通用宏為防誤刪，再點一次（脫戰才會生效哦）"

AdvancedInterfaceOptions.Local["Smart Life Restore"] = "快速戰複"

AdvancedInterfaceOptions.Local["Auto Change Target"] = "自動切換目標"

AdvancedInterfaceOptions.Local["Spell Tip"] = "技能提示"

AdvancedInterfaceOptions.Local["Covenants"] = "盟約技能"

AdvancedInterfaceOptions.Local["Useful In Fight"] = "僅戰鬥中生效"

AdvancedInterfaceOptions.Local["AOE PreView"] = "調試模式(Debug)"

AdvancedInterfaceOptions.Local["Logic optimization"] = "額外邏輯"

AdvancedInterfaceOptions.Local["Smart Brust"] = "自動控爆發"

AdvancedInterfaceOptions.Local["Smart Brust safe"] = "半自動控爆發"

AdvancedInterfaceOptions.Local["Tank Protection"] = "坦克減傷"


AdvancedInterfaceOptions.Local["Auto Interrupts"] = "自動打斷"

elseif GetLocale() == "zhCN" then
   
    AdvancedInterfaceOptions.Local["zztc"] = "(种族特长)"

    AdvancedInterfaceOptions.Local["notify"] = "通知栏"
    AdvancedInterfaceOptions.Local["spellQueueTip"] = "技能提示"

    AdvancedInterfaceOptions.Local["Leave Fighting"] = "先脱战"
    AdvancedInterfaceOptions.Local["Start"] = "开始"
    AdvancedInterfaceOptions.Local["Pause"] = "暂停"
    
    AdvancedInterfaceOptions.Local["Start Root"] = "开启循环"
    AdvancedInterfaceOptions.Local["Pause Root"] = "暂停循环"
    
    AdvancedInterfaceOptions.Local["Burst"] = "爆发"
    AdvancedInterfaceOptions.Local["Normal"] = "常规"
    AdvancedInterfaceOptions.Local["Crazy Dog"] = "疯狗"
    AdvancedInterfaceOptions.Local["Crazy Dog Mode"] = "疯狗模式"
    
    AdvancedInterfaceOptions.Local["Auto Target"] = "自动"
    AdvancedInterfaceOptions.Local["Single Target"] = "单体"
    AdvancedInterfaceOptions.Local["AOE Target"] = "群体"
    
    AdvancedInterfaceOptions.Local["Auto Target Mode"] = "|cFF00FF00自动识别|r"
    AdvancedInterfaceOptions.Local["Single Target Mode"] = "|cFFFF0000强制单体|r"
    AdvancedInterfaceOptions.Local["AOE Target Mode"] = "|cff0042ff强制AOE|r"
    
    AdvancedInterfaceOptions.Local["Change Mode To"] = "切换识别模式为："
    
    
    
    AdvancedInterfaceOptions.Local["Turn On"] = "|cFF00FF00开|r"
    AdvancedInterfaceOptions.Local["Turn Off"] = "|cFFFF0000关|r"
    
    AdvancedInterfaceOptions.Local["Make CMDMarco Success"] = "|cFF00FF00成功！！去专用宏里面看看|r"
    
    AdvancedInterfaceOptions.Local["No Loading"] = "还未更新该职业专精"
    
    AdvancedInterfaceOptions.Local["Level Error"] = "等级低于50 会有一些问题，多多练级吧"
    
    AdvancedInterfaceOptions.Local["Debuff Scan"] = "目标defBuff扫描:"

    AdvancedInterfaceOptions.Local["Range Check"] = "目标距离检测:"
    
    AdvancedInterfaceOptions.Local["Clearn Marco Noty"] = "为防止误删，请在重复一遍该操作"
    
    AdvancedInterfaceOptions.Local["Smart Life Restore"] = "快速战复"
    
    AdvancedInterfaceOptions.Local["Auto Change Target"] = "自动切换目标"
    
    AdvancedInterfaceOptions.Local["Spell Tip"] = "技能提示"
    
    AdvancedInterfaceOptions.Local["Covenants"] = "小爆发技能"
    
    AdvancedInterfaceOptions.Local["Useful In Fight"] = "仅战斗中生效"
    
    AdvancedInterfaceOptions.Local["AOE PreView"] = "调试模式(Debug)"
    
    AdvancedInterfaceOptions.Local["Logic optimization"] = "额外逻辑"
    
    AdvancedInterfaceOptions.Local["Smart Brust"] = "摆烂模式"

    AdvancedInterfaceOptions.Local["Smart Brust safe"] = "爆发技能保护"
    
    AdvancedInterfaceOptions.Local["Tank Protection"] = "减伤"
    
    
    AdvancedInterfaceOptions.Local["Auto Interrupts"] = "自动打断"


else
    
    AdvancedInterfaceOptions.Local["zztc"] = "(berserking)"

    AdvancedInterfaceOptions.Local["notify"] = "Notify Label"
    AdvancedInterfaceOptions.Local["spellQueueTip"] = "Spell Queue"

    AdvancedInterfaceOptions.Local["Leave Fighting"] = "Get out of the fight first"
    AdvancedInterfaceOptions.Local["Start"] = "Start"
    AdvancedInterfaceOptions.Local["Pause"] = "Pause"
    
    AdvancedInterfaceOptions.Local["Start Root"] = "Start"
    AdvancedInterfaceOptions.Local["Pause Root"] = "Pause"
    
    AdvancedInterfaceOptions.Local["Burst"] = "Burst"
    AdvancedInterfaceOptions.Local["Normal"] = "Normal"
    AdvancedInterfaceOptions.Local["Crazy Dog"] = "Crazy Dog"
    AdvancedInterfaceOptions.Local["Crazy Dog Mode"] = "Crazy Dog Mode"
    
    AdvancedInterfaceOptions.Local["Auto Target"] = "Auto Target"
    AdvancedInterfaceOptions.Local["Single Target"] = "Single Target"
    AdvancedInterfaceOptions.Local["AOE Target"] = "AOE Target"
    
    AdvancedInterfaceOptions.Local["Auto Target Mode"] = "|cFF00FF00Auto Target Mode|r"
    AdvancedInterfaceOptions.Local["Single Target Mode"] = "|cFFFF0000Single Target Mode|r"
    AdvancedInterfaceOptions.Local["AOE Target Mode"] = "AOE Target Mode"
    
    AdvancedInterfaceOptions.Local["Change Mode To"] = "Change Mode To："
    
    
    
    AdvancedInterfaceOptions.Local["Turn On"] = "|cFF00FF00On|r"
    AdvancedInterfaceOptions.Local["Turn Off"] = "|cFFFF0000Off|r"
    
    AdvancedInterfaceOptions.Local["Make CMDMarco Success"] = "|cFF00FF00Make CMDMarco Success!|r"
    
    AdvancedInterfaceOptions.Local["No Loading"] = "The professional expertise has not been updated"
    
    AdvancedInterfaceOptions.Local["Level Error"] = "If the level is lower than 50, there will be some problems."
    
    AdvancedInterfaceOptions.Local["Debuff Scan"] = "Target defBuff scan:"

    AdvancedInterfaceOptions.Local["Range Check"] = "Target Range Check:"
    
    AdvancedInterfaceOptions.Local["Clearn Marco Noty"] = "To prevent accidental deletion, please repeat the operation again"
    
    AdvancedInterfaceOptions.Local["Smart Life Restore"] = "Rapid recovery"
    
    AdvancedInterfaceOptions.Local["Auto Change Target"] = "Auto Change Target"
    
    AdvancedInterfaceOptions.Local["Spell Tip"] = "Spell Tip"
    
    AdvancedInterfaceOptions.Local["Covenants"] = "Covenants"
    
    AdvancedInterfaceOptions.Local["Useful In Fight"] = "Useful In Fight"
    
    AdvancedInterfaceOptions.Local["AOE PreView"] = "Debug Mode"
    
    AdvancedInterfaceOptions.Local["Logic optimization"] = "Logic optimization"
    
    AdvancedInterfaceOptions.Local["Smart Brust"] = "Auto Brust"

    AdvancedInterfaceOptions.Local["Smart Brust safe"] = "safe Brust"
    
    AdvancedInterfaceOptions.Local["Tank Protection"] = "Tank Protection"
    
    
    AdvancedInterfaceOptions.Local["Auto Interrupts"] = "Auto Interrupts"

end
