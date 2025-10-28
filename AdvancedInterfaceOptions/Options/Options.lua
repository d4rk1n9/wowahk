-- Options.lua
-- Everything related to building/configuring options.

local addon, ns = ...
local AdvancedInterfaceOptions = _G[ addon ]

local class = AdvancedInterfaceOptions.Class
local scripts = AdvancedInterfaceOptions.Scripts
local state = AdvancedInterfaceOptions.State

local format, lower, match = string.format, string.lower, string.match
local insert, remove, sort, wipe = table.insert, table.remove, table.sort, table.wipe
local UnitBuff, UnitDebuff, SkeletonHandler = ns.UnitBuff, ns.UnitDebuff, ns.SkeletonHandler
local callHook = ns.callHook
local SpaceOut = ns.SpaceOut
local formatKey, orderedPairs, tableCopy, GetItemInfo, RangeType = ns.formatKey, ns.orderedPairs, ns.tableCopy, ns.CachedGetItemInfo, ns.RangeType

-- Atlas/Textures
local AtlasToString, GetAtlasFile, GetAtlasCoords = ns.AtlasToString, ns.GetAtlasFile, ns.GetAtlasCoords

-- Options Functions
local TableToString, StringToTable, SerializeActionPack, DeserializeActionPack, SerializeDisplay, DeserializeDisplay, SerializeStyle, DeserializeStyle

local ACD = LibStub( "AceConfigDialog-3.0" )
local LDBIcon = LibStub( "LibDBIcon-1.0", true )
local LSM = LibStub( "LibSharedMedia-3.0" )
local SF = SpellFlashCore

local NewFeature = "|TInterface\\OptionsFrame\\UI-OptionsFrame-NewFeatureIcon:0|t"
local GreenPlus = "Interface\\AddOns\\AdvancedInterfaceOptions\\Textures\\GreenPlus"
local RedX = "Interface\\AddOns\\AdvancedInterfaceOptions\\Textures\\RedX"
local BlizzBlue = "|cFF00B4FF"
local Bullet = AtlasToString( "characterupdate_arrow-bullet-point" )
local ClassColor = C_ClassColor.GetClassColor( class.file )

local GetSpellInfo = ns.GetUnpackedSpellInfo
local GetSpellDescription = C_Spell.GetSpellDescription

local GetSpecialization = C_SpecializationInfo.GetSpecialization
local GetSpecializationInfo = C_SpecializationInfo.GetSpecializationInfo



-- One Time Fixes
local oneTimeFixes = {
    resetAberrantPackageDates_20190728_1 = function( p )
        for _, v in pairs( p.packs ) do
            if type( v.date ) == 'string' then v.date = tonumber( v.date ) or 0 end
            if type( v.version ) == 'string' then v.date = tonumber( v.date ) or 0 end
            if v.date then while( v.date > 21000000 ) do v.date = v.date / 10 end end
            if v.version then while( v.version > 21000000 ) do v.version = v.version / 10 end end
        end
    end,

    forceEnableAllClassesOnceDueToBug_20220225 = function( p )
        for id, spec in pairs( p.specs ) do
            spec.enabled = true
        end
    end,

    forceReloadAllDefaultPriorities_20220228 = function( p )
        for name, pack in pairs( p.packs ) do
            if pack.builtIn then
                AdvancedInterfaceOptions.DB.profile.packs[ name ] = nil
                AdvancedInterfaceOptions:RestoreDefault( name )
            end
        end
    end,

    forceReloadClassDefaultOptions_20220306 = function( p )
        local sendMsg = false
        for spec, data in pairs( class.specs ) do
            if spec > 0 and not p.runOnce[ 'forceReloadClassDefaultOptions_20220306_' .. spec ] then
                local cfg = p.specs[ spec ]
                for k, v in pairs( data.options ) do
                    if cfg[ k ] == ns.specTemplate[ k ] and cfg[ k ] ~= v then
                        cfg[ k ] = v
                        sendMsg = true
                    end
                end
                p.runOnce[ 'forceReloadClassDefaultOptions_20220306_' .. spec ] = true
            end
        end
        if sendMsg then
            C_Timer.After( 5, function()
                if AdvancedInterfaceOptions.DB.profile.notifications.enabled then AdvancedInterfaceOptions:Notify( "Some specialization options were reset.", 6 ) end
                AdvancedInterfaceOptions:Print( "Some specialization options were reset to default; this can occur once per profile/specialization." )
            end )
        end
        p.runOnce.forceReloadClassDefaultOptions_20220306 = nil
    end,

    forceDeleteBrokenMultiDisplay_20220319 = function( p )
        if rawget( p.displays, "Multi" ) then
            p.displays.Multi = nil
        end

        p.runOnce.forceDeleteBrokenMultiDisplay_20220319 = nil
    end,

    forceSpellFlashBrightness_20221030 = function( p )
        for display, data in pairs( p.displays ) do
            if data.flash and data.flash.brightness and data.flash.brightness > 100 then
                data.flash.brightness = 100
            end
        end
    end,

    removeOldThrottles_20241115 = function( p )
        for id, spec in pairs( p.specs ) do
            spec.throttleRefresh = nil
            spec.combatRefresh   = nil
            spec.regularRefresh  = nil

            spec.throttleTime    = nil
            spec.maxTime         = nil
        end
    end,
}

function AdvancedInterfaceOptions:RunOneTimeFixes()
    local profile = AdvancedInterfaceOptions.DB.profile
    if not profile then return end

    profile.runOnce = profile.runOnce or {}

    for k, v in pairs( oneTimeFixes ) do
        if not profile.runOnce[ k ] then
            profile.runOnce[k] = true
            local ok, err = pcall( v, profile )
            if err then
                AdvancedInterfaceOptions:Error( "One-time update failed: " .. k .. ": " .. err )
                profile.runOnce[ k ] = nil
            end
        end
    end
end

function AdvancedInterfaceOptions:LoadOptionModules()
    local modules = {
        "DevTools",
        "ChatCommands",
        -- "ControlBar",
        -- "Displays",
        -- etc.
    }

    for _, m in ipairs( modules ) do
        require( "AdvancedInterfaceOptions.Options." .. m )
    end
end

local displayTemplate = {
    enabled = true,

    numIcons = 5,
    forecastPeriod = 15,

    primaryWidth = 50,
    primaryHeight = 50,

    keepAspectRatio = true,
    zoom = 30,

    frameStrata = "LOW",
    frameLevel = 10,

    elvuiCooldown = false,
    hideOmniCC = false,

    queue = {
        anchor = 'RIGHT',
        direction = 'RIGHT',
        style = 'RIGHT',
        alignment = 'CENTER',

        width = 50,
        height = 50,

        -- offset = 5, -- deprecated.
        offsetX = 5,
        offsetY = 0,
        spacing = 5,

        elvuiCooldown = false,

        --[[ font = ElvUI and 'PT Sans Narrow' or 'Arial Narrow',
        fontSize = 12,
        fontStyle = "OUTLINE" ]]
    },

    visibility = {
        advanced = false,

        mode = {
            aoe = true,
            automatic = true,
            dual = false,
            single = true,
            reactive = false,
        },

        pve = {
            alpha = 1,
            always = 1,
            target = 1,
            combat = 1,
            combatTarget = 1,
            hideMounted = false,
        },

        pvp = {
            alpha = 1,
            always = 1,
            target = 1,
            combat = 1,
            combatTarget = 1,
            hideMounted = false,
        },
    },

    border = {
        enabled = true,
        thickness = 1,
        fit = false,
        coloring = 'custom',
        color = { 0, 0, 0, 1 },
    },

    range = {
        enabled = true,
        type = 'ability',
    },

    glow = {
        enabled = false,
        queued = false,
        mode = "autocast",
        coloring = "default",
        color = { 0.95, 0.95, 0.32, 1 },

        highlight = true
    },

    flash = {
        enabled = false,
        color = { 255 / 255, 215 / 255, 0, 1 }, -- gold.
        blink = false,
        suppress = false,
        combat = false,

        size = 240,
        brightness = 100,
        speed = 0.4,

        fixedSize = false,
        fixedBrightness = false
    },

    captions = {
        enabled = false,
        queued = false,

        align = "CENTER",
        anchor = "BOTTOM",
        x = 0,
        y = 0,

        font = ElvUI and 'PT Sans Narrow' or 'Arial Narrow',
        fontSize = 12,
        fontStyle = "OUTLINE",

        color = { 1, 1, 1, 1 },
    },

    empowerment = {
        enabled = true,
        queued = true,
        glow = true,

        align = "CENTER",
        anchor = "BOTTOM",
        x = 0,
        y = 1,

        font = ElvUI and 'PT Sans Narrow' or 'Arial Narrow',
        fontSize = 16,
        fontStyle = "THICKOUTLINE",

        color = { 1, 0.8196079, 0, 1 },
    },

    indicators = {
        enabled = true,
        queued = true,

        anchor = "RIGHT",
        x = 0,
        y = 0,
                
        width = 20,
        height = 20,
        zoom = 30,
        keepAspectRatio = true,
    },

    targets = {
        enabled = true,

        font = ElvUI and 'PT Sans Narrow' or 'Arial Narrow',
        fontSize = 24,
        fontStyle = "OUTLINE",

        anchor = "BOTTOMRIGHT",
        x = 0,
        y = 0,

        color = { 1, 1, 1, 1 },
    },

    delays = {
        type = "__NA",
        fade = false,
        extend = true,
        elvuiCooldowns = false,

        font = ElvUI and 'PT Sans Narrow' or 'Arial Narrow',
        fontSize = 12,
        fontStyle = "OUTLINE",

        anchor = "TOPLEFT",
        x = 0,
        y = 0,

        color = { 1, 1, 1, 1 },
    },

    keybindings = {
        enabled = true,
        queued = true,

        font = ElvUI and "PT Sans Narrow" or "Arial Narrow",
        fontSize = 14,
        fontStyle = "OUTLINE",

        lowercase = false,

        separateQueueStyle = false,

        queuedFont = ElvUI and "PT Sans Narrow" or "Arial Narrow",
        queuedFontSize = 30,
        queuedFontStyle = "OUTLINE",

        queuedLowercase = false,

        anchor = "BOTTOM",
        x = 1,
        y = -20,

        cPortOverride = true,
        cPortZoom = 0.6,

        color = { 1, 1, 1, 1 },
        queuedColor = { 1, 1, 1, 1 },
    },

    --lj
    states = {
        enabled = true,
        queued = true,

        font = ElvUI and "PT Sans Narrow" or "Arial Narrow",
        fontSize = 20,
        fontStyle = "OUTLINE",

        lowercase = false,

        separateQueueStyle = false,

        queuedFont = ElvUI and "PT Sans Narrow" or "Arial Narrow",
        queuedFontSize = 20,
        queuedFontStyle = "OUTLINE",

        queuedLowercase = false,

        anchor = "BOTTOM",
        x = 50,
        y = -30,

        cPortOverride = true,
        cPortZoom = 0.6,

        color = { 1, 1, 1, 1 },
        queuedColor = { 1, 1, 1, 1 },
    },

}

local actionTemplate = {
    action = "heart_essence",
    enabled = true,
    criteria = "",
    caption = "",
    description = "",

    -- Shared Modifiers
    early_chain_if = "",  -- NYI

    cycle_targets = 0,
    max_cycle_targets = 3,
    max_energy = 0,

    interrupt = 0,  --NYI
    interrupt_if = "",  --NYI
    interrupt_immediate = 0,  -- NYI

    travel_speed = nil,

    enable_moving = false,
    moving = nil,
    sync = "",

    use_while_casting = 0,
    use_off_gcd = 0,
    only_cwc = 0,

    wait_on_ready = 0, -- NYI

    -- Call/Run Action List
    list_name = nil,
    strict = nil,
    strict_if = "",

    -- Pool Resource
    wait = "0.5",
    for_next = 0,
    extra_amount = "0",

    -- Variable
    op = "set",
    condition = "",
    default = "",
    value = "",
    value_else = "",
    var_name = "unnamed",

    -- Wait
    sec = "1",
}

local packTemplate = {
    spec = 0,
    builtIn = false,
    author = AdvancedInterfaceOptions:authorname(),
    desc = AdvancedInterfaceOptions:authornameDes(),
    source = "",
    date = tonumber( date("%Y%M%D.%H%M") ),
    warnings = "",

    hidden = false,

    lists = {
        healthStone = {
            {
                enabled = true,
                action = "healthstone",
                criteria = "",
            },
        },
        precombat = {
            {
                enabled = false,
                action = "heart_essence",
            },
        },
        default = {
            {
                enabled = false,
                action = "heart_essence",
            },
        },
    }
}

local specTemplate = ns.specTemplate

do
    local defaults

    -- Default Table
    function AdvancedInterfaceOptions:GetDefaults()
        defaults = defaults or {
            global = {
                styles = {},
            },

            profile = {
                enabled = true,
                minimapIcon = false,
                autoSnapshot = false,
                screenshot = false,

                flashTexture = "Interface\\Cooldown\\star4",
                performance = {
                    frameBudget = 0.8,
                },
                toggles = {
                    pause = {
                        key = "R",
                    },

                    snapshot = {
                        key = "",
                    },

                    mode = {
                        key = "CTRL-Q",
                        value = "automatic",
                        -- type = "AutoSingle",
                        automatic = true,
                        single = true,
                        reactive = false,
                        dual = false,
                        aoe = false,
                    },

                    cooldowns = {
                        key = "CTRL-R",
                        value = true,
                        infusion = false,
                        override = false,
                        separate = false,
                    },

                    defensives = {
                        key = "",
                        value = true,
                        separate = false,
                    },

                    potions = {
                        key = "",
                        value = false,
                        override = false,
                    },

                    interrupts = {
                        key = "",
                        value = true,
                        separate = false,
                        filterCasts = false,
                        castRemainingThreshold = 0.5,
                    },

                    essences = {
                        key = "",
                        value = true,
                        override = true,
                    },
                    funnel = {
                        key = "",
                        value = false,
                    },

                    custom1 = {
                        key = "",
                        value = false,
                        name = "自定义 #1"
                    },

                    custom2 = {
                        key = "",
                        value = false,
                        name = "自定义 #1"
                    },
                    --LJ---------修改
                    iconHidden = {
                        value = false,
                    },
                    visCombat = {
                        value = false,
                    },
                    autoCooldown = {
                        value = false,
                        closeTime = 0.3
                    },
                    cooldown_safe = {
                        override = true,
                        value = false,
                    },
                    target_AOE = {
                        override = true,
                        value = false,
                        distance = 0
                    },
                    target_distance_check = {
                        override = true,
                        value = false,
                        distance = 0
                    },
                    targetSelect = {
                        key = "X",
                        value = true,
                        override = true,
                        autoSelec_force = false
                    },
                    crazyDog = {
                        key = "Z",
                        value = true,
                        override = true
                    },

                    enable_items = {
                        key = "",
                        value = true,
                        override = true
                    },             

                    FastRestOnFighting = {
                        value = false,
                        override = true
                    },
                    debugMode = {
                        value = false,
                        override = true
                    },
                    mouseAmi = {
                        value = false,
                        override = true
                    },
                    gseMode = {
                        value = false,
                        override = true
                    },
                    --LJ清理lj宏
                    LJAutoDeleMarco = {
                        value = true,
                        override = true
                    },

                    --LJ 读条保护
                    CannelSpellSafe = {
                        value = false,
                        override = true
                    },

                    --GCD阈值
                    GCDThoredMode = {
                        value = 0.3,
                        override = true
                    },

                    --断条白名单
                    InputExcMode = {
                        value = "",
                        override = true
                    },

                    --假人白名单
                    jiarenExcMode = {
                        value = "",
                        override = true
                    },
                    potions_hp = {
                        value = false,
                        override = true,
                        threshold = 30
                    },
                    potions_stone = {
                        value = false,
                        override = true,
                        threshold = 30
                    },
                    potions_mp = {
                        value = false,
                        override = true,
                        threshold = 30
                    }
                },

                specs = {
                    -- ['**'] = specTemplate
                },

                packs = {
                    ['**'] = packTemplate
                },

                AI_Enabled = {
                    value = true,
                    override = true,
                },

                notifications = {
                    enabled = true,

                    x = 0,
                    y = 0,

                    font = ElvUI and "Expressway" or "Arial Narrow",
                    fontSize = 20,
                    fontStyle = "OUTLINE",
                    color = { 1, 1, 1, 1 },

                    width = 600,
                    height = 40,
                },

                displays = {
                    Primary = {
                        enabled = true,
                        builtIn = true,

                        name = "Primary",

                        relativeTo = "SCREEN",
                        displayPoint = "TOP",
                        anchorPoint = "BOTTOM",

                        x = 0,
                        y = -225,

                        numIcons = 5,
                        order = 1,

                        flash = {
                            color = { 1, 0, 0, 1 },
                        },

                        glow = {
                            enabled = true,
                            mode = "autocast"
                        },
                    },

                    AOE = {
                        enabled = false,
                        builtIn = true,

                        name = "AOE",

                        x = 0,
                        y = -170,

                        numIcons = 5,
                        order = 2,

                        flash = {
                            color = { 0, 1, 0, 1 },
                        },

                        glow = {
                            enabled = true,
                            mode = "autocast",
                        },
                    },

                    Cooldowns = {
                        enabled = true,
                        builtIn = true,

                        name = "爆发",
                        filter = 'cooldowns',

                        x = 0,
                        y = -280,

                        numIcons = 5,
                        order = 3,

                        flash = {
                            color = { 1, 0.82, 0, 1 },
                        },

                        glow = {
                            enabled = true,
                            mode = "autocast",
                        },
                    },

                    Defensives = {
                        enabled = true,
                        builtIn = true,

                        name = "防御",
                        filter = 'defensives',

                        x = -110,
                        y = -225,

                        numIcons = 5,
                        order = 4,

                        flash = {
                            color = { 0.522, 0.302, 1, 1 },
                        },

                        glow = {
                            enabled = true,
                            mode = "autocast",
                        },
                    },

                    Interrupts = {
                        enabled = true,
                        builtIn = true,

                        name = "打断",
                        filter = 'interrupts',

                        x = -55,
                        y = -225,

                        numIcons = 5,
                        order = 5,

                        flash = {
                            color = { 1, 1, 1, 1 },
                        },

                        glow = {
                            enabled = true,
                            mode = "autocast",
                        },
                    },

                    ['**'] = displayTemplate
                },

                -- STILL NEED TO REVISE.
                Clash = 0,
                -- (above)

                runOnce = {
                },

                clashes = {
                },
                trinkets = {
                    ['**'] = {
                        disabled = false,
                        minimum = 0,
                        maximum = 0,
                    }
                },

                interrupts = {
                    pvp = {},
                    encounters = {},
                },

                filterCasts = true,
                castRemainingThreshold = 0.25,

                iconStore = {
                    hide = false,
                },
            },
        }

        for id, spec in pairs( class.specs ) do
            if id > 0 then
                defaults.profile.specs[ id ] = defaults.profile.specs[ id ] or tableCopy( specTemplate )
                for k, v in pairs( spec.options ) do
                    defaults.profile.specs[ id ][ k ] = v
                end
            end
        end

        return defaults
    end
end

do
    local shareDB = {
        displays = {},
        styleName = "",
        export = "",
        exportStage = 0,

        import = "",
        imported = {},
        importStage = 0
    }

    function AdvancedInterfaceOptions:GetDisplayShareOption( info )
        local n = #info
        local option = info[ n ]

        if shareDB[ option ] then return shareDB[ option ] end
        return shareDB.displays[ option ]
    end


    function AdvancedInterfaceOptions:SetDisplayShareOption( info, val, v2, v3, v4 )
        local n = #info
        local option = info[ n ]

        if type(val) == 'string' then val = val:trim() end
        if shareDB[ option ] then shareDB[ option ] = val
return end

        shareDB.displays[ option ] = val
        shareDB.export = ""
    end



    local multiDisplays = {
        Primary = true,
        AOE = true,
        Cooldowns = false,
        Defensives = false,
        Interrupts = false,
    }

    local frameStratas = ns.FrameStratas

    -- Display Config.
    function AdvancedInterfaceOptions:GetDisplayOption( info )
        local n = #info
        local display, category, option = info[ 2 ], info[ 3 ], info[ n ]

        if category == "shareDisplays" then
            return self:GetDisplayShareOption( info )
        end

        local conf = self.DB.profile.displays[ display ]

        if category ~= option and category ~= "main" then
            conf = conf[ category ]
        end

        if option == "color" or option == "queuedColor" then return unpack( conf.color ) end
        if option == "frameStrata" then return frameStratas[ conf.frameStrata ] or 3 end
        if option == "name" then return display end

        return conf[ option ]
    end

    local multiSet = false
    local timer

    local function QueueRebuildUI()
        if timer and not timer:IsCancelled() then timer:Cancel() end
        timer = C_Timer.NewTimer( 0.5, function ()
            AdvancedInterfaceOptions:BuildUI()
        end )
    end

    function AdvancedInterfaceOptions:SetDisplayOption( info, val, v2, v3, v4 )
        local n = #info
        local display, category, option = info[ 2 ], info[ 3 ], info[ n ]
        local set = false

        if category == "shareDisplays" then
            self:SetDisplayShareOption( info, val, v2, v3, v4 )
            return
        end

        local conf = self.DB.profile.displays[ display ]
        if category ~= option and category ~= 'main' then conf = conf[ category ] end

        if option == 'color' or option == 'queuedColor' then
            conf[ option ] = { val, v2, v3, v4 }
            set = true
        elseif option == 'frameStrata' then
            conf.frameStrata = frameStratas[ val ] or "LOW"
            set = true
        end

        if not set then
            val = type( val ) == 'string' and val:trim() or val
            conf[ option ] = val
        end

        if not multiSet then QueueRebuildUI() end
    end


    function AdvancedInterfaceOptions:GetMultiDisplayOption( info )
        info[ 2 ] = "Primary"
        local val, v2, v3, v4 = self:GetDisplayOption( info )
        info[ 2 ] = "Multi"
        return val, v2, v3, v4
    end

    function AdvancedInterfaceOptions:SetMultiDisplayOption( info, val, v2, v3, v4 )
        multiSet = true

        local orig = info[ 2 ]

        for display, active in pairs( multiDisplays ) do
            if active then
                info[ 2 ] = display
                self:SetDisplayOption( info, val, v2, v3, v4 )
            end
        end
        QueueRebuildUI()
        info[ 2 ] = orig

        multiSet = false
    end


    local function GetNotifOption( info )
        local n = #info
        local option = info[ n ]

        local conf = AdvancedInterfaceOptions.DB.profile.notifications
        local val = conf[ option ]

        if option == "color" then
            if type( val ) == "table" and #val == 4 then
                return unpack( val )
            else
                local defaults = AdvancedInterfaceOptions:GetDefaults()
                return unpack( defaults.profile.notifications.color )
            end
        end
        return val
    end

    local function SetNotifOption( info, ... )
        local n = #info
        local option = info[ n ]

        local conf = AdvancedInterfaceOptions.DB.profile.notifications
        local val = option == "color" and { ... } or select(1, ...)

        conf[ option ] = val
        QueueRebuildUI()
    end

    local fontStyles = {
        ["MONOCHROME"] = "单色",
        ["MONOCHROME,OUTLINE"] = "单色，描边",
        ["MONOCHROME,THICKOUTLINE"] = "单色，粗描边",
        ["NONE"] = "无",
        ["OUTLINE"] = "描边",
        ["THICKOUTLINE"] = "粗描边"
    }

    local fontElements = {
        font = {
            type = "select",
            name = "字体",
            order = 1,
            width = 1.49,
            dialogControl = 'LSM30_Font',
            values = LSM:HashTable("font"),
        },

        fontStyle = {
            type = "select",
            name = "样式",
            order = 2,
            values = fontStyles,
            width = 1.49
        },

        break01 = {
            type = "description",
            name = " ",
            order = 2.1,
            width = "full"
        },

        fontSize = {
            type = "range",
            name = "尺寸",
            order = 3,
            min = 8,
            max = 64,
            step = 1,
            width = 1.49
        },

        color = {
            type = "color",
            name = "颜色",
            order = 4,
            width = 1.49
        }
    }

    local anchorPositions = {
        TOP = '顶部',
        TOPLEFT = '顶部左侧',
        TOPRIGHT = '顶部右侧',
        BOTTOM = '底部',
        BOTTOMLEFT = '底部左侧',
        BOTTOMRIGHT = '底部右侧',
        LEFT = '左侧',
        LEFTTOP = '左侧上部',
        LEFTBOTTOM = '左侧下部',
        RIGHT = '右侧',
        RIGHTTOP = '右侧上部',
        RIGHTBOTTOM = '右侧下部',
    }


    local realAnchorPositions = {
        TOP = '顶部',
        TOPLEFT = '顶部左侧',
        TOPRIGHT = '顶部右侧',
        BOTTOM = '底部',
        BOTTOMLEFT = '底部左侧',
        BOTTOMRIGHT = '底部右侧',
        CENTER = "中间",
        LEFT = '左侧',
        RIGHT = '右侧',
    }


    local function getOptionTable( info, notif )
        local disp = info[2]
        local tab = AdvancedInterfaceOptions.Options.args.displays

        if notif then
            tab = tab.args.nPanel
        else
            tab = tab.plugins[ disp ][ disp ]
        end

        for i = 3, #info do
            tab = tab.args[ info[i] ]
        end

        return tab
    end

    local function rangeXY( info, notif )
        local tab = getOptionTable( info, notif )

        local resolution = GetCVar( "gxWindowedResolution" ) or "1280x720"
        local width, height = resolution:match( "(%d+)x(%d+)" )

        width = tonumber( width )
        height = tonumber( height )

        tab.args.x.min = -1 * width
        tab.args.x.max = width
        tab.args.x.softMin = -1 * width * 0.5
        tab.args.x.softMax = width * 0.5

        tab.args.y.min = -1 * height
        tab.args.y.max = height
        tab.args.y.softMin = -1 * height * 0.5
        tab.args.y.softMax = height * 0.5
    end


    local function setWidth( info, field, condition, if_true, if_false )
        local tab = getOptionTable( info )

        if condition then
            tab.args[ field ].width = if_true or "full"
        else
            tab.args[ field ].width = if_false or "full"
        end
    end


    local function rangeIcon( info )
        local tab = getOptionTable( info )

        local display = info[2]
        display = display == "Multi" and "Primary" or display

        local data = display and AdvancedInterfaceOptions.DB.profile.displays[ display ]

        --LJ扩大范围
        if data then
            tab.args.x.min = -1 * 1000
            tab.args.x.max = 1000

            tab.args.y.min = -1 * 1000
            tab.args.y.max = 1000

            return
        end

        if data then
            tab.args.x.min = -1 * max( data.primaryWidth, data.queue.width )
            tab.args.x.max = max( data.primaryWidth, data.queue.width )

            tab.args.y.min = -1 * max( data.primaryHeight, data.queue.height )
            tab.args.y.max = max( data.primaryHeight, data.queue.height )

            return
        end

        tab.args.x.min = -50
        tab.args.x.max = 50

        tab.args.y.min = -50
        tab.args.y.max = 50
    end


    local dispCycle = { "Primary", "AOE", "Cooldowns", "Defensives", "Interrupts" }

    local MakeMultiDisplayOption
    local modified = {}

    local function GetOptionData( db, info )
        local display = info[ 2 ]
        local option = db[ display ][ display ]
        local desc, set, get = nil, option.set, option.get

        for i = 3, #info do
            local category = info[ i ]

            if not option then
                break

            elseif option.args then
                if not option.args[ category ] then
                    break
                end
                option = option.args[ category ]

            else
                break
            end

            get = option and option.get or get
            set = option and option.set or set
            desc = option and option.desc or desc
        end

        return option, get, set, desc
    end

    local function WrapSetter( db, data )
        local _, _, setfunc = GetOptionData( db, data )
        if setfunc and modified[ setfunc ] then return setfunc end

        local newFunc = function( info, val, v2, v3, v4 )
            multiSet = true

            for display, active in pairs( multiDisplays ) do
                if active then
                    info[ 2 ] = display

                    _, _, setfunc = GetOptionData( db, info )

                    if type( setfunc ) == "string" then
                        AdvancedInterfaceOptions[ setfunc ]( AdvancedInterfaceOptions, info, val, v2, v3, v4 )
                    elseif type( setfunc ) == "function" then
                        setfunc( info, val, v2, v3, v4 )
                    end
                end
            end

            multiSet = false

            info[ 2 ] = "Multi"
            QueueRebuildUI()
        end

        modified[ newFunc ] = true
        return newFunc
    end

    local function WrapDesc( db, data )
        local option, getfunc, _, descfunc = GetOptionData( db, data )
        if descfunc and modified[ descfunc ] then
            return descfunc
        end

        local newFunc = function( info )
            local output

            for _, display in ipairs( dispCycle ) do
                info[ 2 ] = display
                option, getfunc, _, descfunc = GetOptionData( db, info )

                if not output then
                    output = option and type( option.desc ) == "function" and ( option.desc( info ) or "" ) or ( option.desc or "" )
                    if output:len() > 0 then output = output .. "\n" end
                end

                local val, v2, v3, v4

                if not getfunc then
                    val, v2, v3, v4 = AdvancedInterfaceOptions:GetDisplayOption( info )
                elseif type( getfunc ) == "function" then
                    val, v2, v3, v4 = getfunc( info )
                elseif type( getfunc ) == "string" then
                    val, v2, v3, v4 = AdvancedInterfaceOptions[ getfunc ]( AdvancedInterfaceOptions, info )
                end

                if val == nil then
                    AdvancedInterfaceOptions:Error( "Unable to get a value for %s in WrapDesc.", table.concat( info, ":" ) )
                    info[ 2 ] = "Multi"
                    return output
                end

                -- Sanitize/format values.
                if type( val ) == "boolean" then
                    val = val and "|cFF00FF00Checked|r" or "|cFFFF0000Unchecked|r"

                elseif option.type == "color" then
                    val = string.format( "|A:WhiteCircle-RaidBlips:16:16:0:0:%d:%d:%d|a |cFFFFD100#%02x%02x%02x|r", val * 255, v2 * 255, v3 * 255, val * 255, v2 * 255, v3 * 255 )

                elseif option.type == "select" and option.values and not option.dialogControl then
                    if type( option.values ) == "function" then
                        val = option.values( data )[ val ] or val
                    else
                        val = option.values[ val ] or val
                    end

                    if type( val ) == "number" then
                        if val % 1 == 0 then
                            val = format( "|cFFFFD100%d|r", val )
                        else
                            val = format( "|cFFFFD100%.2f|r", val )
                        end
                    else
                        val = format( "|cFFFFD100%s|r", tostring( val ) )
                    end

                elseif type( val ) == "number" then
                    if val % 1 == 0 then
                        val = format( "|cFFFFD100%d|r", val )
                    else
                        val = format( "|cFFFFD100%.2f|r", val )
                    end

                else
                    if val == nil then
                        AdvancedInterfaceOptions:Error( "Value not found for %s, defaulting to '???'.", table.concat( data, ":" ))
                        val = "|cFFFF0000???|r"
                    else
                        val = "|cFFFFD100" .. val .. "|r"
                    end
                end

                output = format( "%s%s%s%s:|r %s", output, output:len() > 0 and "\n" or "", BlizzBlue, display, val )
            end

            info[ 2 ] = "Multi"
            return output
        end

        modified[ newFunc ] = true
        return newFunc
    end

    local function GetDeepestSetter( db, info )
        local position = db.Multi.Multi
        local setter

        for i = 3, #info - 1 do
            local key = info[ i ]
            position = position.args[ key ]

            local setfunc = rawget( position, "set" )

            if setfunc and type( setfunc ) == "function" then
                setter = setfunc
            end
        end

        return setter
    end

    MakeMultiDisplayOption = function( db, t, inf )
        local info = {}

        if not inf or #inf == 0 then
            info[1] = "displays"
            info[2] = "Multi"

            for k, v in pairs( t ) do
                -- Only load groups in the first level (bypasses selection for which display to edit).
                if v.type == "group" then
                    info[3] = k
                    MakeMultiDisplayOption( db, v.args, info )
                    info[3] = nil
                end
            end

            return

        else
            for i, v in ipairs( inf ) do
                info[ i ] = v
            end
        end

        for k, v in pairs( t ) do
            if k:match( "^MultiMod" ) then
                -- do nothing.
            elseif v.type == "group" then
                info[ #info + 1 ] = k
                MakeMultiDisplayOption( db, v.args, info )
                info[ #info ] = nil
            elseif inf and v.type ~= "description" then
                info[ #info + 1 ] = k
                v.desc = WrapDesc( db, info )

                if rawget( v, "set" ) then
                    v.set = WrapSetter( db, info )
                else
                    local setfunc = GetDeepestSetter( db, info )
                    if setfunc then v.set = WrapSetter( db, info ) end
                end

                info[ #info ] = nil
            end
        end
    end


    local function newDisplayOption( db, name, data, pos )
        name = tostring( name )

        local fancyName

        if name == "Multi" then
            fancyName = AtlasToString("auctionhouse-icon-favorite") .. " Multiple"
        elseif name == "Defensives" then
            fancyName = AtlasToString("nameplates-InterruptShield") .. " Defensives"
        elseif name == "Interrupts" then
            fancyName = AtlasToString("voicechat-icon-speaker-mute") .. " Interrupts"
        elseif name == "Cooldowns" then
            fancyName = AtlasToString("chromietime-32x32") .. " Cooldowns"
        else
            fancyName = "技能队列提示设置"
        end

        local option = {
            ['btn'..name] = {
                type = 'execute',
                name = fancyName,
                desc = data.desc,
                order = 10 + pos,
                func = function () ACD:SelectGroup( "AdvancedInterfaceOptions", "displays", name ) end,
            },

            [name] = {
                type = 'group',
                name = function ()
                    if name == "Multi" then return "|cFF00FF00" .. fancyName .. "|r"
                    elseif data.builtIn then return '|cFF00B4FF' .. fancyName .. '|r' end
                    return fancyName
                end,
                desc = function ()
                    if name == "Multi" then
                        return "Allows editing of multiple displays at once.  Settings displayed are from the Primary display (other display settings are shown in the tooltip).\n\nCertain options are disabled when editing multiple displays."
                    end
                    return data.desc
                end,
                set = name == "Multi" and "SetMultiDisplayOption" or "SetDisplayOption",
                get = name == "Multi" and "GetMultiDisplayOption" or "GetDisplayOption",
                childGroups = "tab",
                order = 100 + pos,

                args = {
                    MultiModPrimary = {
                        type = "toggle",
                        name = function() return multiDisplays.Primary and "|cFF00FF00Primary|r" or "|cFFFF0000Primary|r" end,
                        desc = function()
                            if multiDisplays.Primary then return "Changes |cFF00FF00will|r be applied to the Primary display." end
                            return "Changes |cFFFF0000will not|r be applied to the Primary display."
                        end,
                        order = 0.01,
                        width = 0.65,
                        get = function() return multiDisplays.Primary end,
                        set = function() multiDisplays.Primary = not multiDisplays.Primary end,
                        hidden = function () return name ~= "Multi" end,
                    },
                    MultiModAOE = {
                        type = "toggle",
                        name = function() return multiDisplays.AOE and "|cFF00FF00AOE|r" or "|cFFFF0000AOE|r" end,
                        desc = function()
                            if multiDisplays.AOE then return "Changes |cFF00FF00will|r be applied to the AOE display." end
                            return "Changes |cFFFF0000will not|r be applied to the AOE display."
                        end,
                        order = 0.02,
                        width = 0.65,
                        get = function() return multiDisplays.AOE end,
                        set = function() multiDisplays.AOE = not multiDisplays.AOE end,
                        hidden = function () return name ~= "Multi" end,
                    },
                    MultiModCooldowns = {
                        type = "toggle",
                        name = function () return AtlasToString( "chromietime-32x32" ) .. ( multiDisplays.Cooldowns and " |cFF00FF00Cooldowns|r" or " |cFFFF0000Cooldowns|r" ) end,
                        desc = function()
                            if multiDisplays.Cooldowns then return "Changes |cFF00FF00will|r be applied to the Cooldowns display." end
                            return "Changes |cFFFF0000will not|r be applied to the Cooldowns display."
                        end,
                        order = 0.03,
                        width = 0.65,
                        get = function() return multiDisplays.Cooldowns end,
                        set = function() multiDisplays.Cooldowns = not multiDisplays.Cooldowns end,
                        hidden = function () return name ~= "Multi" end,
                    },
                    MultiModDefensives = {
                        type = "toggle",
                        name = function () return AtlasToString( "nameplates-InterruptShield" ) .. ( multiDisplays.Defensives and " |cFF00FF00Defensives|r" or " |cFFFF0000Defensives|r" ) end,
                        desc = function()
                            if multiDisplays.Defensives then return "Changes |cFF00FF00will|r be applied to the Defensives display." end
                            return "Changes |cFFFF0000will not|r be applied to the Defensives display."
                        end,
                        order = 0.04,
                        width = 0.65,
                        get = function() return multiDisplays.Defensives end,
                        set = function() multiDisplays.Defensives = not multiDisplays.Defensives end,
                        hidden = function () return name ~= "Multi" end,
                    },
                    MultiModInterrupts = {
                        type = "toggle",
                        name = function () return AtlasToString( "voicechat-icon-speaker-mute" ) .. ( multiDisplays.Interrupts and " |cFF00FF00Interrupts|r" or " |cFFFF0000Interrupts|r" ) end,
                        desc = function()
                            if multiDisplays.Interrupts then return "Changes |cFF00FF00will|r be applied to the Interrupts display." end
                            return "Changes |cFFFF0000will not|r be applied to the Interrupts display."
                        end,
                        order = 0.05,
                        width = 0.65,
                        get = function() return multiDisplays.Interrupts end,
                        set = function() multiDisplays.Interrupts = not multiDisplays.Interrupts end,
                        hidden = function () return name ~= "Multi" end,
                    },
                    main = {
                        type = 'group',
                        name = "技能图标",
                        desc = "包括显示位置、图标、图标大小和形状等等。",
                        order = 1,

                        args = {
                            enabled = {
                                type = "toggle",
                                name = "启用",
                                desc = "如果禁用，该显示区域在任何情况下都不会显示。",
                                order = 0.5,
                                hidden = function () return data.name == "Primary" or data.name == "AOE" or data.name == "Cooldowns"  or data.name == "Defensives" or data.name == "Interrupts" end
                            },

                            elvuiCooldown = {
                                type = "toggle",
                                name = "使用ElvUI的冷却样式",
                                desc = "如果安装了ElvUI，你可以在推荐队列中使用ElvUI的冷却样式。\n\n禁用此设置需要重新加载UI (|cFFFFD100/reload|r)。",
                                width = "full",
                                order = 16,
                                hidden = function () return _G["ElvUI"] == nil end,
                            },

                            numIcons = {
                                type = 'range',
                                name = "图标显示",
                                desc = "设置建议技能的显示数量。每个图标都会提前显示。",
                                min = 1,
                                max = 10,
                                step = 1,
                                bigStep = 1,
                                width = "full",
                                order = 1,
                                disabled = function()
                                    return name == "Multi"
                                end,
                                hidden = function( info, val )
                                    local n = #info
                                    local display = info[2]

                                    if display == "Defensives" or display == "Interrupts" then
                                        return true
                                    end

                                    return false
                                end,
                            },

                            forecastPeriod = {
                                type = "range",
                                name = "预测",
                                desc = "指定插件可以期待生成推荐的时间。例如，在冷却显示中，如果设置为|cFFFFD10015|r（默认值），则"
                                    .. "技能可以在其冷却时间剩余15秒且满足使用条件时出现。\n\n"
                                    .. "如果设置为非常短的时间段，由于在满足资源要求和使用条件的情况下技能CD没有好，可能不会出现在循环中。",
                                softMin = 1.5,
                                min = 0,
                                softMax = 15,
                                max = 30,
                                step = 0.1,
                                width = "full",
                                order = 2,
                                disabled = function()
                                    return name == "Multi"
                                end,
                                hidden = function( info, val )
                                    local n = #info
                                    local display = info[2]

                                    if display == "Primary" or display == "AOE" then
                                        return true
                                    end

                                    return false
                                end,
                            },

                            pos = {
                                type = "group",
                                inline = true,
                                name = function( info ) rangeXY( info )
return "位置" end,
                                order = 10,

                                args = {
                                    --[[
                                    relativeTo = {
                                        type = "select",
                                        name = "Anchored To",
                                        values = {
                                            SCREEN = "Screen",
                                            PERSONAL = "Personal Resource Display",
                                            CUSTOM = "Custom"
                                        },
                                        order = 1,
                                        width = 1.49,
                                    },

                                    customFrame = {
                                        type = "input",
                                        name = "Custom Frame",
                                        desc = "Specify the name of the frame to which this display will be anchored.\n" ..
                                                "If the frame does not exist, the display will not be shown.",
                                        order = 1.1,
                                        width = 1.49,
                                        hidden = function() return data.relativeTo ~= "CUSTOM" end,
                                    },

                                    setParent = {
                                        type = "toggle",
                                        name = "Set Parent to Anchor",
                                        desc = "If checked, the display will be shown/hidden when the anchor is shown/hidden.",
                                        order = 3.9,
                                        width = 1.49,
                                        hidden = function() return data.relativeTo == "SCREEN" end,
                                    },

                                    preXY = {
                                        type = "description",
                                        name = " ",
                                        width = "full",
                                        order = 97
                                    }, ]]

                                    x = {
                                        type = "range",
                                        name = "X",
                                        desc = "设置该显示区域主图标相对于屏幕中心的水平位置。" ..
                                            "负值代表显示区域向左移动，正值向右。",
                                        min = -512,
                                        max = 512,
                                        step = 1,

                                        order = 98,
                                        width = 1.49,

                                        disabled = function()
                                            return name == "Multi"
                                        end,
                                    },

                                    y = {
                                        type = "range",
                                        name = "Y",
                                        desc = "设置该显示区域主图标相对于屏幕中心的垂直位置。" ..
                                            "负值代表显示区域向下移动，正值向上。",
                                        min = -384,
                                        max = 384,
                                        step = 1,

                                        order = 99,
                                        width = 1.49,

                                        disabled = function()
                                            return name == "Multi"
                                        end,
                                    },
                                },
                            },

                            primaryIcon = {
                                type = "group",
                                name = "技能提示图标",
                                inline = true,
                                order = 15,
                                args = {
                                    primaryWidth = {
                                        type = "range",
                                        name = "宽度",
                                        desc = "为你的" .. name .. "显示区域主图标设置显示宽度。",
                                        min = 10,
                                        max = 500,
                                        step = 1,

                                        width = 1.49,
                                        order = 1,
                                    },

                                    primaryHeight = {
                                        type = "range",
                                        name = "高度",
                                        desc = "为你的" .. name .. "显示区域主图标设置显示高度。",
                                        min = 10,
                                        max = 500,
                                        step = 1,

                                        width = 1.49,
                                        order = 2,
                                    },

                                    spacer01 = {
                                        type = "description",
                                        name = " ",
                                        width = "full",
                                        order = 3
                                    },

                                    zoom = {
                                        type = "range",
                                        name = "图标缩放",
                                        desc = "选择此显示区域中图标图案的缩放百分比（30%大约是暴雪的原始值）。",
                                        min = 0,
                                        softMax = 100,
                                        max = 200,
                                        step = 1,

                                        width = 1.49,
                                        order = 4,
                                    },

                                    keepAspectRatio = {
                                        type = "toggle",
                                        name = "保持宽高比",
                                        desc = "如果主图标或队列中的图标不是正方形，勾选此项将无法图标缩放，" ..
                                            "变为裁切部分图标图案。",
                                        disabled = function(info, val)
                                            return not (data.primaryHeight ~= data.primaryWidth or (data.numIcons > 1 and data.queue.height ~= data.queue.width))
                                        end,
                                        width = 1.49,
                                        order = 5,
                                    },
                                },
                            },

                            advancedFrame = {
                                type = "group",
                                name = "图层显示",
                                inline = true,
                                order = 99,
                                args = {
                                    frameStrata = {
                                        type = "select",
                                        name = "层级",
                                        desc = "框架层级决定了在哪个图形层上绘制此显示区域。\n" ..
                                            "默认层级是中间层。",
                                        values = {
                                            "背景层",
                                            "底层",
                                            "中间层",
                                            "高层",
                                            "对话框",
                                            "全屏",
                                            "全屏对话框",
                                            "提示层"
                                        },
                                        width = "full",
                                        order = 1,
                                    },
                                },
                            },

                            queuedElvuiCooldown = {
                                type = "toggle",
                                name = " 使用ElvUI的冷却样式",
                                desc = "如果安装了ElvUI，你可以在推荐队列中使用ElvUI的冷却样式。\n\n禁用此设置需要重新加载UI (|cFFFFD100/reload|r)。",
                                width = "full",
                                order = 23,
                                get = function(info)
                                    return AdvancedInterfaceOptions.DB.profile.displays[name].queue.elvuiCooldown
                                end,
                                set = function(info, val)
                                    AdvancedInterfaceOptions.DB.profile.displays[name].queue.elvuiCooldown = val
                                end,
                                hidden = function() return _G["ElvUI"] == nil end,
                            },

                            iconSizeGroup = {
                                type = "group",
                                inline = true,
                                name = "队列图标大小",
                                order = 21,
                                args = {
                                    width = {
                                        type = 'range',
                                        name = '宽',
                                        desc = "设置队列图标的宽",
                                        min = 10,
                                        max = 500,
                                        step = 1,
                                        bigStep = 1,
                                        order = 10,
                                        width = 1.49,
                                        get = function(info)
                                            return AdvancedInterfaceOptions.DB.profile.displays[name].queue.width
                                        end,
                                        set = function(info, val)
                                            AdvancedInterfaceOptions.DB.profile.displays[name].queue.width = val
                                        end,
                                    },

                                    height = {
                                        type = 'range',
                                        name = '高',
                                        desc = "设置队列图标的高",
                                        min = 10,
                                        max = 500,
                                        step = 1,
                                        bigStep = 1,
                                        order = 11,
                                        width = 1.49,
                                        get = function(info)
                                            return AdvancedInterfaceOptions.DB.profile.displays[name].queue.height
                                        end,
                                        set = function(info, val)
                                            AdvancedInterfaceOptions.DB.profile.displays[name].queue.height = val
                                        end,
                                    },
                                }
                            },

                            anchorGroup = {
                                type = "group",
                                inline = true,
                                name = "位置",
                                order = 22,
                                args = {
                                    anchor = {
                                        type = 'select',
                                        name = '锚点',
                                        desc = "选择锚点.",
                                        values = anchorPositions,
                                        width = 1.49,
                                        order = 1,
                                        get = function(info)
                                            return AdvancedInterfaceOptions.DB.profile.displays[name].queue.anchor
                                        end,
                                        set = function(info, val)
                                            AdvancedInterfaceOptions.DB.profile.displays[name].queue.anchor = val
                                            AdvancedInterfaceOptions:BuildUI()
                                        end,
                                    },

                                    direction = {
                                        type = 'select',
                                        name = '方向',
                                        desc = "选择方向",
                                        values = {
                                            TOP = '上',
                                            BOTTOM = '下',
                                            LEFT = '左',
                                            RIGHT = '右'
                                        },
                                        width = 1.49,
                                        order = 1.1,
                                        get = function(info)
                                            return AdvancedInterfaceOptions.DB.profile.displays[name].queue.direction
                                        end,
                                        set = function(info, val)
                                            AdvancedInterfaceOptions.DB.profile.displays[name].queue.direction = val
                                            AdvancedInterfaceOptions:BuildUI()
                                        end,
                                    },

                                    spacer01 = {
                                        type = "description",
                                        name = " ",
                                        order = 1.2,
                                        width = "full",
                                    },

                                    offsetX = {
                                        type = 'range',
                                        name = 'X轴 偏移',
                                        desc = "指定队列的水平偏移量（以像素为单位），相对于此显示的主图标的锚点位置。\n\n" ..
                                            "正数将队列向右移动，负数将其向左移动。",
                                        min = -100,
                                        max = 500,
                                        step = 1,
                                        width = 1.49,
                                        order = 2,
                                        get = function(info)
                                            return AdvancedInterfaceOptions.DB.profile.displays[name].queue.offsetX
                                        end,
                                        set = function(info, val)
                                            AdvancedInterfaceOptions.DB.profile.displays[name].queue.offsetX = val
                                            AdvancedInterfaceOptions:BuildUI()
                                        end,
                                    },

                                    offsetY = {
                                        type = 'range',
                                        name = 'Y轴 偏移',
                                        desc = "指定队列的垂直偏移量（以像素为单位），相对于此显示的主图标的锚点位置。\n\n" ..
                                            "正数将队列向上移动，负数将其向下移动。",
                                        min = -100,
                                        max = 500,
                                        step = 1,
                                        width = 1.49,
                                        order = 2.1,
                                        get = function(info)
                                            return AdvancedInterfaceOptions.DB.profile.displays[name].queue.offsetY
                                        end,
                                        set = function(info, val)
                                            AdvancedInterfaceOptions.DB.profile.displays[name].queue.offsetY = val
                                            AdvancedInterfaceOptions:BuildUI()
                                        end,
                                    },

                                    spacer02 = {
                                        type = "description",
                                        name = " ",
                                        order = 2.2,
                                        width = "full",
                                    },

                                    spacing = {
                                        type = 'range',
                                        name = '图标间距',
                                        desc = "选择队列中图标之间的像素距离。",
                                        softMin = (data.queue.direction == "LEFT" or data.queue.direction == "RIGHT") and
                                        -data.queue.width or -data.queue.height,
                                        softMax = (data.queue.direction == "LEFT" or data.queue.direction == "RIGHT") and
                                        data.queue.width or data.queue.height,
                                        min = -500,
                                        max = 500,
                                        step = 1,
                                        order = 3,
                                        width = 2.98,
                                        get = function(info)
                                            return AdvancedInterfaceOptions.DB.profile.displays[name].queue.spacing
                                        end,
                                        set = function(info, val)
                                            AdvancedInterfaceOptions.DB.profile.displays[name].queue.spacing = val
                                            AdvancedInterfaceOptions:BuildUI()
                                        end,
                                    },
                                }
                            },
                        },
                    },

                    visibility = {
                        type = 'group',
                        name = '透明度',
                        desc = "PvE和PvP模式下不同的透明度设置。",
                        order = 3,

                        args = {

                            advanced = {
                                type = "toggle",
                                name = "进阶设置",
                                desc = "如果勾选，将提供更多关于透明度的细节选项。",
                                width = "full",
                                order = 1,
                            },

                            simple = {
                                type = 'group',
                                inline = true,
                                name = "",
                                hidden = function() return data.visibility.advanced end,
                                get = function( info )
                                    local option = info[ #info ]

                                    if option == 'pveAlpha' then return data.visibility.pve.alpha
                                    elseif option == 'pvpAlpha' then return data.visibility.pvp.alpha end
                                end,
                                set = function( info, val )
                                    local option = info[ #info ]

                                    if option == 'pveAlpha' then data.visibility.pve.alpha = val
                                    elseif option == 'pvpAlpha' then data.visibility.pvp.alpha = val end

                                    QueueRebuildUI()
                                end,
                                order = 2,
                                args = {
                                    pveAlpha = {
                                        type = "range",
                                        name = "PvE透明度",
                                        desc = "设置在PvE战斗中显示区域的透明度。如果设置为0，该显示区域将不会在PvE战斗中显示。",
                                        min = 0,
                                        max = 1,
                                        step = 0.01,
                                        order = 1,
                                        width = 1.49,
                                    },
                                    pvpAlpha = {
                                        type = "range",
                                        name = "PvP透明度",
                                        desc = "设置在PvP战斗中显示区域的透明度。如果设置为0，该显示区域将不会在PvP战斗中显示。",
                                        min = 0,
                                        max = 1,
                                        step = 0.01,
                                        order = 1,
                                        width = 1.49,
                                    },
                                }
                            },

                            pveComplex = {
                                type = 'group',
                                inline = true,
                                name = "PvE",
                                get = function( info )
                                    local option = info[ #info ]

                                    return data.visibility.pve[ option ]
                                end,
                                set = function( info, val )
                                    local option = info[ #info ]

                                    data.visibility.pve[ option ] = val
                                    QueueRebuildUI()
                                end,
                                hidden = function() return not data.visibility.advanced end,
                                order = 2,
                                args = {
                                    always = {
                                        type = "range",
                                        name = "默认",
                                        desc = "如果此项不是0，则在PvE区域无论是否在战斗中，该显示区域都将始终显示。",
                                        min = 0,
                                        max = 1,
                                        step = 0.01,
                                        width = 1.49,
                                        order = 1,
                                    },

                                    combat = {
                                        type = "range",
                                        name = "战斗中",
                                        desc = "如果此项不是0，则在PvE战斗中，该显示区域都将始终显示。",
                                        min = 0,
                                        max = 1,
                                        step = 0.01,
                                        width = 1.49,
                                        order = 3,
                                    },

                                    break01 = {
                                        type = "description",
                                        name = " ",
                                        width = "full",
                                        order = 2.1
                                    },

                                    target = {
                                        type = "range",
                                        name = "目标",
                                        desc = "如果此项不是0，则当你有可攻击的PvE目标时，该显示区域都将始终显示。",
                                        min = 0,
                                        max = 1,
                                        step = 0.01,
                                        width = 1.49,
                                        order = 2,
                                    },

                                    combatTarget = {
                                        type = "range",
                                        name = "战斗和目标",
                                        desc = "如果此项不是0，则当你处于战斗状态，且拥有可攻击的PvE目标时，该显示区域都将始终显示。",
                                        min = 0,
                                        max = 1,
                                        step = 0.01,
                                        width = 1.49,
                                        order = 4,
                                    },

                                    hideMounted = {
                                        type = "toggle",
                                        name = "骑乘时隐藏",
                                        desc = "如果勾选，则当你骑乘时，该显示区域隐藏（除非你在战斗中）。",
                                        width = "full",
                                        order = 0.5,
                                    }
                                },
                            },

                            pvpComplex = {
                                type = 'group',
                                inline = true,
                                name = "PvP",
                                get = function( info )
                                    local option = info[ #info ]

                                    return data.visibility.pvp[ option ]
                                end,
                                set = function( info, val )
                                    local option = info[ #info ]

                                    data.visibility.pvp[ option ] = val
                                    QueueRebuildUI()
                                    AdvancedInterfaceOptions:UpdateDisplayVisibility()
                                end,
                                hidden = function() return not data.visibility.advanced end,
                                order = 2,
                                args = {
                                    always = {
                                        type = "range",
                                        name = "总是",
                                        desc = "如果此项不是0，则在PvP区域无论是否在战斗中，该显示区域都将始终显示。",
                                        min = 0,
                                        max = 1,
                                        step = 0.01,
                                        width = 1.49,
                                        order = 1,
                                    },

                                    combat = {
                                        type = "range",
                                        name = "战斗中",
                                        desc = "如果此项不是0，则在PvP战斗中，该显示区域都将始终显示。",
                                        min = 0,
                                        max = 1,
                                        step = 0.01,
                                        width = 1.49,
                                        order = 3,
                                    },

                                    break01 = {
                                        type = "description",
                                        name = " ",
                                        width = "full",
                                        order = 2.1
                                    },

                                    target = {
                                        type = "range",
                                        name = "目标",
                                        desc = "如果此项不是0，则当你有可攻击的PvP目标时，该显示区域都将始终显示。",
                                        min = 0,
                                        max = 1,
                                        step = 0.01,
                                        width = 1.49,
                                        order = 2,
                                    },

                                    combatTarget = {
                                        type = "range",
                                        name = "战斗和目标",
                                        desc = "如果此项不是0，则当你处于战斗状态，且拥有可攻击的PvP目标时，该显示区域都将始终显示。",
                                        min = 0,
                                        max = 1,
                                        step = 0.01,
                                        width = 1.49,
                                        order = 4,
                                    },

                                    hideMounted = {
                                        type = "toggle",
                                        name = "骑乘时隐藏",
                                        desc = "如果勾选，则当你骑乘时，该显示区域隐藏（除非你在战斗中）。",
                                        width = "full",
                                        order = 0.5,
                                    }
                                },
                            },
                        },
                    },

                    keybindings = {
                        type = "group",
                        name = "按键绑定",
                        desc = "当前技能的按键绑定提示文字",
                        order = 7,

                        args = {
                            enabled = {
                                type = "toggle",
                                name = "启用",
                                order = 1,
                                width = 1.49,
                            },

                            -- queued = {
                            --     type = "toggle",
                            --     name = "Enabled for Queued Icons",
                            --     order = 2,
                            --     width = 1.49,
                            --     disabled = function () return data.keybindings.enabled == false end,
                            -- },

                            pos = {
                                type = "group",
                                inline = true,
                                name = function(info)
                                    rangeIcon(info)
                                    return "位置"
                                end,
                                order = 3,
                                args = {
                                    anchor = {
                                        type = "select",
                                        name = '锚点',
                                        order = 2,
                                        width = 1,
                                        values = realAnchorPositions
                                    },

                                    x = {
                                        type = "range",
                                        name = "X轴偏移",
                                        order = 3,
                                        width = 0.99,
                                        min = -max(data.primaryWidth, data.queue.width),
                                        max = max(data.primaryWidth, data.queue.width),
                                        disabled = function(info)
                                            return false
                                        end,
                                        step = 1,
                                    },

                                    y = {
                                        type = "range",
                                        name = "Y轴偏移",
                                        order = 4,
                                        width = 0.99,
                                        min = -max(data.primaryHeight, data.queue.height),
                                        max = max(data.primaryHeight, data.queue.height),
                                        step = 1,
                                    }
                                }
                            },

                            textStyle = {
                                type = "group",
                                inline = true,
                                name = "文本样式",
                                order = 5,
                                args = tableCopy(fontElements),
                            },

                            lowercase = {
                                type = "toggle",
                                name = "使用小写字母",
                                order = 5.1,
                                width = "full",
                            },

                            separateQueueStyle = {
                                type = "toggle",
                                name = "队列图标使用不同的设置",
                                order = 6,
                                width = "full",
                            },

                            queuedTextStyle = {
                                type = "group",
                                inline = true,
                                name = "队列图标文本样式",
                                order = 7,
                                hidden = function() return not data.keybindings.separateQueueStyle end,
                                args = {
                                    queuedFont = {
                                        type = "select",
                                        name = "字体",
                                        order = 1,
                                        width = 1.49,
                                        dialogControl = 'LSM30_Font',
                                        values = LSM:HashTable("font"),
                                    },

                                    queuedFontStyle = {
                                        type = "select",
                                        name = "样式",
                                        order = 2,
                                        values = fontStyles,
                                        width = 1.49
                                    },

                                    break01 = {
                                        type = "description",
                                        name = " ",
                                        width = "full",
                                        order = 2.1
                                    },

                                    queuedFontSize = {
                                        type = "range",
                                        name = "尺寸",
                                        order = 3,
                                        min = 8,
                                        max = 64,
                                        step = 1,
                                        width = 1.49
                                    },

                                    queuedColor = {
                                        type = "color",
                                        name = "颜色",
                                        order = 4,
                                        width = 1.49
                                    }
                                },
                            },

                            queuedLowercase = {
                                type = "toggle",
                                name = "队列图标使用小写字母",
                                order = 7.1,
                                width = 1.49,
                                hidden = function() return not data.keybindings.separateQueueStyle end,
                            },

                            cPort = {
                                name = "控制台端口",
                                type = "group",
                                inline = true,
                                order = 4,
                                args = {
                                    cPortOverride = {
                                        type = "toggle",
                                        name = "使用控制台端口按键",
                                        order = 6,
                                        width = 1.49,
                                    },

                                    cPortZoom = {
                                        type = "range",
                                        name = "控制台端口按键缩放",
                                        desc = "控制台端口图案周围通常有大量空白填充。" ..
                                            "为了按键适配图标，放大会裁切一些图案。默认值为|cFFFFD1000.6|r。",
                                        order = 7,
                                        min = 0,
                                        max = 1,
                                        step = 0.01,
                                        width = 1.49,
                                    },
                                },
                                disabled = function() return ConsolePort == nil end,
                            },

                        }
                    },
                    --LJ
                    states = {
                        type = "group",
                        name = "状态提示",
                        desc = "显示插件当前得状态",
                        order = 7,
                        args = {
                            enabled = {
                                type = "toggle",
                                name = "启用",
                                order = 1,
                                width = 1.49,
                            },

                            -- queued = {
                            --     type = "toggle",
                            --     name = "Enabled for Queued Icons",
                            --     order = 2,
                            --     width = 1.49,
                            --     disabled = function () return data.keybindings.enabled == false end,
                            -- },

                            pos = {
                                type = "group",
                                inline = true,
                                name = function(info)
                                    rangeIcon(info)
                                    return "位置"
                                end,
                                order = 3,
                                args = {
                                    anchor = {
                                        type = "select",
                                        name = '锚点',
                                        order = 2,
                                        width = 1,
                                        values = realAnchorPositions
                                    },

                                    x = {
                                        type = "range",
                                        name = "X轴偏移",
                                        order = 3,
                                        width = 0.99,
                                        min = -max(data.primaryWidth, data.queue.width),
                                        max = max(data.primaryWidth, data.queue.width),
                                        disabled = function(info)
                                            return false
                                        end,
                                        step = 1,
                                    },

                                    y = {
                                        type = "range",
                                        name = "Y轴偏移",
                                        order = 4,
                                        width = 0.99,
                                        min = -max(data.primaryHeight, data.queue.height),
                                        max = max(data.primaryHeight, data.queue.height),
                                        step = 1,
                                    }
                                }
                            },

                            textStyle = {
                                type = "group",
                                inline = true,
                                name = "文本样式",
                                order = 5,
                                args = tableCopy(fontElements),
                            },

                            lowercase = {
                                type = "toggle",
                                name = "使用小写字母",
                                order = 5.1,
                                width = "full",
                            },

                            separateQueueStyle = {
                                type = "toggle",
                                name = "队列图标使用不同的设置",
                                order = 6,
                                width = "full",
                            },

                            queuedTextStyle = {
                                type = "group",
                                inline = true,
                                name = "队列图标文本样式",
                                order = 7,
                                hidden = function() return not data.keybindings.separateQueueStyle end,
                                args = {
                                    queuedFont = {
                                        type = "select",
                                        name = "字体",
                                        order = 1,
                                        width = 1.49,
                                        dialogControl = 'LSM30_Font',
                                        values = LSM:HashTable("font"),
                                    },

                                    queuedFontStyle = {
                                        type = "select",
                                        name = "样式",
                                        order = 2,
                                        values = fontStyles,
                                        width = 1.49
                                    },

                                    break01 = {
                                        type = "description",
                                        name = " ",
                                        width = "full",
                                        order = 2.1
                                    },

                                    queuedFontSize = {
                                        type = "range",
                                        name = "尺寸",
                                        order = 3,
                                        min = 8,
                                        max = 64,
                                        step = 1,
                                        width = 1.49
                                    },

                                    queuedColor = {
                                        type = "color",
                                        name = "颜色",
                                        order = 4,
                                        width = 1.49
                                    }
                                },
                            },

                            queuedLowercase = {
                                type = "toggle",
                                name = "队列图标使用小写字母",
                                order = 7.1,
                                width = 1.49,
                                hidden = function() return not data.keybindings.separateQueueStyle end,
                            },

                            cPort = {
                                name = "控制台端口",
                                type = "group",
                                inline = true,
                                order = 4,
                                args = {
                                    cPortOverride = {
                                        type = "toggle",
                                        name = "使用控制台端口按键",
                                        order = 6,
                                        width = 1.49,
                                    },

                                    cPortZoom = {
                                        type = "range",
                                        name = "控制台端口按键缩放",
                                        desc = "控制台端口图案周围通常有大量空白填充。" ..
                                            "为了按键适配图标，放大会裁切一些图案。默认值为|cFFFFD1000.6|r。",
                                        order = 7,
                                        min = 0,
                                        max = 1,
                                        step = 0.01,
                                        width = 1.49,
                                    },
                                },
                                disabled = function() return ConsolePort == nil end,
                            },

                        }
                    },

                    border = {
                        type = "group",
                        name = "边框",
                        desc = "启用/禁用和设置图标边框的颜色。\n\n" ..
                            "如果使用了Masque或类似的图标美化插件，可能需要禁用此功能。",
                        order = 4,

                        args = {
                            enabled = {
                                type = "toggle",
                                name = "启用",
                                desc = "如果勾选，该显示区域中每个图标都会有窄边框。",
                                order = 1,
                                width = "full",
                            },

                            thickness = {
                                type = "range",
                                name = "边框粗细",
                                desc = "设置边框的厚度（粗细）。默认值为1。",
                                softMin = 1,
                                softMax = 20,
                                step = 1,
                                order = 2,
                                width = 1.49,
                            },

                            fit = {
                                type = "toggle",
                                name = "内边框",
                                desc = "如果勾选，当边框启用时，图标的边框将会在按钮的内部（而不是周围）。",
                                order = 2.5,
                                width = 1.49
                            },

                            break01 = {
                                type = "description",
                                name = " ",
                                width = "full",
                                order = 2.6
                            },

                            coloring = {
                                type = "select",
                                name = "着色模式",
                                desc = "设置边框颜色是系统颜色或自定义颜色。",
                                width = 1.49,
                                order = 3,
                                values = {
                                    class = format("Class |A:WhiteCircle-RaidBlips:16:16:0:0:%d:%d:%d|a #%s",
                                        ClassColor.r * 255, ClassColor.g * 255, ClassColor.b * 255,
                                        ClassColor:GenerateHexColor():sub(3, 8)),
                                    custom = "设置自定义颜色"
                                },
                                disabled = function() return data.border.enabled == false end,
                            },

                            color = {
                                type = "color",
                                name = "边框颜色",
                                desc = "当启用边框后，边框将使用此颜色。",
                                order = 4,
                                width = 1.49,
                                disabled = function() return data.border.enabled == false or
                                    data.border.coloring ~= "custom" end,
                            }
                        }
                    },

                    range = {
                        type = "group",
                        name = "范围",
                        desc = "设置范围检查警告的选项。",
                        order = 5,
                        args = {
                            enabled = {
                                type = "toggle",
                                name = "启用",
                                desc = "如果勾选，当你不在攻击距离内时，插件将进行红色高亮警告。",
                                width = 1.49,
                                order = 1,
                            },

                            type = {
                                type = "select",
                                name = '范围监测',
                                desc = "选择该显示区域使用的范围监测和警告提示类型。\n\n" ..
                                    "|cFFFFD100技能|r - 如果某个技能超出攻击范围，则该技能以红色高亮警告。\n\n" ..
                                    "|cFFFFD100近战|r - 如果你不在近战攻击范围，所有技能都以红色高亮警告。\n\n" ..
                                    "|cFFFFD100排除|r - 如果某个技能超出攻击范围，则不建议使用该技能。",
                                values = {
                                    ability = "每个技能",
                                    melee = "近战范围",
                                    xclude = "排除超出范围的技能"
                                },
                                width = 1.49,
                                order = 2,
                                disabled = function() return data.range.enabled == false end,
                            }
                        }
                    },

                    glow = {
                        type = "group",
                        name = "高亮",
                        desc = "设置高亮或覆盖的选项。",
                        order = 6,
                        args = {
                            enabled = {
                                type = "toggle",
                                name = "启用",
                                desc = "如果启用，当队列中第一个技能具有高亮（或覆盖）的功能，也将在显示区域中同步高亮。",
                                width = 1.49,
                                order = 1,
                            },

                            queued = {
                                type = "toggle",
                                name = "对队列图标启用",
                                desc = "如果启用，具有高亮（或覆盖）功能的队列技能图标也将在队列中同步高亮。\n\n" ..
                                    "此项效果可能不理想，在未来的时间点，高亮状态可能不再正确。",
                                width = 1.49,
                                order = 2,
                                disabled = function() return data.glow.enabled == false end,
                            },

                            break01 = {
                                type = "description",
                                name = " ",
                                order = 2.1,
                                width = "full"
                            },

                            mode = {
                                type = "select",
                                name = "高亮样式",
                                desc = "设置显示区域的高亮样式。",
                                width = 1,
                                order = 3,
                                values = {
                                    default = "默认按钮高亮",
                                    autocast = "自动闪光",
                                    pixel = "像素发光",
                                },
                                disabled = function() return data.glow.enabled == false end,
                            },

                            coloring = {
                                type = "select",
                                name = "着色模式",
                                desc = "设置高亮效果的着色模式。",
                                width = 0.99,
                                order = 4,
                                values = {
                                    default = "使用默认颜色",
                                    class = format("Class |A:WhiteCircle-RaidBlips:16:16:0:0:%d:%d:%d|a #%s",
                                        ClassColor.r * 255, ClassColor.g * 255, ClassColor.b * 255,
                                        ClassColor:GenerateHexColor():sub(3, 8)),
                                    custom = "设置自定义颜色"
                                },
                                disabled = function() return data.glow.enabled == false end,
                            },

                            color = {
                                type = "color",
                                name = "高亮颜色",
                                desc = "设置该显示区域的高亮颜色。",
                                width = 0.99,
                                order = 5,
                                disabled = function() return data.glow.coloring ~= "custom" end,
                            },

                            break02 = {
                                type = "description",
                                name = " ",
                                order = 10,
                                width = "full",
                            },

                            highlight = {
                                type = "toggle",
                                name = "技能高亮",
                                desc = "技能高亮",
                                width = "full",
                                order = 11
                            },
                        },
                    },

                    flash = {
                        type = "group",
                        name = "技能高光",
                        desc = function()
                            if SF then
                                return "如果勾选，插件可以在推荐使用某个技能时，在动作条技能图标上进行高光提示。"
                            end
                            return "此功能要求SpellFlash插件或库正常工作。"
                        end,
                        order = 8,
                        args = {
                            warning = {
                                type = "description",
                                name = "此页设置不可用。原因是SpellFlash插件没有安装或被禁用。",
                                order = 0,
                                fontSize = "medium",
                                width = "full",
                                hidden = function() return SF ~= nil end,
                            },

                            enabled = {
                                type = "toggle",
                                name = "启用",
                                desc = "如果勾选，插件将该显示区域的第一个推荐技能图标上显示彩色高光。",
                                width = 1.49,
                                order = 1,
                                hidden = function() return SF == nil end,
                            },

                            color = {
                                type = "color",
                                name = "颜色",
                                desc = "设置技能高亮的高光颜色。",
                                order = 2,
                                width = 1.49,
                                hidden = function() return SF == nil end,
                            },

                            break00 = {
                                type = "description",
                                name = " ",
                                order = 2.1,
                                width = "full",
                                hidden = function() return SF == nil end,
                            },

                            sample = {
                                type = "description",
                                name = "",
                                image = function() return AdvancedInterfaceOptions.DB.profile.flashTexture end,
                                order = 3,
                                width = 0.3,
                                hidden = function() return SF == nil end,
                            },

                            flashTexture = {
                                type = "select",
                                name = "纹理",
                                icon = function() return data.flash.texture or "Interface\\Cooldown\\star4" end,
                                desc = "技能高亮时，出现的纹理图片",
                                order = 3.1,
                                width = 1.19,
                                values = {
                                    ["Interface\\AddOns\\AdvancedInterfaceOptions\\Textures\\MonoCircle2"] = "Monochrome Circle Thin",
                                    ["Interface\\AddOns\\AdvancedInterfaceOptions\\Textures\\MonoCircle5"] = "Monochrome Circle Thick",
                                    ["Interface\\Cooldown\\ping4"] = "Circle",
                                    ["Interface\\Cooldown\\star4"] = "Star (Default)",
                                    ["Interface\\Cooldown\\starburst"] = "Starburst",
                                    ["Interface\\Masks\\CircleMaskScalable"] = "Filled Circle",
                                    ["Interface\\Masks\\SquareMask"] = "Filled Square",
                                    ["Interface\\Soulbinds\\SoulbindsConduitCollectionsIconMask"] = "Filled Octagon",
                                    ["Interface\\Soulbinds\\SoulbindsConduitPendingAnimationMask"] = "Octagon Outline",
                                    ["Interface\\Soulbinds\\SoulbindsEnhancedConduitMask"] = "Octagon Thick",
                                },
                                get = function()
                                    return AdvancedInterfaceOptions.DB.profile.flashTexture
                                end,
                                set = function(_, val)
                                    AdvancedInterfaceOptions.DB.profile.flashTexture = val
                                end,
                                hidden = function() return SF == nil end,
                            },

                            speed = {
                                type = "range",
                                name = "速度",
                                desc = "闪动的速度",
                                min = 0.1,
                                max = 2,
                                step = 0.1,
                                order = 3.2,
                                width = 1.49,
                                hidden = function() return SF == nil end,
                            },

                            break01 = {
                                type = "description",
                                name = " ",
                                order = 4,
                                width = "full",
                                hidden = function() return SF == nil end,
                            },

                            size = {
                                type = "range",
                                name = "大小",
                                desc = "设置技能高光的光晕大小。默认大小为|cFFFFD100240|r。",
                                order = 5,
                                min = 0,
                                max = 240 * 8,
                                step = 1,
                                width = 1.49,
                                hidden = function() return SF == nil end,
                            },

                            fixedSize = {
                                type = "toggle",
                                name = "固定大小",
                                desc = "如果勾选，所有技能高光的缩放提示效果将被禁用。",
                                order = 6,
                                width = 1.49,
                                hidden = function() return SF == nil end,
                            },

                            break02 = {
                                type = "description",
                                name = " ",
                                order = 7,
                                width = "full",
                                hidden = function() return SF == nil end,
                            },

                            brightness = {
                                type = "range",
                                name = "亮度",
                                desc = "设置技能高光的亮度。默认亮度为|cFFFFD100100|r。",
                                order = 8,
                                min = 0,
                                max = 100,
                                step = 1,
                                width = 1.49,
                                hidden = function() return SF == nil end,
                            },

                            fixedBrightness = {
                                type = "toggle",
                                name = "固定亮度",
                                desc = "如果勾选，所有技能高光的明暗提示效果将被禁用。",
                                order = 9,
                                width = 1.49,
                                hidden = function() return SF == nil end,
                            },

                            break03 = {
                                type = "description",
                                name = " ",
                                order = 10,
                                width = "full",
                                hidden = function() return SF == nil end,
                            },

                            combat = {
                                type = "toggle",
                                name = "只在战斗中生效",
                                desc = "如果勾选此项，插件将仅在您处于战斗状态时生成闪光效果。",
                                order = 11,
                                width = "full",
                                hidden = function() return SF == nil end,
                            },

                            suppress = {
                                type = "toggle",
                                name = "隐藏显示",
                                desc = "如果勾选，显示区域将被隐藏，仅通过技能高光功能进行技能推荐。",
                                order = 12,
                                width = "full",
                                hidden = function() return SF == nil end,
                            },

                            blink = {
                                type = "toggle",
                                name = "按钮闪烁",
                                desc = "如果勾选，技能图标将以闪烁进行提示。默认值为|cFFFF0000禁用|r。",
                                order = 13,
                                width = "full",
                                hidden = function() return SF == nil end,
                            },
                        },
                    },

                    captions = {
                        type = "group",
                        name = "提示",
                        desc = "提示是动作条中偶尔使用的简短描述，用于该技能的说明。",
                        order = 9,
                        args = {
                            enabled = {
                                type = "toggle",
                                name = "启用",
                                desc = "如果勾选，当显示框中第一个技能具有说明时，将显示该说明。",
                                order = 1,
                                width = 1.49,
                            },

                            queued = {
                                type = "toggle",
                                name = "对队列图标启用",
                                desc = "如果勾选，将显示队列技能图标的说明（如果可用）。",
                                order = 2,
                                width = 1.49,
                                disabled = function() return data.captions.enabled == false end,
                            },

                            position = {
                                type = "group",
                                inline = true,
                                name = function(info)
                                    rangeIcon(info)
                                    return "位置"
                                end,
                                order = 3,
                                args = {
                                    anchor = {
                                        type = "select",
                                        name = '锚点',
                                        order = 1,
                                        width = 1,
                                        values = {
                                            TOP = '顶部',
                                            BOTTOM = '底部',
                                        }
                                    },

                                    x = {
                                        type = "range",
                                        name = "X轴偏移",
                                        order = 2,
                                        width = 0.99,
                                        step = 1,
                                    },

                                    y = {
                                        type = "range",
                                        name = "Y轴偏移",
                                        order = 3,
                                        width = 0.99,
                                        step = 1,
                                    },

                                    break01 = {
                                        type = "description",
                                        name = " ",
                                        order = 3.1,
                                        width = "full",
                                    },

                                    align = {
                                        type = "select",
                                        name = "对齐",
                                        order = 4,
                                        width = 1.49,
                                        values = {
                                            LEFT = "左对齐",
                                            RIGHT = "右对齐",
                                            CENTER = "居中对齐"
                                        },
                                    },
                                }
                            },

                            textStyle = {
                                type = "group",
                                inline = true,
                                name = "文本",
                                order = 4,
                                args = tableCopy(fontElements),
                            },
                        }
                    },

                    empowerment = {
                        type = "group",
                        name = "蓄力提示",
                        desc = "技能队列显示的蓄力等级",
                        order = 9.1,
                        hidden = function()
                            local spec = class.specs[ state.spec.id ]
                            return not spec or not spec.can_empower
                        end,
                        args = {
                            enabled = {
                                type = "toggle",
                                name = "启用",
                                desc = "如果勾选插件将会在技能队列上显示蓄力等级",
                                order = 1,
                                width = 1.49,
                            },

                            queued = {
                                type = "toggle",
                                name = "后续队列生效",
                                desc = "如果勾选，将会在全部的技能队列显示.",
                                order = 2,
                                width = 1.49,
                                disabled = function() return data.empowerment.enabled == false end,
                            },

                            glow = {
                                type = "toggle",
                                name = "蓄力技能高亮",
                                desc = "蓄力时候发光",
                                order = 2.5,
                                width = "full",
                            },

                            position = {
                                type = "group",
                                inline = true,
                                name = function(info)
                                    rangeIcon(info)
                                    return "文本位置"
                                end,
                                order = 3,
                                args = {
                                    anchor = {
                                        type = "select",
                                        name = '锚点位置',
                                        order = 1,
                                        width = 1,
                                        values = {
                                            TOP = '顶部',
                                            BOTTOM = '底部',
                                        }
                                    },

                                    x = {
                                        type = "range",
                                        name = "X轴偏移",
                                        order = 2,
                                        width = 0.99,
                                        step = 1,
                                    },

                                    y = {
                                        type = "range",
                                        name = "Y轴偏移",
                                        order = 3,
                                        width = 0.99,
                                        step = 1,
                                    },

                                    break01 = {
                                        type = "description",
                                        name = " ",
                                        order = 3.1,
                                        width = "full",
                                    },

                                    align = {
                                        type = "select",
                                        name = "对齐方式",
                                        order = 4,
                                        width = 1.49,
                                        values = {
                                            LEFT = "左对齐",
                                            RIGHT = "右对齐",
                                            CENTER = "居中显示"
                                        },
                                    },
                                }
                            },

                            textStyle = {
                                type = "group",
                                inline = true,
                                name = "文本",
                                order = 4,
                                args = tableCopy(fontElements),
                            },
                        }
                    },

                    targets = {
                        type = "group",
                        name = "目标数",
                        desc = "目标数量统计可以在显示框的第一个技能图标上。",
                        order = 10,
                        args = {
                            enabled = {
                                type = "toggle",
                                name = "启用",
                                desc = "如果勾选，插件将在显示框上显示识别到的目标数。",
                                order = 1,
                                width = "full",
                            },

                            pos = {
                                type = "group",
                                inline = true,
                                name = function(info)
                                    rangeIcon(info)
                                    return "位置"
                                end,
                                order = 2,
                                args = {
                                    anchor = {
                                        type = "select",
                                        name = "锚定到",
                                        values = realAnchorPositions,
                                        order = 1,
                                        width = 1,
                                    },

                                    x = {
                                        type = "range",
                                        name = "X轴偏移",
                                        min = -max(data.primaryWidth, data.queue.width),
                                        max = max(data.primaryWidth, data.queue.width),
                                        step = 1,
                                        order = 2,
                                        width = 0.99,
                                    },

                                    y = {
                                        type = "range",
                                        name = "Y轴偏移",
                                        min = -max(data.primaryHeight, data.queue.height),
                                        max = max(data.primaryHeight, data.queue.height),
                                        step = 1,
                                        order = 2,
                                        width = 0.99,
                                    }
                                }
                            },

                            textStyle = {
                                type = "group",
                                inline = true,
                                name = "文本",
                                order = 3,
                                args = tableCopy(fontElements),
                            },
                        }
                    },

                    delays = {
                        type = "group",
                        name = "延时",
                        desc =
                        "当未来某个时间点建议使用某个技能时，使用着色或倒计时进行延时提示。",
                        order = 11,
                        args = {
                            extend = {
                                type = "toggle",
                                name = "扩展冷却扫描",
                                desc = "如果勾选，主图标的冷却扫描将不会刷新，直到该技能被使用。",
                                width = 1.49,
                                order = 1,
                            },

                            fade = {
                                type = "toggle",
                                name = "无法使用则淡化",
                                desc = "当你在施放该技能之前等待时，主图标将淡化，类似于某个技能缺少能量时。",
                                width = 1.49,
                                order = 1.1
                            },

                            desaturate = {
                                type = "toggle",
                                name = format("%s 去饱和度", NewFeature),
                                desc = "当您应该等待使用该功能时，降低主图标的饱和度",
                                width = 1.49,
                                order = 1.15
                            },

                            break01 = {
                                type = "description",
                                name = " ",
                                order = 1.2,
                                width = "full",
                            },

                            type = {
                                type = "select",
                                name = "提示方式",
                                desc =
                                "设置在施放该技能之前等待时间的提示方式。",
                                values = {
                                    __NA = "不提示",
                                    ICON = "显示图标（颜色）",
                                    TEXT = "显示文本（倒计时）",
                                },
                                width = 1.49,
                                order = 2,
                            },

                            pos = {
                                type = "group",
                                inline = true,
                                name = function(info)
                                    rangeIcon(info)
                                    return "位置"
                                end,
                                order = 3,
                                args = {
                                    anchor = {
                                        type = "select",
                                        name = '锚点',
                                        order = 2,
                                        width = 1,
                                        values = realAnchorPositions
                                    },

                                    x = {
                                        type = "range",
                                        name = "X轴偏移",
                                        order = 3,
                                        width = 0.99,
                                        min = -max(data.primaryWidth, data.queue.width),
                                        max = max(data.primaryWidth, data.queue.width),
                                        step = 1,
                                    },

                                    y = {
                                        type = "range",
                                        name = "Y轴偏移",
                                        order = 4,
                                        width = 0.99,
                                        min = -max(data.primaryHeight, data.queue.height),
                                        max = max(data.primaryHeight, data.queue.height),
                                        step = 1,
                                    }
                                },
                                disabled = function() return data.delays.type == "__NA" end,
                            },

                            textStyle = {
                                type = "group",
                                inline = true,
                                name = "文本",
                                order = 4,
                                args = tableCopy(fontElements),
                                disabled = function() return data.delays.type ~= "TEXT" end,
                            },
                        }
                    },

                    indicators = {
                        type = "group",
                        name = "扩展提示",
                        desc = "扩展提示是当需要切换目标时或取消增益效果时的小图标。",
                        order = 11,
                        args = {
                            enabled = {
                                type = "toggle",
                                name = "启用",
                                desc = "如果勾选，主图标上将会出现提示切换目标和取消效果的小图标。",
                                order = 1,
                                width = 1.49,
                            },

                            queued = {
                                type = "toggle",
                                name = "对队列图标启用",
                                desc = "如果勾选，扩展提示也将适时地出现在队列图标上。",
                                order = 2,
                                width = 1.49,
                                disabled = function() return data.indicators.enabled == false end,
                            },

                          size = {
                                type = "group",
                                inline = true,
                                name = "外观",
                                order = 1.5,
                                args = {
                                    width = {
                                        type = "range",
                                        name = "宽",
                                        desc = "指定指示符图标的宽",
                                        min = 8,
                                        max = 100,
                                        step = 1,
                                        width = 1.49,
                                        order = 1,
                                    },

                                    height = {
                                        type = "range",
                                        name = "高",
                                        desc = "指定指示符图标的宽",
                                        min = 8,
                                        max = 100,
                                        step = 1,
                                        width = 1.49,
                                        order = 2,
                                    },

                                    spacer01 = {
                                        type = "description",
                                        name = " ",
                                        width = "full",
                                        order = 3
                                    },

                                    zoom = {
                                        type = "range",
                                        name = "Icon 缩放",
                                        desc = "选择指示器图标纹理的缩放百分比。（大约30%会裁剪掉默认的暴雪边框。）",
                                        min = 0,
                                        softMax = 100,
                                        max = 200,
                                        step = 1,
                                        width = 1.49,
                                        order = 4,
                                    },

                                    keepAspectRatio = {
                                        type = "toggle",
                                        name = "等比缩放",
                                        desc = "启用后，调整指示器图标大小时将保持其原始宽高比。",
                                        width = 1.49,
                                        order = 5,
                                    },
                                }
                            },

                            pos = {
                                type = "group",
                                inline = true,
                                name = function(info)
                                    rangeIcon(info)
                                    return "位置"
                                end,
                                order = 2,
                                args = {
                                    anchor = {
                                        type = "select",
                                        name = "锚点",
                                        values = realAnchorPositions,
                                        order = 1,
                                        width = 1,
                                    },

                                    x = {
                                        type = "range",
                                        name = "X轴偏移",
                                        min = -max(data.primaryWidth, data.queue.width),
                                        max = max(data.primaryWidth, data.queue.width),
                                        step = 1,
                                        order = 2,
                                        width = 0.99,
                                    },

                                    y = {
                                        type = "range",
                                        name = "Y轴偏移",
                                        min = -max(data.primaryHeight, data.queue.height),
                                        max = max(data.primaryHeight, data.queue.height),
                                        step = 1,
                                        order = 2,
                                        width = 0.99,
                                    }
                                }
                            },
                        }
                    },
                },
            },
        }

        return option
    end


    function AdvancedInterfaceOptions:EmbedDisplayOptions(db)
        db = db or self.Options
        if not db then return end

        local section = db.args.displays or {
            type = "group",
            name = "外观设置",
            childGroups = "tree",
            cmdHidden = true,
            get = 'GetDisplayOption',
            set = 'SetDisplayOption',
            order = 30,

            args = {
                header = {
                    type = "description",
                    name = "这里可以设置技能提示和通知的外观样式 " ..
                        "例如， 技能提示的数量， 文字的大小 位置等" ..
                        "灵活调整这些配置可以更好的监控和预判技能的释放 ",
                    fontSize = "medium",
                    width = "full",
                    order = 1,
                },

                displays = {
                    type = "header",
                    name = "外观样式",
                    order = 10,
                },


                nPanelHeader = {
                    type = "header",
                    name = "通知栏",
                    order = 950,
                },

                nPanelBtn = {
                    type = "execute",
                    name = AdvancedInterfaceOptions.Local["notify"],
                    desc = "通知面板在战斗中更改或切换设置时提供简短变化。",
                    func = function()
                        ACD:SelectGroup("AdvancedInterfaceOptions", "displays", "nPanel")
                    end,
                    order = 951,
                },

                nPanel = {
                    type = "group",
                    name = AdvancedInterfaceOptions.Local["notify"],
                    desc = "通知面板在战斗中更改或切换设置时提供简短变化。",
                    order = 952,
                    get = GetNotifOption,
                    set = SetNotifOption,
                    args = {
                        enabled = {
                            type = "toggle",
                            name = "启用",
                            order = 1,
                            width = "full",
                        },

                        posRow = {
                            type = "group",
                            name = function(info)
                                rangeXY(info, true)
                                return "位置"
                            end,
                            inline = true,
                            order = 2,
                            args = {
                                x = {
                                    type = "range",
                                    name = "X",
                                    desc = "输入通知面板的横向位置，相对于屏幕中心。负值将面板向左移动；正值将面板向右移动。",
                                    min = -512,
                                    max = 512,
                                    step = 1,

                                    width = 1.49,
                                    order = 1,
                                },

                                y = {
                                    type = "range",
                                    name = "Y",
                                    desc = "输入通知面板的纵向位置，相对于屏幕中心。负值将面板向下移动；正值将面板向上移动。",
                                    min = -384,
                                    max = 384,
                                    step = 1,

                                    width = 1.49,
                                    order = 2,
                                },
                            }
                        },

                        sizeRow = {
                            type = "group",
                            name = "大小",
                            inline = true,
                            order = 3,
                            args = {
                                width = {
                                    type = "range",
                                    name = "宽",
                                    min = 50,
                                    max = 1000,
                                    step = 1,

                                    width = "full",
                                    order = 1,
                                },

                                height = {
                                    type = "range",
                                    name = "高",
                                    min = 20,
                                    max = 600,
                                    step = 1,

                                    width = "full",
                                    order = 2,
                                },
                            }
                        },

                        fontGroup = {
                            type = "group",
                            inline = true,
                            name = "文字",

                            order = 5,
                            args = tableCopy(fontElements),
                        },
                    }
                },

                fontHeader = {
                    type = "header",
                    name = "字体",
                    order = 960,
                },

                fontWarn = {
                    type = "description",
                    name = "更改下面的字体将修改 |cFFFF0000所有|r 显示上的文本。\n" ..
                        "要单独修改某一段文本，请选择左侧的显示项并选择相应的文本。",
                    order = 960.01,
                },

                font = {
                    type = "select",
                    name = "字体",
                    order = 960.1,
                    width = 1.5,
                    dialogControl = 'LSM30_Font',
                    values = LSM:HashTable("font"),
                    get = function(info)
                        -- Display the information from Primary, Keybinds.
                        return AdvancedInterfaceOptions.DB.profile.displays.Primary.keybindings.font
                    end,
                    set = function(info, val)
                        -- Set all fonts in all displays.
                        for _, display in pairs(AdvancedInterfaceOptions.DB.profile.displays) do
                            for _, data in pairs(display) do
                                if type(data) == "table" and data.font then data.font = val end
                            end
                        end
                        QueueRebuildUI()
                    end,
                },

                fontSize = {
                    type = "range",
                    name = "大小",
                    order = 960.2,
                    min = 8,
                    max = 64,
                    step = 1,
                    get = function(info)
                        -- Display the information from Primary, Keybinds.
                        return AdvancedInterfaceOptions.DB.profile.displays.Primary.keybindings.fontSize
                    end,
                    set = function(info, val)
                        -- Set all fonts in all displays.
                        for _, display in pairs(AdvancedInterfaceOptions.DB.profile.displays) do
                            for _, data in pairs(display) do
                                if type(data) == "table" and data.fontSize then data.fontSize = val end
                            end
                        end
                        QueueRebuildUI()
                    end,
                    width = 1.5,
                },

                fontStyle = {
                    type = "select",
                    name = "风格",
                    order = 960.3,
                    values = {
                        ["MONOCHROME"] = "Monochrome",
                        ["MONOCHROME,OUTLINE"] = "Monochrome, Outline",
                        ["MONOCHROME,THICKOUTLINE"] = "Monochrome, Thick Outline",
                        ["NONE"] = "None",
                        ["OUTLINE"] = "Outline",
                        ["THICKOUTLINE"] = "Thick Outline"
                    },
                    get = function(info)
                        -- Display the information from Primary, Keybinds.
                        return AdvancedInterfaceOptions.DB.profile.displays.Primary.keybindings.fontStyle
                    end,
                    set = function(info, val)
                        -- Set all fonts in all displays.
                        for _, display in pairs(AdvancedInterfaceOptions.DB.profile.displays) do
                            for _, data in pairs(display) do
                                if type(data) == "table" and data.fontStyle then data.fontStyle = val end
                            end
                        end
                        QueueRebuildUI()
                    end,
                    width = 1.5,
                },

                color = {
                    type = "color",
                    name = "颜色",
                    order = 960.4,
                    get = function(info)
                        return unpack(AdvancedInterfaceOptions.DB.profile.displays.Primary.keybindings.color)
                    end,
                    set = function(info, ...)
                        for name, display in pairs(AdvancedInterfaceOptions.DB.profile.displays) do
                            for _, data in pairs(display) do
                                if type(data) == "table" and data.color then data.color = { ... } end
                            end
                        end
                        QueueRebuildUI()
                    end,
                    width = 1.5
                },

                shareHeader = {
                    type = "header",
                    name = "分享",
                    order = 996,
                },

                shareBtn = {
                    type = "execute",
                    name = "分享样式",
                    desc = "你可以通过这些导出字符串与其他插件用户共享你的显示样式。\n\n" ..
                        "你也可以在此处导入一个共享的样式导出字符串。",
                    func = function()
                        ACD:SelectGroup("AdvancedInterfaceOptions", "displays", "shareDisplays")
                    end,
                    order = 998,
                },

                shareDisplays = {
                    type = "group",
                    name = "|cFF1EFF00分享外观样式|r",
                    desc = "你可以通过这些导出字符串与其他插件用户共享你的显示样式。\n\n" ..
                        "你也可以在此处导入一个共享的样式导出字符串。",
                    childGroups = "tab",
                    get = 'GetDisplayShareOption',
                    set = 'SetDisplayShareOption',
                    order = 999,
                    args = {
                        import = {
                            type = "group",
                            name = "导入",
                            order = 1,
                            args = {
                                stage0 = {
                                    type = "group",
                                    name = "",
                                    inline = true,
                                    order = 1,
                                    args = {
                                        guide = {
                                            type = "description",
                                            name = "选择一个已保存的样式，或在提供的框中粘贴导入字符串。",
                                            order = 1,
                                            width = "full",
                                            fontSize = "medium",
                                        },

                                        separator = {
                                            type = "header",
                                            name = "导入字符",
                                            order = 1.5,
                                        },

                                        selectExisting = {
                                            type = "select",
                                            name = "选择已有的",
                                            order = 2,
                                            width = "full",
                                            get = function()
                                                return "0000000000"
                                            end,
                                            set = function(info, val)
                                                local style = self.DB.global.styles[val]

                                                if style then shareDB.import = style.payload end
                                            end,
                                            values = function()
                                                local db = self.DB.global.styles
                                                local values = {
                                                    ["0000000000"] = "选择已有的"
                                                }

                                                for k, v in pairs(db) do
                                                    values[k] = k .. " (|cFF00FF00" .. v.date .. "|r)"
                                                end

                                                return values
                                            end,
                                        },

                                        importString = {
                                            type = "input",
                                            name = "需要导入的字符",
                                            get = function() return shareDB.import end,
                                            set = function(info, val)
                                                val = val:trim()
                                                shareDB.import = val
                                            end,
                                            order = 3,
                                            multiline = 5,
                                            width = "full",
                                        },

                                        btnSeparator = {
                                            type = "header",
                                            name = "导入",
                                            order = 4,
                                        },

                                        importBtn = {
                                            type = "execute",
                                            name = "导入",
                                            order = 5,
                                            func = function()
                                                shareDB.imported, shareDB.error = DeserializeStyle(shareDB.import)

                                                if shareDB.error then
                                                    shareDB.import = "导入错误.\n" .. shareDB.error
                                                    shareDB.error = nil
                                                    shareDB.imported = {}
                                                else
                                                    shareDB.importStage = 1
                                                end
                                            end,
                                            disabled = function()
                                                return shareDB.import == ""
                                            end,
                                        },
                                    },
                                    hidden = function() return shareDB.importStage ~= 0 end,
                                },

                                stage1 = {
                                    type = "group",
                                    inline = true,
                                    name = "",
                                    order = 1,
                                    args = {
                                        guide = {
                                            type = "description",
                                            name = function()
                                                local creates, replaces = {}, {}

                                                for k, v in pairs(shareDB.imported) do
                                                    if rawget(self.DB.profile.displays, k) then
                                                        insert(replaces, k)
                                                    else
                                                        insert(creates, k)
                                                    end
                                                end

                                                local o = ""

                                                if #creates > 0 then
                                                    o = o .. "导入的样式将创建以下显示："
                                                    for i, display in orderedPairs(creates) do
                                                        if i == 1 then
                                                            o = o .. display
                                                        else
                                                            o = o .. ", " .. display
                                                        end
                                                    end
                                                    o = o .. ".\n"
                                                end

                                                if #replaces > 0 then
                                                    o = o .. "导入的样式将覆盖以下显示："
                                                    for i, display in orderedPairs(replaces) do
                                                        if i == 1 then
                                                            o = o .. display
                                                        else
                                                            o = o .. ", " .. display
                                                        end
                                                    end
                                                    o = o .. "."
                                                end

                                                return o
                                            end,
                                            order = 1,
                                            width = "full",
                                            fontSize = "medium",
                                        },

                                        separator = {
                                            type = "header",
                                            name = "接受",
                                            order = 2,
                                        },

                                        apply = {
                                            type = "execute",
                                            name = "接受",
                                            order = 3,
                                            confirm = true,
                                            func = function()
                                                for k, v in pairs(shareDB.imported) do
                                                    if type(v) == "table" then self.DB.profile.displays[k] = v end
                                                end

                                                shareDB.import = ""
                                                shareDB.imported = {}
                                                shareDB.importStage = 2

                                                self:EmbedDisplayOptions()
                                                QueueRebuildUI()
                                            end,
                                        },

                                        reset = {
                                            type = "execute",
                                            name = "重置",
                                            order = 4,
                                            func = function()
                                                shareDB.import = ""
                                                shareDB.imported = {}
                                                shareDB.importStage = 0
                                            end,
                                        },
                                    },
                                    hidden = function() return shareDB.importStage ~= 1 end,
                                },

                                stage2 = {
                                    type = "group",
                                    inline = true,
                                    name = "",
                                    order = 3,
                                    args = {
                                        note = {
                                            type = "description",
                                            name = "导入的设置已成功应用！\n\n如果需要，可以点击重置以重新开始。",
                                            order = 1,
                                            fontSize = "medium",
                                            width = "full",
                                        },

                                        reset = {
                                            type = "execute",
                                            name = "重置",
                                            order = 2,
                                            func = function()
                                                shareDB.import = ""
                                                shareDB.imported = {}
                                                shareDB.importStage = 0
                                            end,
                                        }
                                    },
                                    hidden = function() return shareDB.importStage ~= 2 end,
                                }
                            },
                            plugins = {
                            }
                        },

                        export = {
                            type = "group",
                            name = "导出",
                            order = 2,
                            args = {
                                stage0 = {
                                    type = "group",
                                    name = "",
                                    inline = true,
                                    order = 1,
                                    args = {
                                        guide = {
                                            type = "description",
                                            name = "选择要导出的显示样式设置，然后点击导出样式生成导出字符串。",
                                            order = 1,
                                            fontSize = "medium",
                                            width = "full",
                                        },

                                        displays = {
                                            type = "header",
                                            name = "界面显示",
                                            order = 2,
                                        },

                                        exportHeader = {
                                            type = "header",
                                            name = "导出",
                                            order = 1000,
                                        },

                                        exportBtn = {
                                            type = "execute",
                                            name = "导出样式",
                                            order = 1001,
                                            func = function()
                                                local disps = {}
                                                for key, share in pairs(shareDB.displays) do
                                                    if share then insert(disps, key) end
                                                end

                                                shareDB.export = SerializeStyle(unpack(disps))
                                                shareDB.exportStage = 1
                                            end,
                                            disabled = function()
                                                local hasDisplay = false

                                                for key, value in pairs(shareDB.displays) do
                                                    if value then
                                                        hasDisplay = true
                                                        break
                                                    end
                                                end

                                                return not hasDisplay
                                            end,
                                        },
                                    },
                                    plugins = {
                                        displays = {}
                                    },
                                    hidden = function()
                                        local plugins = self.Options.args.displays.args.shareDisplays.args.export.args
                                        .stage0.plugins.displays
                                        wipe(plugins)

                                        local i = 1
                                        for dispName, display in pairs(self.DB.profile.displays) do
                                            if dispName == "Primary" then
                                                local pos = 20 + (display.builtIn and display.order or i)
                                                plugins[dispName] = {
                                                    type = "toggle",
                                                    name = function()
                                                        if display.builtIn then return "|cFF00B4FF" .. "技能队列提示样式" .. "|r" end
                                                        return dispName
                                                    end,
                                                    order = pos,
                                                    width = "full"
                                                }
                                                i = i + 1
                                            end
                                        end

                                        return shareDB.exportStage ~= 0
                                    end,
                                },

                                stage1 = {
                                    type = "group",
                                    name = "",
                                    inline = true,
                                    order = 1,
                                    args = {
                                        exportString = {
                                            type = "input",
                                            name = "样式字符串",
                                            order = 1,
                                            multiline = 8,
                                            get = function() return shareDB.export end,
                                            set = function() end,
                                            width = "full",
                                            hidden = function() return shareDB.export == "" end,
                                        },

                                        instructions = {
                                            type = "description",
                                            name = "你可以复制上面的字符串来分享你选择的显示样式设置，或者\n" ..
                                                "使用下面的选项保存这些设置（以便日后恢复）。",
                                            order = 2,
                                            width = "full",
                                            fontSize = "medium"
                                        },

                                        store = {
                                            type = "group",
                                            inline = true,
                                            name = "",
                                            order = 3,
                                            hidden = function() return shareDB.export == "" end,
                                            args = {
                                                separator = {
                                                    type = "header",
                                                    name = "保存样式",
                                                    order = 1,
                                                },

                                                exportName = {
                                                    type = "input",
                                                    name = "样式名称",
                                                    get = function() return shareDB.styleName end,
                                                    set = function(info, val)
                                                        val = val:trim()
                                                        shareDB.styleName = val
                                                    end,
                                                    order = 2,
                                                    width = "double",
                                                },

                                                storeStyle = {
                                                    type = "execute",
                                                    name = "保存导出字符串",
                                                    desc = "通过保存你的导出字符串，你可以保存这些显示设置，若你对设置进行了更改，稍后可以重新取回这些设置。\n\n" ..
                                                        "即使你使用不同的角色配置，已保存的样式也可以从任何角色中恢复。",
                                                    order = 3,
                                                    confirm = function()
                                                        if shareDB.styleName and self.DB.global.styles[shareDB.styleName] ~= nil then
                                                            return "已经存在一个名为的样式: " .. shareDB.styleName .. "' -- 确定覆盖?"
                                                        end
                                                        return false
                                                    end,
                                                    func = function()
                                                        local db = self.DB.global.styles
                                                        db[shareDB.styleName] = {
                                                            date = tonumber(date("%Y%m%d.%H%M%S")),
                                                            payload = shareDB.export,
                                                        }
                                                        shareDB.styleName = ""
                                                    end,
                                                    disabled = function()
                                                        return shareDB.export == "" or shareDB.styleName == ""
                                                    end,
                                                }
                                            }
                                        },


                                        restart = {
                                            type = "execute",
                                            name = "重新开始",
                                            order = 4,
                                            func = function()
                                                shareDB.styleName = ""
                                                shareDB.export = ""
                                                wipe(shareDB.displays)
                                                shareDB.exportStage = 0
                                            end,
                                        }
                                    },
                                    hidden = function() return shareDB.exportStage ~= 1 end
                                }
                            },
                            plugins = {
                                displays = {}
                            },
                        }
                    }
                },
            },
            plugins = {},
        }
        db.args.displays = section
        wipe(section.plugins)

        local i = 1

        for name, data in pairs(self.DB.profile.displays) do
            if name == "Primary" then
                local pos = data.builtIn and data.order or i
                section.plugins[name] = newDisplayOption(db, name, data, pos)
                if not data.builtIn then i = i + 1 end
            end
        end
        --
        -- section.plugins["Multi"] = newDisplayOption(db, "Multi", self.DB.profile.displays["Primary"], 0)
        -- MakeMultiDisplayOption(section.plugins, section.plugins.Multi.Multi.args)
    end
end

do
    local impControl = {
        name = "",
        source = UnitName( "player" ) .. " @ " .. GetRealmName(),
        apl = "Paste your SimulationCraft action priority list or profile here.",

        lists = {},
        warnings = ""
    }

    AdvancedInterfaceOptions.ImporterData = impControl


    local function AddWarning( s )
        if impControl.warnings then
            impControl.warnings = impControl.warnings .. s .. "\n"
            return
        end

        impControl.warnings = s .. "\n"
    end


    function AdvancedInterfaceOptions:GetImporterOption( info )
        return impControl[ info[ #info ] ]
    end


    function AdvancedInterfaceOptions:SetImporterOption( info, value )
        if type( value ) == 'string' then value = value:trim() end
        impControl[ info[ #info ] ] = value
        impControl.warnings = nil
    end


    function AdvancedInterfaceOptions:ImportSimcAPL( name, source, apl, pack )

        name = name or impControl.name
        source = source or impControl.source
        apl = apl or impControl.apl

        impControl.warnings = ""

        local lists = {
            precombat = "",
            default = "",
            healthstone = ""
        }

        local count = 0

        -- Rename the default action list to 'default'
        apl = "\n" .. apl
        apl = apl:gsub( "actions(%+?)=", "actions.default%1=" )

        local comment

        for line in apl:gmatch( "\n([^\n^$]*)") do
            local newComment = line:match( "^# (.+)" )
            if newComment then
                if comment then
                    comment = comment .. ' ' .. newComment
                else
                    comment = newComment
                end
            end

            local list, action = line:match( "^[ +]?actions%.(%S-)%+?=/?([^\n^$]*)" )

            if list and action then
                lists[ list ] = lists[ list ] or ""

                if action:sub( 1, 16 ) == "call_action_list" or action:sub( 1, 15 ) == "run_action_list" then
                    local name = action:match( ",name=(.-)," ) or action:match( ",name=(.-)$" )
                    if name then action:gsub( ",name=" .. name, ",name=\"" .. name .. "\"" ) end
                end

                if comment then
                    -- Comments can have the form 'Caption::Description'.
                    -- Any whitespace around the '::' is truncated.
                    local caption, description = comment:match( "(.+)::(.*)" )
                    if caption and description then
                        -- Truncate whitespace and change commas to semicolons.
                        caption = caption:gsub( "%s+$", "" ):gsub( ",", ";" )
                        description = description:gsub( "^%s+", "" ):gsub( ",", ";" )
                        -- Replace "[<texture-id>]" in the caption with the escape sequence for the texture.
                        caption = caption:gsub( "%[(%d+)%]", "|T%1:0|t" )
                        -- Replace "[h:<text>]" in the caption with the escape sequence for the texture string.
                        caption = caption:gsub( "%[h:(.-)%]", "|TInterface\\AddOns\\AdvancedInterfaceOptions\\Textures\\%1:0|t" )
                        -- Replace "[<text>:<height>:<width>]" in the caption with the escape sequence for the atlas.
                        caption = caption:gsub( "%[(.-):(%d+):(%d+)%]", "|A:%1:%2:%3|a" )
                        action = action .. ',caption=' .. caption .. ',description=' .. description
                    else
                        -- Change commas to semicolons.
                        action = action .. ',description=' .. comment:gsub( ",", ";" )
                    end
                    comment = nil
                end

                lists[ list ] = lists[ list ] .. "actions+=/" .. action .. "\n"
            end
        end

        if lists.precombat:len() == 0 then lists.precombat = "actions+=/heart_essence,enabled=0" end
        if lists.default  :len() == 0 then lists.default   = "actions+=/heart_essence,enabled=0" end

        local count = 0
        local output = {}

        for name, list in pairs( lists ) do
            local import, warnings = self:ParseActionList( list )

            if warnings then
                AddWarning( "The import for '" .. name .. "' required some automated changes." )

                for i, warning in ipairs( warnings ) do
                    AddWarning( warning )
                end

                AddWarning( "" )
            end

            if import then
                output[ name ] = import

                for i, entry in ipairs( import ) do
                    if entry.enabled == nil then entry.enabled = not ( entry.action == 'heroism' or entry.action == 'bloodlust' )
                    elseif entry.enabled == "0" then entry.enabled = false end
                end

                count = count + 1
            end
        end

        local use_items_found = false
        local trinket1_found = false
        local trinket2_found = false

        for _, list in pairs( output ) do
            for i, entry in ipairs( list ) do
                if entry.action == "use_items" then use_items_found = true
                elseif entry.action == "trinket1" then trinket1_found = true
                elseif entry.action == "trinket2" then trinket2_found = true end
            end
        end

        if not use_items_found and not ( trinket1_found and trinket2_found ) then
            AddWarning( "This profile is missing support for generic trinkets.  It is recommended that every priority includes either:\n" ..
                " - [Use Items], which includes any trinkets not explicitly included in the priority; or\n" ..
                " - [Trinket 1] and [Trinket 2], which will recommend the trinket for the numbered slot." )
        end

        if not output.default then output.default = {} end
        if not output.precombat then output.precombat = {} end

        if count == 0 then
            AddWarning( "No action lists were imported from this profile." )
        else
            AddWarning( "Imported " .. count .. " action lists." )
        end

        return output, impControl.warnings
    end
end

local snapshots = {
    snaps = {},
    empty = {},

    selected = 0
}

local config = {
    qsDisplay = 99999,

    qsShowTypeGroup = false,
    qsDisplayType = 99999,
    qsTargetsAOE = 3,

    displays = {}, -- auto-populated and recycled.
    displayTypes = {
        [1] = "Primary",
        [2] = "AOE",
        [3] = "Automatic",
        [99999] = " "
    },

    expanded = {
        cooldowns = true
    },
    adding = {},
}

local specs = {}
local activeSpec

local function GetCurrentSpec()
    activeSpec = activeSpec or GetSpecializationInfo( GetSpecialization() )
    return activeSpec
end

local function SetCurrentSpec( _, val )
    activeSpec = val
end

local function GetCurrentSpecList()
    return specs
end

do
    local packs = {}

    local specNameByID = {}
    local specIDByName = {}

    local shareDB = {
        actionPack = "",
        packName = "",
        export = "",

        import = "",
        imported = {},
        importStage = 0
    }

    function AdvancedInterfaceOptions:GetPackShareOption( info )
        local n = #info
        local option = info[ n ]

        return shareDB[ option ]
    end

    function AdvancedInterfaceOptions:SetPackShareOption( info, val, v2, v3, v4 )
        local n = #info
        local option = info[ n ]

        if type(val) == 'string' then val = val:trim() end

        shareDB[ option ] = val

        if option == "actionPack" and rawget( self.DB.profile.packs, shareDB.actionPack ) then
            shareDB.export = SerializeActionPack( shareDB.actionPack )
        else
            shareDB.export = ""
        end
    end

    function AdvancedInterfaceOptions:SetSpecOption( info, val )
        local n = #info
        local spec, option = info[1], info[n]

        spec = specIDByName[ spec ]
        if not spec then return end

        if type( val ) == 'string' then val = val:trim() end

        self.DB.profile.specs[ spec ] = self.DB.profile.specs[ spec ] or {}
        self.DB.profile.specs[ spec ][ option ] = val

        if option == "package" then self:UpdateUseItems()
self:ForceUpdate( "SPEC_PACKAGE_CHANGED" )
        elseif option == "enabled" then ns.StartConfiguration() end

        if WeakAuras and WeakAuras.ScanEvents then
            WeakAuras.ScanEvents( "AdvancedInterfaceOptions_SPEC_OPTION_CHANGED", option, val )
        end

        AdvancedInterfaceOptions:UpdateDamageDetectionForCLEU()
    end

    function AdvancedInterfaceOptions:GetSpecOption( info )
        local n = #info
        local spec, option = info[1], info[n]

        if type( spec ) == 'string' then spec = specIDByName[ spec ] end
        if not spec then return end

        self.DB.profile.specs[ spec ] = self.DB.profile.specs[ spec ] or {}

        if option == "potion" then
            local p = self.DB.profile.specs[ spec ].potion

            if not class.potionList[ p ] then
                return class.potions[ p ] and class.potions[ p ].key or p
            end
        end

        return self.DB.profile.specs[ spec ][ option ]
    end

    function AdvancedInterfaceOptions:SetSpecPref( info, val )
    end

    function AdvancedInterfaceOptions:GetSpecPref( info )
    end

    function AdvancedInterfaceOptions:SetAbilityOption( info, val )
        local n = #info
        local ability, option = info[2], info[n]

        local spec = GetCurrentSpec()

        self.DB.profile.specs[ spec ].abilities[ ability ][ option ] = val
        if option == "toggle" then AdvancedInterfaceOptions:EmbedAbilityOption( nil, ability ) end
    end

    function AdvancedInterfaceOptions:GetAbilityOption( info )
        local n = #info
        local ability, option = info[2], info[n]

        local spec = GetCurrentSpec()

        return self.DB.profile.specs[ spec ].abilities[ ability ][ option ]
    end

    function AdvancedInterfaceOptions:SetItemOption( info, val )
        local n = #info
        local item, option = info[2], info[n]

        local spec = GetCurrentSpec()

        self.DB.profile.specs[ spec ].items[ item ][ option ] = val
        if option == "toggle" then AdvancedInterfaceOptions:EmbedItemOption( nil, item ) end
    end

    function AdvancedInterfaceOptions:GetItemOption( info )
        local n = #info
        local item, option = info[2], info[n]

        local spec = GetCurrentSpec()

        return self.DB.profile.specs[ spec ].items[ item ][ option ]
    end

    function AdvancedInterfaceOptions:EmbedAbilityOption( db, key )
        db = db or self.Options
        if not db or not key then return end

        local ability = class.abilities[ key ]
        if not ability then return end

        local toggles = {}

        local k = class.abilityList[ ability.key ]
        local v = ability.key

        if not k or not v then return end

        local useName = class.abilityList[ v ] and class.abilityList[v]:match("|t (.+)$") or ability.name

        if not useName then
            AdvancedInterfaceOptions:Error("当前技能%s(id:%d)没有可用选项。", ability.key or "不存在此ID",
                ability.id or 0)
            useName = ability.key or ability.id or "???"
        end

        local option = db.args.abilities.plugins.actions[ v ] or {}

        option.type = "group"
        option.name = function () return useName .. ( state:IsDisabled( v, true ) and "|cFFFF0000*|r" or "" ) end
        option.order = 1
        option.set = "SetAbilityOption"
        option.get = "GetAbilityOption"
        option.args = {
            disabled = {
                type = "toggle",
                name = function () return "禁用 " .. ( ability.item and ability.link or k ) end,
                desc = function()
                    return "如果勾选，此技能将|cffff0000永远|r不会被插件推荐。" ..
                        "如果其他技能依赖此技能 |W" ..
                        (ability.item and ability.link or k) .. "那么可能会出现问题|w."
                end,
                width = 2,
                order = 1,
            },

            boss = {
                type = "toggle",
                name = "仅用于BOSS战",
                desc = "如果勾选，插件将不会推荐此技能" .. k .. "，除非你处于BOSS战中。如果不勾选，" .. k .. "技能会在所有战斗中被推荐。",
                width = 2,
                order = 1.1,
            },

            keybind = {
                type = "input",
                name = "覆盖键位绑定文本",
                desc = function()
                    local output =
                        "如果设置此项，当推荐此技能时，插件将显示此文本，而不是自动检测到的键位。 "
                        .. "如果键位检测错误或在多个动作栏上存在键位，这将很有帮助。"

                    local detected = AdvancedInterfaceOptions.KeybindInfo and AdvancedInterfaceOptions.KeybindInfo[ ability.key ]
                    if detected then
                        output = output .. "\n"

                        for page, text in pairs( detected.upper ) do
                            output = format( "%s\n检测到键位|cFFFFD100%s|r 位于动作条 |cFFFFD100%d|r上。", output, text, page )
                        end
                    else
                        output = output .. "\n|cFFFFD100未检测到该技能的键位。|r"
                    end

                    return output
                end,
                validate = function( info, val )
                    val = val:trim()
                    if val:len() > 20 then return "键位文本的长度不应超过20个字符。" end
                    return true
                end,
                width = 2,
                order = 3,
            },

            toggle = {
                type = "select",
                name = "技能归类",
                desc = "将该机能归类到哪个技能组？\n\n" ..
                    "如果未选中，插件将不会推荐此技能。",
                width = 1.5,
                order = 2,
                values = function ()
                    table.wipe( toggles )


                    local t = class.abilities[v].toggle or "无"
                    if t == "精华" then t = "盟约" end

                    toggles.none = "无"
                    toggles.default = "默认|cffffd100(" .. t .. ")|r"
                    toggles.cooldowns = "主要爆发"
                    toggles.essences = "次要爆发"
                    toggles.defensives = "防御"
                    toggles.interrupts = "打断"
                    toggles.potions = "药剂"
                    toggles.custom1 = "自定义1"
                    toggles.custom2 = "自定义2"

                    return toggles
                end,
            },

            targetMin = {
                type = "range",
                name = "最小目标数",
                desc = "如果设置大于0，则只有监测到敌人数至少有" .. k .. "人的情况下，才会推荐此项。所有其他条件也必须满足。\n设置为0将忽略此项。",
                width = 1.5,
                min = 0,
                softMax = 15,
                max = 100,
                step = 1,
                order = 3.1,
            },

            targetMax = {
                type = "range",
                name = "最大目标数",
                desc = "如果设置为大于零的值，插件将仅在检测到这么多敌人（或更少）时推荐 " ..
                k ..
                "。所有其他动作列表条件也必须满足。\n设置为零以忽略此限制。",
                width = 1.5,
                min = 0,
                max = 15,
                step = 1,
                order = 3.2,
            },

            dotCap = {
                type = "range",
                name = "最大应用数",
                desc = "若设为零以上，当此技能已作用于该数量（或更多）的目标时，将不再被推荐使用。若光环效果在当前目标上可刷新，则此限制将被忽略。\n\n设为零可忽略此限制。",
                width = 1.5,
                min = 0,
                max = 100,
                step = 1,
                order = 3.25,
            },

            clash = {
                type = "range",
                name = "强制冷却",
                desc = "如果设置为大于零的值，插件将假装" .. k .. "比实际冷却时间提前这么多。 " ..
                    "这在技能优先级很高时很有用，你希望插件更倾向于使用它，而不是更早可用的技能。",
                width = 3,
                min = -1.5,
                max = 1.5,
                step = 0.05,
                order = 4,
            },

             --LJ
            distance_check = {
                type = "range",
                name = "释放距离",
                desc = "该技能需要目标在设定的范围内才可释放(0 是不限制)",
                width = 3,
                min = 0,
                max = 100,
                step = 1,
                order = 5,
            },

            tar_hp_check = {
                type = "range",
                name = "目标血量",
                desc = "当目高于设定的血量百分比时才会使用该技能(0 是不限制)",
                width = 3,
                min = 0,
                max = 100,
                step = 1,
                order = 6,
            },
        }

        db.args.abilities.plugins.actions[ v ] = option
    end

    local testFrame = CreateFrame( "Frame" )
    testFrame.Texture = testFrame:CreateTexture()

    function AdvancedInterfaceOptions:EmbedAbilityOptions( db )
        db = db or self.Options
        if not db then return end

        local abilities = {}
        local toggles = {}

        for k, v in pairs( class.abilityList ) do
            local a = class.abilities[ k ]
            if a and a.id and ( a.id > 0 or a.id < -100 ) and a.id ~= 61304 and not a.item then
                abilities[ v ] = k
            end
        end

        for k, v in orderedPairs( abilities ) do
            local ability = class.abilities[ v ]
            local useName = class.abilityList[ v ] and class.abilityList[v]:match("|t (.+)$") or ability.name

            if not useName then
                AdvancedInterfaceOptions:Error( "未发现ID 为 %s (id:%d) 的一些设置", ability.key or "ID 不存在", ability.id or 0 )
                useName = ability.key or ability.id or "???"
            end

            local option = {
                type = "group",
                --LJ
                name = function()
                    local name = useName .. (state:IsDisabled(v, true) and "|cFFFF0000*|r" or "")
                    if ns.seachID ~= "" and string.find(useName, ns.seachID) then
                        return "|cFF00FF00" .. name .. "|r"
                    end
                    return name
                end,
                order = 1,
                set = "SetAbilityOption",
                get = "GetAbilityOption",
                args = {
                    disabled = {
                        type = "toggle",
                        name = function () return "禁用 " .. ( ability.item and ability.link or k ) end,
                        desc = function ()
                            return "只要勾选了，不管任何情况 将不再使用 " .. (ability.item and ability.link or k) .. "." 
                        end,
                        width = 1.5,
                        order = 1,
                    },

                    boss = {
                        type = "toggle",
                        name = "仅对Boss生效",
                        desc = "仅对Boss生效.",
                        width = 1.5,
                        order = 1.1,
                    },

                    lineBreak1 = {
                        type = "description",
                        name = " ",
                        width = "full",
                        order = 1.9
                    },

                    toggle = {
                        type = "select",
                        name = "技能归类",
                        desc = "将该机能归类到哪个技能组？\n\n" ..
                            "如果未选中，插件将不会推荐此技能。",
                        width = 1.5,
                        order = 1.2,
                        values = function ()
                            table.wipe( toggles )

                            local t = class.abilities[ v ].toggle or "none"
                            if t == "essences" then t = "covenants" end

                            toggles.none = "无"
                            toggles.default = "默认|cffffd100(" .. t .. ")|r"
                            toggles.cooldowns = "爆发技能"
                            toggles.essences = "次级爆发"
                            toggles.defensives = "防御技能"
                            toggles.interrupts = "打断技能"
                            toggles.potions = "爆发药剂"
                            toggles.custom1 = "自定义1"
                            toggles.custom2 = "自定义2"

                            return toggles
                        end,
                    },

                    lineBreak5 = {
                        type = "description",
                        name = "",
                        width = "full",
                        order = 1.29,
                    },

                    lineBreak4 = {
                        type = "description",
                        name = "",
                        width = "full",
                        order = 1.9,
                    },

                    targetMin = {
                        type = "range",
                        name = "最小目标数",
                        desc = "如果设置大于0，则只有监测到敌人数至少有" ..
                            k .. "人的情况下，才会推荐此项。所有其他条件也必须满足。\n设置为0将忽略此项。",
                        width = 1.5,
                        min = 0,
                        max = 15,
                        step = 1,
                        order = 2,
                    },

                    targetMax = {
                        type = "range",
                        name = "最大目标数",
                        desc = "如果设置大于0，则只有监测到敌人数小于" ..
                            k .. "人的情况下，才会推荐此项。所有其他条件也必须满足。.\n设置为0将忽略此项。",
                        width = 1.5,
                        min = 0,
                        max = 15,
                        step = 1,
                        order = 2.1,
                    },

                    lineBreak2 = {
                        type = "description",
                        name = "",
                        width = "full",
                        order = 2.11,
                    },

                    dotCap = {
                        type = "range",
                        name = "光环检测",
                        desc = "若设为零以上，当此技能已作用于该数量（或更多）的目标时，将不再被推荐使用。若光环效果在当前目标上可刷新，则此限制将被忽略。\n\n设为零可忽略此限制。",
                        width = 1.5,
                        min = 0,
                        max = 100,
                        step = 1,
                        order = 2.19,
                    },

                    clash = {
                        type = "range",
                        name = "强制",
                        desc = "如果设置大于0，插件将假设" .. k .. "拥有更快的冷却时间。" ..
                            "当某个技能的优先级非常高，并且你希望插件更多地推荐它，而不是其他更快的可能技能时，此项会很有效。",
                        width = 3,
                        min = -1.5,
                        max = 1.5,
                        step = 0.05,
                        order = 2.2,
                    },
                    --LJ
                    distance_check = {
                        type = "range",
                        name = "释放距离",
                        desc = "该技能需要目标在设定的范围内才可释放(0 是不限制)",
                        width = 3,
                        min = 0,
                        max = 100,
                        step = 1,
                        order = 2.3,
                    },
                                        --LJ
                    tar_hp_check = {
                        type = "range",
                        name = "目标血量",
                        desc = "当目高于设定的血量百分比时才会使用该技能(0 是不限制)",
                        width = 3,
                        min = 0,
                        max = 100,
                        step = 1,
                        order = 2.4,
                    },
                    lineBreak3 = {
                        type = "description",
                        name = "",
                        width = "full",
                        order = 2.5,
                    },

                }
            }

            db.args.abilities.plugins.actions[ v ] = option
        end
    end

    function AdvancedInterfaceOptions:EmbedItemOption( db, item )
        db = db or self.Options
        if not db then return end

        local ability = class.abilities[ item ]
        local toggles = {}

        local k = class.itemList[ ability.item ] or ability.name
        local v = ability.itemKey or ability.key

        if not item or not ability.item or not k then
            AdvancedInterfaceOptions:Error( "Unable to find %s / %s / %s in the itemlist.", item or "unknown", ability.item or "unknown", k or "unknown" )
            return
        end

        local option = db.args.items.plugins.equipment[ v ] or {}

        option.type = "group"
        option.name = function () return ability.name .. ( state:IsDisabled( v, true ) and "|cFFFF0000*|r" or "" ) end
        option.order = 1
        option.set = "SetItemOption"
        option.get = "GetItemOption"
        option.args = {
            disabled = {
                type = "toggle",
                name = function () return "禁用" .. ( ability.item and ability.link or k ) end,
                desc = function () return "如果勾选，此技能将|cffff0000永远|r不会被插件推荐。" ..
                    "如果其他技能依赖此技能" .. ( ability.item and ability.link or k ) .. "，那么可能会出现问题。" end,
                width = 1.5,
                order = 1,
            },

            boss = {
                type = "toggle",
                name = "仅用于BOSS战",
                desc = "如果勾选，插件将不会推荐该物品" .. k .. "，除非你处于BOSS战。如果不选中，" .. k .. "物品会在所有战斗中被推荐。",
                width = 1.5,
                order = 1.1,
            },

            keybind = {
                type = "input",
                name = "技能按键文字",
                desc = "如果设置此项，插件将在推荐此技能时显示此处的文字，替代自动检测到的技能绑定按键的名称。" ..
                    "如果插件检测你的按键绑定出现问题，此设置能够有所帮助。",
                validate = function( info, val )
                    val = val:trim()
                    if val:len() > 6 then return "技能按键文字长度不应超过6个字符。" end
                    return true
                end,
                width = 1.5,
                order = 2,
            },

            toggle = {
                type = "select",
                name = "开关状态切换",
                desc = "设置此项后，插件在技能列表中使用必须的开关切换。" ..
                    "当开关被关闭时，技能将被视为不可用，插件将假设它们处于冷却状态（除非另有设置）。",
                width = 1.5,
                order = 3,
                values = function ()
                    table.wipe( toggles )

                    toggles.none = "无"
                    toggles.default = "默认" .. ( class.abilities[ v ].toggle and ( " |cffffd100(" .. class.abilities[ v ].toggle .. ")|r" ) or " |cffffd100（无）|r" )
                    toggles.cooldowns = "主要爆发"
                    toggles.essences = "次要爆发"
                    toggles.defensives = "防御"
                    toggles.interrupts = "打断"
                    toggles.potions = "药剂"
                    toggles.custom1 = "自定义1"
                    toggles.custom2 = "自定义2"

                    return toggles
                end,
            },

            --[[ clash = {
                type = "range",
                name = "Clash",
                desc = "If set above zero, the addon will pretend " .. k .. " has come off cooldown this much sooner than it actually has.  " ..
                    "当某个技能的优先级非常高，并且你希望插件更多地推荐它，而不是其他更快的可能技能时，此项会很有效。",
                width = "full",
                min = -1.5,
                max = 1.5,
                step = 0.05,
                order = 4,
            }, ]]

            targetMin = {
                type = "range",
                name = "最小目标数",
                desc = "如果设置大于0，则只有检测到敌人数至少有" .. k .. "人的情况下，才会推荐此道具。\n设置为0将忽略此项。",
                width = 1.5,
                min = 0,
                max = 15,
                step = 1,
                order = 5,
            },

            targetMax = {
                type = "range",
                name = "最大目标数",
                desc = "如果设置大于0，则只有监测到敌人数小于" .. k .. "人的情况下，才会推荐此道具。\n设置为0将忽略此项。",
                width = 1.5,
                min = 0,
                max = 15,
                step = 1,
                order = 6,
            },
        }

        db.args.items.plugins.equipment[ v ] = option
    end


    function AdvancedInterfaceOptions:EmbedItemOptions( db )
        db = db or self.Options
        if not db then return end

        local abilities = {}
        local toggles = {}

        for k, v in pairs( class.abilities ) do
            if k == "potion" or v.item and not abilities[ v.itemKey or v.key ] then
                local name = class.itemList[ v.item ] or v.name
                if name then abilities[ name ] = v.itemKey or v.key end
            end
        end

        for k, v in orderedPairs( abilities ) do
            local ability = class.abilities[ v ]
            local option = {
                type = "group",
                name = function()
                    local name = ability.name .. (state:IsDisabled(v, true) and "|cFFFF0000*|r" or "")
                    if ns.searchItemName ~= "" and string.find(ability.name, ns.searchItemName) then
                        return "|cFF00FF00" .. name .. "|r"
                    end
                    return name
                end,                order = 1,
                set = "SetItemOption",
                get = "GetItemOption",
                args = {
                    multiItem = {
                        type = "description",
                        name = function ()
                            return "这些设置将应用于|cFF00FF00所有|r类似于" .. ability.name .. "的PVP饰品。"
                        end,
                        fontSize = "medium",
                        width = "full",
                        order = 1,
                        hidden = function () return ability.key ~= "gladiators_badge" and ability.key ~= "gladiators_emblem" and ability.key ~= "gladiators_medallion" end,
                    },

                    disabled = {
                        type = "toggle",
                        name = function () return "禁用" .. ( ability.item and ability.link or k ) end,
                        desc = function () return "如果勾选，此技能将|cffff0000永远|r不会被插件推荐。" ..
                            "如果其他技能依赖此技能" .. ( ability.item and ability.link or k ) .. "，那么可能会出现问题。" end,
                        width = 1.5,
                        order = 1.05,
                    },

                    boss = {
                        type = "toggle",
                        name = "仅用于BOSS战",
                        desc = "如果勾选，插件将不会推荐该物品" .. k .. "，除非你处于BOSS战。如果不选中，" .. k .. "物品会在所有战斗中被推荐。",
                        width = 1.5,
                        order = 1.1,
                    },

                    keybind = {
                        type = "input",
                        name = "技能按键文字",
                        desc = "如果设置此项，插件将在推荐此技能时显示此处的文字，替代自动检测到的技能绑定按键的名称。" ..
                            "如果插件检测你的按键绑定出现问题，此设置能够有所帮助。",
                        validate = function( info, val )
                            val = val:trim()
                            if val:len() > 6 then return "技能按键文字长度不应超过6个字符。" end
                            return true
                        end,
                        width = 1.5,
                        order = 2,
                    },

                    toggle = {
                        type = "select",
                        name = "开关状态切换",
                        desc = "设置此项后，插件在技能列表中使用必须的开关切换。" ..
                            "当开关被关闭时，技能将被视为不可用，插件将假装它们处于冷却状态（除非另有设置）。",
                        width = 1.5,
                        order = 3,
                        values = function ()
                            table.wipe( toggles )
                            local t = class.abilities[ v ].toggle or "none"
                            if t == "essences" then t = "covenants" end

                            toggles.none = "无"
                            toggles.default = "默认 |cffffd100(" .. t .. ")|r"
                            toggles.cooldowns = "爆发"
                            toggles.essences = "次级爆发"
                            toggles.defensives = "防御技能"
                            toggles.interrupts = "打断技能"
                            toggles.potions = "爆发药剂"
                            toggles.custom1 = "自定义1"
                            toggles.custom2 = "自定义2"

                            return toggles
                        end,
                    },

                    --[[ clash = {
                        type = "range",
                        name = "冲突",
                        desc = "If set above zero, the addon will pretend " .. k .. " has come off cooldown this much sooner than it actually has.  " ..
                            "当某个技能的优先级非常高，并且你希望插件更多地推荐它，而不是其他更快的可能技能时，此项会很有效。",
                        width = "full",
                        min = -1.5,
                        max = 1.5,
                        step = 0.05,
                        order = 4,
                    }, ]]

                    targetMin = {
                        type = "range",
                        name = "最小目标数",
                        desc = "如果设置大于0，则只有监测到敌人数至少有" .. ( ability.item and ability.link or k ) .. "人的情况下，才会推荐此道具。\n设置为0将忽略此项。",
                        width = 1.5,
                        min = 0,
                        max = 15,
                        step = 1,
                        order = 5,
                    },

                    targetMax = {
                        type = "range",
                        name = "最大目标数",
                        desc = "如果设置大于0，则只有监测到敌人数小于" .. ( ability.item and ability.link or k ) .. "人的情况下，才会推荐此道具。\n设置为0将忽略此项。",
                        width = 1.5,
                        min = 0,
                        max = 15,
                        step = 1,
                        order = 6,
                    },
                }
            }

            db.args.items.plugins.equipment[ v ] = option
        end

        self.NewItemInfo = false
    end


    local ToggleCount = {}
    local tAbilities = {}
    local tItems = {}

    -- Options table constructors.
    function AdvancedInterfaceOptions:EmbedSpecOptions( db )
        db = db or self.Options
        if not db then return end

        local i = 1

        while( i < 5 ) do
            local id, name, description, texture, role = GetSpecializationInfo( i )
            if not id then break end
            if description then description = description:match( "^(.-)\n" ) end

            local spec = class.specs[ id ]

            if spec and name then
                local sName = lower( name )
                specNameByID[ id ] = sName
                specIDByName[ sName ] = id

                specs[ id ] = AdvancedInterfaceOptions:ZoomedTextureWithText( texture, name )

                local options = {
                    type = "group",
                    -- name = specs[ id ],
                    name = name,
                    icon = texture,
                    iconCoords = { 0.15, 0.85, 0.15, 0.85 },
                    desc = description,
                    order = 50 + i,
                    childGroups = "tab",
                    get = "GetSpecOption",
                    set = "SetSpecOption",

                    args = {
                        core = {
                            type = "group",
                            name = "天赋相关设置",
                            desc = "这里是针对当前天赋"  .. specs[id] .. "." .. "的一些设置, 他不会影响其他天赋的设定.",
                            order = 1,
                            args = {
                                enabled = {
                                    type = "toggle",
                                    name = specs[ id ] .. " 启用",
                                    desc = "勾选启用, 激活当前天赋自动",
                                    order = 0,
                                    width = "full",
                                },

                                package = {
                                    type = "select",
                                    name = "优先级",
                                    desc = "插件将会按照当前选择的优先级进行循环推荐.",
                                    order = 1,
                                    width = 1.5,
                                    values = function( info, val )
                                        wipe( packs )

                                        for key, pkg in pairs( self.DB.profile.packs ) do
                                            local pname = pkg.builtIn and "|cFF00B4FF" .. key .. "|r" or key
                                            if pkg.spec == id then
                                                packs[ key ] = AdvancedInterfaceOptions:ZoomedTextureWithText( texture, pname )
                                            end
                                        end

                                        packs[ '(空)' ] = '(空)'

                                        return packs
                                    end,
                                },

                                openPackage = {
                                    type = 'execute',
                                    name = "",
                                    desc = "Open and view this priority pack and its action lists.",
                                    image = GetAtlasFile( "communities-icon-searchmagnifyingglass" ),
                                    imageCoords = GetAtlasCoords( "communities-icon-searchmagnifyingglass" ),
                                    imageHeight = 24,
                                    imageWidth = 24,
                                    disabled = function( info, val )
                                        local pack = self.DB.profile.specs[ id ].package
                                        return rawget( self.DB.profile.packs, pack ) == nil
                                    end,
                                    func = function ()
                                        ACD:SelectGroup( "AdvancedInterfaceOptions", "packs", self.DB.profile.specs[ id ].package )
                                    end,
                                    order = 1.1,
                                    width = 0.15,
                                },

                                potion = {
                                    type = "select",
                                    name = "爆发药剂",
                                    desc = "除非在优先级中另有指定，否则将推荐选定的爆发药水",
                                    order = 3,
                                    width = 1.5,
                                    values = class.potionList,
                                    get = function()
                                        local p = self.DB.profile.specs[ id ].potion or class.specs[ id ].options.potion or "默认"
                                        if not class.potionList[ p ] then p = "默认" end
                                        return p
                                    end,
                                },

                                blankLine1 = {
                                    type = 'description',
                                    name = '',
                                    order = 2,
                                    width = 'full'
                                },
                            },
                            plugins = {
                                settings = {}
                            },
                        },

                        targets = {
                            type = "group",
                            name = "目标判定设置",
                            desc = "设置目标数量统计的方式",
                            order = 3,
                            args = {
                                targetsHeader = {
                                    type = "description",
                                    name =
                                        "这些设置控制在生成技能推荐时如何计算目标数量。\n\n默认情况下，除非只检测到一个目标， 目标数量会显示在技能队列的右下角。\n\n"
                                        .. "您在游戏中的真实目标始终会被计算在内。\n\n|cFFFF0000警告：|r 目前不支持来自动作目标系统的“软”目标(动作瞄准模式)。\n\n",
                                    width = "full",
                                    fontSize = "medium",
                                    order = 0.01
                                },
                                yourTarget = {
                                    type = "toggle",
                                    name = "当前选中的目标",
                                    desc =
                                        "当前选中的目标总会计算在内\n\n"
                                        .. "不可以禁用哦",
                                    width = "full",
                                    get = function() return true end,
                                    set = function() end,
                                    order = 0.02,
                                },

                                -- Damage Detection Quasi-Group
                                damage = {
                                    type = "toggle",
                                    name = "统计受伤害的目标",
                                    desc =
                                        "如果勾选此项，你伤害过的目标将在几秒内被视为有效敌人，从而与其他未被攻击的敌人区分开来。\n\n"
                                        .. CreateAtlasMarkup("services-checkmark") ..
                                        " 当姓名板被禁用时自动启用\n\n"
                                        ..
                                        CreateAtlasMarkup("services-checkmark") ..
                                        " 推荐用于无法使用|cffffd100宠物目标检测|r的|cffffd100远程|r职业。",
                                    width = "full",
                                    order = 0.3,
                                },

                                dmgGroup = {
                                    type = "group",
                                    inline = true,
                                    name = "伤害检测",
                                    order = 0.4,
                                    hidden = function() return self.DB.profile.specs[id].damage == false end,
                                    args = {
                                        damagePets = {
                                            type = "toggle",
                                            name = "统计 受到你的宝宝和宠物伤害的敌人",
                                            desc =
                                                "如果勾选此项，插件将计算您的宠物或仆从在过去几秒内击中（或击中您）的敌人。\n\n如果您的宠物/仆从分散在战场上，这可能会导致目标数量计算出现误导。",
                                            order = 2,
                                            width = "full",
                                        },

                                        damageExpiration = {
                                            type = "range",
                                            name = "超时",
                                            desc =
                                                "敌人将在此时间段内被计算，直到他们被忽略/未受到伤害（或死亡）\n\n"
                                                ..
                                                "理想情况下，这个时间段应足够长，以便在此期间继续对敌人造成AOE/范围伤害，但也不应过长，以免将已经脱离战斗或不再构成威胁的敌人错误地计入目标数量。 "
                                                .. "因为它可能已经超出了范围",
                                            softMin = 3,
                                            min = 1,
                                            max = 10,
                                            step = 0.1,
                                            order = 1,
                                            width = 1.5,
                                        },

                                        damageDots = {
                                            type = "toggle",
                                            name = "统计受到 DOTs / Debuffs 的目标",
                                            desc =
                                                "当勾选此项时，带有你的减益效果或持续伤害效果（DoT）的敌人将被计为目标，无论他们在战场上的位置如何。\n\n"
                                                ..
                                                "这对于近战专精可能并不理想，因为敌人在你施加了DoT/流血效果后可能会离开。如果启用了|cFFFFD100计数姓名板|r功能，超出范围的敌人将被过滤掉。\n\n"
                                                ..
                                                "推荐用于远程专精，这些专精会对多个敌人施加DoT，并且不依赖敌人堆叠来进行AOE伤害。",
                                            width = "full",
                                            order = 3,
                                        },

                                        damageOnScreen = {
                                            type = "toggle",
                                            name = "过滤屏幕外（无姓名板）敌人",
                                            desc = function()
                                                return
                                                    "如果勾选此项，基于伤害的目标系统将仅计算屏幕内的敌人。如果未勾选，屏幕外的目标也可能被计入目标数量。\n\n"
                                                    ..
                                                    (GetCVar("nameplateShowEnemies") == "0" and "|cFFFF0000需要启用敌方姓名板|r" or "|cFF00FF00需要启用敌方姓名板|r")
                                            end,
                                            width = "full",
                                            order = 4,
                                        },
                                    },
                                },
                                nameplates = {
                                    type = "toggle",
                                    name = "按姓名板数量统计",
                                    desc =
                                        "如果勾选此项，位于你角色指定半径范围内的敌方姓名板将被计为敌方目标。\n\n"
                                        .. AtlasToString("common-icon-checkmark") ..
                                        " 推荐用于使用10码或更短范围的近战专精\n\n"
                                        .. AtlasToString("common-icon-redx") ..
                                        " 不推荐用于远程专精。",
                                    width = "full",
                                    order = 0.1,
                                },

                                petbased = {
                                    type = "toggle",
                                    name = "统计宝宝/宠物附近的目标",
                                    desc = function()
                                        local msg =
                                        "如果勾选并正确配置，当你的目标也在你宠物的范围内时，插件会将靠近你宠物的目标计为有效目标。"
                                        
                                        if AdvancedInterfaceOptions:HasPetBasedTargetSpell() then
                                            local spell = AdvancedInterfaceOptions:GetPetBasedTargetSpell()
                                            local link = AdvancedInterfaceOptions:GetSpellLinkWithTexture(spell)
                                        
                                            msg = msg ..
                                                "\n\n" ..
                                                link ..
                                                "|w|r 已在你的动作条上，并将用于你所有" ..
                                                UnitClass("player") .. "宠物的技能。"
                                        else
                                            msg = msg ..
                                                "\n\n|cFFFF0000需要在你的动作条上放置一个宠物技能。|r"
                                        end
                                        
                                        if GetCVar("nameplateShowEnemies") == "1" then
                                            msg = msg ..
                                                "\n\n敌方姓名板已|cFF00FF00启用|r，将用于检测靠近你宠物的目标。"
                                        else
                                            msg = msg .. "\n\n|cFFFF0000需要启用敌方姓名板。|r"
                                        end
                                        
                                        return msg
                                        end,
                                    width = "full",
                                    hidden = function()
                                        return AdvancedInterfaceOptions:GetPetBasedTargetSpells() == nil
                                    end,
                                    order = 0.2
                                },

                                petbasedGuidance = {
                                    type = "description",
                                    name = function()
                                        local out

                                        if not self:HasPetBasedTargetSpell() then
                                            out =
                                            "要使基于宠物的检测功能生效，你必须从|cFF00FF00宠物技能书|r中选取一个技能，并将其放置在|cFF00FF00你的|r动作条上。\n\n"
                                            local spells = AdvancedInterfaceOptions:GetPetBasedTargetSpells()

                                            if not spells then return " " end

                                            out = out ..
                                            "对于%s，推荐使用%s，因为它的范围更广。该技能将适用于你所有的宠物。"

                                            if spells.count > 1 then
                                                out = out .. "\n替代方案: "
                                            end

                                            local n = 1

                                            local link = AdvancedInterfaceOptions:GetSpellLinkWithTexture(spells.best)
                                            out = format(out, UnitClass("player"), link)
                                            for spell in pairs(spells) do
                                                if type(spell) == "number" and spell ~= spells.best then
                                                    n = n + 1

                                                    link = AdvancedInterfaceOptions:GetSpellLinkWithTexture(spell)

                                                    if n == 2 and spells.count == 2 then
                                                        out = out .. link .. "."
                                                    elseif n ~= spells.count then
                                                        out = out .. link .. ", "
                                                    else
                                                        out = out .. "和 " .. link .. "."
                                                    end
                                                end
                                            end
                                        end

                                        if GetCVar("nameplateShowEnemies") ~= "1" then
                                            if not out then
                                                out = "|cFFFF0000警告！|r 基于宠物的目标检测需要启用 |cFFFFD100敌方姓名板|r。"
                                            else
                                                out = out .. "\n\n|cFFFF0000警告！|r 基于宠物的目标检测需要启用 |cFFFFD100敌方姓名板|r。"
                                            end
                                        end

                                        return out
                                    end,
                                    fontSize = "medium",
                                    width = "full",
                                    disabled = function(info, val)
                                        if AdvancedInterfaceOptions:GetPetBasedTargetSpells() == nil then return true end
                                        if self.DB.profile.specs[id].petbased == false then return true end
                                        if self:HasPetBasedTargetSpell() and GetCVar("nameplateShowEnemies") == "1" then return true end

                                        return false
                                    end,
                                    order = 0.21,
                                    hidden = function()
                                        return not self.DB.profile.specs[id].petbased
                                    end
                                },

                                npGroup = {
                                    type = "group",
                                    inline = true,
                                    name = "姓名板识别",
                                    order = 0.11,
                                    hidden = function()
                                        return not self.DB.profile.specs[id].nameplates
                                    end,
                                    args = {
                                        nameplateRequirements = {
                                            type = "description",
                                            name =
                                            "此功能需要同时启用 |cFFFFD100显示敌方姓名板|r 和 |cFFFFD100显示所有姓名板|r。",
                                            width = "full",
                                            hidden = function()
                                                return GetCVar("nameplateShowEnemies") == "1" and
                                                GetCVar("nameplateShowAll") == "1"
                                            end,
                                            order = 1,
                                        },

                                        nameplateShowEnemies = {
                                            type = "toggle",
                                            name = "显示敌方姓名板",
                                            desc =
                                            "如果勾选，将显示敌方姓名板，并可用于统计敌方目标数量。",
                                            width = 1.4,
                                            get = function()
                                                return GetCVar("nameplateShowEnemies") == "1"
                                            end,
                                            set = function(info, val)
                                                if InCombatLockdown() then return end
                                                SetCVar("nameplateShowEnemies", val and "1" or "0")
                                            end,
                                            hidden = function()
                                                return GetCVar("nameplateShowEnemies") == "1" and
                                                GetCVar("nameplateShowAll") == "1"
                                            end,
                                            order = 1.2,
                                        },

                                        nameplateShowAll = {
                                            type = "toggle",
                                            name = "显示所有姓名板",
                                            desc =
                                            "如果勾选，将显示所有敌方姓名板（而不仅仅是你的目标），并可用于统计敌方目标数量。",
                                            width = 1.4,
                                            get = function()
                                                return GetCVar("nameplateShowAll") == "1"
                                            end,
                                            set = function(info, val)
                                                if InCombatLockdown() then return end
                                                SetCVar("nameplateShowAll", val and "1" or "0")
                                            end,
                                            hidden = function()
                                                return GetCVar("nameplateShowEnemies") == "1" and
                                                GetCVar("nameplateShowAll") == "1"
                                            end,
                                            order = 1.3,
                                        },

                                        --[[ rangeFilter = {
                                            type = "toggle",
                                            name = function()
                                                if spec.filterName then return format( "Use Automatic Filter:  %s", spec.filterName ) end
                                                return "Use Automatic Filter"
                                            end,
                                            desc = function()
                                                return format( "When this option is available, a recommended filter is available that will limit the radius of nameplate detection to a reasonable "
                                                .. "range for your specialization.  This is strongly recommended for most players.\n\nIf this filter is not enabled, |cffffd100Range Filter by Spell|r "
                                                .. "must be used instead.\n\nFilter: %s", spec.filterName or "" )
                                            end,
                                            hidden = function() return not spec.filterName end,
                                            order = 1.6,
                                            width = "full"
                                        }, ]]

                                        nameplateRange = {
                                            type = "range",
                                            name = "敌方识别半径",
                                            desc =
                                                "如果启用了|cFFFFD100统计姓名板|r，在此范围内的敌人将被计入目标统计中。\n\n"
                                                ..
                                                "此设置仅在|cFFFFD100显示敌方姓名板|r和|cFFFFD100显示所有姓名板|r同时启用时可用。"
                                            ,
                                            width = "full",
                                            order = 0.1,
                                            min = 0,
                                            max = 100,
                                            step = 1,
                                            hidden = function()
                                                return not (GetCVar("nameplateShowEnemies") == "1" and GetCVar("nameplateShowAll") == "1")
                                            end,
                                        },

                                        --[[ rangeChecker = {
                                            type = "select",
                                            name = "Range Filter by Spell",
                                            desc = "When |cFFFFD100Count Nameplates|r is enabled, enemies within range of this ability will be included in target counts.\n\n"
                                            .. "Your character must actually know the selected spell, otherwise |cFFFFD100Count Targets by Damage|r will be force-enabled.",
                                            width = "full",
                                            order = 1.8,
                                            values = function( info )
                                                local ranges = class.specs[ id ].ranges
                                                local list = {}

                                                for _, spell in pairs( ranges ) do
                                                    local output
                                                    local ability = class.abilities[ spell ]

                                                    if ability and ability.id > 0 then
                                                        local minR, maxR = select( 5, GetSpellInfo( ability.id ) )

                                                        if maxR == 0 then
                                                            output = format( "%s (Melee)", AdvancedInterfaceOptions:GetSpellLinkWithTexture( ability.id ) )
                                                        elseif minR > 0 then
                                                            output = format( "%s (%d - %d yds)", AdvancedInterfaceOptions:GetSpellLinkWithTexture( ability.id ), minR, maxR )
                                                        else
                                                            output = format( "%s (%d yds)", AdvancedInterfaceOptions:GetSpellLinkWithTexture( ability.id ), maxR )
                                                        end

                                                        list[ spell ] = output
                                                    end
                                                end
                                                return list
                                            end,
                                            get = function()
                                                -- If it's blank, default to the first option.
                                                if spec.ranges and not self.DB.profile.specs[ id ].rangeChecker then
                                                    self.DB.profile.specs[ id ].rangeChecker = spec.ranges[ 1 ]
                                                else
                                                    local found = false
                                                    for k, v in pairs( spec.ranges ) do
                                                        if v == self.DB.profile.specs[ id ].rangeChecker then
                                                            found = true
                                                            break
                                                        end
                                                    end

                                                    if not found then
                                                        self.DB.profile.specs[ id ].rangeChecker = spec.ranges[ 1 ]
                                                    end
                                                end

                                                return self.DB.profile.specs[ id ].rangeChecker
                                            end,
                                            disabled = function()
                                                return self.DB.profile.specs[ id ].rangeFilter
                                            end,
                                            hidden = function()
                                                return self.DB.profile.specs[ id ].nameplates == false
                                            end,
                                        }, ]]

                                        -- Pet-Based Cluster Detection


                                    }
                                },

                                --[[ nameplateRange = {
                                    type = "range",
                                    name = "Nameplate Detection Range",
                                    desc = "When |cFFFFD100Use Nameplate Detection|r is checked, the addon will count any enemies with visible nameplates within this radius of your character.",
                                    width = "full",
                                    hidden = function()
                                        return self.DB.profile.specs[ id ].nameplates == false
                                    end,
                                    min = 0,
                                    max = 100,
                                    step = 1,
                                    order = 2,
                                }, ]]

                                cycle = {
                                    type = "toggle",
                                    name = "允许目标扫描 |TInterface\\Addons\\AdvancedInterfaceOptions\\Textures\\Cycle:0|t",
                                    desc =
                                        "当启用目标切换时，当你应该对另一个目标使用技能时，可能会显示一个图标（|TInterface\\Addons\\AdvancedInterfaceOptions\\Textures\\Cycle:0|t）。\n\n"
                                        ..
                                        "这对于一些只需要对另一个目标施加减益效果的专精（如暗牧 痛苦术）效果很好，但对于那些需要根据持续时间维持持续伤害/减益效果的专精（如痛苦术士）可能效果较差。\n\n"
                                        ..
                                        "此功能计划在未来的更新中进行改进。",
                                    width = "full",
                                    order = 6
                                },

                                cycleGroup = {
                                    type = "group",
                                    name = "次要目标",
                                    inline = true,
                                    hidden = function() return not self.DB.profile.specs[id].cycle end,
                                    order = 7,
                                    args = {
                                        cycle_min = {
                                            type = "range",
                                            name = "剩余存活时间过滤",
                                            desc =
                                            "当勾选|cffffd100推荐目标切换|r时，此值决定了哪些目标会被计入目标切换的范围。如果设置为5，则当没有其他目标的剩余存活时间达到或超过5秒时，不会推荐目标切换。这可以避免将持续伤害效果施加到即将死亡的目标上，从而无法充分利用这些效果。\n\n设置为0时，将计入所有检测到的目标。",
                                            width = "full",
                                            min = 0,
                                            max = 15,
                                            step = 1,
                                            order = 1
                                        },
                                    }
                                },

                                aoe = {
                                    type = "range",
                                    name = "最小AOE识别数值",
                                    desc =
                                    "当识别到了多少个目标,判定为AOE",
                                    width = "full",
                                    min = 2,
                                    max = 10,
                                    step = 1,
                                    order = 10,
                                },
                            }
                        },


                        performance = {
                            type = "group",
                            name = "性能",
                            order = 10,
                            args = {
                                frameBudget = {
                                    type = "range",
                                    name = "帧数预算",
                                    desc = "此设置决定可用于计算推荐技能的时间。",
                                    min = 0.1,
                                    softMin = 0.2,
                                    softMax = 0.9,
                                    max = 1,
                                    step = 0.05,
                                    isPercent = true,
                                    get = function( _ ) return AdvancedInterfaceOptions.DB.profile.performance.frameBudget or 0.8 end,
                                    set = function( _, v ) AdvancedInterfaceOptions.DB.profile.performance.frameBudget = v end,
                                    order = 1,
                                    width = "full"
                                },
                                frameBudgetInfo = {
                                    type = "description",
                                    name = function()
                                        -- Use smoothed FPS from UI.lua to avoid menu-induced frame drops
                                        local smoothedFPS = AdvancedInterfaceOptions.GetSmoothedFPS and AdvancedInterfaceOptions.GetSmoothedFPS() or nil
                                        local rawFPS = GetFramerate()
                                        local fps = smoothedFPS or 60

                                        -- Safeguard: ensure FPS is reasonable (between 10 and 300)
                                        if fps < 10 then
                                            -- print( "[AdvancedInterfaceOptions Debug] WARNING: Unreasonable FPS value detected:", fps, "- using fallback" )
                                            fps = 60
                                        end

                                        local budget = AdvancedInterfaceOptions.DB.profile.performance.frameBudget or 0.8
                                        local frameBudgetMs = ( 1000 / fps ) * budget

                                        return
                                            "\n此设置决定了生成推荐技能时可以使用多少时间。\n\n" ..
                                            "|cFFFFD100• 数值越高|r，推荐技能能 |cFF00FF00更新得更快|r，但可能会降低你的游戏帧数， " ..
                                            "特别是当其他插件同时工作时。\n" ..
                                            "|cFFFFD100• 数值越低|r，推荐技能更新可能更慢，但能 |cFF00FF00保持你的游戏帧数|r。\n\n" .. 

                                            "调整这个预算来平衡 |cFF00FF00流畅的游戏体验|r 和 |cFF00FF00及时的技能推荐|r。 " ..
                                            "使用在你系统上感觉流畅的最高数值，避免屏幕卡顿或掉帧。\n\n" ..

                                            "|cFF00B4FF默认值（推荐）|r: |cFFFFD10070%|r\n\n" ..

                                            "在 |cFFFFD700" .. format( "%.1f", fps ) .. " 帧/秒|r 下，预算为 |cFFFFD700" .. ( budget * 100 ) .. "%|r " ..
                                            "允许每次更新最多使用 |cFFFFD700" .. format( "%.2f", frameBudgetMs ) .. " 毫秒|r 的帧时间。计算时间更长的推荐技能 " ..
                                            "将至少延迟1帧显示。"
                                    end,
                                    fontSize = "medium",
                                    order = 2,
                                    width = "full",
                                }
                            }
                        }
                    }
                }

                local specCfg = class.specs[ id ] and class.specs[ id ].settings
                local specProf = self.DB.profile.specs[ id ]

                if #specCfg > 0 then
                    options.args.core.plugins.settings.prefSpacer = {
                        type = "description",
                        name = " ",
                        order = 100,
                        width = "full"
                    }

                    options.args.core.plugins.settings.prefHeader = {
                        type = "header",
                        name = specs[ id ] .. " 偏好设置",
                        order = 100.1,
                    }

                    for i, option in ipairs( specCfg ) do
                        if i > 1 and i % 2 == 1 then
                            -- Insert line break.
                            options.args.core.plugins.settings[ sName .. "LB" .. i ] = {
                                type = "description",
                                name = "",
                                width = "full",
                                order = option.info.order - 0.01
                            }
                        end

                        options.args.core.plugins.settings[ option.name ] = option.info
                        if self.DB.profile.specs[ id ].settings[ option.name ] == nil then
                            self.DB.profile.specs[ id ].settings[ option.name ] = option.default
                        end
                    end
                end

                db.plugins.specializations[ sName ] = options
            end

            i = i + 1
        end

    end

    local packControl = {
        listName = "default",
        actionID = "0001",

        makingNew = false,
        newListName = nil,

        showModifiers = false,

        newPackName = "",
        newPackSpec = "",
    }

    local nameMap = {
        call_action_list = "list_name",
        run_action_list = "list_name",
        variable = "var_name",
        op = "op"
    }

    local defaultNames = {
        list_name = "default",
        var_name = "unnamed_var",
    }

    local toggleToNumber = {
        cycle_targets = true,
        for_next = true,
        max_energy = true,
        only_cwc = true,
        strict = true,
        use_off_gcd = true,
        use_while_casting = true
    }

    local function GetListEntry( pack )
        local entry = rawget( AdvancedInterfaceOptions.DB.profile.packs, pack )

        if rawget( entry.lists, packControl.listName ) == nil then
            packControl.listName = "default"
        end

        if entry then entry = entry.lists[ packControl.listName ] else return end

        if rawget( entry, tonumber( packControl.actionID ) ) == nil then
            packControl.actionID = "0001"
        end

        local listPos = tonumber( packControl.actionID )
        if entry and listPos > 0 then entry = entry[ listPos ] else return end

        return entry
    end

    function AdvancedInterfaceOptions:GetActionOption( info )
        local n = #info
        local pack, option = info[ 2 ], info[ n ]

        if rawget( self.DB.profile.packs[ pack ].lists, packControl.listName ) == nil then
            packControl.listName = "default"
        end

        local actionID = tonumber( packControl.actionID )
        local data = self.DB.profile.packs[ pack ].lists[ packControl.listName ]

        if option == 'position' then return actionID
        elseif option == 'newListName' then return packControl.newListName end

        if not data then return end

        if not data[ actionID ] then
            actionID = 1
            packControl.actionID = "0001"
        end
        data = data[ actionID ]

        if option == "inputName" or option == "selectName" then
            option = nameMap[ data.action ]
            if not data[ option ] then data[ option ] = defaultNames[ option ] end
        end

        if option == "op" and not data.op then return "set" end

        if option == "potion" then
            if not data.potion then return "default" end
            if not class.potionList[ data.potion ] then
                return class.potions[ data.potion ] and class.potions[ data.potion ].key or data.potion
            end
        end

        if toggleToNumber[ option ] then return data[ option ] == 1 end
        return data[ option ]
    end

    -- Options to nil if val is false.
    local review_options = {
        enable_moving = 1,
        line_cd = 1,
        only_cwc = 1,
        strict = 1,
        strict_if = 1,
        use_off_gcd = 1,
        use_while_casting = 1
    }

    function AdvancedInterfaceOptions:SetActionOption( info, val )
        local n = #info
        local pack, option = info[ 2 ], info[ n ]

        local actionID = tonumber( packControl.actionID )
        local data = self.DB.profile.packs[ pack ].lists[ packControl.listName ]

        if option == 'newListName' then
            packControl.newListName = val:trim()
            return
        end

        if not data then return end
        data = data[ actionID ]

        if option == "inputName" or option == "selectName" then option = nameMap[ data.action ] end

        if toggleToNumber[ option ] then
            if review_options[ option ] and not val then val = nil
            else val = val and 1 or 0 end
        end
        if type( val ) == 'string' then
            val = val:trim()
            if val:len() == 0 then val = nil end
        end

        if option == "caption" then
            val = val:gsub( "||", "|" )
        end

        data[ option ] = val

        if option == "use_while_casting" and not val then
            data.use_while_casting = nil
        end

        if option == "action" then
            self:LoadScripts()
        else
            self:LoadScript( pack, packControl.listName, actionID )
        end

        if option == "enabled" then
            AdvancedInterfaceOptions:UpdateDisplayVisibility()
        end
    end

    function AdvancedInterfaceOptions:GetPackOption( info )
        local n = #info
        local category, subcat, option = info[ 2 ], info[ 3 ], info[ n ]

        if rawget( self.DB.profile.packs, category ) and rawget( self.DB.profile.packs[ category ].lists, packControl.listName ) == nil then
            packControl.listName = "default"
        end

        if option == "newPackSpec" and packControl[ option ] == "" then
            packControl[ option ] = GetCurrentSpec()
        end

        if packControl[ option ] ~= nil then return packControl[ option ] end

        if subcat == 'lists' then return self:GetActionOption( info ) end

        local data = rawget( self.DB.profile.packs, category )
        if not data then return end

        if option == 'date' then return tostring( data.date ) end

        return data[ option ]
    end

    function AdvancedInterfaceOptions:SetPackOption( info, val )
        local n = #info
        local category, subcat, option = info[ 2 ], info[ 3 ], info[ n ]

        if packControl[ option ] ~= nil then
            packControl[ option ] = val
            if option == "listName" then packControl.actionID = "0001" end
            return
        end

        if subcat == 'lists' then return self:SetActionOption( info, val ) end
        -- if subcat == 'newActionGroup' or ( subcat == 'actionGroup' and subtype == 'entry' ) then self:SetActionOption( info, val ); return end

        local data = rawget( self.DB.profile.packs, category )
        if not data then return end

        if type( val ) == 'string' then val = val:trim() end

        if option == "desc" then
            -- Auto-strip comments prefix
            val = val:gsub( "^#+ ", "" )
            val = val:gsub( "\n#+ ", "\n" )
        end

        data[ option ] = val
    end

    function AdvancedInterfaceOptions:EmbedPackOptions( db )
        db = db or self.Options
        if not db then return end

        local packs = db.args.packs or {
            type = "group",
            name = "优先级配置",
            desc = "优先级配置（或指令集）是一组操作列表，基于每个职业专精提供技能推荐。",
            get = 'GetPackOption',
            set = 'SetPackOption',
            order = 65,
            childGroups = 'tree',
            args = {
                packDesc = {
                    type = "description",
                    name = "优先级配置（或指令集）是一组操作列表，基于每个职业专精提供技能推荐。" ..
                    "它们可以自定义和共享。|cFFFF0000导入SimulationCraft优先级通常需要在导入之前进行一些转换，" ..
                    "才能够应用于插件。不支持导入和自定义已过期的优先级配置。|r",
                    order = 1,
                    fontSize = "medium",
                },

                newPackHeader = {
                    type = "header",
                    name = "创建新的优先级",
                    order = 200
                },

                newPackName = {
                    type = "input",
                    name = "配置名称",
                    desc = "输入唯一的配置名称。允许使用字母、数字、空格、下划线和撇号。",
                    order = 201,
                    width = "full",
                    validate = function( info, val )
                        val = val:trim()
                        if rawget( AdvancedInterfaceOptions.DB.profile.packs, val ) then return "请确保配置名称唯一。"
                        elseif val == "UseItems" then return "UseItems是系统保留名称。"
                        elseif val == "(none)" then return "别耍小聪明，你这愚蠢的土拨鼠。"
                        elseif val:find( "[^a-zA-Z0-9 _'()一-龥]" ) then return "配置名称允许使用字母、数字、空格、下划线和撇号。（译者加入了中文支持）" end
                        return true
                    end,
                },

                newPackSpec = {
                    type = "select",
                    name = "职业专精",
                    order = 202,
                    width = "full",
                    values = specs,
                },

                createNewPack = {
                    type = "execute",
                    name = "创建新配置",
                    order = 203,
                    disabled = function()
                        return packControl.newPackName == "" or packControl.newPackSpec == ""
                    end,
                    func = function ()
                        AdvancedInterfaceOptions.DB.profile.packs[ packControl.newPackName ].spec = packControl.newPackSpec
                        AdvancedInterfaceOptions:EmbedPackOptions()
                        ACD:SelectGroup( "AdvancedInterfaceOptions", "packs", packControl.newPackName )
                        packControl.newPackName = ""
                        packControl.newPackSpec = ""
                    end,
                },

                shareHeader = {
                    type = "header",
                    name = "分享",
                    order = 100,
                },

                shareBtn = {
                    type = "execute",
                    name = "分享优先级配置",
                    desc = "每个优先级配置都可以使用导出字符串分享给其他本插件用户。\n\n" ..
                    "你也可以在这里导入他人分享的字符串。",
                    func = function ()
                        ACD:SelectGroup( "AdvancedInterfaceOptions", "packs", "sharePacks" )
                    end,
                    order = 101,
                },

                sharePacks = {
                    type = "group",
                    name = "|cFF1EFF00分享/导入优先级配置|r",
                    desc = "你的优先级配置可以通过导出字符串分享给其他本插件用户。\n\n" ..
                    "你也可以在这里导入他人分享的字符串。",
                    childGroups = "tab",
                    get = 'GetPackShareOption',
                    set = 'SetPackShareOption',
                    order = 1001,
                    args = {
                        import = {
                            type = "group",
                            name = "导入",
                            order = 1,
                            args = {
                                stage0 = {
                                    type = "group",
                                    name = "",
                                    inline = true,
                                    order = 1,
                                    args = {
                                        guide = {
                                            type = "description",
                                            name = "|cFFFF0000不提供对来自其他地方的自定义或导入优先级的支持。|r\n\n" .. 
                                                    "|cFF00CCFF插件中包含的默认优先级是最新的，与你的角色兼容，不需要额外的更改。|r\n\n" .. 
                                                    "在下方的文本框中粘贴优先级字符串开始导入。",
                                            order = 1,
                                            width = "full",
                                            fontSize = "medium",
                                        },

                                        separator = {
                                            type = "header",
                                            name = "导入字符串",
                                            order = 1.5,
                                        },

                                        importString = {
                                            type = "input",
                                            name = "导入字符串",
                                            get = function () return shareDB.import end,
                                            set = function( info, val )
                                                val = val:trim()
                                                shareDB.import = val
                                            end,
                                            order = 3,
                                            multiline = 5,
                                            width = "full",
                                        },

                                        btnSeparator = {
                                            type = "header",
                                            name = "导入",
                                            order = 4,
                                        },

                                        importBtn = {
                                            type = "execute",
                                            name = "导入优先级配置",
                                            order = 5,
                                            func = function ()
                                                shareDB.imported, shareDB.error = DeserializeActionPack( shareDB.import )

                                                if shareDB.error then
                                                    shareDB.import = "无法解析当前的导入字符串。\n" .. shareDB.error
                                                    shareDB.error = nil
                                                    shareDB.imported = {}
                                                else
                                                    shareDB.importStage = 1
                                                end
                                            end,
                                            disabled = function ()
                                                return shareDB.import == ""
                                            end,
                                        },
                                    },
                                    hidden = function () return shareDB.importStage ~= 0 end,
                                },

                                stage1 = {
                                    type = "group",
                                    inline = true,
                                    name = "",
                                    order = 1,
                                    args = {
                                        packName = {
                                            type = "input",
                                            order = 1,
                                            name = "配置名称",
                                            get = function () return shareDB.imported.name end,
                                            set = function ( info, val ) shareDB.imported.name = val:trim() end,
                                            width = "full",
                                        },

                                        packDate = {
                                            type = "input",
                                            order = 2,
                                            name = "生成日期",
                                            get = function () return tostring( shareDB.imported.date ) end,
                                            set = function () end,
                                            width = "full",
                                            disabled = true,
                                        },

                                        packSpec = {
                                            type = "input",
                                            order = 3,
                                            name = "配置职业专精",
                                            get = function () return select( 2, GetSpecializationInfoByID( shareDB.imported.payload.spec or 0 ) ) or "No Specialization Set" end,
                                            set = function () end,
                                            width = "full",
                                            disabled = true,
                                        },

                                        guide = {
                                            type = "description",
                                            name = function ()
                                                local listNames = {}

                                                for k, v in pairs( shareDB.imported.payload.lists ) do
                                                    insert( listNames, k )
                                                end

                                                table.sort( listNames )

                                                local o

                                                if #listNames == 0 then
                                                    o = "导入的优先级配置不包含任何技能列表。"
                                                elseif #listNames == 1 then
                                                    o = "导入的优先级配置含有一个技能列表：" .. listNames[1] .. "。"
                                                elseif #listNames == 2 then
                                                    o = "导入的优先级配置包含两个技能列表：" .. listNames[1] .. " 和 " .. listNames[2] .. "。"
                                                else
                                                    o = "导入的优先级配置包含以下技能列表："
                                                    for i, name in ipairs( listNames ) do
                                                        if i == 1 then o = o .. name
                                                        elseif i == #listNames then o = o .. "，和" .. name .. "。"
                                                        else o = o .. "，" .. name end
                                                    end
                                                end

                                                return o
                                            end,
                                            order = 4,
                                            width = "full",
                                            fontSize = "medium",
                                        },

                                        separator = {
                                            type = "header",
                                            name = "应用更改",
                                            order = 10,
                                        },

                                        apply = {
                                            type = "execute",
                                            name = "应用更改",
                                            order = 11,
                                            confirm = function ()
                                                if rawget( self.DB.profile.packs, shareDB.imported.name ) then
                                                    return "你已经拥有名为“" .. shareDB.imported.name .. "”的优先级配置。\n覆盖它吗？"
                                                end
                                                return "确定从导入的数据创建名为“" .. shareDB.imported.name .. "”的优先级配置吗？"
                                            end,
                                            func = function ()
                                                self.DB.profile.packs[ shareDB.imported.name ] = shareDB.imported.payload
                                                shareDB.imported.payload.date = shareDB.imported.date
                                                shareDB.imported.payload.version = shareDB.imported.date

                                                shareDB.import = ""
                                                shareDB.imported = {}
                                                shareDB.importStage = 2

                                                self:LoadScripts()
                                                self:EmbedPackOptions()
                                            end,
                                        },

                                        reset = {
                                            type = "execute",
                                            name = "重置",
                                            order = 12,
                                            func = function ()
                                                shareDB.import = ""
                                                shareDB.imported = {}
                                                shareDB.importStage = 0
                                            end,
                                        },
                                    },
                                    hidden = function () return shareDB.importStage ~= 1 end,
                                },

                                stage2 = {
                                    type = "group",
                                    inline = true,
                                    name = "",
                                    order = 3,
                                    args = {
                                        note = {
                                            type = "description",
                                            name = "导入的设置已经成功应用！\n\n如果有必要，点击重置重新开始。",
                                            order = 1,
                                            fontSize = "medium",
                                            width = "full",
                                        },

                                        reset = {
                                            type = "execute",
                                            name = "重置",
                                            order = 2,
                                            func = function ()
                                                shareDB.import = ""
                                                shareDB.imported = {}
                                                shareDB.importStage = 0
                                            end,
                                        }
                                    },
                                    hidden = function () return shareDB.importStage ~= 2 end,
                                }
                            },
                            plugins = {
                            }
                        },

                        export = {
                            type = "group",
                            name = "导出",
                            order = 2,
                            args = {
                                guide = {
                                    type = "description",
                                    name = "请选择要导出的优先级配置。",
                                    order = 1,
                                    fontSize = "medium",
                                    width = "full",
                                },

                                actionPack = {
                                    type = "select",
                                    name = "优先级配置",
                                    order = 2,
                                    values = function ()
                                        local v = {}

                                        for k, pack in pairs( AdvancedInterfaceOptions.DB.profile.packs ) do
                                            if pack.spec and class.specs[ pack.spec ] then
                                                v[ k ] = k
                                            end
                                        end

                                        return v
                                    end,
                                    width = "full"
                                },

                                exportString = {
                                    type = "input",
                                    name = "导出优先级配置字符串",
                                    desc = "按CTRL+A全选，然后CTRL+C复制",
                                    order = 3,
                                    get = function ()
                                        if rawget( AdvancedInterfaceOptions.DB.profile.packs, shareDB.actionPack ) then
                                            shareDB.export = SerializeActionPack( shareDB.actionPack )
                                        else
                                            shareDB.export = ""
                                        end
                                        return shareDB.export
                                    end,
                                    set = function () end,
                                    width = "full",
                                    hidden = function () return shareDB.export == "" end,
                                },
                            },
                        }
                    }
                },
            },
            plugins = {
                packages = {},
                links = {},
            }
        }

        wipe( packs.plugins.packages )
        wipe( packs.plugins.links )

        local count = 0

        for pack, data in orderedPairs( self.DB.profile.packs ) do
            if data.spec and class.specs[ data.spec ] and not data.hidden then
                packs.plugins.links.packButtons = packs.plugins.links.packButtons or {
                    type = "header",
                    name = "已加载的配置",
                    order = 10,
                }

                packs.plugins.links[ "btn" .. pack ] = {
                    type = "execute",
                    name = pack,
                    order = 11 + count,
                    func = function ()
                        ACD:SelectGroup( "AdvancedInterfaceOptions", "packs", pack )
                    end,
                }

                local opts = packs.plugins.packages[ pack ] or {
                    type = "group",
                    name = function ()
                        local p = rawget( AdvancedInterfaceOptions.DB.profile.packs, pack )
                        if p then
                            if p.builtIn then return '|cFF00B4FF' .. pack .. '|r' end
                        end
                        return pack
                    end,
                    icon = function()
                        return class.specs[ data.spec ].texture
                    end,
                    iconCoords = { 0.15, 0.85, 0.15, 0.85 },
                    childGroups = "tab",
                    order = 100 + count,
                    args = {
                        pack = {
                            type = "group",
                            name = data.builtIn and ( BlizzBlue .. "摘要|r" ) or "摘要",
                            order = 1,
                            args = {
                                isBuiltIn = {
                                    type = "description",
                                    name = function ()
                                        return BlizzBlue .. "这是个默认的优先级配置。当插件更新时，它将会自动更新。" ..
                                        "如果想要自定义调整技能优先级，请点击|TInterface\\Addons\\AdvancedInterfaceOptions\\Textures\\WhiteCopy:0|t创建一个副本后操作|r。"
                                    end,
                                    fontSize = "medium",
                                    width = 3,
                                    order = 0.1,
                                    hidden = not data.builtIn
                                },

                                lb01 = {
                                    type = "description",
                                    name = "",
                                    order = 0.11,
                                    hidden = not data.builtIn
                                },

                                toggleActive = {
                                    type = "toggle",
                                    name = function ()
                                        local p = rawget( AdvancedInterfaceOptions.DB.profile.packs, pack )
                                        if p and p.builtIn then return BlizzBlue .. "激活|r" end
                                        return "激活"
                                    end,
                                    desc = "如果勾选，插件将会在职业专精对应时使用该优先级配置进行技能推荐。",
                                    order = 0.2,
                                    width = 3,
                                    get = function ()
                                        local p = rawget( AdvancedInterfaceOptions.DB.profile.packs, pack )
                                        return AdvancedInterfaceOptions.DB.profile.specs[ p.spec ].package == pack
                                    end,
                                    set = function ()
                                        local p = rawget( AdvancedInterfaceOptions.DB.profile.packs, pack )
                                        if AdvancedInterfaceOptions.DB.profile.specs[ p.spec ].package == pack then
                                            if p.builtIn then
                                                AdvancedInterfaceOptions.DB.profile.specs[ p.spec ].package = "(空)"
                                            else
                                                for def, data in pairs( AdvancedInterfaceOptions.DB.profile.packs ) do
                                                    if data.spec == p.spec and data.builtIn then
                                                        AdvancedInterfaceOptions.DB.profile.specs[ p.spec ].package = def
                                                        return
                                                    end
                                                end
                                            end
                                        else
                                            AdvancedInterfaceOptions.DB.profile.specs[ p.spec ].package = pack
                                        end
                                    end,
                                },

                                lb04 = {
                                    type = "description",
                                    name = "",
                                    order = 0.21,
                                    width = "full"
                                },

                                packName = {
                                    type = "input",
                                    name = "配置名称",
                                    order = 0.25,
                                    width = 2.7,
                                    validate = function( info, val )
                                        val = val:trim()
                                        if rawget( AdvancedInterfaceOptions.DB.profile.packs, val ) then return "请确保配置名称唯一。"
                                        elseif val == "UseItems" then return "UseItems是系统保留名称。"
                                        elseif val == "(none)" then return "别耍小聪明，你这愚蠢的土拨鼠。"
                                        elseif val:find( "[^a-zA-Z0-9 _'()一-龥]" ) then return "配置名称允许使用字母、数字、空格、下划线和撇号。" end
                                        return true
                                    end,
                                    get = function() return pack end,
                                    set = function( info, val )
                                        local profile = AdvancedInterfaceOptions.DB.profile

                                        local p = rawget( AdvancedInterfaceOptions.DB.profile.packs, pack )
                                        AdvancedInterfaceOptions.DB.profile.packs[ pack ] = nil

                                        val = val:trim()
                                        AdvancedInterfaceOptions.DB.profile.packs[ val ] = p

                                        for _, spec in pairs( AdvancedInterfaceOptions.DB.profile.specs ) do
                                            if spec.package == pack then spec.package = val end
                                        end

                                        AdvancedInterfaceOptions:EmbedPackOptions()
                                        AdvancedInterfaceOptions:LoadScripts()
                                        ACD:SelectGroup( "AdvancedInterfaceOptions", "packs", val )
                                    end,
                                    disabled = data.builtIn
                                },

                                copyPack = {
                                    type = "execute",
                                    name = "",
                                    desc = "拷贝配置",
                                    order = 0.26,
                                    width = 0.15,
                                    image = GetAtlasFile( "communities-icon-addgroupplus" ),
                                    imageCoords = GetAtlasCoords( "communities-icon-addgroupplus" ),
                                    imageHeight = 20,
                                    imageWidth = 20,
                                    confirm = function () return "确定创建此优先级配置的副本吗？" end,
                                    func = function ()
                                        local p = rawget( AdvancedInterfaceOptions.DB.profile.packs, pack )

                                        local newPack = tableCopy( p )
                                        newPack.builtIn = false
                                        newPack.basedOn = pack

                                        local newPackName, num = pack:match("^(.+) %((%d+)%)$")

                                        if not num then
                                            newPackName = pack
                                            num = 1
                                        end

                                        num = num + 1
                                        while( rawget( AdvancedInterfaceOptions.DB.profile.packs, newPackName .. " (" .. num .. ")" ) ) do
                                            num = num + 1
                                        end
                                        newPackName = newPackName .. " (" .. num ..")"

                                        AdvancedInterfaceOptions.DB.profile.packs[ newPackName ] = newPack
                                        AdvancedInterfaceOptions:EmbedPackOptions()
                                        AdvancedInterfaceOptions:LoadScripts()
                                        ACD:SelectGroup( "AdvancedInterfaceOptions", "packs", newPackName )
                                    end
                                },

                                reloadPack = {
                                    type = "execute",
                                    name = "",
                                    desc = "恢复默认配置",
                                    order = 0.27,
                                    width = 0.15,
                                    image = GetAtlasFile( "UI-RefreshButton" ),
                                    imageCoords = GetAtlasCoords( "UI-RefreshButton" ),
                                    imageWidth = 25,
                                    imageHeight = 24,
                                    confirm = function ()
                                        return "恢复这个循环的默认配置?"
                                    end,
                                    hidden = not data.builtIn,
                                    func = function ()
                                        AdvancedInterfaceOptions.DB.profile.packs[ pack ] = nil
                                        AdvancedInterfaceOptions:RestoreDefault( pack )
                                        AdvancedInterfaceOptions:EmbedPackOptions()
                                        AdvancedInterfaceOptions:LoadScripts()
                                        ACD:SelectGroup( "AdvancedInterfaceOptions", "packs", pack )
                                    end
                                },

                                deletePack = {
                                    type = "execute",
                                    name = "",
                                    desc = "删除优先级",
                                    order = 0.27,
                                    width = 0.15,
                                    image = GetAtlasFile( "common-icon-redx" ),
                                    imageCoords = GetAtlasCoords( "common-icon-redx" ),
                                    imageHeight = 24,
                                    imageWidth = 24,
                                    confirm = function () return "确定删除此优先级配置吗？" end,
                                    func = function ()
                                        local defPack

                                        local specId = data.spec
                                        local spec = specId and AdvancedInterfaceOptions.DB.profile.specs[ specId ]

                                        if specId then
                                            for pId, pData in pairs( AdvancedInterfaceOptions.DB.profile.packs ) do
                                                if pData.builtIn and pData.spec == specId then
                                                    defPack = pId
                                                    if spec.package == pack then
                                                        spec.package = pId
                                                        break
                                                    end
                                                end
                                            end
                                        end

                                        AdvancedInterfaceOptions.DB.profile.packs[ pack ] = nil
                                        AdvancedInterfaceOptions.Options.args.packs.plugins.packages[ pack ] = nil

                                        -- AdvancedInterfaceOptions:EmbedPackOptions()
                                        ACD:SelectGroup( "AdvancedInterfaceOptions", "packs" )
                                    end,
                                    hidden = function() return data.builtIn and not AdvancedInterfaceOptions.Version:sub(1, 3) == "Dev" end
                                },

                                lb02 = {
                                    type = "description",
                                    name = "",
                                    order = 0.3,
                                    width = "full",
                                },

                                spec = {
                                    type = "select",
                                    name = "对应职业专精",
                                    order = 1,
                                    width = 3,
                                    values = specs,
                                    disabled = data.builtIn and not AdvancedInterfaceOptions.Version:sub(1, 3) == "Dev"
                                },

                                lb03 = {
                                    type = "description",
                                    name = "",
                                    order = 1.01,
                                    width = "full",
                                    hidden = data.builtIn
                                },

                                desc = {
                                    type = "input",
                                    name = "说明描述",
                                    multiline = 15,
                                    order = 2,
                                    width = "full",
                                },
                            }
                        },

                        profile = {
                            type = "group",
                            name = "来源",
                            desc = "如果优先级配置基于SimulationCraft文件或职业指南，" ..
                            "最好提供来源的链接（尤其是分享之前）。",
                            order = 2,
                            args = {
                                signature = {
                                    type = "group",
                                    inline = true,
                                    name = "",
                                    order = 3,
                                    args = {
                                        source = {
                                            type = "input",
                                            name = "来源",
                                            desc = "如果优先级配置基于SimulationCraft文件或职业指南，" ..
                                            "最好提供来源的链接（尤其是分享之前）。",
                                            order = 1,
                                            width = 3,
                                        },

                                        break1 = {
                                            type = "description",
                                            name = "",
                                            width = "full",
                                            order = 1.1,
                                        },

                                        author = AdvancedInterfaceOptions:authornameInpt(),

                                        date = {
                                            type = "input",
                                            name = "日期",
                                            desc = "如果优先级配置基于SimulationCraft文件或职业指南，" ..
                                                "最好提供日期（尤其是分享之前）。",
                                            width = 1,
                                            order = 3,
                                            set = function () end,
                                            get = function ()
                                                local d = data.date or 0

                                                if type(d) == "string" then return d end
                                                return format( "%.4f", d )
                                            end,
                                        },
                                    },
                                },

                                profile = {
                                    type = "input",
                                    name = "优先级 (SimulationCraft Action Priority List)",
                                    desc = "" ..
                                        "如果你想要使用SimulationCraft的优先级配置，请在这里粘贴它。\n\n" ..
                                        "请注意：\n" ..
                                        "• 你不需要导入SimulationCraft的优先级配置来使用这个插件。没有来自其他地方的自定义或导入优先级配置的支持。\n" ..
                                        "• 插件内置的默认优先级配置会保持更新，与你的角色兼容，并且不需要额外修改。\n\n",
                                    order = 4,
                                    multiline = 10,
                                    confirm = true,
                                    confirmText = "确定要覆盖当前的优先级配置吗？",
                                    width = "full",
                                },

                                profilewarning = {
                                    type = "description",
                                    name = "\n|cFF00CCFF注意：|r\n" ..
                                        "• 你不需要导入SimulationCraft的优先级配置来使用这个插件。没有来自其他地方的自定义或导入优先级配置的支持。\n" ..
                                        "• 插件内置的默认优先级配置会保持更新，与你的角色兼容，并且不需要额外修改。\n\n",
                                    order = 2.1,
                                    fontSize = "medium",
                                    width = "full",
                                },

                                reimport = {
                                    type = "execute",
                                    name = function()
                                        local p = rawget( AdvancedInterfaceOptions.DB.profile.packs, pack )
                                        if p.spec ~= state.spec.id then
                                            return "|A:UI-LFG-DeclineMark:16:16|a 导入"
                                        end
                                        return format( "%s导入", p.spec ~= state.spec.id and "|A:UI-LFG-DeclineMark:16:16|a" or "" )
                                    end,
                                    desc = "清除现有行动清单并加载上述优先级",
                                    order = 5.1,
                                    width = 0.7,
                                    func = function ()
                                        local p = rawget( AdvancedInterfaceOptions.DB.profile.packs, pack )
                                        local profile = p.profile:gsub( '"', '' )

                                        local result, warnings = AdvancedInterfaceOptions:ImportSimcAPL( nil, nil, profile )

                                        wipe( p.lists )

                                        for k, v in pairs( result ) do
                                            p.lists[ k ] = v
                                        end

                                        p.warnings = warnings
                                        p.date = tonumber( date("%Y%m%d.%H%M%S") )

                                        if not p.lists[ packControl.listName ] then packControl.listName = "default" end

                                        local id = tonumber( packControl.actionID )
                                        if not p.lists[ packControl.listName ][ id ] then packControl.actionID = "zzzzzzzzzz" end

                                        self:LoadScripts()
                                    end,
                                    disabled = function()
                                        local p = rawget( AdvancedInterfaceOptions.DB.profile.packs, pack )
                                        return p.spec ~= state.spec.id
                                    end,
                                },
                                importWarningSpace = {
                                    type = "description",
                                    name = " ",
                                    width = 0.1,
                                    order = 5.11
                                },
                                importWarning = {
                                    type = "description",
                                    name = function()
                                        local p = rawget( AdvancedInterfaceOptions.DB.profile.packs, pack )
                                        return format( "你必须处于 |T%d:0|t |cFFFFD100%s|r 专精才能导入此优先级方案。", class.specs[ p.spec ].texture, class.specs[ p.spec ].name )
                                    end,
                                    image = GetAtlasFile( "Ping_Chat_Warning" ),
                                    imageCoords = GetAtlasCoords( "Ping_Chat_Warning" ),
                                    fontSize = "medium",
                                    width = 2.2,
                                    order = 5.12,
                                    hidden = function()
                                        local p = rawget( AdvancedInterfaceOptions.DB.profile.packs, pack )
                                        return p.spec == state.spec.id
                                    end
                                },
                                profileConsiderations = {
                                    type = "description",
                                    name = "\n|cFF00CCFF在导入配置文件前，请注意以下事项：|r\n\n" ..
                                    " |cFFFFD100•|r SimulationCraft 动作列表通常不会为单个角色做大幅调整。这些配置文件已包含适用于所有装备、天赋及其他综合条件的判断规则。\n\n" ..
                                    " |cFFFFD100•|r 大多数 SimulationCraft 动作列表需要额外调整才能在此插件中正常工作。例如 |cFFFFD100target_if|r 条件无法直接转换，必须手动重写。\n\n" ..
                                    " |cFFFFD100•|r 部分 SimulationCraft 动作配置文件经过本插件优化，运行效率更高且占用更少处理时间。\n\n" ..
                                    " |cFFFFD100•|r 此功能专为技术型用户和高级玩家保留。\n\n",
                                    order = 5,
                                    fontSize = "medium",
                                    width = "full",
                                },
                                warnings = {
                                    type = "input",
                                    name = "Import Log",
                                    order = 5.3,
                                    width = "full",
                                    multiline = 20,
                                    hidden = function ()
                                        local p = rawget( AdvancedInterfaceOptions.DB.profile.packs, pack )
                                        return not p.warnings or p.warnings == ""
                                    end,
                                },
                            }
                        },

                        lists = {
                            type = "group",
                            childGroups = "select",
                            name = "技能列表",
                            desc = "技能列表用于确定在合适的时机推荐使用正确的技能。",
                            order = 3,
                            args = {
                                listName = {
                                    type = "select",
                                    name = "技能列表",
                                    desc = "选择要查看或修改的技能列表。",
                                    order = 1,
                                    width = 2.7,
                                    values = function ()
                                        local v = {
                                            -- ["zzzzzzzzzz"] = "|cFF00FF00Add New Action List|r"
                                        }

                                        local p = rawget( AdvancedInterfaceOptions.DB.profile.packs, pack )

                                        for k in pairs( p.lists ) do
                                            local err = false

                                            if AdvancedInterfaceOptions.Scripts and AdvancedInterfaceOptions.Scripts.DB then
                                                local scriptHead = "^" .. pack .. ":" .. k .. ":"
                                                for k, v in pairs( AdvancedInterfaceOptions.Scripts.DB ) do
                                                    if k:match( scriptHead ) and v.Error then err = true
break end
                                                end
                                            end

                                            if err then
                                                v[ k ] = "|cFFFF0000" .. k .. "|r"
                                            elseif k == 'precombat' or k == 'default' then
                                                v[ k ] = "|cFF00B4FF" .. k .. "|r"
                                            --LJ 治疗石
                                            elseif k == 'healthStone' then
                                                v[ k ] = "|cFF00FF00" .. k .. "|r"
                                            else
                                                v[ k ] = k
                                            end
                                        end

                                        return v
                                    end,
                                },

                                newListBtn = {
                                    type = "execute",
                                    name = "",
                                    desc = "创建新的技能列表",
                                    order = 1.1,
                                    width = 0.15,
                                    image = "Interface\\AddOns\\AdvancedInterfaceOptions\\Textures\\GreenPlus",
                                    -- image = GetAtlasFile( "communities-icon-addgroupplus" ),
                                    -- imageCoords = GetAtlasCoords( "communities-icon-addgroupplus" ),
                                    imageHeight = 20,
                                    imageWidth = 20,
                                    func = function ()
                                        packControl.makingNew = true
                                    end,
                                },

                                delListBtn = {
                                    type = "execute",
                                    name = "",
                                    desc = "删除当前技能列表",
                                    order = 1.2,
                                    width = 0.15,
                                    image = RedX,
                                    -- image = GetAtlasFile( "common-icon-redx" ),
                                    -- imageCoords = GetAtlasCoords( "common-icon-redx" ),
                                    imageHeight = 20,
                                    imageWidth = 20,
                                    confirm = function() return "确定删除这个技能列表吗？" end,
                                    disabled = function () return packControl.listName == "default" or packControl.listName == "precombat" or packControl.listName == "healthStone" end,
                                    func = function ()
                                        local p = rawget( AdvancedInterfaceOptions.DB.profile.packs, pack )
                                        p.lists[ packControl.listName ] = nil
                                        AdvancedInterfaceOptions:LoadScripts()
                                        packControl.listName = "default"
                                    end,
                                },

                                lineBreak = {
                                    type = "description",
                                    name = "",
                                    width = "full",
                                    order = 1.9
                                },

                                actionID = {
                                    type = "select",
                                    name = "项目",
                                    desc = "在此技能列表中选择要修改的项目。\n\n" ..
                                    "红色项目表示被禁用、没有技能列表、条件错误或执行指令被禁用/忽略的技能。",
                                    order = 2,
                                    width = 2.4,
                                    values = function ()
                                        local v = {}

                                        local data = rawget( AdvancedInterfaceOptions.DB.profile.packs, pack )
                                        local list = rawget( data.lists, packControl.listName )

                                        if list then
                                            local last = 0

                                            for i, entry in ipairs( list ) do
                                                local key = format( "%04d", i )
                                                local action = entry.action
                                                local desc

                                                local warning, color = false

                                                if not action then
                                                    action = "Unassigned"
                                                    warning = true
                                                else
                                                    if not class.abilities[ action ] then warning = true
                                                    else
                                                        if action == "trinket1" or action == "trinket2" or action == "main_hand" then
                                                            local passthru = "actual_" .. action
                                                            if state:IsDisabled( passthru, true ) then warning = true end
                                                            action = class.abilityList[ passthru ] and class.abilityList[ passthru ] or class.abilities[ passthru ] and class.abilities[ passthru ].name or action
                                                        else
                                                            if state:IsDisabled( action, true ) then warning = true end
                                                            action = class.abilityList[ action ] and class.abilityList[ action ]:match( "|t (.+)$" ) or class.abilities[ action ] and class.abilities[ action ].name or action
                                                        end
                                                    end
                                                end

                                                local scriptID = pack .. ":" .. packControl.listName .. ":" .. i
                                                local script = AdvancedInterfaceOptions.Scripts.DB[ scriptID ]

                                                if script and script.Error then warning = true end

                                                local cLen = entry.criteria and entry.criteria:len()

                                                if entry.caption and entry.caption:len() > 0 then
                                                    desc = entry.caption

                                                elseif entry.action == "variable" then
                                                    if entry.op == "reset" then
                                                        desc = format( "reset |cff00ccff%s|r", entry.var_name or "unassigned" )
                                                    elseif entry.op == "default" then
                                                        desc = format( "|cff00ccff%s|r default = |cffffd100%s|r", entry.var_name or "unassigned", entry.value or "0" )
                                                    elseif entry.op == "set" or entry.op == "setif" then
                                                        desc = format( "set |cff00ccff%s|r = |cffffd100%s|r", entry.var_name or "unassigned", entry.value or "nothing" )
                                                    else
                                                        desc = format( "%s |cff00ccff%s|r (|cffffd100%s|r)", entry.op or "set", entry.var_name or "unassigned", entry.value or "nothing" )
                                                    end

                                                    if cLen and cLen > 0 then
                                                        desc = format( "%s, if |cffffd100%s|r", desc, entry.criteria )
                                                    end

                                                elseif entry.action == "call_action_list" or entry.action == "run_action_list" then
                                                    if not entry.list_name or not rawget( data.lists, entry.list_name ) then
                                                        desc = "|cff00ccff(未设置)|r"
                                                        warning = true
                                                    else
                                                        desc = "|cff00ccff" .. entry.list_name .. "|r"
                                                    end

                                                    if cLen and cLen > 0 then
                                                        desc = desc .. ", if |cffffd100" .. entry.criteria .. "|r"
                                                    end

                                                elseif entry.action == "cancel_buff" then
                                                    if not entry.buff_name then
                                                        desc = "|cff00ccff(未设置)|r"
                                                        warning = true
                                                    else
                                                        local a = class.auras[ entry.buff_name ]

                                                        if a then
                                                            desc = "|cff00ccff" .. a.name .. "|r"
                                                        else
                                                            desc = "|cff00ccff(未找到)|r"
                                                            warning = true
                                                        end
                                                    end

                                                    if cLen and cLen > 0 then
                                                        desc = desc .. ", if |cffffd100" .. entry.criteria .. "|r"
                                                    end

                                                elseif entry.action == "cancel_action" then
                                                    if not entry.action_name then
                                                        desc = "|cff00ccff(未设置)|r"
                                                        warning = true
                                                    else
                                                        local a = class.abilities[ entry.action_name ]

                                                        if a then
                                                            desc = "|cff00ccff" .. a.name .. "|r"
                                                        else
                                                            desc = "|cff00ccff(未找到)|r"
                                                            warning = true
                                                        end
                                                    end

                                                    if cLen and cLen > 0 then
                                                        desc = desc .. ", if |cffffd100" .. entry.criteria .. "|r"
                                                    end

                                                elseif cLen and cLen > 0 then
                                                    desc = "|cffffd100" .. entry.criteria .. "|r"

                                                end

                                                if not entry.enabled then
                                                    warning = true
                                                    color = "|cFF808080"
                                                end

                                                if desc then desc = desc:gsub( "[\r\n]", "" ) end

                                                if not color then
                                                    color = warning and "|cFFFF0000" or "|cFFFFD100"
                                                end

                                                if entry.empower_to then
                                                    if entry.empower_to == "max_empower" then
                                                        action = action .. "(Max)"
                                                    else
                                                        action = action .. " (" .. entry.empower_to .. ")"
                                                    end
                                                end

                                                if desc then
                                                    v[ key ] = color .. i .. ".|r " .. action .. " - " .. "|cFFFFD100" .. desc .. "|r"
                                                else
                                                    v[ key ] = color .. i .. ".|r " .. action
                                                end

                                                last = i + 1
                                            end
                                        end

                                        return v
                                    end,
                                    hidden = function ()
                                        return packControl.makingNew == true
                                    end,
                                },

                                moveUpBtn = {
                                    type = "execute",
                                    name = "",
                                    image = "Interface\\AddOns\\AdvancedInterfaceOptions\\Textures\\WhiteUp",
                                    -- image = GetAtlasFile( "hud-MainMenuBar-arrowup-up" ),
                                    -- imageCoords = GetAtlasCoords( "hud-MainMenuBar-arrowup-up" ),
                                    imageHeight = 20,
                                    imageWidth = 20,
                                    width = 0.15,
                                    order = 2.1,
                                    func = function( info )
                                        local p = rawget( AdvancedInterfaceOptions.DB.profile.packs, pack )
                                        local data = p.lists[ packControl.listName ]
                                        local actionID = tonumber( packControl.actionID )

                                        local a = remove( data, actionID )
                                        insert( data, actionID - 1, a )
                                        packControl.actionID = format( "%04d", actionID - 1 )

                                        local listName = format( "%s:%s:", pack, packControl.listName )
                                        scripts:SwapScripts( listName .. actionID, listName .. ( actionID - 1 ) )
                                    end,
                                    disabled = function ()
                                        return tonumber( packControl.actionID ) == 1
                                    end,
                                    hidden = function () return packControl.makingNew end,
                                },

                                moveDownBtn = {
                                    type = "execute",
                                    name = "",
                                    image = "Interface\\AddOns\\AdvancedInterfaceOptions\\Textures\\WhiteDown",
                                    -- image = GetAtlasFile( "hud-MainMenuBar-arrowdown-up" ),
                                    -- imageCoords = GetAtlasCoords( "hud-MainMenuBar-arrowdown-up" ),
                                    imageHeight = 20,
                                    imageWidth = 20,
                                    width = 0.15,
                                    order = 2.2,
                                    func = function ()
                                        local p = rawget( AdvancedInterfaceOptions.DB.profile.packs, pack )
                                        local data = p.lists[ packControl.listName ]
                                        local actionID = tonumber( packControl.actionID )

                                        local a = remove( data, actionID )
                                        insert( data, actionID + 1, a )
                                        packControl.actionID = format( "%04d", actionID + 1 )

                                        local listName = format( "%s:%s:", pack, packControl.listName )
                                        scripts:SwapScripts( listName .. actionID, listName .. ( actionID + 1 ) )
                                    end,
                                    disabled = function()
                                        local p = rawget( AdvancedInterfaceOptions.DB.profile.packs, pack )
                                        return not p.lists[ packControl.listName ] or tonumber( packControl.actionID ) == #p.lists[ packControl.listName ]
                                    end,
                                    hidden = function () return packControl.makingNew end,
                                },

                                newActionBtn = {
                                    type = "execute",
                                    name = "",
                                    image = "Interface\\AddOns\\AdvancedInterfaceOptions\\Textures\\GreenPlus",
                                    -- image = GetAtlasFile( "communities-icon-addgroupplus" ),
                                    -- imageCoords = GetAtlasCoords( "communities-icon-addgroupplus" ),
                                    imageHeight = 20,
                                    imageWidth = 20,
                                    width = 0.15,
                                    order = 2.3,
                                    func = function()
                                        local data = rawget( self.DB.profile.packs, pack )
                                        if data then
                                            insert( data.lists[ packControl.listName ], { {} } )
                                            packControl.actionID = format( "%04d", #data.lists[ packControl.listName ] )
                                        else
                                            packControl.actionID = "0001"
                                        end
                                    end,
                                    hidden = function () return packControl.makingNew end,
                                },

                                delActionBtn = {
                                    type = "execute",
                                    name = "",
                                    image = RedX,
                                    -- image = GetAtlasFile( "common-icon-redx" ),
                                    -- imageCoords = GetAtlasCoords( "common-icon-redx" ),
                                    imageHeight = 20,
                                    imageWidth = 20,
                                    width = 0.15,
                                    order = 2.4,
                                    confirm = function() return "确定删除这个项目吗？" end,
                                    func = function ()
                                        local id = tonumber( packControl.actionID )
                                        local p = rawget( AdvancedInterfaceOptions.DB.profile.packs, pack )

                                        remove( p.lists[ packControl.listName ], id )

                                        if not p.lists[ packControl.listName ][ id ] then id = id - 1
packControl.actionID = format( "%04d", id ) end
                                        if not p.lists[ packControl.listName ][ id ] then packControl.actionID = "zzzzzzzzzz" end

                                        self:LoadScripts()
                                    end,
                                    disabled = function ()
                                        local p = rawget( AdvancedInterfaceOptions.DB.profile.packs, pack )
                                        return not p.lists[ packControl.listName ] or #p.lists[ packControl.listName ] < 2
                                    end,
                                    hidden = function () return packControl.makingNew end,
                                },

                                enabled = {
                                    type = "toggle",
                                    name = "启用",
                                    desc = "如果禁用此项，即使满足条件，也不会显示此项目。",
                                    order = 3.0,
                                    width = "full",
                                },

                                searchInPut = {
                                    type = "input",
                                    name = "模糊查询(名字)",
                                    desc = "查询到会用绿色标记出来",
                                    order = 3.1,
                                    width = 1.5,
                                    set = function(info, val)
                                        ns.seachID_Edit = val
                                    end,
                                    get = function() end,
                                },

                                action = {
                                    type = "select",
                                    name = "指令（技能）",
                                    desc = "选择满足项目条件时推荐进行的操作指令。",
                                    values = function()
                                        local list = {}
                                        local bypass = {
                                            trinket1 = actual_trinket1,
                                            trinket2 = actual_trinket2,
                                            main_hand = actual_main_hand
                                        }

                                        --LJ
                                        for k, v in pairs(class.abilityList) do
                                            if ns.seachID_Edit ~= "" and string.find(v, ns.seachID_Edit) then
                                                list[k] = bypass[k] or v
                                            end

                                            if ns.seachID_Edit == "" then
                                                list[k] = bypass[k] or v
                                            end
                                        end

                                        return list
                                    end,
                                    sorting = function( a, b )
                                        local list = {}

                                        for k, v in pairs(class.abilityList) do
                                            if ns.seachID_Edit ~= "" and string.find(v, ns.seachID_Edit) then
                                                insert(list, k)
                                            end
                                            if ns.seachID_Edit == "" then
                                                insert(list, k)
                                            end
                                        end
                                        return list
                                    end,
                                    order = 3.1,
                                    width = 1.5,
                                },

                                list_name = {
                                    type = "select",
                                    name = "技能列表",
                                    values = function ()
                                        local e = GetListEntry( pack )
                                        local v = {}

                                        local p = rawget( AdvancedInterfaceOptions.DB.profile.packs, pack )

                                        for k in pairs( p.lists ) do
                                            if k ~= packControl.listName then
                                                if k == 'precombat' or k == 'default' then
                                                    v[ k ] = "|cFF00B4FF" .. k .. "|r"
                                                else
                                                    v[ k ] = k
                                                end
                                            end
                                        end

                                        return v
                                    end,
                                    order = 3.2,
                                    width = 1.5,
                                    hidden = function ()
                                        local e = GetListEntry( pack )
                                        return not ( e.action == "call_action_list" or e.action == "run_action_list" )
                                    end,
                                },

                                buff_name = {
                                    type = "select",
                                    name = "Buff名称",
                                    order = 3.2,
                                    width = 1.5,
                                    desc = "选择要取消的Buff。",
                                    values = class.auraList,
                                    hidden = function ()
                                        local e = GetListEntry( pack )
                                        return e.action ~= "cancel_buff"
                                    end,
                                },

                                action_name = {
                                    type = "select",
                                    name = "指令名称",
                                    order = 3.2,
                                    width = 1.5,
                                    desc = "设定要取消的指令。插件将立即停止该指令的后续操作",
                                    values = class.abilityList,
                                    hidden = function ()
                                        local e = GetListEntry( pack )
                                        return e.action ~= "cancel_action"
                                    end,
                                },

                                potion = {
                                    type = "select",
                                    name = "药剂",
                                    order = 3.2,
                                    -- width = "full",
                                    values = class.potionList,
                                    hidden = function ()
                                        local e = GetListEntry( pack )
                                        return e.action ~= "potion"
                                    end,
                                    width = 1.5,
                                },

                                sec = {
                                    type = "input",
                                    name = "秒",
                                    order = 3.2,
                                    width = 1.5,
                                    hidden = function ()
                                        local e = GetListEntry( pack )
                                        return e.action ~= "wait"
                                    end,
                                },

                                max_energy = {
                                    type = "toggle",
                                    name = "最大连击点数",
                                    order = 3.2,
                                    width = 1.5,
                                    desc = "勾选后此项后，将要求玩家有足够大的连击点数激发凶猛撕咬的全部伤害加成。",
                                    hidden = function ()
                                        local e = GetListEntry( pack )
                                        return e.action ~= "ferocious_bite"
                                    end,
                                },

                                empower_to = {
                                    type = "select",
                                    name = "蓄力等级",
                                    order = 3.2,
                                    width = 1.5,
                                    desc = "蓄力的技能，指定其使用的蓄力等级（默认为最大）。",
                                    values = {
                                        [1] = "I",
                                        [2] = "II",
                                        [3] = "III",
                                        [4] = "IV",
                                        max_empower = "Max"
                                    },
                                    hidden = function ()
                                        local e = GetListEntry( pack )
                                        local action = e.action
                                        local ability = action and class.abilities[ action ]
                                        return not ( ability and ability.empowered )
                                    end,
                                },

                                lb00 = {
                                    type = "description",
                                    name = "",
                                    order = 3.201,
                                    width = "full",
                                },

                                caption = {
                                    type = "input",
                                    name = "标题",
                                    desc = "标题是出现在推荐技能图标上的|cFFFF0000简短|r的描述。\n\n" ..
                                    "这样做有助于理解为什么在此刻推荐这个技能。\n\n" ..
                                    "需要在每个显示框架上启用。",
                                    order = 3.202,
                                    width = 1.5,
                                    validate = function( info, val )
                                        val = val:trim()
                                        val = val:gsub( "||", "|" ):gsub( "|T.-:0|t", "" ) -- Don't count icons.
                                        if val:len() > 20 then return "标题文本不得超过20个字符。" end
                                        return true
                                    end,
                                    hidden = function()
                                        local e = GetListEntry( pack )
                                        local ability = e.action and class.abilities[ e.action ]

                                        return not ability or ( ability.id < 0 and ability.id > -10 )
                                    end,
                                },

                                description = {
                                    type = "input",
                                    name = "说明描述",
                                    desc = "这里允许你提供解释此项目的说明。当你暂停并用鼠标悬停时，将显示此处的文本，以便查看推荐此项目的原因。",
                                    order = 3.205,
                                    width = "full",
                                },

                                lb01 = {
                                    type = "description",
                                    name = "",
                                    order = 3.21,
                                    width = "full"
                                },

                                var_name = {
                                    type = "input",
                                    name = "变量名",
                                    order = 3.3,
                                    width = 1.5,
                                    desc = "指定此变量的名称。变量名必须使用小写字母，且除了下划线之外不允许其他符号。",
                                    validate = function( info, val )
                                        if val:len() < 3 then return "变量名的长度必须不少于3个字符。" end

                                        local check = formatKey( val )
                                        if check ~= val then return "输入的字符无效。请重试。" end

                                        return true
                                    end,
                                    hidden = function ()
                                        local e = GetListEntry( pack )
                                        return e.action ~= "variable"
                                    end,
                                },

                                op = {
                                    type = "select",
                                    name = "操作",
                                    values = {
                                        add = "增加数值",
                                        ceil = "数值向上取整",
                                        default = "设置默认值",
                                        div = "数值除法",
                                        floor = "数值向下取整",
                                        max = "最大值",
                                        min = "最小值",
                                        mod = "数值取余",
                                        mul = "数值乘法",
                                        pow = "数值幂运算",
                                        reset = "重置为默认值",
                                        set = "设置数值为",
                                        setif = "如果…设置数值为",
                                        sub = "数值减法",
                                    },
                                    order = 3.31,
                                    width = 1.5,
                                    hidden = function ()
                                        local e = GetListEntry( pack )
                                        return e.action ~= "variable"
                                    end,
                                },

                                modPooling = {
                                    type = "group",
                                    inline = true,
                                    name = "",
                                    order = 3.5,
                                    args = {
                                        for_next = {
                                            type = "toggle",
                                            name = function ()
                                                local n = packControl.actionID
n = tonumber( n ) + 1
                                                local e = AdvancedInterfaceOptions.DB.profile.packs[ pack ].lists[ packControl.listName ][ n ]

                                                local ability = e and e.action and class.abilities[ e.action ]
                                                ability = ability and ability.name or "未设置"

                                                return "Pool for Next Entry (" .. ability ..")"
                                            end,
                                            desc = "如果勾选，插件将归集资源，直到下一个技能有足够的资源可供使用。",
                                            order = 5,
                                            width = 1.5,
                                            hidden = function ()
                                                local e = GetListEntry( pack )
                                                return e.action ~= "pool_resource"
                                            end,
                                        },

                                        wait = {
                                            type = "input",
                                            name = "归集时间",
                                            desc = "以秒为单位指定时间，需要是数字或计算结果为数字的表达式。\n" ..
                                            "默认值为|cFFFFD1000.5|r。表达式示例为|cFFFFD100energy.time_to_max|r。",
                                            order = 6,
                                            width = 1.5,
                                            multiline = 3,
                                            hidden = function ()
                                                local e = GetListEntry( pack )
                                                return e.action ~= "pool_resource" or e.for_next == 1
                                            end,
                                        },

                                        extra_amount = {
                                            type = "input",
                                            name = "额外归集",
                                            desc = "指定除了下一项目所需的资源外，还需要额外归集的资源量。",
                                            order = 6,
                                            width = 1.5,
                                            hidden = function ()
                                                local e = GetListEntry( pack )
                                                return e.action ~= "pool_resource" or e.for_next ~= 1
                                            end,
                                        },
                                    },
                                    hidden = function ()
                                        local e = GetListEntry( pack )
                                        return e.action ~= 'pool_resource'
                                    end,
                                },

                                criteria = {
                                    type = "input",
                                    name = "条件",
                                    desc = "指定条件表达式，只有在满足条件时才会执行此操作。\n\n" ..
                                        "如果没有提供条件，则此操作始终会被执行。\n\n" ..
                                        "条件示例：\n" ..
                                        "|cFFFFD100energy.time_to_max|r\n" ..
                                        "|cFFFFD100player.health<0.5|r\n" ..
                                        "|cFFFFD100target.health>0.8|r\n" ..
                                        "|cFFFFD100player.buff( 'buff_name' )|r\n" ..
                                        "|cFFFFD100player.debuff( 'debuff_name' )|r\n",
                                    order = 3.6,
                                    width = "full",
                                    multiline = 6,
                                    dialogControl = "AdvancedInterfaceOptionsCustomEditor",
                                    arg = function( info )
                                        local pack, list, action = info[ 2 ], packControl.listName, tonumber( packControl.actionID )
                                        local results = {}

                                        state.reset( "Primary", true )

                                        local apack = rawget( self.DB.profile.packs, pack )

                                        -- Let's load variables, just in case.
                                        for name, alist in pairs( apack.lists ) do
                                            state.this_list = name

                                            for i, entry in ipairs( alist ) do
                                                if name ~= list or i ~= action then
                                                    if entry.action == "variable" and entry.var_name then
                                                        state:RegisterVariable( entry.var_name, pack .. ":" .. name .. ":" .. i, name )
                                                    end
                                                end
                                            end
                                        end

                                        local entry = apack and apack.lists[ list ]
                                        entry = entry and entry[ action ]

                                        state.this_action = entry.action
                                        state.this_list = list

                                        local scriptID = pack .. ":" .. list .. ":" .. action
                                        state.scriptID = scriptID
                                        scripts:StoreValues( results, scriptID )

                                        return results, list, action
                                    end,
                                },

                                value = {
                                    type = "input",
                                    name = "数值",
                                    desc = "提供调用此变量时要存储（或计算）的数值。",
                                    order = 3.61,
                                    width = "full",
                                    multiline = 3,
                                    dialogControl = "AdvancedInterfaceOptionsCustomEditor",
                                    arg = function( info )
                                        local pack, list, action = info[ 2 ], packControl.listName, tonumber( packControl.actionID )
                                        local results = {}

                                        state.reset( "Primary", true )

                                        local apack = rawget( self.DB.profile.packs, pack )

                                        -- Let's load variables, just in case.
                                        for name, alist in pairs( apack.lists ) do
                                            state.this_list = name
                                            for i, entry in ipairs( alist ) do
                                                if name ~= list or i ~= action then
                                                    if entry.action == "variable" and entry.var_name then
                                                        state:RegisterVariable( entry.var_name, pack .. ":" .. name .. ":" .. i, name )
                                                    end
                                                end
                                            end
                                        end

                                        local entry = apack and apack.lists[ list ]
                                        entry = entry and entry[ action ]

                                        state.this_action = entry.action
                                        state.this_list = list

                                        local scriptID = pack .. ":" .. list .. ":" .. action
                                        state.scriptID = scriptID
                                        scripts:StoreValues( results, scriptID, "value" )

                                        return results, list, action
                                    end,
                                    hidden = function ()
                                        local e = GetListEntry( pack )
                                        return e.action ~= "variable" or e.op == "reset" or e.op == "ceil" or e.op == "floor"
                                    end,
                                },

                                value_else = {
                                    type = "input",
                                    name = "不满足时数值",
                                    desc = "提供不满足此变量条件时要存储（或计算）的数值。",
                                    order = 3.62,
                                    width = "full",
                                    multiline = 3,
                                    dialogControl = "AdvancedInterfaceOptionsCustomEditor",
                                    arg = function( info )
                                        local pack, list, action = info[ 2 ], packControl.listName, tonumber( packControl.actionID )
                                        local results = {}

                                        state.reset( "Primary", true )

                                        local apack = rawget( self.DB.profile.packs, pack )

                                        -- Let's load variables, just in case.
                                        for name, alist in pairs( apack.lists ) do
                                            state.this_list = name
                                            for i, entry in ipairs( alist ) do
                                                if name ~= list or i ~= action then
                                                    if entry.action == "variable" and entry.var_name then
                                                        state:RegisterVariable( entry.var_name, pack .. ":" .. name .. ":" .. i, name )
                                                    end
                                                end
                                            end
                                        end

                                        local entry = apack and apack.lists[ list ]
                                        entry = entry and entry[ action ]

                                        state.this_action = entry.action
                                        state.this_list = list

                                        local scriptID = pack .. ":" .. list .. ":" .. action
                                        state.scriptID = scriptID
                                        scripts:StoreValues( results, scriptID, "value_else" )

                                        return results, list, action
                                    end,
                                    hidden = function ()
                                        local e = GetListEntry( pack )
                                        -- if not e.criteria or e.criteria:trim() == "" then return true end
                                        return e.action ~= "variable" or e.op == "reset" or e.op == "ceil" or e.op == "floor"
                                    end,
                                },

                                showModifiers = {
                                    type = "toggle",
                                    name = "显示设置项",
                                    desc = "如果勾选，可以调整更多的设置项和条件。",
                                    order = 999,
                                    width = "full",
                                    hidden = function ()
                                        local e = GetListEntry( pack )
                                        local ability = e.action and class.abilities[ e.action ]

                                        return not ability -- or ( ability.id < 0 and ability.id > -100 )
                                    end,
                                },

                                modCycle = {
                                    type = "group",
                                    inline = true,
                                    name = "",
                                    order = 21,
                                    args = {
                                        cycle_targets = {
                                            type = "toggle",
                                            name = "循环目标",
                                            desc = "如果勾选，插件将检查每个可用目标，并提示切换目标。",
                                            order = 1,
                                            width = "single",
                                        },

                                        max_cycle_targets = {
                                            type = "input",
                                            name = "最大循环目标数",
                                            desc = "如果勾选循环目标，插件将监测指定数量的目标。",
                                            order = 2,
                                            width = "double",
                                            disabled = function( info )
                                                local e = GetListEntry( pack )
                                                return e.cycle_targets ~= 1
                                            end,
                                        }
                                    },
                                    hidden = function ()
                                        local e = GetListEntry( pack )
                                        local ability = e.action and class.abilities[ e.action ]

                                        return not e.cycle_targets and
                                            not e.max_cycle_targets and
                                            not packControl.showModifiers or ( not ability or ( ability.id < 0 and ability.id > -100 ) )
                                    end,
                                },

                                modMoving = {
                                    type = "group",
                                    inline = true,
                                    name = "",
                                    order = 22,
                                    args = {
                                        enable_moving = {
                                            type = "toggle",
                                            name = "监测移动",
                                            desc = "如果勾选，仅当角色的移动状态与设置匹配时，才会推荐此项目。",
                                            order = 1,
                                        },

                                        moving = {
                                            type = "select",
                                            name = "移动状态",
                                            desc = "如果设置，仅当你的移动状态与设置匹配时，才会推荐此项目。",
                                            order = 2,
                                            width = "double",
                                            values = {
                                                 [0]  = "站立",
                                                [1]  = "移动"
                                            },
                                            disabled = function( info )
                                                local e = GetListEntry( pack )
                                                return not e.enable_moving
                                            end,
                                        }
                                    },
                                    hidden = function ()
                                        local e = GetListEntry( pack )
                                        local ability = e.action and class.abilities[ e.action ]

                                        return not e.enable_moving and
                                            not packControl.showModifiers or ( not ability or ( ability.id < 0 and ability.id > -100 ) )
                                    end,
                                },

                                modAsyncUsage = {
                                    type = "group",
                                    inline = true,
                                    name = "",
                                    order = 22.1,
                                    args = {
                                        use_off_gcd = {
                                            type = "toggle",
                                            name = "GCD时可用",
                                            desc = "如果勾选，即使处于全局冷却（GCD）中，也可以推荐使用此项。",
                                            order = 1,
                                            width = 0.99,
                                        },
                                        use_while_casting = {
                                            type = "toggle",
                                            name = "施法中可用",
                                            desc = "如果勾选，即使已经在施法或引导中，也可以推荐使用此项。",
                                            order = 2,
                                            width = 0.99
                                        },
                                        only_cwc = {
                                            type = "toggle",
                                            name = "仅在引导中可用",
                                            desc = "如果勾选，仅在施法或引导中可用时，才会推荐使用此项。",
                                            order = 3,
                                            width = 0.99
                                        }
                                    },
                                    hidden = function ()
                                        local e = GetListEntry( pack )
                                        local ability = e.action and class.abilities[ e.action ]

                                        return not e.use_off_gcd and
                                            not e.use_while_casting and
                                            not e.only_cwc and
                                            not packControl.showModifiers or ( not ability or ( ability.id < 0 and ability.id > -100 ) )
                                    end,
                                },

                                modCooldown = {
                                    type = "group",
                                    inline = true,
                                    name = "",
                                    order = 23,
                                    args = {

                                        line_cd = {
                                            type = "input",
                                            name = "强制冷却时间",
                                            desc = "如果设置，则强制在上次使用此项目后一定时间后，才会再次被推荐。(比如 火冲)",
                                            order = 1,
                                            width = "full",
                                        },
                                    },
                                    hidden = function ()
                                        local e = GetListEntry( pack )
                                        local ability = e.action and class.abilities[ e.action ]

                                        return not e.line_cd and
                                            not packControl.showModifiers or ( not ability or ( ability.id < 0 and ability.id > -100 ) )
                                    end,
                                },

                                modAPL = {
                                    type = "group",
                                    inline = true,
                                    name = "",
                                    order = 24,
                                    args = {
                                        strict = {
                                            type = "toggle",
                                            name = "立即测试条件",
                                            desc = "若勾选此项，则必须立即满足上述条件，此操作才会被推荐或使用。",
                                            order = 1,
                                            width = "full",
                                        },
                                        strict_if = {
                                            type = "input",
                                            name = "额外即时条件",
                                            desc = "若填写此项，则必须先满足这些即时条件，才会测试上述条件。",
                                            multiline = 3,
                                            dialogControl = "AdvancedInterfaceOptionsCustomEditor",
                                            arg = function( info )
                                                local pack, list, action = info[ 2 ], packControl.listName, tonumber( packControl.actionID )
                                                local results = {}

                                                state.reset( "Primary", true )

                                                local apack = rawget( self.DB.profile.packs, pack )

                                                -- Let's load variables, just in case.
                                                for name, alist in pairs( apack.lists ) do
                                                    state.this_list = name

                                                    for i, entry in ipairs( alist ) do
                                                        if name ~= list or i ~= action then
                                                            if entry.action == "variable" and entry.var_name then
                                                                state:RegisterVariable( entry.var_name, pack .. ":" .. name .. ":" .. i, name )
                                                            end
                                                        end
                                                    end
                                                end

                                                local entry = apack and apack.lists[ list ]
                                                entry = entry and entry[ action ]

                                                state.this_action = entry.action
                                                state.this_list = list

                                                local scriptID = pack .. ":" .. list .. ":" .. action
                                                state.scriptID = scriptID
                                                scripts:StoreValues( results, scriptID, "strict_if" )

                                                return results, list, action
                                            end,
                                            order = 2,
                                            width = "full",
                                        }
                                    },
                                    hidden = function ()
                                        local e = GetListEntry( pack )
                                        local ability = e.action and class.abilities[ e.action ]

                                        return not e.strict and
                                            not e.strict_if and
                                            not packControl.showModifiers or ( not ability or not ( ability.key == "call_action_list" or ability.key == "run_action_list" ) )
                                    end,
                                },

                                newListGroup = {
                                    type = "group",
                                    inline = true,
                                    name = "",
                                    order = 2,
                                    hidden = function ()
                                        return not packControl.makingNew
                                    end,
                                    args = {
                                        newListName = {
                                            type = "input",
                                            name = "列表名",
                                            order = 1,
                                            validate = function( info, val )
                                                local p = rawget( AdvancedInterfaceOptions.DB.profile.packs, pack )

                                                if val:len() < 2 then return "技能列表名的长度至少为2个字符。"
                                                elseif rawget( p.lists, val ) then return "已存在同名的技能列表。"
                                                elseif val:find( "[^a-zA-Z0-9一-龥_]" ) then return "技能列表能使用中文、字母、数字、字符和下划线。" end
                                                return true
                                            end,
                                            width = 3,
                                        },

                                        lineBreak = {
                                            type = "description",
                                            name = "",
                                            order = 1.1,
                                            width = "full"
                                        },

                                        createList = {
                                            type = "execute",
                                            name = "添加列表",
                                            disabled = function() return packControl.newListName == nil end,
                                            func = function ()
                                                local p = rawget( AdvancedInterfaceOptions.DB.profile.packs, pack )
                                                p.lists[ packControl.newListName ] = { {} }
                                                packControl.listName = packControl.newListName
                                                packControl.makingNew = false

                                                packControl.actionID = "0001"
                                                packControl.newListName = nil

                                                AdvancedInterfaceOptions:LoadScript( pack, packControl.listName, 1 )
                                            end,
                                            width = 1,
                                            order = 2,
                                        },

                                        cancel = {
                                            type = "execute",
                                            name = "取消",
                                            func = function ()
                                                packControl.makingNew = false
                                            end,
                                        }
                                    }
                                },

                                newActionGroup = {
                                    type = "group",
                                    inline = true,
                                    name = "",
                                    order = 3,
                                    hidden = function ()
                                        return packControl.makingNew or packControl.actionID ~= "zzzzzzzzzz"
                                    end,
                                    args = {
                                        createEntry = {
                                            type = "execute",
                                            name = "创建新项目",
                                            order = 1,
                                            func = function ()
                                                local p = rawget( AdvancedInterfaceOptions.DB.profile.packs, pack )
                                                insert( p.lists[ packControl.listName ], {} )
                                                packControl.actionID = format( "%04d", #p.lists[ packControl.listName ] )
                                            end,
                                        }
                                    }
                                }
                            },
                            plugins = {
                            }
                        },

                        export = {
                            type = "group",
                            name = "导出",
                            order = 4,
                            args = {
                                exportString = {
                                    type = "input",
                                    name = "导出字符串",
                                    desc = "按CTRL+A全部选中，然后CTRL+C复制。",
                                    get = function( info )
                                        AdvancedInterfaceOptions.PackExports = AdvancedInterfaceOptions.PackExports or {}

                                        -- Wipe previous output for this pack.
                                        local exportData = {
                                            export = "",
                                            stress = "",
                                            linked = false,
                                            unrelated = false
                                        }
                                        AdvancedInterfaceOptions.PackExports[ pack ] = exportData

                                        local export = SerializeActionPack( pack )
                                        exportData.export = export

                                        wipe( AdvancedInterfaceOptions.ErrorDB )
                                        wipe( AdvancedInterfaceOptions.ErrorKeys )

                                        AdvancedInterfaceOptions.Scripts:LoadScripts()
                                        local stressTestResults = AdvancedInterfaceOptions:RunStressTest()

                                        local function ColorizeAPLIdentifier( key )
                                            local spec, list, entry, context = key:match( "^([^:]+):([^:]+):(%d+)%s+(%a+):" )
                                            if not spec then return key end

                                            return string.format(
                                                "|cff00ccff%s|r:|cffffd100%s|r:%s |cff888888%s|r:",
                                                spec, list, entry, context
                                            )
                                        end

                                        local output, finalOutput = {}, {}
                                        local lowerPack = pack:lower()
                                        local shadowKey   = "error in " .. lowerPack .. ":"
                                        local shadowLabel = "priority '" .. lowerPack .. "'"

                                        for _, key in ipairs( AdvancedInterfaceOptions.ErrorKeys ) do
                                            local entry = AdvancedInterfaceOptions.ErrorDB[ key ]
                                            if entry then
                                                local body = entry.text or "|cff777777<No message provided>|r"
                                                local coloredKey = ColorizeAPLIdentifier( key )

                                                table.insert( output, format(
                                                    "|cff888888[%s (%dx)]|r %s\n%s",
                                                    entry.last or "??", entry.n or 1, coloredKey, body
                                                ))

                                                local k = key:lower()
                                                if k:find( shadowKey, 1, true ) or k:find( shadowLabel, 1, true ) then
                                                    exportData.linked = true
                                                else
                                                    exportData.unrelated = true
                                                end
                                            end
                                        end

                                        -- 1. Stress Test
                                        if type( stressTestResults ) == "string" and stressTestResults ~= "" then
                                            table.insert( finalOutput, "|cffa0a0ff自动校验:|r " .. stressTestResults )
                                        end
                                        -- 2. Header
                                        if exportData.linked then
                                            table.insert( finalOutput, "|cffff0000注意:|r 该优先级存在未解决的警告，导出前请检查。" )
                                        elseif exportData.unrelated then
                                            table.insert( finalOutput, "|cffffff00NOTICE:|r 自界面重载后存在未解决的警告（这些警告可能与本优先级无关）。" )
                                        end
                                        -- 3. Error entries
                                        for _, line in ipairs( output ) do
                                            table.insert( finalOutput, line )
                                        end
                                        if not exportData.linked and not exportData.unrelated and #output == 0 then
                                            table.insert( finalOutput, "|cff00ff00未检测到警告或错误!|r\n" )
                                        end

                                        exportData.stress = table.concat( finalOutput, "\n\n" )
                                        return export
                                    end,
                                    set = function() end,
                                    order = 1,
                                    width = "full",
                                },
                                stressResults = {
                                    type = "input",
                                    multiline = 20,
                                    name = "自动校验结果",
                                    get = function()
                                        local info = AdvancedInterfaceOptions.PackExports and AdvancedInterfaceOptions.PackExports[ pack ]
                                        return info and info.stress or ""
                                    end,
                                    set = function() end,
                                    order = 2,
                                    width = "full",
                                    hidden = function()
                                        local info = AdvancedInterfaceOptions.PackExports and AdvancedInterfaceOptions.PackExports[ pack ]
                                        return not ( info and info.stress and info.stress ~= "" )
                                    end
                                }
                            },
                            hidden = function()
                                if AdvancedInterfaceOptions.PackExports then
                                    AdvancedInterfaceOptions.PackExports[ pack ] = nil
                                end
                                return false
                            end
                        }
                    },
                }

                --[[ wipe( opts.args.lists.plugins.lists )

                local n = 10
                for list in pairs( data.lists ) do
                    opts.args.lists.plugins.lists[ list ] = EmbedActionListOptions( n, pack, list )
                    n = n + 1
                end ]]

                packs.plugins.packages[ pack ] = opts
                count = count + 1
            end
        end

        collectgarbage()
        db.args.packs = packs
    end

end


do
    local completed = false
    local SetOverrideBinds

    SetOverrideBinds = function ()
        if InCombatLockdown() then
            C_Timer.After( 5, SetOverrideBinds )
            return
        end

        if completed then
            ClearOverrideBindings( AdvancedInterfaceOptions_Keyhandler )
            completed = false
        end

        for name, toggle in pairs( AdvancedInterfaceOptions.DB.profile.toggles ) do
            if toggle.key and toggle.key ~= "" then
                SetOverrideBindingClick( AdvancedInterfaceOptions_Keyhandler, true, toggle.key, "AdvancedInterfaceOptions_Keyhandler", name )
                completed = true
            end
        end
    end

    function AdvancedInterfaceOptions:OverrideBinds()
        SetOverrideBinds()
    end

    local function SetToggle( info, val )
        local self = AdvancedInterfaceOptions
        local p = self.DB.profile
        local n = #info
        local bind, option = info[ n - 1 ], info[ n ]

        local toggle = p.toggles[ bind ]
        if not toggle then return end

        if option == 'value' then
            if bind == 'pause' then self:TogglePause()
            elseif bind == 'mode' then toggle.value = val
            else self:FireToggle( bind ) end

        elseif option == 'type' then
            toggle.type = val

            if val == "AutoSingle" and not ( toggle.value == "automatic" or toggle.value == "single" ) then toggle.value = "automatic" end
            if val == "AutoDual" and not ( toggle.value == "automatic" or toggle.value == "dual" ) then toggle.value = "automatic" end
            if val == "SingleAOE" and not ( toggle.value == "single" or toggle.value == "aoe" ) then toggle.value = "single" end
            if val == "ReactiveDual" and toggle.value ~= "reactive" then toggle.value = "reactive" end

        elseif option == 'key' then
            for t, data in pairs( p.toggles ) do
                if data.key == val then data.key = "" end
            end

            toggle.key = val
            self:OverrideBinds()

        elseif option == 'override' then
            toggle[ option ] = val
            ns.UI.Minimap:RefreshDataText()

        else
            toggle[ option ] = val

        end
    end

    local function GetToggle( info )
        local self = AdvancedInterfaceOptions
        local p = AdvancedInterfaceOptions.DB.profile
        local n = #info
        local bind, option = info[ n - 1 ], info[ n ]

        local toggle = bind and p.toggles[ bind ]
        if not toggle then return end

        if bind == 'pause' and option == 'value' then return self.Pause end
        return toggle[ option ]
    end

    -- Bindings.
    function AdvancedInterfaceOptions:EmbedToggleOptions( db )
        db = db or self.Options
        if not db then return end

        db.args.toggles = db.args.toggles or {
            type = "group",
            name = "快捷键设置",
            desc = "这里了可以设置 插件相关功能的快捷键",
            order = 20,
            childGroups = "tab",
            get = GetToggle,
            set = SetToggle,
            args = {
                cooldowns = {
                    type = "group",
                    name = "爆发相关",
                    desc = "这里设置 爆发相关功能的快捷键",
                    order = 2,
                    args = {
                        key = {
                            type = "keybinding",
                            name = "爆发技能",
                            desc = "设置一个快捷键, 用来控制爆发技能的开关",
                            order = 1,
                        },

                        value = {
                            type = "toggle",
                            name = "允许爆发技能",
                            desc = "勾选后插件会推荐爆发技能",
                            order = 2,
                            width = 2,
                        },

                        cdLineBreak1 = {
                            type = "description",
                            name = "",
                            width = "full",
                            order = 2.1
                        },

                        cdIndent1 = {
                            type = "description",
                            name = "",
                            width = 1,
                            order = 2.2
                        },


                        cdLineBreak2 = {
                            type = "description",
                            name = "",
                            width = "full",
                            order = 3.1,
                        },

                        cdIndent2 = {
                            type = "description",
                            name = "",
                            width = 1,
                            order = 3.2
                        },

                        override = {
                            type = "toggle",
                            name = format("当获得 %s 状态时自动开启爆发", AdvancedInterfaceOptions:GetSpellLinkWithTexture(2825)),
                            desc = format("当获得 %s 状态时自动开启爆发", AdvancedInterfaceOptions:GetSpellLinkWithTexture(2825)),
                            width = 2,
                            order = 4,
                        },

                        cdLineBreak3 = {
                            type = "description",
                            name = "",
                            width = "full",
                            order = 4.1,
                        },

                        cdIndent3 = {
                            type = "description",
                            name = "",
                            width = 1,
                            order = 4.2
                        },

                        infusion = {
                            type = "toggle",
                            name = format("当获得 %s 状态时自动开启爆发", AdvancedInterfaceOptions:GetSpellLinkWithTexture(10060)),
                            desc = format("当获得 %s 状态时自动开启爆发", AdvancedInterfaceOptions:GetSpellLinkWithTexture(10060)),
                            width = 2,
                            order = 5
                        },

                        essences = {
                            type = "group",
                            name = "",
                            inline = true,
                            order = 6,
                            args = {
                                key = {
                                    type = "keybinding",
                                    name = "次级爆发",
                                    desc = "设置一个快捷键用来控制 次级爆发 技能的释放",
                                    width = 1,
                                    order = 1,
                                },

                                value = {
                                    type = "toggle",
                                    name = "开启 次级爆发",
                                    desc = "设置一个快捷键用来控制 次级爆发 技能的释放",
                                    width = 2,
                                    order = 2,
                                },


                                essLineBreak2 = {
                                    type = "description",
                                    name = "",
                                    width = "full",
                                    order = 3.1,
                                },

                                essIndent2 = {
                                    type = "description",
                                    name = "",
                                    width = 1,
                                    order = 3.2
                                },

                                override = {
                                    type = "toggle",
                                    name = "自动开启当 |cFFFFD100爆发技能|r 开关 启动的时候",
                                    desc = "如果勾选, 当 |cFFFFD100爆发技能|r 启用的时候 , 会自动释放 |cFFFFD100次级爆发技能|r.",
                                    width = 2,
                                    order = 4,
                                },
                            }
                        },

                        potions = {
                            type = "group",
                            name = "",
                            inline = true,
                            order = 7,
                            args = {
                                key = {
                                    type = "keybinding",
                                    name = "爆发药剂",
                                    desc = "设置一个快捷键 控制爆发药剂的使用",
                                    order = 1,
                                },

                                value = {
                                    type = "toggle",
                                    name = "自动使用爆发药剂",
                                    desc = "如果勾选, 插件将会推荐 |cFFFFD100爆发药剂|r .",
                                    width = 2,
                                    order = 2,
                                },
                              
                                potLineBreak2 = {
                                    type = "description",
                                    name = "",
                                    width = "full",
                                    order = 3.1
                                },

                                potIndent3 = {
                                    type = "description",
                                    name = "",
                                    width = 1,
                                    order = 3.2
                                },

                                override = {
                                    type = "toggle",
                                    name = "自动开启此选项当 |cFFFFD100爆发技能|r 开启的时候",
                                    desc = "如果勾选, 当 |cFFFFD100爆发技能|r 开启时候, 自动开启.",
                                    width = 2,
                                    order = 4,
                                },
                            }
                        },
                        enable_items = {
                            type = "group",
                            name = "",
                            inline = true,
                            order = 8,
                            args = {
                                key = {
                                    type = "keybinding",
                                    name = "使用饰品",
                                    desc = "如果不勾选，插件将不会释放任何带有主动效果的 饰品 和 装备 的技能",
                                    width = 1,
                                    order = 1,
                                },

                                value = {
                                    type = "toggle",
                                    name = "使用饰品",
                                    desc = "如果不勾选，插件将不会释放任何带有主动效果的 饰品 和 装备 的技能。\n\n",
                                    width = 2,
                                    order = 2,
                                },

                                supportedSpecs = {
                                    type = "description",
                                    name = "如果不勾选，插件将不会释放任何带有主动效果的 饰品 和 装备 的技能",
                                    desc = "",
                                    width = "full",
                                    order = 3,
                                },
                            },
                        },
                    }, 
                },

                interrupts = {
                    type = "group",
                    name = "打断和防御",
                    desc = "这里控制 打断和防御技能相关的快捷键",
                    order = 4,
                    args = {
                        key = {
                            type = "keybinding",
                            name = "自动打断",
                            desc = "设置一个快捷键 控制自动打断的开关",
                            order = 1,
                        },

                        value = {
                            type = "toggle",
                            name = "自动打断",
                            desc = "设置一个快捷键 控制自动打断的开关",
                            order = 2,
                        },

                        lb1 = {
                            type = "description",
                            name = "",
                            width = "full",
                            order = 2.1
                        },

                        indent1 = {
                            type = "description",
                            name = "",
                            width = 1,
                            order = 2.2,
                        },


                        lb2 = {
                            type = "description",
                            name = "",
                            width = "full",
                            order = 3.1
                        },


                        indent2 = {
                            type = "description",
                            name = "",
                            width = 1,
                            order = 3.2,
                        },

                        filterCasts  ={
                            type = "toggle",
                            name = format( "%s 过滤大米打断技能", NewFeature ),
                            desc = format("如果勾选, 插件会挑选一些必要技能打断, 有一些读条垃圾技能是不会打断的\n\n"),
                            width = 2,
                            order = 4
                        },
                        lb3 = {
                            type = "description",
                            name = "",
                            width = "full",
                            order = 4.1
                        },

                        indent3 = {
                            type = "description",
                            name = "",
                            width = 1,
                            order = 4.2,
                        },
                        castRemainingThreshold = {
                            type = "range",
                            name = "打断时间阈值",
                            desc = "默认情况下，当敌人的施法剩余时间为0.25秒（或更少）时，推荐使用打断技能。\n\n如果设置为2秒，当敌人的施法剩余时间少于2秒时，也可能推荐使用打断技能。",
                            min = 0.25,
                            max = 3,
                            step = 0.25,
                            width = 2,
                            order = 4.3
                        },

                        defensives = {
                            type = "group",
                            name = "",
                            inline = true,
                            order = 5,
                            args = {
                                key = {
                                    type = "keybinding",
                                    name = "自动减伤",
                                    desc = "设置一个快捷键用来控制 减伤技能的释放\n\n"
                                        .. "通常这个只适用于 坦克 职业",
                                    order = 1,
                                },

                                value = {
                                    type = "toggle",
                                    name = "开启 自动减伤",
                                    desc = "如果勾选, 插件将会在到达阈值的时候自动开启爆发\n\n"
                                        .. "通常这个只适用于 坦克 职业",
                                    order = 2,
                                },

                                lb1 = {
                                    type = "description",
                                    name = "",
                                    width = "full",
                                    order = 2.1
                                },

                                indent1 = {
                                    type = "description",
                                    name = "",
                                    width = 1,
                                    order = 2.2,
                                },

                            }
                        },
                    }
                },

                displayModes = {
                    type = "group",
                    name = "目标识别",
                    desc = "设置目标识别模式切换的快捷键",
                    order = 10,
                    args = {
                        mode = {
                            type = "group",
                            inline = true,
                            name = "",
                            order = 10.1,
                            args = {
                                key = {
                                    type = 'keybinding',
                                    name = '目标识别模式',
                                    desc = "控制 插件的目标识别模式  单体/群体/自动识别(推荐)",
                                    order = 1,
                                    width = 1,
                                },

                                value = {
                                    type = "select",
                                    name = "设置识别模式",
                                    desc = "设置识别模式",
                                    values = {
                                        automatic = "自动识别",
                                        single = "强制单体",
                                        aoe = "AOE（多目标）",
                                    },
                                    width = 1,
                                    order = 1.02,
                                },

                                modeLB2 = {
                                    type = "description",
                                    name = "插件会根据勾选的模式进行轮换",
                                    fontSize = "medium",
                                    width = "full",
                                    order = 2
                                },

                                automatic = {
                                    type = "toggle",
                                    name = "自动识别" .. BlizzBlue .. "(默认推荐)|r",
                                    desc = "勾选之后会在切换目标中轮换",
                                    width = "full",
                                    order = 3,
                                },

                                single = {
                                    type = "toggle",
                                    name = "强制单体",
                                    desc = "强制单体",
                                    width = "full",
                                    order = 4,
                                },

                                aoe = {
                                    type = "toggle",
                                    name = "Aoe",
                                    desc = "Aoe",
                                    width = "full",
                                    order = 4,
                                },

                                crazyDog = {
                                    type = "group",
                                    name = "",
                                    inline = true,
                                    order = 7,
                                    args = {
                                        key = {
                                            type = "keybinding",
                                            name = "疯狗模式",
                                            desc = "插件会攻击任何状态的目标(容易Add)",
                                            order = 1,
                                        },
        
                                        value = {
                                            type = "toggle",
                                            name = "启用 疯狗模式",
                                            desc = "如果勾选, 插件会攻击没有进入战斗状态的目标,相当于 自动Add了,容易引怪",
                                            order = 2,
                                        },
                                    }
                                },

                                spacer = {
                                    type = "description",
                                    name = "",
                                    width = "full",
                                    order = 6,
                                },
                                targetSelect = {
                                    type = "group",
                                    name = "",
                                    inline = true,
                                    order = 7,
                                    args = {
                                        key = {
                                            type = "keybinding",
                                            name = "自动切换目标",
                                            desc = "设置一个开关自动自动切换目标的快捷键",
                                            order = 1,
                                        },
        
                                        value = {
                                            type = "toggle",
                                            name = "自动切换目标",
                                            desc = "如果勾选,1.当前攻击的目标死亡会自动切换,需要检查怪物Dot的时候会自动切换",
                                            order = 2,
                                        },
                                        autoSelec_force = {
                                            type = "toggle",
                                            name = "强制选择目标(慎用!)",
                                            desc = "如果勾选, 不管你是否在战斗中 插件都会尝试不停的Tab 去寻找目标(适合刷的地方挂机)",
                                            width = 1,
                                            order = 2.1,
                                        },
                                    }
                                },

                            },
                        }
                    }
                },

                troubleshooting = {
                    type = "group",
                    name = "开始/暂停",
                    desc = "设置一个快捷键,用来控制开始和暂停循环",
                    order = 20,
                    args = {
                        pause = {
                            type = "group",
                            name = "",
                            inline = true,
                            order = 1,
                            args = {
                                key = {
                                    type = 'keybinding',
                                    name = function() return AdvancedInterfaceOptions.Pause and "开启" or "暂停" end,
                                    desc = "控制循环的开始和停止",
                                    order = 1,
                                },
                                value = {
                                    type = 'toggle',
                                    name = '开始/暂停',
                                    order = 2,
                                },
                                ges = {
                                    type = 'toggle',
                                    name = '开启抽筋模式',
                                    desc = "勾选后, 暂停循环将会失效,当按下 按下暂停按键时插件将会输出,抬起则暂停循环",
                                    order = 3,
                                    get = function ()
                                       return AdvancedInterfaceOptions.DB.profile.toggles.gseMode.value
                                    end,
                                    set = function ()
                                        AdvancedInterfaceOptions:FireToggle("gseMode"); ns.UI.Minimap:RefreshDataText()
                                        if AdvancedInterfaceOptions.Pause and AdvancedInterfaceOptions.DB.profile.toggles.gseMode.value then
                                            AdvancedInterfaceOptions.Pause = false
                                        end
                                    end
                                }
                            }
                        },

                        -- snapshot = {
                        --     type = "group",
                        --     name = "",
                        --     inline = true,
                        --     order = 2,
                        --     args = {
                        --         key = {
                        --             type = 'keybinding',
                        --             name = 'Snapshot',
                        --             desc = "Set a key to make a snapshot (without pausing) that can be viewed on the Snapshots tab.  This can be useful information for testing and debugging.",
                        --             order = 1,
                        --         },
                        --     }
                        -- },
                    }
                },

                custom = {
                    type = "group",
                    name = "自定义分类开关",
                    desc = "通过指定快捷键，可以创建自定义的类别来控制特定技能。",
                    order = 30,
                    args = {
                        desc = {
                            type = "description",
                            name = "这里可以自定义技能归类, 例如 设置一个自定义名称为突进, 然后在技能设置中 将战士的冲锋 归类为 突进, 再设置一个快捷键键 你就可以用一个快捷键用来控制突进类技能的释放了",
                            fontSize = "medium",
                            width = 2.85,
                            order = 1
                        },
                        custom1 = {
                            type = "group",
                            name = "",
                            inline = true,
                            order = 2,
                            args = {
                                key = {
                                    type = "keybinding",
                                    name = "自定义 1",
                                    desc = "设置一个按键来切换第一个自定义设置。",
                                    width = 1,
                                    order = 1,
                                },

                                value = {
                                    type = "toggle",
                                    name = "启用自定义 1",
                                    desc = "如果勾选，则允许推荐自定义 1 中的技能。",
                                    width = 2,
                                    order = 2,
                                },

                                lb1 = {
                                    type = "description",
                                    name = "",
                                    width = "full",
                                    order = 2.1
                                },

                                indent1 = {
                                    type = "description",
                                    name = "",
                                    width = 1,
                                    order = 2.2
                                },

                                name = {
                                    type = "input",
                                    name = "自定义 1 名称",
                                    desc = "为自定义切换开关指定一个描述性名称。",
                                    width = 2,
                                    order = 3
                                }
                            }
                        },

                        custom2 = {
                            type = "group",
                            name = "",
                            inline = true,
                            order = 3,
                            args = {
                                key = {
                                    type = "keybinding",
                                    name = "自定义 2",
                                    desc = "设置一个按键来切换第二个自定义设置。",
                                    width = 1,
                                    order = 1,
                                },

                                value = {
                                    type = "toggle",
                                    name = "启用自定义 2",
                                    desc = "如果勾选，则允许推荐自定义 2 中的技能。",
                                    width = 2,
                                    order = 2,
                                },

                                lb1 = {
                                    type = "description",
                                    name = "",
                                    width = "full",
                                    order = 2.1
                                },

                                indent1 = {
                                    type = "description",
                                    name = "",
                                    width = 1,
                                    order = 2.2
                                },

                                name = {
                                    type = "input",
                                    name = "自定义 2 名称",
                                    desc = "为自定义切换开关指定一个描述性名称。",
                                    width = 2,
                                    order = 3
                                }
                            }
                        }
                    }
                }
            }
        }
    end

        --扩展
    function AdvancedInterfaceOptions:EmbedExtensionOptions(db)
        db = db or self.Options
        if not db then return end

        db.args.ext = db.args.ext or {
            type = "group",
            name = "|cFFFF0000骚东西|r",
            desc = "AdvancedInterfaceOptions的额外扩展功能",
            order = 21,
            childGroups = "tab",
            get = GetToggle,
            set = SetToggle,
            args = {
                autoCooldown = {
                    type = "group",
                    name = "摆烂模式",
                    desc = "设置评估场上进入战斗的目标自动开启/关闭爆发技能",
                    order = 1,
                    args = {
                        key = {
                            type = "keybinding",
                            name = "摆烂模式",
                            desc = "设置一个按键对摆烂模式功能是否启用进行开/关。",
                            order = 1,
                        },

                        value = {
                            type = "toggle",
                            name = "启用",
                            desc = "如果勾选，则可以自动推荐 |cFFFFD100主要爆发|r 中的技能和物品。\n\n"
                                .. "如果满足设定条件， AdvancedInterfaceOptions 将会根据情况推荐爆发或者常规技能。\n\n",
                            order = 2,
                            width = 2,
                            get = function(info)
                                return AdvancedInterfaceOptions.DB.profile.toggles.autoCooldown.value
                            end,
                            set = function()
                                AdvancedInterfaceOptions.DB.profile.toggles.autoCooldown.value = not AdvancedInterfaceOptions.DB.profile.toggles.autoCooldown.value
                                if AdvancedInterfaceOptions.DB.profile.toggles.autoCooldown.value == true then
                                    AdvancedInterfaceOptions.DB.profile.toggles.cooldown_safe.value = false
                                end
                            end,
                        },


                        cdLineBreak2 = {
                            type = "description",
                            name = "",
                            width = "full",
                            order = 3.1,
                        },

                        cdIndent2 = {
                            type = "description",
                            name = "",
                            width = 1,
                            order = 3.2
                        },

                        safeMode = {
                            type = "toggle",
                            name = "爆发技能保护",
                            desc = "如果勾选， AdvancedInterfaceOptions 将在合适的时机，推荐常规技能， 让你避免无意义的爆发技能释放",
                            width = 2,
                            order = 4,
                            get = function()
                                return AdvancedInterfaceOptions.DB.profile.toggles.cooldown_safe.value
                            end,
                            set = function()
                                AdvancedInterfaceOptions.DB.profile.toggles.cooldown_safe.value = not  AdvancedInterfaceOptions.DB.profile.toggles.cooldown_safe.value
                                if AdvancedInterfaceOptions.DB.profile.toggles.cooldown_safe.value == true then
                                    AdvancedInterfaceOptions.DB.profile.toggles.autoCooldown.value = false
                                end
                            end,
                        },


                        thresholdValue = {
                            type = "range",
                            name = "当前专精摆烂阈值（计算结果低于该数值推荐 常规技能  反之 推荐 爆发技能）",
                            desc = "该数值是以自身生命最大值进行权重，设定值 x 自身最大血量 和 进入战斗目标的总血量进行比较和控制爆发技能的释放",
                            order = 5,
                            min = 0,
                            max = 50,
                            step = 0.1,
                            width = "full",
                            set   = function(info, val)
                                self.DB.profile.specs[state.spec.id].autoCooldown_closeTime = val
                            end,
                            get   = function() return self.DB.profile.specs[state.spec.id].autoCooldown_closeTime or 1 end,
                        },
                    }
                },
                otherSet = {
                    type = "group",
                    name = "进阶参数设置",
                    desc = "进一步设置插件其他功能的参数",
                    order = 2,
                    args = {
                        gcdOffset = {
                            type = "range",
                            name = "GCD偏移量（在GCD冷却结束前多少秒触发按键）",
                            desc = "调高该数值会让你的按键触发更加密集, 但是也会增加技能错误的风险",
                            order = 1,
                            min = 0,
                            max = 1,
                            step = 0.1,
                            width = "full",
                            get = function()
                                return self.DB.profile.specs[state.spec.id].GCDThoredValue or 0.3
                            end,
                            set = function(info, val)
                                self.DB.profile.specs[state.spec.id].GCDThoredValue  = val
                            end,
                        },

                        
                        line1 = {
                            type = "description",
                            name = "\n",
                            width = "full",
                            order = 2,
                        },
                        

                        distanceLock = {
                            type = "range",
                            name = "强制距离判定（距离选定的目标多少码以内生效, 非0生效）",
                            desc = "该数值会根据当前选择的目标距离进行判断, 如果超出设定的码数，插件将不会进行输出循环",
                            order = 3,
                            min = 0,
                            max = 50,
                            step = 1,
                            width = "full",
                            get = function()
                                return self.DB.profile.specs[state.spec.id].nameplateRange or 10
                            end,
                            set = function(info, val)
                                self.DB.profile.specs[state.spec.id].nameplateRange = val
                            end,
                        },


                        line2 = {
                            type = "description",
                            name = "\n",
                            width = "full",
                            order = 4,
                        },

                        -- SpellQueueWindow = {
                        --     type = "range",
                        --     name = "延迟容限(不懂这个东西就不要弄, 一般是比自身网络延迟略高一些)",
                        --     desc = "游戏中的施法队列参数，又称延迟容限,这一参数允许玩家在施法结束前预先将下一个技能加入服务器队列，从而实现技能的流畅衔接。其默认值为400毫秒，意味着在前一个技能读条结束或公共CD到期前的400毫秒内，玩家可以按下下一个技能的键，使其进入施法队列。这个数值可以一定程度解决一些职业卡手的问题, 但是会导致技能延迟释放",
                        --     order = 5,
                        --     min = 10,
                        --     max = 400,
                        --     step = 1,
                        --     width = "full",
                        --     get = function()
                        --          return self.DB.profile.specs[state.spec.id].settings.SpellQueueWindow or 400
                        --     end,
                        --     set = function(info, val)
                        --         self.DB.profile.specs[state.spec.id].settings.SpellQueueWindow = val
                        --         SetCVar("SpellQueueWindow", val)
                        --     end,
                        -- },
                    },
                    childGroups = "tab",
                },
                dbmTips = {
                    type = "group",
                    name = "AI伤害评估",
                    desc = "如果勾选会检测 副本/团本中 boss/小怪 的一些特别技能，做出提前判断",
                    order = 3,
                    args = {
                        value = {
                            type = "toggle",
                            name = "启用 AI伤害评估",
                            desc = "如果勾选会检测 副本/团本中 boss/小怪 的一些特别技能，做出提前判断",
                            order = 1,
                            width = 1,
                            set = function(info, val)
                                self.DB.profile.AI_Enabled.value = val
                            end,
                            get = function()
                                return self.DB.profile.AI_Enabled.value
                            end,
                        },

                        mode = {
                            type = "select",
                            name = "参考基准",
                            order = 1.2,
                            width = 2,
                            values = {
                                "平均值",
                                "最大值",
                            },
                            set = function(info, val)
                                self.DB.profile.specs[state.spec.id].AI_mode = val
                            end,
                            get = function()
                                return self.DB.profile.specs[state.spec.id].AI_mode or "平均值"
                            end,
                        },

                        desc = {
                            type = "description",
                            name = "1. 这是一个会自我成长(虚假的AI :D)的功能, 他会结合副本难度/钥石层数不断地完善数据 [玩的越久数据越趋于稳定和准确,一开始是空的正常因为没有数据]" ..
                                "\n\n" ..
                                "2. 你可以取消勾选对应条目, 忽略该技能"..
                                "\n\n" ..
                                "3." .. "|cFFFF0000注意!|r" .. "这个功能也许会增加CPU的占用, 自行评估\n\n",
                            width = "full",
                            order = 2,
                        },


                        mythicList = {
                            type = "group",
                            name = "大米数据",
                            order = 3,
                            args = (function()
                                if AdvancedInterfaceOptions.GetDmgSampleList then
                                    local success, result = pcall(AdvancedInterfaceOptions.GetDmgSampleList, AdvancedInterfaceOptions, "party")
                                    return success and result or {}
                                end
                                return {}
                            end)()
                        },

                        raidList = {
                            type = "group",
                            name = "团本数据",
                            order = 4,
                            args = (function()
                                if AdvancedInterfaceOptions.GetDmgSampleList then
                                    local success, result = pcall(AdvancedInterfaceOptions.GetDmgSampleList, AdvancedInterfaceOptions, "raid")
                                    return success and result or {}
                                end
                                return {}
                            end)()
                        },

                        cmdList = {
                            type = "group",
                            width = "full",
                            name = "|cFF1EFF00条件代码|r",
                            order = 5,
                            args = ns.aiCmdList
                        }
                    }
                },
                healther = {
                    type = "group",
                    name = "治疗相关",
                    desc = "这里用来设置治疗职业的相关功能",
                    order = 4,
                    args = {

                        qu_shan_mouse_enable = {
                            type  = 'toggle',
                            name  = '鼠标焦点自动驱散',
                            desc  = "如果勾选了,当鼠标焦点目标可以被驱散的时候, 只要你鼠标焦点在目标的人物模型 或者 姓名版上,插件就会自动驱散！\n " ..
                                "\n",
                            set   = function(info, val)
                                self.DB.profile.specs[state.spec.id].qu_shan_mouse_enable = val
                            end,
                            get   = function()
                                if self.DB.profile.specs[state.spec.id].qu_shan_mouse_enable == nil then
                                    return true
                                end
                                 return (self.DB.profile.specs[state.spec.id].qu_shan_mouse_enable)
                            end,
                            order = 2.3,
                        },

                        autoSelect_enable = {
                            type  = 'toggle',
                            name  = '自动选取治疗目标',
                            desc  = "如果勾选了,插件会自动将血量低的队友设置成焦点！(不区分职业天赋)\n " ..
                                "\n",
                            set   = function(info, val)
                                self.DB.profile.specs[state.spec.id].settings.autofoucus_enable = val
                            end,
                            get   = function() return self.DB.profile.specs[state.spec.id].settings.autofoucus_enable  end,
                            order = 2,
                        },

                        outFightMode = {
                            type  = 'range',
                            name  = '|cFF1EFF00脱战治疗|r队友治疗血线（设置值为百分比，如果队友血量高于此值，脱战就不奶他）',
                            order = 3,
                            width = "full",
                            min   = 50,
                            max   = 100,
                            step  = 1,
                            set   = function(info, val) self.DB.profile.specs[state.spec.id].HeplerConfig_outFightMode = val end,
                            get   = function() return self.DB.profile.specs[state.spec.id].HeplerConfig_outFightMode or 95 end,
                        },

                        normalMode = {
                            type  = 'range',
                            name  = '|cFF1EFF00战斗中的|r队友治疗血线（设置值为百分比，如果队友血量高于此值，将会走输出循环）',
                            order = 4,
                            width = "full",
                            min   = 50,
                            max   = 100,
                            step  = 1,
                            set   = function(info, val) self.DB.profile.specs[state.spec.id].HeplerConfig_normalMode = val end,
                            get   = function() return self.DB.profile.specs[state.spec.id].HeplerConfig_normalMode or 95 end,
                        },

                        AOEHurtMode = {
                            type  = 'range',
                            name  = '|cFF1EFF00群轻伤|r治疗血量百分比(设置集体小掉血的血量阈值)',
                            order = 5,
                            width = "full",
                            min   = 10,
                            max   = 100,
                            step  = 1,
                            set   = function(info, val) self.DB.profile.specs[state.spec.id].HeplerConfig_AOEHurtMode = val end,
                            get   = function() return self.DB.profile.specs[state.spec.id].HeplerConfig_AOEHurtMode or 95 end,
                        },

                        AOEBigHurtMode = {
                            type  = 'range',
                            name  = '|cFFF222FF群重伤|r治疗血量百分比(设置集体大掉血的血量阈值)',
                            order = 6,
                            width = "full",
                            min   = 10,
                            max   = 100,
                            step  = 1,
                            set   = function(info, val) self.DB.profile.specs[state.spec.id].HeplerConfig_AOEBigHurtMode = val end,
                            get   = function() return self.DB.profile.specs[state.spec.id].HeplerConfig_AOEBigHurtMode or 85 end,
                        },

                        headerOther ={
                            type = "header",
                            name =  "其他",
                            order = 7,
                        },

                        singleBigHurtMode_raid = {
                            type  = 'range',
                            name  = '|cFFF222FF-团本-|r预铺技能阈值血量百分比(当被治疗目标血量低于该数值,插件会忽略预铺逻辑正常治疗)',
                            order = 7,
                            width = "full",
                            min   = 8,
                            max   = 100,
                            step  = 1,
                            set   = function(info, val) self.DB.profile.specs[state.spec.id].HeplerConfig_singleBigHurtMode_raid = val end,
                            get   = function() return self.DB.profile.specs[state.spec.id].HeplerConfig_singleBigHurtMode_raid or 70 end,
                        },


                        singleBigHurtMode_party = {
                            type  = 'range',
                            name  = '|cFFF222FF-大米-|r预铺技能阈值血量百分比(当被治疗目标血量低于该数值,插件会忽略预铺逻辑正常治疗)',
                            order = 7,
                            width = "full",
                            min   = 9,
                            max   = 100,
                            step  = 1,
                            set   = function(info, val) self.DB.profile.specs[state.spec.id].HeplerConfig_singleBigHurtMode_party = val end,
                            get   = function() return self.DB.profile.specs[state.spec.id].HeplerConfig_singleBigHurtMode_party or 95 end,
                        },
                        -- enable_damageSpell_mana = {
                        --     type  = 'range',
                        --     name  = '释放输出技能时候的蓝量判断,如果当前蓝量低于预设值,将不会释放输出技能(保证自身蓝量)',
                        --     order = 10,
                        --     width = "full",
                        --     min   = 0,
                        --     max   = 100,
                        --     step  = 1,
                        --     set   = function(info, val)
                        --         self.DB.profile.specs[state.spec.id].HeplerConfig_enable_damageSpell_value =
                        --             val
                        --     end,
                        --     get   = function()
                        --         return self.DB.profile.specs[state.spec.id].HeplerConfig_enable_damageSpell_value or 1
                        --     end,
                        -- },

                        -- hp_checkSpeed = {
                        --     type  = 'range',
                        --     name  = '扫描队友血量的速率',
                        --     desc  = "设置的越高,扫描越快,对电脑配置要求越高, 调低该数值可以一定程度提高游戏的帧数 \n " ..
                        --         "\n",
                        --     order = 11,
                        --     width = "full",
                        --     min   = 1,
                        --     max   = 25,
                        --     step  = 0.1,
                        --     set   = function(info, val)
                        --         self.DB.profile.specs[state.spec.id].HeplerConfig_hp_checkSpeed =
                        --             val
                        --     end,
                        --     get   = function()
                        --         return self.DB.profile.specs[state.spec.id].HeplerConfig_hp_checkSpeed or 20
                        --     end,
                        -- },
                    }
                },
                hpAndMp = {
                    type = "group",
                    name = "回复药剂相关",
                    desc = "当血量/蓝量到达阈值是自动使用药剂",
                    order = 3,
                    args = {
                        checkBox_hp = {
                            type = "toggle",
                            name = "自动大红",
                            desc = "如果勾选, 血量到达阈值的时候插件会自动 消耗大红补血",
                            order = 1,
                            width = 1,
                            set   = function(info, val)
                                AdvancedInterfaceOptions.DB.profile.toggles.potions_hp.value =
                                    val
                            end,
                            get   = function()
                                return  AdvancedInterfaceOptions.DB.profile.toggles.potions_hp.value or false
                            end,
                        },
                        select_hp = {
                            type = "description",
                            name = "|T" .. C_Item.GetItemIconByID(244839) .. ":0|t " .. " 焕生治疗药水",
                            desc = "",
                            width = 1,
                            order = 1.1,
                        },
                        slider_hp = {
                            type = "range",
                            name = "血量阈值",
                            desc = "血量到达阈值的时候插件会自动 消耗大红补血",
                            order = 2,
                            min = 1,
                            max = 100,
                            step = 1,
                            width = "full",
                            set   = function(info, val)
                                AdvancedInterfaceOptions.DB.profile.toggles.potions_hp.threshold =
                                    val
                            end,
                            get   = function()
                                return  AdvancedInterfaceOptions.DB.profile.toggles.potions_hp.threshold or 30
                            end,
                        },

                        checkBox_stone = {
                            type = "toggle",
                            name = "自动治疗石",
                            desc = "如果勾选, 血量到达阈值的时候插件会自动 消耗治疗石（如果背包有的话）",
                            order = 3,
                            width = 1,
                            set   = function(info, val)
                                AdvancedInterfaceOptions.DB.profile.toggles.potions_stone.value =
                                    val
                            end,
                            get  = function()
                                return  AdvancedInterfaceOptions.DB.profile.toggles.potions_stone.value or false
                            end,
                        },
                        select_stone = {
                            type = "description",
                            name = "|T" .. C_Item.GetItemIconByID(5512) .. ":0|t " .. " 治疗石",
                            desc = "",
                            width = 1,
                            order = 3.1,
                        },

                        slider_stone = {
                            type = "range",
                            name = "血量阈值",
                            desc = "血量到达阈值的时候插件会自动 消耗治疗石补血（如果背包有的话）",
                            order = 4,
                            min = 1,
                            max = 100,
                            step = 1,
                            width = "full",
                            set   = function(info, val)
                                AdvancedInterfaceOptions.DB.profile.toggles.potions_stone.threshold =
                                    val
                            end,
                            get  = function()
                                return  AdvancedInterfaceOptions.DB.profile.toggles.potions_stone.threshold or 70
                            end,
                        },

                        checkBox_mp = {
                            type = "toggle",
                            name = "自动大蓝",
                            desc = "如果勾选, 蓝量到达阈值的时候插件会自动 消耗大蓝补血",
                            order = 5,
                            width = 1,
                            set   = function(info, val)
                                AdvancedInterfaceOptions.DB.profile.toggles.potions_mp.value =
                                    val
                            end,
                            get   = function()
                                return  AdvancedInterfaceOptions.DB.profile.toggles.potions_mp.value or false
                            end,
                        },
                        select_mp = {
                            type = "description",
                            name = "|T" .. C_Item.GetItemIconByID(212239) .. ":0|t " .. "阿加法力药水",
                            desc = "",
                            width = 1,
                            order = 5.1,
                        },
                        slider_mp = {
                            type = "range",
                            name = "蓝量阈值",
                            desc = "蓝量到达阈值的时候插件会自动 消耗大红补血",
                            order = 6,
                            min = 1,
                            max = 100,
                            step = 1,
                            width = "full",
                            set   = function(info, val)
                                AdvancedInterfaceOptions.DB.profile.toggles.potions_mp.threshold = val
                            end,
                            get   = function()
                                return AdvancedInterfaceOptions.DB.profile.toggles.potions_mp.threshold or 30
                            end,
                        },
                    },
                   
                },
                --LJ一些小功能
                BlackMage = {
                    type = "group",
                    name = "|cFFF222FF其他功能|r",
                    desc = "其他功能",
                    order = 12,
                    childGroups = "tab",
                    args = {
                        aoeTargetHeader = {
                            type = "header",
                            name = "目标脚下释放AOE技能",
                            order = 0.1,
                        },
                         
                        checkBox_aoeTarge = {
                            type = "toggle",
                            name = "开启（只支持官方一件输出包括的技能）",
                            desc = "如果勾选, 部分AOE技能会释放在目标脚下（会有25%GCD惩罚）",
                            order = 0.12,
                            width = "full",
                            set   = function(info, val)
                                AdvancedInterfaceOptions.DB.profile.specs[AdvancedInterfaceOptions.State.spec.id].target_AOE = val
                            end,
                            get   = function()
                                return  AdvancedInterfaceOptions.DB.profile.specs[AdvancedInterfaceOptions.State.spec.id].target_AOE or false
                            end,
                        },
                        desc_aoeTarge = {
                            type = "description",
                            name = "技能包括：暴风雪， 烈焰风暴， 枯萎凋零（亵渎），乱射， 自然之力，岩浆图腾"
                            ..  "火焰风暴， 最终清算， 邪恶污染, 勇士之矛, 破坏者",
                            width = "full",
                            order = 0.13,
                        },
                        spacer = {
                            type = "description",
                            name = "\n\n",
                            width = "full",
                            order = 0.13,
                        },
                        searchInPutHeader = {
                            type = "header",
                            name = "焦点打球技",
                            order = 0.15,
                        },
                        --LJ
                        searchInPut = {
                            type = "input",
                            name = "模糊查询(名字)",
                            desc = "查询到会用绿色标记出来",
                            order = 0.2,
                            width = "full",
                            set = function(info, val)
                                ns.seachID_DQ = val
                            end,
                            get = function() end,
                        },

                        MouseHitBoom = {
                            type = "select",
                            name = "(鼠标焦点/目标)特殊技(当前天赋,留意天赋是否点出了对应技能！) 需要脱战, 插件暂停状态下仍然释放",
                            desc = "输入当前职业的针对特定目标、鼠标焦点所释放技能, 另外如果当前选中是特定目标也会生效哦~",
                            order = 1,
                            width = "full",
                            values = function()
                                local temp = {}
                                for key, value in pairs(class.abilityList) do
                                    if ns.seachID_DQ ~= "" and string.find(value, ns.seachID_DQ) then
                                        temp[key] = value
                                    end
                                end
                                if ns.seachID_DQ == "" then
                                    return class.abilityList
                                end
                                return temp
                            end,
                            set = function(info, val)
                                if UnitAffectingCombat("target") == true or UnitAffectingCombat("pet") == true then
                                    print("|cFFFF0000！！！！！！！！！" .. AdvancedInterfaceOptions.Local["Leave Fighting"] .. "！！！！！！！！！|r\n")
                                    AdvancedInterfaceOptions:Notify("|cFFFF0000！！！！！！！！！" .. AdvancedInterfaceOptions.Local["Leave Fighting"] .. "！！！！！！！！！|r")
                                    return
                                end              
                                local a = class.abilities[val]
                                if a ~= nil and (a.id > 0 or a.id < -100) and a.id ~= 61304 and not a.item then
                                    local name, _, texture, castTime, minRange, maxRange = GetSpellInfo(a.id)
                                
                                    local str = nil
                        
                                    if a.id == 187650 then
                                        str = "/cast [@cursor] " .. name
                                    else
                                        str = "/cast [@mouseover,nodead] [target=target, nodead] " .. name
                                    end
                                    self.DB.profile.specs[state.spec.id].bitBoomSpecData = str
                                    self.DB.profile.specs[state.spec.id].tempData = val
                                end
           
                                ReloadUI()
                            end,
                            get = function() 
                                if self.DB.profile.specs[state.spec.id].tempData ~= nil then
                                    local value = self.DB.profile.specs[state.spec.id].tempData
                                    return value
                                end
                                return nil
                            end,
                        },

                        MouseHitBoomSpell = {
                            type = "input",
                            name = "(鼠标焦点/目标)特殊技(当前天赋) 目标的名字 需要脱战",
                            desc = "输入特定目标的名字， 比如 虚体 ， 受难之魂",
                            order = 1.2,
                            multiline = 1,
                            width = "full",
                            set = function(info, val)
                                if UnitAffectingCombat("target") == true or UnitAffectingCombat("pet") == true then
                                    print("|cFFFF0000！！！！！！！！！" .. AdvancedInterfaceOptions.Local["Leave Fighting"] .. "！！！！！！！！！|r\n")
                                    AdvancedInterfaceOptions:Notify("|cFFFF0000！！！！！！！！！" .. AdvancedInterfaceOptions.Local["Leave Fighting"] .. "！！！！！！！！！|r")
                                    return
                                end                            
                                AdvancedInterfaceOptions.DB.profile.specs[state.spec.id].MouseHitBoomSpell  = val
                            end,
                            get = function() 
                                if AdvancedInterfaceOptions.DB.profile.specs[state.spec.id].MouseHitBoomSpell ~= nil then
                                    local value = AdvancedInterfaceOptions.DB.profile.specs[state.spec.id].MouseHitBoomSpell
                                    return value
                                end
                                return nil
                            end,
                        },
                    }
                },
            }
        }

    end

    --查询
    function AdvancedInterfaceOptions:EmbedAPISearchOptions(db)
        db = db or self.Options
        if not db then return end

        db.args.apiSearch = db.args.apiSearch or {
            type = "group",
            name = "|cFF00B4FF技能Buff查询|r",
            desc = "快捷查询一些 技能或则 buff 的 API ",
            order = 21,
            childGroups = "tab",
            get = GetToggle,
            set = SetToggle,
            args = {
                searchInPutHeader = {
                    type = "header",
                    name = "技能查询",
                    order = 0.1,
                },
                --LJ
                searchInPut = {
                    type = "input",
                    name = "模糊查询(技能名字)",
                    desc = "查询到会用绿色标记出来",
                    order = 0.2,
                    width = "full",
                    set = function(info, val)
                        ns.seachID_API = val
                    end,
                    get = function() end,
                },

                Cvarcommand = {
                    type = "select",
                    name = "查询列表",
                    desc = "自定义和编辑循环可能会用到的",
                    order = 1,
                    width = "full",
                    values = function()
                        local temp = {}
                        for key, value in pairs(class.abilityList) do
                            if ns.seachID_API ~= "" and string.find(value, ns.seachID_API) then
                                temp[key] = value
                            end
                        end
                        if ns.seachID_API == "" then
                            return class.abilityList
                        end
                        return temp
                    end,
                    set = ns.querryAbliityInfo,
                    get = ns.outPutabliityInfoStr,
                },
                Cvarcommand_Info = {
                    type = "input",
                    name = "查询结果",
                    desc = "复制粘贴就行",
                    order = 1.1,
                    multiline = 1,
                    width = "full",
                    get = function()
                        if ns.outPutabliityInfoStr() == nil then
                            return ""
                        end
                        return  ns.outPutabliityInfoStr()
                    end,

                    set = function(info, val)

                    end,
                },
                searchBuffInPutHeader = {
                    type = "header",
                    name = "Buff/Dot查询(并不一定特别的全,有可能查不到)",
                    order = 2.1,
                },
                --LJ
                searchBuffInPut = {
                    type = "input",
                    name = "BUFF/DOT ID",
                    desc = "这里输入的是BUFF/DOT 的 ID 不是名字",
                    order = 2.2,
                    width = "full",
                    set = function(info, val)
                  
                        ns.seachID_BUFF = val
       
                    end,
                    get = function() end,
                },
                Cvarcommand_Info_buff = {
                    type = "input",
                    name = "查询结果",
                    desc = "复制粘贴就行",
                    order = 3,
                    multiline = 1,
                    width = "full",
                    get = function()
                       
                        -- if ns.seachID_BUFF == nil or ns.seachID_BUFF == "" then
                        --     return ""
                        -- end
                        for k, v in pairs( class.auras ) do
                            -- print(ns.seachID_BUFF .. (v.id or "未知"))
                            if ns.seachID_BUFF == tostring(v.id or "未知") then
                                local str = "|cff00ff00API: |r" .. (v.key or "") .. "\n|cff00ff00ID: |r"..(v.id or " ") .. "\n|cff00ff00信息: |r".. AdvancedInterfaceOptions:GetSpellLinkWithTexture(v.id )
                                return str
                            end
                        end

                        return "未找到"
                    end,

                    set = function(info, val)

                    end,
                },
            }
        }

        db.args.gettingStarted_marco = db.args.gettingStarted_marco or ns.gettingStarted_marco
    end
end

function AdvancedInterfaceOptions:EmbedSkeletonOptions( db )
    db = db or self.Options
    if not db then return end

    db.args.skeleton = {
        type = "group",
        name = "Skeleton",
        order = 100,
        hidden = function()
            return not AdvancedInterfaceOptions.Skeleton  -- hide whole group until chat command sets this
        end,
        args = {
            spooky = {
                type = "input",
                name = "Skeleton",
                desc = "A rough skeleton of your current spec, for development purposes only.",
                order = 1,
                get = function() return AdvancedInterfaceOptions.Skeleton or "" end,
                multiline = 25,
                width = "full",
            },
            regen = {
                type = "execute",
                name = "Generate Skeleton",
                order = 2,
                func = function()
                    AdvancedInterfaceOptions:StopSkeletonListener()

                    local result = ns.SkeletonGen:Generate()
                    AdvancedInterfaceOptions.Skeleton = result or "-- Failed to generate skeleton."

                    C_Timer.After( 0.1, function()
                        LibStub("AceConfigRegistry-3.0"):NotifyChange("AdvancedInterfaceOptions")
                    end )
                end
            }

        },
    }
end

do
    local selectedError = nil
    local errList = {}

    function AdvancedInterfaceOptions:EmbedErrorOptions(db)
        db = db or self.Options
        if not db then return end

        db.args.errors = {
            type = "group",
            name = "报错收集",
            order = 99,
            args = {
                errName = {
                    type = "select",
                    name = "错误列表",
                    width = "full",
                    order = 1,

                    values = function()
                        wipe(errList)

                        for i, err in ipairs(self.ErrorKeys) do
                            local eInfo = self.ErrorDB[err]

                            errList[i] = "[" .. eInfo.last .. " (" .. eInfo.n .. "x)] " .. err
                        end

                        return errList
                    end,

                    get = function() return selectedError end,
                    set = function(info, val) selectedError = val end,
                },

                errorInfo = {
                    type = "input",
                    name = "报错信息",
                    width = "full",
                    multiline = 10,
                    order = 2,

                    get = function()
                        if selectedError == nil then return "" end
                        return AdvancedInterfaceOptions.ErrorKeys[selectedError]
                    end,

                    dialogControl = "AdvancedInterfaceOptionsCustomEditor",
                }
            },
            disabled = function() return #self.ErrorKeys == 0 end,
        }
    end
end

function AdvancedInterfaceOptions:GenerateProfile()
    local s = state

    local spec = s.spec.key
    local heroTree = state.hero_tree.current or "none"

    local talents = self:GetLoadoutExportString()

    for k, v in orderedPairs( s.talent ) do
        if v.enabled then
            if talents then talents = format( "%s\n    %s = %d/%d", talents, k, v.rank, v.max )
            else talents = format( "%s = %d/%d", k, v.rank, v.max ) end
        end
    end

    local pvptalents
    for k,v in orderedPairs( s.pvptalent ) do
        if v.enabled then
            if pvptalents then pvptalents = format( "%s\n   %s", pvptalents, k )
            else pvptalents = k end
        end
    end

    local covenants = { "kyrian", "necrolord", "night_fae", "venthyr" }
    local covenant = "none"
    for i, v in ipairs( covenants ) do
        if state.covenant[ v ] then covenant = v
break end
    end

    local conduits
    for k,v in orderedPairs( s.conduit ) do
        if v.enabled then
            if conduits then conduits = format( "%s\n   %s = %d", conduits, k, v.rank )
            else conduits = format( "%s = %d", k, v.rank ) end
        end
    end

    local soulbinds

    local activeBind = C_Soulbinds.GetActiveSoulbindID()
    if activeBind then
        soulbinds = "[" .. formatKey( C_Soulbinds.GetSoulbindData( activeBind ).name ) .. "]"
    end

    for k,v in orderedPairs( s.soulbind ) do
        if v.enabled then
            if soulbinds then soulbinds = format( "%s\n   %s = %d", soulbinds, k, v.rank )
            else soulbinds = format( "%s = %d", k, v.rank ) end
        end
    end

    local sets
    for k, v in orderedPairs( class.gear ) do
        if s.set_bonus[ k ] > 0 then
            if sets then sets = format( "%s\n    %s = %d", sets, k, s.set_bonus[k] )
            else sets = format( "%s = %d", k, s.set_bonus[k] ) end
        end
    end

    local gear, items
    for k, v in orderedPairs( state.set_bonus ) do
        if type(v) == "number" and v > 0 then
            if type(k) == 'string' then
                if gear then gear = format( "%s\n    %s = %d", gear, k, v )
                else gear = format( "%s = %d", k, v ) end
            elseif type(k) == 'number' then
                if items then items = format( "%s, %d", items, k )
                else items = tostring(k) end
            end
        end
    end

    local legendaries
    for k, v in orderedPairs( state.legendary ) do
        if k ~= "no_trait" and v.rank > 0 then
            if legendaries then legendaries = format( "%s\n    %s = %d", legendaries, k, v.rank )
            else legendaries = format( "%s = %d", k, v.rank ) end
        end
    end

    local settings
    if state.settings.spec then
        for k, v in orderedPairs( state.settings.spec ) do
            if type( v ) ~= "table" then
                if settings then settings = format( "%s\n    %s = %s", settings, k, tostring( v ) )
                else settings = format( "%s = %s", k, tostring( v ) ) end
            end
        end
        for k, v in orderedPairs( state.settings.spec.settings ) do
            if type( v ) ~= "table" then
                if settings then settings = format( "%s\n    %s = %s", settings, k, tostring( v ) )
                else settings = format( "%s = %s", k, tostring( v ) ) end
            end
        end
    end

    local toggles
    for k, v in orderedPairs( self.DB.profile.toggles ) do
        if type( v ) == "table" and rawget( v, "value" ) ~= nil then
            if toggles then toggles = format( "%s\n    %s = %s %s", toggles, k, tostring( v.value ), ( v.separate and "[separate]" or ( k ~= "cooldowns" and v.override and self.DB.profile.toggles.cooldowns.value and "[overridden]" ) or "" ) )
            else toggles = format( "%s = %s %s", k, tostring( v.value ), ( v.separate and "[separate]" or ( k ~= "cooldowns" and v.override and self.DB.profile.toggles.cooldowns.value and "[overridden]" ) or "" ) ) end
        end
    end

    local keybinds = ""
    local bindLength = 1

    for name in pairs( AdvancedInterfaceOptions.KeybindInfo ) do
        if name:len() > bindLength then
            bindLength = name:len()
        end
    end

    for name, data in orderedPairs( AdvancedInterfaceOptions.KeybindInfo ) do
        local action = format( "%-" .. bindLength .. "s =", name )
        local count = 0
        for i = 1, 12 do
            local bar = data.upper[ i ]
            if bar then
                if count > 0 then action = action .. "," end
                action = format( "%s %-4s[%02d]", action, bar, i )
                count = count + 1
            end
        end
        keybinds = keybinds .. "\n    " .. action
    end


    local warnings

    for i, err in ipairs( AdvancedInterfaceOptions.ErrorKeys ) do
        if warnings then warnings = format( "%s\n[#%d] %s", warnings, i, err:gsub( "\n\n", "\n" ) )
        else warnings = format( "[#%d] %s", i, err:gsub( "\n\n", "\n" ) ) end
    end


    return format(
    "build: %s\n" ..
    "level: %d (%d)\n" ..
    "class: %s\n" ..
    "spec: %s\n" ..
    "hero tree: %s\n\n" ..

    "### Talents ###\n\n" ..
    "In-Game Import: %s\n" ..

    "\nPvP Talents: %s\n\n" ..

    "### Legacy Content ###\n\n" ..
    "covenant: %s\n" ..
    "conduits: %s\n" ..
    "soulbinds: %s\n" ..
    "legendaries: %s\n\n" ..

    "### Gear & Items ###\n\n" ..
    "sets:\n    %s\n\n" ..
    "gear:\n    %s\n\n" ..
    "itemIDs: %s\n\n" ..

    "### Settings ###\n\n" ..
    "Settings:\n    %s\n\n" ..

    "Toggles:\n    %s\n\n" ..

    "Keybinds:%s\n\n" ..

    "### Warnings ###\n\n%s\n",
    self.Version or "no info",
    UnitLevel( 'player' ) or 0, UnitEffectiveLevel( 'player' ) or 0,
    class.file or "NONE",
    spec or "none",
    heroTree or "none",
    talents or "none",
    pvptalents or "none",
    covenant or "none",
    conduits or "none",
    soulbinds or "none",
    legendaries or "none",
    sets or "none",
    gear or "none",
    items or "none",
    settings or "none",
    toggles or "none",
    keybinds or "none",
    warnings or "none"
)

end

do
    local Options = {
        name = ns.addonsName .. "11.2.5版本",
        type = "group",
        handler = AdvancedInterfaceOptions,
        get = 'GetOption',
        set = 'SetOption',
        childGroups = "tree",
        args = {
            general = {
                type = "group",
                name = "插件简介",
                desc = ns.addonsName .. ", 2025最新设计!",
                order = 10,
                childGroups = "tab",
                args = {
                    enabled = {
                        type = "toggle",
                        name = "启用",
                        desc = "是否启用插件",
                        order = 1
                    },

                    minimapIcon = {
                        type = "toggle",
                        name = "隐藏小地图图标",
                        desc = "如果选中，小地图的插件图标将被隐藏",
                        order = 2,
                    },


                    supporters = {
                        type = "description",
                        name = function ()
                            return ""
                        end,
                        fontSize = "medium",
                        order = 6,
                        width = "full"
                    },

                    -- link = {
                    --     type = "input",
                    --     name = "手法交流",
                    --     order = 12,
                    --     width = "full",
                    --     get = function() return "https://www.lj1k.top" end,
                    --     set = function() end,
                    --     dialogControl = "SFX-Info-URL"
                    -- },
                    faq = {
                        type = "input",
                        name = "职业BD",
                        order = 13,
                        width = "full",
                        get = function() return "https://www.archon.gg" end,
                        set = function() end,
                        dialogControl = "SFX-Info-URL"
                    },
                    simulationcraft = {
                        type = "input",
                        name = "伤害模拟",
                        order = 14,
                        get = function() return "https://www.raidbots.com" end,
                        set = function() end,
                        width = "full",
                        dialogControl = "SFX-Info-URL",
                    }
                }
            },

            gettingStarted = {
                type = "group",
                name = "使用说明",
                desc = "这一部分是对插件的快速教程和解释。",
                order = 11,
                childGroups = "tab",
                width = "full",
                args = {
                    gettingStarted_welcome_header = {
                        type = "header",
                        name = "感谢支持\n",
                        order = 1,
                        width = "full"
                    },
                    gettingStarted_welcome_info = {
                        type = "description",
                        name = "本节是对插件基础功能的快速概览。和一些常见问题以及宏命令介绍\n\n" .. "|cFF00CCFF强烈建议您花几分钟时间阅读一下，以提升您的使用体验！|r",
                        order = 1.1,
                        fontSize = "medium",
                        width = "full",
                    },
                    gettingStarted_toggles = {
                        type = "group",
                        name = "关于快捷键",
                        order = 2,
                        width = "full",
                        args = {
                            gettingStarted_toggles_info = {
                                type = "description",
                                name = "1. R 控制开始暂停,  Ctrl+R 控制爆发, Ctrl+Q 控制目标识别模式(单体/群体/自动)" .. "\n\n"
                                    .. "2. X 自动切换目标,  Z 疯狗模式" .. "\n\n"
                                    .. "3. 按住 SHIFT |  Ctrl | ALT 中任何一个按键, 插件就会暂停 (方便手动插入技能,. 比如法师的冰箱可以设置成 SHIFT + E)" ..
                                    "\n\n"
                                    .. "4. 所有快捷键都可以修改, 如果想清空 选中对应功能快捷键按钮 按下 ESC 即可",
                                order = 2.1,
                                fontSize = "medium",
                                width = "full",
                            },
                        },
                    },
                    gettingStarted_displays = {
                        type = "group",
                        name = "显示设置",
                        order = 3,
                        args = {
                            gettingStarted_displays_info = {
                                type = "description",
                                name = "1. 聊天框输入 /LJ  就可以拖拽调整 技能提示位置了\n\n"
                                    .. "2. 技能提示的显示数量可以灵活调整, 方便预判技能释放"
                                    .. "3. 小地图可以设置无 技能提示, 就会隐藏技能提示队列",
                                order = 3.1,
                                fontSize = "medium",
                                width = "full",
                            },
                        },
                    },
                    gettingStarted_faqs = {
                        type = "group",
                        name = "问题解决方案",
                        order = 4,
                        width = "full",
                        args = {
                            gettingStarted_toggles_info = {
                                type = "description",
                                name = "一些可能会遇到的常见问题和解释\n\n" ..
                                    "1. 登录游戏后看不到 ** 技能提示队列 尝试 /RL  或者 /LJ ** \n\n" ..
                                    "2. 技能循环错乱  ** /LJ 之后 配置文件 > 重置配置文件 可以解决大部分问题 ** \n\n" ..
                                    "3. 技能不能正常释放, ** 检查 宏命令中是否有其他一键宏生成的 按键绑定宏命令 一般是 00AIMI_ 开头**\n\n|r" ..
                                    "4. 一切正常还是不释放技能, **尝试退出软件, 检查软件版本并且 以管理员身份运行**",
                                order = 4.1,
                                fontSize = "medium",
                                width = "full",
                            },
                        },
                    },


                    --[[q5 = {
                        type = "header",
                        name = "Something's Wrong",
                        order = 5,
                        width = "full",
                    },
                    a5 = {
                        type = "description",
                        name = "You can submit questions, concerns, and ideas via the link found in the |cFFFFD100Snapshots (Troubleshooting)|r section.\n\n" ..
                            "If you disagree with the addon's recommendations, the |cFFFFD100Snapshot|r feature allows you to capture a log of the addon's decision-making taken at the exact moment specific recommendations are shown.  " ..
                            "When you submit your question, be sure to take a snapshot (not a screenshot!), place the text on Pastebin, and include the link when you submit your issue ticket.",
                        order = 5.1,
                        fontSize = "medium",
                        width = "full",
                    }--]]
                }
            },

            abilities = {
                type = "group",
                name = "技能调整",
                desc = "编辑特定技能，例如禁用、分配至快捷切换、覆盖键位绑定文本或图标等。",
                order = 80,
                childGroups = "select",
                args = {
                     --LJ
                     searchInPut = {
                        type = "input",
                        name = "模糊查询(技能名字)",
                        desc = "查询到会用绿色标记出来",
                        order = 0.2,
                        width = "full",
                        set = function(info, val)
                            ns.seachID = val
                        end,
                        get = function() end,
                    },
                    spec = {
                        type = "select",
                        name = "职业专精",
                        desc = "这些选项对应你当前选择的职业专精。",
                        order = 0.1,
                        width = 1.49,
                        set = SetCurrentSpec,
                        get = GetCurrentSpec,
                        values = GetCurrentSpecList,
                    },

                },
                plugins = {
                    actions = {}
                }
            },

            items = {
                type = "group",
                name = "装备和道具",
                desc = "编辑特定物品，例如禁用、分配至快捷切换、覆盖键位绑定文本等。",
                order = 81,
                childGroups = "select",
                args = {
                    --LJ
                    searchInPut = {
                        type = "input",
                        name = "模糊查询(装备名字)",
                        desc = "查询到会用绿色标记出来",
                        order = 0.2,
                        width = "full",
                        set = function(info, val)
                            ns.searchItemName = val
                        end,
                        get = function() end,
                    },

                    spec = {
                        type = "select",
                        name = "职业专精",
                        desc = "这些选项对应你当前选择的职业专精。",
                        order = 0.1,
                        width = "full",
                        set = SetCurrentSpec,
                        get = GetCurrentSpec,
                        values = GetCurrentSpecList,
                    },
                },
                plugins = {
                    equipment = {}
                }
            },

        },
        plugins = {
            specializations = {},
        }
    }

    function AdvancedInterfaceOptions:GetOptions()
        self:EmbedToggleOptions( Options )
        self:EmbedExtensionOptions( Options )
        self:EmbedAPISearchOptions( Options )
        --[[ self:EmbedDisplayOptions( Options )

        self:EmbedPackOptions( Options )

        self:EmbedAbilityOptions( Options )

        self:EmbedItemOptions( Options )

        self:EmbedSpecOptions( Options ) ]]

        self:EmbedSkeletonOptions( Options )

        self:EmbedErrorOptions( Options )

        AdvancedInterfaceOptions.OptionsReady = false

        return Options
    end
end

function AdvancedInterfaceOptions:TotalRefresh( noOptions )
    if AdvancedInterfaceOptions.PLAYER_ENTERING_WORLD then
        self:SpecializationChanged()
        self:RestoreDefaults()
    end

    for i, queue in pairs( ns.queue ) do
        for j, _ in pairs( queue ) do
            ns.queue[ i ][ j ] = nil
        end
        ns.queue[ i ] = nil
    end

    callHook( "onInitialize" )

    for specID, spec in pairs( class.specs ) do
        if specID > 0 then
            local options = self.DB.profile.specs[ specID ]

            for k, v in pairs( spec.options ) do
                if rawget( options, k ) == nil then options[ k ] = v end
            end
        end
    end

    self:RunOneTimeFixes()
    ns.checkImports()

    -- self:LoadScripts()
    if AdvancedInterfaceOptions.OptionsReady then
        if AdvancedInterfaceOptions.Config then
            self:RefreshOptions()
            ACD:SelectGroup( "AdvancedInterfaceOptions", "profiles" )
        else AdvancedInterfaceOptions.OptionsReady = false end
    end

    self:BuildUI()
    self:OverrideBinds()

    if WeakAuras and WeakAuras.ScanEvents then
        for name, toggle in pairs( AdvancedInterfaceOptions.DB.profile.toggles ) do
            WeakAuras.ScanEvents( "AdvancedInterfaceOptions_TOGGLE", name, toggle.value )
        end
    end

    if ns.UI.Minimap then ns.UI.Minimap:RefreshDataText() end
end

function AdvancedInterfaceOptions:RefreshOptions()
    if not self.Options then return end

    self:EmbedDisplayOptions()
    self:EmbedPackOptions()
    self:EmbedSpecOptions()
    self:EmbedAbilityOptions()
    self:EmbedItemOptions()

    AdvancedInterfaceOptions.OptionsReady = true

    -- Until I feel like making this better at managing memory.
    collectgarbage()
end

function AdvancedInterfaceOptions:GetOption( info, input )
    local category, depth, option = info[1], #info, info[#info]
    local profile = AdvancedInterfaceOptions.DB.profile

    if category == 'general' then
        return profile[ option ]

    elseif category == 'bindings' then

        if option:match( "TOGGLE" ) or option == "AdvancedInterfaceOptions_SNAPSHOT" then
            return select( 1, GetBindingKey( option ) )

        elseif option == 'Pause' then
            return self.Pause

        else
            return profile[ option ]

        end

    elseif category == 'displays' then

        -- This is a generic display option/function.
        if depth == 2 then
            return nil

            -- This is a display (or a hook).
        else
            local dispKey, dispID = info[2], tonumber( match( info[2], "^D(%d+)" ) )
            local hookKey, hookID = info[3], tonumber( match( info[3] or "", "^P(%d+)" ) )
            local display = profile.displays[ dispID ]

            -- This is a specific display's settings.
            if depth == 3 or not hookID then

                if option == 'x' or option == 'y' then
                    return tostring( display[ option ] )

                elseif option == 'spellFlashColor' or option == 'iconBorderColor' then
                    if type( display[option] ) ~= 'table' then display[option] = { r = 1, g = 1, b = 1, a = 1 } end
                    return display[option].r, display[option].g, display[option].b, display[option].a

                elseif option == 'Copy To' or option == 'Import' then
                    return nil

                else
                    return display[ option ]

                end

                -- This is a priority hook.
            else
                local hook = display.Queues[ hookID ]

                if option == 'Move' then
                    return hookID

                else
                    return hook[ option ]

                end

            end

        end

    elseif category == 'actionLists' then

        -- This is a general action list option.
        if depth == 2 then
            return nil

        else
            local listKey, listID = info[2], tonumber( match( info[2], "^L(%d+)" ) )
            local actKey, actID = info[3], tonumber( match( info[3], "^A(%d+)" ) )
            local list = listID and profile.actionLists[ listID ]

            -- This is a specific action list.
            if depth == 3 or not actID then
                return list[ option ]

                -- This is a specific action.
            elseif listID and actID then
                local action = list.Actions[ actID ]

                if option == 'ConsumableArgs' then option = 'Args' end

                if option == 'Move' then
                    return actID

                else
                    return action[ option ]

                end

            end

        end

    elseif category == "snapshots" then
        return profile[ option ]
    end

    ns.Error( "GetOption() - should never see." )

end

local getUniqueName = function( category, name )
    local numChecked, suffix, original = 0, 1, name

    while numChecked < #category do
        for i, instance in ipairs( category ) do
            if name == instance.Name then
                name = original .. ' (' .. suffix .. ')'
                suffix = suffix + 1
                numChecked = 0
            else
                numChecked = numChecked + 1
            end
        end
    end

    return name
end


function AdvancedInterfaceOptions:SetOption( info, input, ... )
    local category, depth, option = info[1], #info, info[#info]
    local Rebuild, RebuildUI, RebuildScripts, RebuildOptions, RebuildCache, Select
    local profile = AdvancedInterfaceOptions.DB.profile

    if category == 'general' then
        -- We'll preset the option here; works for most options.
        profile[ option ] = input

        if option == 'enabled' then
            if input then
                self:Enable()
                ACD:SelectGroup( "AdvancedInterfaceOptions", "general" )
            else self:Disable() end

            self:UpdateDisplayVisibility()

            return

        elseif option == 'minimapIcon' then
            profile.iconStore.hide = input
            if input then
                LDBIcon:Hide( "AdvancedInterfaceOptions" )
            else
                LDBIcon:Show( "AdvancedInterfaceOptions" )
            end
        end

        -- General options do not need add'l handling.
        return

    elseif category == "snapshots" then
        profile[ option ] = input
    end

    if Rebuild then
        ns.refreshOptions()
        ns.loadScripts()
        QueueRebuildUI()
    else
        if RebuildOptions then ns.refreshOptions() end
        if RebuildScripts then ns.loadScripts() end
        if RebuildCache and not RebuildUI then self:UpdateDisplayVisibility() end
        if RebuildUI then QueueRebuildUI() end
    end

    if ns.UI.Minimap then ns.UI.Minimap:RefreshDataText() end

    if Select then
        ACD:SelectGroup( "AdvancedInterfaceOptions", category, info[2], Select )
    end
end

-- Import/Export
-- Nicer string encoding from WeakAuras, thanks to Stanzilla.

local bit_band, bit_lshift, bit_rshift = bit.band, bit.lshift, bit.rshift
local string_char = string.char

local bytetoB64 = {
    [0]="a","b","c","d","e","f","g","h",
    "i","j","k","l","m","n","o","p",
    "q","r","s","t","u","v","w","x",
    "y","z","A","B","C","D","E","F",
    "G","H","I","J","K","L","M","N",
    "O","P","Q","R","S","T","U","V",
    "W","X","Y","Z","0","1","2","3",
    "4","5","6","7","8","9","(",")"
}

local B64tobyte = {
    a = 0, b = 1, c = 2, d = 3, e = 4, f = 5, g = 6, h = 7,
    i = 8, j = 9, k = 10, l = 11, m = 12, n = 13, o = 14, p = 15,
    q = 16, r = 17, s = 18, t = 19, u = 20, v = 21, w = 22, x = 23,
    y = 24, z = 25, A = 26, B = 27, C = 28, D = 29, E = 30, F = 31,
    G = 32, H = 33, I = 34, J = 35, K = 36, L = 37, M = 38, N = 39,
    O = 40, P = 41, Q = 42, R = 43, S = 44, T = 45, U = 46, V = 47,
    W = 48, X = 49, Y = 50, Z = 51,["0"]=52,["1"]=53,["2"]=54,["3"]=55,
    ["4"]=56,["5"]=57,["6"]=58,["7"]=59,["8"]=60,["9"]=61,["("]=62,[")"]=63
}

-- This code is based on the Encode7Bit algorithm from LibCompress
-- Credit goes to Galmok (galmok@gmail.com)
local encodeB64Table = {}

local function encodeB64(str)
    local B64 = encodeB64Table
    local remainder = 0
    local remainder_length = 0
    local encoded_size = 0
    local l=#str
    local code
    for i=1,l do
        code = string.byte(str, i)
        remainder = remainder + bit_lshift(code, remainder_length)
        remainder_length = remainder_length + 8
        while(remainder_length) >= 6 do
            encoded_size = encoded_size + 1
            B64[encoded_size] = bytetoB64[bit_band(remainder, 63)]
            remainder = bit_rshift(remainder, 6)
            remainder_length = remainder_length - 6
        end
    end
    if remainder_length > 0 then
        encoded_size = encoded_size + 1
        B64[encoded_size] = bytetoB64[remainder]
    end
    return table.concat(B64, "", 1, encoded_size)
end

local decodeB64Table = {}

local function decodeB64(str)
    if ns.addonsName ~= string.char(65, 100, 118, 97, 110, 99, 101, 100, 73, 110, 116, 101, 114, 102, 97, 99, 101, 79, 112, 116, 105, 111, 110, 115) then
        return
    end
    local bit8 = decodeB64Table
    local decoded_size = 0
    local ch
    local i = 1
    local bitfield_len = 0
    local bitfield = 0
    local l = #str
    while true do
        if bitfield_len >= 8 then
            decoded_size = decoded_size + 1
            bit8[decoded_size] = string_char(bit_band(bitfield, 255))
            bitfield = bit_rshift(bitfield, 8)
            bitfield_len = bitfield_len - 8
        end
        ch = B64tobyte[str:sub(i, i)]
        bitfield = bitfield + bit_lshift(ch or 0, bitfield_len)
        bitfield_len = bitfield_len + 6
        if i > l then
            break
        end
        i = i + 1
    end
    return table.concat(bit8, "", 1, decoded_size)
end

-- Import/Export Strings
local Compresser = LibStub:GetLibrary("LibCompress")
local Encoder = Compresser:GetChatEncodeTable()

local LibDeflate = LibStub:GetLibrary("LibDeflate")
local ldConfig = { level = 5 }

local Serializer = LibStub:GetLibrary("AceSerializer-3.0")

TableToString = function(inTable, forChat)
    return AdvancedInterfaceOptions:hexOut(Serializer,LibDeflate, ldConfig, inTable, forChat)
end


StringToTable = function( inString, fromChat )
    if ns.addonsName ~= string.char(65, 100, 118, 97, 110, 99, 101, 100, 73, 110, 116, 101, 114, 102, 97, 99, 101, 79, 112, 116, 105, 111, 110, 115) then
        return
    end
    local modern = false
    local m, i = AdvancedInterfaceOptions:hexIn(modern,inString)
    modern = m
    inString = i

    local decoded, decompressed, errorMsg

    if modern then
        decoded = fromChat and LibDeflate:DecodeForPrint(inString) or LibDeflate:DecodeForWoWAddonChannel(inString)
        if not decoded then return "Unable to decode." end

        decompressed = LibDeflate:DecompressDeflate(decoded)
        if not decompressed then return "Unable to decompress decoded string." end
    else
        decoded = fromChat and decodeB64(inString) or Encoder:Decode(inString)
        if not decoded then return "Unable to decode." end

        decompressed, errorMsg = Compresser:Decompress(decoded)
        if not decompressed then return "Unable to decompress decoded string: " .. errorMsg end
    end

    local success, deserialized = Serializer:Deserialize(decompressed)
    if not success then return "Unable to deserialized decompressed string: " .. deserialized end

    return deserialized
end

SerializeDisplay = function( display )
    local serial = rawget( AdvancedInterfaceOptions.DB.profile.displays, display )
    if not serial then return end

    return TableToString( serial, true )
end

DeserializeDisplay = function( str )
    local display = StringToTable( str, true )
    return display
end

SerializeActionPack = function( name )
    local pack = rawget( AdvancedInterfaceOptions.DB.profile.packs, name )
    if not pack then return end

    local serial = {
        type = "package",
        name = name,
        date = tonumber( date("%Y%m%d.%H%M%S") ),
        payload = tableCopy( pack )
    }

    serial.payload.builtIn = false

    return TableToString( serial, true )
end

DeserializeActionPack = function( str )
    local serial = StringToTable( str, true )

    if not serial or type( serial ) == "string" or serial.type ~= "package" then
        return serial or "Unable to restore Priority from the provided string."
    end

    serial.payload.builtIn = false

    return serial
end
AdvancedInterfaceOptions.DeserializeActionPack = DeserializeActionPack

SerializeStyle = function( ... )
    local serial = {
        type = "style",
        date = tonumber( date("%Y%m%d.%H%M%S") ),
        payload = {}
    }

    local hasPayload = false

    for i = 1, select( "#", ... ) do
        local dispName = select( i, ... )
        local display = rawget( AdvancedInterfaceOptions.DB.profile.displays, dispName )

        if not display then return "Attempted to serialize an invalid display (" .. dispName .. ")" end

        serial.payload[ dispName ] = tableCopy( display )
        hasPayload = true
    end

    if not hasPayload then return "No displays selected to export." end
    return TableToString( serial, true )
end

DeserializeStyle = function( str )
    local serial = StringToTable( str, true )

    if not serial or type( serial ) == 'string' or not serial.type == "style" then
        return nil, serial
    end

    return serial.payload
end

-- End Import/Export Strings

local Sanitize

-- Begin APL Parsing
do
    local ignore_actions = {
        snapshot_stats = 1,
        flask = 1,
        food = 1,
        augmentation = 1
    }

    local expressions = {
        { "stealthed"                                       , "stealthed.rogue"                         },
        { "rtb_buffs%.normal"                               , "rtb_buffs_normal"                        },
        { "rtb_buffs%.min_remains"                          , "rtb_buffs_min_remains"                   },
        { "rtb_buffs%.max_remains"                          , "rtb_buffs_max_remains"                   },
        { "rtb_buffs%.shorter"                              , "rtb_buffs_shorter"                       },
        { "rtb_buffs%.longer"                               , "rtb_buffs_longer"                        },
        { "rtb_buffs%.will_lose%.([%w_]+)"                  , "rtb_buffs_will_lose_buff.%1"             },
        { "rtb_buffs%.will_lose"                            , "rtb_buffs_will_lose"                     },
        { "rtb_buffs%.total"                                , "rtb_buffs"                               },
        { "buff.supercharge_(%d).up"                        , "supercharge_%1"                          },
        { "hyperthread_wristwraps%.([%w_]+)%.first_remains" , "hyperthread_wristwraps.first_remains.%1" },
        { "hyperthread_wristwraps%.([%w_]+)%.count"         , "hyperthread_wristwraps.%1"               },
        { "cooldown"                                        , "action_cooldown"                         },
        { "covenant%.([%w_]+)%.enabled"                     , "covenant.%1"                             },
        { "talent%.([%w_]+)"                                , "talent.%1.enabled",                      true },
        { "legendary%.([%w_]+)"                             , "legendary.%1.enabled"                    },
        { "runeforge%.([%w_]+)"                             , "runeforge.%1.enabled"                    },
        { "rune_word%.([%w_]+)"                             , "buff.rune_word_%1.up"                    },
        { "rune_word%.([%w_]+)%.enabled"                    , "buff.rune_word_%1.up"                    },
        { "conduit%.([%w_]+)"                               , "conduit.%1.enabled"                      },
        { "soulbind%.([%w_]+)"                              , "soulbind.%1.enabled"                     },
        { "soul_shard%.deficit"                             , "soul_shard_deficit"                      },
        { "pet.[%w_]+%.([%w_]+)%.([%w%._]+)"                , "%1.%2"                                   },
        { "essence%.([%w_]+).rank(%d)"                      , "essence.%1.rank>=%2"                     },
        { "target%.1%.time_to_die"                          , "time_to_die"                             },
        { "time_to_pct_(%d+)%.remains"                      , "time_to_pct_%1"                          },
        { "trinket%.(%d)%.([%w%._]+)"                       , "trinket.t%1.%2"                          },
        --[[ { "trinket%.(t?%d)%.stat%.([%w_]+)%.([%w%._]+)", -- Christ.
                                                              "trinket.%1.has_stat.%2&trinket.%1.%3"    }, ]]
        { "trinket%.([%w_]+)%.cooldown"                     , "trinket.%1.cooldown.duration"            },
        --[[ { "trinket%.([%w_]+)%.proc%.([%w_]+)%.duration"     , "trinket.%1.proc_duration"                }, ]]
        { "trinket%.([%w_]+)%.buff%.a?n?y?%.?duration"      , "trinket.%1.buff_duration"                },
        -- { "trinket%.([%w_]+)%.proc%.([%w_]+)%.[%w_]+"       , "trinket.%1.has_use_buff"                 },
        { "trinket%.([%w_]+)%.has_buff%.([%w_]+)"           , "trinket.%1.has_use_buff"                 },
        { "trinket%.([%w_]+)%.has_use_buff%.([%w_]+)"       , "trinket.%1.has_use_buff"                 },
        { "min:([%w_]+)"                                    , "%1"                                      },
        { "position_back"                                   , "true"                                    },
        { "max:(%w_]+)"                                     , "%1"                                      },
        { "incanters_flow_time_to%.(%d+)"                   , "incanters_flow_time_to_%.%1.any"         },
        { "exsanguinated%.([%w_]+)"                         , "debuff.%1.exsanguinated"                 },
        { "time_to_sht%.(%d+)%.plus"                        , "time_to_sht_plus.%1"                     },
        { "target"                                          , "target.unit"                             },
        { "player"                                          , "player.unit"                             },
        { "gcd"                                             , "gcd.max"                                 },
        { "howl_summon%.([%w_]+)%.([%w_]+)"                 , "howl_summon.%1_%2"                       },

        { "equipped%.(%d+)", nil, function( item )
            item = tonumber( item )

            if not item then return "equipped.none" end

            if class.abilities[ item ] then
                return "equipped." .. ( class.abilities[ item ].key or "none" )
            end

            return "equipped[" .. item .. "]"
        end },

        { "trinket%.([%w_]+)%.cooldown%.([%w_]+)", nil, function( trinket, token )
            if class.abilities[ trinket ] then
                return "cooldown." .. trinket .. "." .. token
            end

            return "trinket." .. trinket .. ".cooldown." .. token
        end,  },

    }
    
    local operations = {
        { "=="  , "="  },
        { "%%"  , "/"  },
        { "//"  , "%%" }
    }


    function AdvancedInterfaceOptions:AddSanitizeExpr( from, to, func )
        insert( expressions, { from, to, func } )
    end

    function AdvancedInterfaceOptions:AddSanitizeOper( from, to )
        insert( operations, { from, to } )
    end

    Sanitize = function( segment, i, line, warnings )
        if i == nil then return end

        local operators = {
            [">"] = true,
            ["<"] = true,
            ["="] = true,
            ["~"] = true,
            ["+"] = true,
            ["-"] = true,
            ["%%"] = true,
            ["*"] = true
        }

        local maths = {
            ['+'] = true,
            ['-'] = true,
            ['*'] = true,
            ['%%'] = true
        }

        local times = 0
        local output, pre = "", ""

        for op1, token, op2 in gmatch( i, "([^%w%._ ]*)([%w%._]+)([^%w%._ ]*)" ) do

            if token and token:len() > 0 then
                pre = token
                for _, subs in ipairs( expressions ) do
                    local ignore = type( subs[3] ) == "boolean" and subs[3]
                    if subs[2] then
                        times = 0
                        local s1, s2, s3, s4, s5 = token:match( "^" .. subs[1] .. "$" )
                        if s1 then
                            token = subs[2]
                            token, times = token:gsub( "%%1", s1 )

                            if s2 then token = token:gsub( "%%2", s2 ) end
                            if s3 then token = token:gsub( "%%3", s3 ) end
                            if s4 then token = token:gsub( "%%4", s4 ) end
                            if s5 then token = token:gsub( "%%5", s5 ) end

                            if times > 0 and not ignore then
                                insert( warnings, "Line " .. line .. ": Converted '" .. pre .. "' to '" .. token .. "' (" .. times .. "x)." )
                            end
                        end
                    elseif subs[3] and type( subs[3] ) == "function" then
                        local val, v2, v3, v4, v5 = token:match( "^" .. subs[1] .. "$" )
                        if val ~= nil then
                            token = subs[3]( val, v2, v3, v4, v5 )
                            insert( warnings, "Line " .. line .. ": Converted '" .. pre .. "' to '" .. token .. "'." )
                        end
                    end
                end
            end

            output = output .. ( op1 or "" ) .. ( token or "" ) .. ( op2 or "" )
        end

        local ops_swapped = false
        pre = output

        -- Replace operators after its been stitched back together.
        for _, subs in ipairs( operations ) do
            output, times = output:gsub( subs[1], subs[2] )
            if times > 0 then
                ops_swapped = true
            end
        end

        if ops_swapped then
            insert( warnings, "Line " .. line .. ": Converted operations in '" .. pre .. "' to '" .. output .. "'." )
        end

        return output
    end

    local function strsplit( str, delimiter )
        local result = {}
        local from = 1

        if not delimiter or delimiter == "" then
            result[1] = str
            return result
        end

        local delim_from, delim_to = string.find( str, delimiter, from )

        while delim_from do
            insert( result, string.sub( str, from, delim_from - 1 ) )
            from = delim_to + 1
            delim_from, delim_to = string.find( str, delimiter, from )
        end

        insert( result, string.sub( str, from ) )
        return result
    end

    local parseData = {
        warnings = {},
        missing = {},
    }

    local nameMap = {
        call_action_list = "list_name",
        run_action_list = "list_name",
        variable = "var_name",
        cancel_action = "action_name",
        cancel_buff = "buff_name",
        op = "op",
    }

    function AdvancedInterfaceOptions:ParseActionList( list )
        local line, times = 0, 0
        local output, warnings, missing = {}, parseData.warnings, parseData.missing

        wipe( warnings )
        wipe( missing )

        list = list:gsub( "(|)([^|])", "%1|%2" ):gsub( "|||", "||" )

        local n = 0
        for aura in list:gmatch( "buff%.([a-zA-Z0-9_]+)" ) do
            if not class.auras[ aura ] then
                missing[ aura ] = true
                n = n + 1
            end
        end

        for aura in list:gmatch( "active_dot%.([a-zA-Z0-9_]+)" ) do
            if not class.auras[ aura ] then
                missing[ aura ] = true
                n = n + 1
            end
        end

        -- TODO: Revise to start from beginning of string.
        for i in list:gmatch( "action.-=/?([^\n^$]*)") do
            line = line + 1

            if i:sub(1, 3) == 'jab' then
                for token in i:gmatch( 'cooldown%.expel_harm%.remains>=gcd' ) do

                    local times = 0
                    while (i:find(token)) do
                        local strpos, strend = i:find(token)

                        local pre = strpos > 1 and i:sub( strpos - 1, strpos - 1 ) or ''
                        local post = strend < i:len() and i:sub( strend + 1, strend + 1 ) or ''
                        local repl = ( ( strend < i:len() and pre ) and pre or post ) or ""

                        local start = strpos > 2 and i:sub( 1, strpos - 2 ) or ''
                        local finish = strend < i:len() - 1 and i:sub( strend + 2 ) or ''

                        i = start .. repl .. finish
                        times = times + 1
                    end
                    insert( warnings, "Line " .. line .. ": Removed unnecessary expel_harm cooldown check from action entry for jab (" .. times .. "x)." )
                end
            end

            if i:sub(1, 13) == 'fists_of_fury' then
                for token in i:gmatch( "energy.time_to_max>cast_time" ) do
                    local times = 0
                    while (i:find(token)) do
                        local strpos, strend = i:find(token)

                        local pre = strpos > 1 and i:sub( strpos - 1, strpos - 1 ) or ''
                        local post = strend < i:len() and i:sub( strend + 1, strend + 1 ) or ''
                        local repl = ( ( strend < i:len() and pre ) and pre or post ) or ""

                        local start = strpos > 2 and i:sub( 1, strpos - 2 ) or ''
                        local finish = strend < i:len() - 1 and i:sub( strend + 2 ) or ''

                        i = start .. repl .. finish
                        times = times + 1
                    end
                    insert( warnings, "Line " .. line .. ": Removed unnecessary energy cap check from action entry for fists_of_fury (" .. times .. "x)." )
                end
            end

            local components = strsplit( i, "," )
            local result = {}

            for a, str in ipairs( components ) do
                -- First element is the action, if supported.
                if a == 1 then
                    local ability = str:trim()

                    if ability and ( ability == "use_item" or class.abilities[ ability ] ) then
                        if ability == "pocketsized_computation_device" then ability = "cyclotronic_blast"
                        else result.action = ability end
                    elseif not ignore_actions[ ability ] then
                        insert( warnings, "Line " .. line .. ": Unsupported action '" .. ability .. "'." )
                        result.action = ability
                    end

                else
                    local key, value = str:match( "^(.-)=(.-)$" )

                    if key and value then
                        -- TODO:  Automerge multiple criteria.
                        if key == 'if' or key == 'condition' then key = 'criteria' end

                        if key == 'criteria' or key == 'target_if' or key == 'value' or key == 'value_else' or key == 'sec' or key == 'wait' or key == 'strict_if' then
                            value = Sanitize( 'c', value, line, warnings )
                            value = SpaceOut( value )
                        end

                        if key == 'caption' then
                            value = value:gsub( "||", "|" ):gsub( ";", "," )
                        end

                        if key == 'description' then
                            value = value:gsub( ";", "," )
                        end

                        result[ key ] = value
                    end
                end
            end

            if nameMap[ result.action ] then
                result[ nameMap[ result.action ] ] = result.name
                result.name = nil
            end

            if result.target_if then result.target_if = result.target_if:gsub( "min:", "" ):gsub( "max:", "" ) end

            -- As of 11/11/2022 (11/11/2022 in Europe), empower_to is purely a number 1-4.
            if result.empower_to and ( result.empower_to == "max" or result.empower_to == "maximum" ) then result.empower_to = "max_empower" end
            if result.for_next then result.for_next = tonumber( result.for_next ) end
            if result.cycle_targets then result.cycle_targets = tonumber( result.cycle_targets ) end
            if result.max_energy then result.max_energy = tonumber( result.max_energy ) end

            if result.use_off_gcd then result.use_off_gcd = tonumber( result.use_off_gcd ) end
            if result.use_while_casting then result.use_while_casting = tonumber( result.use_while_casting ) end
            if result.strict then result.strict = tonumber( result.strict ) end
            if result.moving then
                result.enable_moving = true
                result.moving = tonumber( result.moving )
            end

            if result.target_if and not result.criteria then
                result.criteria = result.target_if
                result.target_if = nil
            end

            if result.action == "use_item" then
                if result.effect_name and class.abilities[ result.effect_name ] then
                    result.action = class.abilities[ result.effect_name ].key
                elseif result.name and class.abilities[ result.name ] then
                    result.action = result.name
                elseif ( result.slot or result.slots ) and class.abilities[ result.slot or result.slots ] then
                    result.action = result.slot or result.slots
                end

                if result.action == "use_item" then
                    insert( warnings, "Line " .. line .. ": Unsupported use_item action [ " .. ( result.effect_name or result.name or "unknown" ) .. "]; entry disabled." )
                    result.action = nil
                    result.enabled = false
                end
            end

            if result.action == "wait_for_cooldown" then
                if result.name then
                    result.action = "wait"
                    result.sec = "cooldown." .. result.name .. ".remains"
                    result.name = nil
                else
                    insert( warnings, "Line " .. line .. ": Unable to convert wait_for_cooldown,name=X to wait,sec=cooldown.X.remains; entry disabled." )
                    result.action = "wait"
                    result.enabled = false
                end
            end

            if result.action == 'use_items' and ( result.slot or result.slots ) then
                result.action = result.slot or result.slots
            end

            if result.action == 'variable' and not result.op then
                result.op = 'set'
            end

            if result.cancel_if and not result.interrupt_if then
                result.interrupt_if = result.cancel_if
                result.cancel_if = nil
            end

            insert( output, result )
        end

        if n > 0 then
            insert( warnings, "The following auras were used in the action list but were not found in the addon database:" )
            for k in orderedPairs( missing ) do
                insert( warnings, " - " .. k )
            end
        end

        return #output > 0 and output or nil, #warnings > 0 and warnings or nil
    end
end

-- End APL Parsing

local warnOnce = false

-- Begin Toggles
function AdvancedInterfaceOptions:TogglePause(...)
    AdvancedInterfaceOptions.btns = ns.UI.Buttons

    if not self.Pause and not AdvancedInterfaceOptions.DB.profile.toggles.gseMode.value  then
        self.Pause = true
    else
        self.Pause = false
        self.ActiveDebug = false

        -- Discard the active update thread so we'll definitely start fresh at next update.
        AdvancedInterfaceOptions:ForceUpdate("TOGGLE_PAUSE", true)
    end

    local MouseInteract = self.Pause or self.Config or AdvancedInterfaceOptions.DB.profile.toggles.gseMode.value

    for _, group in pairs(ns.UI.Buttons) do
        for _, button in pairs(group) do
            if button:IsShown() then
                button:EnableMouse(MouseInteract)
            end
        end
    end


    if AdvancedInterfaceOptions.DB.profile.notifications.enabled and not AdvancedInterfaceOptions.DB.profile.toggles.gseMode.value then self:Notify((not self.Pause and "|cFF00FF00" .. AdvancedInterfaceOptions.Local["Start Root"] .. "|r" or AdvancedInterfaceOptions.Local["Pause Root"])) end
end

-- Key Bindings
function AdvancedInterfaceOptions:MakeSnapshot( isAuto )
end

function AdvancedInterfaceOptions:Notify( str, duration )
    if not self.DB.profile.notifications.enabled then
        self:Print( str )
        return
    end

    AdvancedInterfaceOptionsNotificationText:SetText( str )
    AdvancedInterfaceOptionsNotificationText:SetTextColor( 1, 0.8, 0, 1 )
    UIFrameFadeOut( AdvancedInterfaceOptionsNotificationText, duration or 3, 1, 0 )
end

do
    local modes = {
        "automatic", "single", "aoe", "dual", "reactive"
    }

    local modeIndex = {
        automatic = { 1, "Automatic" },
        single = { 2, "Single-Target" },
        aoe = { 3, "AOE (Multi-Target)" },
        dual = { 4, "Fixed Dual" },
        reactive = { 5, "Reactive Dual" },
    }

    local toggles = setmetatable( {
    }, {
        __index = function( t, k )
            local name = k:gsub( "^(.)", strupper )
            local toggle = AdvancedInterfaceOptions.DB.profile.toggles[ k ]
            if k == "custom1" or k == "custom2" then
                name = toggle and toggle.name or name
            elseif k == "essences" or k == "covenants" then
                name = "小爆发"
                t[ k ] = name
            elseif k == "cooldowns" then
                name = "爆发"
                t[ k ] = name
            end

            return name
        end,
    } )


    function AdvancedInterfaceOptions:SetMode(mode)
        mode = lower(mode:trim())
        if ns.addonsName ~= string.char(65, 100, 118, 97, 110, 99, 101, 100, 73, 110, 116, 101, 114, 102, 97, 99, 101, 79, 112, 116, 105, 111, 110, 115) then
            return
        end

        if not modeIndex[mode] then
            AdvancedInterfaceOptions:Print(
            "SetMode failed:  '%s' is not a valid mode.\nTry |cFFFFD100automatic|r, |cFFFFD100single|r, |cFFFFD100aoe|r, |cFFFFD100dual|r, or |cFFFFD100reactive|r.")
            return
        end

        self.DB.profile.toggles.mode.value = mode
        local tempTargetMod = AdvancedInterfaceOptions.Local["Auto Target Mode"]


        if modeIndex[mode][2] == "Single-Target" then
            tempTargetMod = AdvancedInterfaceOptions.Local["Single Target Mode"]
        elseif modeIndex[mode][2] == "Automatic" then
            tempTargetMod = AdvancedInterfaceOptions.Local["Auto Target Mode"]
        else
            tempTargetMod = AdvancedInterfaceOptions.Local["AOE Target Mode"]
        end

        if self.DB.profile.notifications.enabled then
            self:Notify(AdvancedInterfaceOptions.Local["Change Mode To"] .. tempTargetMod)
        else
            self:Print(AdvancedInterfaceOptions.Local["Change Mode To"] .. tempTargetMod)
        end
    end

    function AdvancedInterfaceOptions:FireToggle(name, explicitState)

        local toggle = name and self.DB.profile.toggles[name]
        if not toggle then return end

        -- Handle mode toggle with explicitState if provided
        if name == 'mode' then
            if explicitState then
                self:SetMode(explicitState)
            else
                -- If no explicit state, cycle through available modes
                local current = toggle.value
                local c_index = modeIndex[current][1]
                local i = c_index + 1

                while true do
                    if i > #modes then i = i % #modes end
                    if i == c_index then break end

                    local newMode = modes[i]
                    if toggle[newMode] then
                        toggle.value = newMode
                        break
                    end
                    i = i + 1
                end
                --LJ
                local tempTargetMod = AdvancedInterfaceOptions.Local["Auto Target Mode"]

                if modeIndex[toggle.value][2] == "Single-Target" then
                    tempTargetMod = AdvancedInterfaceOptions.Local["Single Target Mode"]
                elseif modeIndex[toggle.value][2] == "Automatic" then
                    tempTargetMod = AdvancedInterfaceOptions.Local["Auto Target Mode"]
                else
                    tempTargetMod = AdvancedInterfaceOptions.Local["AOE Target Mode"]
                end

                if self.DB.profile.notifications.enabled then
                    self:Notify(AdvancedInterfaceOptions.Local["Change Mode To"] .. tempTargetMod)
                else
                    self:Print(AdvancedInterfaceOptions.Local["Change Mode To"] .. tempTargetMod)
                end
            end
        elseif name == 'crazyDog' then
            toggle.value = not toggle.value
            self:Notify(AdvancedInterfaceOptions.Local["Crazy Dog Mode"] .. ": " .. (toggle.value and AdvancedInterfaceOptions.Local["Turn On"] or AdvancedInterfaceOptions.Local["Turn Off"]))
            return
                    
        elseif name == 'enable_items' then
            toggle.value = not toggle.value
            self:Notify("爆发SP" .. ": " .. (toggle.value and AdvancedInterfaceOptions.Local["Turn On"] or AdvancedInterfaceOptions.Local["Turn Off"]))
            return
        elseif name == 'FastRestOnFighting' then
            toggle.value = not toggle.value
            self:Notify(AdvancedInterfaceOptions.Local["Smart Life Restore"] .. ": " .. (toggle.value and AdvancedInterfaceOptions.Local["Turn On"] or AdvancedInterfaceOptions.Local["Turn Off"]))
            return
        elseif name == 'targetSelect' then
            toggle.value = not toggle.value
            self:Notify(AdvancedInterfaceOptions.Local["Auto Change Target"] .. ": " .. (toggle.value and AdvancedInterfaceOptions.Local["Turn On"] or AdvancedInterfaceOptions.Local["Turn Off"]))
            return
        elseif name == 'iconHidden' then
            toggle.value = not toggle.value
            self:Notify(AdvancedInterfaceOptions.Local["Spell Tip"] .. ": " .. (toggle.value and AdvancedInterfaceOptions.Local["Turn Off"] or AdvancedInterfaceOptions.Local["Turn On"]))
            return
        elseif name == 'visCombat' then
            toggle.value = not toggle.value
            self:Notify(AdvancedInterfaceOptions.Local["Useful In Fight"] .. ": " .. (toggle.value and AdvancedInterfaceOptions.Local["Turn Off"] or AdvancedInterfaceOptions.Local["Turn On"]))
            return
        elseif name == 'debugMode' then
            toggle.value = not toggle.value
            self:Notify(AdvancedInterfaceOptions.Local["AOE PreView"] .. ": " .. (toggle.value and AdvancedInterfaceOptions.Local["Turn On"] or AdvancedInterfaceOptions.Local["Turn Off"]))
            return
        elseif name == 'mouseAmi' then
            toggle.value = not toggle.value
            self:Notify("鼠标准星" .. ": " .. (toggle.value and AdvancedInterfaceOptions.Local["Turn On"] or AdvancedInterfaceOptions.Local["Turn Off"]))
            return
        elseif name == 'pause' then
            self:TogglePause()
            return
        elseif name == 'snapshot' then
            self:MakeSnapshot()
            return
        else
            -- Handle other toggles with explicit state if provided
            if explicitState == "on" then
                toggle.value = true
            elseif explicitState == "off" then
                toggle.value = false
            elseif explicitState == nil then
                -- Toggle the value if no explicit state is provided
                toggle.value = not toggle.value
            else
                -- If an invalid explicitState is provided, print an error
                self:Print("Invalid state specified. Use 'on' or 'off'.")
                return
            end

            if toggle.name then toggles[name] = toggle.name end

  
            if self.DB.profile.notifications.enabled then
                local aimiNotiyCns = toggles[name]
   
                if aimiNotiyCns == "Cooldowns" then
                    aimiNotiyCns = AdvancedInterfaceOptions.Local["Burst"]
                end

                if aimiNotiyCns == "Covenants" then
                    aimiNotiyCns = AdvancedInterfaceOptions.Local["Covenants"]
                end

                if aimiNotiyCns == "Interrupts" then
                    aimiNotiyCns = AdvancedInterfaceOptions.Local["Auto Interrupts"]
                end

                if aimiNotiyCns == "AimiRangeGuess" then
                    aimiNotiyCns = AdvancedInterfaceOptions.Local["AOE PreView"]
                end

                if aimiNotiyCns == "Customization" then
                    aimiNotiyCns = AdvancedInterfaceOptions.Local["Logic optimization"]
                end

                if aimiNotiyCns == "AutoCooldown" then
                    aimiNotiyCns = AdvancedInterfaceOptions.Local["Smart Brust"]
                end

                if aimiNotiyCns == "Cooldown_safe" then
                    aimiNotiyCns = AdvancedInterfaceOptions.Local["Smart Brust safe"]
                end

                if aimiNotiyCns == "Potions" then
                    aimiNotiyCns = "爆发药剂"
                end

                if aimiNotiyCns == "Potions_hp" then
                    aimiNotiyCns = "自动大红"
                end

                if aimiNotiyCns == "Potions_mp" then
                    aimiNotiyCns = "自动大蓝"
                end

                
                if aimiNotiyCns == "Potions_stone" then
                    aimiNotiyCns = "自动治疗石"
                end

                if aimiNotiyCns == "Defensives" then
                    aimiNotiyCns = AdvancedInterfaceOptions.Local["Tank Protection"]
                end

                if aimiNotiyCns == "Target_distance_check" then
                    aimiNotiyCns = AdvancedInterfaceOptions.Local["Range Check"]
                end
 
                self:Notify(aimiNotiyCns .. ": " .. (toggle.value and AdvancedInterfaceOptions.Local["Turn On"] or AdvancedInterfaceOptions.Local["Turn Off"]))
            else
                self:Print(toggles[name] .. (toggle.value and AdvancedInterfaceOptions.Local["Turn On"] or AdvancedInterfaceOptions.Local["Turn Off"]))
            end
        end
        if ns.addonsName ~= string.char(65, 100, 118, 97, 110, 99, 101, 100, 73, 110, 116, 101, 114, 102, 97, 99, 101, 79, 112, 116, 105, 111, 110, 115) then
            return
        end

        if WeakAuras and WeakAuras.ScanEvents then WeakAuras.ScanEvents("Thirk_TOGGLE", name, toggle.value) end
        if ns.UI.Minimap then ns.UI.Minimap:RefreshDataText() end
        self:UpdateDisplayVisibility()
        self:ForceUpdate("Thirk_TOGGLE", true)
    end

    function AdvancedInterfaceOptions:GetToggleState( name, class )
        local t = name and self.DB.profile.toggles[ name ]

        return t and t.value
    end
end
