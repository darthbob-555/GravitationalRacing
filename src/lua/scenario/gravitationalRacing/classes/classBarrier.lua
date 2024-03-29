local errorHandler = require("scenario/gravitationalRacing/utils/errorHandler")

ClassBarrier = {}
ClassBarrier.__index = ClassBarrier

function ClassBarrier:new(id, position)
  errorHandler.assertNil(id, position)

  local self = {}
  self.id = id
  --Since position is used twice, prevent mutability screwing things up
  self.position = position:clone()
  self.initialPosition = position

  setmetatable(self, ClassBarrier)
  return self
end

function ClassBarrier:getPosition()
  return self.position
end

function ClassBarrier:reset()
  --[[
  Resets the barrier back to the original "closed" state
  ]]--
  TorqueScript.eval('barrier'..self.id..'.position="'..self.initialPosition:getX()..' '..self.initialPosition:getY()..' '..self.initialPosition:getZ()..'";')
  self.position = self.initialPosition:clone()
end

function ClassBarrier:animateClosing(dt)
  --[[
  Animates the opening by moving the barrier downwards
  Parameters:
    dt - the time since last frame
  Returns
    <boolean> - whether the animation is finished
  ]]--
  self.position:setZ(self.position:getZ() + 10*dt)
  TorqueScript.eval('barrier'..self.id..'.position="'..self.position:getX()..' '..self.position:getY()..' '..self.position:getZ()..'";')

  if self.position:getZ() >= self.initialPosition:getZ() then
    --Make sure it is at the same height it was before
    TorqueScript.eval('barrier'..self.id..'.position="'..self.position:getX()..' '..self.position:getY()..' '..self.initialPosition:getZ()..'";')
    be:reloadStaticCollision();
    return true
  end

  return false
end

function ClassBarrier:animateOpening(dt)
  --[[
  Animates the opening by moving the barrier downwards
  Parameters:
    dt - the time since last frame
  Returns
    <boolean> - whether the animation is finished
  ]]--
  self.position:setZ(self.position:getZ() - 10*dt)
  TorqueScript.eval('barrier'..self.id..'.position="'..self.position:getX()..' '..self.position:getY()..' '..self.position:getZ()..'";')

  if self.position:getZ() <= self.initialPosition:getZ()-10 then
    be:reloadStaticCollision();
    return true
  end

  return false
end

---------------------------------------------------------------------------------------------------------------------------------------------------------

local function new(id, position)
  --[[
  Attributes:
    id       - the id (number) of this barrier
    position - the position of this barrier
  ]]--
  return ClassBarrier:new(id, position)
end

return {new = new}
