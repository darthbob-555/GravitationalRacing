local fileHandler = require("scenario/gravitationalRacing/utils/fileHandler")

ClassCollectable = {}
ClassCollectable.__index = ClassCollectable

function ClassCollectable:setVisible(id, visible)
  --[[
  Sets the collectable's visibilty
  ]]--
  --If the collectable is already hidden, in can still showup. Applying it again will not have any affect,
  --so change the state to the opposite and then the correct state to force it to do so
  TorqueScript.eval('collectable'..id..'.hidden = "'..tostring(visible)..'";')
  TorqueScript.eval('collectable'..id..'.hidden = "'..tostring(not visible)..'";')
  -- scenetree.findObject("collectable"..id).hidden = not visible
end

function ClassCollectable:new(id, position, visible)
  local self = {}
  self.collected = false
  self.canBeCollected = visible
  self.visible = visible or false

  if visible ~= nil then
    ClassCollectable:setVisible(id, visible)
  end

  self.angle = 0
  self.id = id
  self.position = position

  setmetatable(self, ClassCollectable)
  return self
end

function ClassCollectable:setCollectable(canBeCollected)
  --Only allow canBeCollected to be true if the collectable is visible
  if (self.visible and canBeCollected) or not canBeCollected then
    self.canBeCollected = canBeCollected
  end
end

function ClassCollectable:instanceOf()
  return "ClassCollectable"
end

function ClassCollectable:getCollectRadius()
  return 10
end

function ClassCollectable:isCollected()
  return self.collected
end

function ClassCollectable:getPosition()
  return self.position
end

function ClassCollectable:animate(dt)
  --[[
  Animates the collectable by rotating and bobbing it
  ]]--
  TorqueScript.eval('collectable'..self.id..'.rotation = "0 0 -1 '..self.angle..'";')

  self.angle = self.angle + dt*bullettime.get()*60
end

function ClassCollectable:collect()
  --[[
  Collects the collectable by removing it
  ]]--
  Engine.Audio.playOnce("AudioGui", "event:UI_Checkpoint", {volume = 1, pitch = 1, fadeInTime = 0})

  self:setVisible(self.id, false)
  self.collected = true
end

function ClassCollectable:reset()
  --[[
  Resets the collectable to its original positions
  ]]--
  if self.visible then
    self:setVisible(self.id, true)
    self.collected = false
  end
end

function ClassCollectable:update(dt, vehPos, currentCheckpoint, currentLap)
  --[[
  Updates the collectable, suchg as animating
  If the collectable is collected, the function effectively does nothing
  ]]--
  if self.visible and not self:isCollected() then
    local distance = vehPos:getDistanceBetween(self:getPosition())

    --Determine whether the vehicle is close enough to collect it
    if distance <= self:getCollectRadius() and self.canBeCollected then
      self:collect()
    else
      self:animate(dt)
    end
  end
end

function ClassCollectable:toString()
  return "ClassCollectable[ID: "..self.id..", position: "..self.position:toString().."]"
end

---------------------------------------------------------------------------------------------------------------------------------------------

local function new(id, position, visible)
  return ClassCollectable:new(id, position, visible)
end

return {new = new}
