local M = {}

--local errorHandler = require("scenario/gravitationalRacing/utils/errorHandler")

local pack = table.pack or function(...) return {n = select('#',...), ...} end

local function getCaller()
    --[[
    Returns the caller of the function that called this one (ie. 2 steps back)
    Returns:
        <string> - the caller of the function
    ]]--
    local caller = debug.getinfo(3).name
    --Caller may not be known
    if not caller then
        return "?"
    end

    return caller
end

local function assertNil(...)
    --[[
    Throws an error if one of the parameters is nil
    Parameters:
        ... - a varying number of arguments to check
    Error - if one argument is nil
    ]]--
    local hasError = false

    local args = pack(...)

    --See if any parameter is nil
    for i = 1, args.n do
        if args[i] == nil then
            hasError = true
            break
        end
    end

    if hasError then
        --Create a string for all parameters
        local errParamMsg = "["
        for i = 1, args.n do
            local param = tostring(args[i])
            errParamMsg = errParamMsg..(param or "nil")..", "
        end

        --Remove end ", "
        errParamMsg = errParamMsg:sub(1, #errParamMsg-2)
        --Add in ] to end
        errParamMsg = errParamMsg.."]"

        error(getCaller().." - One or more parameters is nil: "..errParamMsg)
    end
end

local function assertTrue(bool, errorMsg)
    --[[
    Throws an error if the boolean expression is false
    Parameters:
        bool     - the boolean to check
        errorMsg - the error message to throw if bool is false
    Error - if bool is false
    ]]--
    --Default if not set
    errorMsg = errorMsg or "No error message has been set, this should be fixed!"

    if not bool then
        error(getCaller().." - "..errorMsg)
    end
end

local function assertValidElement(element, set, errorMsg)
    --[[
    Throws an error if the element is in the set
    Parameters:
        element - the element to check
        set     - the set of valid elements
    Error - if element is not a member of set
    ]]--
    assertNil(element, set)

    for _, x in ipairs(set) do
        if x == element then
            --Exists so don't do anything
            return
        end
    end

    error(getCaller().." - "..errorMsg)
end

M.assertNil = assertNil
M.assertTrue = assertTrue
M.assertValidElement = assertValidElement
return M