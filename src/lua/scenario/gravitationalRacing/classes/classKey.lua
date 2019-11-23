local ClassBarrier = require("scenario/gravitationalRacing/classes/classBarrier")
local ClassVector = require("scenario/gravitationalRacing/classes/classVector")

ClassKey = {}
ClassKey.__index = ClassKey

function ClassKey:new(id, barriers, position, useOnNextLap)
  local self = {}
  self.id = id
  self.position = position
  self.collectedData = {canBeCollected = true, collected = false, checkpoint = 0, lap = 0}
  self.handlingBarriers = false

  self.barriersOpen = false
  self.barrierTimer = false
  --Setup the barriers that this key controls
  self.barriers = {}
  --By default, this key controls the barrier with the same id as it
  if barriers == id then
    if not scenetree.findObject("barrier"..id) then
      error("The associated barrier cannot be found for key with id="..(id or "nil"))
    end

    local pos = scenetree.findObject("barrier"..id):getPosition()
    self.barriers[1] = ClassBarrier.new(id, ClassVector.new(pos.x, pos.y, pos.z))
  else
    for i = 1, #barriers do
      local subID = barriers:sub(i, i)
      local fullID = id..subID
      local pos = scenetree.findObject("barrier"..fullID):getPosition()
      self.barriers[i] = ClassBarrier.new(fullID, ClassVector.new(pos.x, pos.y, pos.z))
    end
  end

  self.useOnNextLap = useOnNextLap

  self.angle = 0

  setmetatable(self, ClassKey)
  return self
end

function ClassKey:getID()
  return self.id
end

function ClassKey:getUsageLap()
  return self.useOnNextLap
end

function ClassKey:setCollectable(canBeCollected)
  self.collectedData.canBeCollected = canBeCollected
end

function ClassKey:instanceOf()
  return "ClassKey"
end

function ClassKey:getBarriers()
  return self.barriers
end

function ClassKey:getPosition()
  return self.position
end

function ClassKey:isCollected()
  return self.collectedData.collected
end

function ClassKey:getCollectedOnData()
  return {lap = self.collectedData.lap, checkpoint = self.collectedData.checkpoint}
end

function ClassKey:getCollectRadius()
  return 5
end

function ClassKey:getUnlockRadius()
  return 75
end

function ClassKey:isHandlingBarriers()
  return self.handlingBarriers
end

function ClassKey:closeOpenBarriers()
  if self.handlingBarriers then
    self.isClosingBarriers = true
  end
end

function ClassKey:getDistanceFromBarrier(objPos)
  --[[
  Returns the distance from an object to the (first if more than one) barrier
  ]]--
  return objPos:subtract(self.barriers[1]:getPosition()):getMagnitude()
end

function ClassKey:collect(checkpoint, lap)
  --[[
  Removes the key and pends moving the controlled barriers
  ]]--
  Engine.Audio.playOnce("AudioGui", "event:UI_Checkpoint", {volume = 1, pitch = 1, fadeInTime = 0})

  TorqueScript.eval('key'..self.id..'.hidden = "true";')

  self.collectedData = {collected = true, canBeCollected = false, checkpoint = checkpoint, lap = lap}

  if self.useOnNextLap then
    self.useOnNextLap = lap + 1
  end
end

function ClassKey:resetBarriers()
  --[[
  Resets all barriers controlled by this key
  ]]--
  for _, instance in ipairs(self.barriers) do
    instance:reset()
  end

  self.handlingBarriers = false

  self.collectedData.collected = false
  self.collectedData.checkpoint = 0
end

function ClassKey:reset(resetBarriers)
  --[[
  Resets the key (and optionally all barriers controlled by this key) to their original positions
  ]]--
  TorqueScript.eval('key'..self.id..'.hidden = "false";')

  self.collectedData.collected = false
  self.collectedData.canBeCollected = true
  self.collectedData.checkpoint = 0
  self.collectedData.lap = 0

  if resetBarriers then
    self:resetBarriers()
    self.handlingBarriers = false
  end
end

function ClassKey:updateTimer(dt)
  --[[
  Udpates the barriers opening and closing
  ]]--
  if self.barrierTimer then
    for _, instance in ipairs(self.barriers) do
      if instance:animateOpening(dt) then
        self.barrierTimer = false
        self.barriersOpen = true
      end
    end
  elseif self.isClosingBarriers and self.barriersOpen then
    for _, instance in ipairs(self.barriers) do
      if instance:animateClosing(dt) then
        self.isClosingBarriers = false
        self.barriersOpen = false
        --Reset the key
        self:reset(true)
      end
    end
  end
end

function ClassKey:animate(dt)
  --[[
  Animates the key by rotating and bobbing it
  ]]--
  TorqueScript.eval('key'..self.id..'.rotation = "0 0 -1 '..self.angle..'";')
  -- TorqueScript.eval('key'..self.id..'.position = "'..self.position:getX()..' '..self.position:getY()..' '..(self.position:getZ()+self.elevation)..'";')

  self.angle = self.angle + dt*bullettime.get()*120
  -- --+1 to offset cos so that self.elevation is never less than 0 (for placement aid)
  -- self.elevation = 0.25*math.cos(math.rad(self.angle)) + 1
end

function ClassKey:update(dt, vehPos, checkpoint, lap)
  --[[
  Updates the key, suchg as animating
  If the key is collected, the function effectively does nothing
  ]]--
  if not self.collectedData.collected then
    local distance = vehPos:subtract(self.position):getMagnitude()

    --Determine whether the vehicle is close enough to collect it
    if distance <= self:getCollectRadius() and self.collectedData.canBeCollected then
      self:collect(checkpoint, lap)
    else
      self:animate(dt)
    end
  else
    --Some keys will not open until the next lap
    if not self.useOnNextLap or self.collectedData.lap + 1 == self.useOnNextLap then
      local distance = self:getDistanceFromBarrier(vehPos)

      --If the player is close to the barrier to see it open
      if not self.handlingBarriers and distance <= self:getUnlockRadius() then
        self.handlingBarriers = true
        self.barrierTimer = true
      elseif self.handlingBarriers then
        --Decrease the key timer for closing barriers
        --This also animates the barrier for the first few seconds
        self:updateTimer(dt)
      end
    end
  end
end

function ClassKey:toString()
  return "ClassKey[ID: "..self.id..", position: "..self.position:toString().."]"
end

---------------------------------------------------------------------------------------------------------------------------------------------

local function new(id, barriers, position, useOnNextLap)
  return ClassKey:new(id, barriers, position, useOnNextLap)
end

return {new = new}
