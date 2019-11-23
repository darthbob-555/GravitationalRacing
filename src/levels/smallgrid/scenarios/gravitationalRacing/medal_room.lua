local M = {}

local fileHandler         = require("scenario/gravitationalRacing/utils/fileHandler")
local tableComp           = require("scenario/gravitationalRacing/utils/tableComprehension")
local scenarioDetails     = require("scenario/gravitationalRacing/scenario/scenarioDetails")
local championshipHandler = require("scenario/gravitationalRacing/scenario/championship/championshipHandler")

--[[
Measurements:
Collectables:
Start     (3.5, 14.5, 210.5)
Inc (4)   (  0,  6.5,     0)
Inc (Row) (  0,    0,   6.5)
Badges:
Start (91,  115   , 207)
Inc.  (0 , - 12.75,   0)
Championships:
Start ( 79   , 1, 207)
Inc.  (-11.83, 0,   0)
]]--

--[[
NOTE: Order matters to keep the badges in the same order every time
      Trophies are ordered via the championshipConfigs file, so do not need to
      be added here
      Total collectables are determined with player progress checking
]]--
local CURRENT_UNLOCKABLES = {
  totalCollectables = {
    basic    = 0,
    advanced = 0,
    expert   = 0,
    insane   = 0
  },
  badges = {
    "collectable_basic"   ,
    "collectable_advanced",
    "collectable_expert"  ,
    "collectable_insane"
  }
}

--In %
local COLLECTABLE_BADGES_RANK = {25, 50, 75, 100}

local function getPositionOfUnlockable(unlockableType, isStand, id)
  --[[
  Returns the position for this unlockable
  ]]--
  if unlockableType == "badge" then
    local baseOffset = {}
    local incOffset  = {x =  0, y = -12.75, z = 0}
    --The location of the first badge (ie. badge origin)
    local baseOffset = isStand and {x = 91, y = 115, z = 207} or {x = 94.85, y = 115.25, z = 213}

    --The amount of times to offset the unlockable from badge origin
    local offsetMulti = id-1

    return {
      x = baseOffset.x + offsetMulti * incOffset.x,
      y = baseOffset.y + offsetMulti * incOffset.y,
      z = baseOffset.z + offsetMulti * incOffset.z
    }
  end
end

local function placeCollectables() end

local function placeTrophies() end

local function placeBadges(unlocked)
  --[[
  Places all badges, with the tier corresponding to what has been achieved
  ]]--
  local i = 0
  for _, data in ipairs(unlocked) do
    local tier = data.rank
    local badgeName = data.name

    --id is already sorted
    i = i+1

    local standPos = getPositionOfUnlockable("badge", true, i)

    badgeName = badgeName:gsub(" ", "_")
    local standName = badgeName.."_stand"
    --Place stand
    if not scenetree.findObject(standName) then
      TorqueScript.eval([[
      new TSStatic(]]..standName..[[) {
        shapeName = "levels/smallgrid/art/gravitationalRacing/medalRoom/stands/badges/]]..tier..[[.dae";
        position = "]]..standPos.x..[[ ]]..standPos.y..[[ ]]..standPos.z..[[";
      };
      ]])
    end

    local badgePos = getPositionOfUnlockable("badge", false, i)
    --Place unlockable itself (if gotten)
    if tier ~= "none" then
      if not scenetree.findObject(badgeName.."_badge") then
        TorqueScript.eval([[
        new TSStatic(]]..badgeName..[[_base) {
          shapeName = "levels/smallgrid/art/gravitationalRacing/medalRoom/items/badges/]]..badgeName..[[.dae";
          position = "]]..badgePos.x..[[ ]]..badgePos.y..[[ ]]..badgePos.z..[[";
        };
        ]])
      end
    end
  end
end

local function placeAllUnlockables(currentProgress)
  --[[
  Places all unlockables, with repsect to what has been unlocked
  ]]--
  placeCollectables(currentProgress.collectables)
  placeTrophies(currentProgress.trophies)
  placeBadges(currentProgress.badges)
end

local function orderBadges(badges)
  --[[
  Reorders a table of badges according to how they should be laid out
  ]]--
  local ordered = {}
  local badges = tableComp.merge({}, badges)

  for badgeName, rank in pairs(badges) do
    for i, badgeNameOrdered in ipairs(CURRENT_UNLOCKABLES.badges) do
      --Find the correct index
      if badgeName == badgeNameOrdered then
        table.insert(ordered, {name = badgeName, rank = rank, index = i})
        break
      end
    end
  end

  table.sort(ordered, function(a, b) return a.index < b.index end)
  tableComp.removeKey(ordered, "index")

  return ordered
end

local function earnedCollectableBadges(collectables)
  --[[
  Returns the tier of badge earned by the player
  ]]--
  local badges = {collectable_basic = "", collectable_advanced = "", collectable_expert = "", collectable_insane = ""}

  for dif, amount in pairs(collectables) do
    local total = CURRENT_UNLOCKABLES.totalCollectables[dif]
    local percentage = amount / total * 100

    for rank, rankReq in ipairs(COLLECTABLE_BADGES_RANK) do
      if percentage < rankReq then
        --Player has achieved rank below this (0 for less than first rank)
        local achievedRank = rank - 1
        badges["collectable_"..dif] = championshipHandler.trophyRankToName(achievedRank)
        break
      end
    end
  end

  return badges
end

local function formatDataFromSave(saveData)
  --[[
  Organises the save data into an easier format for using
  ]]--
  local currentProgress = {
    collectables = {
      basic    = 0,
      advanced = 0,
      expert   = 0,
      insane   = 0
    },
    badges = {},
    championships = {}
  }

  local scenarios = scenarioDetails.getScenariosSortedByDif()
  for difficulty, scenarios in pairs(scenarios) do
    if difficulty ~= "tutorial" then
      for _, scName in ipairs(scenarios) do
        --Add this to the current total for this difficulty
        CURRENT_UNLOCKABLES.totalCollectables[difficulty] = CURRENT_UNLOCKABLES.totalCollectables[difficulty]+1

        local gotCollectable = saveData.scenarios[scName].collectables[1]

        if gotCollectable then
          --Add the collectable into its respective difficulty
          currentProgress.collectables[difficulty] = currentProgress.collectables[difficulty] + 1
        end
      end
    end
  end

  local championships = championshipHandler.getAllChampionships()
  for _, chName in ipairs(championships) do
    local champData = saveData.championships[chName]
    local completed = champData.completed

    if completed then
      local rank = champData.trophy
      --Get the trophy name and store it respectively
      currentProgress.championships[chName] = championshipHandler.trophyRankToName(rank)
    end
  end

  --Get badges
  local earnedBadges = earnedCollectableBadges(currentProgress.collectables)
  currentProgress.badges = orderBadges(earnedBadges)

  dump(currentProgress)
  return currentProgress
end

local function onScenarioChange(sc)
  if sc and sc.state == "pre-running" then
    local saveFile = fileHandler.readWholeFile()
    local playerProgress = formatDataFromSave(saveFile)

    placeAllUnlockables(playerProgress)
  end
end

M.onScenarioChange = onScenarioChange
return M
