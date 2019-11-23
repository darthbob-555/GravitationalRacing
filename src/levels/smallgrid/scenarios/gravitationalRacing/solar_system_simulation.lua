local M = {}

local celestialsHandler = require("scenario/gravitationalRacing/celestial/celestialsHandler")
local ClassText         = require("scenario/gravitationalRacing/classes/classText")
local ClassVector       = require("scenario/gravitationalRacing/classes/classVector")

local function lotsOfSuns()
  --[[
  Creates lots of suns
  ]]--
  for i = 1, 6 do
    local pos = ClassVector.new(0 + 5000*math.sin(math.rad(60 * i)), 2750 + 5000*math.cos(math.rad(60 * i)), 1750)
    local name = "star_"..(i+1)
    celestialsHandler.createCelestial("sun", pos, name, "star", math.random(5000, 15000), "dynamic", nil, true, false, nil)
  end
end

local function onBeamNGTrigger(data)
  if data.event == "enter" then
    if data.triggerName == "lotsOfSuns" then
      lotsOfSuns()
    end
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
    celestialsHandler.findCelestial("planet_"..i, "dynamic"):createLabel()
  end
end

local function onScenarioChange(sc)
  if sc and sc.state == "pre-running" then
    local pos = scenetree.findObject("lotsOfSuns"):getPosition()
    ClassText.new("chaos", ClassVector.new(pos.x-6, pos.y+10, pos.z+1), 100)
  end
end

M.onPreRender = onPreRender
M.onBeamNGTrigger = onBeamNGTrigger
M.onScenarioRestarted = onScenarioRestarted
M.onRaceStart = onRaceStart
M.onScenarioChange = onScenarioChange
return M
