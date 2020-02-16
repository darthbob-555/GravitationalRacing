local M = {}

local errorHandler = require("scenario/gravitationalRacing/utils/errorHandler")

local vanillaMaps = {
	"automation_test_track",
	"Cliff",
	"driver_training",
	"east_coast_usa",
	"glow_city",
	"GridMap",
	"hirochi_raceway",
	"industrial",
	"italy",
	"jungle_rock_island",
	"port",
	"smallgrid",
	"small_island",
	"Utah",
	"west_coast_usa"
}

local function getSourcePath(scenarioName)
  --[[
  Gets the file path for a scenario
  Parameters:
    scenarioName - the name of the scenario
  Returns:
    <string> - the file directory of the scenario
  ]]--
  errorHandler.assertNil(scenarioName)

  for _, map in ipairs(vanillaMaps) do
    if scenarioName == "solar_system_simulation" then
      return "levels/smallgrid/scenarios/gravitationalRacing/"..scenarioName..".json"
    end

    local fileDirectory = "levels/"..map.."/scenarios/gravitationalRacing/tracks/"..scenarioName..".json"

    if readFile(fileDirectory) then
      return fileDirectory
    end
  end

  log("E", "getSourcePath()", "Cannot find "..(scenarioName or "nil").." as a source file!")
end

local function getVanillaMaps()
  return vanillaMaps
end

local function difficultyToColourRGBA(difficulty)
  --[[
  Gets the difficulty colour (rgba)
  Parameters:
    difficulty - the difficult level
  Returns:
    <string> - the RGBA colour
  ]]--
  errorHandler.assertNil(difficulty)

  difficulty = difficulty:lower()
  if difficulty == "basic" then
    return "0 1 0 1"
  elseif difficulty == "advanced" then
    return "1 1 0 1"
  elseif difficulty == "expert" then
    return "1 0 0 1"
  elseif difficulty == "insane" then
    return "0.1171875 0.5625 1 1"
  else
    return "1 1 1 1"
  end
end

local function difficultyToColour(difficulty)
  --[[
  Returns the colour of a difficulty
  ]]--
  difficulty = difficulty:upper()

  if difficulty == "TUTORIAL" then
    return "white"
  elseif difficulty == "SIMULATION" then
    return "lightblue"
  elseif difficulty == "BASIC" then
    return "lightgreen"
  elseif difficulty == "ADVANCED" then
    return "gold"
  elseif difficulty == "EXPERT" then
    return "red"
  elseif difficulty == "INSANE" then
    return "dodgerblue"
  end
end

local function stringToSecs(s)
  --[[
  Converts a string to seconds
  Parameters:
    s - the string
  Returns:
    totalSeconds - the number of seconds represented by the string
  ]]--
  errorHandler.assertNil(s)

  local sections = {}
  local i = 1
  for part in string.gmatch(s, "%d+") do
    sections[i] = part
    i = i + 1
  end

  local totalSeconds = sections[1] * 60 + sections[2] + sections[3]/1000
  return totalSeconds
end

local function stringToMilliSecs(s)
  --[[
  Converts a string to milliseconds
  Parameters:
    s - the string
  Returns:
    <number> - the string converted to milliseconds
  ]]--
   errorHandler.assertNil(s)
  return stringToSecs(s) * 1000
end

local function timeToString(t)
  --[[
  Converts a time (in ms) to a string of format minutes:seconds.milliseconds
  t must be in the format of seconds.milliseconds (scenario timer standard)
  Parameters:
    t - the time to convert
  Returns:
    <string> - the string version
  ]]--
  errorHandler.assertNil(t)

  local format = function(value, numDigits)
    --[[
    Adds extra zeros onto the front of a number until it is n digits long
    ]]--
    local strVal = tostring(value)
    local digits = #strVal

    if digits < numDigits then
      for i = digits, numDigits-1 do
        strVal = "0"..strVal
      end
    elseif digits > numDigits then
      return math.floor(value * 10^numDigits) / 10^numDigits
    end

    return strVal
  end

  local minutes      = format(math.floor(((t / (1000*60)))), 2)
  local seconds      = format(math.floor(t/1000) % 60, 2)
  local milliseconds = format(math.floor(t - minutes*1000*60 - seconds*1000), 3)

  return minutes..":"..seconds.."."..milliseconds
end

local function fasterTime(t1, t2)
    --[[
    Returns the faster time of two string formatted times
    Parameters:
        t1 - the first time
        t2 - the second time
    Returns:
        <string> - the faster time of t1 and t2
    ]]--
    --Check for unspecified times
    if t1 == nil then return t2 end
    if t2 == nil then return t1 end
    --Check for non-set times (if they are the same then it doesn't matter which it returns)
    if t1 == "0:00.000" then return t2 end
    if t2 == "0:00.000" then return t1 end

    local t1Secs, t2Secs = stringToSecs(t1), stringToSecs(t2)

    return t1Secs < t2Secs and t1 or t2
end

local function fasterTimeBool(t1, t2)
  --[[
  Returns whether t1 is a faster time than t2
  Parameters:
    t1 - the first time
    t2 - the second time
  Returns:
    <boolean> - whether t1 is faster than t2
  ]]--
  return fasterTime(t1, t2) == t1
end

local function getScenarioDetails(sourceFile)
  --[[
  Returns the title and difficulty of the scenario
  Parameters:
    sourceFile - the file directory of the scenario
  Returns:
    scenarioName       - the name of the scenario
    scenarioDifficulty - the difficulty of the scenario
  ]]--
  errorHandler.assertNil(sourceFile)

  local scenarioTitle = jsonDecode(readFile(sourceFile), sourceFile)[1].name
  --Matches the first part of the title
  local scenarioName = scenarioTitle:match("[%a%s']*")
  --Remove space at the end of the name and the start of the difficulty
  scenarioName = scenarioName:sub(1, #scenarioName-1)
  --Matches the seconds part in the brackets
  local scenarioDifficulty = scenarioTitle:match("%((%a+)%)")

  return scenarioName, scenarioDifficulty
end

local function getSpecificDetail(attribute, sourceFile)
  --[[
  Returns a specific attribute of a scenario
  Parameters:
    attribute  - the attribute
    sourceFile - the file directory of the scenario
  Returns:
    <?> - the attribute value
  ]]--
  errorHandler.assertNil(attribute, sourceFile)
  return jsonDecode(readFile(sourceFile), sourceFile)[1][attribute]
end

local function getScenariosSortedByDif()
	--[[
	Returns:
	    scenarios - all scenarios present, ordered into a table by difficulty
	]]--
	local scenarios = {basic = {}, advanced = {}, expert = {}, insane = {}, tutorial = {}}

	for _, map in ipairs(vanillaMaps) do
		local path = "/levels/"..map.."/scenarios/gravitationalRacing/tracks"
		local files = FS:findFilesByPattern(path, "*.json", 1, true, false)

		for _, fileName in ipairs(files) do
			local scName, scDif = getScenarioDetails(fileName)
			table.insert(scenarios[scDif:lower()], scName)
		end
	end

	return scenarios
end

M.getSourcePath = getSourcePath
M.getVanillaMaps = getVanillaMaps
M.difficultyToColourRGBA = difficultyToColourRGBA
M.difficultyToColour = difficultyToColour
M.stringToSecs = stringToSecs
M.stringToMilliSecs = stringToMilliSecs
M.timeToString = timeToString
M.fasterTime = fasterTime
M.fasterTimeBool = fasterTimeBool
M.getScenarioDetails = getScenarioDetails
M.getSpecificDetail = getSpecificDetail
M.getScenariosSortedByDif = getScenariosSortedByDif
return M
