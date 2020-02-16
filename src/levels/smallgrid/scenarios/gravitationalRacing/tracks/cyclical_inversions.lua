local M = {}

local gravity = true

local function onBeamNGTrigger(data)
  --Player needs a little help around the loops :)
  if data.triggerName:find("toggleGravity") and data.event == "enter" then
    gravity = not gravity
    be:queueAllObjectLua("obj:setGravity("..(gravity and -9.81 or 0)..")")
  end
end

local function onScenarioChange(sc)
  if sc.state == "pre-running" then
    be:queueAllObjectLua("obj:setGravity(-9.81)")
  end
end

M.onScenarioChange = onScenarioChange
M.onBeamNGTrigger = onBeamNGTrigger
return M
