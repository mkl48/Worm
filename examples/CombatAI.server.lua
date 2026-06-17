local Players           = game:GetService("Players")
local Workspace          = game:GetService("Workspace")
local RunService         = game:GetService("RunService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local DataStoreService   = game:GetService("DataStoreService")

local Worm = ReplicatedStorage:FindFirstChild("Packages") and ReplicatedStorage.Packages:FindFirstChild("Worm")
    or ReplicatedStorage:WaitForChild("Worm")
Worm = require(Worm)

local SWORD_NAME         = "Classic Sword"
local ATTACK_RANGE       = 6
local ATTACK_DAMAGE      = 12
local ATTACK_COOLDOWN    = 1
local APPROACH_SPEED     = 1
local ROUND_RESET_DELAY  = 2
local TARGET_MAX_HEALTH  = 100
local SAVE_KEY           = "Fighter_v1"
local SAVE_EVERY_ROUNDS  = 25

local Fighter          = Workspace:WaitForChild("Fighter")
local Dummy            = Workspace:WaitForChild("Dummy")
local FighterHumanoid  = Fighter:WaitForChild("Humanoid")
local DummyHumanoid    = Dummy:WaitForChild("Humanoid")
local FighterRoot      = Fighter:WaitForChild("HumanoidRootPart")
local DummyRoot        = Dummy:WaitForChild("HumanoidRootPart")

local fighterSpawnCFrame = FighterRoot.CFrame
local dummySpawnCFrame   = DummyRoot.CFrame
local fighterMaxHealth   = FighterHumanoid.MaxHealth

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

-- Picks the nearest live player to fight; falls back to the practice
-- dummy when no player is around to train against.
local function findTarget()
    local closest, closestDist = nil, math.huge

    for _, player in ipairs(Players:GetPlayers()) do
        local character = player.Character
        local humanoid   = character and character:FindFirstChildOfClass("Humanoid")
        local root        = character and character:FindFirstChild("HumanoidRootPart")

        if humanoid and root and humanoid.Health > 0 then
            local dist = (FighterRoot.Position - root.Position).Magnitude
            if dist < closestDist then
                closest, closestDist = {
                    humanoid = humanoid,
                    root     = root,
                    model    = character,
                    isPlayer = true,
                }, dist
            end
        end
    end

    if closest then
        return closest
    end

    return { humanoid = DummyHumanoid, root = DummyRoot, model = Dummy, isPlayer = false }
end

-- Plays the swing and resolves the hit locally -- the Attack remote only
-- replicates the animation/sound, it doesn't tell us whether we connected.
local function tryAttack(target)
    local now = os.clock()
    if now - lastAttackTime < ATTACK_COOLDOWN then
        return false
    end
    lastAttackTime = now
    fireSwing()

    local distance = (FighterRoot.Position - target.root.Position).Magnitude
    if distance <= ATTACK_RANGE and target.humanoid.Health > 0 then
        target.humanoid:TakeDamage(ATTACK_DAMAGE)
        return true
    end
    return false
end

local function moveToward(point)
    local offset = Vector3.new(point.X - FighterRoot.Position.X, 0, point.Z - FighterRoot.Position.Z)
    if offset.Magnitude > 0.1 then
        FighterHumanoid:Move(offset.Unit * APPROACH_SPEED)
    end
end

local ACTION_LABELS = { "attack", "approach", "retreat", "reset" }

local lastAttackOutcome = nil

local ACTION_HANDLERS = {
    attack = function(target)
        lastAttackOutcome = tryAttack(target) and "hit" or "whiff"
    end,
    approach = function(target)
        moveToward(target.root.Position)
    end,
    retreat = function(target)
        moveToward(2 * FighterRoot.Position - target.root.Position)
    end,
    reset = function(_target)
        FighterHumanoid:Move(Vector3.new())
    end,
}

local CombatAI

local CombatStore = DataStoreService:GetDataStore("WormCombatAI")

local function loadCombatAI()
    local ok, data = pcall(function()
        return CombatStore:GetAsync(SAVE_KEY)
    end)
    if ok and data then
        print("CombatAI -- restored trained profile from DataStore")
        return Worm.load(data)
    end
    return nil
end

local function saveCombatAI()
    CombatAI:export()
        :next(function(data)
            local ok, err = pcall(function()
                CombatStore:SetAsync(SAVE_KEY, data)
            end)
            if not ok then
                warn("CombatAI save --", err)
            end
        end)
        :toss(function(err)
            warn("CombatAI export --", err)
        end)
end

CombatAI = loadCombatAI() or Worm.build(Worm.QLEARN, {
    states  = 5,
    actions = #ACTION_LABELS,
    gamma         = 0.95,
    epsilon       = 0.9,
    epsilon_decay = 0.997,
    epsilon_min   = 0.05,
    memory        = 5000,
    batch         = 64,
    schema = {
        hp            = { range = { 0, fighterMaxHealth  } },
        target_hp     = { range = { 0, TARGET_MAX_HEALTH } },
        distance      = { range = { 0, 60                } },
        on_cooldown   = { range = { 0, 1                 } },
        facing_target = { range = { 0, 1                 } },
    }
})

-- Restoring grade_resolved through import() already brings these back;
-- calling rewards() again is harmless and keeps a fresh build in sync.
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
    target            = findTarget(),
    prevRaw           = nil,
    prevActionIndex   = nil,
    prevActionName    = nil,
    prevFighterHP     = FighterHumanoid.Health,
    prevTargetHP      = nil,
    roundOver         = false,
    roundCount        = 0,
}
round.prevTargetHP = round.target.humanoid.Health

local function captureRaw(target)
    local distance  = (FighterRoot.Position - target.root.Position).Magnitude
    local look      = FighterRoot.CFrame.LookVector
    local toTarget  = (target.root.Position - FighterRoot.Position)
    local facing    = toTarget.Magnitude > 0 and look:Dot(toTarget.Unit) or 0

    return {
        hp            = FighterHumanoid.Health,
        target_hp     = target.humanoid.Health,
        distance      = distance,
        on_cooldown   = (os.clock() - lastAttackTime < ATTACK_COOLDOWN) and 1 or 0,
        facing_target = facing > 0 and 1 or 0,
    }
end

local function resolveReward(raw)
    if raw.target_hp <= 0 and round.prevTargetHP > 0 then
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
    FighterRoot.CFrame     = fighterSpawnCFrame

    local target = findTarget()
    if not target.isPlayer then
        DummyHumanoid.Health = DummyHumanoid.MaxHealth
        DummyRoot.CFrame     = dummySpawnCFrame
    end

    round.target          = target
    round.prevRaw         = nil
    round.prevActionIndex = nil
    round.prevActionName  = nil
    round.prevFighterHP   = fighterMaxHealth
    round.prevTargetHP    = target.humanoid.Health
    round.roundOver       = false
    round.roundCount      += 1

    if round.roundCount % SAVE_EVERY_ROUNDS == 0 then
        saveCombatAI()
    end
end

RunService.Heartbeat:Connect(function()
    if round.roundOver then
        return
    end

    local target = round.target
    if not target.root.Parent or not target.humanoid.Parent then
        round.roundOver = true
        task.delay(ROUND_RESET_DELAY, resetRound)
        return
    end

    local raw = captureRaw(target)

    local lessonPromise = nil
    if round.prevRaw and round.prevActionIndex then
        local done = raw.hp <= 0 or raw.target_hp <= 0
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

                ACTION_HANDLERS[actionName](target)

                round.prevRaw         = raw
                round.prevActionIndex = actionIndex
                round.prevActionName  = actionName
                round.prevFighterHP   = raw.hp
                round.prevTargetHP    = raw.target_hp
            end)
            :toss(function(err)
                warn("CombatAI infer --", err)
            end)
    end

    if raw.hp <= 0 or raw.target_hp <= 0 then
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

game:BindToClose(function()
    saveCombatAI()
    task.wait(2)
end)
