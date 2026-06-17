-- WormSnakeGameSetup
-- Auto-generated from examples/SnakeGame.server.lua -- regenerate after
-- any edit there, this is a snapshot, not live-synced.
-- Run in Roblox Studio's Command Bar to install the Snake game. The
-- game script itself builds the floor/walls/scoreboard at runtime, so
-- this only needs to insert the script -- assumes Worm is already set
-- up under ReplicatedStorage (run scaffold/CreateWorm.lua first if not).

local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

assert(
    ReplicatedStorage:FindFirstChild("Worm"),
    "WormSnakeGameSetup -- Worm not found under ReplicatedStorage. Run scaffold/CreateWorm.lua first."
)

local existing = ServerScriptService:FindFirstChild("SnakeGame")
if existing then
    existing:Destroy()
end

local snakeGame = Instance.new("Script")
snakeGame.Name = "SnakeGame"
snakeGame.Source = [====[
-- SnakeGame
-- A classic grid Snake game, fully self-contained -- it builds its own
-- floor, walls, and scoreboard at runtime, so the only prerequisite is
-- Worm itself under ReplicatedStorage. A Worm QLearner plays it: danger/
-- direction/food flags in, one of up/down/left/right out, trained on
-- ate_food / died / closer / farther rewards across endless episodes.

local Workspace         = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService  = game:GetService("DataStoreService")

local Worm = ReplicatedStorage:FindFirstChild("Packages") and ReplicatedStorage.Packages:FindFirstChild("Worm")
    or ReplicatedStorage:WaitForChild("Worm")
Worm = require(Worm)

local GRID_SIZE           = 16
local CELL_SIZE           = 4
local FLOOR_Y             = 0
local TICK_INTERVAL        = 0.15
local EPISODE_RESET_DELAY   = 1
local SAVE_KEY                = "Snake_v1"
local SAVE_EVERY_EPISODES       = 10

local HEAD_COLOR = Color3.fromRGB(60, 200, 90)
local BODY_COLOR = Color3.fromRGB(40, 150, 70)
local FOOD_COLOR = Color3.fromRGB(220, 60, 60)
local DEAD_COLOR = Color3.fromRGB(180, 40, 40)

local DIRS = {
    up    = { dx = 0,  dz = -1 },
    down  = { dx = 0,  dz = 1  },
    left  = { dx = -1, dz = 0  },
    right = { dx = 1,  dz = 0  },
}
local ACTION_LABELS = { "up", "down", "left", "right" }

--------------------------------------------------------------------------
-- World setup -- builds the board entirely from Instance.new(), no
-- prerequisites in the place beyond Worm being installed.
--------------------------------------------------------------------------

local boardSize = GRID_SIZE * CELL_SIZE

local function buildWorld()
    local existing = Workspace:FindFirstChild("SnakeGame")
    if existing then
        existing:Destroy()
    end

    local root = Instance.new("Folder")
    root.Name = "SnakeGame"
    root.Parent = Workspace

    local floor = Instance.new("Part")
    floor.Name = "Floor"
    floor.Size = Vector3.new(boardSize, 1, boardSize)
    floor.Position = Vector3.new(boardSize / 2, FLOOR_Y - 0.5, boardSize / 2)
    floor.Anchored = true
    floor.Color = Color3.fromRGB(40, 40, 45)
    floor.Parent = root

    local wallHeight = 3
    local wallThickness = 1
    local wallSpecs = {
        { size = Vector3.new(boardSize + 2, wallHeight, wallThickness), pos = Vector3.new(boardSize / 2, wallHeight / 2, -wallThickness / 2) },
        { size = Vector3.new(boardSize + 2, wallHeight, wallThickness), pos = Vector3.new(boardSize / 2, wallHeight / 2, boardSize + wallThickness / 2) },
        { size = Vector3.new(wallThickness, wallHeight, boardSize + 2), pos = Vector3.new(-wallThickness / 2, wallHeight / 2, boardSize / 2) },
        { size = Vector3.new(wallThickness, wallHeight, boardSize + 2), pos = Vector3.new(boardSize + wallThickness / 2, wallHeight / 2, boardSize / 2) },
    }
    for i, spec in ipairs(wallSpecs) do
        local wall = Instance.new("Part")
        wall.Name = "Wall" .. i
        wall.Size = spec.size
        wall.Position = spec.pos
        wall.Anchored = true
        wall.Color = Color3.fromRGB(80, 80, 90)
        wall.Parent = root
    end

    local segmentsFolder = Instance.new("Folder")
    segmentsFolder.Name = "Segments"
    segmentsFolder.Parent = root

    local food = Instance.new("Part")
    food.Name = "Food"
    food.Shape = Enum.PartType.Ball
    food.Size = Vector3.new(CELL_SIZE * 0.6, CELL_SIZE * 0.6, CELL_SIZE * 0.6)
    food.Anchored = true
    food.CanCollide = false
    food.Color = FOOD_COLOR
    food.Parent = root

    local scoreboard = Instance.new("Part")
    scoreboard.Name = "Scoreboard"
    scoreboard.Size = Vector3.new(boardSize * 0.8, boardSize * 0.25, 0.5)
    scoreboard.Position = Vector3.new(boardSize / 2, boardSize * 0.35, boardSize / 2)
    scoreboard.Anchored = true
    scoreboard.CanCollide = false
    scoreboard.Transparency = 1
    scoreboard.Parent = root

    local gui = Instance.new("SurfaceGui")
    gui.Face = Enum.NormalId.Front
    gui.LightInfluence = 0
    gui.Parent = scoreboard

    local label = Instance.new("TextLabel")
    label.Name = "Label"
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.Code
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextScaled = true
    label.Text = "Score: 0  Best: 0  Episode: 0"
    label.Parent = gui

    return root, segmentsFolder, food, label
end

local root, segmentsFolder, foodPart, scoreLabel = buildWorld()

local function cellToWorld(gx, gz)
    return Vector3.new((gx - 0.5) * CELL_SIZE, FLOOR_Y + CELL_SIZE / 2, (gz - 0.5) * CELL_SIZE)
end

local function inBounds(gx, gz)
    return gx >= 1 and gx <= GRID_SIZE and gz >= 1 and gz <= GRID_SIZE
end

--------------------------------------------------------------------------
-- Snake + food state
--------------------------------------------------------------------------

local snake = { dir = "right", segments = {} }
local food  = { gx = 1, gz = 1 }
local score, bestScore, episode = 0, 0, 0

local function makeSegmentPart()
    local part = Instance.new("Part")
    part.Size = Vector3.new(CELL_SIZE * 0.9, CELL_SIZE * 0.9, CELL_SIZE * 0.9)
    part.Anchored = true
    part.CanCollide = false
    part.Parent = segmentsFolder
    return part
end

local function isOccupiedBySnake(gx, gz, excludeTail)
    local segs = snake.segments
    local limit = excludeTail and (#segs - 1) or #segs
    for i = 1, limit do
        local s = segs[i]
        if s.gx == gx and s.gz == gz then
            return true
        end
    end
    return false
end

local function spawnFood()
    local attempts = 0
    repeat
        food.gx = math.random(1, GRID_SIZE)
        food.gz = math.random(1, GRID_SIZE)
        attempts += 1
    until not isOccupiedBySnake(food.gx, food.gz, false) or attempts > 200

    foodPart.Position = cellToWorld(food.gx, food.gz)
end

local function recolorSegments()
    for i, segment in ipairs(snake.segments) do
        segment.part.Color = (i == 1) and HEAD_COLOR or BODY_COLOR
    end
end

local function updateScoreboard()
    scoreLabel.Text = ("Score: %d  Best: %d  Episode: %d"):format(score, bestScore, episode)
end

local function resetEpisode()
    for _, segment in ipairs(snake.segments) do
        segment.part:Destroy()
    end

    snake.dir = "right"
    snake.segments = {}

    local startGx, startGz = math.floor(GRID_SIZE / 2), math.floor(GRID_SIZE / 2)
    for i = 0, 2 do
        local gx = startGx - i
        local part = makeSegmentPart()
        part.Position = cellToWorld(gx, startGz)
        table.insert(snake.segments, { gx = gx, gz = startGz, part = part })
    end
    recolorSegments()

    spawnFood()

    score = 0
    episode += 1
    updateScoreboard()
end

resetEpisode()

--------------------------------------------------------------------------
-- AI -- danger/direction/food flags in 4 absolute directions, one of
-- up/down/left/right out.
--------------------------------------------------------------------------

local SCHEMA = {}
for _, name in ipairs({
    "danger_up", "danger_down", "danger_left", "danger_right",
    "dir_up", "dir_down", "dir_left", "dir_right",
    "food_up", "food_down", "food_left", "food_right",
}) do
    SCHEMA[name] = { range = { 0, 1 } }
end

local SnakeStore = DataStoreService:GetDataStore("WormSnakeAI")

local function loadSnakeAI()
    local ok, data = pcall(function()
        return SnakeStore:GetAsync(SAVE_KEY)
    end)
    if ok and data then
        print("SnakeGame -- restored trained AI from DataStore")
        return Worm.load(data)
    end
    return nil
end

local SnakeAI = loadSnakeAI() or Worm.build(Worm.QLEARN, {
    states  = 12,
    actions = #ACTION_LABELS,
    gamma         = 0.9,
    epsilon       = 1.0,
    epsilon_decay = 0.998,
    epsilon_min   = 0.02,
    memory        = 8000,
    batch         = 64,
    schema = SCHEMA,
})

SnakeAI:labels(ACTION_LABELS)
SnakeAI:rewards({
    ate_food = 10,
    died     = -10,
    closer   = 0.1,
    farther  = -0.1,
    idle     = 0,
})

local function saveSnakeAI()
    SnakeAI:export()
        :next(function(data)
            local ok, err = pcall(function()
                SnakeStore:SetAsync(SAVE_KEY, data)
            end)
            if not ok then
                warn("SnakeGame save --", err)
            end
        end)
        :toss(function(err)
            warn("SnakeGame export --", err)
        end)
end

local function buildState()
    local head = snake.segments[1]

    local function danger(dx, dz)
        local gx, gz = head.gx + dx, head.gz + dz
        if not inBounds(gx, gz) then
            return 1
        end
        if isOccupiedBySnake(gx, gz, true) then
            return 1
        end
        return 0
    end

    return {
        danger_up    = danger(DIRS.up.dx, DIRS.up.dz),
        danger_down  = danger(DIRS.down.dx, DIRS.down.dz),
        danger_left  = danger(DIRS.left.dx, DIRS.left.dz),
        danger_right = danger(DIRS.right.dx, DIRS.right.dz),
        dir_up       = snake.dir == "up" and 1 or 0,
        dir_down     = snake.dir == "down" and 1 or 0,
        dir_left     = snake.dir == "left" and 1 or 0,
        dir_right    = snake.dir == "right" and 1 or 0,
        food_up      = food.gz < head.gz and 1 or 0,
        food_down    = food.gz > head.gz and 1 or 0,
        food_left    = food.gx < head.gx and 1 or 0,
        food_right   = food.gx > head.gx and 1 or 0,
    }
end

local function manhattan(gx1, gz1, gx2, gz2)
    return math.abs(gx1 - gx2) + math.abs(gz1 - gz2)
end

local function resolveReward(ate, died, prevDist, newDist)
    if died then
        return "died"
    end
    if ate then
        return "ate_food"
    end
    if newDist < prevDist then
        return "closer"
    end
    if newDist > prevDist then
        return "farther"
    end
    return "idle"
end

--------------------------------------------------------------------------
-- Game loop
--------------------------------------------------------------------------

local prevState, prevActionIndex = nil, nil
local episodeOver = false
local globalEpisodeCount = 0

local function applyDeath()
    episodeOver = true
    for _, segment in ipairs(snake.segments) do
        segment.part.Color = DEAD_COLOR
    end

    if score > bestScore then
        bestScore = score
    end
    updateScoreboard()

    task.delay(EPISODE_RESET_DELAY, function()
        resetEpisode()
        prevState, prevActionIndex = nil, nil
        episodeOver = false

        globalEpisodeCount += 1
        if globalEpisodeCount % SAVE_EVERY_EPISODES == 0 then
            saveSnakeAI()
        end
    end)
end

local function step()
    local head = snake.segments[1]
    local prevDist = manhattan(head.gx, head.gz, food.gx, food.gz)
    local state = buildState()

    SnakeAI:infer(state)
        :next(function()
            -- QLearner resolves the actual epsilon-greedy/argmax choice
            -- internally; pull it back out so lesson() trains the index
            -- it really picked, not a label round-tripped through text.
            local actionIndex = SnakeAI._impl._lastAction
            local direction    = ACTION_LABELS[actionIndex]
            local delta          = DIRS[direction]

            local newGx, newGz = head.gx + delta.dx, head.gz + delta.dz
            local ate  = newGx == food.gx and newGz == food.gz
            local died = not inBounds(newGx, newGz) or isOccupiedBySnake(newGx, newGz, not ate)

            -- Computed before spawnFood() below moves the food -- ate/died
            -- both short-circuit resolveReward before newDist is read, but
            -- it should still mean "distance to the food that mattered".
            local newDist = manhattan(newGx, newGz, food.gx, food.gz)
            local reward  = resolveReward(ate, died, prevDist, newDist)

            if not died then
                snake.dir = direction
                if ate then
                    local part = makeSegmentPart()
                    part.Position = cellToWorld(newGx, newGz)
                    table.insert(snake.segments, 1, { gx = newGx, gz = newGz, part = part })
                    score += 1
                    spawnFood()
                else
                    local tail = table.remove(snake.segments)
                    tail.gx, tail.gz = newGx, newGz
                    tail.part.Position = cellToWorld(newGx, newGz)
                    table.insert(snake.segments, 1, tail)
                end
                recolorSegments()
                updateScoreboard()
            end

            if prevState and prevActionIndex then
                SnakeAI:lesson({
                    state  = prevState,
                    action = prevActionIndex,
                    next   = state,
                    reward = reward,
                    done   = died,
                })
            end

            if died then
                applyDeath()
                prevState, prevActionIndex = nil, nil
            else
                prevState, prevActionIndex = state, actionIndex
            end
        end)
        :toss(function(err)
            warn("SnakeGame infer --", err)
        end)
end

task.spawn(function()
    while true do
        if not episodeOver then
            step()
        end
        task.wait(TICK_INTERVAL)
    end
end)

game:BindToClose(function()
    saveSnakeAI()
    task.wait(2)
end)
]====]
snakeGame.Parent = ServerScriptService

print("WormSnakeGameSetup -- done. Press Play -- the board builds itself and the AI starts training immediately.")
