ClassCelestial = {}
ClassCelestial.__index = ClassCelestial

local helper        = require("scenario/scenariohelper")
local factors       = require("scenario/gravitationalRacing/dataValues/factors")
local ClassText     = require("scenario/gravitationalRacing/classes/classText")
local ClassPath     = require("scenario/gravitationalRacing/classes/classPath")
local ClassVector   = require("scenario/gravitationalRacing/classes/classVector")
--local ClassMatrix   = require("scenario/gravitationalRacing/classes/classMatrix")
local tableComp     = require("scenario/gravitationalRacing/utils/tableComprehension")
local field         = require("scenario/gravitationalRacing/celestial/gravitationalScalarField")
local celestialInfo = require("scenario/gravitationalRacing/dataValues/celestialInformation")

local unpack = unpack or table.unpack

--Class methods
local function getGravitationalConstant()
  --[[
  Returns the value of G
  ]]--
  return 6.67408*math.pow(10, -11)
end

local function getDangerRadiiValues()
  return {51, 101, 151}
end

local function setDangerRadiiValues(newValues)
  --[[
  Sets the danger radii values
  Note: this function WILL automatically update celestials, since they use these
  numbers to update their danger radii every update
  ]]--
  getDangerRadiiValues = function()
    return {newValues[1], newValues[2], newValues[3]}
  end
end

local function getAccretionDiscRadius()
  --[[
  Returns the radius of the accretion disc in-game, per scale
  ]]--
  return 0.155757
end

local function getEjectionJetHeight()
  --[[
  Returns the height (only counts top/bottom part ie. half) of the ejectin jets in-game, per scale
  ]]--
  return 0.3
end

local function getRingRadius()
  --[[
  Returns the radius of Saturn's rings
  ]]--
  return 0.07
end

local function getAllCelestials(categorised)
  --[[
  Returns all celestial names
  categorised returns them in categories, else flatterns to a single table
  ]]--
  local celestials = {
    planet = {"mercury", "venus", "earth", "mars", "jupiter", "saturn", "uranus", "neptune"},
    star   = {"sun", "neutronStar", "CDCrucis", "HD49798", "etaUrsaeMajoris", "alphaVolantis", "procyonA", "ABDoradusA", "CHXR73"},
    other  = {"blackhole"}
  }

  if categorised then
    return celestials
  else
    return tableComp.flattenDictToArr(celestials)
  end
end

local function getCelestialTypeFromModel(model)
  --[[
  Returns the type of a celestial
  ]]--
  if not model then
    error("gr:getCelestialTypeFromModel(): Model is nil")
  end

  local celestials = getAllCelestials(true)

  for type, objects in pairs(celestials) do
    for _, object in ipairs(objects) do
      if model == object then
        if type == "other" then
          --Other type celestial will be their own type
          return model
        else
          return type
        end
      end
    end
  end

  log("I", "gr:getCelestialTypeFromModel()", "Model="..model.." is not recognised")
end

function ClassCelestial:calculateMass(radius, actualRadius, actualMass)
  --[[
  Returns the mass of this object
  ]]--
  if not radius or not actualRadius then
    error("One or more parameters is nil")
  end

  --Given m = ρV, it follows that m ∝ r³:
  --thus, the mass is affected by the ratio of (radius / actualRadius)³
  local radiusRatio = math.pow(radius / actualRadius, 3)

  return actualMass * radiusRatio
end

function ClassCelestial:calculateRotationSpeed(period)
  --[[
  Returns the rotation speed of this object
  ]]--
  local freq = 1/period
  return 2*math.pi*freq
end

function ClassCelestial:new(name, type, scale, objectType, orbitingBody, passive, delayed, axisTilt)
  --Some parameters are optional as not required/applicable in some cases
  if not name or not type or not scale or not objectType then
    error("One or more parameters is nil! [name="..tostring(name or "nil")..", type="..tostring(type or "nil")..", scale="..tostring(scale or "nil")..", objectType="..tostring(objectType or "nil").."]")
  end

  local self = {}
  self.name = name

  self.model = scenetree.findObject(name).shapeName
  for _, pattern in ipairs({"levels/smallgrid/art/gravitationalRacing/celestialbodies/", ".dae", "_eventHorizon", "/"}) do
    self.model = self.model:gsub(pattern, "")
  end

  --Whether this object is fixed in position (static), manipulable (dynamic) or fixed along a path (fixedDynamic)
  self.objectType = objectType
  --The celestial type
  self.type = type
  --delayed is whether the object is currently delayed
  self.delayed = delayed
  --isDelayed is a property that stores whether it is a delayed object,
  self.isDelayed = delayed

  self.orbitingBody = orbitingBody
  self.isPassive = passive

  --Stores references to other celestials orbiting this one
  self.children = {}

  self.acceleration = ClassVector.new(0, 0, 0)
  self.position     = ClassVector.new(0, 0, 0)
  self.velocity     = ClassVector.new(0, 0, 0)

  --Since the framerate will change, this is used to scale the velocity appropriately
  self.frameTime = 1

  --Only used with objectType = "dynamic"
  self.trail = {}
  self.trailLimit = 100
  self.path = nil

  self.label = nil
  self.isHighlighted = false

  self.shouldBeDestroyed = false
  --Only used when the object should be deleted no matter what
  self.forceDelete = false
  self.isDestroyed = false

  self.radius = scale * factors.getRadiusScaleFactor()
  self.info = celestialInfo.getData(self.model)
  self.mass = ClassCelestial:calculateMass(self.radius, self.info.radius, self.info.mass)

  --When a supernova explodes near this object, it will become heated
  self.burning = false

  ---Axis tilt can be specified for axis tilt instead of real-life value
  self.axisTilt = nil
  if axisTilt and axisTilt ~= "nil" then
    self.axisTilt = axisTilt
  else
    self.axisTilt = self.info.axisTilt
  end


  self.rotAngle = 0
  self.angularVelocity = ClassCelestial:calculateRotationSpeed(self.info.rotationPeriod)

  self.setup = false

  self.initScale       = scale
  self.initMass        = self.mass
  self.initRadius      = self.radius
  self.initModel       = self.model
  self.initialPosition = ClassVector.new(0, 0, 0)

  setmetatable(self, ClassCelestial)
  return self
end

function ClassCelestial:getCelestialColour()
  --[[
  Returns the colour of the trail, based on the celestial model
  ]]--
  if     self.model == "sun"             then return {r = 1.000, g = 0.800, b = 0.122}
  elseif self.model == "neutronStar"     then return {r = 0.843, g = 0.843, b = 0.843}
  elseif self.model:find("blackhole")    then return {r = 0.125, g = 0.125, b = 0.125}
  elseif self.model == "mercury"         then return {r = 0.549, g = 0.549, b = 0.549}
  elseif self.model == "venus"           then return {r = 0.796, g = 0.443, b = 0.137}
  elseif self.model == "earth"           then return {r = 0.376, g = 0.467, b = 0.192}
  elseif self.model == "mars"            then return {r = 0.878, g = 0.380, b = 0.212}
  elseif self.model == "jupiter"         then return {r = 0.761, g = 0.608, b = 0.455}
  elseif self.model == "saturn"          then return {r = 0.863, g = 0.753, b = 0.600}
  elseif self.model == "uranus"          then return {r = 0.643, g = 0.835, b = 0.902}
  elseif self.model == "neptune"         then return {r = 0.227, g = 0.396, b = 0.769}
  elseif self.model == "CDCrucis"        then return {r = 0.404, g = 0.671, b = 0.996}
  elseif self.model == "HD49798"         then return {r = 0.404, g = 0.671, b = 0.804}
  elseif self.model == "etaUrsaeMajoris" then return {r = 0.435, g = 0.522, b = 0.667}
  elseif self.model == "alphaVolantis"   then return {r = 0.635, g = 0.635, b = 0.635}
  elseif self.model == "procyonA"        then return {r = 0.824, g = 0.765, b = 0.431}
  elseif self.model == "ABDoradusA"      then return {r = 0.980, g = 0.910, b = 0.275}
  elseif self.model == "CHXR73"          then return {r = 0.918, g = 0.000, b = 0.000}
  end
end

function ClassCelestial:addChild(child)
  table.insert(self.children, child)
end

function ClassCelestial:setBurning(burning)
  --[[
  Sets the object to be heated
  ]]--
  if self.burning == burning then
    return
  end

  if burning then
    local scale = 0.06125 * self:getScale();

    TorqueScript.eval([[
    new TSStatic(]]..self.name..[[_heatMask) {
      shapeName = "levels/smallgrid/art/gravitationalRacing/celestialbodies/nova/sphere.dae";
      dynamic = "1";
      scale = "]]..scale..[[ ]]..scale..[[ ]]..scale..[[";
      position = "]]..self.position:getX()..[[ ]]..self.position:getY()..[[ ]]..self.position:getZ()..[[";
      instanceColor = "1 0.3 0 0.375";
    };
    ]])

    TorqueScript.eval([[
    new PointLight(]]..self.name..[[_heatLight) {
      radius = "]]..(self:getScaledRadius() * 6)..[[";
      isEnabled = "1";
      color = "1 0.3 0 0.8";
      brightness = "2.5";
      castShadows = "0";
      position = "]]..self.position:getX()..[[ ]]..self.position:getY()..[[ ]]..self.position:getZ()..[[";
    };
    ]])
  else
    if scenetree.findObject(self.name.."_fire")      then TorqueScript.eval(self.name.."_fire.delete();")      end
    if scenetree.findObject(self.name.."_heatMask")  then TorqueScript.eval(self.name.."_heatMask.delete();")  end
    if scenetree.findObject(self.name.."_heatLight") then TorqueScript.eval(self.name.."_heatLight.delete();") end
  end

  self.burning = burning
end

function ClassCelestial:getActual(attribute)
  return self.info[attribute] or log("E", "celestialInformaton.getData()", "Cannot get an unknown attribute of this celestial! [attribute="..tostring(attribute).."]")
end

function ClassCelestial:createLabel()
  --[[
  Creates a 3d label above the celestial
  ]]--
  --Do not recreate an existing label
  if not self.label then
    local pos = self.position
    self.label = ClassText.new(scenetree.findObject(self.name).model:gsub("levels/smallgrid/art/gravitationalRacing/celestialbodies/", ""):gsub(".dae", ""), ClassVector.new(pos:getX(), pos:getY() + self:getScaledRadius() + 5, pos:getZ()))
  end
end

function ClassCelestial:isMarkedForDestruction()
  return self.shouldBeDestroyed
end

function ClassCelestial:isCircumbinary()
  --[[
  Returns whether this celestial is orbiting two bodies or not
  ]]--
  return self.orbitingBody and self.orbitingBody:find("|")
end

function ClassCelestial:markForDestruction(force)
  if force then
    --Forces the object to be delete (bypasses "static" rule in update())
    self.forceDelete = true
  else
    self.shouldBeDestroyed = true
  end
end

function ClassCelestial:isBurning()
  return self.burning
end

function ClassCelestial:isADelayedObject()
  return self.isDelayed
end

function ClassCelestial:isCurrentlyDelayed()
  return self.delayed
end

function ClassCelestial:setDelayed(delayed)
  self.delayed = delayed
end

function ClassCelestial:hasChildren()
  return #self.children > 0
end

function ClassCelestial:reset()
  --[[
  Resets the celestial back to its starting state
  TODO - consider resetting the pos, mass, scale, radius + display here instead of in celestialsHandler?
  ]]--
  self:destroyTrail()
  self:resetPath()
  self.acceleration:zero()
  self.velocity:zero()
  self.frameTime = 1
  self.isDestroyed = false
  self.delayed = self.isDelayed
  self.mass = self.initMass

  --Reset back to test
  if self.model ~= self.initModel then
    self:changeModel(self.initModel)
  end
end

function ClassCelestial:isRemoved()
  return self.isDestroyed
end

function ClassCelestial:getModel()
  return self.model
end

function ClassCelestial:destroyTrail()
  --[[
  Destroys the object's trail
  ]]--
  if self.objectType == "dynamic" then
    for i = 1, #self.trail do
      if scenetree.findObject(self.name..'_trail_'..i) then
        TorqueScript.eval(self.name..'_trail_'..i..'.delete();')
      end
    end

    self.trail = {}
  elseif self.objectType == "fixedDynamic" and self.path then
    --Handle for binaries!
    self.path:deleteTrail()
  end
end

function ClassCelestial:delete()
  --[[
  Destroys this instance and deletes its assets
  ]]--
  self.forceDelete = true
  self:removeFromScene()
  self = nil
end

function ClassCelestial:removeFromScene()
  --[[
  Removes the celestial from view and prevents it doing anything
  Note: The object is not deleted from the scenario (unless told to explicity),
  only positioned away from view, and reduced to 0 scale so it cannot be seen or h
  ave any effect
  This is because it is computationally expensive to delete and create a
  numerous number of objects, especially since scenario resets are likely
  This is NOT the same as delete() as deleting destroys the entire instance
  ]]--
  if self.forceDelete then
    TorqueScript.eval(self.name..'.delete();')
  else
    TorqueScript.eval(self.name..'.position = "10000 -10000 10000";')
    TorqueScript.eval(self.name..'.scale = "0 0 0";')
  end

  if self.type == "blackhole" then
    if self.forceDelete then
      TorqueScript.eval(self.name..'_disc.delete();')
    else
      TorqueScript.eval(self.name..'_disc.position = "100000 -100000 100000";')
      TorqueScript.eval(self.name..'_disc.scale = "0 0 0";')
    end
  elseif self.type == "star" then
    --Delete star's light
    TorqueScript.eval(self.name.."_light.delete();")
  end

  if not self.isPassive then
    for i = 1, 3 do
      local objectDangerRadiusName = self.name.."_Danger_radius"..i
      if scenetree.findObject(objectDangerRadiusName) then
        TorqueScript.eval(objectDangerRadiusName..".delete();")
      end
    end
  end

  if self.isHighlighted then
    local highlightName = self.name.."_highlight"
    if scenetree.findObject(highlightName) then
      TorqueScript.eval(highlightName..'.delete();')
    end
  end

  self:setBurning(false)
  self:destroyTrail()

  if self.label then
    self.label:move(ClassVector.new(10000, -10000, 10000))
  end

  self.isDestroyed = true

  print(self.name.." has been destroyed!")
end

--Functions only applicable to celestials of objectType="fixedDynamic" - TODO Make a class for them that inherits off of ClassCelestial
function ClassCelestial:setupPath(parent)
  --[[
  Setups the path (if it is fixed)
  ]]--
  --Only setup path if it has not been already
  if not self.path and not self.isDestroyed then
    local obj = scenetree.findObject(self.name)
    local path = obj.path

    if path then
      --Note: not all of these need to be specified for certain path types
      local direction       =          obj.direction
      local invertDirection = tonumber(obj.invertDirection)
      local frequency       = tonumber(obj.frequency      )
      local length          = tonumber(obj.length         )

      if     path == "linear" then
        self.path = ClassPath.newLinearPath(self.name, self, invertDirection, frequency, length, direction)
      elseif path == "circular" then
        local radius = self.position:subtract(parent:getPosition())
        local offset = self.position:subtract(radius)
        --Some scenarios have celestials above and below the parent. so use this celestial's z value
        offset:setZ(self.position:getZ())
        self.path = ClassPath.newCircularPath(self.name, 0, self, offset, radius:getMagnitude(), invertDirection, frequency)
      end

      self.path:createTrail()
    end
  end
end

function ClassCelestial:setPath(path)
  self.path = path
end

function ClassCelestial:resetPath()
  --[[
  Resets the path
  ]]--
  if self.objectType == "dynamic" then
    for i = 1, #self.trail do
      if scenetree.findObject(self.name..'_trail_'..i) then
        TorqueScript.eval(self.name..'_trail_'..i..'.hidden = "false";')
      end
    end
  end

  if self.path then
    self.path:reset()
  end
end

function ClassCelestial:getPath()
  return self.path
end
--

function ClassCelestial:setPassive(passive)
  self.isPassive = passive
end

function ClassCelestial:getPassivity()
  return self.isPassive
end

function ClassCelestial:setPosition(newPosition)
  --[[
  Sets the position of this object
  ]]--
  self.position = newPosition:clone()

  --Adjust label to new position
  if self.label then
    self.label:move(ClassVector.new(newPosition:getX(), newPosition:getY() + self:getScaledRadius() + 5, newPosition:getZ()))
  end
end

function ClassCelestial:getSurfaceOfCelestial()
  --[[
  Returns the lowest possible value of an orbit, which will be the surface
  of a celestial
  ]]--
  if self:getType() == "blackhole" then
    return math.floor(self:getScale()*getAccretionDiscRadius() + 1)
  else
    return math.floor(self:getScaledRadius() + 1)
  end
end

function ClassCelestial:setInitialPosition(pos)
  self.initialPosition = pos:clone()
end

function ClassCelestial:setVelocity(newVelocity)
  self.velocity = newVelocity:clone()
end

function ClassCelestial:getTrailLimit()
  return self.trailLimit
end

function ClassCelestial:getVelocity()
  return self.velocity
end

function ClassCelestial:getAngularVelocity()
  return self.angularVelocity
end

function ClassCelestial:getScale()
  return scenetree.findObject(self.name):getScale().x
end

function ClassCelestial:setAngularVelocity(angVel)
  self.angularVelocity = angVel
end

function ClassCelestial:setAngularVelocityRelative(percentage, value)
  --[[
  Sets the rotational speed relative to what it was previously
  ]]--
  --f ∝ 1/T
  if percentage then
    self.angularVelocity = self.angularVelocity * 1/value
  else
    self.angularVelocity = self.angularVelocity + value
  end
end

function ClassCelestial:setScaleRelative(scale)
  --[[
  Sets the scale relative to what it was previously
  Ie. a scale of 2x is double the size
  ]]--
  if scale < 0 then
    log("E", "gravitationalRacing: setScaleRelative()", "Scale cannot be less than 0, ignoring...")
    return
  end

  local previousScale = self:getScale()
  local newScale = scale * previousScale

  if newScale < 0 then
    self.shouldBeDestroyed = true
  else
    self:setScale(newScale)
  end
end

function ClassCelestial:setScale(scale)
  --[[
  Set the absolute scale of the object
  ]]--
  if scale < 0 then
    log("E", "gravitationalRacing: setScale()", "Scale cannot be less than 0, ignoring...")
    return
  end

  TorqueScript.eval(self.name..'.scale = "'..scale..' '..scale..' '..scale..'";')
end

function ClassCelestial:setMass(mass)
  --[[
  Sets the mass
  Note: setting the mass to <= 0 destroys the object
  ]]--
  if mass > 0 then
    self.mass = mass
  else
    self.mass = 0
    self.shouldBeDestroyed = true
  end
end

function ClassCelestial:setMassRelative(scale)
  --[[
  Sets the mass relative to what it was previously
  Ie. a mass of 2x is double the mass
  ]]--
  self:setMass(scale * self.mass)
end

function ClassCelestial:setScaleWithEffect(scale)
  --[[
  Sets the scale and thus the radius and mass due to the new scale, as well as
  adjusts the radial vision
  ]]--
  local newRadius = scale * factors.getRadiusScaleFactor()

  --NOTE: BeamNG is eating RAM with this (see note in ClassUnstableCelestial's constructor)
  --self:setScale(scale)

  self:setRadius(newRadius)
  --m ∝ r³
  self:setMass(self:calculateMass(newRadius, self.info.radius, self.info.mass))
  --Since the smaller the object the faster it will spin since momentum is conserved

  self:setAngularVelocity(self:calculateRotationSpeed(self.info.rotationPeriod * 1/(self.initRadius/newRadius)))
  if not self.isPassive then
    self:displayRadialZones()
  end

  if self:instanceOf() == "ClassUnstableCelestial" and self:hasChildren() then
    --Change the speed of orbiting celestials as the parent mass has changes
    for _, child in ipairs(self.children) do
      local path = child:getPath()
      if path then
        --T² ∝ m -> T ∝ m^(1/2)
        path:setFrequency(path:getInitFreq() * math.sqrt(self.mass/self.initMass))
      end
    end
  end
end

function ClassCelestial:callMethod(func, args)
  if args then
    return self[func](self, unpack(args))
  else
    return self[func](self)
  end
end

function ClassCelestial:changeModel(newModel)
  --[[
  Changes the celestial type
  ]]--
  local oldModel = self.model

  if newModel == oldModel then
    return
  end

  if oldModel == "blackhole" then
    TorqueScript.eval(self.name..'_disc.position = "100000 -100000 100000";')
    TorqueScript.eval(self.name..'_disc.scale = "0 0 0";')
  end

  local scale = self:getScale()

  local renderModel = newModel
  local newType = ""

  if newModel == "blackhole" then
    renderModel = renderModel.."_eventHorizon"

    local discName = self.name.."_disc"

    if not scenetree.findObject(discName) then
      TorqueScript.eval([[
      new TSStatic(]]..discName..[[) {
        shapeName = "levels/smallgrid/art/gravitationalRacing/celestialbodies/blackhole_discJets.dae";
        dynamic = "1";
        scale = "]]..scale..[[ ]]..scale..[[ ]]..scale..[[";
        position = "]]..self.position:getX()..[[ ]]..self.position:getY()..[[ ]]..self.position:getZ()..[[";
      };
      ]])
    else
      TorqueScript.eval(discName..'.position = "'..self.position:getX()..' '..self.position:getY()..' '..self.position:getZ()..'";')
      TorqueScript.eval(discName..'.scale = "'..scale..' '..scale..' '..scale..'";')
    end

    newType = "blackhole"
  elseif newModel == "sun" or newModel == "neutronStar" then
    newType = "star"
  else
    newType = "planet"
  end

  --Delete old...
  TorqueScript.eval(self.name..'.delete();')
  --...And replace with new
  TorqueScript.eval([[
  new TSStatic(]]..self.name..[[) {
    shapeName = "levels/smallgrid/art/gravitationalRacing/celestialbodies/]]..renderModel..[[.dae";
    dynamic = "1";
    scale = "]]..scale..[[ ]]..scale..[[ ]]..scale..[[";
    position = "]]..self.position:getX()..[[ ]]..self.position:getY()..[[ ]]..self.position:getZ()..[[";
  };
  ]])

  if newType == "star" then
    self:placeLights()
  end

  self.model = newModel
end

function ClassCelestial:getMass()
  return self.mass
end

function ClassCelestial:getRadius()
  return self.radius
end

function ClassCelestial:getScaledRadius()
  --[[
  Returns the radius in the scenario
  ]]--
  --A scale of 1 means the radius of the object is 0.03m
  return self:getScale() * 0.03
end

function ClassCelestial:setRadius(radius)
  --[[
  Sets the radius
  Note: setting the radius to <= 0 destroys the object
  ]]--
  if radius > 0 then
    self.radius = radius
  else
    self.radius = 0
    self.shouldBeDestroyed = true
  end
end

function ClassCelestial:setRadiusRelative(scale)
  --[[
  Sets the radius relative to what it was previously
  Ie. a mass of 2x is double the mass
  ]]--
  self:setRadius(scale * self.radius)
end

function ClassCelestial:setSetup(setup)
  self.setup = setup
end

function ClassCelestial:getPosition()
  return self.position
end

function ClassCelestial:getParentCelestial()
  return self.orbitingBody
end

function ClassCelestial:getName()
  return self.name
end

function ClassCelestial:getShapeName()
  return self.model
end


function ClassCelestial:getType()
  return self.type
end

function ClassCelestial:getObjectType()
  return self.objectType
end

function ClassCelestial:instanceOf()
  return "ClassCelestial"
end

function ClassCelestial:collide(object)
  --[[
  Handles the collision of two objects: the one with the bigger mass gains what
  the other looses
  ]]--
  if not object then
    log("E", "Solar System: collide()", "Cannot collide with nil object, ignoring...")
    return
  end

  --Determine how much the objects are intersecting one another by; this distance
  --will be what is to be shifted around between objects
  local intersection = (object:getScaledRadius() + self:getScaledRadius()) - object:getDistanceBetween(self.position)

  local objectToLose, objectToGain
  --Give preferential treatment to this object if they both have the same mass
  if self.mass >= object:getMass() then
    objectToLose = object
    objectToGain = self
  else
    objectToLose = self
    objectToGain = object
  end

  --The amount (0 < scale < 1) the object is clipping by
  --This is the amount to remove from the radius, and thus the size and mass
  local clippingAmount = intersection / objectToLose:getScaledRadius()
  local newScale = 1 - clippingAmount

  if newScale < 0 then
    --Object is entirely inside the other, thus should be destroyed
    objectToLose:markForDestruction()
  else
    local update = function(obj, scale)
      --[[
      Updates the object's new mass, scale, radius and rotation speed
      ]]--
      --m ∝ r³, therefore if the radius doubles then the mass octuples
      local massScale = scale^3
      local radiusScale = scale

      obj:setScaleRelative(scale)
      obj:setMassRelative(massScale)
      obj:setRadiusRelative(radiusScale)

      -- --T ∝ m, T ∝ r²
      -- object:setAngularVelocityRelative(true, 1 + massScale * radiusScale^2)
    end

    local clippingAmount2 = intersection / objectToGain:getScaledRadius()
    local newScale2 = 1 + clippingAmount2

    -- local angVelOfChunk = objectToLose:getAngularVelocity() * (clippingAmount^3 + clippingAmount^2)

    update(objectToLose, newScale)
    update(objectToGain, newScale2)

    -- --Also add the angular velocity of the additional piece to the winning object
    -- objectToGain:setAngularVelocityRelative(false, angVelOfChunk)
  end
end

function ClassCelestial:handleCollision(object)
  --[[
  Handles the collision of two objects, if necessary
  ]]--
  if not object then
    log("E", "Solar System: handleCollision()", "Cannot check for collision with nil object, ignoring...")
    return
  end

  --Distance between this object and the other
  local objPos = object:getPosition()
  local r = objPos:getDistanceBetween(self.position)

  if object:instanceOf() == "ClassCelestial" and r < object:getScaledRadius() + self:getScaledRadius() then
    self:collide(object)
    --If a vehicle is inside a celestial (hence must not be static)
  elseif self.objectType ~= "static" and object:instanceOf() == "ClassVehicle" and r < self:getScaledRadius() and not object:isResetting() then
    object:scheduleReset()
    if self.type == "star" then
      object:ignite()
    end
  end
end

function ClassCelestial:findRadialZones()
  --[[
  Returns the zone radius of the gravitational field, with increasing acceleration
  ]]--
  local findRadiusWithAccel = function(accel)
    --Assumes vehicle has mass=1
    return math.sqrt(50000 * getGravitationalConstant() * 1 * self.mass / accel) * factors.getDistanceScaleFactor()
  end

  local maxAccels = getDangerRadiiValues()
  local rmin, rmax = findRadiusWithAccel(maxAccels[1]), findRadiusWithAccel(maxAccels[3])

  return {rmin, (rmax-rmin)/2 + rmin, rmax}
end

function ClassCelestial:displayRadialZones()
  --[[
  Displays a sphere, representing the point of no return for a vehicle
  ]]--
  local radii = self:findRadialZones()
  local colour = field.displayColour(false, nil, self:instanceOf())

  for i, v in ipairs(radii) do
    local objectDangerRadiusName = self.name.."_Danger_radius"..i

    if not scenetree.findObject(objectDangerRadiusName) then
      TorqueScript.eval([[
      new TSStatic(]]..objectDangerRadiusName..[[) {
        shapeName = "levels/smallgrid/art/gravitationalRacing/field/spheres/]]..colour..[[.dae";
        scale = "]]..v..[[ ]]..v..[[ ]]..v..[[";
        dynamic = "1";
      };
      ]])
    else
      TorqueScript.eval(objectDangerRadiusName..'.scale = "'..v..' '..v..' '..v..'";')
    end

    TorqueScript.eval(objectDangerRadiusName..'.position = "'..self.position:getX()..' '..self.position:getY()..' '..self.position:getZ()..'";')
  end
end

function ClassCelestial:getForceAtPoint(point)
  --[[
  Returns the force exerted at a point by this object (with mass m=1)
  ]]--
  --Distance between this object and the other
  local objPos = point:getPosition()
  local distanceVec = objPos:subtract(self.position)
  local distance = distanceVec:getMagnitude()

  --Newton's Law of Gravitation: F = GMm/r²
  local force = getGravitationalConstant()*self.mass*point:getMass() / math.pow(distance, 2)

  --Component magnitudes = current * ratio between new and old magnitudes
  return distanceVec:multiply(force/distance)
end

function ClassCelestial:getForce(object)
  --[[
  Returns the force exerted on each object by their gravity
  ]]--
  if not object then
    log("E", "Solar System: getForce()", "Cannot determine gravitational force with nil object, ignoring...")
    return
  end


  if object:instanceOf() == "ClassVehicle" and object:isImmune() then
    return ClassVector.new(0, 0, 0)
  end

  --Distance between this object and the other
  local objPos = object:getPosition()
  local distanceVec = objPos:subtract(self.position)
  local distance = distanceVec:getMagnitude() / factors.getDistanceScaleFactor()

  --Newton's Law of Gravitation: F = GMm/r²
  local force = getGravitationalConstant()*self.mass*object:getMass() / math.pow(distance, 2)

  --Multiply vector by scalar to maintain direction with correct magnitude
  return distanceVec:multiply(force/distance)
end

function ClassCelestial:applyForce(force, dt)
  --[[
  Applies the force to this object
  ]]--
  if not force then
    log("E", "Solar System: applyForce()", "Cannot apply a nil force, ignoring...")
    return
  end

  --Newton's second law: F = ma --> a = F/m
  local a = force:divide(self.mass)

  --a ∝ v² ∝ t⁻² --> acts as t² as we are speeding up time (therefore decreasing time overall)
  a = a:multiply((factors.getTimeScaleFactor()*dt)^2)

  self.acceleration = self.acceleration:add(a)
end

function ClassCelestial:highlight(show)
  --[[
  Shows the axis of the celestial
  ]]--
  self.isHighlighted = true

  local name = self.name.."_highlight"

  local standardScale = self:getScale()
  local scale = {x = standardScale, y = standardScale, z = standardScale}

  if self.type == "blackhole" then
    --Assumes the disc is of the xy plane and the jets on the z plane
    local discScale = getAccretionDiscRadius()/0.03 * standardScale
    scale.x = discScale
    scale.y = discScale
    scale.z = getEjectionJetHeight()/0.03 * standardScale
  elseif self.model:find("saturn") then
    local ringScale = getRingRadius()/0.03 * standardScale
    scale.x = ringScale
    scale.y = math.cos(math.rad(self.axisTilt)) * ringScale
  end

  if show then
    if not scenetree.findObject(name) then
      TorqueScript.eval([[
      new TSStatic(]]..name..[[) {
        shapeName = "levels/smallgrid/art/gravitationalRacing/highlight.dae";
        scale = "]]..scale.x..[[ ]]..scale.y..[[ ]]..scale.z..[[";
        dynamic = "1";
      };
      ]])
    end

    TorqueScript.eval(name..'.position = "'..self.position:getX()..' '..self.position:getY()..' '..self.position:getZ()..'";')
  else
    TorqueScript.eval(name..".delete();");
  end
end

function ClassCelestial:placeLights()
  --[[
  Illuminates an area around the celestial
  ]]--
  if self.type == "star" then
    local name = self.name.."_light"

    local colour = self:getCelestialColour()

    if not scenetree.findObject(name) then
      TorqueScript.eval([[
      new PointLight(]]..name..[[) {
        radius = "]]..(self:getScaledRadius() * 6)..[[";
        isEnabled = "1";
        color = "]]..colour.r..[[ ]]..colour.g..[[ ]]..colour.b..[[ 1";
        brightness = "2.5";
        castShadows = "0";
        position = "]]..self.position:getX()..[[ ]]..self.position:getY()..[[ ]]..self.position:getZ()..[[";
      };
      ]])
    else
      TorqueScript.eval(name..'.position = "'..self.position:getX()..' '..self.position:getY()..' '..self.position:getZ()..'";')
      TorqueScript.eval(name..'.color = "'..colour.r..' '..colour.g..' '..colour.b..'";')
    end
  end
end

function ClassCelestial:display()
  --[[
  Updates the visuals of this object, such as moving it in-world and placing trails
  ]]--
  if self.objectType == "dynamic" or self.objectType == "fixedDynamic" or not self.setup then
    --Do not display radial zones if this object is not setup, as passive mode
    --does not kick in until the objects are setup
    if not self.isPassive then
      self:displayRadialZones()
    end

    if self.type == "star" then
      self:placeLights()
    end

    if self.isHighlighted then
      TorqueScript.eval(self.name..'_highlight.position = "'..self.position:getX()..' '..self.position:getY()..' '..self.position:getZ()..'";')
    end

    if self.burning then
      TorqueScript.eval(self.name..'_heatLight.position = "'..self.position:getX()..' '..self.position:getY()..' '..self.position:getZ()..'";')
      TorqueScript.eval(self.name..'_heatMask .position = "'..self.position:getX()..' '..self.position:getY()..' '..self.position:getZ()..'";')
    end

    --Place accretion disc and jets for blackhole
    if self.name:find("blackhole") then
      TorqueScript.eval(self.name..'_disc.position = "'..self.position:getX()..' '..self.position:getY()..' '..self.position:getZ()..'";')
    end

    --Place itself
    TorqueScript.eval(self.name..'.position = "'..self.position:getX()..' '..self.position:getY()..' '..self.position:getZ()..'";')

    if not self.setup then self.setup = true end
  end
end

function ClassCelestial:updateTrail()
  --[[
  Updates the trail by adding/removing trail points as necessary
  ]]--
  --Only add in the trail if the celestial has moved at least 10 meters
  if #self.trail == 0 or self.trail[#self.trail]:subtract(self.position):getMagnitude() >= 10 then
    table.insert(self.trail, ClassVector.new(self.position:getX(), self.position:getY(), self.position:getZ()))

    if #self.trail > self.trailLimit then
      --Delete the oldest value
      table.remove(self.trail, 1)
    end

    self:placeTrail(true)
  end
end

function ClassCelestial:rotate(dt)
  --[[
  Rotates the object
  ]]--
  --Black holes do not rotate (currently)
  if self.type ~= "blackhole" then
    self.rotAngle = self.rotAngle + dt*self.angularVelocity

    local z = self.rotAngle
    local x = math.rad(self.axisTilt)

    local q = quatFromEuler(x, 0, z):toTorqueQuat()

    TorqueScript.eval(self.name..'.rotation = "'..q.x..' '..q.y..' '..q.z..' '..q.w..'";')
  end
end

function ClassCelestial:update(dt)
  --[[
  Updates the celestial for the next frame
  Note: this function returns false if it could not update, due to this object
  being destroyed
  ]]--
  --Static objects cannot be destroyed, even if they have 0 mass/radius, unless forced to
  if self.forceDelete or (self.shouldBeDestroyed and self.objectType ~= "static") then
    self:removeFromScene()
    return false
  end

  if not self.delayed then
    if self.objectType == "dynamic" then
      --Update the velocity from the acceleration
      self.velocity = self.velocity:add(self.acceleration)

      --The framerate will fluctuate, so the velocity should scale appropriately
      self.velocity = self.velocity:multiply(dt/self.frameTime)

      --Update the position with respect to the velocity
      self.position = self.position:add(self.velocity)

      self:updateTrail()

      self.acceleration:zero()

      self.frameTime = dt
    elseif self.objectType == "fixedDynamic" and self.path then
      self.position = self.path:update(dt)

      for _, child in ipairs(self.children) do
        --Binary celestials do not care where the other celestial is
        if child:getName() ~= self.orbitingBody then
          local path = child:getPath()
          if path then
            path:setOffset(self.position)
          end
        end
      end
    end

    if self.label then
      local pos = self.position:clone()
      self.label:move(ClassVector.new(pos:getX(), pos:getY() + self:getScaledRadius() + 5, pos:getZ()))
    end

    self:rotate(dt)
    self:display()
  end

  return true
end

function ClassCelestial:toList()
  --[[
  Returns a list representation of this instance
  ]]--
  return {self:instanceOf(), self.name, scenetree.findObject(self.name).shapeName:gsub("levels/smallgrid/art/gravitationalRacing/celestialbodies/", ""):gsub(".dae", ""), self.mass, self.objectType, self:findRadialZones()[2], self.position:toString(), self.velocity:toString()}
end

function ClassCelestial:toString()
  --[[
  Returns a string representation of this instance
  ]]--
  return self:instanceOf().."[Name: "..self.name..
  ", Type: "..self.type..
  ", Model: "..scenetree.findObject(self.name).shapeName:gsub("levels/smallgrid/art/gravitationalRacing/celestialbodies/", ""):gsub(".dae", "")..
  ", Mass: "..self.mass..
  ", ObjectType: "..self.objectType..
  ", DangerRadius: "..self:findRadialZones()[2]..
  ", Position: "..self.position:toString()..
  ", Velocity: "..self.velocity:toString().."]"
end

------------------------------------------------------------------------------------------------------------------------------------------

ClassSupernova = {}
ClassSupernova.__index = ClassSupernova

function ClassSupernova:new(name, type, scale, objectType, orbitingBody, passive, delayed, rotation, supernovaData)
  --NOTE: All supernovae will be simulated as a type II supernova

  if not supernovaData then
    error("No supernova data!")
  end

  local self = ClassCelestial:new(name, type, scale, objectType, orbitingBody, passive, delayed, rotation)

  local constants = {
    --The time it takes to collapse the core of the star
    COLLAPSE_PERIOD = 0.0625,
    --Assume that 66% of the mass is lost in the explosion - rough estimate which lies
    --in the limit suggested here: https://en.wikipedia.org/wiki/Tolman%E2%80%93Oppenheimer%E2%80%93Volkoff_limit
    MASS_LOSS = 0.66,
    --(Tolman–Oppenheimer–Volkoff limit) The maximum solar mass before a remnant becomes a black hole
    TOV_LIMIT = 3,
    --The total time the cloud lingers
    CHANGE_PERIOD = 10,
    --When the timer reaches this point, the player will get a warning
    WARNING_TIME = 10,
    --How far the outer-most cloud can reach
    MAX_CLOUD_SCALE = self.initScale * 25,
    --Which cloud will burn planets within it
    HEAT_RANGE = 4,
    --Which cloud will destroy planets within it
    VAPORISATION_RANGE = 2,
    --Celestial to cloud radius ratio
    CELESTIAL_CLOUD_RATIO = 6/100,
    --The radius of the cloud where scale=1
    CLOUD_RADIUS = 0.5
  }

  local massOfRemnant = self.mass * (1-constants.MASS_LOSS)
  local targetType = massOfRemnant > constants.TOV_LIMIT and "blackhole" or "neutronStar"

  local sunScale = celestialInfo.getData("sun", "radius")
  local targetScale = targetType == "neutronStar"
  and (celestialInfo.getData("neutronStar", "radius") / sunScale) * scale
  or  (celestialInfo.getData("blackhole"  , "radius") / sunScale) * scale

  --The total time period
  local T = constants.CHANGE_PERIOD
  --Function for the scaling of the supernova
  --https://www.desmos.com/calculator/noqwvbuozb
  local S = function(t) return -(t/T + 1)^-10 + 1 end

  --Function for the outward acceleration applied to vehicles
  local A = function(d) return 300*(1 - (d/constants.MAX_CLOUD_SCALE)) end

  local vehicles = {}
  --Each vehicle will only be affected once by the supernova
  for n, instance in pairs(supernovaData.vehicles) do
    vehicles[n] = {instance = instance, affected = false}
  end

  self.supernovaData = {
    constants    = constants,
    triggerType  = supernovaData.triggerType or "countdown",
    initTimer    = supernovaData.timer       or 20,
    phase        = "waiting",
    targetType   = targetType,
    targetScale  = targetScale,
    scaleChange  = (scale - targetScale) * 1/constants.COLLAPSE_PERIOD,
    warned = false,
    gasCloudData = {
      S       = S,
      A       = A,
      time    = 0,
      colours = {
        {r = 0  , g = 192, b = 255, a = 2},
        {r = 255, g = 255, b = 255, a = 2},
        {r = 255, g = 255, b = 0  , a = 2},
        {r = 255, g = 128, b = 0  , a = 2},
        {r = 255, g = 0  , b = 0  , a = 2}
      }
    },
    celestialsInRange = {},
    vehicles = vehicles
  }

  --This is used when the trigger type is a countdown
  --Self referential to table so declared outside
  self.supernovaData.timer = self.supernovaData.initTimer

  --Create layers of gas clouds (inner to outer): blue, white, yellow, orange, red
  --Do this beforehand so there is a smooth transition between collapse and explosion
  for i = 1, 5 do
    local col = self.supernovaData.gasCloudData.colours[i]

    TorqueScript.eval([[
    new TSStatic(]]..self.name..[[_gasCloud_]]..i..[[) {
      shapeName = "levels/smallgrid/art/gravitationalRacing/celestialbodies/nova/sphere.dae";
      dynamic = "1";
      scale = "0 0 0";
      position = "0 0 0";
      instanceColor = "]]..col.r..[[ ]]..col.g..[[ ]]..col.b..[[ ]]..col.a..[[";
    };
    ]])
  end

  --Create warning sphere
  local warningScale = constants.MAX_CLOUD_SCALE * constants.CELESTIAL_CLOUD_RATIO

  TorqueScript.eval([[
  new TSStatic(]]..self.name..[[_supernova_warning) {
    shapeName = "levels/smallgrid/art/gravitationalRacing/celestialbodies/nova/sphere.dae";
    dynamic = "1";
    scale = "]]..warningScale..[[ ]]..warningScale..[[ ]]..warningScale..[[";
    position = "0 0 0";
    instanceColor = "1 0 0 0";
  };
  ]])

  setmetatable(self, ClassSupernova)
  return self
end

--Inheritance
setmetatable(ClassSupernova, {__index = ClassCelestial})

function ClassSupernova:getEffectRange()
  local constants = self.supernovaData.constants
  return constants.MAX_CLOUD_SCALE/5 * constants.HEAT_RANGE * constants.CELESTIAL_CLOUD_RATIO * constants.CLOUD_RADIUS
end

function ClassSupernova:setCelestialsWithinRange(celestials)
  self.supernovaData.celestialsInRange = celestials
end

function ClassSupernova:goSupernova()
  --[[
  Begins the supernova
  ]]--
  self.supernovaData.phase = "collapse"
end

function ClassSupernova:update(dt)
  --[[
  Responsible for changing states when applicable and causing the supernova (if triggerType = countdown)
  ]]--
  ClassCelestial.update(self, dt)

  local data = self.supernovaData
  if data.phase == "waiting" then
    --This phase waits for the trigger or countdown to finish
    if data.triggerType == "countdown" then
      data.timer = data.timer - dt

      local WARNING_TIME = data.constants.WARNING_TIME

      if data.timer <= 0 then
        --Remove warning from view
        TorqueScript.eval(self.name..'_supernova_warning.instanceColor = "1 0 0 0";')
        self:goSupernova()
      elseif data.timer <= WARNING_TIME and not data.warned then
        helper.flashUiMessage("Supernova Imminent!", 5)
        data.warned = true

        --Place at positon of celestial
        TorqueScript.eval(self.name..'_supernova_warning.position = "'..self.position:getX()..' '..self.position:getY()..' '..self.position:getZ()..'";')
      elseif data.warned then
        if self.objectType ~= "static" then
          TorqueScript.eval(self.name..'_supernova_warning.position = "'..self.position:getX()..' '..self.position:getY()..' '..self.position:getZ()..'";')
        end

        local alpha = math.abs(math.sin(3*math.pi/WARNING_TIME * data.timer) / 4)
        local colour = "1 "..(data.timer / WARNING_TIME).." 0 "..alpha
        TorqueScript.eval(self.name..'_supernova_warning.instanceColor = "'..colour..'";')
      end
    end
  elseif data.phase == "collapse" then
    --This phase scales the celestial down to its remnant scale
    local newScale = self:getScale() - data.scaleChange * dt

    if newScale <= data.targetScale then
      newScale = data.targetScale
      data.phase = "pre-explosion"
    end

    self:setScale(newScale)
  elseif data.phase == "pre-explosion" then
    --This phase sets up the gasclouds' positions and changes the celestial to its new type

    --Subtract the loss of mass from the explosion and update the model
    self:setMassRelative(1 - data.constants.MASS_LOSS)
    self:changeModel(data.targetType)
    --Update the radial vision
    self:displayRadialZones()

    --Position the clouds at the necessary points
    for i = 1, 5 do
      TorqueScript.eval(self.name..'_gasCloud_'..i..'.position = "'..self.position:getX()..' '..self.position:getY()..' '..self.position:getZ()..'";')
    end

    data.phase = "explosion"
  elseif data.phase == "explosion" then
    --This phase scales up the clouds and is responsible for affecting planets

    local cloudData = data.gasCloudData
    local constants = data.constants
    local CHANGE_PERIOD = constants.CHANGE_PERIOD

    --/5 since the fifth layer is *5 this baseScale
    local baseScale = cloudData.S(cloudData.time) * constants.MAX_CLOUD_SCALE/5 * constants.CELESTIAL_CLOUD_RATIO
    local alpha = 1 - cloudData.time / CHANGE_PERIOD

    for i = 1, 5 do
      local scale = i * baseScale
      TorqueScript.eval(self.name..'_gasCloud_'..i..'.scale = "'..scale..' '..scale..' '..scale..'";')

      --Set alpha
      local col = cloudData.colours[i]
      col.a = alpha
      TorqueScript.eval(self.name..'_gasCloud_'..i..'.instanceColor = "'..col.r..' '..col.g..' '..col.b..' '..col.a..'";')

      local isHeatCloud     = i == constants.HEAT_RANGE
      local isVaporiseCloud = i == constants.VAPORISATION_RANGE

      if isHeatCloud or isVaporiseCloud then
        local radiusOfSphere = scale * constants.CLOUD_RADIUS

        --Check each celestial to see if they are in one of the cloud ranges
        for _, celestial in ipairs(data.celestialsInRange) do
          if not celestial:isRemoved() and self.position:getDistanceBetween(celestial:getPosition()) <= radiusOfSphere then
            --No point in setting it burning if it already is
            if isHeatCloud and not celestial:isBurning() then
              celestial:setBurning(true)
            elseif isVaporiseCloud then
              --TODO - actually animate vaporising the celestial
              celestial:removeFromScene()
            end
          end
        end
      end
    end

    if not self.isPassive then
      --Check each vehicle
      for _, vehicleData in pairs(data.vehicles) do
        local instance = vehicleData.instance

        local distVec = self.position:subtract(instance:getPosition())
        local dist = distVec:getMagnitude()
        local radiusOfCloud = baseScale * 5 * constants.CLOUD_RADIUS

        if not vehicleData.affected and dist <= radiusOfCloud then
          local accelMag = cloudData.A(dist)
          local accel = distVec:toUnitVector():multiply(-accelMag)

          instance:addAcceleration(accel, 1)

          --Don't apply another lot of acceleration
          vehicleData.affected = true
        end
      end
    end

    if cloudData.time >= CHANGE_PERIOD then
      data.phase = "post-explosion"
    else
      cloudData.time = cloudData.time + dt
    end
  elseif data.phase == "post-explosion" then
    --This phase resets the gasclouds' back to their starting state

    for i = 1, 5 do
      TorqueScript.eval(self.name..'_gasCloud_'..i..'.scale = "0 0 0";')
    end

    TorqueScript.eval(self.name..'_supernova_warning.scale = "0 0 0";')

    data.phase = "finished"
  end
end

function ClassSupernova:reset()
  --[[
  Resets the object
  ]]--
  ClassCelestial.reset(self)

  local data = self.supernovaData
  data.timer = data.initTimer
  data.phase = "waiting"
  data.warned = false
  data.gasCloudData.time = 0

  for _, vehicleData in pairs(data.vehicles) do
    vehicleData.affected = false
  end

  --Reset the scale for the gas clouds
  for i = 1, 5 do
    TorqueScript.eval(self.name..'_gasCloud_'..i..'.scale = "0 0 0";')
  end

  self:displayRadialZones()
end

function ClassSupernova:instanceOf()
  return "ClassSupernova"
end

------------------------------------------------------------------------------------------------------------------------------------------

ClassUnstableCelestial = {}
ClassUnstableCelestial.__index = ClassUnstableCelestial

function ClassUnstableCelestial:new(name, type, scale, objectType, orbitingBody, passive, delayed, rotation, ferocity)
  local self = ClassCelestial:new(name, type, scale, objectType, orbitingBody, passive, delayed, rotation)

  --Set a default to low-medium
  if not ferocity then
    ferocity = 2
  end

  self.instability = {
    --The maximum change of mass ie. between 50% -> 150% of normal mass
    MAX_DEVIATION = scale / 2,
    --This is how quickly the celestial will change its mass
    nextCycle = 0,
    targetScale = 0,
    rateOfChange = 175 * ferocity  * scale/1000,
    ferocity = ferocity,
    currentScale = scale
  }

  setmetatable(self, ClassUnstableCelestial)
  return self
end

--Inheritance
setmetatable(ClassUnstableCelestial, {__index = ClassCelestial})

function ClassUnstableCelestial:update(dt)
  --[[
  Updates the celestial by periodically changing its mass
  ]]--
  ClassCelestial.update(self, dt)

  local data = self.instability

  data.currentScale = data.currentScale + data.rateOfChange * dt
  self:setScaleWithEffect(data.currentScale)

  --Check if it has reached its target mass
  if (data.rateOfChange > 0 and data.currentScale >= data.targetScale) or (data.rateOfChange < 0 and data.currentScale <= data.targetScale) then
    local dev = data.MAX_DEVIATION
    local nextTarget = 0
    --The speed to change the celestial's mass - end term makes big and small celestials take the same time to change between states:
    --for example, it takes the same time to change a mass of 100 -> 200 as it does 1000 -> 2000
    local baseChange = math.random(175, 350) * data.ferocity * self.initScale/1000
    if data.currentScale > self.initScale then
      --The next cycle makes the celestial smaller
      nextTarget = self.initScale + math.random(-dev, -dev/10)
      data.rateOfChange = -baseChange
    else
      --The next cycle makes the celestial bigger
      nextTarget = self.initScale + math.random(dev/10, dev)
      data.rateOfChange = baseChange
    end

    data.targetScale = nextTarget
  end
end

function ClassUnstableCelestial:instanceOf()
  return "ClassUnstableCelestial"
end

------------------------------------------------------------------------------------------------------------------------------------------

ClassExoticCelestial = {}
ClassExoticCelestial.__index = ClassExoticCelestial

function ClassExoticCelestial:new(name, type, scale, objectType, orbitingBody, passive, delayed, rotation)
  local self = ClassCelestial:new(name, type, scale, objectType, orbitingBody, passive, delayed, rotation)

  self.mass = -self.mass

  setmetatable(self, ClassExoticCelestial)
  return self
end

--Inheritance
setmetatable(ClassExoticCelestial, {__index = ClassCelestial})

function ClassExoticCelestial:calculateMass(radius, actualRadius, actualMass)
  return -ClassCelestial.calculateMass(self, radius, actualRadius, actualMass)
end

function ClassExoticCelestial:setMass(mass)
  --[[
  Sets the mass of the object
  Opposite of ClassCelestial's setMass function's requirements
  ]]--
  if mass < 0 then
    self.mass = mass
  else
    self.mass = 0
    self.shouldBeDestroyed = true
  end
end

function ClassExoticCelestial:findRadialZones()
  --[[
  Returns the zone radius of the gravitational field, with decreasing acceleration (since this object pushes things away)
  ]]--
  local findRadiusWithAccel = function(accel)
    --Assumes vehicle has mass=1
    return math.sqrt(50000 * getGravitationalConstant() * 1 * self.mass / accel) * factors.getDistanceScaleFactor()
  end

  local maxAccels = getDangerRadiiValues()
  --Technically, rmin and rmax should be swapped as negatives are involved but it is closer
  --to the parent's function and so easier to change if need be
  local rmin, rmax = findRadiusWithAccel(-maxAccels[1]), findRadiusWithAccel(-maxAccels[3])

  return {rmin, (rmax-rmin)/2 + rmin, rmax}
end

function ClassExoticCelestial:instanceOf()
  return "ClassExoticCelestial"
end

------------------------------------------------------------------------------------------------------------------------------------------

local function new(name, type, scale, objectType, orbitingBody, passive, delayed, rotation)
  return ClassCelestial:new(name, type, scale, objectType, orbitingBody, passive, delayed, rotation)
end

local function newUnstable(name, type, scale, objectType, orbitingBody, passive, delayed, rotation, ferocity)
  return ClassUnstableCelestial:new(name, type, scale, objectType, orbitingBody, passive, delayed, rotation, ferocity)
end

local function newExotic(name, type, scale, objectType, orbitingBody, passive, delayed, rotation)
  return ClassExoticCelestial:new(name, type, scale, objectType, orbitingBody, passive, delayed, rotation)
end

local function newSupernova(name, type, scale, objectType, orbitingBody, passive, delayed, rotation, supernovaData)
  return ClassSupernova:new(name, type, scale, objectType, orbitingBody, passive, delayed, rotation, supernovaData)
end

local function getTypes()
  --[[
  Returns the types of celestials possible
  ]]--
  --DO NOT change the order of these: "star" must be first for some algorithms to work
  return {"star", "planet", "blackhole"}
end

local function toListKeys()
  --[[
  Returns a list with the keys of attributes in this class returned by toList()
  Note: this function exists instead of having these keys in the same table as toList()
  because order needs to be maintained, which string keys do not provide
  ]]--
  return {"Class", "Name", "Model", "Mass", "ObjectType", "DangerRadius", "Position", "Velocity"}
end

local M = {}

M.new = new
M.newUnstable = newUnstable
M.newExotic = newExotic
M.newSupernova = newSupernova

M.getTypes = getTypes
M.toListKeys = toListKeys
M.getGravitationalConstant = getGravitationalConstant
M.getAccretionDiscRadius = getAccretionDiscRadius
M.getRingRadius = getRingRadius
M.setDangerRadiiValues = setDangerRadiiValues
M.getAllCelestials = getAllCelestials
M.getCelestialTypeFromModel = getCelestialTypeFromModel
return M
