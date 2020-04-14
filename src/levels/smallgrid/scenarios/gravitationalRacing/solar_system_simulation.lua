local M = {}

local celestialsHandler = require("scenario/gravitationalRacing/celestial/celestialsHandler")
local ClassText         = require("scenario/gravitationalRacing/classes/classText")
local ClassVector       = require("scenario/gravitationalRacing/classes/classVector")

local function lotsOfSuns()
  --[[
  Creates lots of suns in random positions
  ]]--
  for i = 1, 6 do
    local pos = ClassVector.new(0 + 5000*math.sin(math.rad(60 * i)), 2750 + 5000*math.cos(math.rad(60 * i)), 1750)
    celestialsHandler.createCelestial("ClassCelestial", "sun", pos, "star_"..(i+1), "star", math.random(5000, 15000), "dynamic", nil, true, false, nil, nil, nil)
  end
end

local function onBeamNGTrigger(data)
  if data.event == "enter" and data.triggerName == "lotsOfSuns" then
    lotsOfSuns()
  end
end

local function onScenarioRestarted()
  --[[
  Deletes the suns created
  ]]--
  for i = 1, 6 do
    celestialsHandler.deleteCelestial("star_"..(i+1), "dynamic")
  end
end

local function onRaceStart()
  for i = 1, 8 do
    -- Finds each celestial and creates the label in-world
    celestialsHandler.findCelestial("planet_"..i, "dynamic"):createLabel()
  end
end

local function onScenarioChange(sc)
  if sc and sc.state == "pre-running" then
    local pos = scenetree.findObject("lotsOfSuns"):getPosition()
    -- Place text in-world for the button
    ClassText.new("chaos", ClassVector.new(pos.x-6, pos.y+10, pos.z+1), 100)
  end
end

M.onBeamNGTrigger = onBeamNGTrigger
M.onScenarioRestarted = onScenarioRestarted
M.onRaceStart = onRaceStart
M.onScenarioChange = onScenarioChange
return M
