local M = {}

local fileHandler     = require("scenario/gravitationalRacing/utils/fileHandler")
local tableComp       = require("scenario/gravitationalRacing/utils/tableComprehension")
local scenarioDetails = require("scenario/gravitationalRacing/scenario/scenarioDetails")

--The best possible result for an AI is _% of base
local BEST_MULTI = 100
--The worst possible result for an AI is _% of base
local WORST_MULTI = 150

local AI_PERSONALITIES = {
  {name = "", skillLevel = 1},
  {name = "the legendary bob", skillLevel = 2},
  {name = ""  , skillLevel = 3},
  {name = "infinite"    , skillLevel = 4}
}

local drivers = {"player"}
for _, data in ipairs(AI_PERSONALITIES) do
  table.insert(drivers, data.name)
end

local showingEndscreen = false
local isSkipping = false
local filePath = ""

local function getAiSkillLevel(aiName)
  --[[
  Returns the skill level for an ai
  ]]--
  for _, data in ipairs(AI_PERSONALITIES) do
    if data.name == aiName then
      return data.skillLevel
    end
  end
end

local function simulateAiFinish(baseValue, aiName)
  --[[
  "Simulates" the AI to produce their results from the scenario
  The result is based on a percentage of the baseValue being compared (such as time)
  and the difficulty increases their chance to have a better time, though not guranteed
  Same goes with skill level
  ]]--
  local baseBound = BEST_MULTI
  return baseValue * (math.random(baseBound, baseBound + WORST_MULTI / getAiSkillLevel(aiName)) / 100)
end

local function trophyRankToName(rank)
  --[[
  Converts a trophy rank number to the trophy name
  ]]--
  if     rank == 0 then return "none"
  elseif rank == 1 then return "bronze"
  elseif rank == 2 then return "silver"
  elseif rank == 3 then return "gold"
  elseif rank == 4 then return "diamond"
  end

  log("E", "trophyRankToName()", "No trophy name exists for rank "..(rank or "nil"))
end

local function positionToTrophy(pos, whiteWash)
  --[[
  Converts a position to a trophy rank and name
  ]]--
  if     pos == 1 then
    if whiteWash then  return 4
    else               return 3
    end
  elseif pos == 2 then return 2
  elseif pos == 3 then return 1
  else                 return 0
  end
end

local function finishChampionship(championshipName, finalStandings, numberOfScenarios)
  --[[
  Finishes the whole championship
  Returns whether one driver won all races
  ]]--
  local playerPos
  local whiteWash, playeWhiteWash = false, false

  for i, data in ipairs(finalStandings) do
    local isPlayer = data.driver:lower() == "player"

    if i == 1 then
      --If the person in first has won all the rounds
      whiteWash = data.roundWins == numberOfScenarios
      playeWhiteWash = isPlayer and whiteWash
    end

    if isPlayer then
      playerPos = i
      break
    end
  end

  local champData = {
    current = "",
    engaged = false,
    completed = true,
    trophy = positionToTrophy(playerPos, playeWhiteWash),
    currentData = {
      standings = fileHandler.getDefaultChampionshipData().currentData.standings,
      currentScenario = 1
    }
  }

  fileHandler.saveToFile("championship", {champName = championshipName, champData = champData}, false)

  return whiteWash
end

local function extractTotal(standings)
  --[[
  Removes all but the total key from a standings table
  ]]--
  local newStandings = tableComp.merge({}, standings)
  for i, data in ipairs(standings) do
    newStandings[i] = {}
    for k, v in pairs(data) do
      if k == "total" then
        newStandings[i][k] = v
      end
    end
  end

  return newStandings
end

local function addResultDifferential(standings, scoringType)
  --[[
  Adds in result differential to each driver (leading driver has none)
  ]]--
  local lowestValue = tableComp.getSmallestValue(standings)

  local isScoringTime = scoringType == "times"

  for _, data in ipairs(standings) do
    local value = data.total or data.result
    if type(value) == "string" then
      value = scenarioDetails.stringToMilliSecs(value)
    end

    local dif = value - lowestValue

    if dif == 0 then
      data.dif = "-"
    else
      data.dif = isScoringTime and scenarioDetails.timeToString(dif) or dif
    end
  end

  return standings
end

local function getRoundStandingsFormatted(baseValue, playerResult, scoringType)
  --[[
  Returns the scenario standings
  Table returned is sorted in order of driver position
  ]]--
  local roundStandingsFormatted = {}

  for i, driver in ipairs(drivers) do
    --AI's need to be simulated, player already has their result
    local rawResult = driver ~= "player" and simulateAiFinish(baseValue, driver) or playerResult
    --Same as raw but formatted to be pretty (only for time currently)
    local result = scoringType == "times" and scenarioDetails.timeToString(rawResult) or rawResult

    roundStandingsFormatted[i] = {
      driver = driver,
      --Accurate to 1ms, same as UI
      rawResult = math.floor(rawResult),
      result = result
    }
  end

  --Order drivers by result (worst to best)
  table.sort(roundStandingsFormatted, function(a, b) return a.result < b.result end)

  return roundStandingsFormatted
end

local function getPreviousStandingsFormatted(currentStandings, scoringType)
  --[[
  Returns the current standings before this scenario is added,
  sorted by lowest to highest value
  ]]--
  local previousStandingsFormatted = {}

  for driver, data in pairs(currentStandings) do
    local driverTotal = data.total
    table.insert(previousStandingsFormatted, {
      driver = driver:upper(),
      rawTotal = driverTotal,
      total = scoringType == "times" and scenarioDetails.timeToString(driverTotal) or driverTotal
    })
  end

  table.sort(previousStandingsFormatted, function(a, b) return a.rawTotal < b.rawTotal end)

  return previousStandingsFormatted
end

local function addToCurrentStandings(currentStandings, roundStandingsFormatted)
  --[[
  Adds a set of results to the current standings
  ]]--
  for i, data in ipairs(roundStandingsFormatted) do
    local currentData = currentStandings[data.driver]
    currentStandings[data.driver] = {
      total = currentData.total + data.rawResult,
      --Only add if they are first
      roundWins = currentData.roundWins + (i == 1 and 1 or 0),
    }
  end

  return currentStandings
end

local function formatNewStandings(previousStandingsFormatted, newStandings, currentStandings, scoringType)
  --[[
  Returns a formatted version of the new standings
  The order is the same as previous standings for the UI to do the re-ordering later
  ]]--
  local newStandings = {}
  local driverOrder = {}

  for i, data in ipairs(previousStandingsFormatted) do
    driverOrder[i] = data.driver:lower()
  end

  for i, driver in ipairs(driverOrder) do
    local driverData = currentStandings[driver]
    local driverTotal = driverData.total

    newStandings[i] = {
      driver = driver:upper(),
      total = driverTotal,
      roundWins = driverData.roundWins
    }
  end

  return newStandings
end

local function isSmallerTotal(a, b)
  a, b = a.total, b.total

  if type(a) == "string" then
    a, b = scenarioDetails.stringToMilliSecs(a), scenarioDetails.stringToMilliSecs(b)
  end

  return a < b
end

local function finishEvent(scData)
  --[[
  Finishes a championship event by simulating data and senting the end screen
  ]]--
  local championshipName = fileHandler.readSectionFromFile("championships").current
  local champData = jsonDecode(readFile("lua/scenario/gravitationalRacing/dataValues/championshipConfigs.json"))[championshipName]
  local scoringType = champData.scoringType
  local config = champData.config

  local currentData = fileHandler.readSectionFromFile("championships")[championshipName].currentData
  local currentStandings = currentData.standings

  local roundStandingsFormatted    = getRoundStandingsFormatted(scData[scoringType].target, scData[scoringType].set, scoringType)
  local previousStandingsFormatted = getPreviousStandingsFormatted(currentStandings, scoringType)
  local newStandings               = addToCurrentStandings(currentStandings, roundStandingsFormatted)
  local newStandingsIndexed        = formatNewStandings(previousStandingsFormatted, newStandings, currentStandings, scoringType)

  roundStandingsFormatted    = addResultDifferential(roundStandingsFormatted   , scoringType)
  previousStandingsFormatted = addResultDifferential(previousStandingsFormatted, scoringType)
  --Removes the wins key as this will mess up the lowest score from getSmallestValue()
  local newStandingsFormatted      = addResultDifferential(tableComp.removeKey(deepcopy(newStandingsIndexed), "roundWins"), scoringType)

  local newStandingsOrdered = tableComp.merge({}, newStandingsFormatted)
  table.sort(newStandingsOrdered, isSmallerTotal)
  table.sort(newStandingsIndexed, isSmallerTotal)

  --Convert times to string, if necessary
  if scoringType == "times" then
    for _, v in ipairs(newStandingsFormatted) do
      v.total = scenarioDetails.timeToString(v.total)
    end
  end

  local scenarioNum, totalScenarios = currentData.currentScenario, #config

  fileHandler.saveToFile("championship", {champName = championshipName, champData = {currentData = {standings = currentStandings, currentScenario = scenarioNum + 1}}}, false)
  fileHandler.setLastScenario(championshipName)

  --If this scenario is the last, end the championship
  if scenarioNum == totalScenarios then
    scData.champFinished = true
    scData.whiteWash = finishChampionship(championshipName, newStandingsIndexed, totalScenarios)
  else
    local nextScenarioName = config[scenarioNum+1]
    scData.nextScenario = {
      filePath = scenarioDetails.getSourcePath(nextScenarioName:lower():gsub(" ", "_")),
      name = nextScenarioName
    }

    --Self referential, so must happen outside the table declaration
    local _, dif = scenarioDetails.getScenarioDetails(scData.nextScenario.filePath)
    scData.nextScenario.colour = scenarioDetails.difficultyToColour(dif)
  end

  scData.champScoringType = scoringType
  scData.roundStandings = roundStandingsFormatted
  scData.newStandings = newStandingsFormatted
  scData.previousStandings = previousStandingsFormatted
  scData.newStandingsOrdered = newStandingsOrdered
  scData.champName = championshipName.." ["..scenarioNum.."/"..totalScenarios.."] "

  guihooks.trigger("gravitationalRacingScenarioEndScreen", scData)

  showingEndscreen = true
end

local function skip()
  --[[
  Skips this event and moves to the next
  ]]--
  local championshipName = fileHandler.readSectionFromFile("championships").current
  local champData = jsonDecode(readFile("lua/scenario/gravitationalRacing/dataValues/championshipConfigs.json"))[championshipName]
  local config = champData.config

  local currentData = fileHandler.readSectionFromFile("championships")[championshipName].currentData
  local currentScenario = currentData.currentScenario

  local next = currentScenario + 1

  if next <= #config then
    local nextScenarioName = config[next]
    filePath = scenarioDetails.getSourcePath(nextScenarioName:lower():gsub(" ", "_"))
  else
    filePath = "levels/smallgrid/scenarios/gravitationalRacing/hubWorld.json"
  end

  isSkipping = true
end

local function isShowingEndscreen()
  return showingEndscreen
end

local function isSkippingEvent()
  return isSkipping
end

local function getAllChampionships()
  --[[
  Returns all championships
  ]]--
  local championships = {}
  local champs = jsonDecode(readFile("lua/scenario/gravitationalRacing/dataValues/championshipConfigs.json"))

  for champName, _ in pairs(champs) do
    table.insert(championships, champName)
  end

  return championships
end

local function onScenarioChange(sc)
  if sc and sc.state == "pre-running" then
    if isSkipping and filePath ~= "" then
      scenario_scenariosLoader.start(scenario_scenariosLoader.loadScenario(filePath, nil, filePath))
      isSkipping = false
      showingEndscreen = false
      filePath = ""
    end
  end
end

M.trophyRankToName = trophyRankToName
M.finishEvent = finishEvent
M.skip = skip
M.isShowingEndscreen = isShowingEndscreen
M.isSkippingEvent = isSkippingEvent
M.getAllChampionships = getAllChampionships
M.onScenarioChange = onScenarioChange
return M
