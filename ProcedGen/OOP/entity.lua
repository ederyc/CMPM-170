-- entity.lua
local Entity = {}
Entity.__index = Entity

function Entity:new(x, y)
    local instance = setmetatable({}, self)
    instance.x = x or 0
    instance.y = y or 0
    return instance
end

function Entity:update(dt) end
function Entity:draw() end

return Entity