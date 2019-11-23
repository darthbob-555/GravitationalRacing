ClassTrackPiece = {}
ClassTrackPiece.__index = ClassTrackPiece

function ClassTrackPiece:new(id, position, direction)
  local self = {}
  self.id = id
  self.direction = direction
  self.position = position:clone()

  setmetatable(self, ClassTrackPiece)
  return self
end

--Abstract functions, only need to be implemented in sub-classes
function ClassTrackPiece:getOccupiedSpace() --[[Returns the space in-world occupied by this piece]] return end

function ClassTrackPiece:getDirection() return self.direction end
function ClassTrackPiece:getPosition()  return self.position  end
function ClassTrackPiece:getid()        return self.id        end

---------------------------------------------------------------------------------------------------------------------------------------------------------

ClassPieceStraight = {}
ClassPieceStraight.__index = ClassPieceStraight

function ClassPieceStraight:new(id, position, direction)
  local self = ClassTrackPiece:new(id, position, direction)
  setmetatable(self, ClassPieceStraight)
  return self
end

setmetatable(ClassPieceStraight, {__index = ClassTrackPiece})

---------------------------------------------------------------------------------------------------------------------------------------------------------

ClassPieceTurn = {}
ClassPieceTurn.__index = ClassPieceTurn

function ClassPieceTurn:new(id, position, direction)
  local self = ClassTrackPiece:new(id, position, direction)
  setmetatable(self, ClassPieceTurn)
  return self
end

setmetatable(ClassPieceTurn, {__index = ClassTrackPiece})

---------------------------------------------------------------------------------------------------------------------------------------------------------

ClassPieceElevation = {}
ClassPieceElevation.__index = ClassPieceElevation

function ClassPieceElevation:new(id, position, direction)
  local self = ClassPieceElevation:new(id, position, direction)
  setmetatable(self, ClassPieceElevation)
  return self
end

setmetatable(ClassPieceElevation, {__index = ClassTrackPiece})

---------------------------------------------------------------------------------------------------------------------------------------------------------


local M = {}

local function newPiece(type, id, position, direction)
  if     type == "straight"  then return ClassPieceStraight :new(id, position, direction)
  elseif type == "turn"      then return ClassPieceTurn     :new(id, position, direction)
  elseif type == "elevation" then return ClassPieceElevation:new(id, position, direction)
  end
end

--Skethcup:
-- Remake medium and large turns for multiplies of 30m
-- Deal with 4-way intersection arrows

M.newPiece = newPiece
return M
