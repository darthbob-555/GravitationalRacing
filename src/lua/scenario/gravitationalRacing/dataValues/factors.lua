local M = {}

--This factor is how much the distance between orbits are scaled by
--Default: 10⁻⁸
local distanceScaleFactor = math.pow(10, -8)
--This factor is how much the velocities of objects is sped up by
--Real-time: 1
--Default: 25 days/s
local timeScaleFactor = 25*24*60*60
--This factor is by how much the sizes of objects are scaled inwards by:
--Set by rₐ/r₉, where rₐ , r₉ = actual radius, in-game radius respectively
local actualRadiusScaleFactor   = 696342/(10000*0.03)
--This factor is an artificial/manual factor to make the celestials big enough to be visible. but not too powerful
local scaledRadiusScaleFactor = actualRadiusScaleFactor * 0.03

local function getTimeScaleFactor()         return timeScaleFactor         end
local function getDistanceScaleFactor()     return distanceScaleFactor     end
local function getRadiusScaleFactor()       return scaledRadiusScaleFactor end
local function getActualRadiusScaleFactor() return actualRadiusScaleFactor end

local function setFactors(distFactor, timeFactor, radiusFactor)
  --[[
  Sets specific factors for the scenario
  ]]--
  --If factors are specified, then set them, else use default values
  if distFactor   then distanceScaleFactor = distFactor   end
  if timeFactor   then timeScaleFactor     = timeFactor   end
  if radiusFactor then radiusScaleFactor   = radiusFactor end
end

M.getTimeScaleFactor = getTimeScaleFactor
M.getDistanceScaleFactor = getDistanceScaleFactor
M.getRadiusScaleFactor = getRadiusScaleFactor
M.getActualRadiusScaleFactor = getActualRadiusScaleFactor
M.getVelocityScaleFactor = getVelocityScaleFactor
M.setFactors = setFactors
return M
