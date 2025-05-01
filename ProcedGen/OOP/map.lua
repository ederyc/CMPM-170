-- map.lua
local Coin = require "coin"
local Map  = {}
Map.__index = Map

-- Grid & tile settings
Map.CHUNK_W     = 40
Map.CHUNK_H     = 30
Map.CELL_SIZE   = 20
Map.BIOME_SIZE  = 4   -- chunks per biome on each axis
Map.coinChance  = 0.005

-- Extended tile definitions
Map.TILES = {
  WATER    = 1,
  SAND     = 2,
  GRASS    = 3,
  FOREST   = 4,
  SWAMP    = 5,
  DESERT   = 6,
  SNOW     = 7,
  MOUNTAIN = 8,
  ROCK     = 9,
  LAVA     = 10,
  JUNGLE   = 11,
  VOLCANO  = 12,
}

-- Base colors for each tile
Map.COLORS = {
  [Map.TILES.WATER]    = {0.2, 0.4, 0.9, 1},  -- Deep water
  [Map.TILES.SAND]     = {0.9, 0.8, 0.5, 1},  -- Beaches
  [Map.TILES.GRASS]    = {0.3, 0.7, 0.2, 1},  -- Plains
  [Map.TILES.FOREST]   = {0.1, 0.4, 0.1, 1},  -- Trees
  [Map.TILES.SWAMP]    = {0.1, 0.3, 0.2, 1},  -- Boggy
  [Map.TILES.DESERT]   = {0.95, 0.9, 0.55, 1}, -- Arid
  [Map.TILES.SNOW]     = {0.9, 0.95, 1.0, 1}, -- Snow
  [Map.TILES.MOUNTAIN] = {0.6, 0.6, 0.6, 1},  -- High ground
  [Map.TILES.ROCK]     = {0.4, 0.4, 0.4, 1},  -- Cliff
  [Map.TILES.LAVA]     = {1.0, 0.3, 0.0, 1},  -- Magma
  [Map.TILES.JUNGLE]   = {0.1, 0.6, 0.1, 1},  -- Dense jungle
  [Map.TILES.VOLCANO]  = {0.5, 0.1, 0.0, 1},  -- Volcanic
  UNCOLLAPSED          = {1, 1, 1, 1},        -- For debugging
}

-- Tile weights for more variety
Map.tileWeights = {
  [Map.TILES.WATER]    = 1,
  [Map.TILES.SAND]     = 1,
  [Map.TILES.GRASS]    = 1,
  [Map.TILES.FOREST]   = 1,
  [Map.TILES.SWAMP]    = 0.7,
  [Map.TILES.DESERT]   = 0.4,
  [Map.TILES.SNOW]     = 0.3,
  [Map.TILES.MOUNTAIN] = 0.6,
  [Map.TILES.ROCK]     = 0.8,
  [Map.TILES.LAVA]     = 0.3,
  [Map.TILES.JUNGLE]   = 0.8,
  [Map.TILES.VOLCANO]  = 0.2,
}

local function chunkKey(cx, cy)
  return cx .. "," .. cy
end

-- Setup adjacency rules
function Map:initializeRules()
  self.rules = {}
  local function addRule(a, b, dir)
    self.rules[a] = self.rules[a] or {}
    self.rules[a][b] = self.rules[a][b] or {}
    self.rules[a][b][dir] = true
  end
  local function addBoth(a, b, d1, d2)
    addRule(a, b, d1)
    addRule(b, a, d2)
  end
  local T = Map.TILES
  -- Water <-> Sand chain
  addBoth(T.WATER, T.WATER, "up", "down"); addBoth(T.WATER, T.WATER, "right", "left")
  addBoth(T.WATER, T.SAND,  "up", "down"); addBoth(T.WATER, T.SAND,  "right", "left")
  addBoth(T.SAND,  T.SAND,  "up", "down"); addBoth(T.SAND,  T.SAND,  "right", "left")
  addBoth(T.SAND,  T.DESERT,"up", "down"); addBoth(T.SAND,  T.DESERT,"right", "left")
  -- Sand <-> Grass
  addBoth(T.SAND,  T.GRASS, "up", "down"); addBoth(T.SAND,  T.GRASS, "right", "left")
  -- Grass <-> Forest <-> Jungle
  addBoth(T.GRASS, T.GRASS, "up", "down"); addBoth(T.GRASS, T.GRASS, "right", "left")
  addBoth(T.GRASS, T.FOREST,"up", "down"); addBoth(T.GRASS, T.FOREST,"right", "left")
  addBoth(T.FOREST,T.FOREST,"up", "down"); addBoth(T.FOREST,T.FOREST,"right", "left")
  addBoth(T.FOREST,T.JUNGLE,"up", "down"); addBoth(T.FOREST,T.JUNGLE,"right", "left")
  addBoth(T.JUNGLE,T.JUNGLE,"up", "down"); addBoth(T.JUNGLE,T.JUNGLE,"right", "left")
  -- Grass <-> Swamp
  addBoth(T.GRASS, T.SWAMP, "up", "down"); addBoth(T.GRASS, T.SWAMP, "right", "left")
  addBoth(T.SWAMP, T.SWAMP,"up", "down"); addBoth(T.SWAMP, T.SWAMP,"right", "left")
  -- Mountain <-> Rock <-> Lava <-> Volcano
  addBoth(T.MOUNTAIN, T.MOUNTAIN, "up", "down"); addBoth(T.MOUNTAIN, T.MOUNTAIN, "right", "left")
  addBoth(T.MOUNTAIN, T.ROCK,     "up", "down"); addBoth(T.MOUNTAIN, T.ROCK,     "right", "left")
  addBoth(T.ROCK,     T.ROCK,     "up", "down"); addBoth(T.ROCK,     T.ROCK,     "right", "left")
  addBoth(T.ROCK,     T.LAVA,     "up", "down"); addBoth(T.ROCK,     T.LAVA,     "right", "left")
  addBoth(T.LAVA,     T.LAVA,     "up", "down"); addBoth(T.LAVA,     T.LAVA,     "right", "left")
  addBoth(T.LAVA,     T.VOLCANO,  "up", "down"); addBoth(T.LAVA,     T.VOLCANO,  "right", "left")
  addBoth(T.VOLCANO,  T.VOLCANO,  "up", "down"); addBoth(T.VOLCANO,  T.VOLCANO,  "right", "left")
  -- Mountain <-> Snow
  addBoth(T.MOUNTAIN, T.SNOW,     "up", "down"); addBoth(T.MOUNTAIN, T.SNOW,     "right", "left")
  addBoth(T.SNOW,     T.SNOW,     "up", "down"); addBoth(T.SNOW,     T.SNOW,     "right", "left")
  -- Collect all tile IDs
  self.allTileIDs = {}
  for _, id in pairs(self.TILES) do
    table.insert(self.allTileIDs, id)
  end
end

-- single-pass WFC that throws on contradiction
function Map:_generateChunkOnce(cx, cy)
  local chunk = { grid = {} }
  for y = 1, self.CHUNK_H do
    chunk.grid[y] = {}
    for x = 1, self.CHUNK_W do
      local poss = {}
      for _, tid in ipairs(self.allTileIDs) do poss[tid] = true end
      chunk.grid[y][x] = { possibilities = poss, entropy = #self.allTileIDs, collapsed = false }
    end
  end

  local function collapseCell(cell, tile)
    cell.possibilities = { [tile] = true }
    cell.entropy = 1
    cell.collapsed = true
  end

  -- neighbor seeding only within same biome
  local function sameBiome(x1,y1,x2,y2)
    return math.floor(x1/self.BIOME_SIZE)==math.floor(x2/self.BIOME_SIZE)
       and math.floor(y1/self.BIOME_SIZE)==math.floor(y2/self.BIOME_SIZE)
  end
  local neigh = { up = nil, down = nil, left = nil, right = nil }
  if sameBiome(cx, cy, cx, cy-1) then neigh.up = self.worldChunks[chunkKey(cx, cy-1)] end
  if sameBiome(cx, cy, cx, cy+1) then neigh.down = self.worldChunks[chunkKey(cx, cy+1)] end
  if sameBiome(cx, cy, cx-1, cy) then neigh.left = self.worldChunks[chunkKey(cx-1, cy)] end
  if sameBiome(cx, cy, cx+1, cy) then neigh.right = self.worldChunks[chunkKey(cx+1, cy)] end

  if neigh.up then
    for x = 1, self.CHUNK_W do
      local src = neigh.up.grid[self.CHUNK_H][x]
      if src.collapsed then collapseCell(chunk.grid[1][x], next(src.possibilities)) end
    end
  end
  if neigh.down then
    for x = 1, self.CHUNK_W do
      local src = neigh.down.grid[1][x]
      if src.collapsed then collapseCell(chunk.grid[self.CHUNK_H][x], next(src.possibilities)) end
    end
  end
  if neigh.left then
    for y = 1, self.CHUNK_H do
      local src = neigh.left.grid[y][self.CHUNK_W]
      if src.collapsed then collapseCell(chunk.grid[y][1], next(src.possibilities)) end
    end
  end
  if neigh.right then
    for y = 1, self.CHUNK_H do
      local src = neigh.right.grid[y][1]
      if src.collapsed then collapseCell(chunk.grid[y][self.CHUNK_W], next(src.possibilities)) end
    end
  end

-- propagation that errors on contradiction
  local function propagate(ch, sx, sy)
    local stack = {}
    local function add(px, py)
      if px >= 1 and px <= self.CHUNK_W and py >= 1 and py <= self.CHUNK_H then
        stack[py * self.CHUNK_W + px] = { x = px, y = py }
      end
    end
    add(sx, sy - 1); add(sx + 1, sy); add(sx, sy + 1); add(sx - 1, sy)
    local dx = {0,1,0,-1}
    local dy = {-1,0,1,0}
    local dirs = {"down","left","up","right"}
    while true do
      local proc = {}
      for _, pos in pairs(stack) do table.insert(proc, pos) end
      if #proc == 0 then break end
      stack = {}
      for _, pos in ipairs(proc) do
        local c = ch.grid[pos.y][pos.x]
        if not c.collapsed then
          local first = true
          local allowed = {}
          for i = 1, 4 do
            local nx, ny = pos.x + dx[i], pos.y + dy[i]
            if nx >= 1 and nx <= self.CHUNK_W and ny >= 1 and ny <= self.CHUNK_H then
              local sc = ch.grid[ny][nx]
              if sc.collapsed then
                local sid = next(sc.possibilities)
                local layer = {}
                if self.rules[sid] then
                  for pid, ok in pairs(self.rules[sid]) do
                    if ok[dirs[i]] then layer[pid] = true end
                  end
                end
                if first then
                  allowed, first = layer, false
                else
                  for pid in pairs(allowed) do
                    if not layer[pid] then allowed[pid] = nil end
                  end
                end
              end
            end
          end
          if not first then
            local changed = false
            for pid in pairs(c.possibilities) do
              if not allowed[pid] then
                c.possibilities[pid] = nil
                c.entropy = c.entropy - 1
                changed = true
              end
            end
            if changed then
              if c.entropy == 0 then error("contradiction") end
              if c.entropy == 1 then c.collapsed = true end
              add(pos.x, pos.y - 1)
              add(pos.x + 1, pos.y)
              add(pos.x, pos.y + 1)
              add(pos.x - 1, pos.y)
            end
          end
        end
      end
    end
  end

  -- propagate seeded cells
  for y = 1, self.CHUNK_H do
    for x = 1, self.CHUNK_W do
      if chunk.grid[y][x].collapsed then propagate(chunk, x, y) end
    end
  end

  -- collapse remaining with weighted selection
  local function findLowest(ch)
    local best, pos = math.huge, nil
    for y = 1, self.CHUNK_H do
      for x = 1, self.CHUNK_W do
        local cc = ch.grid[y][x]
        if not cc.collapsed and cc.entropy > 1 and cc.entropy < best then
          best = cc.entropy
          pos = { x = x, y = y }
        end
      end
    end
    return pos
  end

  local cand = findLowest(chunk)
  while cand do
    local cc = chunk.grid[cand.y][cand.x]
    -- gather options
    local opts = {}
    for pid in pairs(cc.possibilities) do table.insert(opts, pid) end
    -- compute total weight
    local totalW = 0
    for _, pid in ipairs(opts) do
      totalW = totalW + (Map.tileWeights[pid] or 1)
    end
    -- pick a random threshold
    local r = math.random() * totalW
    -- select by accumulating
    local accum = 0
    local choice = nil
    for _, pid in ipairs(opts) do
      accum = accum + (Map.tileWeights[pid] or 1)
      if r <= accum then
        choice = pid
        break
      end
    end
    -- collapse to choice
    cc.possibilities = { [choice] = true }
    cc.entropy = 1
    cc.collapsed = true
    propagate(chunk, cand.x, cand.y)
    cand = findLowest(chunk)
  end

    -- blend biome border edges for natural transitions
  local function blendBorder()
    local modX = cx % self.BIOME_SIZE
    local modY = cy % self.BIOME_SIZE
    -- West border of biome
    if modX == 0 then
      for y = 2, self.CHUNK_H - 1, 2 do
        local srcY = math.random(2, self.CHUNK_H - 1)
        local srcX = math.random(2, self.CHUNK_W)
        local srcTile = next(chunk.grid[srcY][srcX].possibilities)
        chunk.grid[y][1].possibilities = { [srcTile] = true }
      end
    end
    -- East border of biome
    if modX == self.BIOME_SIZE - 1 then
      for y = 2, self.CHUNK_H - 1, 2 do
        local srcY = math.random(2, self.CHUNK_H - 1)
        local srcX = math.random(1, self.CHUNK_W - 1)
        local srcTile = next(chunk.grid[srcY][srcX].possibilities)
        chunk.grid[y][self.CHUNK_W].possibilities = { [srcTile] = true }
      end
    end
    -- North border of biome
    if modY == 0 then
      for x = 2, self.CHUNK_W - 1, 2 do
        local srcX = math.random(2, self.CHUNK_W - 1)
        local srcY = math.random(2, self.CHUNK_H)
        local srcTile = next(chunk.grid[srcY][srcX].possibilities)
        chunk.grid[1][x].possibilities = { [srcTile] = true }
      end
    end
    -- South border of biome
    if modY == self.BIOME_SIZE - 1 then
      for x = 2, self.CHUNK_W - 1, 2 do
        local srcX = math.random(2, self.CHUNK_W - 1)
        local srcY = math.random(1, self.CHUNK_H - 1)
        local srcTile = next(chunk.grid[srcY][srcX].possibilities)
        chunk.grid[self.CHUNK_H][x].possibilities = { [srcTile] = true }
      end
    end
  end
  blendBorder()

  -- spawn coins unchanged
  for y = 1, self.CHUNK_H do
    for x = 1, self.CHUNK_W do
      if math.random() < self.coinChance then
        local wx = cx * (self.CHUNK_W * self.CELL_SIZE) + (x - 1) * self.CELL_SIZE + self.CELL_SIZE / 2
        local wy = cy * (self.CHUNK_H * self.CELL_SIZE) + (y - 1) * self.CELL_SIZE + self.CELL_SIZE / 2
        table.insert(self.coins, Coin:new(wx, wy))
      end
    end
  end

  return chunk
end

-- retry wrapper remains the same
function Map:generateChunk(cx, cy)
  local MAX_TRIES = 4
  for i = 1, MAX_TRIES do
    local ok, chunk = pcall(self._generateChunkOnce, self, cx, cy)
    if ok then return chunk end
    print(("Contradiction at chunk [%d,%d], retry %d/%d"):format(cx, cy, i, MAX_TRIES))
  end
  -- fallback to grass
  local chunk = { grid = {} }
  for y = 1, self.CHUNK_H do
    chunk.grid[y] = {}
    for x = 1, self.CHUNK_W do
      chunk.grid[y][x] = { possibilities = { [self.TILES.GRASS] = true }, entropy = 1, collapsed = true }
    end
  end
  print(("Chunk [%d,%d] fallback to grass"):format(cx, cy))
  return chunk
end

function Map:getChunk(cx, cy)
  self.coins = self.coins or {}
  local key = chunkKey(cx, cy)
  if not self.worldChunks[key] then self.worldChunks[key] = self:generateChunk(cx, cy) end
  return self.worldChunks[key]
end

function Map:new()
  local o = setmetatable({}, self)
  o.worldChunks = {}
  o.coins       = {}
  o:initializeRules()
  return o
end

function Map:getTileAt(x, y)
  local cs = self.CELL_SIZE
  local cx = math.floor(x / (cs * self.CHUNK_W))
  local cy = math.floor(y / (cs * self.CHUNK_H))
  local chunk = self:getChunk(cx, cy)
  local lx = math.floor((x - cx * self.CHUNK_W * cs) / cs) + 1
  local ly = math.floor((y - cy * self.CHUNK_H * cs) / cs) + 1
  local cell = chunk.grid[ly] and chunk.grid[ly][lx]
  if cell and cell.collapsed then return next(cell.possibilities) end
  return nil
end

return Map
