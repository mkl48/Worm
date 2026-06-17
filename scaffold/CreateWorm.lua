-- Worm scaffold
-- Auto-generated from src/ -- regenerate after any src/ edit, this is a snapshot, not live-synced
-- Run in Roblox Studio's Command Bar to build the full Worm ModuleScript tree under ReplicatedStorage

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local existing = ReplicatedStorage:FindFirstChild("Worm")
if existing then
	existing:Destroy()
end

local n_Worm = Instance.new("ModuleScript")
n_Worm.Name = "Worm"
n_Worm.Source = [====[
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
]====]
n_Worm.Parent = ReplicatedStorage

local n_Worm_Types = Instance.new("ModuleScript")
n_Worm_Types.Name = "Types"
n_Worm_Types.Source = [====[
export type WormEnum = "MLP" | "QLEARN" | "CSF" | "NEAT"

export type ActivationName = "relu" | "sigmoid" | "tanh" | "softmax" | "leaky_relu"
export type OptimizerName  = "sgd" | "adam" | "rmsprop"
export type PoolName       = "max" | "avg"
export type GradeStyle     = "ordinal" | "polarity" | "pairs"
export type PolarityValue  = "+critical" | "+high" | "+medium" | "+low"
                           | "-critical" | "-high" | "-medium" | "-low"
export type MarginValue    = "large" | "medium" | "small"

export type SchemaField = {
    range: { number },
}

export type Schema = { [string]: SchemaField }

export type MLPConfig = {
    inputs:             number,
    outputs:            number,
    hidden:             { number }?,
    activation:         ActivationName?,
    output_activation:  ActivationName?,
    optimizer:          OptimizerName?,
    lr:                 number?,
    schema:             Schema?,
}

export type QLearnConfig = {
    states:         number,
    actions:        number,
    gamma:          number?,
    epsilon:        number?,
    epsilon_decay:  number?,
    epsilon_min:    number?,
    memory:         number?,
    batch:          number?,
    lr:             number?,
    schema:         Schema?,
}

export type CSFConfig = {
    grid:    { number },
    filters: number?,
    kernel:  number?,
    stride:  number?,
    pool:    PoolName?,
    outputs: number,
    schema:  Schema?,
}

export type NEATConfig = {
    inputs:             number,
    outputs:            number,
    population:         number?,
    persist:            boolean?,
    mutation_rate:      number?,
    weight_mutation:    number?,
    weight_perturb:     number?,
    crossover_rate:     number?,
    species_threshold:  number?,
    schema:             Schema?,
}

export type OrdinalEvents  = { [string]: number }
export type PolarityEvents = { [string]: PolarityValue }
export type PairEvent = {
    better: string,
    worse:  string,
    margin: MarginValue,
}

export type GradeConfig = {
    style:  GradeStyle,
    events: OrdinalEvents | PolarityEvents | { PairEvent },
    pin:    { [string]: number }?,
}

export type MLPLessonSingle = {
    input: { [string]: number } | { number },
    label: string,
}

export type MLPLessonBatch = { MLPLessonSingle }

export type QLearnLesson = {
    state:  { [string]: number } | { number },
    action: number,
    next:   { [string]: number } | { number },
    reward: string | number,
    done:   boolean,
}

export type NEATLesson = {
    evaluate:    (genome: Profile) -> number,
    generations: number?,
    on_evolve:   ((gen: number, best: NEATGenome) -> ())?,
}

export type NEATGenome = {
    fitness:  number,
    infer:    (input: any) -> any,
    export:   () -> table,
}

export type NEATStats = {
    generation:    number,
    best_fitness:  number,
    species_count: number,
}

export type Snapshot = {
    name:    string,
    weights: any,
}

export type ExportData = {
    _worm_type:   WormEnum,
    _worm_ver:    string,
    config:       any,
    weights:      any,
    labels:       { string }?,
    label_map:    { [string]: number }?,
    grade_config: GradeConfig?,
    grade_resolved: { [string]: number }?,
    snapshots:    { Snapshot }?,
    optimizer_state: any?,
    neat_population: any?,
}

export type Profile = {
    infer:      (self: Profile, input: any) -> Promise,
    lesson:     (self: Profile, data: any) -> Promise,
    interpret:  (self: Profile, fn: (raw: any) -> any) -> (),
    labels:     (self: Profile, list: { string }) -> (),
    grade:      (self: Profile, config: GradeConfig) -> (),
    grades:     (self: Profile) -> { [string]: number },
    rewards:    (self: Profile, map: { [string]: number }) -> (),
    export:     (self: Profile) -> Promise,
    import:     (self: Profile, data: ExportData) -> Promise,
    reset:      (self: Profile) -> (),
    tag:        (self: Profile, name: string) -> (),
    rollback:   (self: Profile, name: string) -> (),
    history:    (self: Profile) -> { string },
    type:       (self: Profile) -> WormEnum,
    evolve:     (self: Profile) -> Promise,
    champion:   (self: Profile) -> Profile,
}

export type Promise = {
    next:    (self: Promise, fn: (...any) -> any) -> Promise,
    toss:    (self: Promise, fn: (...any) -> any) -> Promise,
    finally: (self: Promise, fn: (...any) -> any) -> Promise,
}

return {}
]====]
n_Worm_Types.Parent = n_Worm

local n_Worm_Activations = Instance.new("ModuleScript")
n_Worm_Activations.Name = "Activations"
n_Worm_Activations.Source = [====[
local Activations = {}

function Activations.relu(x)
    return math.max(0, x)
end

function Activations.leaky_relu(x)
    return x >= 0 and x or 0.01 * x
end

function Activations.sigmoid(x)
    return 1 / (1 + math.exp(-x))
end

function Activations.tanh(x)
    local e2x = math.exp(2 * x)
    return (e2x - 1) / (e2x + 1)
end

function Activations.softmax(vec)
    local max = math.max(table.unpack(vec))
    local exps = {}
    local sum  = 0
    for i, v in ipairs(vec) do
        exps[i] = math.exp(v - max)
        sum    += exps[i]
    end
    for i in ipairs(exps) do
        exps[i] /= sum
    end
    return exps
end

function Activations.relu_deriv(x)
    return x > 0 and 1 or 0
end

function Activations.leaky_relu_deriv(x)
    return x >= 0 and 1 or 0.01
end

function Activations.sigmoid_deriv(x)
    local s = Activations.sigmoid(x)
    return s * (1 - s)
end

function Activations.tanh_deriv(x)
    local t = Activations.tanh(x)
    return 1 - t * t
end

function Activations.linear(vec)
    local out = {}
    for i, v in ipairs(vec) do
        out[i] = v
    end
    return out
end

Activations.fn = {
    relu       = Activations.relu,
    leaky_relu = Activations.leaky_relu,
    sigmoid    = Activations.sigmoid,
    tanh       = Activations.tanh,
    softmax    = Activations.softmax,
    linear     = Activations.linear,
}

Activations.deriv = {
    relu       = Activations.relu_deriv,
    leaky_relu = Activations.leaky_relu_deriv,
    sigmoid    = Activations.sigmoid_deriv,
    tanh       = Activations.tanh_deriv,
}

return Activations
]====]
n_Worm_Activations.Parent = n_Worm

local n_Worm_Optimizer = Instance.new("ModuleScript")
n_Worm_Optimizer.Name = "Optimizer"
n_Worm_Optimizer.Source = [====[
local Optimizer = {}
Optimizer.__index = Optimizer

function Optimizer.new(kind, lr, params)
    local self = setmetatable({}, Optimizer)
    self._kind  = kind
    self._lr    = lr
    self._t     = 0
    self._m     = {}
    self._v     = {}
    self._cache = {}
    if kind == "adam" then
        self._beta1 = params and params.beta1 or 0.9
        self._beta2 = params and params.beta2 or 0.999
        self._eps   = params and params.eps   or 1e-8
    elseif kind == "rmsprop" then
        self._decay = params and params.decay or 0.9
        self._eps   = params and params.eps   or 1e-8
    end
    return self
end

function Optimizer:step(weights, grads)
    self._t += 1
    if self._kind == "sgd" then
        for i, g in ipairs(grads) do
            weights[i] -= self._lr * g
        end

    elseif self._kind == "adam" then
        local b1, b2, eps = self._beta1, self._beta2, self._eps
        for i, g in ipairs(grads) do
            self._m[i] = self._m[i] or 0
            self._v[i] = self._v[i] or 0
            self._m[i] = b1 * self._m[i] + (1 - b1) * g
            self._v[i] = b2 * self._v[i] + (1 - b2) * g * g
            local mh = self._m[i] / (1 - b1 ^ self._t)
            local vh = self._v[i] / (1 - b2 ^ self._t)
            weights[i] -= self._lr * mh / (math.sqrt(vh) + eps)
        end

    elseif self._kind == "rmsprop" then
        local decay, eps = self._decay, self._eps
        for i, g in ipairs(grads) do
            self._cache[i] = self._cache[i] or 0
            self._cache[i] = decay * self._cache[i] + (1 - decay) * g * g
            weights[i] -= self._lr * g / (math.sqrt(self._cache[i]) + eps)
        end
    end
end

function Optimizer:exportState()
    return {
        kind  = self._kind,
        lr    = self._lr,
        t     = self._t,
        m     = table.clone(self._m),
        v     = table.clone(self._v),
        cache = table.clone(self._cache),
    }
end

function Optimizer:importState(state)
    self._t     = state.t
    self._m     = state.m
    self._v     = state.v
    self._cache = state.cache
end

return Optimizer
]====]
n_Worm_Optimizer.Parent = n_Worm

local n_Worm_Grade = Instance.new("ModuleScript")
n_Worm_Grade.Name = "Grade"
n_Worm_Grade.Source = [====[
local Grade = {}

local POLARITY_BASE = {
    ["+critical"] =  4.0,
    ["+high"]     =  2.0,
    ["+medium"]   =  1.0,
    ["+low"]      =  0.4,
    ["-low"]      = -0.4,
    ["-medium"]   = -1.0,
    ["-high"]     = -2.0,
    ["-critical"] = -4.0,
}

local MARGIN = {
    large  = 2.0,
    medium = 1.0,
    small  = 0.5,
}

function Grade.resolve(config)
    local weights = {}

    if config.style == "ordinal" then
        local values = {}
        for _, v in pairs(config.events) do table.insert(values, v) end
        table.sort(values)
        local min, max = values[1], values[#values]
        local range    = max - min

        for event, v in pairs(config.events) do
            if range == 0 then
                weights[event] = 0
            else
                weights[event] = ((v - min) / range) * 8 - 4
            end
        end

    elseif config.style == "polarity" then
        for event, polarity in pairs(config.events) do
            weights[event] = POLARITY_BASE[polarity]
            assert(weights[event], "Worm: unknown polarity value '" .. polarity .. "'")
        end

    elseif config.style == "pairs" then
        local scores = {}
        for _, pair in ipairs(config.events) do
            scores[pair.better] = (scores[pair.better] or 0) + MARGIN[pair.margin]
            scores[pair.worse]  = (scores[pair.worse]  or 0) - MARGIN[pair.margin]
        end
        local vals = {}
        for _, v in pairs(scores) do table.insert(vals, v) end
        table.sort(vals)
        local min, max = vals[1], vals[#vals]
        local range    = max - min
        for event, v in pairs(scores) do
            weights[event] = range == 0 and 0 or ((v - min) / range) * 8 - 4
        end
    end

    if config.pin then
        for pinnedEvent, pinnedVal in pairs(config.pin) do
            local currentVal = weights[pinnedEvent]
            assert(currentVal, "Worm: pin target '" .. pinnedEvent .. "' not in events")
            if currentVal ~= 0 then
                local scale = pinnedVal / currentVal
                for event in pairs(weights) do
                    weights[event] *= scale
                end
            end
        end
    end

    return weights
end

return Grade
]====]
n_Worm_Grade.Parent = n_Worm

local n_Worm_Serializer = Instance.new("ModuleScript")
n_Worm_Serializer.Name = "Serializer"
n_Worm_Serializer.Source = [====[
local Serializer = {}

function Serializer.packSnapshots(snapshots, order)
    local packed = {}
    for _, name in ipairs(order) do
        table.insert(packed, { name = name, weights = snapshots[name] })
    end
    return packed
end

function Serializer.unpackSnapshots(packed)
    local snapshots = {}
    local order     = {}
    for _, entry in ipairs(packed) do
        snapshots[entry.name] = entry.weights
        table.insert(order, entry.name)
    end
    return snapshots, order
end

function Serializer.deepClone(t)
    if type(t) ~= "table" then return t end
    local copy = {}
    for k, v in pairs(t) do
        copy[Serializer.deepClone(k)] = Serializer.deepClone(v)
    end
    return copy
end

return Serializer
]====]
n_Worm_Serializer.Parent = n_Worm

local n_Worm_Promise = Instance.new("ModuleScript")
n_Worm_Promise.Name = "Promise"
n_Worm_Promise.Source = [====[
local EvaeraProm = require(script.Parent._Libraries.Promise)

local WormPromise = {}

function WormPromise.new(executor)
    local p = EvaeraProm.new(executor)
    return WormPromise._wrap(p)
end

function WormPromise.resolve(value)
    return WormPromise._wrap(EvaeraProm.resolve(value))
end

function WormPromise.reject(reason)
    return WormPromise._wrap(EvaeraProm.reject(reason))
end

function WormPromise._wrap(p)
    local proxy = {}

    function proxy:next(fn)
        return WormPromise._wrap(p:andThen(fn))
    end

    function proxy:toss(fn)
        return WormPromise._wrap(p:catch(fn))
    end

    function proxy:finally(fn)
        return WormPromise._wrap(p:finally(fn))
    end

    return proxy
end

return WormPromise
]====]
n_Worm_Promise.Parent = n_Worm

local n_Worm_Util = Instance.new("ModuleScript")
n_Worm_Util.Name = "Util"
n_Worm_Util.Source = [====[
local Util = {}

function Util.toVector(input)
    if type(input[1]) == "number" then
        return input
    end
    local vec = {}
    for _, v in pairs(input) do
        table.insert(vec, v)
    end
    return vec
end

function Util.normalizeSchema(input, schema)
    local vec = {}
    for field, def in pairs(schema) do
        local raw = input[field]
        assert(raw ~= nil, "Worm: schema field '" .. field .. "' missing from input")
        local min, max = def.range[1], def.range[2]
        local normalized = (raw - min) / (max - min)
        normalized = math.clamp(normalized, 0, 1)
        table.insert(vec, normalized)
    end
    return vec
end

function Util.topologicalSort(genome)
    local inDegree = {}
    local adj      = {}
    local nodes    = {}

    for id in pairs(genome.nodes) do
        inDegree[id] = 0
        adj[id]      = {}
        table.insert(nodes, id)
    end

    local conns = {}
    for _, conn in pairs(genome.connections) do
        if conn.enabled then
            table.insert(conns, conn)
            inDegree[conn.out] = (inDegree[conn.out] or 0) + 1
            table.insert(adj[conn.in_], conn)
        end
    end

    local queue = {}
    for id, deg in pairs(inDegree) do
        if deg == 0 then table.insert(queue, id) end
    end

    local sorted = {}
    local head   = 1
    while head <= #queue do
        local node = queue[head]
        head += 1
        for _, conn in ipairs(adj[node] or {}) do
            table.insert(sorted, conn)
            inDegree[conn.out] -= 1
            if inDegree[conn.out] == 0 then
                table.insert(queue, conn.out)
            end
        end
    end

    return sorted
end

return Util
]====]
n_Worm_Util.Parent = n_Worm

local n_Worm_Profile = Instance.new("ModuleScript")
n_Worm_Profile.Name = "Profile"
n_Worm_Profile.Source = [====[
local Grade      = require(script.Parent.Grade)
local Serializer = require(script.Parent.Serializer)
local Promise     = require(script.Parent.Promise)
local Util        = require(script.Parent.Util)

local toVector       = Util.toVector
local normalizeSchema = Util.normalizeSchema

local VERSION = "0.1.0-beta"

local Profile = {}
Profile.__index = Profile

function Profile.new(wormType, config, impl)
    local self = setmetatable({}, Profile)

    self._type           = wormType
    self._config         = config
    self._interpreter    = nil
    self._labels         = {}
    self._label_map      = {}
    self._label_inv      = {}
    self._grade_config   = nil
    self._grade_weights  = {}
    self._snapshots      = {}
    self._snapshot_order = {}
    self._impl           = impl

    return self
end

function Profile:infer(input)
    return Promise.new(function(resolve, reject)
        local prepared = input
        if self._interpreter then
            local ok, result = pcall(self._interpreter, input)
            if not ok then reject(result) return end
            prepared = result
        end

        if self._config.schema then
            local ok, normalized = pcall(normalizeSchema, prepared, self._config.schema)
            if not ok then reject(normalized) return end
            prepared = normalized
        end

        local vec = toVector(prepared)
        local ok, output = pcall(self._impl._forward, self._impl, vec)
        if not ok then reject(output) return end

        if next(self._label_inv) then
            local maxIdx, maxVal = 1, output[1]
            for i = 2, #output do
                if output[i] > maxVal then
                    maxIdx = i
                    maxVal = output[i]
                end
            end
            resolve(self._label_inv[maxIdx])
        else
            resolve(output)
        end
    end)
end

function Profile:lesson(data)
    return Promise.new(function(resolve, reject)
        local ok, result = pcall(self._impl._lesson, self._impl, data, self)
        if not ok then reject(result) return end
        resolve(result)
    end)
end

function Profile:interpret(fn)
    assert(type(fn) == "function", "Worm: interpret() expects a function")
    self._interpreter = fn
end

function Profile:labels(list)
    for i, label in ipairs(list) do
        if not self._label_map[label] then
            self._label_map[label] = i
            self._label_inv[i]     = label
            table.insert(self._labels, label)
        end
    end
end

function Profile:grade(config)
    self._grade_config  = config
    self._grade_weights = Grade.resolve(config)
end

function Profile:grades()
    return table.clone(self._grade_weights)
end

function Profile:rewards(map)
    self._grade_weights = table.clone(map)
end

function Profile:export()
    return Promise.new(function(resolve, reject)
        local ok, weights = pcall(self._impl._exportWeights, self._impl)
        if not ok then reject(weights) return end

        local data = {
            _worm_type      = self._type,
            _worm_ver       = VERSION,
            config          = self._config,
            weights         = weights,
            labels          = table.clone(self._labels),
            label_map       = table.clone(self._label_map),
            grade_config    = self._grade_config,
            grade_resolved  = self._grade_weights,
            snapshots       = Serializer.packSnapshots(self._snapshots, self._snapshot_order),
        }

        resolve(data)
    end)
end

function Profile:import(data)
    return Promise.new(function(resolve, reject)
        local ok, err = pcall(function()
            self._impl:_importWeights(data.weights)
            self._labels        = data.labels or {}
            self._label_map     = data.label_map or {}
            self._grade_config  = data.grade_config
            self._grade_weights = data.grade_resolved or {}
            if data.snapshots then
                self._snapshots, self._snapshot_order =
                    Serializer.unpackSnapshots(data.snapshots)
            end
            for i, label in ipairs(self._labels) do
                self._label_inv[i] = label
            end
        end)
        if not ok then reject(err) return end
        resolve()
    end)
end

function Profile:reset()
    self._impl:_reset()
end

function Profile:tag(name)
    local ok, weights = pcall(self._impl._exportWeights, self._impl)
    if not ok then return end
    self._snapshots[name] = weights
    table.insert(self._snapshot_order, name)
end

function Profile:rollback(name)
    local snap = self._snapshots[name]
    assert(snap, "Worm: no snapshot tagged '" .. name .. "'")
    self._impl:_importWeights(snap)
end

function Profile:history()
    return table.clone(self._snapshot_order)
end

function Profile:type()
    return self._type
end

function Profile:evolve()
    assert(self._impl.evolve, "Worm: evolve() is only available on NEAT profiles")
    return self._impl:evolve(self)
end

function Profile:champion()
    assert(self._impl.champion, "Worm: champion() is only available on NEAT profiles")
    return self._impl:champion(self)
end

Profile.VERSION = VERSION

return Profile
]====]
n_Worm_Profile.Parent = n_Worm

local n_Worm_MLP = Instance.new("ModuleScript")
n_Worm_MLP.Name = "MLP"
n_Worm_MLP.Source = [====[
local Activations = require(script.Parent.Activations)
local Optimizer    = require(script.Parent.Optimizer)
local Util         = require(script.Parent.Util)

local toVector        = Util.toVector
local normalizeSchema = Util.normalizeSchema

local MLP = {}
MLP.__index = MLP

local function initWeight(fanIn, fanOut, activation)
    if activation == "relu" or activation == "leaky_relu" then
        local std = math.sqrt(2 / fanIn)
        return (math.random() * 2 - 1) * std
    else
        local limit = math.sqrt(6 / (fanIn + fanOut))
        return (math.random() * 2 - 1) * limit
    end
end

local function buildLayers(config)
    local sizes = { config.inputs }
    for _, h in ipairs(config.hidden) do
        table.insert(sizes, h)
    end
    table.insert(sizes, config.outputs)

    local layers = {}
    for i = 1, #sizes - 1 do
        local fanIn, fanOut = sizes[i], sizes[i + 1]
        local weights, biases = {}, {}
        for o = 1, fanOut do
            biases[o] = 0
            for j = 1, fanIn do
                weights[(o - 1) * fanIn + j] = initWeight(fanIn, fanOut, config.activation)
            end
        end
        layers[i] = {
            weights = weights,
            biases  = biases,
            in_     = fanIn,
            out     = fanOut,
        }
    end
    return layers
end

function MLP.new(config)
    local self = setmetatable({}, MLP)

    self._config     = config
    self._layers     = buildLayers(config)
    self._optimizer  = Optimizer.new(config.optimizer, config.lr)
    self._activFn    = Activations.fn[config.activation]
    self._activDeriv = Activations.deriv[config.activation]
    self._outputFn   = Activations.fn[config.output_activation]
    self._zs         = {}
    self._acts       = {}

    return self
end

function MLP:_forward(input)
    local activation = input
    self._zs    = {}
    self._acts  = { activation }

    for i, layer in ipairs(self._layers) do
        local z = {}
        for o = 1, layer.out do
            local sum = layer.biases[o]
            for j = 1, layer.in_ do
                sum += activation[j] * layer.weights[(o - 1) * layer.in_ + j]
            end
            z[o] = sum
        end
        self._zs[i] = z

        local next_act = {}
        local isLast   = i == #self._layers
        if isLast then
            next_act = self._outputFn(z)
        else
            for j, val in ipairs(z) do
                next_act[j] = self._activFn(val)
            end
        end
        activation = next_act
        self._acts[i + 1] = activation
    end

    return activation
end

function MLP:_backward(target)
    local numLayers = #self._layers
    local deltas    = {}

    local output = self._acts[numLayers + 1]
    local delta  = {}
    for i = 1, #output do
        delta[i] = output[i] - target[i]
    end
    deltas[numLayers] = delta

    for i = numLayers - 1, 1, -1 do
        local layer     = self._layers[i + 1]
        local prevDelta = deltas[i + 1]
        local d         = {}
        for j = 1, self._layers[i].out do
            local err = 0
            for k = 1, layer.out do
                err += prevDelta[k] * layer.weights[(k - 1) * layer.in_ + j]
            end
            d[j] = err * self._activDeriv(self._zs[i][j])
        end
        deltas[i] = d
    end

    for i, layer in ipairs(self._layers) do
        local d    = deltas[i]
        local act  = self._acts[i]
        local wGrads = {}
        local bGrads = {}

        for o = 1, layer.out do
            bGrads[o] = d[o]
            for j = 1, layer.in_ do
                wGrads[(o - 1) * layer.in_ + j] = d[o] * act[j]
            end
        end

        local flatWeights = layer.weights
        self._optimizer:step(flatWeights, wGrads)
        self._optimizer:step(layer.biases, bGrads)
    end

    local output2 = self._acts[numLayers + 1]
    local loss = 0
    for i = 1, #output2 do
        local diff = output2[i] - target[i]
        loss += diff * diff
    end
    return loss / #output2
end

function MLP:_lesson(data, profile)
    local isBatch = data[1] ~= nil and type(data[1]) == "table" and data[1].input ~= nil

    if isBatch then
        local totalLoss = 0
        for _, sample in ipairs(data) do
            totalLoss += self:_learnOne(sample, profile)
        end
        return totalLoss / #data
    else
        return self:_learnOne(data, profile)
    end
end

function MLP:_learnOne(sample, profile)
    local input = sample.input
    local label = sample.label

    if profile._interpreter then
        input = profile._interpreter(input)
    end
    if profile._config.schema then
        input = normalizeSchema(input, profile._config.schema)
    end
    input = toVector(input)

    profile:labels({ label })
    local targetIdx = profile._label_map[label]
    local target    = {}
    for i = 1, profile._config.outputs do
        target[i] = i == targetIdx and 1 or 0
    end

    self:_forward(input)
    return self:_backward(target)
end

function MLP:_exportWeights()
    local packed = {}
    for i, layer in ipairs(self._layers) do
        packed[i] = {
            weights = table.clone(layer.weights),
            biases  = table.clone(layer.biases),
        }
    end
    return {
        layers          = packed,
        optimizer_state = self._optimizer:exportState(),
    }
end

function MLP:_importWeights(data)
    for i, layer in ipairs(self._layers) do
        layer.weights = data.layers[i].weights
        layer.biases  = data.layers[i].biases
    end
    if data.optimizer_state then
        self._optimizer:importState(data.optimizer_state)
    end
end

function MLP:_reset()
    self._layers    = buildLayers(self._config)
    self._optimizer = Optimizer.new(self._config.optimizer, self._config.lr)
end

return MLP
]====]
n_Worm_MLP.Parent = n_Worm

local n_Worm_QLearner = Instance.new("ModuleScript")
n_Worm_QLearner.Name = "QLearner"
n_Worm_QLearner.Source = [====[
local MLP  = require(script.Parent.MLP)
local Util = require(script.Parent.Util)

local toVector        = Util.toVector
local normalizeSchema = Util.normalizeSchema

local QLearner = {}
QLearner.__index = QLearner

local function netConfig(config)
    return {
        inputs            = config.states,
        outputs           = config.actions,
        hidden            = config.hidden or { 24, 24 },
        activation        = config.activation or "relu",
        output_activation = "linear",
        optimizer         = config.optimizer,
        lr                = config.lr,
    }
end

function QLearner.new(config)
    local self = setmetatable({}, QLearner)

    self._config       = config
    self._online        = MLP.new(netConfig(config))
    self._target        = MLP.new(netConfig(config))
    self._target:_importWeights(self._online:_exportWeights())

    self._buffer        = table.create(config.memory, nil)
    self._bufferHead     = 0
    self._bufferSize     = 0
    self._epsilon        = config.epsilon
    self._updateEvery    = 50
    self._lessonCount    = 0
    self._lastAction     = nil

    return self
end

function QLearner:_forward(stateVec)
    if math.random() < self._epsilon then
        local action = math.random(1, self._config.actions)
        local dummy  = table.create(self._config.actions, 0)
        dummy[action] = 1
        self._lastAction = action
        return dummy
    else
        local qvals = self._online:_forward(stateVec)
        local maxIdx, maxVal = 1, qvals[1]
        for i = 2, #qvals do
            if qvals[i] > maxVal then
                maxIdx = i
                maxVal = qvals[i]
            end
        end
        self._lastAction = maxIdx
        return qvals
    end
end

function QLearner:_remember(state, action, reward, next, done)
    self._bufferHead = (self._bufferHead % self._config.memory) + 1
    self._buffer[self._bufferHead] = {
        state  = state,
        action = action,
        reward = reward,
        next   = next,
        done   = done,
    }
    self._bufferSize = math.min(self._bufferSize + 1, self._config.memory)
end

function QLearner:_lesson(data, profile)
    local state  = data.state
    local action = data.action
    local next   = data.next
    local done   = data.done

    local reward = data.reward
    if type(reward) == "string" then
        reward = profile._grade_weights[reward]
        assert(reward, "Worm: reward event '" .. data.reward .. "' not found in grade weights")
    end

    if profile._interpreter then
        state = profile._interpreter(state)
        next  = profile._interpreter(next)
    end
    if profile._config.schema then
        state = normalizeSchema(state, profile._config.schema)
        next  = normalizeSchema(next, profile._config.schema)
    end
    state = toVector(state)
    next  = toVector(next)

    self:_remember(state, action, reward, next, done)
    self._lessonCount += 1

    if self._bufferSize < self._config.batch then
        return 0
    end

    local loss = self:_replay(profile)

    self._epsilon = math.max(
        self._config.epsilon_min,
        self._epsilon * self._config.epsilon_decay
    )

    if self._lessonCount % self._updateEvery == 0 then
        self:_syncTarget()
    end

    return loss
end

function QLearner:_replay(profile)
    local batch  = {}
    local taken  = {}
    local bSize  = self._config.batch

    while #batch < bSize do
        local idx = math.random(1, self._bufferSize)
        if not taken[idx] then
            taken[idx] = true
            table.insert(batch, self._buffer[idx])
        end
    end

    local totalLoss = 0

    for _, exp in ipairs(batch) do
        local currentQ = self._online:_forward(exp.state)
        local nextQ    = self._target:_forward(exp.next)

        local maxNextQ = 0
        for _, v in ipairs(nextQ) do
            if v > maxNextQ then maxNextQ = v end
        end

        local targetQ = table.clone(currentQ)
        if exp.done then
            targetQ[exp.action] = exp.reward
        else
            targetQ[exp.action] = exp.reward + self._config.gamma * maxNextQ
        end

        self._online:_forward(exp.state)
        totalLoss += self._online:_backward(targetQ)
    end

    return totalLoss / bSize
end

function QLearner:_syncTarget()
    local weights = self._online:_exportWeights()
    self._target:_importWeights(weights)
end

function QLearner:_exportWeights()
    return {
        online       = self._online:_exportWeights(),
        target       = self._target:_exportWeights(),
        epsilon      = self._epsilon,
        lesson_count = self._lessonCount,
    }
end

function QLearner:_importWeights(data)
    self._online:_importWeights(data.online)
    self._target:_importWeights(data.target)
    self._epsilon     = data.epsilon
    self._lessonCount = data.lesson_count
end

function QLearner:_reset()
    self._online       = MLP.new(netConfig(self._config))
    self._target       = MLP.new(netConfig(self._config))
    self._target:_importWeights(self._online:_exportWeights())
    self._buffer       = table.create(self._config.memory, nil)
    self._bufferHead   = 0
    self._bufferSize   = 0
    self._epsilon      = self._config.epsilon
    self._lessonCount  = 0
end

return QLearner
]====]
n_Worm_QLearner.Parent = n_Worm

local n_Worm_CSF = Instance.new("ModuleScript")
n_Worm_CSF.Name = "CSF"
n_Worm_CSF.Source = [====[
local MLP = require(script.Parent.MLP)

local CSF = {}
CSF.__index = CSF

local function headConfig(config)
    return {
        inputs            = config.filters,
        outputs           = config.outputs,
        hidden            = { 16 },
        activation        = "relu",
        output_activation = "softmax",
        optimizer         = "adam",
        lr                = 0.001,
    }
end

local function initKernels(config)
    local kernels, biases = {}, {}
    for f = 1, config.filters do
        local kernel = {}
        local std = math.sqrt(2 / (config.kernel * config.kernel))
        for i = 1, config.kernel * config.kernel do
            kernel[i] = (math.random() * 2 - 1) * std
        end
        kernels[f] = kernel
        biases[f]  = 0
    end
    return kernels, biases
end

function CSF.new(config)
    local self = setmetatable({}, CSF)

    self._config           = config
    self._kernels, self._kBiases = initKernels(config)
    self._head              = MLP.new(headConfig(config))
    self._pooled            = {}

    return self
end

function CSF:_forward(input)
    local W, H     = self._config.grid[1], self._config.grid[2]
    local K        = self._config.kernel
    local S        = self._config.stride
    local filters  = self._config.filters
    local outW     = math.floor((W - K) / S) + 1
    local outH     = math.floor((H - K) / S) + 1
    local pooled   = {}

    for f = 1, filters do
        local kernel = self._kernels[f]
        local bias   = self._kBiases[f]
        local fmap   = {}

        for oy = 1, outH do
            for ox = 1, outW do
                local sum = bias
                for ky = 0, K - 1 do
                    for kx = 0, K - 1 do
                        local ix  = (ox - 1) * S + kx + 1
                        local iy  = (oy - 1) * S + ky + 1
                        local idx = (iy - 1) * W + ix
                        local ki  = ky * K + kx + 1
                        sum += input[idx] * kernel[ki]
                    end
                end
                table.insert(fmap, math.max(0, sum))
            end
        end

        if self._config.pool == "max" then
            local m = fmap[1] or 0
            for _, v in ipairs(fmap) do
                if v > m then m = v end
            end
            table.insert(pooled, m)
        else
            local s = 0
            for _, v in ipairs(fmap) do s += v end
            table.insert(pooled, s / #fmap)
        end
    end

    self._pooled = pooled
    return self._head:_forward(pooled)
end

function CSF:_lesson(data, profile)
    local input = data.input
    local label = data.label

    if profile._interpreter then
        input = profile._interpreter(input)
    end

    local output = self:_forward(input)

    profile:labels({ label })
    local targetIdx = profile._label_map[label]
    local target    = {}
    for i = 1, profile._config.outputs do
        target[i] = i == targetIdx and 1 or 0
    end

    self._head:_forward(self._pooled)
    local loss = self._head:_backward(target)
    return loss
end

function CSF:_exportWeights()
    return {
        kernels = table.clone(self._kernels),
        kBiases = table.clone(self._kBiases),
        head    = self._head:_exportWeights(),
    }
end

function CSF:_importWeights(data)
    self._kernels = data.kernels
    self._kBiases = data.kBiases
    self._head:_importWeights(data.head)
end

function CSF:_reset()
    self._kernels, self._kBiases = initKernels(self._config)
    self._head = MLP.new(headConfig(self._config))
end

return CSF
]====]
n_Worm_CSF.Parent = n_Worm

local n_Worm_NEAT = Instance.new("ModuleScript")
n_Worm_NEAT.Name = "NEAT"
n_Worm_NEAT.Source = [====[
local Activations = require(script.Parent.Activations)
local Promise      = require(script.Parent.Promise)
local Util         = require(script.Parent.Util)

local toVector        = Util.toVector
local normalizeSchema = Util.normalizeSchema
local topologicalSort = Util.topologicalSort

local NEAT = {}
NEAT.__index = NEAT

local function newGenome()
    return { nodes = {}, connections = {}, fitness = 0, species_id = nil }
end

function NEAT.new(config)
    local self = setmetatable({}, NEAT)

    self._config      = config
    self._innovation   = 0
    self._innovations  = {}
    self._generation    = 0
    self._champion       = nil
    self._species         = {}
    self._population       = {}

    for _ = 1, config.population do
        table.insert(self._population, self:_createInitialGenome())
    end

    return self
end

function NEAT:_createInitialGenome()
    local genome = newGenome()

    for i = 1, self._config.inputs do
        genome.nodes[i] = { type = "input", id = i }
    end

    local outputStart = self._config.inputs + 1
    for o = 1, self._config.outputs do
        local id = outputStart + o - 1
        genome.nodes[id] = { type = "output", id = id }
    end

    for i = 1, self._config.inputs do
        for o = 1, self._config.outputs do
            local outId = outputStart + o - 1
            local innov = self:_getInnovation(i, outId)
            genome.connections[innov] = {
                in_        = i,
                out        = outId,
                weight     = (math.random() * 2 - 1) * 2,
                enabled    = true,
                innovation = innov,
            }
        end
    end

    return genome
end

function NEAT:_cloneGenome(genome)
    local clone = newGenome()
    clone.fitness = genome.fitness

    for id, node in pairs(genome.nodes) do
        clone.nodes[id] = { type = node.type, id = node.id }
    end
    for innov, conn in pairs(genome.connections) do
        clone.connections[innov] = {
            in_        = conn.in_,
            out        = conn.out,
            weight     = conn.weight,
            enabled    = conn.enabled,
            innovation = conn.innovation,
        }
    end

    return clone
end

function NEAT:_getInnovation(inNode, outNode)
    local key = inNode .. "_" .. outNode
    if not self._innovations[key] then
        self._innovation += 1
        self._innovations[key] = self._innovation
    end
    return self._innovations[key]
end

function NEAT:_compatibility(g1, g2)
    local matching, disjoint, excess = 0, 0, 0
    local weightDiff = 0
    local maxInnov1, maxInnov2 = 0, 0

    for innov in pairs(g1.connections) do
        if innov > maxInnov1 then maxInnov1 = innov end
    end
    for innov in pairs(g2.connections) do
        if innov > maxInnov2 then maxInnov2 = innov end
    end

    local maxShared = math.min(maxInnov1, maxInnov2)

    for innov, conn in pairs(g1.connections) do
        if g2.connections[innov] then
            matching  += 1
            weightDiff += math.abs(conn.weight - g2.connections[innov].weight)
        elseif innov <= maxShared then
            disjoint += 1
        else
            excess += 1
        end
    end

    for innov in pairs(g2.connections) do
        if not g1.connections[innov] then
            if innov <= maxShared then
                disjoint += 1
            else
                excess += 1
            end
        end
    end

    local N    = math.max(#g1.connections, #g2.connections, 1)
    local avgW = matching > 0 and weightDiff / matching or 0

    return (1.0 * excess / N) + (1.0 * disjoint / N) + (0.4 * avgW)
end

function NEAT:_crossover(g1, g2)
    local fitter   = g1.fitness >= g2.fitness and g1 or g2
    local weaker   = fitter == g1 and g2 or g1
    local child    = newGenome()

    for id, node in pairs(fitter.nodes) do
        child.nodes[id] = { type = node.type, id = node.id }
    end

    for innov, conn in pairs(fitter.connections) do
        if weaker.connections[innov] and math.random() < 0.5 then
            child.connections[innov] = {
                in_        = conn.in_,
                out        = conn.out,
                weight     = weaker.connections[innov].weight,
                enabled    = conn.enabled and weaker.connections[innov].enabled,
                innovation = innov,
            }
        else
            child.connections[innov] = {
                in_        = conn.in_,
                out        = conn.out,
                weight     = conn.weight,
                enabled    = conn.enabled,
                innovation = innov,
            }
        end
    end

    return child
end

function NEAT:_mutateWeights(genome)
    for _, conn in pairs(genome.connections) do
        if math.random() < self._config.weight_mutation then
            if math.random() < self._config.weight_perturb then
                conn.weight += (math.random() * 2 - 1) * 0.5
            else
                conn.weight = (math.random() * 2 - 1) * 2
            end
        end
    end
end

function NEAT:_mutateAddConnection(genome)
    local nodeIds = {}
    for id in pairs(genome.nodes) do table.insert(nodeIds, id) end
    local inNode  = nodeIds[math.random(#nodeIds)]
    local outNode = nodeIds[math.random(#nodeIds)]
    if inNode == outNode then return end

    local innov = self:_getInnovation(inNode, outNode)
    if genome.connections[innov] then return end

    genome.connections[innov] = {
        in_        = inNode,
        out        = outNode,
        weight     = (math.random() * 2 - 1) * 2,
        enabled    = true,
        innovation = innov,
    }
end

function NEAT:_mutateAddNode(genome)
    local connList = {}
    for _, c in pairs(genome.connections) do
        if c.enabled then table.insert(connList, c) end
    end
    if #connList == 0 then return end

    local conn    = connList[math.random(#connList)]
    conn.enabled  = false

    local newId   = #genome.nodes + 1
    genome.nodes[newId] = { type = "hidden", id = newId }

    local innov1 = self:_getInnovation(conn.in_, newId)
    local innov2 = self:_getInnovation(newId, conn.out)

    genome.connections[innov1] = {
        in_ = conn.in_, out = newId,
        weight = 1, enabled = true, innovation = innov1,
    }
    genome.connections[innov2] = {
        in_ = newId, out = conn.out,
        weight = conn.weight, enabled = true, innovation = innov2,
    }
end

function NEAT:_genomeForward(genome, input)
    local values = {}
    for i, v in ipairs(input) do
        values[i] = v
    end

    local outputStart = #input + 1
    local outputEnd   = outputStart + self._config.outputs - 1

    local sortedConns = topologicalSort(genome)

    for _, conn in ipairs(sortedConns) do
        if conn.enabled then
            values[conn.out] = (values[conn.out] or 0) + values[conn.in_] * conn.weight
        end
    end

    local result = {}
    for i = outputStart, outputEnd do
        result[i - outputStart + 1] = Activations.sigmoid(values[i] or 0)
    end
    return result
end

function NEAT:_speciate()
    local species = {}
    for _, genome in ipairs(self._population) do
        local placed = false
        for _, sp in ipairs(species) do
            if self:_compatibility(genome, sp.representative) < self._config.species_threshold then
                table.insert(sp.members, genome)
                genome.species_id = sp.id
                placed = true
                break
            end
        end
        if not placed then
            local id = #species + 1
            table.insert(species, { id = id, representative = genome, members = { genome } })
            genome.species_id = id
        end
    end
    self._species = species
end

function NEAT:_fitnessShare()
    for _, sp in ipairs(self._species) do
        local total = 0
        for _, g in ipairs(sp.members) do
            total += g.fitness
        end
        sp.avgFitness = total / #sp.members
    end
end

function NEAT:_findChampion()
    local best = self._population[1]
    for _, g in ipairs(self._population) do
        if g.fitness > best.fitness then
            best = g
        end
    end
    return best
end

function NEAT:_reproduce()
    local totalAvg = 0
    for _, sp in ipairs(self._species) do
        totalAvg += sp.avgFitness
    end
    if totalAvg <= 0 then totalAvg = 1 end

    local popSize       = self._config.population
    local newPopulation = {}

    if self._champion then
        table.insert(newPopulation, self:_cloneGenome(self._champion))
    end

    for _, sp in ipairs(self._species) do
        local share          = sp.avgFitness / totalAvg
        local offspringCount = math.max(1, math.floor(share * popSize))

        for _ = 1, offspringCount do
            if #newPopulation >= popSize then break end

            local parent1 = sp.members[math.random(#sp.members)]
            local parent2 = sp.members[math.random(#sp.members)]
            local child

            if #sp.members > 1 and math.random() < self._config.crossover_rate then
                child = self:_crossover(parent1, parent2)
            else
                child = self:_cloneGenome(parent1)
            end

            if math.random() < self._config.mutation_rate then
                self:_mutateWeights(child)
                if math.random() < 0.05 then
                    self:_mutateAddConnection(child)
                end
                if math.random() < 0.03 then
                    self:_mutateAddNode(child)
                end
            end

            child.fitness = 0
            table.insert(newPopulation, child)
        end
    end

    while #newPopulation < popSize do
        local parent = self._population[math.random(#self._population)]
        table.insert(newPopulation, self:_cloneGenome(parent))
    end

    while #newPopulation > popSize do
        table.remove(newPopulation)
    end

    self._population = newPopulation
end

function NEAT:_lesson(data, profile)
    local gens      = data.generations or 1
    local evaluate  = data.evaluate
    local on_evolve = data.on_evolve

    local best

    for g = 1, gens do
        for _, genome in ipairs(self._population) do
            local genomeProfile = self:_wrapGenome(genome, profile)
            genome.fitness = evaluate(genomeProfile)
        end

        self:_speciate()
        self:_fitnessShare()

        best = self:_findChampion()
        self._champion = best

        if on_evolve then
            on_evolve(self._generation, {
                fitness = best.fitness,
                genome  = self:_wrapGenome(best, profile),
            })
        end

        self:_reproduce()
        self._generation += 1
    end

    return self:_wrapGenome(best, profile)
end

function NEAT:_wrapGenome(genome, profile)
    return {
        infer = function(_, input)
            local prepared = input
            if profile._interpreter then
                prepared = profile._interpreter(input)
            end
            if profile._config.schema then
                prepared = normalizeSchema(prepared, profile._config.schema)
            end
            local vec = toVector(prepared)
            return Promise.resolve(self:_genomeForward(genome, vec))
        end,
        export = function()
            return { genome = genome, config = profile._config }
        end,
        fitness = genome.fitness,
    }
end

function NEAT:_forward(vec)
    assert(self._champion, "Worm: no champion yet -- run lesson() first")
    return self:_genomeForward(self._champion, vec)
end

function NEAT:evolve(profile)
    return Promise.new(function(resolve)
        self:_speciate()
        self:_fitnessShare()
        self:_reproduce()
        self._generation += 1
        resolve({
            generation    = self._generation,
            best_fitness  = self._champion and self._champion.fitness or 0,
            species_count = #self._species,
        })
    end)
end

function NEAT:champion(profile)
    assert(self._champion, "Worm: no champion yet -- run lesson() first")
    return self:_wrapGenome(self._champion, profile)
end

function NEAT:_exportWeights()
    if self._config.persist then
        return {
            neat_population = self._population,
            innovation      = self._innovation,
            innovations     = self._innovations,
            generation      = self._generation,
            champion        = self._champion,
        }
    else
        return {
            champion   = self._champion,
            generation = self._generation,
        }
    end
end

function NEAT:_importWeights(data)
    self._champion   = data.champion
    self._generation = data.generation or 0
    if data.neat_population then
        self._population = data.neat_population
    end
    if data.innovation then
        self._innovation  = data.innovation
        self._innovations = data.innovations or {}
    end
end

function NEAT:_reset()
    self._innovation  = 0
    self._innovations = {}
    self._generation  = 0
    self._champion     = nil
    self._species       = {}
    self._population     = {}
    for _ = 1, self._config.population do
        table.insert(self._population, self:_createInitialGenome())
    end
end

return NEAT
]====]
n_Worm_NEAT.Parent = n_Worm

local n_Worm__Libraries = Instance.new("Folder")
n_Worm__Libraries.Name = "_Libraries"
n_Worm__Libraries.Parent = n_Worm

local n_Worm__Libraries_Promise = Instance.new("ModuleScript")
n_Worm__Libraries_Promise.Name = "Promise"
n_Worm__Libraries_Promise.Source = [====[
--[[
	An implementation of Promises similar to Promise/A+.
]]

local ERROR_NON_PROMISE_IN_LIST = "Non-promise value passed into %s at index %s"
local ERROR_NON_LIST = "Please pass a list of promises to %s"
local ERROR_NON_FUNCTION = "Please pass a handler function to %s!"
local MODE_KEY_METATABLE = { __mode = "k" }

local function isCallable(value)
	if type(value) == "function" then
		return true
	end

	if type(value) == "table" then
		local metatable = getmetatable(value)
		if metatable and type(rawget(metatable, "__call")) == "function" then
			return true
		end
	end

	return false
end

--[[
	Creates an enum dictionary with some metamethods to prevent common mistakes.
]]
local function makeEnum(enumName, members)
	local enum = {}

	for _, memberName in ipairs(members) do
		enum[memberName] = memberName
	end

	return setmetatable(enum, {
		__index = function(_, k)
			error(string.format("%s is not in %s!", k, enumName), 2)
		end,
		__newindex = function()
			error(string.format("Creating new members in %s is not allowed!", enumName), 2)
		end,
	})
end

--[=[
	An object to represent runtime errors that occur during execution.
	Promises that experience an error like this will be rejected with
	an instance of this object.

	@class Error
]=]
local Error
do
	Error = {
		Kind = makeEnum("Promise.Error.Kind", {
			"ExecutionError",
			"AlreadyCancelled",
			"NotResolvedInTime",
			"TimedOut",
		}),
	}
	Error.__index = Error

	function Error.new(options, parent)
		options = options or {}
		return setmetatable({
			error = tostring(options.error) or "[This error has no error text.]",
			trace = options.trace,
			context = options.context,
			kind = options.kind,
			parent = parent,
			createdTick = os.clock(),
			createdTrace = debug.traceback(),
		}, Error)
	end

	function Error.is(anything)
		if type(anything) == "table" then
			local metatable = getmetatable(anything)

			if type(metatable) == "table" then
				return rawget(anything, "error") ~= nil and type(rawget(metatable, "extend")) == "function"
			end
		end

		return false
	end

	function Error.isKind(anything, kind)
		assert(kind ~= nil, "Argument #2 to Promise.Error.isKind must not be nil")

		return Error.is(anything) and anything.kind == kind
	end

	function Error:extend(options)
		options = options or {}

		options.kind = options.kind or self.kind

		return Error.new(options, self)
	end

	function Error:getErrorChain()
		local runtimeErrors = { self }

		while runtimeErrors[#runtimeErrors].parent do
			table.insert(runtimeErrors, runtimeErrors[#runtimeErrors].parent)
		end

		return runtimeErrors
	end

	function Error:__tostring()
		local errorStrings = {
			string.format("-- Promise.Error(%s) --", self.kind or "?"),
		}

		for _, runtimeError in ipairs(self:getErrorChain()) do
			table.insert(
				errorStrings,
				table.concat({
					runtimeError.trace or runtimeError.error,
					runtimeError.context,
				}, "\n")
			)
		end

		return table.concat(errorStrings, "\n")
	end
end

--[[
	Packs a number of arguments into a table and returns its length.

	Used to cajole varargs without dropping sparse values.
]]
local function pack(...)
	return select("#", ...), { ... }
end

--[[
	Returns first value (success), and packs all following values.
]]
local function packResult(success, ...)
	return success, select("#", ...), { ... }
end

local function makeErrorHandler(traceback)
	assert(traceback ~= nil, "traceback is nil")

	return function(err)
		-- If the error object is already a table, forward it directly.
		-- Should we extend the error here and add our own trace?

		if type(err) == "table" then
			return err
		end

		return Error.new({
			error = err,
			kind = Error.Kind.ExecutionError,
			trace = debug.traceback(tostring(err), 2),
			context = "Promise created at:\n\n" .. traceback,
		})
	end
end

--[[
	Calls a Promise executor with error handling.
]]
local function runExecutor(traceback, callback, ...)
	return packResult(xpcall(callback, makeErrorHandler(traceback), ...))
end

--[[
	Creates a function that invokes a callback with correct error handling and
	resolution mechanisms.
]]
local function createAdvancer(traceback, callback, resolve, reject)
	return function(...)
		local ok, resultLength, result = runExecutor(traceback, callback, ...)

		if ok then
			resolve(unpack(result, 1, resultLength))
		else
			reject(result[1])
		end
	end
end

local function isEmpty(t)
	return next(t) == nil
end

--[=[
	An enum value used to represent the Promise's status.
	@interface Status
	@tag enum
	@within Promise
	.Started "Started" -- The Promise is executing, and not settled yet.
	.Resolved "Resolved" -- The Promise finished successfully.
	.Rejected "Rejected" -- The Promise was rejected.
	.Cancelled "Cancelled" -- The Promise was cancelled before it finished.
]=]
--[=[
	@prop Status Status
	@within Promise
	@readonly
	@tag enums
	A table containing all members of the `Status` enum, e.g., `Promise.Status.Resolved`.
]=]
--[=[
	A Promise is an object that represents a value that will exist in the future, but doesn't right now.
	Promises allow you to then attach callbacks that can run once the value becomes available (known as *resolving*),
	or if an error has occurred (known as *rejecting*).

	@class Promise
	@__index prototype
]=]
local Promise = {
	Error = Error,
	Status = makeEnum("Promise.Status", { "Started", "Resolved", "Rejected", "Cancelled" }),
	_getTime = os.clock,
	_timeEvent = game:GetService("RunService").Heartbeat,
	_unhandledRejectionCallbacks = {},
}
Promise.prototype = {}
Promise.__index = Promise.prototype

function Promise._new(traceback, callback, parent)
	if parent ~= nil and not Promise.is(parent) then
		error("Argument #2 to Promise.new must be a promise or nil", 2)
	end

	local self = {
		-- The executor thread.
		_thread = nil,

		-- Used to locate where a promise was created
		_source = traceback,

		_status = Promise.Status.Started,

		-- A table containing a list of all results, whether success or failure.
		-- Only valid if _status is set to something besides Started
		_values = nil,

		-- Lua doesn't like sparse arrays very much, so we explicitly store the
		-- length of _values to handle middle nils.
		_valuesLength = -1,

		-- Tracks if this Promise has no error observers..
		_unhandledRejection = true,

		-- Queues representing functions we should invoke when we update!
		_queuedResolve = {},
		_queuedReject = {},
		_queuedFinally = {},

		-- The function to run when/if this promise is cancelled.
		_cancellationHook = nil,

		-- The "parent" of this promise in a promise chain. Required for
		-- cancellation propagation upstream.
		_parent = parent,

		-- Consumers are Promises that have chained onto this one.
		-- We track them for cancellation propagation downstream.
		_consumers = setmetatable({}, MODE_KEY_METATABLE),
	}

	if parent and parent._status == Promise.Status.Started then
		parent._consumers[self] = true
	end

	setmetatable(self, Promise)

	local function resolve(...)
		self:_resolve(...)
	end

	local function reject(...)
		self:_reject(...)
	end

	local function onCancel(cancellationHook)
		if cancellationHook then
			if self._status == Promise.Status.Cancelled then
				cancellationHook()
			else
				self._cancellationHook = cancellationHook
			end
		end

		return self._status == Promise.Status.Cancelled
	end

	self._thread = coroutine.create(function()
		local ok, _, result = runExecutor(self._source, callback, resolve, reject, onCancel)

		if not ok then
			reject(result[1])
		end
	end)

	task.spawn(self._thread)

	return self
end

--[=[
	Construct a new Promise that will be resolved or rejected with the given callbacks.

	If you `resolve` with a Promise, it will be chained onto.

	You can safely yield within the executor function and it will not block the creating thread.

	```lua
	local myFunction()
		return Promise.new(function(resolve, reject, onCancel)
			wait(1)
			resolve("Hello world!")
		end)
	end

	myFunction():andThen(print)
	```

	You do not need to use `pcall` within a Promise. Errors that occur during execution will be caught and turned into a rejection automatically. If `error()` is called with a table, that table will be the rejection value. Otherwise, string errors will be converted into `Promise.Error(Promise.Error.Kind.ExecutionError)` objects for tracking debug information.

	You may register an optional cancellation hook by using the `onCancel` argument:

	* This should be used to abort any ongoing operations leading up to the promise being settled.
	* Call the `onCancel` function with a function callback as its only argument to set a hook which will in turn be called when/if the promise is cancelled.
	* `onCancel` returns `true` if the Promise was already cancelled when you called `onCancel`.
	* Calling `onCancel` with no argument will not override a previously set cancellation hook, but it will still return `true` if the Promise is currently cancelled.
	* You can set the cancellation hook at any time before resolving.
	* When a promise is cancelled, calls to `resolve` or `reject` will be ignored, regardless of if you set a cancellation hook or not.

	:::caution
	If the Promise is cancelled, the `executor` thread is closed with `coroutine.close` after the cancellation hook is called.

	You must perform any cleanup code in the cancellation hook: any time your executor yields, it **may never resume**.
	:::

	@param executor (resolve: (...: any) -> (), reject: (...: any) -> (), onCancel: (abortHandler?: () -> ()) -> boolean) -> ()
	@return Promise
]=]
function Promise.new(executor)
	return Promise._new(debug.traceback(nil, 2), executor)
end

function Promise:__tostring()
	return string.format("Promise(%s)", self._status)
end

--[=[
	The same as [Promise.new](/api/Promise#new), except execution begins after the next `Heartbeat` event.

	This is a spiritual replacement for `spawn`, but it does not suffer from the same [issues](https://eryn.io/gist/3db84579866c099cdd5bb2ff37947cec) as `spawn`.

	```lua
	local function waitForChild(instance, childName, timeout)
	  return Promise.defer(function(resolve, reject)
		local child = instance:WaitForChild(childName, timeout)

		;(child and resolve or reject)(child)
	  end)
	end
	```

	@param executor (resolve: (...: any) -> (), reject: (...: any) -> (), onCancel: (abortHandler?: () -> ()) -> boolean) -> ()
	@return Promise
]=]
function Promise.defer(executor)
	local traceback = debug.traceback(nil, 2)
	local promise
	promise = Promise._new(traceback, function(resolve, reject, onCancel)
		task.defer(function()
			local ok, _, result = runExecutor(traceback, executor, resolve, reject, onCancel)

			if not ok then
				reject(result[1])
			end
		end)
	end)

	return promise
end

-- Backwards compatibility
Promise.async = Promise.defer

--[=[
	Creates an immediately resolved Promise with the given value.

	```lua
	-- Example using Promise.resolve to deliver cached values:
	function getSomething(name)
		if cache[name] then
			return Promise.resolve(cache[name])
		else
			return Promise.new(function(resolve, reject)
				local thing = getTheThing()
				cache[name] = thing

				resolve(thing)
			end)
		end
	end
	```

	@param ... any
	@return Promise<...any>
]=]
function Promise.resolve(...)
	local length, values = pack(...)
	return Promise._new(debug.traceback(nil, 2), function(resolve)
		resolve(unpack(values, 1, length))
	end)
end

--[=[
	Creates an immediately rejected Promise with the given value.

	:::caution
	Something needs to consume this rejection (i.e. `:catch()` it), otherwise it will emit an unhandled Promise rejection warning on the next frame. Thus, you should not create and store rejected Promises for later use. Only create them on-demand as needed.
	:::

	@param ... any
	@return Promise<...any>
]=]
function Promise.reject(...)
	local length, values = pack(...)
	return Promise._new(debug.traceback(nil, 2), function(_, reject)
		reject(unpack(values, 1, length))
	end)
end

--[[
	Runs a non-promise-returning function as a Promise with the
  given arguments.
]]
function Promise._try(traceback, callback, ...)
	local valuesLength, values = pack(...)

	return Promise._new(traceback, function(resolve)
		resolve(callback(unpack(values, 1, valuesLength)))
	end)
end

--[=[
	Begins a Promise chain, calling a function and returning a Promise resolving with its return value. If the function errors, the returned Promise will be rejected with the error. You can safely yield within the Promise.try callback.

	:::info
	`Promise.try` is similar to [Promise.promisify](#promisify), except the callback is invoked immediately instead of returning a new function.
	:::

	```lua
	Promise.try(function()
		return math.random(1, 2) == 1 and "ok" or error("Oh an error!")
	end)
		:andThen(function(text)
			print(text)
		end)
		:catch(function(err)
			warn("Something went wrong")
		end)
	```

	@param callback (...: T...) -> ...any
	@param ... T... -- Additional arguments passed to `callback`
	@return Promise
]=]
function Promise.try(callback, ...)
	return Promise._try(debug.traceback(nil, 2), callback, ...)
end

--[[
	Returns a new promise that:
		* is resolved when all input promises resolve
		* is rejected if ANY input promises reject
]]
function Promise._all(traceback, promises, amount)
	if type(promises) ~= "table" then
		error(string.format(ERROR_NON_LIST, "Promise.all"), 3)
	end

	-- We need to check that each value is a promise here so that we can produce
	-- a proper error rather than a rejected promise with our error.
	for i, promise in pairs(promises) do
		if not Promise.is(promise) then
			error(string.format(ERROR_NON_PROMISE_IN_LIST, "Promise.all", tostring(i)), 3)
		end
	end

	-- If there are no values then return an already resolved promise.
	if #promises == 0 or amount == 0 then
		return Promise.resolve({})
	end

	return Promise._new(traceback, function(resolve, reject, onCancel)
		-- An array to contain our resolved values from the given promises.
		local resolvedValues = {}
		local newPromises = {}

		-- Keep a count of resolved promises because just checking the resolved
		-- values length wouldn't account for promises that resolve with nil.
		local resolvedCount = 0
		local rejectedCount = 0
		local done = false

		local function cancel()
			for _, promise in ipairs(newPromises) do
				promise:cancel()
			end
		end

		-- Called when a single value is resolved and resolves if all are done.
		local function resolveOne(i, ...)
			if done then
				return
			end

			resolvedCount = resolvedCount + 1

			if amount == nil then
				resolvedValues[i] = ...
			else
				resolvedValues[resolvedCount] = ...
			end

			if resolvedCount >= (amount or #promises) then
				done = true
				resolve(resolvedValues)
				cancel()
			end
		end

		onCancel(cancel)

		-- We can assume the values inside `promises` are all promises since we
		-- checked above.
		for i, promise in ipairs(promises) do
			newPromises[i] = promise:andThen(function(...)
				resolveOne(i, ...)
			end, function(...)
				rejectedCount = rejectedCount + 1

				if amount == nil or #promises - rejectedCount < amount then
					cancel()
					done = true

					reject(...)
				end
			end)
		end

		if done then
			cancel()
		end
	end)
end

--[=[
	Accepts an array of Promises and returns a new promise that:
	* is resolved after all input promises resolve.
	* is rejected if *any* input promises reject.

	:::info
	Only the first return value from each promise will be present in the resulting array.
	:::

	After any input Promise rejects, all other input Promises that are still pending will be cancelled if they have no other consumers.

	```lua
	local promises = {
		returnsAPromise("example 1"),
		returnsAPromise("example 2"),
		returnsAPromise("example 3"),
	}

	return Promise.all(promises)
	```

	@param promises {Promise<T>}
	@return Promise<{T}>
]=]
function Promise.all(promises)
	return Promise._all(debug.traceback(nil, 2), promises)
end

--[=[
	Folds an array of values or promises into a single value. The array is traversed sequentially.

	The reducer function can return a promise or value directly. Each iteration receives the resolved value from the previous, and the first receives your defined initial value.

	The folding will stop at the first rejection encountered.
	```lua
	local basket = {"blueberry", "melon", "pear", "melon"}
	Promise.fold(basket, function(cost, fruit)
		if fruit == "blueberry" then
			return cost -- blueberries are free!
		else
			-- call a function that returns a promise with the fruit price
			return fetchPrice(fruit):andThen(function(fruitCost)
				return cost + fruitCost
			end)
		end
	end, 0)
	```

	@since v3.1.0
	@param list {T | Promise<T>}
	@param reducer (accumulator: U, value: T, index: number) -> U | Promise<U>
	@param initialValue U
]=]
function Promise.fold(list, reducer, initialValue)
	assert(type(list) == "table", "Bad argument #1 to Promise.fold: must be a table")
	assert(isCallable(reducer), "Bad argument #2 to Promise.fold: must be a function")

	local accumulator = Promise.resolve(initialValue)
	return Promise.each(list, function(resolvedElement, i)
		accumulator = accumulator:andThen(function(previousValueResolved)
			return reducer(previousValueResolved, resolvedElement, i)
		end)
	end):andThen(function()
		return accumulator
	end)
end

--[=[
	Accepts an array of Promises and returns a Promise that is resolved as soon as `count` Promises are resolved from the input array. The resolved array values are in the order that the Promises resolved in. When this Promise resolves, all other pending Promises are cancelled if they have no other consumers.

	`count` 0 results in an empty array. The resultant array will never have more than `count` elements.

	```lua
	local promises = {
		returnsAPromise("example 1"),
		returnsAPromise("example 2"),
		returnsAPromise("example 3"),
	}

	return Promise.some(promises, 2) -- Only resolves with first 2 promises to resolve
	```

	@param promises {Promise<T>}
	@param count number
	@return Promise<{T}>
]=]
function Promise.some(promises, count)
	assert(type(count) == "number", "Bad argument #2 to Promise.some: must be a number")

	return Promise._all(debug.traceback(nil, 2), promises, count)
end

--[=[
	Accepts an array of Promises and returns a Promise that is resolved as soon as *any* of the input Promises resolves. It will reject only if *all* input Promises reject. As soon as one Promises resolves, all other pending Promises are cancelled if they have no other consumers.

	Resolves directly with the value of the first resolved Promise. This is essentially [[Promise.some]] with `1` count, except the Promise resolves with the value directly instead of an array with one element.

	```lua
	local promises = {
		returnsAPromise("example 1"),
		returnsAPromise("example 2"),
		returnsAPromise("example 3"),
	}

	return Promise.any(promises) -- Resolves with first value to resolve (only rejects if all 3 rejected)
	```

	@param promises {Promise<T>}
	@return Promise<T>
]=]
function Promise.any(promises)
	return Promise._all(debug.traceback(nil, 2), promises, 1):andThen(function(values)
		return values[1]
	end)
end

--[=[
	Accepts an array of Promises and returns a new Promise that resolves with an array of in-place Statuses when all input Promises have settled. This is equivalent to mapping `promise:finally` over the array of Promises.

	```lua
	local promises = {
		returnsAPromise("example 1"),
		returnsAPromise("example 2"),
		returnsAPromise("example 3"),
	}

	return Promise.allSettled(promises)
	```

	@param promises {Promise<T>}
	@return Promise<{Status}>
]=]
function Promise.allSettled(promises)
	if type(promises) ~= "table" then
		error(string.format(ERROR_NON_LIST, "Promise.allSettled"), 2)
	end

	-- We need to check that each value is a promise here so that we can produce
	-- a proper error rather than a rejected promise with our error.
	for i, promise in pairs(promises) do
		if not Promise.is(promise) then
			error(string.format(ERROR_NON_PROMISE_IN_LIST, "Promise.allSettled", tostring(i)), 2)
		end
	end

	-- If there are no values then return an already resolved promise.
	if #promises == 0 then
		return Promise.resolve({})
	end

	return Promise._new(debug.traceback(nil, 2), function(resolve, _, onCancel)
		-- An array to contain our resolved values from the given promises.
		local fates = {}
		local newPromises = {}

		-- Keep a count of resolved promises because just checking the resolved
		-- values length wouldn't account for promises that resolve with nil.
		local finishedCount = 0

		-- Called when a single value is resolved and resolves if all are done.
		local function resolveOne(i, ...)
			finishedCount = finishedCount + 1

			fates[i] = ...

			if finishedCount >= #promises then
				resolve(fates)
			end
		end

		onCancel(function()
			for _, promise in ipairs(newPromises) do
				promise:cancel()
			end
		end)

		-- We can assume the values inside `promises` are all promises since we
		-- checked above.
		for i, promise in ipairs(promises) do
			newPromises[i] = promise:finally(function(...)
				resolveOne(i, ...)
			end)
		end
	end)
end

--[=[
	Accepts an array of Promises and returns a new promise that is resolved or rejected as soon as any Promise in the array resolves or rejects.

	:::warning
	If the first Promise to settle from the array settles with a rejection, the resulting Promise from `race` will reject.

	If you instead want to tolerate rejections, and only care about at least one Promise resolving, you should use [Promise.any](#any) or [Promise.some](#some) instead.
	:::

	All other Promises that don't win the race will be cancelled if they have no other consumers.

	```lua
	local promises = {
		returnsAPromise("example 1"),
		returnsAPromise("example 2"),
		returnsAPromise("example 3"),
	}

	return Promise.race(promises) -- Only returns 1st value to resolve or reject
	```

	@param promises {Promise<T>}
	@return Promise<T>
]=]
function Promise.race(promises)
	assert(type(promises) == "table", string.format(ERROR_NON_LIST, "Promise.race"))

	for i, promise in pairs(promises) do
		assert(Promise.is(promise), string.format(ERROR_NON_PROMISE_IN_LIST, "Promise.race", tostring(i)))
	end

	return Promise._new(debug.traceback(nil, 2), function(resolve, reject, onCancel)
		local newPromises = {}
		local finished = false

		local function cancel()
			for _, promise in ipairs(newPromises) do
				promise:cancel()
			end
		end

		local function finalize(callback)
			return function(...)
				cancel()
				finished = true
				return callback(...)
			end
		end

		if onCancel(finalize(reject)) then
			return
		end

		for i, promise in ipairs(promises) do
			newPromises[i] = promise:andThen(finalize(resolve), finalize(reject))
		end

		if finished then
			cancel()
		end
	end)
end

--[=[
	Iterates serially over the given an array of values, calling the predicate callback on each value before continuing.

	If the predicate returns a Promise, we wait for that Promise to resolve before moving on to the next item
	in the array.

	:::info
	`Promise.each` is similar to `Promise.all`, except the Promises are ran in order instead of all at once.

	But because Promises are eager, by the time they are created, they're already running. Thus, we need a way to defer creation of each Promise until a later time.

	The predicate function exists as a way for us to operate on our data instead of creating a new closure for each Promise. If you would prefer, you can pass in an array of functions, and in the predicate, call the function and return its return value.
	:::

	```lua
	Promise.each({
		"foo",
		"bar",
		"baz",
		"qux"
	}, function(value, index)
		return Promise.delay(1):andThen(function()
		print(("%d) Got %s!"):format(index, value))
		end)
	end)

	--[[
		(1 second passes)
		> 1) Got foo!
		(1 second passes)
		> 2) Got bar!
		(1 second passes)
		> 3) Got baz!
		(1 second passes)
		> 4) Got qux!
	]]
	```

	If the Promise a predicate returns rejects, the Promise from `Promise.each` is also rejected with the same value.

	If the array of values contains a Promise, when we get to that point in the list, we wait for the Promise to resolve before calling the predicate with the value.

	If a Promise in the array of values is already Rejected when `Promise.each` is called, `Promise.each` rejects with that value immediately (the predicate callback will never be called even once). If a Promise in the list is already Cancelled when `Promise.each` is called, `Promise.each` rejects with `Promise.Error(Promise.Error.Kind.AlreadyCancelled`). If a Promise in the array of values is Started at first, but later rejects, `Promise.each` will reject with that value and iteration will not continue once iteration encounters that value.

	Returns a Promise containing an array of the returned/resolved values from the predicate for each item in the array of values.

	If this Promise returned from `Promise.each` rejects or is cancelled for any reason, the following are true:
	- Iteration will not continue.
	- Any Promises within the array of values will now be cancelled if they have no other consumers.
	- The Promise returned from the currently active predicate will be cancelled if it hasn't resolved yet.

	@since 3.0.0
	@param list {T | Promise<T>}
	@param predicate (value: T, index: number) -> U | Promise<U>
	@return Promise<{U}>
]=]
function Promise.each(list, predicate)
	assert(type(list) == "table", string.format(ERROR_NON_LIST, "Promise.each"))
	assert(isCallable(predicate), string.format(ERROR_NON_FUNCTION, "Promise.each"))

	return Promise._new(debug.traceback(nil, 2), function(resolve, reject, onCancel)
		local results = {}
		local promisesToCancel = {}

		local cancelled = false

		local function cancel()
			for _, promiseToCancel in ipairs(promisesToCancel) do
				promiseToCancel:cancel()
			end
		end

		onCancel(function()
			cancelled = true

			cancel()
		end)

		-- We need to preprocess the list of values and look for Promises.
		-- If we find some, we must register our andThen calls now, so that those Promises have a consumer
		-- from us registered. If we don't do this, those Promises might get cancelled by something else
		-- before we get to them in the series because it's not possible to tell that we plan to use it
		-- unless we indicate it here.

		local preprocessedList = {}

		for index, value in ipairs(list) do
			if Promise.is(value) then
				if value:getStatus() == Promise.Status.Cancelled then
					cancel()
					return reject(Error.new({
						error = "Promise is cancelled",
						kind = Error.Kind.AlreadyCancelled,
						context = string.format(
							"The Promise that was part of the array at index %d passed into Promise.each was already cancelled when Promise.each began.\n\nThat Promise was created at:\n\n%s",
							index,
							value._source
						),
					}))
				elseif value:getStatus() == Promise.Status.Rejected then
					cancel()
					return reject(select(2, value:await()))
				end

				-- Chain a new Promise from this one so we only cancel ours
				local ourPromise = value:andThen(function(...)
					return ...
				end)

				table.insert(promisesToCancel, ourPromise)
				preprocessedList[index] = ourPromise
			else
				preprocessedList[index] = value
			end
		end

		for index, value in ipairs(preprocessedList) do
			if Promise.is(value) then
				local success
				success, value = value:await()

				if not success then
					cancel()
					return reject(value)
				end
			end

			if cancelled then
				return
			end

			local predicatePromise = Promise.resolve(predicate(value, index))

			table.insert(promisesToCancel, predicatePromise)

			local success, result = predicatePromise:await()

			if not success then
				cancel()
				return reject(result)
			end

			results[index] = result
		end

		resolve(results)
	end)
end

--[=[
	Checks whether the given object is a Promise via duck typing. This only checks if the object is a table and has an `andThen` method.

	@param object any
	@return boolean -- `true` if the given `object` is a Promise.
]=]
function Promise.is(object)
	if type(object) ~= "table" then
		return false
	end

	local objectMetatable = getmetatable(object)

	if objectMetatable == Promise then
		-- The Promise came from this library.
		return true
	elseif objectMetatable == nil then
		-- No metatable, but we should still chain onto tables with andThen methods
		return isCallable(object.andThen)
	elseif
		type(objectMetatable) == "table"
		and type(rawget(objectMetatable, "__index")) == "table"
		and isCallable(rawget(rawget(objectMetatable, "__index"), "andThen"))
	then
		-- Maybe this came from a different or older Promise library.
		return true
	end

	return false
end

--[=[
	Wraps a function that yields into one that returns a Promise.

	Any errors that occur while executing the function will be turned into rejections.

	:::info
	`Promise.promisify` is similar to [Promise.try](#try), except the callback is returned as a callable function instead of being invoked immediately.
	:::

	```lua
	local sleep = Promise.promisify(wait)

	sleep(1):andThen(print)
	```

	```lua
	local isPlayerInGroup = Promise.promisify(function(player, groupId)
		return player:IsInGroup(groupId)
	end)
	```

	@param callback (...: any) -> ...any
	@return (...: any) -> Promise
]=]
function Promise.promisify(callback)
	return function(...)
		return Promise._try(debug.traceback(nil, 2), callback, ...)
	end
end

--[=[
	Returns a Promise that resolves after `seconds` seconds have passed. The Promise resolves with the actual amount of time that was waited.

	This function is a wrapper around `task.delay`.

	:::warning
	Passing NaN, +Infinity, -Infinity, 0, or any other number less than the duration of a Heartbeat will cause the promise to resolve on the very next Heartbeat.
	:::

	```lua
		Promise.delay(5):andThenCall(print, "This prints after 5 seconds")
	```

	@function delay
	@within Promise
	@param seconds number
	@return Promise<number>
]=]
function Promise.delay(seconds)
	assert(type(seconds) == "number", "Bad argument #1 to Promise.delay, must be a number.")
	local startTime = Promise._getTime()
	return Promise._new(debug.traceback(nil, 2), function(resolve)
		task.delay(seconds, function()
			resolve(Promise._getTime() - startTime)
		end)
	end)
end

--[=[
	Returns a new Promise that resolves if the chained Promise resolves within `seconds` seconds, or rejects if execution time exceeds `seconds`. The chained Promise will be cancelled if the timeout is reached.

	Rejects with `rejectionValue` if it is non-nil. If a `rejectionValue` is not given, it will reject with a `Promise.Error(Promise.Error.Kind.TimedOut)`. This can be checked with [[Error.isKind]].

	```lua
	getSomething():timeout(5):andThen(function(something)
		-- got something and it only took at max 5 seconds
	end):catch(function(e)
		-- Either getting something failed or the time was exceeded.

		if Promise.Error.isKind(e, Promise.Error.Kind.TimedOut) then
			warn("Operation timed out!")
		else
			warn("Operation encountered an error!")
		end
	end)
	```

	Sugar for:

	```lua
	Promise.race({
		Promise.delay(seconds):andThen(function()
			return Promise.reject(
				rejectionValue == nil
				and Promise.Error.new({ kind = Promise.Error.Kind.TimedOut })
				or rejectionValue
			)
		end),
		promise
	})
	```

	@param seconds number
	@param rejectionValue? any -- The value to reject with if the timeout is reached
	@return Promise
]=]
function Promise.prototype:timeout(seconds, rejectionValue)
	local traceback = debug.traceback(nil, 2)

	return Promise.race({
		Promise.delay(seconds):andThen(function()
			return Promise.reject(rejectionValue == nil and Error.new({
				kind = Error.Kind.TimedOut,
				error = "Timed out",
				context = string.format(
					"Timeout of %d seconds exceeded.\n:timeout() called at:\n\n%s",
					seconds,
					traceback
				),
			}) or rejectionValue)
		end),
		self,
	})
end

--[=[
	Returns the current Promise status.

	@return Status
]=]
function Promise.prototype:getStatus()
	return self._status
end

--[[
	Creates a new promise that receives the result of this promise.

	The given callbacks are invoked depending on that result.
]]
function Promise.prototype:_andThen(traceback, successHandler, failureHandler)
	self._unhandledRejection = false

	-- If we are already cancelled, we return a cancelled Promise
	if self._status == Promise.Status.Cancelled then
		local promise = Promise.new(function() end)
		promise:cancel()

		return promise
	end

	-- Create a new promise to follow this part of the chain
	return Promise._new(traceback, function(resolve, reject, onCancel)
		-- Our default callbacks just pass values onto the next promise.
		-- This lets success and failure cascade correctly!

		local successCallback = resolve
		if successHandler then
			successCallback = createAdvancer(traceback, successHandler, resolve, reject)
		end

		local failureCallback = reject
		if failureHandler then
			failureCallback = createAdvancer(traceback, failureHandler, resolve, reject)
		end

		if self._status == Promise.Status.Started then
			-- If we haven't resolved yet, put ourselves into the queue
			table.insert(self._queuedResolve, successCallback)
			table.insert(self._queuedReject, failureCallback)

			onCancel(function()
				-- These are guaranteed to exist because the cancellation handler is guaranteed to only
				-- be called at most once
				if self._status == Promise.Status.Started then
					table.remove(self._queuedResolve, table.find(self._queuedResolve, successCallback))
					table.remove(self._queuedReject, table.find(self._queuedReject, failureCallback))
				end
			end)
		elseif self._status == Promise.Status.Resolved then
			-- This promise has already resolved! Trigger success immediately.
			successCallback(unpack(self._values, 1, self._valuesLength))
		elseif self._status == Promise.Status.Rejected then
			-- This promise died a terrible death! Trigger failure immediately.
			failureCallback(unpack(self._values, 1, self._valuesLength))
		end
	end, self)
end

--[=[
	Chains onto an existing Promise and returns a new Promise.

	:::warning
	Within the failure handler, you should never assume that the rejection value is a string. Some rejections within the Promise library are represented by [[Error]] objects. If you want to treat it as a string for debugging, you should call `tostring` on it first.
	:::

	You can return a Promise from the success or failure handler and it will be chained onto.

	Calling `andThen` on a cancelled Promise returns a cancelled Promise.

	:::tip
	If the Promise returned by `andThen` is cancelled, `successHandler` and `failureHandler` will not run.

	To run code no matter what, use [Promise:finally].
	:::

	@param successHandler (...: any) -> ...any
	@param failureHandler? (...: any) -> ...any
	@return Promise<...any>
]=]
function Promise.prototype:andThen(successHandler, failureHandler)
	assert(successHandler == nil or isCallable(successHandler), string.format(ERROR_NON_FUNCTION, "Promise:andThen"))
	assert(failureHandler == nil or isCallable(failureHandler), string.format(ERROR_NON_FUNCTION, "Promise:andThen"))

	return self:_andThen(debug.traceback(nil, 2), successHandler, failureHandler)
end

--[=[
	Shorthand for `Promise:andThen(nil, failureHandler)`.

	Returns a Promise that resolves if the `failureHandler` worked without encountering an additional error.

	:::warning
	Within the failure handler, you should never assume that the rejection value is a string. Some rejections within the Promise library are represented by [[Error]] objects. If you want to treat it as a string for debugging, you should call `tostring` on it first.
	:::

	Calling `catch` on a cancelled Promise returns a cancelled Promise.

	:::tip
	If the Promise returned by `catch` is cancelled,  `failureHandler` will not run.

	To run code no matter what, use [Promise:finally].
	:::

	@param failureHandler (...: any) -> ...any
	@return Promise<...any>
]=]
function Promise.prototype:catch(failureHandler)
	assert(failureHandler == nil or isCallable(failureHandler), string.format(ERROR_NON_FUNCTION, "Promise:catch"))
	return self:_andThen(debug.traceback(nil, 2), nil, failureHandler)
end

--[=[
	Similar to [Promise.andThen](#andThen), except the return value is the same as the value passed to the handler. In other words, you can insert a `:tap` into a Promise chain without affecting the value that downstream Promises receive.

	```lua
		getTheValue()
		:tap(print)
		:andThen(function(theValue)
			print("Got", theValue, "even though print returns nil!")
		end)
	```

	If you return a Promise from the tap handler callback, its value will be discarded but `tap` will still wait until it resolves before passing the original value through.

	@param tapHandler (...: any) -> ...any
	@return Promise<...any>
]=]
function Promise.prototype:tap(tapHandler)
	assert(isCallable(tapHandler), string.format(ERROR_NON_FUNCTION, "Promise:tap"))
	return self:_andThen(debug.traceback(nil, 2), function(...)
		local callbackReturn = tapHandler(...)

		if Promise.is(callbackReturn) then
			local length, values = pack(...)
			return callbackReturn:andThen(function()
				return unpack(values, 1, length)
			end)
		end

		return ...
	end)
end

--[=[
	Attaches an `andThen` handler to this Promise that calls the given callback with the predefined arguments. The resolved value is discarded.

	```lua
		promise:andThenCall(someFunction, "some", "arguments")
	```

	This is sugar for

	```lua
		promise:andThen(function()
		return someFunction("some", "arguments")
		end)
	```

	@param callback (...: any) -> any
	@param ...? any -- Additional arguments which will be passed to `callback`
	@return Promise
]=]
function Promise.prototype:andThenCall(callback, ...)
	assert(isCallable(callback), string.format(ERROR_NON_FUNCTION, "Promise:andThenCall"))
	local length, values = pack(...)
	return self:_andThen(debug.traceback(nil, 2), function()
		return callback(unpack(values, 1, length))
	end)
end

--[=[
	Attaches an `andThen` handler to this Promise that discards the resolved value and returns the given value from it.

	```lua
		promise:andThenReturn("some", "values")
	```

	This is sugar for

	```lua
		promise:andThen(function()
			return "some", "values"
		end)
	```

	:::caution
	Promises are eager, so if you pass a Promise to `andThenReturn`, it will begin executing before `andThenReturn` is reached in the chain. Likewise, if you pass a Promise created from [[Promise.reject]] into `andThenReturn`, it's possible that this will trigger the unhandled rejection warning. If you need to return a Promise, it's usually best practice to use [[Promise.andThen]].
	:::

	@param ... any -- Values to return from the function
	@return Promise
]=]
function Promise.prototype:andThenReturn(...)
	local length, values = pack(...)
	return self:_andThen(debug.traceback(nil, 2), function()
		return unpack(values, 1, length)
	end)
end

--[=[
	Cancels this promise, preventing the promise from resolving or rejecting. Does not do anything if the promise is already settled.

	Cancellations will propagate upwards and downwards through chained promises.

	Promises will only be cancelled if all of their consumers are also cancelled. This is to say that if you call `andThen` twice on the same promise, and you cancel only one of the child promises, it will not cancel the parent promise until the other child promise is also cancelled.

	```lua
		promise:cancel()
	```
]=]
function Promise.prototype:cancel()
	if self._status ~= Promise.Status.Started then
		return
	end

	self._status = Promise.Status.Cancelled

	if self._cancellationHook then
		self._cancellationHook()
	end

	coroutine.close(self._thread)

	if self._parent then
		self._parent:_consumerCancelled(self)
	end

	for child in pairs(self._consumers) do
		child:cancel()
	end

	self:_finalize()
end

--[[
	Used to decrease the number of consumers by 1, and if there are no more,
	cancel this promise.
]]
function Promise.prototype:_consumerCancelled(consumer)
	if self._status ~= Promise.Status.Started then
		return
	end

	self._consumers[consumer] = nil

	if next(self._consumers) == nil then
		self:cancel()
	end
end

--[[
	Used to set a handler for when the promise resolves, rejects, or is
	cancelled.
]]
function Promise.prototype:_finally(traceback, finallyHandler)
	self._unhandledRejection = false

	local promise = Promise._new(traceback, function(resolve, reject, onCancel)
		local handlerPromise

		onCancel(function()
			-- The finally Promise is not a proper consumer of self. We don't care about the resolved value.
			-- All we care about is running at the end. Therefore, if self has no other consumers, it's safe to
			-- cancel. We don't need to hold out cancelling just because there's a finally handler.
			self:_consumerCancelled(self)

			if handlerPromise then
				handlerPromise:cancel()
			end
		end)

		local finallyCallback = resolve
		if finallyHandler then
			finallyCallback = function(...)
				local ok, _, resultList = runExecutor(traceback, finallyHandler, ...)
				local result = resultList[1]
				if not ok then
					return reject(result)
				end

				if Promise.is(result) then
					handlerPromise = result

					result
						:finally(function(status)
							if status ~= Promise.Status.Rejected then
								resolve(self)
							end
						end)
						:catch(function(...)
							reject(...)
						end)
				else
					resolve(self)
				end
			end
		end

		if self._status == Promise.Status.Started then
			-- The promise is not settled, so queue this.
			table.insert(self._queuedFinally, finallyCallback)
		else
			-- The promise already settled or was cancelled, run the callback now.
			finallyCallback(self._status)
		end
	end)

	return promise
end

--[=[
	Set a handler that will be called regardless of the promise's fate. The handler is called when the promise is
	resolved, rejected, *or* cancelled.

	Returns a new Promise that:
	- resolves with the same values that this Promise resolves with.
	- rejects with the same values that this Promise rejects with.
	- is cancelled if this Promise is cancelled.

	If the value you return from the handler is a Promise:
	- We wait for the Promise to resolve, but we ultimately discard the resolved value.
	- If the returned Promise rejects, the Promise returned from `finally` will reject with the rejected value from the
	*returned* promise.
	- If the `finally` Promise is cancelled, and you returned a Promise from the handler, we cancel that Promise too.

	Otherwise, the return value from the `finally` handler is entirely discarded.

	:::note Cancellation
	As of Promise v4, `Promise:finally` does not count as a consumer of the parent Promise for cancellation purposes.
	This means that if all of a Promise's consumers are cancelled and the only remaining callbacks are finally handlers,
	the Promise is cancelled and the finally callbacks run then and there.

	Cancellation still propagates through the `finally` Promise though: if you cancel the `finally` Promise, it can cancel
	its parent Promise if it had no other consumers. Likewise, if the parent Promise is cancelled, the `finally` Promise
	will also be cancelled.
	:::

	```lua
	local thing = createSomething()

	doSomethingWith(thing)
		:andThen(function()
			print("It worked!")
			-- do something..
		end)
		:catch(function()
			warn("Oh no it failed!")
		end)
		:finally(function()
			-- either way, destroy thing

			thing:Destroy()
		end)

	```

	@param finallyHandler (status: Status) -> ...any
	@return Promise<...any>
]=]
function Promise.prototype:finally(finallyHandler)
	assert(finallyHandler == nil or isCallable(finallyHandler), string.format(ERROR_NON_FUNCTION, "Promise:finally"))
	return self:_finally(debug.traceback(nil, 2), finallyHandler)
end

--[=[
	Same as `andThenCall`, except for `finally`.

	Attaches a `finally` handler to this Promise that calls the given callback with the predefined arguments.

	@param callback (...: any) -> any
	@param ...? any -- Additional arguments which will be passed to `callback`
	@return Promise
]=]
function Promise.prototype:finallyCall(callback, ...)
	assert(isCallable(callback), string.format(ERROR_NON_FUNCTION, "Promise:finallyCall"))
	local length, values = pack(...)
	return self:_finally(debug.traceback(nil, 2), function()
		return callback(unpack(values, 1, length))
	end)
end

--[=[
	Attaches a `finally` handler to this Promise that discards the resolved value and returns the given value from it.

	```lua
		promise:finallyReturn("some", "values")
	```

	This is sugar for

	```lua
		promise:finally(function()
			return "some", "values"
		end)
	```

	@param ... any -- Values to return from the function
	@return Promise
]=]
function Promise.prototype:finallyReturn(...)
	local length, values = pack(...)
	return self:_finally(debug.traceback(nil, 2), function()
		return unpack(values, 1, length)
	end)
end

--[=[
	Yields the current thread until the given Promise completes. Returns the Promise's status, followed by the values that the promise resolved or rejected with.

	@yields
	@return Status -- The Status representing the fate of the Promise
	@return ...any -- The values the Promise resolved or rejected with.
]=]
function Promise.prototype:awaitStatus()
	self._unhandledRejection = false

	if self._status == Promise.Status.Started then
		local thread = coroutine.running()

		self
			:finally(function()
				task.spawn(thread)
			end)
			-- The finally promise can propagate rejections, so we attach a catch handler to prevent the unhandled
			-- rejection warning from appearing
			:catch(
				function() end
			)

		coroutine.yield()
	end

	if self._status == Promise.Status.Resolved then
		return self._status, unpack(self._values, 1, self._valuesLength)
	elseif self._status == Promise.Status.Rejected then
		return self._status, unpack(self._values, 1, self._valuesLength)
	end

	return self._status
end

local function awaitHelper(status, ...)
	return status == Promise.Status.Resolved, ...
end

--[=[
	Yields the current thread until the given Promise completes. Returns true if the Promise resolved, followed by the values that the promise resolved or rejected with.

	:::caution
	If the Promise gets cancelled, this function will return `false`, which is indistinguishable from a rejection. If you need to differentiate, you should use [[Promise.awaitStatus]] instead.
	:::

	```lua
		local worked, value = getTheValue():await()

	if worked then
		print("got", value)
	else
		warn("it failed")
	end
	```

	@yields
	@return boolean -- `true` if the Promise successfully resolved
	@return ...any -- The values the Promise resolved or rejected with.
]=]
function Promise.prototype:await()
	return awaitHelper(self:awaitStatus())
end

local function expectHelper(status, ...)
	if status ~= Promise.Status.Resolved then
		error((...) == nil and "Expected Promise rejected with no value." or (...), 3)
	end

	return ...
end

--[=[
	Yields the current thread until the given Promise completes. Returns the values that the promise resolved with.

	```lua
	local worked = pcall(function()
		print("got", getTheValue():expect())
	end)

	if not worked then
		warn("it failed")
	end
	```

	This is essentially sugar for:

	```lua
	select(2, assert(promise:await()))
	```

	**Errors** if the Promise rejects or gets cancelled.

	@error any -- Errors with the rejection value if this Promise rejects or gets cancelled.
	@yields
	@return ...any -- The values the Promise resolved with.
]=]
function Promise.prototype:expect()
	return expectHelper(self:awaitStatus())
end

-- Backwards compatibility
Promise.prototype.awaitValue = Promise.prototype.expect

--[[
	Intended for use in tests.

	Similar to await(), but instead of yielding if the promise is unresolved,
	_unwrap will throw. This indicates an assumption that a promise has
	resolved.
]]
function Promise.prototype:_unwrap()
	if self._status == Promise.Status.Started then
		error("Promise has not resolved or rejected.", 2)
	end

	local success = self._status == Promise.Status.Resolved

	return success, unpack(self._values, 1, self._valuesLength)
end

function Promise.prototype:_resolve(...)
	if self._status ~= Promise.Status.Started then
		if Promise.is((...)) then
			(...):_consumerCancelled(self)
		end
		return
	end

	-- If the resolved value was a Promise, we chain onto it!
	if Promise.is((...)) then
		-- Without this warning, arguments sometimes mysteriously disappear
		if select("#", ...) > 1 then
			local message = string.format(
				"When returning a Promise from andThen, extra arguments are " .. "discarded! See:\n\n%s",
				self._source
			)
			warn(message)
		end

		local chainedPromise = ...

		local promise = chainedPromise:andThen(function(...)
			self:_resolve(...)
		end, function(...)
			local maybeRuntimeError = chainedPromise._values[1]

			-- Backwards compatibility < v2
			if chainedPromise._error then
				maybeRuntimeError = Error.new({
					error = chainedPromise._error,
					kind = Error.Kind.ExecutionError,
					context = "[No stack trace available as this Promise originated from an older version of the Promise library (< v2)]",
				})
			end

			if Error.isKind(maybeRuntimeError, Error.Kind.ExecutionError) then
				return self:_reject(maybeRuntimeError:extend({
					error = "This Promise was chained to a Promise that errored.",
					trace = "",
					context = string.format(
						"The Promise at:\n\n%s\n...Rejected because it was chained to the following Promise, which encountered an error:\n",
						self._source
					),
				}))
			end

			self:_reject(...)
		end)

		if promise._status == Promise.Status.Cancelled then
			self:cancel()
		elseif promise._status == Promise.Status.Started then
			-- Adopt ourselves into promise for cancellation propagation.
			self._parent = promise
			promise._consumers[self] = true
		end

		return
	end

	self._status = Promise.Status.Resolved
	self._valuesLength, self._values = pack(...)

	-- We assume that these callbacks will not throw errors.
	for _, callback in ipairs(self._queuedResolve) do
		coroutine.wrap(callback)(...)
	end

	self:_finalize()
end

function Promise.prototype:_reject(...)
	if self._status ~= Promise.Status.Started then
		return
	end

	self._status = Promise.Status.Rejected
	self._valuesLength, self._values = pack(...)

	-- If there are any rejection handlers, call those!
	if not isEmpty(self._queuedReject) then
		-- We assume that these callbacks will not throw errors.
		for _, callback in ipairs(self._queuedReject) do
			coroutine.wrap(callback)(...)
		end
	else
		-- At this point, no one was able to observe the error.
		-- An error handler might still be attached if the error occurred
		-- synchronously. We'll wait one tick, and if there are still no
		-- observers, then we should put a message in the console.

		local err = tostring((...))

		coroutine.wrap(function()
			Promise._timeEvent:Wait()

			-- Someone observed the error, hooray!
			if not self._unhandledRejection then
				return
			end

			-- Build a reasonable message
			local message = string.format("Unhandled Promise rejection:\n\n%s\n\n%s", err, self._source)

			for _, callback in ipairs(Promise._unhandledRejectionCallbacks) do
				task.spawn(callback, self, unpack(self._values, 1, self._valuesLength))
			end

			if Promise.TEST then
				-- Don't spam output when we're running tests.
				return
			end

			warn(message)
		end)()
	end

	self:_finalize()
end

--[[
	Calls any :finally handlers. We need this to be a separate method and
	queue because we must call all of the finally callbacks upon a success,
	failure, *and* cancellation.
]]
function Promise.prototype:_finalize()
	for _, callback in ipairs(self._queuedFinally) do
		-- Purposefully not passing values to callbacks here, as it could be the
		-- resolved values, or rejected errors. If the developer needs the values,
		-- they should use :andThen or :catch explicitly.
		coroutine.wrap(callback)(self._status)
	end

	self._queuedFinally = nil
	self._queuedReject = nil
	self._queuedResolve = nil

	-- Clear references to other Promises to allow gc
	if not Promise.TEST then
		self._parent = nil
		self._consumers = nil
	end

	task.defer(coroutine.close, self._thread)
end

--[=[
	Chains a Promise from this one that is resolved if this Promise is already resolved, and rejected if it is not resolved at the time of calling `:now()`. This can be used to ensure your `andThen` handler occurs on the same frame as the root Promise execution.

	```lua
	doSomething()
		:now()
		:andThen(function(value)
			print("Got", value, "synchronously.")
		end)
	```

	If this Promise is still running, Rejected, or Cancelled, the Promise returned from `:now()` will reject with the `rejectionValue` if passed, otherwise with a `Promise.Error(Promise.Error.Kind.NotResolvedInTime)`. This can be checked with [[Error.isKind]].

	@param rejectionValue? any -- The value to reject with if the Promise isn't resolved
	@return Promise
]=]
function Promise.prototype:now(rejectionValue)
	local traceback = debug.traceback(nil, 2)
	if self._status == Promise.Status.Resolved then
		return self:_andThen(traceback, function(...)
			return ...
		end)
	else
		return Promise.reject(rejectionValue == nil and Error.new({
			kind = Error.Kind.NotResolvedInTime,
			error = "This Promise was not resolved in time for :now()",
			context = ":now() was called at:\n\n" .. traceback,
		}) or rejectionValue)
	end
end

--[=[
	Repeatedly calls a Promise-returning function up to `times` number of times, until the returned Promise resolves.

	If the amount of retries is exceeded, the function will return the latest rejected Promise.

	```lua
	local function canFail(a, b, c)
		return Promise.new(function(resolve, reject)
			-- do something that can fail

			local failed, thing = doSomethingThatCanFail(a, b, c)

			if failed then
				reject("it failed")
			else
				resolve(thing)
			end
		end)
	end

	local MAX_RETRIES = 10
	local value = Promise.retry(canFail, MAX_RETRIES, "foo", "bar", "baz") -- args to send to canFail
	```

	@since 3.0.0
	@param callback (...: P) -> Promise<T>
	@param times number
	@param ...? P
	@return Promise<T>
]=]
function Promise.retry(callback, times, ...)
	assert(isCallable(callback), "Parameter #1 to Promise.retry must be a function")
	assert(type(times) == "number", "Parameter #2 to Promise.retry must be a number")

	local args, length = { ... }, select("#", ...)

	return Promise.resolve(callback(...)):catch(function(...)
		if times > 0 then
			return Promise.retry(callback, times - 1, unpack(args, 1, length))
		else
			return Promise.reject(...)
		end
	end)
end

--[=[
	Repeatedly calls a Promise-returning function up to `times` number of times, waiting `seconds` seconds between each
	retry, until the returned Promise resolves.

	If the amount of retries is exceeded, the function will return the latest rejected Promise.

	@since v3.2.0
	@param callback (...: P) -> Promise<T>
	@param times number
	@param seconds number
	@param ...? P
	@return Promise<T>
]=]
function Promise.retryWithDelay(callback, times, seconds, ...)
	assert(isCallable(callback), "Parameter #1 to Promise.retry must be a function")
	assert(type(times) == "number", "Parameter #2 (times) to Promise.retry must be a number")
	assert(type(seconds) == "number", "Parameter #3 (seconds) to Promise.retry must be a number")

	local args, length = { ... }, select("#", ...)

	return Promise.resolve(callback(...)):catch(function(...)
		if times > 0 then
			Promise.delay(seconds):await()

			return Promise.retryWithDelay(callback, times - 1, seconds, unpack(args, 1, length))
		else
			return Promise.reject(...)
		end
	end)
end

--[=[
	Converts an event into a Promise which resolves the next time the event fires.

	The optional `predicate` callback, if passed, will receive the event arguments and should return `true` or `false`, based on if this fired event should resolve the Promise or not. If `true`, the Promise resolves. If `false`, nothing happens and the predicate will be rerun the next time the event fires.

	The Promise will resolve with the event arguments.

	:::tip
	This function will work given any object with a `Connect` method. This includes all Roblox events.
	:::

	```lua
	-- Creates a Promise which only resolves when `somePart` is touched
	-- by a part named `"Something specific"`.
	return Promise.fromEvent(somePart.Touched, function(part)
		return part.Name == "Something specific"
	end)
	```

	@since 3.0.0
	@param event Event -- Any object with a `Connect` method. This includes all Roblox events.
	@param predicate? (...: P) -> boolean -- A function which determines if the Promise should resolve with the given value, or wait for the next event to check again.
	@return Promise<P>
]=]
function Promise.fromEvent(event, predicate)
	predicate = predicate or function()
		return true
	end

	return Promise._new(debug.traceback(nil, 2), function(resolve, _, onCancel)
		local connection
		local shouldDisconnect = false

		local function disconnect()
			connection:Disconnect()
			connection = nil
		end

		-- We use shouldDisconnect because if the callback given to Connect is called before
		-- Connect returns, connection will still be nil. This happens with events that queue up
		-- events when there's nothing connected, such as RemoteEvents

		connection = event:Connect(function(...)
			local callbackValue = predicate(...)

			if callbackValue == true then
				resolve(...)

				if connection then
					disconnect()
				else
					shouldDisconnect = true
				end
			elseif type(callbackValue) ~= "boolean" then
				error("Promise.fromEvent predicate should always return a boolean")
			end
		end)

		if shouldDisconnect and connection then
			return disconnect()
		end

		onCancel(disconnect)
	end)
end

--[=[
	Registers a callback that runs when an unhandled rejection happens. An unhandled rejection happens when a Promise
	is rejected, and the rejection is not observed with `:catch`.

	The callback is called with the actual promise that rejected, followed by the rejection values.

	@since v3.2.0
	@param callback (promise: Promise, ...: any) -- A callback that runs when an unhandled rejection happens.
	@return () -> () -- Function that unregisters the `callback` when called
]=]
function Promise.onUnhandledRejection(callback)
	table.insert(Promise._unhandledRejectionCallbacks, callback)

	return function()
		local index = table.find(Promise._unhandledRejectionCallbacks, callback)

		if index then
			table.remove(Promise._unhandledRejectionCallbacks, index)
		end
	end
end

return Promise
]====]
n_Worm__Libraries_Promise.Parent = n_Worm__Libraries

