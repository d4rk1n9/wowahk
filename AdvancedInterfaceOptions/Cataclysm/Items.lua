-- Cataclysm/Items.lua

local addon, ns = ...
local AdvancedInterfaceOptions = _G[ addon ]

local class, state = AdvancedInterfaceOptions.Class, AdvancedInterfaceOptions.State
local all = AdvancedInterfaceOptions.Class.specs[ 0 ]

all:RegisterAbility( "skardyns_grace", {
    cast = 0,
    cooldown = 120,
    gcd = "off",

    item = 133282,
    toggle = "cooldowns",

    handler = function ()
        applyBuff( "speed_of_thought" )
    end,

    auras = {
        speed_of_thought = {
            id = 92099,
            duration = 35,
            max_stack = 1
        }
    }
} )
