-- main.lua
--[[ 
  Endless WFC World with Player, Health & Coins (Coin Spawns during Procedural Generation)
  - Procedurally generates world chunks using a wave function collapse system.
  - The player moves around and has a health bar that decreases over time.
  - Standing on LAVA decreases health faster.
  - Coins are placed during chunk generation with a chance, and collecting them boosts health.
--]]

----------------------------
-- TILE SETUP & RULES
----------------------------
local TILES = {
    WATER = 1,
    SAND  = 2,
    GRASS = 3,
    FOREST = 4,
    LAVA = 5,
    MOUNTAIN = 6,
    ROCK = 7,
}

local COLORS = {
    [TILES.WATER]    = {0.2, 0.4, 0.9, 1.0},  -- Blue
    [TILES.SAND]     = {0.9, 0.8, 0.5, 1.0},  -- Yellow
    [TILES.GRASS]    = {0.3, 0.7, 0.2, 1.0},  -- Green
    [TILES.FOREST]   = {0.1, 0.4, 0.1, 1.0},  -- Dark Green
    [TILES.LAVA]     = {1.0, 0.3, 0.0, 1.0},  -- Orange-red for lava
    [TILES.MOUNTAIN] = {0.6, 0.6, 0.6, 1.0},  -- Gray for mountains
    [TILES.ROCK]     = {0.4, 0.4, 0.4, 1.0},  -- Uniform gray for rocky
    UNCOLLAPSED      = {1, 1, 1, 1},          -- White for uncollapsed cells
}

local rules = {}

local function addRule(t1, t2, dir)
    rules[t1] = rules[t1] or {}
    rules[t1][t2] = rules[t1][t2] or {}
    rules[t1][t2][dir] = true
end

local function addMutualRule(t1, t2, dir1, dir2)
    addRule(t1, t2, dir1)
    addRule(t2, t1, dir2)
end

-- Set up simple transition rules.
-- Water next to Water/Sand
addMutualRule(TILES.WATER, TILES.WATER, "up", "down")
addMutualRule(TILES.WATER, TILES.WATER, "right", "left")
addMutualRule(TILES.WATER, TILES.SAND, "up", "down")
addMutualRule(TILES.WATER, TILES.SAND, "right", "left")

-- Sand next to Water/Sand/Grass
addMutualRule(TILES.SAND, TILES.SAND, "up", "down")
addMutualRule(TILES.SAND, TILES.SAND, "right", "left")
addMutualRule(TILES.SAND, TILES.GRASS, "up", "down")
addMutualRule(TILES.SAND, TILES.GRASS, "right", "left")

-- Grass next to Sand/Grass/Forest
addMutualRule(TILES.GRASS, TILES.GRASS, "up", "down")
addMutualRule(TILES.GRASS, TILES.GRASS, "right", "left")
addMutualRule(TILES.GRASS, TILES.FOREST, "up", "down")
addMutualRule(TILES.GRASS, TILES.FOREST, "right", "left")

-- Forest next to Grass/Forest
addMutualRule(TILES.FOREST, TILES.FOREST, "up", "down")
addMutualRule(TILES.FOREST, TILES.FOREST, "right", "left")

-- Rock next to Rock/Sand/Grass
addMutualRule(TILES.ROCK, TILES.ROCK, "up", "down")
addMutualRule(TILES.ROCK, TILES.ROCK, "right", "left")
addMutualRule(TILES.ROCK, TILES.SAND, "up", "down")
addMutualRule(TILES.ROCK, TILES.SAND, "right", "left")
addMutualRule(TILES.ROCK, TILES.GRASS, "up", "down")
addMutualRule(TILES.ROCK, TILES.GRASS, "right", "left")

-- Lava next to Lava/Rock
addMutualRule(TILES.LAVA, TILES.LAVA, "up", "down")
addMutualRule(TILES.LAVA, TILES.LAVA, "right", "left")
addMutualRule(TILES.LAVA, TILES.ROCK, "up", "down")
addMutualRule(TILES.LAVA, TILES.ROCK, "right", "left")

-- Mountain next to Mountain/Rock
addMutualRule(TILES.MOUNTAIN, TILES.MOUNTAIN, "up", "down")
addMutualRule(TILES.MOUNTAIN, TILES.MOUNTAIN, "right", "left")
addMutualRule(TILES.MOUNTAIN, TILES.ROCK, "up", "down")
addMutualRule(TILES.MOUNTAIN, TILES.ROCK, "right", "left")

-- Build an array of all tile IDs for iteration.
local allTileIDs = {}
for key, value in pairs(TILES) do
    if type(value) == "number" then
        table.insert(allTileIDs, value)
    end
end

----------------------------
-- CHUNK & WORLD CONFIGURATION
----------------------------
local CHUNK_W, CHUNK_H = 40, 30   -- Cells per chunk in X and Y
local CELL_SIZE = 20              -- Pixel size of each cell

local worldChunks = {}

local function chunkKey(cx, cy)
    return cx .. "," .. cy
end

local function worldToChunk(pos, cellSize, chunkCount)
    return math.floor(pos / (cellSize * chunkCount))
end

----------------------------
-- COIN & HEALTH MECHANICS
----------------------------
-- Global table to hold coins (spawned during chunk generation).
coins = {}

-- When a coin is collected, the player gains some health.
local coinHealthBoost = 15   -- Health gained per coin

-- Player setup (including health properties).
player = {
    x = 200,
    y = 200,
    speed = 150,
    health = 100,
    maxHealth = 100
}

-- Base health decay per second.
local baseHealthDecay = 1
-- Extra decay per second when standing on LAVA.
local lavaHealthDecay = 4

----------------------------
-- CHUNK GENERATION & WFC FUNCTIONS
----------------------------
-- Forward-declare getChunk so it can be used in getTileAt.
local getChunk

-- Helper function: Given world coordinates, return the tile beneath.
-- (Must be defined after getChunk, so we forward-declare it later.)
local function getTileAt(x, y)
    local cellSize = CELL_SIZE
    local chunkX = math.floor(x / (cellSize * CHUNK_W))
    local chunkY = math.floor(y / (cellSize * CHUNK_H))
    local chunk = getChunk(chunkX, chunkY)
    local localX = math.floor((x - chunkX * CHUNK_W * cellSize) / cellSize) + 1
    local localY = math.floor((y - chunkY * CHUNK_H * cellSize) / cellSize) + 1
    local cell = chunk.grid[localY] and chunk.grid[localY][localX]
    if cell and cell.collapsed then
        return next(cell.possibilities)
    end
    return nil
end

local function propagateChunk(chunk, startX, startY)
    local stack = {}
    local function addToStack(x, y)
        if x >= 1 and x <= CHUNK_W and y >= 1 and y <= CHUNK_H then
            local key = y * CHUNK_W + x
            if not stack[key] then
                stack[key] = {x = x, y = y}
            end
        end
    end

    addToStack(startX, startY - 1)
    addToStack(startX + 1, startY)
    addToStack(startX, startY + 1)
    addToStack(startX - 1, startY)

    local processedStack = {}
    while true do
        processedStack = {}
        for _, cellPos in pairs(stack) do
            table.insert(processedStack, cellPos)
        end
        if #processedStack == 0 then break end
        stack = {}
        for _, current in ipairs(processedStack) do
            local nx, ny = current.x, current.y
            local neighbor = chunk.grid[ny][nx]
            if not neighbor.collapsed then
                local firstNeighbor = true
                local possibleBasedOnNeighbors = {}
                local dx = {0, 1, 0, -1}
                local dy = {-1, 0, 1, 0}
                local oppositeDirs = {"down", "left", "up", "right"}
                for i = 1, 4 do
                    local sourceX = nx + dx[i]
                    local sourceY = ny + dy[i]
                    local sourceToNeighborDir = oppositeDirs[i]
                    if sourceX >= 1 and sourceX <= CHUNK_W and sourceY >= 1 and sourceY <= CHUNK_H then
                        local sourceCell = chunk.grid[sourceY][sourceX]
                        if sourceCell.collapsed then
                            local sourceTileID = next(sourceCell.possibilities)
                            local allowedBySource = {}
                            if rules[sourceTileID] then
                                for potentialID, ruleSet in pairs(rules[sourceTileID]) do
                                    if ruleSet[sourceToNeighborDir] then
                                        allowedBySource[potentialID] = true
                                    end
                                end
                            end
                            if firstNeighbor then
                                possibleBasedOnNeighbors = allowedBySource
                                firstNeighbor = false
                            else
                                for existing, _ in pairs(possibleBasedOnNeighbors) do
                                    if not allowedBySource[existing] then
                                        possibleBasedOnNeighbors[existing] = nil
                                    end
                                end
                            end
                        end
                    end
                end
                if not firstNeighbor then
                    local changed = false
                    for possibility, _ in pairs(neighbor.possibilities) do
                        if not possibleBasedOnNeighbors[possibility] then
                            neighbor.possibilities[possibility] = nil
                            neighbor.entropy = neighbor.entropy - 1
                            changed = true
                        end
                    end
                    if changed then
                        if neighbor.entropy == 0 then
                            print("Error: Contradiction at cell", nx, ny)
                            return
                        elseif neighbor.entropy == 1 then
                            neighbor.collapsed = true
                        end
                        addToStack(nx, ny - 1)
                        addToStack(nx + 1, ny)
                        addToStack(nx, ny + 1)
                        addToStack(nx - 1, ny)
                    end
                end
            end
        end
    end
end

local function generateChunk(cx, cy)
    local chunk = {}
    chunk.grid = {}
    for y = 1, CHUNK_H do
        chunk.grid[y] = {}
        for x = 1, CHUNK_W do
            local possibilities = {}
            for _, tileID in ipairs(allTileIDs) do
                possibilities[tileID] = true
            end
            chunk.grid[y][x] = {
                possibilities = possibilities,
                entropy = #allTileIDs,
                collapsed = false
            }
        end
    end

    -- Seed edge cells if neighboring chunks exist.
    local function collapseCell(cell, tileID)
        cell.possibilities = { [tileID] = true }
        cell.entropy = 1
        cell.collapsed = true
    end

    local top = worldChunks[chunkKey(cx, cy - 1)]
    local bottom = worldChunks[chunkKey(cx, cy + 1)]
    local left = worldChunks[chunkKey(cx - 1, cy)]
    local right = worldChunks[chunkKey(cx + 1, cy)]

    if top then
        for x = 1, CHUNK_W do
            local neighborCell = top.grid[CHUNK_H] and top.grid[CHUNK_H][x]
            if neighborCell and neighborCell.collapsed then
                local tileID = next(neighborCell.possibilities)
                collapseCell(chunk.grid[1][x], tileID)
            end
        end
    end
    if bottom then
        for x = 1, CHUNK_W do
            local neighborCell = bottom.grid[1] and bottom.grid[1][x]
            if neighborCell and neighborCell.collapsed then
                local tileID = next(neighborCell.possibilities)
                collapseCell(chunk.grid[CHUNK_H][x], tileID)
            end
        end
    end
    if left then
        for y = 1, CHUNK_H do
            local neighborCell = left.grid[y] and left.grid[y][CHUNK_W]
            if neighborCell and neighborCell.collapsed then
                local tileID = next(neighborCell.possibilities)
                collapseCell(chunk.grid[y][1], tileID)
            end
        end
    end
    if right then
        for y = 1, CHUNK_H do
            local neighborCell = right.grid[y] and right.grid[y][1]
            if neighborCell and neighborCell.collapsed then
                local tileID = next(neighborCell.possibilities)
                collapseCell(chunk.grid[y][CHUNK_W], tileID)
            end
        end
    end

    -- Propagate seeded edge cells.
    for y = 1, CHUNK_H do
        for x = 1, CHUNK_W do
            local cell = chunk.grid[y][x]
            if cell.collapsed then
                propagateChunk(chunk, x, y)
            end
        end
    end

    local function findLowestEntropyCell()
        local minEntropy = #allTileIDs + 1
        local candidate = nil
        for y = 1, CHUNK_H do
            for x = 1, CHUNK_W do
                local cell = chunk.grid[y][x]
                if not cell.collapsed and cell.entropy > 1 and cell.entropy < minEntropy then
                    minEntropy = cell.entropy
                    candidate = { x = x, y = y }
                end
            end
        end
        return candidate
    end

    local candidate = findLowestEntropyCell()
    while candidate do
        local cell = chunk.grid[candidate.y][candidate.x]
        local possibleNow = {}
        for possibility, _ in pairs(cell.possibilities) do
            table.insert(possibleNow, possibility)
        end
        if #possibleNow == 0 then
            print("Chunk generation contradiction at", candidate.x, candidate.y)
            break
        end
        local chosenTile = possibleNow[math.random(#possibleNow)]
        cell.possibilities = { [chosenTile] = true }
        cell.entropy = 1
        cell.collapsed = true

        -- *** Coin Spawn Mechanic During Generation ***
        local coinChance = 0.03  -- 5% chance to spawn a coin on this cell.
        if math.random() < coinChance then
            -- Compute the world coordinates of this cell's center.
            local worldX = cx * (CHUNK_W * CELL_SIZE) + (candidate.x - 1) * CELL_SIZE + CELL_SIZE / 2
            local worldY = cy * (CHUNK_H * CELL_SIZE) + (candidate.y - 1) * CELL_SIZE + CELL_SIZE / 2
            table.insert(coins, { x = worldX, y = worldY })
        end

        propagateChunk(chunk, candidate.x, candidate.y)
        candidate = findLowestEntropyCell()
    end

    return chunk
end

getChunk = function(cx, cy)
    local key = chunkKey(cx, cy)
    if not worldChunks[key] then
        worldChunks[key] = generateChunk(cx, cy)
    end
    return worldChunks[key]
end

----------------------------
-- LOVE2D CALLBACKS & GAME LOGIC
----------------------------
function love.load()
    love.window.setTitle("Endless WFC World")
    love.window.setMode(800, 600)
    math.randomseed(os.time())
end

function love.update(dt)
    local currentTile = getTileAt(player.x, player.y)
    if currentTile == TILES.WATER then
        player.speed = 80  -- Slower in water
    else 
        player.speed = 150  -- Normal speed
    end

    -- Player movement.
    if love.keyboard.isDown("w", "up") then
        player.y = player.y - player.speed * dt
    end
    if love.keyboard.isDown("s", "down") then
        player.y = player.y + player.speed * dt
    end
    if love.keyboard.isDown("a", "left") then
        player.x = player.x - player.speed * dt
    end
    if love.keyboard.isDown("d", "right") then
        player.x = player.x + player.speed * dt
    end

    -- Health decays over time.
    player.health = player.health - baseHealthDecay * dt

    -- Check the tile beneath the player for additional health decay (e.g., on LAVA).
    local tileUnderPlayer = getTileAt(player.x, player.y)
    if tileUnderPlayer == TILES.LAVA then
        player.health = player.health - lavaHealthDecay * dt
    end
    if player.health < 0 then
        player.health = 0
    end

    -- Check collision between player and coins (collect coins).
    for i = #coins, 1, -1 do
        local coin = coins[i]
        local dx = player.x - coin.x
        local dy = player.y - coin.y
        local distance = math.sqrt(dx * dx + dy * dy)
        if distance < 10 then  -- Collision threshold.
            player.health = math.min(player.maxHealth, player.health + coinHealthBoost)
            table.remove(coins, i)
        end
    end
end

function love.draw()
    local screenW, screenH = love.graphics.getWidth(), love.graphics.getHeight()
    love.graphics.push()
    love.graphics.translate(screenW / 2 - player.x, screenH / 2 - player.y)

    local cellSize = CELL_SIZE
    local chunkPixelW = CHUNK_W * cellSize
    local chunkPixelH = CHUNK_H * cellSize

    local currentChunkX = math.floor(player.x / (cellSize * CHUNK_W))
    local currentChunkY = math.floor(player.y / (cellSize * CHUNK_H))

    for cx = currentChunkX - 1, currentChunkX + 1 do
        for cy = currentChunkY - 1, currentChunkY + 1 do
            local chunk = getChunk(cx, cy)
            local offsetX = cx * chunkPixelW
            local offsetY = cy * chunkPixelH
            for y = 1, CHUNK_H do
                for x = 1, CHUNK_W do
                    local cell = chunk.grid[y][x]
                    local drawX = offsetX + (x - 1) * cellSize
                    local drawY = offsetY + (y - 1) * cellSize
                    local tileID = next(cell.possibilities) or 0
                    local color = COLORS[tileID] or COLORS.UNCOLLAPSED
                    love.graphics.setColor(color)
                    love.graphics.rectangle("fill", drawX, drawY, cellSize - 1, cellSize - 1)
                end
            end
        end
    end

    -- Draw coins as small gold circles.
    love.graphics.setColor(1, 0.84, 0, 1)  -- Gold color.
    for _, coin in ipairs(coins) do
        love.graphics.circle("fill", coin.x, coin.y, 5)
    end

    -- Draw the player.
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle("fill", player.x, player.y, 5)
    love.graphics.pop()

    -- Draw HUD (Health Bar)
    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", 20, 20, 104, 24) -- Background
    love.graphics.setColor(0, 1, 0, 1)
    local healthBarWidth = (player.health / player.maxHealth) * 100
    love.graphics.rectangle("fill", 22, 22, healthBarWidth, 20)
    love.graphics.setColor(1, 1, 1, 1)

    love.graphics.print("Use WASD or arrow keys to move", 10, screenH - 30)
    love.graphics.print("Collect coins to gain health!", 10, screenH - 50)
    love.graphics.print("Avoid LAVA to prevent health loss!", 10, screenH - 70)


    local tileUnderPlayer = getTileAt(player.x, player.y)
    if tileUnderPlayer == TILES.LAVA then
        love.graphics.setColor(1, 0, 0, 1) -- Red for burning
        love.graphics.rectangle("fill", 22, 22, healthBarWidth, 20)
        love.graphics.setColor(1, 1, 0, 1) -- Yellow for health text
        love.graphics.print("Health (BURNING): " .. math.floor(player.health), 20, 50)
    elseif tileUnderPlayer == TILES.WATER then
        love.graphics.setColor(1, 1, 0, 1) -- Yellow for health text
        love.graphics.print("Health (SWIMMING): " .. math.floor(player.health), 20, 50)
    else
        love.graphics.setColor(0, 1, 0, 1) -- Green for normal
        love.graphics.print("Health: " .. math.floor(player.health), 20, 50)
        love.graphics.rectangle("fill", 22, 22, healthBarWidth, 20)
    end
    
end
