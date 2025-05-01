-- conf.lua
-- Configuration for Love2D

function love.conf(t)
    t.title = "Team 2 Endless Exploration"
    t.version = "11.4"  -- The LÖVE version this game was made for
    t.window.width = 800
    t.window.height = 600
    t.console = true
    
    -- For Windows debugging
    t.window.resizable = true
    t.window.minwidth = 800
    t.window.minheight = 600
    
    -- Modules
    t.modules.audio = true
    t.modules.event = true
    t.modules.graphics = true
    t.modules.image = true
    t.modules.joystick = true
    t.modules.keyboard = true
    t.modules.math = true
    t.modules.mouse = true
    t.modules.physics = true
    t.modules.sound = true
    t.modules.system = true
    t.modules.timer = true
    t.modules.window = true
    t.modules.thread = true
end
