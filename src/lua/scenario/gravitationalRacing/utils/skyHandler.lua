local M = {}

local errorHandler = require("scenario/gravitationalRacing/utils/errorHandler")

local function generateSkybox(type)
    --[[
    Generates the skybox for this scenario
    Parameters:
        type - the type of skybox (HubWorld, Green, Yellow, Red, Blue)
    ]]--
    errorHandler.assertNil(type)
    errorHandler.assertValidElement(type, {"Green", "Yellow", "Red", "Blue", "Default"}, (type or "nil").." is not valid!")

    if scenetree.findObject("scSkybox") then
        return
    end

    TorqueScript.eval([[
        new SkyBox(scSkybox) {
            material = "SpaceSky]]..type..[[";
        };
    ]])
end

local function scDifToSkyboxColour(scenarioDifficulty)
    --[[
    Converts a scenario difficulty to skybox type
    Parameters:
        scenarioDifficulty - the scenario difficulty
    Returns:
        <string> - the skybox type
    ]]--
    if not scenarioDifficulty then
        return "Default"
    end

    scenarioDifficulty = scenarioDifficulty:lower()

    if scenarioDifficulty == "basic" then
        return "Green"
    elseif scenarioDifficulty == "advanced" then
        return "Yellow"
    elseif scenarioDifficulty == "expert" then
        return "Red"
    elseif scenarioDifficulty == "insane" then
        return "Blue"
    else
        return "Default"
    end
end

local function initialise(scenarioDifficulty)
    --[[
    Initialises the sky by creating the skybox
    Parameters:
        scenarioDifficulty - the scenario difficulty
    ]]--
    generateSkybox(scDifToSkyboxColour(scenarioDifficulty))
end

M.initialise = initialise
return M