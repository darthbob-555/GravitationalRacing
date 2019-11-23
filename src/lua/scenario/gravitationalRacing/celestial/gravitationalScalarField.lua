local M = {}

local tableComp = require("scenario/gravitationalRacing/utils/tableComprehension")
local ClassVector = require("scenario/gravitationalRacing/classes/classVector")

local function getResultantForce(celestials, point)
  --[[
  Finds the resultant force at a particular point
  ]]--
  local force = ClassVector.new(0, 0, 0)

  for k, types in pairs(celestials) do
    for _, instance in pairs(types) do
      force = force:add(instance:getForceAtPoint(point))
    end
  end

  return force
end

local function createFieldComponent(i, pos, scale, colour)
  --[[
  Creates the area and colours it
  ]]--
  if scenetree.findObject("field"..i..colour) then
    TorqueScript.eval("field"..i..colour..".delete();")
  end

  -- print("Creating object "..i.." with data: "..scale:toString(), pos:toString(), colour)

  TorqueScript.eval([[
  new TSStatic(field]]..i..colour..[[) {
    shapeName = "levels/smallgrid/art/gravitationalRacing/field/]]..colour..[[.dae";
    scale = "]]..scale:getX()..[[ ]]..scale:getY()..[[ ]]..scale:getZ()..[[";
    position = "]]..pos:getX()..[[ ]]..pos:getY()..[[ ]]..pos:getZ()..[[";
  };
  ]])
end

local function displayColour(field, val, class)
  --[[
  Returns the colour based on how high the value is
  Class is optional and only needs to be considered when using field
  ]]--
  if not field then
    if class == "ClassExoticCelestial" then
      return "blue"
    else
      return "red"
    end
  end

  if     val <= 50  then return "green"
  elseif val <= 100 then return "yellow"
  elseif val <= 150 then return "orange"
  else                   return "red"
  end
end

local function generateMatrix(celestials, center, step)
  --[[
  Generates a 3D matrix of positions for each point in the field
  ]]--

  -- WorstCase = 214221, X-Compacted = 6957, Full = 5843

  local range = 500
  local scale = ClassVector.new(step, step, step)
  local i, j, k, total = 1, 1, 1, 0

  local currentChain = {i = nil, j = nil, k = nil, colour = nil, scale = nil, pos = nil}
  local lastChain = {i = nil, j = nil, k = nil, colour = nil, scale = nil, pos = nil}

  local M = {}

  for z = -100, 100, step do
    z = z + center:getZ()
    M[k] = {}
    for y = -range, range, step do
      M[k][j] = {}
      y = y + center:getY()
      for x = -range, range, step do
        x = x + center:getX()

        local pos = ClassVector.new(x, y, z)
        --Find force and hence the colour
        local fMag = getResultantForce(celestials, pos):multiply(50000):getMagnitude()
        local colour = displayColour(fMag)

        if not currentChain.colour then
          --Initialise the first object
          currentChain = {i = i, j = j, k = k, colour = colour, scale = ClassVector.new(step, step, step), pos = pos}
        else
          if currentChain.colour == colour then
            --Colours are the same so this object is unecessary
            currentChain.scale:setX(currentChain.scale:getX() + step)
          else
            --The current chain needs to be saved to the correct origin object
            M[currentChain.k][currentChain.j][currentChain.i] = {colour = currentChain.colour, scale = currentChain.scale, pos = currentChain.pos}
            lastChain = {i = currentChain.i, j = currentChain.j, k = currentChain.k, colour = currentChain.colour, scale = currentChain.scale, pos = currentChain.pos}

            local rectangle = M[currentChain.k][currentChain.j][currentChain.i]

            total = total + 1
            createFieldComponent(total, rectangle.pos, rectangle.scale, rectangle.colour)


            --This cube should start the next chain
            currentChain = {i = i, j = j, k = k, colour = colour, scale = ClassVector.new(step, step, step), pos = pos}
            --and be added to the matrix
            M[k][j][i] = {colour = colour, scale = ClassVector.new(step, step, step), pos = pos}
          end
        end

        i = i + 1
      end

      --If the chain does not exist (the last chain ended at the end of the last row), ignore it
      if currentChain.colour and currentChain.scale and currentChain.i and currentChain.j and currentChain.k then
        --If lastChain is set, both are maximum size, are on the same elevation (z) and are the same colour
        if lastChain.colour and lastChain.scale and lastChain.i and lastChain.j and lastChain.k and currentChain.scale:getX() == 2*range + step and lastChain.scale:getX() == 2*range + step and currentChain.k == lastChain.k and currentChain.colour == lastChain.colour then
          -- Update last row's Y scale
          local scale = M[lastChain.k][lastChain.j][lastChain.i].scale
          M[lastChain.k][lastChain.j][lastChain.i].scale = scale:add(ClassVector.new(0, step, 0))
          scale = M[lastChain.k][lastChain.j][lastChain.i].scale
          --Update in the scenario
          -- print("Changing object "..total.." to scale "..scale:toString());
          TorqueScript.eval('field'..total..lastChain.colour..'.scale = "'..scale:getX()..' '..scale:getY()..' '..scale:getZ()..'";');
        else
          --The end of the row has been reached so save current chain and reset to nil values
          M[currentChain.k][currentChain.j][currentChain.i] = {colour = currentChain.colour, scale = currentChain.scale, pos = currentChain.pos}
          local rectangle = M[currentChain.k][currentChain.j][currentChain.i]

          total = total + 1
          createFieldComponent(total, rectangle.pos, rectangle.scale, rectangle.colour)

          lastChain = {i = currentChain.i, j = currentChain.j, k = currentChain.k, colour = currentChain.colour, scale = currentChain.scale, pos = currentChain.pos}
        end

        --Reset for next iteration
        currentChain = {i = nil, j = nil, k = nil, colour = nil, scale = nil, pos = nil, maxSize = true}
      end

      j = j + 1
      i = 1
    end

    k = k + 1
    j = 1
  end

  return M
end

local function create(celestials)
  --[[
  Creates the scalar field
  ]]--
  local step = 10
  local center = ClassVector.new(391-88, 360-2534, 67+50)

  generateMatrix(celestials, center, step)
end

M.create = create
M.displayColour = displayColour
return M
