local Profile  = require(script.Profile)
local MLP      = require(script.MLP)
local QLearner = require(script.QLearner)
local CSF      = require(script.CSF)
local NEAT     = require(script.NEAT)

local Worm = {}

Worm.VERSION = "0.1.0-beta"

Worm.MLP    = "MLP"
Worm.QLEARN = "QLEARN"
Worm.CSF    = "CSF"
Worm.NEAT   = "NEAT"

local IMPLS = {
    MLP    = MLP,
    QLEARN = QLearner,
    CSF    = CSF,
    NEAT   = NEAT,
}

local DEFAULT_CONFIGS = {
    MLP = {
        hidden            = { 16, 16 },
        activation        = "relu",
        output_activation = "softmax",
        optimizer         = "adam",
        lr                = 0.001,
    },
    QLEARN = {
        gamma         = 0.95,
        epsilon       = 1.0,
        epsilon_decay = 0.995,
        epsilon_min   = 0.05,
        memory        = 5000,
        batch         = 64,
        lr            = 0.001,
        optimizer     = "adam",
    },
    CSF = {
        filters = 8,
        kernel  = 3,
        stride  = 1,
        pool    = "max",
    },
    NEAT = {
        population        = 150,
        persist           = false,
        mutation_rate     = 0.8,
        weight_mutation   = 0.9,
        weight_perturb    = 0.8,
        crossover_rate    = 0.75,
        species_threshold = 3.0,
    },
}

local function mergeConfig(wormType, userConfig)
    local merged = {}
    for k, v in pairs(DEFAULT_CONFIGS[wormType]) do
        merged[k] = v
    end
    for k, v in pairs(userConfig or {}) do
        merged[k] = v
    end
    return merged
end

function Worm.build(wormType, config)
    local impl = IMPLS[wormType]
    assert(impl, "Worm: unknown type '" .. tostring(wormType) .. "'")

    local mergedConfig = mergeConfig(wormType, config)
    local instance     = impl.new(mergedConfig)
    local profile       = Profile.new(wormType, mergedConfig, instance)

    return profile
end

function Worm.load(data)
    local profile = Worm.build(data._worm_type, data.config)
    profile:import(data)
    return profile
end

return Worm
