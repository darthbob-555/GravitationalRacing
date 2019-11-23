local M = {}

local function mergeAppend(a, b, ...)
  --[[
  Merges two or more integer indexed tables into a new table, preventing overwriting
  of the same index
  ]]--
  local tables = {a, b, select(1, ...)}

  local c = {}
  local index = 1

  for _, T in ipairs(tables) do
    for i, v in ipairs(T) do
      c[index] = v
      index = index + 1
    end
  end

  return c
end

local function merge(a, b)
  --[[
  Merges table b and a into c. If b is nil, then it returns a
  This does not merge in place, so can be used to clone a table
  ]]--
  local c = {}

  for k, v in pairs(a or {}) do
    c[k] = v
  end

  for k, v in pairs(b or {}) do
    c[k] = v
  end

  return c
end

local function lengthOfTable(T)
  local c = 0
  for _, _ in pairs(T) do
    c = c + 1
  end

  return c
end

local function contains(T, v)
  --[[
  Returns whether a table T contains a value v
  This function is recursively defined
  ]]--
  if not v then
    error("Cannot check for a nil value!")
  end

  for _, value in ipairs(T) do
    if type(value) == "table" then
      if contains(value, v) then
        return true
      end
    else
      if value == v then
        return true
      end
    end
  end

  return false
end

local function flattenDict(T)
  --[[
  Flatterns a table T by removing all subtables in T
  This version flattens dictionaries
  This function is recursively defined
  ]]--
  --Base Case
  if type(T) ~= "table" then
    return {T}
  end

  --General Case
  local flattenedT = {}
  for k1, element in pairs(T) do
    for k2, value in pairs(flattenDict(element)) do
      --If flattenDict is called on a value, k2 will be 1 ie. a number
      if type(k2) ~= "number" then
        --Value is now a value and not a table (if it was previously)
        flattenedT[k2] = value
      else
        flattenedT[k1] = value
      end
    end
  end

  return flattenedT
end

local function flattenDictToArr(T)
  --[[
  Flattens a dictionary T by removing all subtables in T and converting to an array
  This function is recursively defined
  ]]--
  --Base Case
  if type(T) ~= "table" then
    return {T}
  end

  --General Case
  local flattenedT = {}
  for k1, element in pairs(T) do
    for k2, value in pairs(flattenDictToArr(element)) do
      table.insert(flattenedT, value)
    end
  end

  return flattenedT
end

local function flatten(T)
  --[[
  Flattens a table T by removing all subtables in T whilst maintaining order
  This function is recursively defined
  ]]--
  --Base Case
  if type(T) ~= "table" then
    return {T}
  end

  --General Case
  local flattenedT = {}
  for _, element in ipairs(T) do
    for _, value in ipairs(flatten(element)) do
      --Value is now a value and not a table (if it was previously)
      table.insert(flattenedT, value)
    end
  end

  return flattenedT
end

local function containsIndex(T, v, indexes)
  --[[
  Returns the index (multiple for sub-tables) for a particular value in a table
  This function is recursively defined
  ]]--
  if not v then
    error("Cannot check for a nil value!")
  end

  if not indexes then
    indexes = {}
  end

  for i, value in ipairs(T) do
    if type(value) == "table" then
      local subindex = containsIndex(value, v, indexes)
      if subindex then
        return flatten({i, subindex})
      end
    else
      if value == v then
        return i
      end
    end
  end

  return nil
end

local function hasNumericalIndexes(T)
  --[[
  Returns whether a table T is numerically indexed ie. an array
  ]]--
  for i = 1, lengthOfTable(T) do
    --If there is no key, it cannot be an array
    if not T[i] then
      return false
    end
  end

  return true
end

local function getSmallestValue(T)
  --[[
  Returns the lowest value in a table
  This function is recursively defined
  ]]--
  if not T then
    return
  end

  local smallest = math.huge

  --Sort out dictionaries from arrays
  if hasNumericalIndexes(T) then
    for _, value in ipairs(T) do
      local valType = type(value)
      if valType == "table" then
        local smallestInSubTable = getSmallestValue(value)
        if smallestInSubTable < smallest then
          smallest = smallestInSubTable
        end
      elseif valType == "number" then
        if value < smallest then
          smallest = value
        end
      end
    end
  else
    for _, value in pairs(T) do
      --TODO merge this with above to reduce repeating code
      local valType = type(value)
      if valType == "table" then
        local smallestInSubTable = getSmallestValue(value)
        if smallestInSubTable < smallest then
          smallest = smallestInSubTable
        end
      elseif valType == "number" then
        if value < smallest then
          smallest = value
        end
      end
    end
  end

  return smallest
end

local function removeKey(T, K)
  --[[
  Removes a key from a nested dictionary
  This function is recursively defined
  ]]--
  if not T or not K then
    return
  end

  for k, v in pairs(T) do
    if k == K then
      T[k] = nil
    elseif type(v) == "table" then
      v = removeKey(v, K)
    end
  end

  return T
end

M.mergeAppend = mergeAppend
M.merge = merge
M.lengthOfTable = lengthOfTable
M.contains = contains
M.flattenDictToArr = flattenDictToArr
M.flattenDict = flattenDict
M.flatten = flatten
M.containsIndex = containsIndex
M.getSmallestValue = getSmallestValue
M.removeKey = removeKey
return M
