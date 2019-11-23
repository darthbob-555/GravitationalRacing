local factors        = require("scenario/gravitationalRacing/dataValues/factors")
local ClassPath      = require("scenario/gravitationalRacing/classes/classPath")
local ClassCelestial = require("scenario/gravitationalRacing/classes/classCelestial")

ClassBinarySystem = {}
ClassBinarySystem.__index = ClassBinarySystem

function ClassBinarySystem:getOrbitRadius(quantity, dist, mass, parentMass)
  --[[
  Returns the radius a celestial will orbit the barycenter at
  ]]--
  --r/[1 + (m1/m2)]
  if     quantity == "vector" then
    return dist:divide(1 + mass/parentMass)
  elseif quantity == "scalar" then
    return dist   /   (1 + mass/parentMass)
  end
end

function ClassBinarySystem:getOrbitalVelocity(component)
  --[[
  Returns the orbital velocity for this component
  ]]--
  local c1, c2
  if component == self.components[1] then
    c1 = component
    c2 = self.components[2]
  else
    c1 = self.components[1]
    c2 = component
  end

  local c2Mass = c2:getMass()
  local dist = c1:getPosition():getDistanceBetween(c2:getPosition()) / factors.getDistanceScaleFactor()

  --v = sqrt(G.m2.r1/r²)
  --If m1 = m2 -> v1 = v2 = sqrt(Gm/4r)
  return math.sqrt((ClassCelestial.getGravitationalConstant() * c2Mass * self:getOrbitRadius("scalar", dist, c1:getMass(), c2Mass)) / (dist^2)) * factors.getDistanceScaleFactor() * factors.getTimeScaleFactor()
end

function ClassBinarySystem:calculateBarycenter(components)
  --[[
  Calculates and return the barycenter of this system
  ]]--
  local c1, c2 = unpack(components)
  local c1Pos ,  c2Pos  = c1:getPosition(), c2:getPosition()
  local c1Mass,  c2Mass = c1:getMass()    , c2:getMass()

  --Needs to be absolute since to work out the barycenter, the distance vector must be positive
  local distVec = c1Pos:subtract(c2Pos):abs()
  --This is relative to the components
  local barycenterRelative = self:getOrbitRadius("vector", distVec, c1Mass, c2Mass)

  --Subtract from the one in front (could also add to the one behind)
  local celestialInFront = c1Pos:getY() > c2Pos:getY() and c1Pos or c2Pos
  return celestialInFront:subtract(barycenterRelative)
end

function ClassBinarySystem:calculateFrequency()
  --[[
  Returns the frequency of the system
  ]]--
  --T = sqrt(4pi² r³ / G(m + M))
  local r = self.components[1]:getPosition():getDistanceBetween(self.components[2]:getPosition()) / factors.getDistanceScaleFactor()
  local period = math.sqrt(4*math.pi^2 * r^3 / (ClassCelestial.getGravitationalConstant() * self.systemMass)) / factors.getTimeScaleFactor()
  return 1/period
end

function ClassBinarySystem:new(systemName, components, orbitalFrequency)
  local self = {}

  --A system can be orbited by another star or system so can have its own path
  self.systemPath = nil
  self.systemName = systemName
  self.systemMass = 0
  self.circumbinaries = {}

  self.orbitalFrequency = orbitalFrequency

  self.components = components
  self.barycenter = ClassVector.new(0, 0, 0)

  setmetatable(self, ClassBinarySystem)
  return self
end

function ClassBinarySystem:initialise()
  --[[
  Initialises some attributes that need to be set after the constructor or components occurs
  ]]--
  self.systemMass = self.components[1]:getMass() + self.components[2]:getMass()
  self.barycenter = ClassBinarySystem:calculateBarycenter(self.components)
  --If not specified, calculate it
  self.orbitalFrequency = self.orbitalFrequency or self:calculateFrequency()
end

function ClassBinarySystem:setupComponentPaths()
  --[[
  Calculates and configures the paths for both celestials in the system
  ]]--
  local c1, c2 = unpack(self.components)

  --Don't setup paths for delete celestials
  if not (c1:isRemoved() or c2:isRemoved()) and not (c1:getPath() or c2:getPath()) then
    local data = {}
    for i, instance in ipairs(self.components) do
      data[i] = {
        mass = instance:getMass(),
        name = instance:getName(),
        pos  = instance:getPosition()
      }
    end

    local dist = data[1].pos:getDistanceBetween(data[2].pos)

    local c1OrbitRadius = self:getOrbitRadius("scalar", dist, data[1].mass, data[2].mass)
    local c2OrbitRadius = self:getOrbitRadius("scalar", dist, data[2].mass, data[1].mass)

    local config = {
      frequency       = nil,
      invertDirection = nil
    }

    --Setup up config values
    for i = 1, 2 do
      local obj = scenetree.findObject(self.components[i]:getName())
      for k, v in pairs(config) do
        --If two objects have different values, take the first's
        config[k] = v or obj[k]
      end
    end

    if not config.frequency then
      config.frequency = self.orbitalFrequency
    end

    --Adjust names to be valid for torquescript
    local c1Path = ClassPath.newCircularPath(data[1].name:gsub("[(|)]", {["("] = "_", ["|"] = "_", [")"] = "_"}), 0      , c1, self.barycenter, c1OrbitRadius, config.invertDirection, config.frequency)
    local c2Path = ClassPath.newCircularPath(data[2].name:gsub("[(|)]", {["("] = "_", ["|"] = "_", [")"] = "_"}), math.pi, c2, self.barycenter, c2OrbitRadius, config.invertDirection, config.frequency)
    c1:setPath(c1Path)
    c2:setPath(c2Path)

    --[[Show the second trail if it will be different to the first
    Allow for two different stars orbitting but having mass defects due to rounding/floating point arithmetic]]--
    if math.abs(c1OrbitRadius - c2OrbitRadius) > 1 then
      c2Path:createTrail(true)
    end

    c1Path:createTrail(true)
  end
end

function ClassBinarySystem:getCelestialColour()
  --[[
  Returns the colour of the system
  ]]--
  local c1, c2 = self.components[1]:getCelestialColour(), self.components[2]:getCelestialColour()
  --Return the average of both rgb values
  return {
    r = (c1.r + c2.r)/2,
    g = (c1.g + c2.g)/2,
    b = (c1.b + c2.b)/2
  }
end

function ClassBinarySystem:setPath(path)
  --[[
  Setups the system path
  ]]--
  if not self.systemPath then
    self.systemPath = path
  end
end

function ClassBinarySystem:getSurfaceOfCelestial()
  --[[
  Returns the lowest orbit
  ]]--
  local c1, c2 = unpack(self.components)
  --Find the outermost component
  local outerComponent = c1:getMass() > c2:getMass() and c1 or c2
  --Get the surface of that celestial and add it to the distance it is from the center
  return math.abs(self.barycenter:getX() - outerComponent:getPosition():getX()) + outerComponent:getSurfaceOfCelestial()
end

function ClassBinarySystem:addChild(child)
  --[[
  Adds an orbiting celestial reference to this binary system
  ]]--
  table.insert(self.circumbinaries, child)
end

function ClassBinarySystem:delete()
  --[[
  Deletes the components and this system instance
  ]]--
  self.components[1]:delete()
  self.components[2]:delete()
  self = nil
end

function ClassBinarySystem:getPath()
  return self.systemPath
end

function ClassBinarySystem:getComponents()
  return self.components
end

function ClassBinarySystem:getVelocity()
  return 2 * math.pi * self.barycenter:getDistanceBetween(self.components[1]:getPosition()) * self.orbitalFrequency
end

function ClassBinarySystem:isRemoved()
  return self.components[1]:isRemoved() and self.components[2]:isRemoved()
end

function ClassBinarySystem:getMass()
  return self.systemMass
end

function ClassBinarySystem:getPosition()
  return self.barycenter
end

function ClassBinarySystem:getName()
  return self.systemName
end

function ClassCelestial:callMethod(func, args)
  if args then
    return self[func](self, unpack(args))
  else
    return self[func](self)
  end
end

function ClassBinarySystem:update(dt)
  if self.systemPath then
    local c1, c2 = unpack(self.components)
    local c1Removed, c2Removed = c1:isRemoved(), c2:isRemoved()

    --If both components don't exist, stop updating the system
    if not (c1Removed and c2Removed) then
      self.barycenter = self.systemPath:update(dt)

      for _, component in ipairs(self.components) do
        component:getPath():setOffset(self.barycenter)
      end

      --TODO add in a check to see if this system is moving (ie. part of a larger system)
      for _, child in ipairs(self.circumbinaries) do
        local path = child:getPath()
        if path then
          path:setOffset(self.barycenter)
        end
      end
    elseif c1Removed or c2Removed then
      --One component is removed so the other should be ejected in a tangental trajectory
      local remainingComp = c1Removed and c2 or c1
      remainingComp:setPath(ClassPath.newInfiniteLinearPath(remainingComp:getVelocity(), remainingComp:getPosition()))
    end
  end
end

function ClassBinarySystem:instanceOf()
  return "ClassBinarySystem"
end

-----------------------------------------------------------------------------------------------------------------------------------------------

local function new(systemName, components, orbitalFrequency)
  return ClassBinarySystem:new(systemName, components, orbitalFrequency)
end

local M = {}

M.new = new
return M
