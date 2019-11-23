local tableComp = require("scenario/gravitationalRacing/utils/tableComprehension")

ClassMatrix = {}
ClassMatrix.__index = ClassMatrix

function ClassMatrix.new(elements)
  local rowLen = 0
  for _, row in ipairs(elements) do
    if rowLen == 0 then
      rowLen = #row
    elseif rowLen ~= #row then
      error("Rows must be the same length!")
    end
  end

  local self = {}
  self.elements = elements

  setmetatable(self, ClassMatrix)
  return self
end

function ClassMatrix:getNumberOfColumns()
  return #self.elements[1]
end

function ClassMatrix:getNumberOfRows()
  return #self.elements
end

function ClassMatrix:getElement(r, c)
  return self.elements[r][c]
end

function ClassMatrix:getColumn(number)
  local column = {}

  for i = 1, self:getNumberOfRows() do
    column[i] = self.elements[i][number]
  end

  return column
end

function ClassMatrix:getRow(number)
  return self.elements[number]
end

function ClassMatrix:multiply(m)
  --[[
  Multiply this matrix by another
  Note: the order matters, and this matrix is considered multiplying first
  ie. self * m = M
  ]]--

  if self:getNumberOfColumns() ~= m:getNumberOfRows() then
    error("Cannot multiply matrices with incorrect dimensions!")
  end

  local mResult = {}

  for i = 1, self:getNumberOfRows() do
    mResult[i] = {}
    for j = 1, m:getNumberOfColumns() do
      local value = 0

      local rows, columns = self:getRow(i), m:getColumn(j)
      --Both arrays will be the same length
      for index = 1, #rows do
        value = value + rows[index]*columns[index]
      end

      mResult[i][j] = value
    end
  end

  return ClassMatrix.new(mResult)
end

function ClassMatrix:display(M)
  --[[
  Displays a/this matrix in an easy to read manner
  ]]--
  local matrix = self and self.elements or M

  for i, row in ipairs(matrix) do
    local rowString = " "
    if i == 1 then rowString = "[" end

    for i2, value in ipairs(row) do
      if i2 == 1 then rowString = rowString..value
      else rowString = rowString..","..value
      end
    end

    if i == #matrix then rowString = rowString.."]" end

    rowString = rowString:gsub(",", " ")

    print(rowString)
  end
end

---------------------------------------------------------------------------------------------------------------------------------------------

local function new(elements)
  return ClassMatrix.new(elements)
end

local function getRotationXMatrix(angle)
  --[[
  Returns a matrix rotation about the x axis
  ]]--
  return ClassMatrix.new({
    {1,        0       ,         0       },
    {0, math.cos(angle), -math.sin(angle)},
    {0, math.sin(angle),  math.cos(angle)},
  })
end

local function getRotationYMatrix(angle)
  --[[
  Returns a matrix rotation about the y axis
  ]]--
  return ClassMatrix.new({
    { math.cos(angle), 0, math.sin(angle)},
    {        0       , 1,        0        },
    {-math.sin(angle), 0, math.cos(angle)},
  })
end

local function getRotationZMatrix(angle)
  --[[
  Returns a matrix rotation about the z axis
  ]]--
  return ClassMatrix.new({
    {math.cos(angle), -math.sin(angle), 0},
    {math.sin(angle),  math.cos(angle), 0},
    {       0       ,         0       , 1}
  })
end

return {
  new = new,
  getRotationXMatrix = getRotationXMatrix,
  getRotationYMatrix = getRotationYMatrix,
  getRotationZMatrix = getRotationZMatrix
}
