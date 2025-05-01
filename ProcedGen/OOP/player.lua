-- player.lua
local Entity = require "entity"
local Player = {}
Player.__index = Player
setmetatable(Player, { __index = Entity })

function Player:new(x, y)
    local instance = Entity.new(self, x, y)
    setmetatable(instance, Player)
    instance.speed = 150
    instance.health = 100
    instance.maxHealth = 100
    return instance
end

function Player:update(dt, map, coins, coinBoost, baseDecay, lavaDecay)
    -- adjust speed by terrain
    local tile = map:getTileAt(self.x, self.y)
    self.speed = (tile == map.TILES.WATER) and 80 or 150

    -- movement
    if love.keyboard.isDown("w", "up") then self.y = self.y - self.speed * dt end
    if love.keyboard.isDown("s", "down") then self.y = self.y + self.speed * dt end
    if love.keyboard.isDown("a", "left") then self.x = self.x - self.speed * dt end
    if love.keyboard.isDown("d", "right") then self.x = self.x + self.speed * dt end

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
        end
    end
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