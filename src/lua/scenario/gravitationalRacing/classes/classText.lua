local errorHandler = require("scenario/gravitationalRacing/utils/errorHandler")

local function createText(input, objectName, position, scale, spacing)
  --[[
  Creates the input text into the world and returns the table
  Parameters:
    input      - the input string
    objectName - the name of the text object
    position   - the position to start the text at
    scale      - the scale of each character
    spacing    - the distance between two characters
  Returns:
    characters - a list of characters and their respective X values, relative to the origin
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
  errorHandler.assertNil(name, position)

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
  Parameters:
    newPosition - the new position of the text
  ]]--
  errorHandler.assertNil(newPosition)

  local x = newPosition:getX()
  --Move each character
  for i, _ in ipairs(self.charTable) do
    TorqueScript.eval('text_'..self.objectName..'_'..i..'.position = "'..x..' '..newPosition:getY()..' '..newPosition:getZ()..'";')
    x = x + 0.0175*self.scale + self.spacing
  end

  self.position = newPosition
end

--------------------------------------------------------------------------------------------------------------------------------------------------------

local function new(name, position, scale)
  --[[
  Attributes:
    name     - the base name of the text object
    position - the initial starting point fo thr first character
    scale    - the scale of each character
  ]]--
  return ClassText:new(name, position, scale)
end

return {new = new}
