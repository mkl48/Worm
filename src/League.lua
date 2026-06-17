local Promise = require(script.Parent.Promise)

-- A bounded pool of frozen snapshots taken from a live Profile, used to
-- spar against past versions of itself (self-play) instead of plateauing
-- against a single static opponent. League only stores/serves raw export
-- data -- materializing a sparring Profile from it is the caller's job via
-- Worm.load(), which keeps this module decoupled from Worm's own loader.
local League = {}
League.__index = League

function League.new(profile, opts)
    opts = opts or {}

    local self = setmetatable({}, League)
    self._profile = profile
    self._keep    = opts.keep or 10
    self._pool    = {}

    return self
end

function League:checkpoint(label)
    return Promise.new(function(resolve, reject)
        self._profile:export()
            :next(function(data)
                table.insert(self._pool, {
                    data    = data,
                    label   = label,
                    savedAt = os.clock(),
                })

                while #self._pool > self._keep do
                    table.remove(self._pool, 1)
                end

                resolve(#self._pool)
            end)
            :toss(reject)
    end)
end

function League:size()
    return #self._pool
end

function League:sample()
    if #self._pool == 0 then
        return nil
    end
    return self._pool[math.random(1, #self._pool)].data
end

function League:latest()
    if #self._pool == 0 then
        return nil
    end
    return self._pool[#self._pool].data
end

function League:history()
    local labels = {}
    for _, entry in ipairs(self._pool) do
        table.insert(labels, entry.label)
    end
    return labels
end

return League
