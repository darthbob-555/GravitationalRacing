local M = {}

--[[
1) Select piece
2) Place piece
3) Update to current position
]]--

local generate = false
local timer = 0.2

local function onPreRender(dt)
  if generate then
    timer = timer-dt
    --Generate a piece every 0.2s
    if timer <= 0 then
      

      timer = 0.2
    end
  end
end

local function onRaceStart()
  generate = true
end

M.onPreRender = onPreRender
M.onRaceStart = onRaceStart
return M
