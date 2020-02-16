local M = {}

local tableComp          = require("scenario/gravitationalRacing/utils/tableComprehension")
local fileHandler        = require("scenario/gravitationalRacing/utils/fileHandler")
local errorHandler       = require("scenario/gravitationalRacing/utils/errorHandler")
local ClassCheckpoint    = require("scenario/gravitationalRacing/classes/classCheckpoint")
local shortcutHandler    = require("scenario/gravitationalRacing/scenario/track/shortcutHandler")
local scenarioDetails    = require("scenario/gravitationalRacing/scenario/scenarioDetails")
local scenarioEndHandler = require("scenario/gravitationalRacing/scenario/scenarioEndHandler")

local checkpoints, checkpointConfig = {}, {}
--i = section/non-split-route cp, j = specific split-route, k = split-route cp
local currentIndexes = {i = 0, j = nil, k = nil}
local lastIndexes = {i = 0, j = nil, k = nil}

local currentLap, totalLaps = 0, 0

local finished = false

local currentCheckpointNum, totalCheckpointNum = 0, 0
local nextCheckpointInstances = {}

local resets = 0
local sourceFile = ""

local function completeLap()
  --[[
  Completes the lap by adding 1 to the currentLap and applying UI/sound changes
  If the number of laps is sufficient, ends the scenario
  ]]--
  --Lap is complete (if p-to-p race then this still applies as it is treated as a one lap race)
  currentLap = currentLap + 1

  if currentLap == totalLaps then
    scenarioEndHandler.finish(resets, sourceFile)
    finished = true
  else
    guihooks.trigger("RaceLapChange", {current = currentLap+1, count = totalLaps})
    shortcutHandler.closeOpenBarriers()
    Engine.Audio.playOnce("AudioGui", "event:UI_Checkpoint")
  end
end

local function getCheckpointFromTable(indexes)
  --[[
  Gets the last checkpoint triggered, given the indexes
  Parameters:
    indexes - the list of indexes to use
  Returns:
    <string> - the checkpoint
  ]]--
  errorHandler.assertNil(indexes)

  --The index will be out of bounds if the player has not reached a checkpoint
  if indexes.i == 0 then
    return "checkpoint0"
  else
    errorHandler.assertTrue(indexes.i > 0, "Index must be greater than 0")

    if indexes.j and indexes.k then
      errorHandler.assertTrue(indexes.j > 0 and indexes.k > 0, "Indexes must be greater than 0")
      errorHandler.assertNil(indexes.j, indexes.k)
      return checkpointConfig[indexes.i][indexes.j][indexes.k]
    else
      return checkpointConfig[indexes.i]
    end
  end
end

local function getLastCheckpoint()
  --[[
  Returns:
    <string> - the last checkpoint the player passed
  ]]--
  return getCheckpointFromTable(lastIndexes)
end

local function getCurrentCheckpoint()
  --[[
  Returns:
    string - the name of the current checkpoint
  ]]--
  return getCheckpointFromTable(currentIndexes)
end

local function getNextSection()
  --[[
  Returns:
    <string> - the next section (either single checkpoint or split-route)
  ]]--
  if currentIndexes.j and currentIndexes.k then
    local splitRoute = checkpointConfig[currentIndexes.i  ][currentIndexes.j][currentIndexes.k+1]
    --Return the next split-route checkpoint. If there is not one, return the next non split-route checkpoint
    return splitRoute
       and splitRoute
        or checkpointConfig[currentIndexes.i+1]
  else
    return checkpointConfig[currentIndexes.i+1]
  end
end

local function changeState(cpName, state)
  --[[
  Changes the state of a checkpoint, given a name and a state
  Parameters:
    cpName - the name of the checkpoint
    state  - the state to change to
  ]]--
  errorHandler.assertNil(cpName, state)

  local instance = checkpoints[cpName]
  --Change the next checkpoint, if it is not the end
  if not instance:isEndCheckpoint() then
    instance:setState(state)
  end
end

local function triggerCheckpoint(checkpointNum)
  --[[
  Triggers a checkpoint
  Parameters:
    checkpointNum - the checkpoint number in the lap/route
  ]]--
  errorHandler.assertNil(checkpointNum)

  local cpName = "checkpoint"..checkpointNum
  errorHandler.assertTrue(scenetree.findObject(cpName) ~= nil, cpName.." is not a checkpoint in this scenario")

  local toChangeState = {}

  local possibleChoices = getNextSection()
  local indexJ = nil
  --Determine which checkpoint was taken in the split-route
  if type(possibleChoices) == "table" then
    for i, route in ipairs(possibleChoices) do
      if route[1] == cpName then
        indexJ = i
        break
      end
    end
  end

  local cpInstance = checkpoints[cpName]
  currentCheckpointNum = currentCheckpointNum + 1
  Engine.Audio.playOnce("AudioGui", "event:UI_Checkpoint")
  --If the checkpoint is not the end
  if checkpointNum > 0 and cpName ~= checkpointConfig[#checkpointConfig] then
    cpInstance:trigger()
  else
    completeLap()
  end

  local isCurrSplit = cpInstance:isAlternativeCheckpoint()

  lastIndexes.i = currentIndexes.i
  lastIndexes.j = currentIndexes.j
  lastIndexes.k = currentIndexes.k

  if not isCurrSplit then
    currentIndexes.i = currentIndexes.i + 1

    --Coming out or not being involved in split-routes ignore the secondary and tertiary indexes
    currentIndexes.j, currentIndexes.k = nil, nil
  else
    --This is the first split route checkpoint in this section
    if not currentIndexes.j or not currentIndexes.k then
      --Just entered the next section
      currentIndexes.i = currentIndexes.i + 1
      currentIndexes.j = indexJ
      currentIndexes.k = 1

      --Add the extra checkpoints to the total number, since split routes (provisionly)
      --count as 1 checkpoint
      totalCheckpointNum = totalCheckpointNum + (#checkpointConfig[currentIndexes.i][indexJ]-1)

      local otherRouteFirstCpName = checkpointConfig[currentIndexes.i][indexJ == 1 and 2 or 1][1]
      changeState(otherRouteFirstCpName, "inactive")
    else
      currentIndexes.k = currentIndexes.k + 1
    end
  end

  local nextChoices = getNextSection()
  --If there are multiple next checkpoints
  if type(nextChoices) == "table" then
    --The first checkpoint for each section is inside their own table
    toChangeState = {nextChoices[1][1], nextChoices[2][1]}
  else
    toChangeState[1] = nextChoices
  end

  for _, v in ipairs(toChangeState) do
    --Split routes have checkpoints separated in their own tables
    if type(v) == "table" then
      for _, v2 in ipairs(v) do
        changeState(v2, "next")
      end
    else
      changeState(v, "next")
    end
  end

  guihooks.trigger("WayPoint", "Checkpoint "..currentCheckpointNum.." / "..totalCheckpointNum)

  --Only applies to lapped circuits
  if totalLaps > 1 then
    --If there is more than one lap, change the previous checkpoint to inactive again
    local prevInstance = checkpoints[getLastCheckpoint()]
    if currentLap ~= totalLaps and not prevInstance:isEndCheckpoint() then
      prevInstance:setState("inactive")
    end
  end
end

local function resetToCheckpoint(vehicle)
  --[[
  Resets the player back to the last checkpoint passed
  If the player has not reached the first checkpoint, it resets them to the start
  Parameters:
    vehicle - the vehicle obj to reset
  ]]--
  errorHandler.assertNil(vehicle)

  resets = resets + 1

  local checkpoint = getCurrentCheckpoint()

  shortcutHandler.resetKeysAfterReset(tonumber(checkpoint:match("%d+")), currentLap)

  local checkpointObj = checkpoints[checkpoint]
  local position = checkpointObj:getPosition()
  local vehRot = ClassCheckpoint.convertDirToRot(checkpointObj)

  local vehName = vehicle:getName()

  TorqueScript.eval(vehName..'.position = "'..position:getX()..' '..position:getY()..' '..position:getZ()..'";')
  TorqueScript.eval(vehName..'.rotation = "'..vehRot.x..' '..vehRot.y..' '..vehRot.z..' '..vehRot.w..'";')

  --Fix vehicle and reset its physics
  local vehObj = vehicle:getObj()
  vehObj:requestReset(RESET_PHYSICS)
  vehObj:resetBrokenFlexMesh()
end

local function setupCheckpointConfig()
  --[[
  Creates the checkpoint configuration
  NOTES:
    -For the algorithm to work, the split routes MUST be in order of pathID,
    otherwise it will not setup properly
    ie. cp12, cp13 should have pathIDs 1, 2 respectively
    -Also, split routes cannot end the scenario (only one finish checkpoint)
  Returns:
    cpConfig - the checkpoint configuration for the scenario
  ]]--
  local cpConfig = {}

  local index = 1
  --Creates a lap config for a single lap
  for i = 1, tableComp.lengthOfTable(checkpoints)-1 do
    local instance = checkpoints["checkpoint"..i]
    local name = checkpoints["checkpoint"..i]:getName()

    if instance:isAlternativeCheckpoint() then
      local splitId = instance:getPathID()

      --If a table has not been setup for a split route
      if not cpConfig[index] then
        table.insert(cpConfig, {})
      end

      --If the split route table has not been setup
      if not cpConfig[index][splitId] then
        table.insert(cpConfig[index], {name})
      else
        table.insert(cpConfig[index][splitId], name)
      end
    else
      --If the last index was a split route, add one to show that this cp is not part of the split route
      if type(cpConfig[index]) == "table" then
        index = index + 1
      end

      table.insert(cpConfig, name)
      index = index + 1
    end
  end

  if totalLaps > 1 then
    --Add in the last checkpoint (which will be the first again) for that lap
    table.insert(cpConfig, "checkpoint0")
    --Repeat the single lap for the total number of laps
    cpConfig = tableComp.repeatTable(cpConfig, totalLaps)
  end

  cpsToString = function(cps)
    --[[
    Stringifies the checkpoints found, handling split routes
    This function is defined recursively
    Parameters:
      cps - the checkpoints found
    Returns:
      <string> - the string representation of the checkpoints
    ]]--
    errorHandler.assertNil(cps)

    if type(cps) == "table" then
      local route = ""
      for i, v in ipairs(cps) do
        if i == 1 then
          if type(v) == "table" then route = cpsToString(v)
          else route = v
          end
        else route = route..", ".. cpsToString(v)
        end
      end

      return "["..route.."]"
    else
      return cps
    end
  end

  local sCpConfig = ""
  for i, cps in ipairs(cpConfig) do
    if i == 1 then
      sCpConfig = cpsToString(cps)
    else
      sCpConfig = sCpConfig..", ".. cpsToString(cps)
    end
  end
  --print("Checkpoint config: ["..sCpConfig.."]")

  return cpConfig
end

local function findCheckpoints()
  --[[
  Finds all checkpoints in the scenario
  Returns:
    cps - the checkpoints found and their corresponding data
  ]]--
  local cps = {}

  --Checkpoint 0 is the start platform
  local i = 0
  local name = "checkpoint"..i
  local obj = scenetree.findObject(name)

  while obj do
    local state = i == 1 and "next" or "inactive"

    local rot = obj:getRotation()
    rot = quat(rot.x, rot.y, rot.z, rot.w)
    rot = rot:toTorqueQuat()

    cps[name] = ClassCheckpoint.new(obj:getPosition(), rot, obj.scale, obj.direction, i, state, i == 0, obj.pathID, obj.closeOn)

    i = i + 1
    name = "checkpoint"..i
    obj = scenetree.findObject(name)
  end

  --The last checkpoint is the ending one (only applies to p-to-p races)
  if totalLaps == 1 and cps["checkpoint"..(i-1)] then
    --i-1 since the while loop has not found i=i+1
    cps["checkpoint"..(i-1)]:setEndCheckpoint(true)
  end

  return cps
end

local function getCurrentLap()
  return currentLap
end

local function findNextCheckpoints()
  --[[
  Finds a list of next checkpoints to check for
  ]]--
  local nextCheckpoints = getNextSection()

  --Should only ever be true when finishing a scenario and so no more checkpoints
  if not nextCheckpoints then
    return
  end

  --Handle all sections (including non-split-route checkpoints) as tables
  if type(nextCheckpoints) ~= "table" then
    nextCheckpointInstances = {nextCheckpoints}
  else
    nextCheckpointInstances = nextCheckpoints
  end
end

local function createCheckpoints(fullReset, srcFile)
  --[[
  Finds, creates and sets up checkpoints
  Parameters:
    fullReset - whether thi sis a full reset of the scenario
    srcFile   - the scenario file directory
  ]]--
  errorHandler.assertNil(srcFile)

  currentIndexes = {i = 0, j = nil, k = nil}
  currentCheckpointNum = 0
  currentLap = 0
  resets = 0

  if fullReset then
    sourceFile = srcFile
    totalLaps = jsonDecode(readFile(sourceFile), sourceFile)[1].gr_laps or 1
    checkpoints = findCheckpoints()
    checkpointConfig = setupCheckpointConfig()
    totalCheckpointNum = #checkpointConfig
  else
    local firstSection = checkpointConfig[1]
    local isSplitRoute = type(firstSection) == "table"
    local splitRouteCheckpoints = {firstSection[1] and firstSection[1][1] or "nil", firstSection[2] and firstSection[2][1] or "nil"}

    --Reset checkpoints
    for _, instance in pairs(checkpoints) do
      --The first section is a split-route, so two checkpoints need to be in the next state
      if instance:getNumber() == 1 or (isSplitRoute and (instance:getName() == splitRouteCheckpoints[1] or instance:getName() == splitRouteCheckpoints[2])) then
        instance:setState("next")
      else
        instance:reset()
      end
    end
  end

  finished = false

  findNextCheckpoints()

  local scenarioName = scenarioDetails.getScenarioDetails(sourceFile)
  --Let the file know it has been tried
  fileHandler.saveToFile("scenario", {scenarioName = scenarioName, scenarioData = {tried = true}})

  --Reset UIs
  if totalLaps > 1 then
    guihooks.trigger('RaceLapChange', {current = 1, count = totalLaps})
  end

  guihooks.trigger('WayPoint', 'Checkpoint 0 / '..totalCheckpointNum)
end

local function update(running, vehicle, dt)
  --[[
  Checks to see if the player has activated the next checkpoint and update the shortcut handler
  Parameters:
    running - whether the scenario is running
    vehicle - the vehicle instance to use for triggering checkpoints
    dt      - the time since the last frame
  ]]--
  errorHandler.assertNil(vehicle, dt)

  if finished then return end

  local currentCheckpoint = getCurrentCheckpoint()
  if currentCheckpoint then
    shortcutHandler.update(vehicle, dt, tonumber(currentCheckpoint:match("%d+")), currentLap)
  end

  if running then
    --Get the value of the horn
    vehicle:getObj():queueLuaCommand("obj:queueGameEngineLua('hornVal = '..tostring(electrics.values.horn)..'')")

    if not vehicle:isResetting() and hornVal == 1 then
      vehicle:scheduleReset()
    end

    local trigger = function(cpName)
      --[[
      Triggers a checkpoint if close enough
      ]]--
      local instance = checkpoints[cpName]
      local distance = vehicle:getPosition():getDistanceBetween(instance:getPosition())

      if distance < instance:getTriggerRadius() then
        triggerCheckpoint(instance:getNumber())
      end
    end

    for _, v in ipairs(nextCheckpointInstances) do
      local reachedNextCp = false
      --Split routes are in separated tables inside this table
      if type(v) == "table" then
        for _, v2 in ipairs(v) do
          trigger(v2)
          reachedNextCp = true
        end
      else
        trigger(v)
        reachedNextCp = true
      end

      if reachedNextCp then
        findNextCheckpoints()
      end
    end
  end
end

local function isInScenario()
  return sourceFile ~= nil
end

local function isFinished()
  return finished
end

local function setSrcFile(srcFile)
  errorHandler.assertNil(srcFile)
  sourceFile = srcFile
end

local function printResults()
  --[[
  A testing function for printing the checkpoints found
  ]]--
  print("\nCheckpoints Found:\n")
  for _, instance in pairs(checkpoints) do
    local rot = instance:getRotation()
    print(instance:getName()..": [Pos = ("..instance:getPosition():toString().."), Dir = "..(instance:getDirection() or "nil")..", Rot = {"..rot.x..", "..rot.y..", "..rot.z..", "..rot.w.."},  IsEndCheckpoint="..tostring(instance:isEndCheckpoint())..", IsSplitCheckpoint="..tostring(instance:isAlternativeCheckpoint()).."]")
  end
end

local function onRaceStart()
  shortcutHandler.initCollectables()
end

M.getCurrentCheckpoint = getCurrentCheckpoint
M.resetToCheckpoint = resetToCheckpoint
M.getCurrentLap = getCurrentLap
M.createCheckpoints = createCheckpoints
M.update = update
M.isInScenario = isInScenario
M.isFinished = isFinished
M.setSrcFile = setSrcFile
M.printResults = printResults
M.onRaceStart = onRaceStart
return M
