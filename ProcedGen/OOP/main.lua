-- main.lua
local Player = require "player"
local Map    = require "map"


-- Constants
local baseHealthDecay = 4
local lavaHealthDecay = 10
local coinHealthBoost = 15

function love.load()
    math.randomseed(os.time())
    map = Map:new()
    player = Player:new(200, 200)

    -- Fonts
    levelUp = love.graphics.newFont(20)
    default = love.graphics.newFont(12)

end

function love.update(dt)
    if player.health > 0 then
        player:update(dt, map, map.coins, coinHealthBoost, baseHealthDecay, lavaHealthDecay)
    end
    if love.keyboard.isDown("r") then
        map = Map:new()
        player = Player:new(200, 200)
    end
end

function love.draw()
    if player.health <= 0 then
        love.graphics.setColor(1, 0, 0)
        love.graphics.print("Game Over!", love.graphics.getWidth()/2-50, love.graphics.getHeight()/2-20)
        local bx, by, bw, bh = love.graphics.getWidth()/2-60, love.graphics.getHeight()/2+20, 100, 30
        love.graphics.setColor(0.2,0.2,0.2)
        love.graphics.rectangle("fill", bx,by,bw,bh)
        love.graphics.setColor(1,1,1)
        love.graphics.printf("Respawn", bx, by+8, bw, "center")
        if love.mouse.isDown(1) then
            local mx,my = love.mouse.getPosition()
            if mx>=bx and mx<=bx+bw and my>=by and my<=by+bh then
                map = Map:new()
                player = Player:new(200, 200)
            end
        end
        return
    end
    local sw, sh = love.graphics.getWidth(), love.graphics.getHeight()
    love.graphics.push()
    love.graphics.translate(sw/2 - player.x, sh/2 - player.y)
    local cs = Map.CELL_SIZE
    local ccx = math.floor(player.x/(cs*Map.CHUNK_W))
    local ccy = math.floor(player.y/(cs*Map.CHUNK_H))
    for cx = ccx-1, ccx+1 do for cy = ccy-1, ccy+1 do
        local chunk = map:getChunk(cx, cy)
        local offX, offY = cx*Map.CHUNK_W*cs, cy*Map.CHUNK_H*cs
        for y=1,Map.CHUNK_H do for x=1,Map.CHUNK_W do
            local cell = chunk.grid[y][x]
            local tile = next(cell.possibilities) or 0
            if tile == Map.TILES.WATER then
                love.graphics.setColor(0,0,(180+math.random(20))/255)
            else
                love.graphics.setColor(Map.COLORS[tile] or Map.COLORS.UNCOLLAPSED)
            end
            love.graphics.rectangle("fill", offX+(x-1)*cs, offY+(y-1)*cs, cs-1, cs-1)
        end end
    end end
    for _,c in ipairs(map.coins) do c:draw() end
    player:draw(map)
    love.graphics.pop()


    -- HUD

        -- health bar
    local hbW = (player.health/player.maxHealth)*100
    love.graphics.setColor(0,0,0)
    love.graphics.rectangle("fill",22,22,104,24)
    love.graphics.setColor(0,1,0)
    love.graphics.rectangle("fill",24,24,hbW,20)
    love.graphics.setColor(1,1,1)
    love.graphics.print("Use WASD or arrow keys to move", 10, sh-30)
    
        -- health text
    local tu = map:getTileAt(player.x, player.y)
    if tu == Map.TILES.LAVA then
        love.graphics.setColor(1,0,0)
        love.graphics.rectangle("fill",24,24,hbW,20)
        love.graphics.setColor(1,1,0)
        love.graphics.print("Health (BURNING): "..math.floor(player.health), 20, 50)
    elseif tu == Map.TILES.WATER then
        love.graphics.setColor(1,1,0)
        love.graphics.print("Health (SWIMMING): "..math.floor(player.health), 20, 50)
    else
        love.graphics.setColor(0,1,0)
        love.graphics.print("Health: "..math.floor(player.health), 20, 50)
        love.graphics.rectangle("fill",24,24,hbW,20)
    end

        -- level bar
    local lbW = (player.coinsCollected/player.coinsForLevelUp)*100
    love.graphics.setColor(0,0,0)
    love.graphics.rectangle("fill",678,22,104,24)
    love.graphics.setColor(1, 0.84, 0, 1 ) -- gold color
    love.graphics.rectangle("fill",680,24,lbW,20)
    love.graphics.setColor(1,1,1)

    love.graphics.setColor(1, 0.84, 0, 1)
    love.graphics.print("Coins Needed: "..player.coinsForLevelUp - player.coinsCollected, 680, sh - 530)
    love.graphics.print("Coins Collected: "..player.totalCoins, 20, 70)

    love.graphics.setColor(0,1,0)
    love.graphics.print("Level: "..player.level, 680, sh - 550)
    love.graphics.setColor(1,1,1)

    

        -- level up message
    if player.currentMessage then

        if player.isErrorMessage then
            love.graphics.setColor(1,0,0)  -- red text
        else
            love.graphics.setColor(1,1,0)  -- yellow text
        end
        
        love.graphics.setFont(levelUp)
        love.graphics.printf(
        player.currentMessage,
        0, love.graphics.getHeight()/2 + 20,
        love.graphics.getWidth(),
        "center"
        )
        love.graphics.setColor(1,1,1)
        love.graphics.setFont(default)
    end
        -- instructions
    love.graphics.print("Collect coins to gain health and level up!", 10, sh-50)
    love.graphics.print("Avoid LAVA to prevent health loss!", 10, sh-70)
    love.graphics.print("Press 'R' to restart", 10, sh-90)
end
