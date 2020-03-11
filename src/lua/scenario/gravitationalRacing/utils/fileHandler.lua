local M = {}
local tableComp       = require("scenario/gravitationalRacing/utils/tableComprehension")
local errorHandler    = require("scenario/gravitationalRacing/utils/errorHandler")
local scenarioDetails = require("scenario/gravitationalRacing/scenario/scenarioDetails")

local function getDefaultTrackData()
	--[[
	Returns:
	 	<table> - the default data for a new track that has not been unlocked
	]]--
	return {
		unlocked = false,
		tried = false,
		completed = false,
		resets = -1,
		time = "0:00.000",
		medals = {
			time = false,
			resets = false
		},
		collectables = {
			false
		}
	}
end

local function getDefaultStandings()
	--[[
	Returns:
	 	<table> - a blank set of standings for all drivers
	]]--
	local drivers = {"player", "nu scorpii", "the legendary bob", "xi tauri", "infinite"}
	local standings = {}
	for i = 1, 5 do
		standings[drivers[i]] = {roundWins = 0, total = 0}
	end

	return standings
end

local function getDefaultChampionshipData()
	--[[
	Returns:
	 	<table> - the default data for a new championship that has not been unlocked
	]]--
	return {
		unlocked = false,
		engaged = false,
		completed = false,
		trophy = 0,
		currentData = {
			standings = getDefaultStandings(),
			currentScenario = 1
		}
	}
end

local function getDefaultChampionshipsData()
	--[[
	Returns:
		<table> - the default data for the championships
	]]--
	local championships = {current = ""}
	for champName, _ in pairs(jsonDecode(readFile("lua/scenario/gravitationalRacing/dataValues/championshipConfigs.json"))) do
		championships[champName] = getDefaultChampionshipData()
	end

	return championships
end

local function createNewSaveFile()
	--[[
	Creates a blank new save file
	]]--
	local content = {
		championships = {},
		scenarios = {["Solar System Simulation"] = {unlocked = false}}
	}

	local fileDirectory = "/levels/smallgrid/scenarios/gravitationalRacing/tracks/"
	local files = FS:findFilesByPattern(fileDirectory, "*.json", 1, true, false)

	for _, fileName in pairs(files) do
		local scenarioName, _ = scenarioDetails.getScenarioDetails(fileName)
		if scenarioName == "Tutorial" then
			content.scenarios[scenarioName] = {
				unlocked = true,
				tried = false,
				completed = false
			}
		else
			content.scenarios[scenarioName] = getDefaultTrackData()
		end
	end

	-- content.championships = getDefaultChampionshipsData()

	serializeJsonToFile("gr_savefile", content, true)
end

local function checkFileExists()
	--[[
	Checks to see if it can open the savefile. If it can then also return the file
	so any function calling this doesn't have to open the file again - efficiency
	Returns:
		<boolean> - whether the file exists
		file      - the file object
	]]--
	local file = readFile("gr_savefile")
	if file then
		return true, file
	else
		return false
	end
end

local function readWholeFile()
	--[[
	Checks the file exists and it up to date, and then reads the file
	Returns:
		<table> - contents of the file
	]]--
	local fileExists, file = checkFileExists()
	if not fileExists then
		createNewSaveFile()
		--Update the file variable with newly created info
		_, file = checkFileExists()
	end

	return jsonDecode(file, "gr_savefile")
end

local function readSectionFromFile(section)
	--[[
	Gets an entire section of the save file such as scenarios
	Parameters:
		section - the section of the savefile to read from
	Returns:
		<table> - the section of the table from the savefile
	]]--
	if section then
		return readWholeFile()[section] or error("Section = ["..tostring(section).."] does not exist in savefile")
	end
end

local function readFromFile(scName, attribute)
	--[[
	Returns data from the save file
	If the attribute parameter is not given, this functions returns the whole scenario
	data for that scName
	Else, returns a specific attribute
	Parameters:
		scName    - the name of the scenario
		attribute - the attribute to read (can be nil)
	Returns:
		? - the contents of file that matches the requirements

	TODO work out a "path" like system for nested table keys - such as {a = {b = {c = {}}}}
	]]--
	errorHandler.assertNil(scName)

	if scName == "Tutorial" then
		return
	end

	local fileContents = readWholeFile().scenarios[scName]

	if not attribute then
		return fileContents
	else
		local contents = fileContents[attribute]
		errorHandler.assertNil(contents)

		return contents
	end
end

local function getNumberOfMedals()
	--[[
	Returns:
	 	<number> - the number of medals + collectables achieved
	]]--
	local contents = readWholeFile().scenarios
	local numMedals = 0
	for _, scData in pairs(contents) do
		--Some scenarios do not have medals
		if scData.medals then
			for _, medalAchieved in pairs(scData.medals) do
				if medalAchieved then
					numMedals = numMedals + 1
				end
			end
		end

		if scData.collectables then
			if scData.collectables[1] then
				numMedals = numMedals + 1
			end
		end
	end

	return numMedals
end

local function saveToFile(type, data, forceOverwrite)
	--[[
	Saves data to the savefile
	forceOverwrite is an optional parameter and will force the update on the savefile,
	irregardless of whether it is better than previous
	Parameters:
		type           - the type of data to store
		data           - the data to store
		forceOverwrite - whether to overwrite existing data
	]]--
	errorHandler.assertNil(type, data)
	errorHandler.assertValidElement(type, {"scenario", "lastScenario", "championship"}, type.." is not valid to be saved")

	local betterBool = function(curr, new, best)
		--[[
		Returns the best boolean value, with respect to what is considered the
		best (true or false)
		Note: if new is nil, returns curr
		Parameters:
			curr - the current value
			new  - the new value (can be nil)
			best - what is considered better
		Returns:
			? - the better value
		]]--
		errorHandler.assertNil(curr)

		if new == nil then return curr end

		if     curr == best then return curr
		elseif new  == best then return new
		--Both new and curr are the same
		else                     return curr
		end
	end

	local smallestSetValue = function(curr, new)
		--[[
		Returns the smallest (number) set value
		Parameters:
			curr - the current value
			new  - the new value (can be nil)
		Returns:
			<number> - the smallest value that is not nil
		]]--
		errorHandler.assertNil(curr)

		if     new == nil then return curr
		elseif curr == -1 then return new
		end

		if     curr > new then return new
		elseif curr < new then return curr
		--Both new and curr are the same
		else             	   return new
		end
	end

	local largestSetValue = function(curr, new)
		--[[
		Returns the smallest (number) set value
		Parameters:
			curr - the current value
			new  - the new value
		Returns:
			<number> - the largest value that is not nil
		]]--
		if     new == nil then return curr
		elseif curr == -1 then return new
		end

		if     curr < new then return new
		elseif curr > new then return curr
		--Both new and curr are the same
		else                	 return new
		end
	end

	local saveFileData = readWholeFile()

	if type == "scenario" then
		local scName, scData = data.scenarioName, data.scenarioData
		errorHandler.assertNil(scName, scData)

		local newData = {}
		if scName == "Tutorial" then
			newData = {
				unlocked = true,
				tried = scData.tried or false,
				completed = scData.completed or false,
			}
		elseif scName == "Solar System Simulation" then
			newData = {
				unlocked = scData.unlocked or false,
			}
		else
			local resets, unlckd, cmpltd, time, tried, clltbls = scData.resets, scData.unlocked, scData.completed, scData.time, scData.tried, scData.collectables
			local medals = scData.medals

			--Apply new data, even if the new data is worst than the old
			if forceOverwrite then
				newData = {
					resets     = resets or -1,
					unlocked   = unlckd or false,
					completed  = cmpltd or false,
					tried      = tried  or false,
					time       = time   or "0:00:000",
					medals     = {
						time     = medals.time or false,
						resets   = medals.medals or false
					}
				}

				newData.collectables = {clltbls[1] or false}
			else
				local currentData = saveFileData.scenarios[scName]
				--Hub world will not have current data
				if not currentData then
					return
				end

				newData = {
					resets    = smallestSetValue(currentData.resets, resets),
					unlocked  = betterBool(currentData.unlocked,  unlckd, true),
					completed = betterBool(currentData.completed, cmpltd, true),
					tried     = betterBool(currentData.tried,     tried,  true),
					time      = scenarioDetails.fasterTime(currentData.time, time),
					medals = {
						time   = betterBool(currentData.medals.time,   medals and medals.time   or nil, true),
						resets = betterBool(currentData.medals.resets, medals and medals.resets or nil, true)
					}
				}

				--Not necessary anymore?
				if currentData.collectables then
					newData.collectables = {}
					if not clltbls then
						--No update necessary
						newData.collectables = currentData.collectables
					else
						for i, v in ipairs(clltbls) do
							newData.collectables[i] = betterBool(currentData.collectables[i], v, true)
						end
					end
				end
			end

			--Error checking to prevent deleting data from the savefile
			if scName ~= "Tutorial" and scName ~= "Solar System Simulation" then
				local keys = {"completed", "tried", "unlocked", "time", "resets", "medals", "collectables"}
				--Make sure that every key is in the new data (does not check contents)
				for _, key in ipairs(keys) do
					local found = false
					for k, _ in pairs(newData) do
						if key == k then
							found = true
							break
						end
					end

					errorHandler.assertTrue(found, "Save data incomplete, could not find key="..key)
				end
			end

			saveFileData.scenarios[scName] = newData
		end
	elseif type == "lastScenario" then
		if not saveFileData.lastScenario then
			saveFileData.lastScenario = {}
		end

		saveFileData.lastScenario.scenario = data.scenarioName
	elseif type == "championship" then
		if not saveFileData.championships then
			saveFileData.championships = {current = ""}
		elseif data.champData.current then
			saveFileData.championships.current = data.champData.current
		end

		if overwrite then
			saveFileData.championships[data.champName] = {
				unlocked   = data.champData.unlocked   or false,
				engaged    = data.champData.engaged    or false,
				completed  = data.champData.completed  or false,
				trophy     = data.champData.trophy     or 0,
				currentData = {
					standings = data.champData.currentData
					and (data.champData.currentData.standings
					or getDefaultChampionshipData().currentData.standings)
					or getDefaultChampionshipData().currentData.standings,
					currentScenario = data.champData.currentScenario or 1
				}
			}
		else
			local champSaveData = saveFileData.championships[data.champName]

			local prevCurrentScenario = champSaveData.currentData.currentScenario

			saveFileData.championships[data.champName] = {
				--betterBool() can be used to return the new value if it is set, or the old value if not
				unlocked   = betterBool(champSaveData.unlocked , data.champData.unlocked , data.champData.unlocked ),
				engaged    = betterBool(champSaveData.engaged  , data.champData.engaged  , data.champData.engaged  ),
				completed  = betterBool(champSaveData.completed, data.champData.completed, data.champData.completed),
				trophy     = largestSetValue(champSaveData.trophy, data.champData.trophy),
				currentData = {
					standings = data.champData.currentData
					and (data.champData.currentData.standings
					or getDefaultChampionshipData().currentData.standings)
					or getDefaultChampionshipData().currentData.standings,
					currentScenario = data.champData.currentData and (data.champData.currentData.currentScenario or prevCurrentScenario) or prevCurrentScenario
				}
			}
		end
	end

	serializeJsonToFile("gr_savefile", saveFileData, true)
end

local function updateUnlocks(scenarioNames, scenarioInfo, mapData, saveData)
	--[[
	Unlocks any new scenarios (most likely after an update has occurred with new scenarios
	such that the old scenarios did not know to unlock them)
	Parameters:
		scenarioNames   - the names of the scenarios unlocked
		scenarioDetails - the information for each scenario
		mapData         - the map gotten from trackRequirementMap
		saveData        - the savefile contents
	]]--
	local medals = getNumberOfMedals()

	for _, newScenario in ipairs(scenarioInfo) do
		local scName = newScenario.scenarioName
		local scenarioData = newScenario.scenarioData
		if mapData[scName].price <= medals then
			scenarioData.unlocked = true
		else
			for name, oldScenario in pairs(mapData) do
				--Prevent looking at unlock data from a new scenario (since savefile data does not exist yet)
				if not tableComp.contains(scenarioNames, name) then
					--Check to see if they have completed the scenario and whether it unlocks this new scenario
					if saveData.scenarios[name].completed and tableComp.contains(oldScenario.unlocks, scName) then
						scenarioData.unlocked = true
						break
					end
				end
			end
		end

		--Force overwrite to prevent an error as comparing to non-existent values
		saveToFile("scenario", {scenarioName = scName, scenarioData = scenarioData}, true)
	end
end

local function checkForUpdate()
	--[[
	Checks to see if a new update has occurred that has added new tracks
	If so, adds these to the savefile
	]]--
	local files = {}
	for _, map in ipairs(scenarioDetails.getVanillaMaps()) do
		local trackFiles = FS:findFilesByPattern("levels/"..map.."/scenarios/gravitationalRacing/tracks", "*.json", 1, true, false)
		files = tableComp.mergeAppend(files, trackFiles)
	end

	local saveData = readWholeFile()

	local newTracks = {}
	for _, fileName in ipairs(files) do
		local scenarioName, _ = scenarioDetails.getScenarioDetails(fileName)
		--There is a new track so an update must have occurred
		if not saveData.scenarios[scenarioName] then
			table.insert(newTracks, scenarioName)
		end
	end

	if #newTracks > 0 then
		local mapData = jsonDecode(readFile("lua/scenario/gravitationalRacing/dataValues/trackRequirementMap.json"))

		local scenarioInfo = {}

		for i, scenarioName in ipairs(newTracks) do
			scenarioInfo[i] = {
				scenarioName = scenarioName,
				scenarioData = getDefaultTrackData()
			}
		end

		updateUnlocks(newTracks, scenarioInfo, mapData, saveData)
	end

	-- --Championships were also added in an update so check for them
	-- if not saveData.championships then
	-- 	for champ, data in pairs(getDefaultChampionshipData()) do
	-- 		saveToFile("championship", {champName = champ, champData = data}, true)
	-- 	end
	-- end
end

local function setLastScenario(scName)
	--[[
	Sets the last scenario information to the save file
	Parameters:
		scName - the scenario name
	]]--
	saveToFile("lastScenario", {scenarioName = scName}, nil)
end

M.createNewSaveFile = createNewSaveFile
M.getDefaultChampionshipData = getDefaultChampionshipData
M.readWholeFile = readWholeFile
M.readPlayerData = readPlayerData
M.readSectionFromFile = readSectionFromFile
M.readFromFile = readFromFile
M.getNumberOfMedals = getNumberOfMedals
M.saveToFile = saveToFile
M.checkForUpdate = checkForUpdate
M.setLastScenario = setLastScenario
return M
