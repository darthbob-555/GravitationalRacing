local helper             = require("scenario/scenariohelper")
local factors            = require("scenario/gravitationalRacing/dataValues/factors")
local ClassVector        = require("scenario/gravitationalRacing/classes/classVector")
local checkpointsHandler = require("scenario/gravitationalRacing/scenario/track/checkpointsHandler")

ClassVehicle = {}
ClassVehicle.__index = ClassVehicle

function ClassVehicle:new(name, position)
  if not name or not position then
    error("One or more parameters are nil")
  end

  local self = {}
  setmetatable(self, ClassVehicle)

  self.name = name
  self.mass = 1
  self.position = ClassVector.new(position.x, position.y, position.z)
  self.initialPosition = self.position:clone()
  self.acceleration = ClassVector.new(0, 0, 0)
  self.forcedAccel = {}
  self.maxAccel = 300
  self.isBoosting = false

  self.obj = scenetree.findObject(name)

  self.pendReset = false
  self.resetTimer = 0
  self.freeroamReset = false

  self.immune = false
  self.immuneTime = 0

  return self
end

function ClassVehicle:instanceOf()
  return "ClassVehicle"
end

function ClassVehicle:getName()
  return self.name
end

function ClassVehicle:getObj()
  return self.obj
end

function ClassVehicle:getPosition()
  return self.position
end

function ClassVehicle:getMass()
  return self.mass
end

function ClassVehicle:isResetting()
  return self.pendReset
end

function ClassVehicle:isImmune()
  return self.immune
end

function ClassVehicle:setInitialPosition(initPos)
  self.initialPosition = initPos
end

function ClassVehicle:setFreeroamReset(freeroam)
  self.freeroamReset = freeroam
end

function ClassVehicle:setMaxAccel(accel)
  self.maxAccel = accel
end

function ClassVehicle:ignite()
  --[[
  Ignites the vehicle in flames
  ]]--
  self.obj:queueLuaCommand("fire.explodeVehicle()")
end

function ClassVehicle:scheduleReset()
  --[[
  Schedules the reset of the vehicle
  ]]--
  if not self.pendReset then
    if checkpointsHandler.isInScenario() then
      helper.flashUiMessage("Resetting...", 2)
      self.pendReset = true
      self.resetTimer = 2
    elseif self.freeroamReset then
      self.pendReset = true
      self.resetTimer = 1
    end
  end
end

function ClassVehicle:applyAccel(dt)
  --[[
  Applies wind to the vehicle
  ]]--
  --Only validate for calculated values, not specified ones
  if not self.isBoosting then
    -- Clamps a number to within a certain range
    local clamp = function(low, value, high)
      return math.min(math.max(value, low), high)
    end

    for i, accelData in ipairs(self.forcedAccel) do
      --Once the timer has run out, remove from the list
      if accelData.t <= 0 then
        self.forcedAccel[i] = nil
      else
        self.acceleration = self.acceleration:add(accelData.a)
        accelData.t = accelData.t - dt
      end
    end

    --A really high/low value will eviscerate the vehicle, and probably cause instability, so limit the wind speed
    self.acceleration:setX(clamp(-self.maxAccel, self.acceleration:getX(), self.maxAccel))
    self.acceleration:setY(clamp(-self.maxAccel, self.acceleration:getY(), self.maxAccel))
    self.acceleration:setZ(clamp(-self.maxAccel, self.acceleration:getZ(), self.maxAccel))
  end

  self.obj:queueLuaCommand("obj:setWind("..self.acceleration:getX()..", "..self.acceleration:getY()..", "..self.acceleration:getZ()..")")

  if not self.isBoosting then
    --Reset acceleration
    self.acceleration:zero()
  end
end

function ClassVehicle:addAcceleration(accel, time)
  --[[
  Adds an amount of acceleration for a period of time to the vehicle
  ]]--
  table.insert(self.forcedAccel, {a = accel, t = time})
end

function ClassVehicle:addWind(force)
  --[[
  Adds another amount of wind to the vehicles acceleration
  ]]--
  if not force then
    log("E", "Solar System: addWind()", "Cannot apply a nil force, ignoring...")
    return
  end

  --While boosting, no celestial affects the vehicle. This is because the acceleration
  --via a trigger ticks slower than the update time, which causes the boost to be
  --null and voided
  if not self.isBoosting then
    local a = force:multiply(50000)
    a = a:divide(factors.getDistanceScaleFactor())

    self.acceleration = self.acceleration:add(a)
  end
end

function ClassVehicle:update(dt)
  --[[
  Updates the vehicle by applying wind
  ]]--
  local vehObj = self.obj
  --Wait for the vehicle to spawn
  if not vehObj then
    return
  end

  self:applyAccel(dt)

  local objPos = vehObj:getPosition()
  self.position:setX(objPos.x)
  self.position:setY(objPos.y)
  self.position:setZ(objPos.z)

  if self.pendReset then
    if self.resetTimer <= 0 then
      --This prevents resetting happening twice as the celestial still thinks
      --the vehicle is touching it
      if self.resetTimer == -1 then
        self.pendReset = false
      else
        self.resetTimer = -1
        self.heat = 0
        self.fireDamage = "none"
        self.immune = true
        self.immuneTime = 2

        if self.freeroamReset then
          TorqueScript.eval(self.name..'.position = "'..self.initialPosition:getX()..' '..self.initialPosition:getY()..' '..self.initialPosition:getZ()..'";')

          --Fix vehicle and reset its physics
          vehObj:requestReset(RESET_PHYSICS)
          vehObj:resetBrokenFlexMesh()
        else
          checkpointsHandler.resetToCheckpoint(self)
        end
      end
    else
      self.resetTimer = self.resetTimer - dt
    end
  elseif self.immune then
    self.immuneTime = self.immuneTime - dt
    if self.immuneTime <= 0 then
      self.immune = false
    end
  end
end

function ClassVehicle:placeVehicle(pos)
  TorqueScript.eval(self.name..'.position = "'..pos:getX()..' '..pos:getY()..' '..pos:getZ()..'";')
end

function ClassVehicle:resetPosition()
  self.position = self.initialPosition:clone()
end

function ClassVehicle:toString()
  --[[
  Returns a string representation of this instance
  ]]--
  return "ClassVehicle[Name: "..self.name..", Mass: "..self.mass..", Position: "..self.position:toString().."]"
end

-----------------------------------------------------------------------------------------------------------------------------------------------

local function new(name, position)
  return ClassVehicle:new(name, position)
end

return {new = new}
