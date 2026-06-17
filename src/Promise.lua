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
