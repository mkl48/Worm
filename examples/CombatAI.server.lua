local Workspace         = game:GetService("Workspace")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Worm = ReplicatedStorage:FindFirstChild("Packages") and ReplicatedStorage.Packages:FindFirstChild("Worm")
    or ReplicatedStorage:WaitForChild("Worm")
Worm = require(Worm)

local SWORD_NAME         = "Classic Sword"
local ATTACK_RANGE       = 6
local ATTACK_DAMAGE      = 12
local ATTACK_COOLDOWN    = 1
local APPROACH_SPEED     = 1
local ROUND_RESET_DELAY  = 2

local Fighter          = Workspace:WaitForChild("Fighter")
local Dummy            = Workspace:WaitForChild("Dummy")
local FighterHumanoid  = Fighter:WaitForChild("Humanoid")
local DummyHumanoid    = Dummy:WaitForChild("Humanoid")
local FighterRoot      = Fighter:WaitForChild("HumanoidRootPart")
local DummyRoot        = Dummy:WaitForChild("HumanoidRootPart")

local fighterSpawnCFrame = FighterRoot.CFrame
local dummySpawnCFrame   = DummyRoot.CFrame
local fighterMaxHealth   = FighterHumanoid.MaxHealth
local dummyMaxHealth     = DummyHumanoid.MaxHealth

local function getSword()
    local tool = Fighter:FindFirstChild(SWORD_NAME)
    if tool then
        return tool
    end

    local template = Dummy:FindFirstChild(SWORD_NAME) or ReplicatedStorage:FindFirstChild(SWORD_NAME)
    assert(template, "CombatAI -- couldn't find a '" .. SWORD_NAME .. "' tool to clone for the Fighter")

    tool = template:Clone()
    tool.Parent = Fighter
    return tool
end

local Sword  = getSword()
local Attack = Sword:WaitForChild("Attack")
FighterHumanoid:EquipTool(Sword)

local lastAttackTime = 0

local function fireSwing()
    if Attack:IsA("RemoteEvent") then
        Attack:FireAllClients()
    elseif Attack:IsA("BindableEvent") then
        Attack:Fire()
    end
end

-- Plays the swing and resolves the hit locally -- the Attack remote only
-- replicates the animation/sound, it doesn't tell us whether we connected.
local function tryAttack()
    local now = os.clock()
    if now - lastAttackTime < ATTACK_COOLDOWN then
        return false
    end
    lastAttackTime = now
    fireSwing()

    local distance = (FighterRoot.Position - DummyRoot.Position).Magnitude
    if distance <= ATTACK_RANGE and DummyHumanoid.Health > 0 then
        DummyHumanoid:TakeDamage(ATTACK_DAMAGE)
        return true
    end
    return false
end

local function moveToward(target)
    local offset = Vector3.new(target.X - FighterRoot.Position.X, 0, target.Z - FighterRoot.Position.Z)
    if offset.Magnitude > 0.1 then
        FighterHumanoid:Move(offset.Unit * APPROACH_SPEED)
    end
end

local ACTION_LABELS = { "attack", "approach", "retreat", "reset" }

local lastAttackOutcome = nil

local ACTION_HANDLERS = {
    attack = function()
        lastAttackOutcome = tryAttack() and "hit" or "whiff"
    end,
    approach = function()
        moveToward(DummyRoot.Position)
    end,
    retreat = function()
        moveToward(2 * FighterRoot.Position - DummyRoot.Position)
    end,
    reset = function()
        FighterHumanoid:Move(Vector3.new())
    end,
}

local CombatAI = Worm.build(Worm.QLEARN, {
    states  = 5,
    actions = #ACTION_LABELS,
    gamma         = 0.95,
    epsilon       = 0.9,
    epsilon_decay = 0.997,
    epsilon_min   = 0.05,
    memory        = 5000,
    batch         = 64,
    schema = {
        hp           = { range = { 0, fighterMaxHealth } },
        dummy_hp     = { range = { 0, dummyMaxHealth   } },
        distance     = { range = { 0, 60               } },
        on_cooldown  = { range = { 0, 1                } },
        facing_dummy = { range = { 0, 1                } },
    }
})

CombatAI:rewards({
    kill             = 5,
    hit_landed       = 2,
    approach_success = 0.5,
    idle             = 0,
    whiffed          = -0.5,
    took_damage      = -1,
    died             = -5,
})

local round = {
    prevRaw           = nil,
    prevActionIndex   = nil,
    prevActionName    = nil,
    prevFighterHP     = FighterHumanoid.Health,
    prevDummyHP       = DummyHumanoid.Health,
    roundOver         = false,
}

local function captureRaw()
    local distance   = (FighterRoot.Position - DummyRoot.Position).Magnitude
    local look       = FighterRoot.CFrame.LookVector
    local toDummy    = (DummyRoot.Position - FighterRoot.Position)
    local facing     = toDummy.Magnitude > 0 and look:Dot(toDummy.Unit) or 0

    return {
        hp           = FighterHumanoid.Health,
        dummy_hp     = DummyHumanoid.Health,
        distance     = distance,
        on_cooldown  = (os.clock() - lastAttackTime < ATTACK_COOLDOWN) and 1 or 0,
        facing_dummy = facing > 0 and 1 or 0,
    }
end

local function resolveReward(raw)
    if raw.dummy_hp <= 0 and round.prevDummyHP > 0 then
        return "kill"
    end
    if raw.hp <= 0 and round.prevFighterHP > 0 then
        return "died"
    end
    if round.prevActionName == "attack" then
        return lastAttackOutcome == "hit" and "hit_landed" or "whiffed"
    end
    if raw.hp < round.prevFighterHP then
        return "took_damage"
    end
    if round.prevActionName == "approach" and raw.distance <= ATTACK_RANGE then
        return "approach_success"
    end
    return "idle"
end

local function resetRound()
    FighterHumanoid.Health = fighterMaxHealth
    DummyHumanoid.Health   = dummyMaxHealth
    FighterRoot.CFrame     = fighterSpawnCFrame
    DummyRoot.CFrame       = dummySpawnCFrame

    round.prevRaw         = nil
    round.prevActionIndex = nil
    round.prevActionName  = nil
    round.prevFighterHP   = fighterMaxHealth
    round.prevDummyHP     = dummyMaxHealth
    round.roundOver       = false
end

RunService.Heartbeat:Connect(function()
    if round.roundOver then
        return
    end

    local raw = captureRaw()

    local lessonPromise = nil
    if round.prevRaw and round.prevActionIndex then
        local done = raw.hp <= 0 or raw.dummy_hp <= 0
        lessonPromise = CombatAI:lesson({
            state  = round.prevRaw,
            action = round.prevActionIndex,
            next   = raw,
            reward = resolveReward(raw),
            done   = done,
        })
    end

    local function act()
        CombatAI:infer(raw)
            :next(function()
                -- QLearner resolves the actual epsilon-greedy/argmax choice
                -- internally; pull it back out so lesson() trains the index
                -- it really picked, not a label round-tripped through text.
                local actionIndex = CombatAI._impl._lastAction
                local actionName  = ACTION_LABELS[actionIndex]

                ACTION_HANDLERS[actionName]()

                round.prevRaw         = raw
                round.prevActionIndex = actionIndex
                round.prevActionName  = actionName
                round.prevFighterHP   = raw.hp
                round.prevDummyHP     = raw.dummy_hp
            end)
            :toss(function(err)
                warn("CombatAI infer --", err)
            end)
    end

    if raw.hp <= 0 or raw.dummy_hp <= 0 then
        round.roundOver = true
        if lessonPromise then
            lessonPromise:toss(function(err) warn("CombatAI lesson --", err) end)
        end
        task.delay(ROUND_RESET_DELAY, resetRound)
        return
    end

    if lessonPromise then
        lessonPromise
            :next(act)
            :toss(function(err)
                warn("CombatAI lesson --", err)
                act()
            end)
    else
        act()
    end
end)
