local function convertDirToRot(checkpointInstance)
  --[[
  Converts a direction to a rotation for the player vehicle
  ]]--
  local dir = checkpointInstance:getDirection()
  if dir then
    if     dir == "N" then return {x = 0, y = 0, z = -1, w = 90 }
    elseif dir == "S" then return {x = 0, y = 0, z =  1, w = 90 }
    elseif dir == "W" then return {x = 0, y = 0, z =  1, w = 180}
    elseif dir == "E" then return {x = 1, y = 0, z =  0, w = 0  }
    end
  else
    --Default to the direction of the checkpoint (also used for non-cardinal-angled checkpoints)
    return checkpointInstance:getRotation()
  end
end

-------------------------------------------------------------------------------------------------------------------------------------------------------
local ClassVector = require("scenario/gravitationalRacing/classes/classVector")

ClassCheckpoint = {}
ClassCheckpoint.__index = ClassCheckpoint

function ClassCheckpoint:new(position, rotation, scale, direction, number, state, isEndingCheckpoint, splitID)
  if not position or not scale or not number or not state then
    error("One or more parameters is nil! [position="..tostring(position and position:toString() or nil)..", scale="..tostring(scale or "nil")..", direction="..tostring(direction or "nil")..", number="..tostring(number or "nil")..", state="..tostring(state or "nil").."]")
  end

  local self = {}
  self.position = ClassVector.new(position.x, position.y, position.z)
  self.direction = direction
  self.rotation = rotation
  self.number = number
  self.state = state
  self.scale = scale
  self.isEndingCheckpoint = isEndingCheckpoint
  self.isSplitCheckpoint = splitID and true or false
  self.pathID = tonumber(splitID)
  self.name = "checkpoint"..number

  setmetatable(self, ClassCheckpoint)
  return self
end

function ClassCheckpoint:getTriggerRadius()
  --[[
  Returns the radius at which the checkpoint will be classed as reached
  ]]
  if self.isEndingCheckpoint then
    --Ending checkpoints are a little bit more leniant
    return 20 * self.scale.x
  else
    --14 is the radius of the inner torus at scale x = 1
    return 14 * self.scale.x
  end
end

function ClassCheckpoint:getName()                 return self.name               end
function ClassCheckpoint:getState()                return self.state              end
function ClassCheckpoint:getPathID()               return self.pathID             end
function ClassCheckpoint:getNumber()               return self.number             end
function ClassCheckpoint:getPosition()             return self.position           end
function ClassCheckpoint:getRotation()             return self.rotation           end
function ClassCheckpoint:getDirection()            return self.direction          end
function ClassCheckpoint:isEndCheckpoint()         return self.isEndingCheckpoint end
function ClassCheckpoint:isAlternativeCheckpoint() return self.isSplitCheckpoint  end

function ClassCheckpoint:setEndCheckpoint(value)
  self.isEndingCheckpoint = value
end

function ClassCheckpoint:setState(state)
  if not (state == "next" or state == "active" or state == "inactive" or state == "split") then
    error("Incorrect state entered for checkpoint: "..(state and state or "nil"))
  end

  --An ending checkpoint cannot be changed from its finish flag texture
  if self.isEndingCheckpoint then
    return
  end

  self.state = state
  --Apply changes
  self:updateCheckpointStateInWorld()
end

function ClassCheckpoint:updateCheckpointStateInWorld()
  --[[
  Changes the state of the checkpoint in-world
  ]]--
  --Delete old version
  TorqueScript.eval(self.name..".delete();")

  local rot = convertDirToRot(self)
  local pos = self.position

  --Place new version
  TorqueScript.eval([[
    new TSStatic(]]..self.name..[[) {
      shapeName = "levels/smallgrid/art/gravitationalRacing/checkpoints/]]..self.state..[[.dae";
      scale = "]]..self.scale.x..[[ ]]..self.scale.y..[[ ]]..self.scale.z..[[";
      position = "]]..pos:getX()..[[ ]]..pos:getY()..[[ ]]..pos:getZ()..[[";
      rotation = "]]..rot.x..[[ ]]..rot.y..[[ ]]..rot.z..[[ ]]..rot.w..[[";
      direction = "]]..(self.direction or "")..[[";
    };

    ScenarioObjectsGroup.add(]]..self.name..[[);
  ]])

  if self.isSplitCheckpoint and self.pathID then
    TorqueScript.eval(self.name..'.pathID="'..self.pathID..'";')
  end
end

function ClassCheckpoint:trigger()
  --[[
  Triggers the checkpoint
  ]]--
  self.state = "active"
  if not self.isEndingCheckpoint then
    self:updateCheckpointStateInWorld()
  end
end

function ClassCheckpoint:reset()
  --[[
  Resets the checkpoint to the inactive state
  ]]--
  if not self.isEndingCheckpoint then
    self:setState("inactive")

    local currentState = scenetree.findObject(self.name).shapeName

    --Only update if necessary
    if not currentState:find(self.state) then
      self:updateCheckpointStateInWorld()
    end
  end
end

--------------------------------------------------------------------------------------------------------------------------------------------------------

local function new(position, rotation, scale, direction, number, state, isEndingCheckpoint, splitID)
  return ClassCheckpoint:new(position, rotation, scale, direction, number, state, isEndingCheckpoint, splitID)
end

return {new = new, convertDirToRot = convertDirToRot}
