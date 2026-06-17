-- WeaponSystem
-- A self-contained melee moveset: light/heavy/dash attacks, parry, dodge
-- roll, backstep, and feint, with stamina, per-move cooldowns, combo
-- scaling, and arc/range-based hit resolution. No animations required --
-- everything resolves through timers and Humanoid:Move/TakeDamage, so it
-- runs standalone for NPCs and ghosts that have no client to animate them.
--
-- Usage:
--   local weapon = WeaponSystem.new(model)
--   RunService.Heartbeat:Connect(function(dt) weapon:update(dt) end)
--   weapon:use("light_attack", { humanoid = targetHumanoid, root = targetRoot, weaponSystem = targetWeapon })

local WeaponSystem = {}
WeaponSystem.__index = WeaponSystem

local MOVES = {
    light_attack = { stamina = 10, cooldown = 0.4, windup = 0.05, range = 6,  arc = 80, damage = 8,  combo = true,  breaks_combo = false, parryable = true },
    heavy_attack = { stamina = 25, cooldown = 1.2, windup = 0.5,  range = 6,  arc = 70, damage = 22, combo = false, breaks_combo = true,  parryable = true },
    dash_attack  = { stamina = 18, cooldown = 1.5, windup = 0.15, range = 14, arc = 50, damage = 12, combo = false, breaks_combo = true,  parryable = true, dash = true },
    parry        = { stamina = 6,  cooldown = 1.0, active = 0.35 },
    dodge_roll   = { stamina = 15, cooldown = 1.0, active = 0.3, dash = true, invuln = true },
    backstep     = { stamina = 8,  cooldown = 0.6, dash = true },
    feint        = { stamina = 5,  cooldown = 0.8, windup = 0.2 },
}

-- Fixed order so anything mapping a numeric index (e.g. a NEAT genome's
-- output nodes) back to a move name gets the same move every time --
-- pairs() iteration order over MOVES is not guaranteed stable.
local MOVE_NAMES = {
    "light_attack", "heavy_attack", "dash_attack",
    "parry", "dodge_roll", "backstep", "feint",
}

function WeaponSystem.new(model, opts)
    opts = opts or {}

    local humanoid = model:WaitForChild("Humanoid")
    local root      = model:WaitForChild("HumanoidRootPart")

    local self = setmetatable({}, WeaponSystem)

    self.model         = model
    self.humanoid       = humanoid
    self.root            = root
    self.maxStamina       = opts.maxStamina or 100
    self.stamina            = self.maxStamina
    self.staminaRegen        = opts.staminaRegen or 15
    self.comboWindow           = opts.comboWindow or 1.2

    self.cooldowns      = {}
    self.combo           = 0
    self.lastHitAt        = 0
    self.parryUntil        = 0
    self.invulnUntil        = 0
    self.staggeredUntil      = 0

    -- Optional reward hooks -- assign functions to wire these into Worm's grade()/rewards().
    self.onHitLanded   = nil -- (moveName, target, damage, comboLevel)
    self.onHitTaken    = nil -- (moveName, attackerWeaponSystem, damage)
    self.onWhiff       = nil -- (moveName)
    self.onParried     = nil -- (attackerWeaponSystem) -- fired on the defender who parried
    self.onFeintBaited = nil -- () -- fired on the feinter when it baits a parry/dodge

    return self
end

function WeaponSystem:update(dt)
    self.stamina = math.min(self.maxStamina, self.stamina + self.staminaRegen * dt)
end

function WeaponSystem:isOnCooldown(moveName)
    local until_ = self.cooldowns[moveName]
    return until_ ~= nil and os.clock() < until_
end

function WeaponSystem:isStaggered()
    return os.clock() < self.staggeredUntil
end

function WeaponSystem:isParrying()
    return os.clock() < self.parryUntil
end

function WeaponSystem:isInvulnerable()
    return os.clock() < self.invulnUntil
end

function WeaponSystem:canUse(moveName)
    local move = MOVES[moveName]
    if not move then
        return false
    end
    if self:isStaggered() then
        return false
    end
    if self:isOnCooldown(moveName) then
        return false
    end
    if self.stamina < move.stamina then
        return false
    end
    return true
end

function WeaponSystem:_facingTarget(move, targetRoot)
    local toTarget = targetRoot.Position - self.root.Position
    local distance  = toTarget.Magnitude
    if distance > move.range then
        return false
    end
    if distance < 0.01 then
        return true
    end

    local look  = self.root.CFrame.LookVector
    local angle = math.acos(math.clamp(look:Dot(toTarget.Unit), -1, 1))
    return math.deg(angle) <= move.arc / 2
end

local function repositionAway(self, target)
    local away = self.root.Position - target.root.Position
    if away.Magnitude > 0.01 then
        self.humanoid:Move(away.Unit)
    end
end

local function repositionToward(self, target)
    local toward = target.root.Position - self.root.Position
    if toward.Magnitude > 0.01 then
        self.humanoid:Move(toward.Unit)
    end
end

local function resolveHit(self, moveName, move, target)
    if not self:_facingTarget(move, target.root) then
        self.combo = 0
        if self.onWhiff then
            self.onWhiff(moveName)
        end
        return
    end

    local targetWeapon = target.weaponSystem
    if targetWeapon then
        if targetWeapon:isInvulnerable() then
            self.combo = 0
            if self.onWhiff then
                self.onWhiff(moveName)
            end
            return
        end
        if move.parryable and targetWeapon:isParrying() then
            self.staggeredUntil = os.clock() + 0.6
            self.combo = 0
            if targetWeapon.onParried then
                targetWeapon.onParried(self)
            end
            if self.onHitTaken then
                self.onHitTaken("parried", target, 0)
            end
            return
        end
    end

    local now = os.clock()
    if move.combo and now - self.lastHitAt <= self.comboWindow then
        self.combo += 1
    else
        self.combo = move.combo and 1 or 0
    end
    self.lastHitAt = now

    local damage = move.damage * (1 + 0.15 * math.min(self.combo, 5))
    if target.humanoid.Health > 0 then
        target.humanoid:TakeDamage(damage)
    end

    if move.breaks_combo then
        self.combo = 0
    end

    if self.onHitLanded then
        self.onHitLanded(moveName, target, damage, self.combo)
    end
    if targetWeapon and targetWeapon.onHitTaken then
        targetWeapon.onHitTaken(moveName, self, damage)
    end
end

-- target: { humanoid: Humanoid, root: BasePart, weaponSystem: WeaponSystem? }
-- fireSwingFn: optional () -> () callback to replicate a visual/sound cue
function WeaponSystem:use(moveName, target, fireSwingFn)
    if not self:canUse(moveName) then
        return false, "unavailable"
    end

    local move = MOVES[moveName]
    self.stamina = self.stamina - move.stamina
    self.cooldowns[moveName] = os.clock() + move.cooldown

    if moveName == "parry" then
        self.parryUntil = os.clock() + move.active
        return true, "parry"
    end

    if moveName == "dodge_roll" then
        self.invulnUntil = os.clock() + move.active
        repositionAway(self, target)
        return true, "dodged"
    end

    if moveName == "backstep" then
        repositionAway(self, target)
        return true, "backstep"
    end

    if moveName == "feint" then
        task.delay(move.windup, function()
            local targetWeapon = target.weaponSystem
            if targetWeapon and (targetWeapon:isParrying() or targetWeapon:isInvulnerable()) then
                if self.onFeintBaited then
                    self.onFeintBaited()
                end
            end
        end)
        return true, "feint"
    end

    if move.dash then
        repositionToward(self, target)
    end

    if fireSwingFn then
        fireSwingFn()
    end

    task.delay(move.windup, function()
        resolveHit(self, moveName, move, target)
    end)

    return true, "swinging"
end

function WeaponSystem.moveNames()
    return table.clone(MOVE_NAMES)
end

function WeaponSystem.moveInfo(name)
    return MOVES[name]
end

return WeaponSystem
