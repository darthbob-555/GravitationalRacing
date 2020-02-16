local M = {}

local ClassVector       = require("scenario/gravitationalRacing/classes/classVector")
local ClassKey          = require("scenario/gravitationalRacing/classes/classKey")
local ClassCollectable  = require("scenario/gravitationalRacing/classes/classCollectable")
local scenarioDetails   = require("scenario/gravitationalRacing/scenario/scenarioDetails")
local fileHandler       = require("scenario/gravitationalRacing/utils/fileHandler")
local errorHandler      = require("scenario/gravitationalRacing/utils/errorHandler")

local items = {}

local function resetAllItems()
  --[[
  Resets all keys and barriers back to their original places
  ]]--
  for _, instances in pairs(items) do
    for _, instance in ipairs(instances) do
      instance:reset(true)
      instance:setCollectable(true)
    end
  end
end

local function closeOpenBarriers()
  --[[
  Closes all open barriers
  ]]--
  for _, instance in ipairs(items.key) do
    instance:closeOpenBarriers()
  end
end

local function resetKeys()
  --[[
  Resets all keys (but not their associated barriers)
  ]]--
  for _, instance in ipairs(items.key) do
    instance:reset(false)
  end
end

local function initCollectables()
  --[[
  Sets all collectables to be able to be collected
  ]]--
  for _, instances in pairs(items) do
    for _, instance in ipairs(instances) do
      instance:setCollectable(true)
    end
  end
end

local function resetKeysAfterReset(checkpoint, lap)
  --[[
  Resets any keys unlocked after the last checkpoint
  Parameters:
    checkpoint - the checkpoint to use as reference
    lap        - the lap to use as reference
  ]]--
  errorHandler.assertNil(checkpoint, lap)

  for _, instance in ipairs(items.key) do
    if instance:isCollected() then
      local data = instance:getCollectedOnData()
      if data.checkpoint == checkpoint and data.lap == lap then
        instance:reset(false)
      end
    end
  end
end

local function hasCollectedCollectables()
  --[[
  Returns:
   collected - the collectables collected
  ]]--
  local collected = {}
  for i, instance in ipairs(items.collectable) do
    collected[i] = instance:isCollected()
  end

  return collected
end

local function update(vehicle, dt, currentCheckpoint, currentLap)
  --[[
  Checks and monitors the keys' and collectables' distances to the vehicle, and activates the keys
  if the vehicle gets within range of the key/collectable.
  This function also animates them and, if collected, is responsible for triggering the opening of
  the barriers at the appropriate range of the vehicle and also triggering the closing of said barriers
  Parameters:
    vehicle           - the vehicle to check distances with
    dt                - the time since the last frame
    currentCheckpoint - the current checkpoint
    currentLap        - the currentLap
  ]]--
  errorHandler.assertNil(vehicle, dt, currentCheckpoint, currentLap)

  for _, instances in pairs(items) do
    for _, instance in ipairs(instances) do
      instance:update(dt, vehicle:getPosition(), currentCheckpoint, currentLap)
    end
  end
end

local function findAllItems()
  --[[
  Finds all keys/collectables in the scenario
  Returns:
    foundItems - a list of all items found and their useful data
  ]]--
  local types = {"key", "collectable"}
  local foundItems = {}
  for _, type in ipairs(types) do
    foundItems[type] = {}

    local i = 1
    local name = type..i
    local obj = scenetree.findObject(name)

    while obj do
      local pos = obj:getPosition()

      if type == "key" then
        foundItems[type][i] = {controlledBarriers = obj.controlledBarriers or i, position = ClassVector.new(pos.x, pos.y, pos.z), useOnNextLap = tonumber(obj.useOnNextLap)}
      elseif type == "collectable" then
        foundItems[type][i] = {position = ClassVector.new(pos.x, pos.y, pos.z)}
      end

      i = i + 1
      name = type..i
      obj = scenetree.findObject(name)
    end
  end

  return foundItems
end

local function createAllItems(scName)
  --[[
  Finds and creates the key objects
  Parameters:
    scName - the name of the scenario
  ]]--
  items = {}
  local foundItems = findAllItems()

  local foundCollectables = fileHandler.readFromFile(scName, "collectables")

  for type, collection in pairs(foundItems) do
    items[type] = {}
    for i, data in ipairs(collection) do
      if type == "key" then
        items[type][i] = ClassKey.new(i, data.controlledBarriers, data.position, data.useOnNextLap)
      elseif type == "collectable" then
        local visible = nil
        if foundCollectables then
          visible = not foundCollectables[1]
        end

        --Assumes there is only 1 collectable per scenario
        --Account for tutorial not considering the collectable as a proper collectable in the save file
        items[type][i] = ClassCollectable.new(i, data.position, visible)
      end
    end
  end
end

local function printResults()
  --[[
  Prints all keys and objects found
  ]]--
  print("\nCollectables Found:\n")
  for _, instances in pairs(items) do
    for _, instance in ipairs(instances) do
      print(instance:toString())
    end
  end
end

local function initialise(fullReset, srcFile)
  --[[
  Setups the script
  Parameters:
    fullReset - whether it is a full reset or not
    srcFile   - the source file of the scenario loaded
  ]]--
  if fullReset then
    local scenarioName = scenarioDetails.getScenarioDetails(srcFile)
    --Set the last scenario to this
    fileHandler.setLastScenario(scenarioName)

    createAllItems(scenarioName)
  else
    resetAllItems()
  end
end

M.resetAllItems = resetAllItems
M.closeOpenBarriers = closeOpenBarriers
M.resetKeys = resetKeys
M.initCollectables = initCollectables
M.resetKeysAfterReset = resetKeysAfterReset
M.hasCollectedCollectables = hasCollectedCollectables
M.update = update
M.printResults = printResults
M.initialise = initialise
return M
