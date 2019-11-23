local ClassVector = require("scenario/gravitationalRacing/classes/classVector")

local function createText(input, objectName, position, scale, spacing)
  --[[
  Creates the input text into the world and returns the table
  ]]--
  local characters = {}
  local x = position:getX()

  for i = 1, #input do
    --Find character in string
    local c = string.upper(input:sub(i, i))


    if c ~= ' ' then
      TorqueScript.eval([[
      new TSStatic(text_]]..objectName..'_'..i..[[) {
        shapeName = "levels/smallgrid/art/gravitationalRacing/alphanumeric/consolas/]]..c..[[.dae";
        scale = "]]..scale..[[ ]]..scale..[[ ]]..scale..[[";
        dynamic = "1";
        position = "]]..x..[[ ]]..position:getY()..[[ ]]..position:getZ()..[[";
      };
      ]])
    end

    characters[i] = {alphanumeric = c, offsetX = 0.0175*scale + spacing}

    x = x + 0.0175*scale + spacing
  end

  return characters
end

-- local function createUnit(name, input)
-- 	if scenetree.findObject('Text_'..name..'_'..input) ~= nil then
-- 		TorqueScript.eval('Text_'..name..'_'..input..'.delete();')
-- 	end
--
-- 	TorqueScript.eval([[
-- 		new TSStatic(Text_]]..name..'_'..input..[[) {
-- 		  shapeName = "levels/smallgrid/art/solarsystem/alphanumeric/units/]]..input..[[.dae";
-- 		  scale = "1000 1000 1000";
-- 		};
-- 	]])
-- end

--------------------------------------------------------------------------------------------------------------------------------------------------------

ClassText = {}
ClassText.__index = ClassText

function ClassText:new(name, position, scale)
  local self = {}
  setmetatable(self, ClassText)
  self.position = position
  self.string = name
  self.scale = scale or 1000
  self.spacing = 0.005 * self.scale
  self.objectName = name:gsub(" ", "")
  self.charTable = createText(name, self.objectName, position, self.scale, self.spacing)
  return self
end

function ClassText:move(newPosition)
  --[[
  Moves the text to a new location
  ]]--
  local x = newPosition:getX()
  for i, data in ipairs(self.charTable) do
    TorqueScript.eval('text_'..self.objectName..'_'..i..'.position = "'..x..' '..newPosition:getY()..' '..newPosition:getZ()..'";')
    x = x + 0.0175*self.scale + self.spacing
  end

  self.position = newPosition
end

--------------------------------------------------------------------------------------------------------------------------------------------------------

local function new(name, position, scale)
  --TODO use ClassPoint instead of ClassVector for position
  return ClassText:new(name, position, scale)
end

return {new = new}
