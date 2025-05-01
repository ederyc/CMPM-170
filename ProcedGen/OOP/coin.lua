-- coin.lua
local Entity = require "entity"
local Coin = {}
Coin.__index = Coin
setmetatable(Coin, { __index = Entity })

function Coin:new(x, y)
    local instance = Entity.new(self, x, y)
    setmetatable(instance, Coin)
    instance.radius = 5
    return instance
end

function Coin:draw()
    love.graphics.setColor(1, 0.84, 0, 1)
    love.graphics.circle("fill", self.x, self.y, self.radius)
end

return Coin