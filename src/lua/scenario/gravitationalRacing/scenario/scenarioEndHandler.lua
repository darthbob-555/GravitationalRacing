local M = {}

local fileHandler             = require("scenario/gravitationalRacing/utils/fileHandler")
local shortcutHandler         = require("scenario/gravitationalRacing/scenario/track/shortcutHandler")
local tableComp               = require("scenario/gravitationalRacing/utils/tableComprehension")
local championshipHandler     = require("scenario/gravitationalRacing/scenario/championship/championshipHandler")
local scenarioDetailsHandler  = require("scenario/gravitationalRacing/scenario/scenarioDetails")
local errorHandler            = require("scenario/gravitationalRacing/utils/errorHandler")

local function getUnlocksFromMedals(mapData)
  --[[
  Gets the unlocks from having x amount of medals
  Parameters:
    mapData - the map of unlocks gotten from the trackRequirementMap.json file
  Returns:
    <table> - the now unlocked scenarios
  ]]--
  errorHandler.assertNil(mapData)

  local unlocks = {}
  local medals = fileHandler.getNumberOfMedals()

  for scName, data in pairs(mapData) do
    if data.price and data.price <= medals then
      table.insert(unlocks, scName)
    end
  end

  return unlocks
end

local function processUnlocks(scenarioName)
  --[[
  Finds which scenarios are now unlocked and returns them formatted for the UI
  Parameters:
    scenarioName - the name of the scenario
  Returns:
    unlocksFormatted - a table of unlocks with their details
  ]]--
  errorHandler.assertNil(scenarioName)

  local mapData = jsonDecode(readFile("lua/scenario/gravitationalRacing/dataValues/trackRequirementMap.json"))
  --Unlocks from completing the scenario
  local unlocks = mapData[scenarioName].unlocks
  local medalUnlocks = getUnlocksFromMedals(mapData)

  local unlocksFormatted = {}
  for _, scName in ipairs(tableComp.mergeAppend(unlocks, medalUnlocks)) do
    local alreadyUnlocked = fileHandler.readFromFile(scName, "unlocked")

    if not alreadyUnlocked then
      local difficulty = ""

      for _, map in ipairs(scenarioDetailsHandler.getVanillaMaps()) do
        local formattedScName = scName:gsub(" ", "_"):lower()

        local fileDirectory = formattedScName == "solar_system_simulation"
                              and "levels/"..map.."/scenarios/gravitationalRacing/"..formattedScName..".json"
                              or  "levels/"..map.."/scenarios/gravitationalRacing/tracks/"..formattedScName..".json"

        local file = readFile(fileDirectory)
        if file then
          difficulty = jsonDecode(file)[1].name:match("%((%a+)%)")
          break
        end
      end

      table.insert(unlocksFormatted, {name = scName, difficulty = difficulty, colour = scenarioDetailsHandler.difficultyToColour(difficulty)})

      --Update the savefile to let it know this track has been unlocked
      fileHandler.saveToFile("scenario", {scenarioName = scName, scenarioData = {unlocked = true}})
    end
  end

  return unlocksFormatted
end

local function finish(resets, sourceFile)
  --[[
  Finishes the scenario
  Parameters:
    resets     - the number of resets the player finished the scenario with
    sourceFile - the file directory of the scenario
  ]]--
  errorHandler.assertNil(resets, sourceFile)

  local scenarioName, scenarioDifficulty = scenarioDetailsHandler.getScenarioDetails(sourceFile)

  local targetData = jsonDecode(readFile("lua/scenario/gravitationalRacing/dataValues/targetData.json"))[scenarioName]

  --Timer is in seconds, so convert to ms
  local time = scenario_scenarios.getScenario().timer*1000

  if scenarioName == "Tutorial" then
    fileHandler.saveToFile("scenario", {scenarioName = scenarioName, scenarioData = {tried = true, completed = true}}, false)

    --No need to store the result as the scenario will not be showing the UI
    processUnlocks(scenarioName)

    --Skip end screen and load back into hub-world
    scenario_scenariosLoader.start(scenario_scenariosLoader.loadScenario("levels/smallgrid/scenarios/gravitationalRacing/hubworld.json", nil, "levels/smallgrid/scenarios/gravitationalRacing/hubworld.json"))
    return
  end

  local targetTime = scenarioDetailsHandler.stringToMilliSecs(targetData.time)
  local bestTime = scenarioDetailsHandler.stringToMilliSecs(fileHandler.readFromFile(scenarioName, "time"))

  local targetResets = targetData.resets
  local bestResets = fileHandler.readFromFile(scenarioName, "resets")

  local collectedCollectables = shortcutHandler.hasCollectedCollectables()

  local medalsGottenAlready = fileHandler.readFromFile(scenarioName, "medals")

  --Update savefile for this scenario
  fileHandler.saveToFile("scenario", {
    scenarioName = scenarioName,
    scenarioData = {
      tried = true,
      completed = true,
      resets = resets,
      time = scenarioDetailsHandler.timeToString(time),
      medals = {
        time = time <= targetTime,
        resets = resets <= targetResets
      },
      collectables = collectedCollectables
    }
  }, false)

  local unlocksFormatted = processUnlocks(scenarioName)

  --Accumulate the data for the UI
  local scData = {
    scenarioName = scenarioName:upper(),
    difficulty = {
      type = scenarioDifficulty:upper(),
      colour = scenarioDetailsHandler.difficultyToColour(scenarioDifficulty)
    },
    times = {
      set             = time,
      best            = bestTime,
      target          = targetTime,
      targetFormatted = targetData.time
    },
    resets = {
      set    = resets,
      best   = bestResets,
      target = targetResets
    },
    unlocks = unlocksFormatted,
    medalsGottenAlready = medalsGottenAlready
  }

  scenario_scenarios.stopRaceTimer()
  bullettime.set(1/8)

  -- --Check that there is a current championship (check for non-empty - len of 0)
  -- if #fileHandler.readSectionFromFile("championships").current > 0 then
  --   championshipHandler.finishEvent(scData)
  --   return
  -- end

  guihooks.trigger("gravitationalRacingScenarioEndScreen", scData)
end

M.finish = finish
return M
