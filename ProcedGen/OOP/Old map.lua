-- map.lua
local Coin = require "coin"
local Map = {}
Map.__index = Map

Map.CHUNK_W = 40
Map.CHUNK_H = 30
Map.CELL_SIZE = 20
Map.coinChance = 0.005

Map.TILES = { WATER = 1, SAND = 2, GRASS = 3, FOREST = 4, LAVA = 5, MOUNTAIN = 6, ROCK = 7 }
Map.COLORS = {
    [Map.TILES.WATER]    = {0.2, 0.4, 0.9, 1.0},
    [Map.TILES.SAND]     = {0.9, 0.8, 0.5, 1.0},
    [Map.TILES.GRASS]    = {0.3, 0.7, 0.2, 1.0},
    [Map.TILES.FOREST]   = {0.1, 0.4, 0.1, 1.0},
    [Map.TILES.LAVA]     = {1.0, 0.3, 0.0, 1.0},
    [Map.TILES.MOUNTAIN] = {0.6, 0.6, 0.6, 1.0},
    [Map.TILES.ROCK]     = {0.4, 0.4, 0.4, 1.0},
    UNCOLLAPSED          = {1, 1, 1, 1}
}

local function chunkKey(cx, cy) return cx .. "," .. cy end

function Map:new()
    local instance = setmetatable({}, self)
    instance.worldChunks = {}
    instance.coins = {}
    instance:initializeRules()
    return instance
end

function Map:initializeRules()
    self.rules = {}
    local function addRule(t1, t2, dir)
        self.rules[t1] = self.rules[t1] or {}
        self.rules[t1][t2] = self.rules[t1][t2] or {}
        self.rules[t1][t2][dir] = true
    end
    local function addMutualRule(t1, t2, d1, d2)
        addRule(t1, t2, d1)
        addRule(t2, t1, d2)
    end
    local T = Map.TILES
    -- define all adjacency rules (water, sand, grass, forest, rock, lava, mountain)
    addMutualRule(T.WATER, T.WATER, "up","down")
    addMutualRule(T.WATER, T.WATER, "right","left")
    addMutualRule(T.WATER, T.SAND,  "up","down")
    addMutualRule(T.WATER, T.SAND,  "right","left")
    addMutualRule(T.SAND,  T.SAND,  "up","down")
    addMutualRule(T.SAND,  T.SAND,  "right","left")
    addMutualRule(T.SAND,  T.GRASS, "up","down")
    addMutualRule(T.SAND,  T.GRASS, "right","left")
    addMutualRule(T.GRASS, T.GRASS, "up","down")
    addMutualRule(T.GRASS, T.GRASS, "right","left")
    addMutualRule(T.GRASS, T.FOREST,"up","down")
    addMutualRule(T.GRASS, T.FOREST,"right","left")
    addMutualRule(T.FOREST,T.FOREST,"up","down")
    addMutualRule(T.FOREST,T.FOREST,"right","left")
    addMutualRule(T.ROCK,  T.ROCK,  "up","down")
    addMutualRule(T.ROCK,  T.ROCK,  "right","left")
    addMutualRule(T.ROCK,  T.SAND,  "up","down")
    addMutualRule(T.ROCK,  T.SAND,  "right","left")
    addMutualRule(T.ROCK,  T.GRASS, "up","down")
    addMutualRule(T.ROCK,  T.GRASS, "right","left")
    addMutualRule(T.LAVA,  T.LAVA,  "up","down")
    addMutualRule(T.LAVA,  T.LAVA,  "right","left")
    addMutualRule(T.LAVA,  T.ROCK,  "up","down")
    addMutualRule(T.LAVA,  T.ROCK,  "right","left")
    addMutualRule(T.MOUNTAIN,T.MOUNTAIN,"up","down")
    addMutualRule(T.MOUNTAIN,T.MOUNTAIN,"right","left")
    addMutualRule(T.MOUNTAIN,T.ROCK,   "up","down")
    addMutualRule(T.MOUNTAIN,T.ROCK,   "right","left")
    -- collect all tile IDs
    self.allTileIDs = {}
    for _,v in pairs(self.TILES) do table.insert(self.allTileIDs, v) end
end

function Map:generateChunk(cx, cy)
    local chunk = { grid = {} }
    for y=1,self.CHUNK_H do
        chunk.grid[y] = {}
        for x=1,self.CHUNK_W do
            local poss = {}
            for _,id in ipairs(self.allTileIDs) do poss[id] = true end
            chunk.grid[y][x] = { possibilities = poss, entropy = #self.allTileIDs, collapsed = false }
        end
    end
    -- seed edges from existing chunks
    local neighbors = {
        top    = self.worldChunks[chunkKey(cx, cy-1)],
        bottom = self.worldChunks[chunkKey(cx, cy+1)],
        left   = self.worldChunks[chunkKey(cx-1, cy)],
        right  = self.worldChunks[chunkKey(cx+1, cy)]
    }
    local function collapseCell(cell, tile)
        cell.possibilities = { [tile] = true }
        cell.entropy = 1
        cell.collapsed = true
    end
    if neighbors.top then
        for x=1,self.CHUNK_W do
            local nc = neighbors.top.grid[self.CHUNK_H][x]
            if nc.collapsed then collapseCell(chunk.grid[1][x], next(nc.possibilities)) end
        end
    end
    if neighbors.bottom then
        for x=1,self.CHUNK_W do
            local nc = neighbors.bottom.grid[1][x]
            if nc.collapsed then collapseCell(chunk.grid[self.CHUNK_H][x], next(nc.possibilities)) end
        end
    end
    if neighbors.left then
        for y=1,self.CHUNK_H do
            local nc = neighbors.left.grid[y][self.CHUNK_W]
            if nc.collapsed then collapseCell(chunk.grid[y][1], next(nc.possibilities)) end
        end
    end
    if neighbors.right then
        for y=1,self.CHUNK_H do
            local nc = neighbors.right.grid[y][1]
            if nc.collapsed then collapseCell(chunk.grid[y][self.CHUNK_W], next(nc.possibilities)) end
        end
    end
    -- propagation
    local function propagate(ch, sx, sy)
        local stack = {}
        local function add(px, py)
            if px>=1 and px<=self.CHUNK_W and py>=1 and py<=self.CHUNK_H then
                local k = py*self.CHUNK_W + px
                if not stack[k] then stack[k] = { x = px, y = py } end
            end
        end
        add(sx, sy-1); add(sx+1, sy); add(sx, sy+1); add(sx-1, sy)
        while true do
            local proc = {}
            for _,v in pairs(stack) do table.insert(proc, v) end
            if #proc==0 then break end
            stack = {}
            for _,pos in ipairs(proc) do
                local c = ch.grid[pos.y][pos.x]
                if not c.collapsed then
                    local first = true
                    local allowed = {}
                    local dx={0,1,0,-1}; local dy={-1,0,1,0}
                    local dirs={"down","left","up","right"}
                    for i=1,4 do
                        local sx, sy = pos.x+dx[i], pos.y+dy[i]
                        if sx>=1 and sx<=self.CHUNK_W and sy>=1 and sy<=self.CHUNK_H then
                            local sc = ch.grid[sy][sx]
                            if sc.collapsed then
                                local sid = next(sc.possibilities)
                                local layer = {}
                                if self.rules[sid] then
                                    for pid,rs in pairs(self.rules[sid]) do
                                        if rs[dirs[i]] then layer[pid] = true end
                                    end
                                end
                                if first then allowed = layer; first = false
                                else for k,_ in pairs(allowed) do if not layer[k] then allowed[k] = nil end end end
                            end
                        end
                    end
                    if not first then
                        local changed = false
                        for pid,_ in pairs(c.possibilities) do
                            if not allowed[pid] then c.possibilities[pid] = nil; c.entropy = c.entropy-1; changed = true end
                        end
                        if changed then
                            if c.entropy==0 then print("Error: contradiction at chunk") return end
                            if c.entropy==1 then c.collapsed = true end
                            add(pos.x, pos.y-1); add(pos.x+1, pos.y); add(pos.x, pos.y+1); add(pos.x-1, pos.y)
                        end
                    end
                end
            end
        end
    end
    -- initial propagate seeded cells
    for y=1,self.CHUNK_H do for x=1,self.CHUNK_W do
        if chunk.grid[y][x].collapsed then propagate(chunk, x, y) end
    end end
    -- collapse loop
    local function findLowest(ch)
        local minEntropy = #self.allTileIDs + 1; local cand
        for y=1,self.CHUNK_H do for x=1,self.CHUNK_W do
            local cc = ch.grid[y][x]
            if not cc.collapsed and cc.entropy>1 and cc.entropy<minEntropy
            then minEntropy = cc.entropy; cand={ x=x, y=y } end
        end end
        return cand
    end
    local cand = findLowest(chunk)
    while cand do
        local cc = chunk.grid[cand.y][cand.x]
        local opts = {}
        for pid,_ in pairs(cc.possibilities) do table.insert(opts, pid) end
        local choice = opts[math.random(#opts)]
        cc.possibilities = { [choice] = true }
        cc.entropy = 1; cc.collapsed = true
        propagate(chunk, cand.x, cand.y)
        cand = findLowest(chunk)
    end
    -- spawn coins
    for y=1,self.CHUNK_H do for x=1,self.CHUNK_W do
        if math.random() < self.coinChance then
            local wx = cx*(self.CHUNK_W*self.CELL_SIZE) + (x-1)*self.CELL_SIZE + self.CELL_SIZE/2
            local wy = cy*(self.CHUNK_H*self.CELL_SIZE) + (y-1)*self.CELL_SIZE + self.CELL_SIZE/2
            table.insert(self.coins, Coin:new(wx, wy))
        end
    end end
    return chunk
end

function Map:getChunk(cx, cy)
    local key = chunkKey(cx, cy)
    if not self.worldChunks[key] then self.worldChunks[key] = self:generateChunk(cx, cy) end
    return self.worldChunks[key]
end

function Map:getTileAt(x, y)
    local cs = self.CELL_SIZE
    local cx = math.floor(x / (cs * self.CHUNK_W))
    local cy = math.floor(y / (cs * self.CHUNK_H))
    local chunk = self:getChunk(cx, cy)
    local lx = math.floor((x - cx*self.CHUNK_W*cs)/cs) + 1
    local ly = math.floor((y - cy*self.CHUNK_H*cs)/cs) + 1
    local cell = chunk.grid[ly] and chunk.grid[ly][lx]
    if cell and cell.collapsed then return next(cell.possibilities) end
    return nil
end

return Map
