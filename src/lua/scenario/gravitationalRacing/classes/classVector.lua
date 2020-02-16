local errorHandler = require("scenario/gravitationalRacing/utils/errorHandler")

ClassVector = {}
ClassVector.__index = ClassVector

function ClassVector:new(x, y, z)
  errorHandler.assertNil(x, y, z)

  local self = {}
  setmetatable(self, ClassVector)
  self.components = {x = x, y = y, z = z}
  return self
end

--Getters
function ClassVector:getX() return self.components.x end
function ClassVector:getY() return self.components.y end
function ClassVector:getZ() return self.components.z end

--Setters
function ClassVector:setX(newX)
  errorHandler.assertNil(newX)
  self.components.x = newX
end

function ClassVector:setY(newY)
  errorHandler.assertNil(newY)
  self.components.y = newY
end

function ClassVector:setZ(newZ)
  errorHandler.assertNil(newZ)
  self.components.z = newZ
end

function ClassVector:clone()
  return ClassVector:new(self.components.x, self.components.y, self.components.z)
end

function ClassVector:add(a)
  --[[
  Return the vector a added to this vector
  Parameters:
    a - the vector to add
  Returns:
    <ClassVector> - the resultant vector
  ]]--
  errorHandler.assertNil(a)

  if type(a) == "table" then
	--Resultant vector
    local r = ClassVector:new(0, 0, 0)
    r:setX(self.components.x + a:getX())
    r:setY(self.components.y + a:getY())
    r:setZ(self.components.z + a:getZ())
    return r
  else
    error("Data type error: "..type(a))
  end
end

function ClassVector:subtract(a)
  --[[
  Subtract vector a from this vector
  Parameters:
    a - the vector to subtract
  Returns:
    <ClassVector> - the resultant vector
  ]]--
  errorHandler.assertNil(a)

  if type(a) == "table" then
    local r = ClassVector:new(0, 0, 0)
    r:setX(self.components.x - a:getX())
    r:setY(self.components.y - a:getY())
    r:setZ(self.components.z - a:getZ())
    return r
  else
    error("Data type error: "..type(a))
  end
end

function ClassVector:multiply(a)
  --[[
  Multiply this vector by a vector/number a
  Parameters:
    a - the vector to use
  Returns:
    <ClassVector> - the resultant vector
  ]]--
  errorHandler.assertNil(a)

  local r = ClassVector:new(0, 0, 0)
  if type(a) == "table" then
    r:setX(self.components.x * a:getX())
    r:setY(self.components.y * a:getY())
    r:setZ(self.components.z * a:getZ())
  elseif type(a) == "number" then
    r:setX(self.components.x * a)
    r:setY(self.components.y * a)
    r:setZ(self.components.z * a)
  else
    error("Data type error: "..type(a))
  end

  return r
end

function ClassVector:divide(a)
  --[[
  Divide this vector by a vector/number a
  Parameters:
    a - the vector to divide
  Returns:
    <ClassVector> - the resultant vector
  ]]--
  errorHandler.assertNil(a)

  local r = ClassVector:new(0, 0, 0)
  if type(a) == "table" then
    r:setX(self.components.x / a:getX())
    r:setY(self.components.y / a:getY())
    r:setZ(self.components.z / a:getZ())
  elseif type(a) == "number" then
    r:setX(self.components.x / a)
    r:setY(self.components.y / a)
    r:setZ(self.components.z / a)
  else
    error("Data type error: "..type(a))
  end

  return r
end

function ClassVector:getMagnitude()
  --[[
  Returns:
    <number> - the length/magnitude of this vector
  ]]--
  return math.sqrt(math.pow(self.components.x, 2) + math.pow(self.components.y, 2) + math.pow(self.components.z, 2))
end

function ClassVector:getDistanceBetween(a)
  --[[
  Parameters:
    a - the vector to compare
  Returns:
    <number> - the distance between this vector and another
  ]]--
  errorHandler.assertNil(a)
  return self:subtract(a):getMagnitude()
end

function ClassVector:toUnitVector()
  --[[
  Returns:
    <ClassVector> - the unit vector of this vector ie. mag(v) = 1
  ]]--
  local mag = self:getMagnitude()
  return self:divide(mag)
end

function ClassVector:abs()
  --[[
  Absolutes each component and returns the resulting vector
  ]]--
  self.components.x = math.abs(self.components.x)
  self.components.y = math.abs(self.components.y)
  self.components.z = math.abs(self.components.z)
  return self
end

function ClassVector:isEqual(a)
  --[[
  Determine whether this vector is the same as vector a, or its magnitude is equal to a
  Parameters:
    a - the vector to compare
  Returns:
    <boolean> - if a is a vector, returns if all components match
                else            , returns if the magnitude match a
  ]]--
  errorHandler.assertNil(a)

  if type(a) == "table" then
    return self.components.x == a:getX() and self.components.y == a:getY() and self.components.z == a:getZ()
  else
    return self:getMagnitude() == a
  end
end

function ClassVector:isEqualTolerance(a, t)
  --[[
  Determine whether this vector is the same as vector a within a tolerance t
  Parameters:
    a - the vector to compare
    t - the tolerance
  Returns:
    <boolean> - if the components match within the specified tolerance
  ]]--
  errorHandler.assertNil(a, t)
  errorHandler.assertTrue(t >= 0, "Tolerance must be positive")

  if type(a) == "table" then
    return math.abs(self.components.x-a:getX()) <= t and
           math.abs(self.components.y-a:getY()) <= t and
           math.abs(self.components.z-a:getZ()) <= t
  else
    error("Data type error: "..type(a))
  end
end

function ClassVector:zero()
  --[[
  Sets all the vectors dimensions to zero
  ]]--
  self:setX(0)
  self:setY(0)
  self:setZ(0)
end

function ClassVector:instanceOf()
  --[[
  Return the class this object is of
  ]]--
  return "ClassVector"
end

function ClassVector:toString()
  --[[
  Returns a string of this vector for viewing its attributes
  ]]--
  return '['..self.components.x..', '..self.components.y..', '..self.components.z..']'
end

---------------------------------------------------------------------------------------------------------------------------------------------

local function new(x, y, z)
  --[[
  Attributes:
    x - the x component
    y - the y component
    z - the z component
  ]]--
  return ClassVector:new(x, y, z)
end

return {new = new}
