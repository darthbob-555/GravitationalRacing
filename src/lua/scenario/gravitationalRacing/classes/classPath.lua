ClassPath = {}
ClassPath.__index = ClassPath

local ClassVector = require("scenario/gravitationalRacing/classes/classVector")
local factors = require("scenario/gravitationalRacing/dataValues/factors")

local function getMaxTrails()
  return 100
end

local function getTrailSize(orbitRadius)
  --[[
  Returns the scale of each trail, based on the orbit radius
  ]]--
  return math.min(5, 5*orbitRadius/100)
end

---------------------------------------------------------------------------------------------------------------------------------------------

function ClassPath:new(attributes)
  if not attributes then
    error("One or more parameters is nil")
  end

  local self = {trail = {}, MAX_TRAILS = getMaxTrails}
  for k, v in pairs(attributes) do
    self[k] = v
  end

  setmetatable(self, ClassPath)
  return self
end

function ClassPath:createTrail()
  --[[
  Creates the trail objects in world
  ]]--
  local col = self.trailColour

  for i = 1, #self.trail do
    local trailName = self.name.."_trail_"..i
    local trailPos  = self.trail[i]

    if not scenetree.findObject(trailName) then
      TorqueScript.eval([[
      new TSStatic(]]..(trailName)..[[) {
        shapeName = "levels/smallgrid/art/gravitationalRacing/trail.dae";
        scale = "]]..self.trailSize..[[ ]]..self.trailSize..[[ ]]..self.trailSize..[[";
        dynamic = "1";
        instanceColor = "]]..col.r..[[ ]]..col.g..[[ ]]..col.b..[[ 1";
        position = "]]..trailPos:getX()..[[ ]]..trailPos:getY()..[[ ]]..trailPos:getZ()..[[";
      };
      ]])
    end
  end
end

function ClassPath:updateTrail(show)
  --[[
  Displays/hides the trail at this object's position
  ]]--
  --Loop through list of trail points
  for i = 1, #self.trail do
    local trailName = self.name.."_trail_"..i
    local trailPos  = self.trail[i]
    TorqueScript.eval(trailName..'.position = "'..trailPos:getX()..' '..trailPos:getY()..' '..trailPos:getZ()..'";')
    TorqueScript.eval(trailName..'.hidden = "'..tostring(not show)..'";')
  end
end

function ClassPath:deleteTrail()
  --[[
  Deletes the trail
  ]]--
  for i = 1, #self.trail do
    local name = self.name.."_trail_"..i
    if scenetree.findObject(name) then
      TorqueScript.eval(name..".delete();")
    end
  end
end

----------------------------------------------------------------------------------------------------------------------------------------------

ClassCircularPath = {}
ClassCircularPath.__index = ClassCircularPath

function ClassCircularPath:calculateFrequency(celestialVel, radius)
  --[[
  Calculates and returns the speed of the orbital path
  ]]--
  return celestialVel / (2*math.pi*radius)
end

function ClassCircularPath:createTrailPoints(radius, offset)
  --[[
  Creates each trail point
  ]]--
  local circumference = 2 * math.pi * radius
  --The number of trails should not exceed the trail limit, and are spaced every 10m
  local numTrails = math.min(math.floor(circumference / 10), getMaxTrails())
  local angleIncrement = 2*math.pi/numTrails

  local trail = {}

  for theta = 0, 2*math.pi, angleIncrement do
    table.insert(trail, ClassVector.new(
    offset:getX() + radius*math.cos(theta),
    offset:getY() + radius*math.sin(theta),
    offset:getZ()
  ))
end

return trail
end

function ClassCircularPath:new(trailName, angle, celestial, center, radius, invertDirection, frequency)
  if not trailName or not angle or not center or not radius then
    error("One or more parameters is nil!")
  end

  local frequency = frequency or ClassCircularPath:calculateFrequency(celestial:getVelocity():getMagnitude(), radius)

  local self = ClassPath:new({
    name          = trailName,
    trailColour   = celestial:getCelestialColour(),
    trailSize     = getTrailSize(radius),
    type          = "circular",
    radius        = radius,
    frequency     = frequency,
    initFrequency = frequency,
    angle         = angle,
    initAngle     = angle,
    offset        = center,
    direction     = (invertDirection and invertDirection == 1 and -1) or 1
  })

  self.trail = ClassCircularPath:createTrailPoints(self.radius, self.offset)

  setmetatable(self, ClassCircularPath)
  return self
end

--Inheritance
setmetatable(ClassCircularPath, {__index = ClassPath})

function ClassCircularPath:setFrequency(freq)
  self.frequency = freq
end

function ClassCircularPath:setOffset(offset)
  self.offset = offset:clone()
  self.trail = self:createTrailPoints(self.radius, self.offset)
  self:updateTrail(true)
end

function ClassCircularPath:getInitFreq()
  return self.initFrequency
end

function ClassCircularPath:update(dt)
  --[[
  Finds the next position this object will be in, and returns it
  ]]--
  self.angle = self.angle + (dt*self.frequency) * 2*math.pi * self.direction
  return ClassVector.new(
  self.offset:getX() + self.radius*math.cos(self.angle),
  self.offset:getY() + self.radius*math.sin(self.angle),
  self.offset:getZ()
)
end

function ClassCircularPath:reset()
  --[[
  Resets the path to the beginning
  ]]--
  self.angle = self.initAngle
  self:updateTrail(true)
end

-----------------------------------------------------------------------------------------------------------------------------------------------

ClassLinearPath = {}
ClassLinearPath.__index = ClassLinearPath

function ClassLinearPath:getBounds(baseDirection, offset, length)
  if baseDirection == "X" then
    return {
      offset:getX() + length,
      offset:getX() - length
    }
  elseif baseDirection == "Y" then
    return {
      offset:getY() + length,
      offset:getY() - length
    }
  end
end

function ClassLinearPath:createTrailPoints(baseDirection, offset, length)
  --[[
  Creates each trail point
  ]]--
  local bounds = ClassLinearPath:getBounds(baseDirection, offset, length)

  --There should be at least 5 meters between each cube
  local increment = math.max(5, math.abs(bounds[1]-bounds[2]) / getMaxTrails())

  local trail = {}
  --Loop from biggest to smallest
  for i = math.min(bounds[1], bounds[2]), math.max(bounds[1], bounds[2]), increment do
    if     baseDirection == "X" then
      table.insert(trail, ClassVector.new(i, offset:getY(), offset:getZ()))
    elseif baseDirection == "Y" then
      table.insert(trail, ClassVector.new(offset:getX(), i, offset:getZ()))
    end
  end

  return trail
end

function ClassLinearPath:new(trailName, celestial, invertDirection, frequency, length, direction)
  if not celestial or not frequency or not length or not direction then
    error("One or more parameters is nil! [celestial="..tostring(celestial and celestial or 'nil')..", frequency="..tostring(frequency and frequency or 'nil')..", length="..tostring(length and length or 'nil')..", direction="..tostring(direction and direction or 'nil').."]")
  end

  local celestialPos = celestial:getPosition()
  local lengthVec = direction == "X" and ClassVector.new(length, 0, 0) or ClassVector.new(0, length, 0)

  local self = ClassPath:new({
    name          = trailName,
    type          = "linear",
    trail         = ClassLinearPath:createTrailPoints(direction, celestialPos, length),
    trailColour   = celestial:getCelestialColour(),
    trailSize     = getTrailSize(length/2),
    length        = length,
    frequency     = frequency,
    baseDirection = direction:upper(),
    offset        = celestialPos,
    direction     = (invertDirection and invertDirection == 1 and -1) or 1,
    angle = 0
  })

  --Set angle to be in anti-phase to original
  if self.direction == -1 then
    self.angle = math.pi
  end

  setmetatable(self, ClassLinearPath)
  return self
end

--Inheritance
setmetatable(ClassLinearPath, {__index = ClassPath})

function ClassLinearPath:update(dt)
  --[[
  Finds the next position this object will be in, and returns it
  ]]--
  self.angle = self.angle + (dt*self.frequency) * 2*math.pi

  if self.baseDirection == "X" then
    return ClassVector.new(self.offset:getX() + self.length*math.cos(self.angle), self.offset:getY(), self.offset:getZ())
  elseif self.baseDirection == "Y" then
    return ClassVector.new(self.offset:getX(), self.offset:getY() + self.length*math.cos(self.angle), self.offset:getZ())
  end
end

function ClassLinearPath:reset()
  --[[
  Resets the path to the beginning
  ]]--
  self.angle = self.direction == -1 and math.pi or 0
end

function ClassLinearPath:getDirection()
  return self.baseDirection
end

-----------------------------------------------------------------------------------------------------------------------------------------------

ClassInfiniteLinearPath = {}
ClassInfiniteLinearPath.__index = ClassInfiniteLinearPath

function ClassInfiniteLinearPath:new(velocity, initPos)
  local self = {
    initPos = initPos,
    velocity = velocity,
    time = 0
  }

  setmetatable(self, ClassInfiniteLinearPath)
  return self
end

function ClassInfiniteLinearPath:update(dt)
  --[[
  Returns a new position vector
  ]]--
  self.time = self.time + dt
  local dVel = self.velocity:multiply(self.time)
  return self.initPos:add(dVel)
end

-----------------------------------------------------------------------------------------------------------------------------------------------

local function newCircularPath(trailName, angle, celestial, center, radius, invertDirection, frequency)
  return ClassCircularPath:new(trailName, angle, celestial, center, radius, invertDirection, frequency)
end

local function newLinearPath(trailName, celestial, invertDirection, frequency, length, direction)
  return ClassLinearPath:new(trailName, celestial, invertDirection, frequency, length, direction)
end

return {newCircularPath = newCircularPath, newLinearPath = newLinearPath}
