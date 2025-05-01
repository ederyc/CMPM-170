-- player.lua
local Entity = require "entity"
local levelDefs = require "levels"
local Player = {}
Player.__index = Player
setmetatable(Player, { __index = Entity })

function Player:new(x, y)
    local instance = Entity.new(self, x, y)
    setmetatable(instance, Player)
    instance.speed = 150
    instance.health = 100
    instance.maxHealth = 100
    instance.level = 1
    instance.coinsCollected = 0
    instance.totalCoins = 0
    instance.coinsForLevelUp = 10
    instance.currentMessage = nil
    instance.messageTimer = 0
    instance.isErrorMessage = false

    return instance
end

function Player:update(dt, map, coins, coinBoost, baseDecay, lavaDecay)

    local oldX, oldY = self.x, self.y
    local moveX, moveY = 0, 0
    if love.keyboard.isDown("w","up")    then moveY = -1 end
    if love.keyboard.isDown("s","down")  then moveY =  1 end
    if love.keyboard.isDown("a","left")  then moveX = -1 end
    if love.keyboard.isDown("d","right") then moveX =  1 end

    -- adjust speed by terrain
    local tile = map:getTileAt(self.x, self.y)
    self.speed = (tile == map.TILES.WATER) and 80 or 150

    -- compute proposed new position
    local nx = self.x + moveX * self.speed * dt
    local ny = self.y + moveY * self.speed * dt
    local nextTile = map:getTileAt(nx, ny)

    -- only allow water‐tile moves if unlocked
    if not (nextTile == map.TILES.WATER and not (self.level >= 2)) then
        self.x, self.y = nx, ny
    else
        -- if we can't move, reset to old position
        self.x, self.y = oldX, oldY
        self.isErrorMessage = true
        self.currentMessage = levelDefs[2].error
    end

    -- health decay
    self.health = self.health - baseDecay * dt
    if tile == map.TILES.LAVA then self.health = self.health - lavaDecay * dt end
    self.health = math.max(0, self.health)

    -- collect coins
    for i = #coins, 1, -1 do
        local c = coins[i]
        local dx, dy = self.x - c.x, self.y - c.y
        if math.sqrt(dx*dx + dy*dy) < 10 then
            self.health = math.min(self.maxHealth, self.health + coinBoost)
            table.remove(coins, i)

            -- track coin count
            self.coinsCollected = self.coinsCollected + 1
            self.totalCoins = self.totalCoins + 1
            if self.coinsCollected >= self.coinsForLevelUp then
                self:levelUp()
            end
        end
    end

    -- handle level up message timer 
    if self.currentMessage then
        self.messageTimer = self.messageTimer + dt
        if self.messageTimer > 3 then -- Max message duration in seconds is 3
            self.currentMessage = nil
            self.messageTimer = 0
            self.isErrorMessage = false
        end
    end

end

function Player:levelUp()
    
    self.level    = self.level + 1

    -- increase coins for next level up by 50%
    local COIN_INCREASE_PERCENT = 0.5
    local newCoinAmount = self.coinsForLevelUp + math.floor(self.coinsForLevelUp * COIN_INCREASE_PERCENT)
    self.coinsForLevelUp = newCoinAmount
    self.coinsCollected = 0
    
    -- handle level up message
    local message = levelDefs[self.level]
    self.currentMessage = "Level up!\n"
    if message then
        self.currentMessage = self.currentMessage .. message.text
    end

    print("Level up! New level: " .. self.level)
end

function Player:draw(map)
    local tile = map:getTileAt(self.x, self.y)
    if tile == map.TILES.WATER then
        love.graphics.setColor(0.4, 0.2, 0)
        love.graphics.rectangle("fill", self.x - 15, self.y, 30, 8)
        love.graphics.setColor(0.6, 0.6, 0.6)
        love.graphics.line(self.x, self.y, self.x, self.y - 15)
        love.graphics.setColor(1, 1, 1)
        love.graphics.polygon("fill", self.x, self.y - 15, self.x, self.y - 5, self.x + 10, self.y - 10)
    else
        love.graphics.setColor(1, 1, 1)
        love.graphics.line(self.x, self.y - 10, self.x, self.y + 10)
        love.graphics.line(self.x - 5, self.y, self.x + 5, self.y)
        love.graphics.line(self.x, self.y + 10, self.x - 5, self.y + 15)
        love.graphics.line(self.x, self.y + 10, self.x + 5, self.y + 15)
        love.graphics.circle("line", self.x, self.y - 15, 5)
    end
end

return Player