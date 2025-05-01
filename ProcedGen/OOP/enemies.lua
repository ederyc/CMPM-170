-- enemies.lua
local Enemy = {}
Enemy.__index = Enemy

function Enemy:new(x, y)
    return setmetatable({
        x = x,
        y = y,
        health = 20,
        isEnemy = true
    }, Enemy)
end

function Enemy:draw()
    love.graphics.setColor(1, 0, 0)
    love.graphics.circle("fill", self.x, self.y, 10)
end

return Enemy
