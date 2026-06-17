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
