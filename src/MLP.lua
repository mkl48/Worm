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
