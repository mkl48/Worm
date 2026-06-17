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
