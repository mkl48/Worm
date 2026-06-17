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
