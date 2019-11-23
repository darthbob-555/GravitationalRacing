local M = {}

local function formatColumns(l)
  --[[
  Formats the columns of the list of lists l
  ]]--
  local columnSizes = {}

  repeatString = function(s, n)
    --[[
    Repeats a string, s, n times
    This function is recursively defined
    ]]--
    --Base Case
    if n == 0 then
      return ""
    end

    --General Case
    return s..repeatString(s, n-1)
  end

  for pass = 1, 2 do
    for k, subList in pairs(l) do
      for i, element in ipairs(subList) do
        if type(element) ~= "string" then
          --Make sure each element is a string
          l[k][i] = tostring(element)
          element = tostring(element)
        end

        elementLength = #element

        --On the first pass, find the longest string in each column
        --On the second pass, update short strings to have required white space
        if pass == 1 and (not columnSizes[i] or columnSizes[i] < elementLength) then
          columnSizes[i] = elementLength
        elseif pass == 2 and elementLength < columnSizes[i] then
          l[k][i] = element..repeatString(" ", columnSizes[i]-elementLength)
        end
      end
    end
  end

  return l
end

local function printClassInfo(info, keys)
  --[[
  Prints out a classes information about an instance ina  formatted form
  ]]--
  if not info or not keys then
    error("One or more parameters are nil")
  end

  if #info == 0 or #keys == 0 then
    print("No info to display")
    return
  end

  info = formatColumns(info)

  local s = ""
  local length = #info[1]

  for _, instanceInfo in ipairs(info) do
    for i, v in ipairs(instanceInfo) do
      local k = keys[i]
      if i == 1 then
        s = v.."["
      else
        --Don't place a comma for a non-existant next attribute
        if i == length then
          s = s..k..": "..v.."]"
        else
          s = s..k..": "..v..", "
        end
      end
      i = i + 1
    end
    print(s)
  end
end

M.printClassInfo = printClassInfo
return M
