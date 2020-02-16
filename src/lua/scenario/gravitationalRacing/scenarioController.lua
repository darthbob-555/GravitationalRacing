--------------------------------------------------------------------------------------------------------------------------------------------------------
--This file is the center of the system and initiates the interactions with other scripts
--------------------------------------------------------------------------------------------------------------------------------------------------------

local M = {}

local errorHandler        = require("scenario/gravitationalRacing/utils/errorHandler")
local ClassVehicle        = require("scenario/gravitationalRacing/classes/classVehicle")
local shortcutHandler     = require("scenario/gravitationalRacing/scenario/track/shortcutHandler")
local celestialsHandler   = require("scenario/gravitationalRacing/celestial/celestialsHandler")
local checkpointsHandler  = require("scenario/gravitationalRacing/scenario/track/checkpointsHandler")
local championshipHandler = require("scenario/gravitationalRacing/scenario/championship/championshipHandler")

local vehicles = {}

local sourceFile = ""

---------
-- local streams = require("vehicle/guistreams")

-- local function getRollPitch(dirFront, dirUp)
--   -- find vehicle roll and pitch, in degrees, 0deg being normal upright rotation, +/-180deg being on its roof
--   local dirLeft = dirUp:cross(dirFront)
--   local roll  = math.deg(math.asin(dirLeft.z))
--   local pitch = math.deg(math.asin(dirFront.z))
--   if dirUp.z < 0 then -- if we are closer to upside down than to downside up
--     -- detect the "on its roof" situation, where angles are zero, and make sure they go all the way to 180deg instead, like this:
--     -- original rotation angles:  0deg (ok), 90deg (halfway),      0deg (on its roof), -90deg (halfway), 0deg (ok)
--     -- corrected rotation angles: 0deg (ok), 90deg (halfway), +/-180deg (on its roof), -90deg (halfway), 0deg (ok)
--     roll  = sign( roll)*(180 - math.abs( roll))
--     pitch = sign(pitch)*(180 - math.abs(pitch))
--   end
--   --log("D", "recovery", "Roll: "..r(roll,2,2)..", Pitch: "..r(pitch,2,2)..", dirUp: "..s(recPoint.dirUp, 2,2))
--   return roll, pitch
-- end

-- local obj = scenetree.findObject("scenario_player0")
-- print(getRollPitch(vec3(obj:getDirectionVector()), vec3(obj:getDirectionVectorUp())))
---------

local function update(dt, start)
  --[[
  Updates the scenario, by calling various modules' update functions
  Parameters:
    dt    - the time since the last frame
    start - whether the scenario has started
  ]]--
  if vehicles.scenario_player0 then
    celestialsHandler.update(start, vehicles, dt)
    checkpointsHandler.update(start, vehicles.scenario_player0, dt)
  end
end

local function onScenarioRestarted()
  if championshipHandler.isShowingEndscreen() then
    championshipHandler.skip()
  end
end

local function setSourceFile(srcFile)
  --[[
  Sets the scenario's file directory that is being used
  Parameters:
    sourceFile - the file directory to use
  ]]--
  errorHandler.assertNil(srcFile)
  sourceFile = srcFile
  checkpointsHandler.setSrcFile(srcFile)
end

local function getSourceFile()
  return sourceFile
end

local function resetVehicle(vehicleName)
  --[[
  Resets the vehicle, given the vehicle name
  Parameters:
    vehicle - the name of the vehicle
  ]]--
  errorHandler.assertNil(vehicleName)
  if vehicles[vehicleName] then
    vehicles[vehicleName]:scheduleReset()
  else
    log("W", "scenarioController:resetVehicle()", vehicleName.." is not a known vehicle")
  end
end

local function resetVehiclePos(vehicleName)
  --[[
  Resets a vehicle's internal pos
  This prevents the car from triggering anything while a scenario restart takes place
  ]]--
  errorHandler.assertNil(vehicleName)
  if vehicles[vehicleName] then
    vehicles[vehicleName]:resetPosition()
  else
    log("W", "scenarioController:resetVehicle()", vehicleName.." is not a known vehicle")
  end
end

local function setMoving()
  --[[
  Sets delayed celestials moving
  ]]--
  celestialsHandler.callMethodOnCelestials(nil, "setDelayed", {false})
end

local function start()
  --[[
  Sets any delayed celestials moving and sets the countdown for supernovae
  ]]--
  setMoving()
  celestialsHandler.startSupernovae()
end

local function initialise(srcFile)
  errorHandler.assertNil(srcFile)

  local fullReset = sourceFile ~= srcFile

  if not vehicles.scenario_player0 or fullReset then
    vehicles.scenario_player0 = ClassVehicle.new("scenario_player0", scenetree.findObject("scenario_player0"):getPosition())
  else
    resetVehiclePos("scenario_player0")
  end

  if srcFile:find("solar_system_simulation") then
    celestialsHandler.createCelestials(fullReset, vehicles, true)
  else
    celestialsHandler.createCelestials(fullReset, vehicles, false)

    --Setup checkpoints
    checkpointsHandler.createCheckpoints(fullReset, srcFile)
    checkpointsHandler.printResults()
    --Setup shortcuts
    shortcutHandler.initialise(fullReset, srcFile)
    shortcutHandler.printResults()
  end

  celestialsHandler.initCelestials()
  celestialsHandler.printResults()

  sourceFile = srcFile
end

local function onScenarioChange(sc)
  if sc and sc.state == "pre-running" then
    championshipHandler.onScenarioChange(sc)

    --Don't load if the scenario is going to change anyway
    if not championshipHandler.isSkippingEvent() then
      initialise(sc.sourceFile)
    end
  end
end

M.update = update
M.onScenarioRestarted = onScenarioRestarted
M.setSourceFile = setSourceFile
M.getSourceFile = getSourceFile
M.resetVehicle = resetVehicle
M.setMoving = setMoving
M.start = start
M.initialise = initialise
M.onScenarioChange = onScenarioChange
return M
