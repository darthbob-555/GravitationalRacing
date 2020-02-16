local errorHandler = require("scenario/gravitationalRacing/utils/errorHandler")

ClassCollectable = {}
ClassCollectable.__index = ClassCollectable

function ClassCollectable:setVisible(id, visible)
  --[[
  Sets the collectable's visibility
  Parameter:
    id - the id of the collectable
    visible - the visibility of the collectable
  ]]--
  errorHandler.assertNil(id, visible)

  local name = "collectable"..id
  if not scenetree.findObject(name) then
    log("W", "ClassCollectable:setVisible()", "No collectable with id="..id.." exists")
    return
  end

  --If the collectable is already hidden, in can still show-up. Applying it again will not have any affect,
  --so change the state to the opposite and then the correct state to force it to do so
  TorqueScript.eval(name..'.hidden = "'..tostring(visible)..'";')
  TorqueScript.eval(name..'.hidden = "'..tostring(not visible)..'";')
end

function ClassCollectable:new(id, position, visible)
  errorHandler.assertNil(id, position)

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
  --[[
  Returns the minimal distance the collectable can be collected from
  Returns:
    <number> - the minimum distance
  ]]--
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
  Parameter:
    dt - the time since last frame
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

function ClassCollectable:update(dt, vehPos)
  --[[
  Updates the collectable, such as animating and checking the distance of a vehicle for collection
  If the collectable is collected, the function effectively does nothing
  Parameter:
    dt     - the time since last frame
    vehPos - the position of the vehicle to use for determining collection
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
  --[[
  Attributes:
    id       - the id
    position - the position
    visible  - whether the collectable is initially visible
  ]]--
  return ClassCollectable:new(id, position, visible)
end

return {new = new}
