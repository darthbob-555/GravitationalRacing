local M = {}

local fileHandler            = require("scenario/gravitationalRacing/utils/fileHandler")
local scenarioDetailsHandler = require("scenario/gravitationalRacing/scenario/scenarioDetails")
local scenarioController     = require("scenario/gravitationalRacing/scenarioController")
local celestialsHandler      = require("scenario/gravitationalRacing/celestial/celestialsHandler")
local ClassVehicle           = require("scenario/gravitationalRacing/classes/classVehicle")
local ClassVector            = require("scenario/gravitationalRacing/classes/classVector")

local saveFileData = nil
local triggersGroup = nil
local setup = false
local loadingScenario = false

local sourceFiles = {}

local vehicles = {player = nil}

local display = {displaying = false, scenario = ""}

local function highlightScenario(show, triggerName, pos, difficultyColour)
  --[[
  Shows a waypoint over the scenario
  ]]--
  if not scenetree.findObject(triggerName.."_waypoint") and show then
    TorqueScript.eval([[
    new TSStatic(]]..triggerName..[[_waypoint){
      shapeName = "art/shapes/interface/checkpoint_marker.dae";
      position = "]]..pos.x..[[ ]]..pos.y..[[ ]]..pos.z..[[";
      scale = "20 20 150";
      instanceColor = "]]..difficultyColour..[[";
    };
    ]])
  else
    if show then
      TorqueScript.eval(triggerName..'_waypoint.hidden = "0";')
    else
      TorqueScript.eval(triggerName..'_waypoint.hidden = "1";')
    end
  end
end

local function lockScenario(triggerName, pos)
  --[[
  Positions a barrier to the scenario to prevent entering
  ]]--
  if not scenetree.findObject(triggerName.."_shield") then
    TorqueScript.eval([[
    new TSStatic(]]..triggerName..[[_shield) {
      shapeName = "levels/smallgrid/art/gravitationalRacing/hubWorld/scenario_shield.dae";
      position = "]]..pos.x..[[ ]]..pos.y..[[ ]]..(pos.z-3)..[[";
      scale = "12 12 12";
      collisionType = "Visible Mesh Final";
      decalType = "Visible Mesh Final";
    };
    ]])
  end
end

local function stringToTrigger(string)
  return string:lower():gsub(" ", "_")
end

local function scenarioNameToTrigger(scName)
  --[[
  Converts a formatted scenario name to its trigger name
  ]]--
  return stringToTrigger("sc_"..scName)
end

local function championshipNameToTrigger(chName)
  --[[
  Converts a formatted scenario name to its trigger name
  ]]--
  return stringToTrigger("ch_"..chName)
end

local function triggerNameFormatted(trigName)
  --[[
  Converts a trigger name to a formatted scenario/championship name
  ]]--
  --Remove prefix
  trigName = trigName:gsub("sc_", ""):gsub("ch_", "")
  --Capitalise 1st letter
  trigName = trigName:sub(1, 1):upper()..trigName:sub(2, #trigName)

  local scName, i = "", 1

  while i <= #trigName do
    local char = trigName:sub(i, i)
    if char == "_" then
      char = i == 1 and "" or " "

      i = i+1
      --Add in a blank or empty space and capitalise the next char
      scName = scName..char..trigName:sub(i, i):upper()
    else
      --Add in next char
      scName = scName..char
    end

    i = i+1
  end

  return scName
end

local function setupScenarios()
  --[[
  Sets up the scenarios by locking those which are not avaiable to the player,
  placing the medals achieved and indicating new scenarios which have been unlocked
  ]]--
  local scenarios = saveFileData.scenarios
  for scName, scData in pairs(scenarios) do
    local triggerName = scenarioNameToTrigger(scName)
    local trigger = scenetree.findObject(triggerName)

    if trigger then
      local pos = trigger:getPosition()

      local fileName = sourceFiles[triggerName:gsub("sc_", "")]

      if not scData.unlocked then
        lockScenario(triggerName, pos)
      elseif not scData.completed then
        local _, difficulty = scenarioDetailsHandler.getScenarioDetails(fileName)
        local difficultyColour = scenarioDetailsHandler.difficultyToColourRGBA(difficulty)
        highlightScenario(true, triggerName, pos, difficultyColour)
      end
    end
  end
end

local function setupScenary()
  --[[
  Shows the applicable scenary, based on the scenarios completed
  ]]--
  local scenaryMap = jsonDecode(readFile("lua/scenario/gravitationalRacing/dataValues/trackRequirementMap.json"))
  for scName, data in pairs(saveFileData.scenarios) do
    --All objects are placed correctly in the prefab, so remove not achieved scenary
    if not data.completed then
      local scenary = scenaryMap[scName].hubworld
      --Not all scenarios unlock scenary
      if scenary then
        for _, objName in ipairs(scenary) do
          local obj = celestialsHandler.findCelestial(objName, nil)
          --May already have been deleted
          if obj then
            --Remove the object
            obj:removeFromScene(true)
          end
        end
      end
    end
  end
end

local function setupSideInfo()
  --[[
  Setups the side UI
  ]]--
  local data = {}
  local fileData = saveFileData.scenarios
  --Target data is in the order of scenarios
  local targetData = jsonDecode(readFile("lua/scenario/gravitationalRacing/dataValues/targetData.json"))

  local i = 1
  for k, _ in pairs(targetData) do
    local saveData = fileData[k] or error("No savedata is stored for track="..tostring(k or "nil"))
    --Only show if that sceanrio has been unlocked
    if saveData.unlocked then
      local sourceFile = sourceFiles[scenarioNameToTrigger(k):gsub("sc_", "")]

      local _, difficulty = scenarioDetailsHandler.getScenarioDetails(sourceFile)
      local prefabName = scenarioDetailsHandler.getSpecificDetail("prefabs", sourceFile)[1]

      --Used to order scenarios by difficulty and progression
      local stringOrder = {basic = 1, advanced = 2, expert = 3, insane = 4}

      data[i] = {
        scenarioName = k,
        scenarioColour = scenarioDetailsHandler.difficultyToColour(difficulty),
        difficulty = difficulty,
        collectable = saveData.collectables[1],
        medals = {
          resets = saveData.medals.resets,
          time = saveData.medals.time
        },
        --[[
        100 is used as some random value that will be much bigger than the total
        number of scenarios with that difficulty
        Results in index ranges:
          Basic    = 101-199
          advanced = 201-299
          Expert   = 301-399
          Insane   = 401-499
        ]]--
        index = stringOrder[prefabName:gsub("%d+", "")]*100 + prefabName:match("%d+"),
        shown = not saveData.completed
      }

      i = i + 1
    end
  end

  --Sort by calculated indexes
  table.sort(data, function(a, b) return a.index < b.index end)

  guihooks.trigger("displayStats", data)
end

local function uiRequest(request, params)
  --[[
  Handles a request from a UI, and also sends a response
  ]]--
  if request == "Highlight Scenario" then
    local scenarioName = params.scenario
    local triggerName = scenarioNameToTrigger(scenarioName)

    local waypointObj = scenetree.findObject(triggerName.."_waypoint")
    local show = not waypointObj or (waypointObj and waypointObj.hidden)

    local _, difficulty = scenarioDetailsHandler.getScenarioDetails(sourceFiles[triggerName:gsub("sc_", "")])
    highlightScenario(show, triggerName, scenetree.findObject(triggerName):getPosition(), scenarioDetailsHandler.difficultyToColourRGBA(difficulty) )

    return {show}
  else
    log("E", "uiRequest(): Unkown request! [request="..(request or "nil"))
  end
end

local function setupSourceFiles()
  --[[
  Creates the mappings of scenario name to source file
  ]]--
  for _, objName in ipairs(triggersGroup) do
    local scenarioName = objName:gsub("sc_", "")
    local formattedName = scenarioName:gsub(" ", "_"):lower()
    sourceFiles[scenarioName] = scenarioDetailsHandler.getSourcePath(formattedName)
  end
end

--------------------------------------------------------------------------------------------------------------------
--Teleport Functions------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------------------------

local teleportData = {destination = "", championship = "", angle = 0, starting = false, time = 3, rgba = {r = 0, g = 0, b = 0, a = 0}}

local function teleportToScenario(scenario, championship)
  --[[
  Loads the specified scenario
  ]]--
  if not scenario then
    log("E", "gravitationalRacing: teleportToScenario()", "Cannot load up a nil scenario, ignoring...")
    return
  end

  if championship and championship ~= "" then
    fileHandler.saveToFile("championship", {champName = championship, champData = {current = championship, engaged = true}}, false)
  end

  local filePath = sourceFiles[scenario]

  scenario_scenariosLoader.start(scenario_scenariosLoader.loadScenario(filePath, nil, filePath))
  loadingScenario = true
end

local function beginTeleport(dt)
  --[[
  Begins the teleport
  ]]--
  local rgba = teleportData.rgba
  rgba.a = 1 - teleportData.time/3

  for i = 1, 3 do
    TorqueScript.eval('teleport'..i..'.instanceColor = "'..rgba.r..' '..rgba.g..' '..rgba.b..' '..rgba.a..'";')
  end

  teleportData.time = teleportData.time - dt

  if teleportData.time <= 0 then
    teleportToScenario(teleportData.destination, teleportData.championship)
    --Prevents this function being called while the new scenario is being loaded
    teleportData.starting = false
  end
end

local function cancelTeleport()
  --[[
  Cancels the teleport by resetting the teleport data
  ]]--
  teleportData.destination = ""
  teleportData.starting = false
  teleportData.time = 3

  for i = 1, 3 do
    TorqueScript.eval('teleport'..i..'.position = "10000 0 0";')
    TorqueScript.eval('teleport'..i..'.instanceColor = "0 0 1 0";')
  end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------

local function onPreRender(dt)
  if setup and not loadingScenario then
    celestialsHandler.update(true, vehicles, dt)
    vehicles.scenario_player0:update(dt)

    --Begin the teleporting procedure
    if teleportData.starting then
      beginTeleport(dt)
    end

    local vehPos = vehicles.scenario_player0:getPosition()

    if triggersGroup then
      if not display.displaying then
        --Check each trigger to see if the player is close by
        for _, objName in ipairs(triggersGroup) do
          local objPos = scenetree.findObject(objName):getPosition()

          local dist = math.sqrt((vehPos:getX()-objPos.x)^2 + (vehPos:getY()-objPos.y)^2 + (vehPos:getZ()-objPos.z)^2)

          if dist <= 20 then
            local data = {}

            --Show scenario info to user
            if objName ~= "sc_solar_system_simulation" then
              local name, difficulty = scenarioDetailsHandler.getScenarioDetails(sourceFiles[objName:gsub("sc_", "")])

              local collectable
              local requirementsFormatted

              local saveData = fileHandler.readFromFile(name)
              if saveData then
                if saveData.collectables then
                  collectable = saveData.collectables[1]
                end

                local unlocked = saveData.unlocked
                if not unlocked then
                  local reqMap = jsonDecode(readFile("lua/scenario/gravitationalRacing/dataValues/trackRequirementMap.json"))
                  local currentMedals = fileHandler.getNumberOfMedals()
                  local price = reqMap[name].price - currentMedals

                  if price > 0 then
                    requirementsFormatted = " "..price
                    if price == 1 then
                      requirementsFormatted = requirementsFormatted.." medal"
                    else
                      requirementsFormatted = requirementsFormatted.." medals"
                    end
                  else
                    requirementsFormatted = ""
                  end

                  for scenario, data in pairs(reqMap) do
                    for _, sc in ipairs(data.unlocks or {}) do
                      if sc == name then
                        if requirementsFormatted ~= "" then
                          requirementsFormatted = requirementsFormatted.." or "..scenario
                        else
                          requirementsFormatted = "  "..scenario
                        end

                        --There won't be another instance of this so continue to next scenario
                        break
                      end
                    end
                  end
                end
              end

              if name == "Tutorial" then
                data = {
                  scenarioName = name,
                  difficulty = {
                    type = difficulty,
                    colour = scenarioDetailsHandler.difficultyToColour(difficulty)
                  }
                }
              else
                data = {
                  scenarioName = name,
                  difficulty = {
                    type = difficulty,
                    colour = scenarioDetailsHandler.difficultyToColour(difficulty)
                  },
                  collectable = collectable,
                  resets = {
                    best = saveData.resets,
                    wonMedal = saveData.medals.resets
                  },
                  time = {
                    best = saveData.time,
                    wonMedal = saveData.medals.time
                  },
                  requirementsFormatted = requirementsFormatted
                }
              end
            else
              data = {
                scenarioName = "Solar System Simulation",
                difficulty = {
                  type = "Simulation",
                  colour = scenarioDetailsHandler.difficultyToColour("Simulation")
                }
              }
            end

            --Update the UI
            guihooks.trigger("displayTrackInfo", data)

            --Prevent unecessary looping of this code with data is being displayed
            display.displaying = true
            display.scenario = objName
          end
        end
      else
        local objPos = scenetree.findObject(display.scenario):getPosition()
        local dist = math.sqrt((vehPos:getX()-objPos.x)^2 + (vehPos:getY()-objPos.y)^2 + (vehPos:getZ()-objPos.z)^2)
        if dist > 20 then
          --Vehicle has moved out of the area so the UI should be reset
          guihooks.trigger("hideTrackInfo")
          --Reset variables
          display.displaying = false
          display.scenario = ""
        end
      end
    end
  end
end

local function onBeamNGTrigger(data)
  if data.event == "enter" then
    local isScenario, isChamp = data.triggerName:find("sc_"), data.triggerName:find("ch_")

    if isScenario then
      teleportData.destination = data.triggerName:gsub("sc_", "")
    elseif isChamp then
      local championshipName = triggerNameFormatted(data.triggerName)
      local config = jsonDecode(readFile("lua/scenario/gravitationalRacing/dataValues/championshipConfigs.json"))[championshipName].config

      --Continue where the chamnpionship left off (starts anew automatically in savefile)
      local scenarioNum = fileHandler.readSectionFromFile("championships")[championshipName].currentData.currentScenario

      local scenarioName = config[scenarioNum]
      teleportData.destination = scenarioNameToTrigger(scenarioName):gsub("sc_", "")
      teleportData.championship = championshipName
    end

    if isScenario or isChamp then
      ui_message("Teleporting...", 3, "A")
      teleportData.starting = true

      --Get the rgba for the teleport object
      local _, dif = scenarioDetailsHandler.getScenarioDetails(sourceFiles[teleportData.destination])
      local rgbaString = scenarioDetailsHandler.difficultyToColourRGBA(dif)
      local rgba = {}
      --Match decimals or integers
      for val in rgbaString:gmatch("(%d*%.?%d+)") do
        table.insert(rgba, val)
      end

      teleportData.rgba = {r = rgba[1], g = rgba[2], b = rgba[3], a = 0}

      --Place markers
      local pos = scenetree.findObject(data.triggerName):getPosition()
      for i = 1, 3 do
        TorqueScript.eval('teleport'..i..'.position = "'..pos.x..' '..pos.y..' '..pos.z..'";')
      end
    end
  else
    ui_message("Teleporting cancelled", 3, "A")
    --Reset data back to initial state
    cancelTeleport()
  end
end

local function onScenarioChange(sc)
  if sc and sc.state == "pre-running" then
    --Hide track info
    guihooks.trigger("hideTrackInfo")

    for i = 1, 3 do
      TorqueScript.eval('teleport'..i..'.position = "10000 0 0";')
    end

    if setup then
      return
    end

    celestialsHandler.createCelestials(scenarioController.getSourceFile() ~= sc.sourceFile, nil, true)

    --This prevents an issue where returning from a level to the hub-world and going back
    --would overwrite celestials in the scenario with hub-world celestials
    scenarioController.setSourceFile(sc.sourceFile)

    if not vehicles.scenario_player0 then
      vehicles.scenario_player0 = ClassVehicle.new("scenario_player0", scenetree.findObject("scenario_player0"):getPosition())
    end

    fileHandler.checkForUpdate()

    saveFileData = fileHandler.readWholeFile()

    --Compatibility since this feature was added in an update so some savefiles do not have this
    --Also, new savefiles do not have this as there is no player scenario yet
    if saveFileData.lastScenario then
      local lastScenario = saveFileData.lastScenario.scenario
      local potentialNames = {scenarioNameToTrigger(lastScenario), championshipNameToTrigger(lastScenario)}
      local trigger = scenetree.findObject(potentialNames[1]) or scenetree.findObject(potentialNames[2])

      if trigger then
        --Place player next to trigger
        local tPos = trigger:getPosition()
        local position = ClassVector.new(tPos.x, tPos.y-13, tPos.z)

        vehicles.scenario_player0:placeVehicle(position)
      end
    end

    triggersGroup = scenetree.findClassObjects('BeamNGTrigger')

    setupSourceFiles()

    setupScenarios()
    setupScenary()
    be:reloadStaticCollision()

    --Happens after setupScenary to save creating and deleting trails or non-shown celestials (which is expensive to do so)
    celestialsHandler.initCelestials()
    celestialsHandler.printResults()

    setupSideInfo()

    --Hide the floor
    local ground = scenetree.findClassObjects('Groundplane')
    for _, name in ipairs(ground) do
      scenetree.findObject(name).hidden = true
    end

    setup = true
  end
end

M.uiRequest = uiRequest

M.onPreRender = onPreRender
M.onBeamNGTrigger = onBeamNGTrigger
M.onScenarioChange = onScenarioChange
return M