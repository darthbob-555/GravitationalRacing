local M = {}

local scenarioController = require("scenario/gravitationalRacing/scenarioController")

local start, setup = false, false

local function onPreRender(dt)
  if setup then
    scenarioController.update(dt, start)
  end
end

local function begin()
  --[[
  Note: this function can be hooked and run from specific scenario script files
  to allow for earlier movement of celestials
  ]]--
  start = true
end

local function requestHubWorld(msg, params)
  --[[
  Responsible for transferring messages from UI to the hub world, and then
  sending back a message
  ]]--
  return require("levels/smallgrid/scenarios/gravitationalRacing/hubworld").uiRequest(msg, params)
end


local function onRaceStart()
  begin()
  scenarioController.start()
end

local function onScenarioRestarted()
  scenarioController.onScenarioRestarted()
end

local function onScenarioChange(sc)
  if sc.state == "pre-running" then
    --Hub world only uses this for UI messages
    if not sc.sourceFile:find("hubworld") then
      scenarioController.onScenarioChange(sc)

      --Hide the floor(s)
      local ground = scenetree.findClassObjects('Groundplane')
      for _, name in ipairs(ground) do
        scenetree.findObject(name).hidden = true
      end

      setup = true
    end

    -- require("util/richPresence").set("")
  end
end

M.onPreRender = onPreRender
M.begin = begin
M.requestHubWorld = requestHubWorld
M.passiveCelestials = passiveCelestials
M.onRaceStart = onRaceStart
M.onScenarioRestarted = onScenarioRestarted
M.onScenarioChange = onScenarioChange
return M
