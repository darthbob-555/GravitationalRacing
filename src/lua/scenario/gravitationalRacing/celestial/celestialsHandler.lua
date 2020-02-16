local M = {}

local stringFormatter   = require("scenario/gravitationalRacing/utils/stringFormatting")
local ClassVector       = require("scenario/gravitationalRacing/classes/classVector")
local ClassCelestial    = require("scenario/gravitationalRacing/classes/classCelestial")
local ClassBinarySystem = require("scenario/gravitationalRacing/classes/classBinarySystem")
local factors           = require("scenario/gravitationalRacing/dataValues/factors")
local field             = require("scenario/gravitationalRacing/celestial/gravitationalScalarField")
local tableComp         = require("scenario/gravitationalRacing/utils/tableComprehension")
local errorHandler      = require("scenario/gravitationalRacing/utils/errorHandler")

local unpack = unpack or table.unpack

local celestials = {fixedDynamic = {}, dynamic = {}, static = {}}
local systems = {}
local supernovae = {}

local initial = {positions = {length = 0}, scale = {}}
local passiveMode = false
-- local spectating, camera = nil, nil

local function findCelestial(name, objectType)
	--[[
	Returns the celestial object in the table of celestials in the scenario
	This function MUST be given the celestial name, but can also receive an optional
	parameter to narrow the search
	Parameters:
		name       - the name of the celestial
		objectType - the object type of the celestial (optional)
	Returns:
		<ClassCelestial> - the celestial instance
	]]--
	if objectType then
		local instance = celestials[objectType][name]
		if instance then
			return instance
		end
	else
		for _, typeTables in pairs(celestials) do
			local instance = typeTables[name]
			if instance then
				return instance
			end
		end
	end

	log("I", "gravitationalRacing: findCelestial()", "Could not find celestial with name="..name)
end

local function findSystem(systemName)
	--[[
	Returns a system instance with name systemName
	Parameters:
		systemName - the name of the system
	Returns:
		<ClassBinarySystem> - the system instance
	]]--
	errorHandler.assertNil(systemName)
	return systems[systemName]
end

local function systemNameToCelestials(systemName)
	--[[
	Returns the two parts in a system (each part can be either a celestial or another binary system)
	Parameters:
		systemName - the name of the system
	Returns:
		<string> - the first celestial/system
		<string> - the second celestial/system
	]]--
	errorHandler.assertNil(systemName)

	local type = systemName:match("%a+")
	--Return the celestial on the left and right side of the |
	return type.."_"..systemName:match("[%d]+"), type.."_"..systemName:match("(|[%d]+)"):gsub("|", "")
end

local function findNextName(type)
	--[[
	Finds the name of the next object (ie. if there are two black holes in-world, returns blackhole_3)
	Parameters:
		type - the type of celestial
	Returns:
		name - the name of the celestial
	]]--
	errorHandler.assertNil(type)

	local i = 1
	local name = type.."_"..i
	while scenetree.findObject(name) do
		i = i + 1
		name = type.."_"..i
	end

	return name
end

-- local function findSystemMatch(func, value, returnInstances)
-- 	--[[
-- 	Finds ALL systems whose particular method return value equals value
-- 	returnInstances is an optional parameter that tells this function to return instance,
-- 	not names instead
-- 	TODO allow arguments
-- 	]]--
-- 	local matching = {}
--
-- 	for _, system in pairs(systems) do
-- 		local result = system:callMethod(func)
-- 		if result == value then
-- 			table.insert(matching, returnInstances and instance or instance:getName())
-- 		end
-- 	end
--
-- 	return matching
-- end

local function findCelestialMatch(func, value, returnInstances)
	--[[
	Finds ALL celestials whose particular method return value equals value
	returnInstances is an optional parameter that tells this function to return instance,
	not names instead
	TODO allow arguments
	Parameters:
		func            - the name of the function to call on each celestial
		value           - the expected value of the function return (can be nil)
		returnInstances - whether to return instances or just names
	Returns:
		matching - the celestial which match the value when the method is called
	]]--
	errorHandler.assertNil(func)

	local matching = {}

	for _, objType in pairs(celestials) do
		for _, instance in pairs(objType) do
			local result = instance:callMethod(func)
			if type(result) == "table" then
				if result["instanceOf"] and result:instanceOf() == "ClassVector" then
					--TODO This should probably be more generic
					if result:isEqualTolerance(value, 10) then
						table.insert(matching, returnInstances and instance or instance:getName())
					end
				else
					log("E", "findCelestialMatch()", "I don't know how to compare this table!")
				end
			elseif result == value then
				table.insert(matching, returnInstances and instance or instance:getName())
			end
		end
	end

	return matching
end

local function callMethodOnCelestials(list, method, args)
	--[[
	Calls a method on a set of celestials, or all if not specified
	Parameters:
		list   - the list of celestials (can be nil to use all)
		method - the method to call on each celestial
		args   - the args to use for that method call (can be nil for no args)
	]]--
	errorHandler.assertNil(method)

	--Whether to use specific celestials or not
	local check = list ~= nil

	for _, objType in pairs(celestials) do
		for _, instance in pairs(objType) do
			--Check that the celestial exists in the list
			if check then
				local instName = instance:getName()
				for _, name in ipairs(list) do
					if name == instName then
						instance:callMethod(method, args)
						break
					end
				end
			else
				instance:callMethod(method, args)
			end
		end
	end
end

local function isInBinarySystem(component, returnSystem)
	--[[
	Returns whether this component (system or celestial) is in a binary system
	Parameters:
		celestial    - the celestial instance to check
		returnSystem - whether to return the system or not
	Returns:
		<boolean>           - whether this component is part of a system
		<ClassBinarySystem> - the system this celestial is part of (nil if not wanted)
	]]--
	for _, systemInstance in pairs(systems) do
		local c1, c2 = unpack(systemInstance:getComponents())
		--Check either component to see if it is part of this system
		if c1 == component or c2 == component then
			return true, returnSystem and systemInstance
		end
	end

	return false, nil
end

local function sortDependencies(allCelestials)
	--[[
	Returns a table of all celestials based on their 'importance'
	This is determined by whether a celestial needs another before it can setup
	Ie. circumbinary planet needs its two parent stars setup beforehand
	Note: the specific order does not matter (ie. between two indexes), only that
	parents should be first in the list
	Parameters:
		allCelestials - all celestials in the scenario
	Returns:
		orderedCelestials - the celestials ordered
	]]--
	errorHandler.assertNil(allCelestials)

	local orderedCelestials = {instances = {}, names = {}}

	local timeout = 3

	--While there are celestials left (timeout is a debug to prevent infinite looping)
	while tableComp.lengthOfTable(allCelestials) > 0 and timeout > 0 do
		for name, celestial in pairs(allCelestials) do
			local parentName = celestial:getParentCelestial()

			local binary = celestial:isCircumbinary()
			local binaryParentSetup = false
			if binary then
				local parent1, parent2 = systemNameToCelestials(parentName)
				binaryParentSetup = orderedCelestials.names[parent1] or orderedCelestials.names[parent2]
			end

			--TODO if binary, then check for hierarchical levels with multiple |
			--If it is a stand-alone celestial, it doesn't matter - neither if it is binary since it doesn't matter which sets up first
			if not parentName or orderedCelestials.names[parentName] or isInBinarySystem(celestial) or binaryParentSetup then
				table.insert(orderedCelestials.instances, celestial)
				orderedCelestials.names[name] = true
				allCelestials[name] = nil
			end
		end

		timeout = timeout - 1
	end

	--DEBUG
	if timeout == 0 then
		print("Failed to append: ")
		for name, _ in pairs(allCelestials) do print("   "..name) end
	end

	return orderedCelestials.instances
end

local function getOrbitalVelocity(celestial, parent)
	--[[
	Calculates the orbital velocity of an object, given an instance of the parent
	celestial body
	Note1: Formula derived from F = GMm/r² = mv²/r, --> v = sqrt(GM/r) only works for NON-STARS as m1 << m2
	Another formula can be derived for stars: a = F/m, F = GMm/r², a = v²/r -->  v1 = sqrt(G.M2.r1/r²)
	Note2: The vector returned will always have the object going anti-clockwise
	around its parent celestials, and starts in the +y direction
	Parameters:
		celestial - the celestial instance
		parent    - the parent instance to the celestial
	Returns:
		<ClassVector> - a velocity vector for the celestial
	]]--
	errorHandler.assertNil(celestial, parent)

	local inSystem, systemInstance = isInBinarySystem(celestial, true)
	--Stars can orbit black holes as m1 >> m2 - for all intents and purposes
	if inSystem then
		return ClassVector.new(0, systemInstance:getOrbitalVelocity(celestial), 0)
	else
		local m = parent:getMass()
		local r = celestial:getPosition():getDistanceBetween(parent:getPosition()) / factors.getDistanceScaleFactor()
		local scaling = factors.getDistanceScaleFactor() * factors.getTimeScaleFactor()

		return ClassVector.new(
				0,
				math.sqrt(ClassCelestial.getGravitationalConstant() * m/r) * scaling,
				0
		)
	end
end

local function setInitialVelocities(sortedCelestials)
	--[[
	Sets the initial velocities for all dynamic celestials
	Parameters:
		sortedCelestials - celestials where importance has been sorted
	]]--
	for _, celestial in ipairs(sortedCelestials) do
		local parent = celestial:getParentCelestial()
		if parent then
			--Parent can either be a single celestial or a system (circumbinary)
			parent = parent:find("|") and systems[parent] or findCelestial(parent)

			v = getOrbitalVelocity(celestial, parent)
			celestial:setVelocity(v)
		end
	end
end

local function setInitialConditions()
	--[[
	Sets the initial starting position and scale for each celestial
	If the information does not exist, create it and stored it
	]]--
	--Only one length variable needs to be stored for both positions and scale tables,
	--as they will have the same value
	if initial.positions.length == 0 then
		--Save initial conditions (indicates the scenario has been reloaded or first time loaded)
		for type, table in pairs(celestials) do
			initial.positions[type] = {}
			initial.scale[type] = {}
			for k, _ in pairs(table) do
				local obj = scenetree.findObject(k)

				local objPos = obj:getPosition()
				initial.positions[type][k] = ClassVector.new(objPos.x, objPos.y, objPos.z)
				initial.positions.length = initial.positions.length + 1

				initial.scale[type][k] = obj:getScale().x
			end
		end
	end

	--Set object's position in its instance
	for type, table in pairs(celestials) do
		for k, celestial in pairs(table) do
			celestial:setSetup(false)

			local pos = initial.positions[type][k]
			local initPos = ClassVector.new(pos:getX(), pos:getY(), pos:getZ())

			celestial:setPosition(initPos)
			celestial:setInitialPosition(initPos)

			local scale = initial.scale[type][k]
			celestial:setScale(scale)

			local newRadius = scale*factors.getRadiusScaleFactor()
			celestial:setRadius(newRadius)

			local newMass = celestial:calculateMass(newRadius, celestial:getActual("radius"), celestial:getActual("mass"))
			celestial:setMass(newMass)

			--Update its position and size in world
			celestial:display()
		end
	end
end

local function findCelestials()
	--[[
	Finds all celestials in the scenario
	Returns:
		celestialsInScenario - all celestials in the scenario
	]]--
	local celestialsInScenario = {}
	local categories = ClassCelestial.getTypes()

	local i, obj
	for _, category in ipairs(categories) do
		i = 1
		obj = scenetree.findObject(category.."_"..i)
		--While they exist, add them into the table
		while obj do
			table.insert(celestialsInScenario, {category = category, obj = obj})
			i = i + 1
			obj = scenetree.findObject(category.."_"..i)
		end
	end

	return celestialsInScenario
end

local function resetCelestials()
	--[[
	Reset danger zone areas and delete old trails
	]]--
	for type, groupOfCelestials in pairs(celestials) do
		for k, _ in pairs(groupOfCelestials) do
			local instance = celestials[type][k]

			if not passiveMode then
				instance:displayRadialZones()
			end

			instance:reset()
		end
	end
end

local function startSupernovae()
	--[[
	Sets the countdown to begin for all supernovae
	]]--
	for _, supernova in ipairs(supernovae) do
		supernova:prep()
	end
end

local function convertToSystemName(p1Name, p2Name)
	--[[
	Converts two parents orbiting each other into a system name for them
	Examples:
		1) star_2,     star_1     -> star_(1|2)
		2) star_(1|2), star_3     -> star_((1|2)|3)
		3) star_(1|7), star_(4|6) -> star_((1|7)|(4|6))
	Conventions:
		Order of singular celestials should be smallest first - see 1)
		In cases where a system and a singular celestial, the system goes first - see 2)
		In cases where 2 systems are orbiting, the one with the smallest FIRST celestial id goes first - see 3)
	Parameters:
		p1Name - the first parent
		p2Name - the second parent
	Returns:
		<string> - the system name comprised of the two parents
	]]--
	local isP1Binary, isP2Binary = p1Name:find("|"), p2Name:find("|")

	local type = p2Name:match("[^(%d+)]+")
	local id1, id2

	if not (isP1Binary or isP2Binary) then
		id1, id2 = tonumber(p1Name:match("%d+")), tonumber(p2Name:match("%d+"))
		id1, id2 = math.min(id1, id2), math.max(id1, id2)
	elseif isP1Binary and not isP2Binary then
		id1, id2 = p1Name:match("%(.+%)"), tonumber(p2Name:match("%d+"))
	elseif not isP1Binary and isP2Binary then
		id1, id2 = p2Name:match("%(.+%)"), tonumber(p1Name:match("%d+"))
	else
		local p1FirstCel, p2FirstCel = tonumber(p1Name:match("%d+")), tonumber(p2Name:match("%d+"))
		id1, id2 = p1Name:match("%(.+%)"), p2Name:match("%(.+%)")
		id1, id2 = p1FirstCel < p2FirstCel and id1 or id2, p1FirstCel < p2FirstCel and id2 or id1
	end

	return type.."("..id1.."|"..id2..")"
end

local function createInstances(vehicles)
	--[[
	Finds and creates instances of every celestial in scenario
	Returns celestials that need additional usage outside of this function
	Parameters:
		vehicles - the vehicle instances
	]]--
	--Reset/update variables
	celestials = {fixedDynamic = {}, dynamic = {}, static = {}}
	initial = {positions = {length = 0}, scale = {}}
	supernovae = {}

	local foundCelestials = findCelestials()
	--Stores all children to a parent
	local children = {}
	local binaries = {}

	for _, celestial in ipairs(foundCelestials) do
		local objData = celestial.obj

		local name = objData.name
		local objectType = objData.objectType
		local celestialType = name:gsub("_%d+", "")
		local class = objData.celestialClass
		local parent = objData.orbitingBody

		errorHandler.assertNil(objectType)
		errorHandler.assertTrue(
				not (objectType == "fixedDynamic" and not objData.path),
				"A fixedDynamic celestial requires a path"
		)

		local isPassive
		--The celestial gets preferential treatment over passivity
		if objData.passive then
			if tonumber(objData.passive) == 1 then
				passive = true
			else
				passive = false or passiveMode
			end
		else
			isPassive = passiveMode
		end

		local data = {name, celestialType, objData:getScale().x, objectType, parent, isPassive, objData.delayed or false, objData.axisTilt or "nil"}

		local instance
		if not class or class == "stable" then
			instance = ClassCelestial.new(unpack(data))
		elseif class == "unstable" then
			table.insert(data, objData.ferocity)
			instance = ClassCelestial.newUnstable(unpack(data))
		elseif class == "exotic" then
			instance = ClassCelestial.newExotic(unpack(data))
		elseif class == "supernova" then
			local supernovaData = {
				vehicles = vehicles,
				triggerType = objData.triggerType,
				timer = objData.timer and tonumber(objData.timer),
				explosionPower = objData.explosionPower and tonumber(objData.explosionPower)
			}

			table.insert(data, supernovaData)

			instance = ClassCelestial.newSupernova(unpack(data))

			table.insert(supernovae, instance)
		elseif class == "binary" then
			local systemName = convertToSystemName(name, parent)

			instance = ClassCelestial.new(unpack(data))

			if not binaries[systemName] then
				binaries[systemName] = {components = {}, orbitalFrequency = nil}
			end

			table.insert(binaries[systemName].components, instance)
			binaries[systemName].orbitalFrequency = binaries[systemName].orbitalFrequency or objData.orbitalFrequency

			--For systems orbiting each other
			local systemParent = objData.systemOrbitingBody
			if systemParent then
				local superSystemName = convertToSystemName(systemName, systemParent)
				if not binaries[superSystemName] then
					binaries[superSystemName] = {components = {}, orbitalFrequency = nil}
				end

				--Cannot store instance since they do not exist yet
				table.insert(binaries[superSystemName].components, systemName)
				binaries[superSystemName].orbitalFrequency = binaries[superSystemName].orbitalFrequency or objData.orbitalFrequency
			end
		end

		celestials[objectType][name] = instance

		--Add in children to parents
		if parent then
			if not children[parent] then
				children[parent] = {instance}
			else
				table.insert(children[parent], instance)
			end
		end
	end

	--Add a reference to each parent from the children
	for parent, childInstances in pairs(children) do
		local parentInstance = {}

		if parent:find("|") then
			-- parentInstance = systems[parent]
			goto skip
		else
			parentInstance = findCelestial(parent)
		end

		for _, childInstance in ipairs(childInstances) do
			parentInstance:addChild(childInstance)
		end

		::skip::
	end

	--Place into integer indexed table for sorting (since supersystems need to be setup after the sub-systems and so on)
	local binariesSorted = {}
	for systemName, system in pairs(binaries) do
		table.insert(binariesSorted, {name = systemName, components = system.components, orbitalFrequency = system.orbitalFrequency})
	end

	--Sorts based on the number of | in the system name, smallest amount first
	table.sort(binariesSorted, function(a, b)
			local _, c1 = a.name:gsub("|", "")
			local _, c2 = b.name:gsub("|", "")
			return c1 < c2
		end
	)

	--Binary systems need each other to work out some attributes
	for _, systemData in ipairs(binariesSorted) do
		local systemName = systemData.name
		local orbitalFrequency = systemData.orbitalFrequency
		local p1, p2 = unpack(systemData.components)

		--Indicates two systems are orbiting
		if type(p1) == "string" and type(p2) == "string" then
			p1, p2 = systems[p1], systems[p2]
		elseif not p2 then
			--Find the system this object is orbiting
			p2 = systems[p1:getParentCelestial()]
		end

		systems[systemName] = ClassBinarySystem.new(systemName, {p1, p2}, orbitalFrequency)
	end

	return binariesSorted
end

local function createCelestials(fullReset, vehicles, passive)
	--[[
	Creates the celestials in the scenario into objects
	Parameters:
		fullReset - whether this is a full reset
		vehicles  - the vehicle instances in the scenario
		passive   - whether the scenario is in passive mode
	]]--
	passiveMode = passive

	local binariesSorted = {}

	--When loading another scenario, the data here is still stored, so can be used for setting up
	if fullReset then
		binariesSorted = createInstances(vehicles)
	else
		resetCelestials()
	end

	local allCelestials = tableComp.merge(celestials.dynamic, tableComp.merge(celestials.fixedDynamic, celestials.static))
	local sortedCelestials = sortDependencies(tableComp.merge({}, allCelestials))

	setInitialConditions()

	for _, systemData in ipairs(binariesSorted) do
		systems[systemData.name]:initialise()
	end

	--Note: velocities need to be set after as to calculate this the positions
	--need to be setup beforehand
	setInitialVelocities(sortedCelestials)

	--Needs to happen after above functions as the celestials need to be positioned first
	if fullReset then
		--Add a reference to any celestial that will be affected by a supernova explosion
		for sName, supernova in pairs(supernovae) do
			local sPosition = supernova:getPosition()
			local effectRange = supernova:getEffectRange()

			local celestialsInRange = {}
			for cName, instance in pairs(allCelestials) do
				--Don't reference itself and a supernova only affects planets
				if sName ~= cName and instance:getType() == "planet" then
					if sPosition:getDistanceBetween(instance:getPosition()) <= effectRange then
						table.insert(celestialsInRange, instance)
					end
				end
			end

			supernova:setCelestialsWithinRange(celestialsInRange)
		end
	end
end

local function initCelestials()
	--[[
	'Preps' the celestials in world, such as by creating the path trails
	]]--
	--Flatten to a single table
	local allCelestials = tableComp.merge(celestials.dynamic, tableComp.merge(celestials.fixedDynamic, celestials.static))

	for _, systemInstance in pairs(systems) do
		--Systems should setup their component paths first, to avoid being overwritten
		systemInstance:setupComponentPaths()
	end

	for _, instance in pairs(allCelestials) do
		local parentName = instance:getParentCelestial()
		local parent
		if parentName then
			parent = systems[parentName] or allCelestials[parentName]
		end

		instance:setupPath(parent)
	end
end

local function update(start, vehicles, dt)
	--[[
	Updates all celestials in the scenario
	]]--
	if bullettime.get() > 0 then
		local attractVehicles = function(celestial, invert)
			--[[
			Attracts the player car to the celestial
			]]--
			--Even if the scenario/event is non-passive, a celestial can still be individually
			if not celestial:getPassivity() then
				for _, vehInstance in pairs(vehicles) do
					if not vehInstance:isImmune() then
						local forceOnPlayer = celestial:getForce(vehInstance)
						if invert then
							forceOnPlayer = forceOnPlayer:multiply(-1)
						end

						vehInstance:addWind(forceOnPlayer)
						celestial:handleCollision(vehInstance)
					end
				end
			end
		end

		local actualDt = dt * bullettime.get()

		--Dynamic celestials wait until the scenario start
		if start then
			for k, celestial1 in pairs(celestials.dynamic) do
				if not celestial1:isRemoved() then
					--Account for the possibility that the object has been destroyed previously
					--by another object
					if not celestial1:isMarkedForDestruction() then
						for k2, celestial2 in pairs(celestials.dynamic) do
							--Do not attract object to itself
							if k ~= k2 then
								if not celestial2:isMarkedForDestruction() and not celestial2:isRemoved() then
									local force = celestial1:getForce(celestial2)
									celestial1:applyForce(force, actualDt)
									celestial1:handleCollision(celestial2)
								end
							end
						end
					end

					if not passiveMode then
						attractVehicles(celestial1)
					end

					celestial1:update(actualDt)
				end
			end
		end

		for _, celestial in pairs(celestials.fixedDynamic) do
			if not celestial:isRemoved() then
				if start and not passiveMode then
					attractVehicles(celestial, true)
				end

				celestial:update(actualDt)
			end
		end

		for _, celestial in pairs(celestials.static) do
			if not celestial:isRemoved() then
				if start and not passiveMode then
					attractVehicles(celestial, true)
				end

				celestial:update(actualDt)
			end
		end

		for _, system in pairs(systems) do
			system:update(actualDt)
		end

		if start then
			for _, vehInstance in pairs(vehicles) do
				vehInstance:update(actualDt)
			end
		end

		-- if spectating then
		-- 	local pos = spectating:getPosition()
		-- 	local radius = spectating:getScaledRadius()
		-- 	camera:setPosition(vec3(pos:getX(), pos:getY(), pos:getZ() + 250):toPoint3F())
		-- end
	end
end

local function createSystem(systemName, components, orbitalFrequency)
	--[[
	Creates a new system and returns it
	Parameters:
		systemName       - the name of the system to create
		components       - the two components of the system
		orbitalFrequency - the orbital orbitalFrequency of the system (can be nil to calculate it)
	Returns:
		systemInst - the system instance
	]]--
	errorHandler.assertNil(systemName, components)
	errorHandler.assertTrue(#components == 2, "Components must be comprised of two components")

	local systemInst = ClassBinarySystem.new(systemName, components, orbitalFrequency)
	systemInst:initialise()
	systemInst:setupComponentPaths()
	--Add into the systems table for updating
	systems[systemName] = systemInst
	return systemInst
end

local function createCelestial(class, shapeName, initPos, name, type, scale, objectType, orbitingBody, passive, delayed, rotation, pathData)
	--[[
	Creates a new celestial
	Parameters:
		(See ClassCelestial)
	Returns:
		obj - the celestial instance
	]]--
	--Create the object
	if not scenetree.findObject(name) then
		if objectType == "static" then
			TorqueScript.eval([[
			new TSStatic(]]..(name)..[[) {
				shapeName = "levels/smallgrid/art/gravitationalRacing/celestialbodies/]]..shapeName..[[.dae";
				dynamic = "1";
				scale = "]]..scale..[[ ]]..scale..[[ ]]..scale..[[";
				objectType = "static";
				position = "]]..initPos:getX()..[[ ]]..initPos:getY()..[[ ]]..initPos:getZ()..[[";
				collisionType = "Visible Mesh Final";
				decalType = "Visible Mesh Final";
			};
			]])
		else
			TorqueScript.eval([[
			new TSStatic(]]..(name)..[[) {
				shapeName = "levels/smallgrid/art/gravitationalRacing/celestialbodies/]]..shapeName..[[.dae";
				dynamic = "1";
				scale = "]]..scale..[[ ]]..scale..[[ ]]..scale..[[";
				objectType = ]]..objectType..[[;
				position = "]]..initPos:getX()..[[ ]]..initPos:getY()..[[ ]]..initPos:getZ()..[[";
			};
			]])
		end
	end

	if type == "blackhole" then
		if not scenetree.findObject(name.."_disc") then
			TorqueScript.eval([[
			new TSStatic(]]..(name)..[[_disc) {
				shapeName = "levels/smallgrid/art/gravitationalRacing/celestialbodies/blackhole_discJets.dae";
				dynamic = "1";
				scale = "]]..scale..[[ ]]..scale..[[ ]]..scale..[[";
				position = "]]..initPos:getX()..[[ ]]..initPos:getY()..[[ ]]..initPos:getZ()..[[";
			};
			]])
		end
	end

	if orbitingBody then
		TorqueScript.eval(name..'.orbitingBody = "'..orbitingBody..'";')
	end

	if delayed then
		TorqueScript.eval(name..'.delayed = "'..tostring(delayed)..'";')
	end

	if pathData then
		for k, v in pairs(pathData) do
			TorqueScript.eval(name..'.'..k..' = "'..v..'";')
		end
	end

	--Create the associated instance
	local obj
	if class == "unstable" then
		--TODO add parameter ferocity
		obj = ClassCelestial.newUnstable(name, type, scale, objectType, orbitingBody, passive, delayed, rotation)
	elseif class == "exotic" then
		obj = ClassCelestial.newExotic  (name, type, scale, objectType, orbitingBody, passive, delayed, rotation)
	else
		obj = ClassCelestial.new        (name, type, scale, objectType, orbitingBody, passive, delayed, rotation)
	end

	obj:setPosition(initPos)
	--Add it into the table for updating
	celestials[objectType][name] = obj

	--Return a reference for use in another file
	return obj
end

local function deleteSystem(systemName)
	--[[
	Deletes a system
	Parameters:
		systemName - the system name
	]]--
	errorHandler.assertNil(systemName)

	local sysInstance = systems[systemName]
	if not sysInstance then
		log("I", "celestialHandler:deleteSystem()", "No system called "..systemName.."exists")
		return
	end

	sysInstance:delete()
end

local function deleteCelestialFromInst(instance)
	--[[
	Deletes a celestial, given its instance
	Parameters:
		instance - the celestial instance
	]]--
	errorHandler.assertNil(instance)

	celestials[instance:getObjectType()][instance:getName()] = nil
	instance:delete()
end

local function deleteCelestial(name, objectType)
	--[[
	Deletes a celestial
	Parameters:
		name       - the name of the celestial
		objectType - the object type of the celestial (optional for more efficient searching)
	]]--
	errorHandler.assertNil(name)

	if objectType then
		local instance = findCelestial(name, objectType)
		instance:delete()

		celestials[objectType][name] = nil
		return
	else
		for _, group in pairs(celestials) do
			local instance = group[name]
			if instance then
				instance:delete()
				group[name] = nil
				return
			end
		end
	end

	log("E", "gr:deleteCelestial()", "No celestial with name="..name.." exists to be deleted")
end

local function setSpectate(name, objectType)
	--[[
	Spectates an object
	NOTE: Experimental
	]]--
	spectating = findCelestial(name, objectType)
	commands.setFreeCamera()
	camera = commands.getCamera(commands.getGame())
end

local function createForceField()
	--[[
	Creates a force scale field, showing the strength of the gravitational force
	over an area
	]]--
	field.create(celestials)
end

local function removeAllCelestials()
	celestials = {fixedDynamic = {}, dynamic = {}, static = {}}
end

local function printResults()
	--[[
	A testing function for printing the various celestial related data it has created
	]]--
	print("\nCelestials: [Passive Mode = "..tostring(passiveMode).."]\n")
	local celestialInfo = {}
	local keys = ClassCelestial.toListKeys()

	for _, t in pairs(celestials) do
		for _, instance in pairs(t) do
			table.insert(celestialInfo, instance:toList())
		end
	end

	stringFormatter.printClassInfo(celestialInfo, keys)

	print("\nScenario running with factors:")
	print("  Distance Factor: "..factors.getDistanceScaleFactor())
	print("  Time Factor: "..factors.getTimeScaleFactor())
	print("  Radius Factor: "..factors.getActualRadiusScaleFactor().."\n")
end

M.findCelestial = findCelestial
M.findSystem = findSystem
M.systemNameToCelestials = systemNameToCelestials
M.findNextName = findNextName
-- M.findSystemMatch = findSystemMatch
M.findCelestialMatch = findCelestialMatch
M.callMethodOnCelestials = callMethodOnCelestials
M.getOrbitalVelocity = getOrbitalVelocity
M.startSupernovae = startSupernovae
M.convertToSystemName = convertToSystemName
-- M.enablePassiveMode = enablePassiveMode
-- M.disablePassiveMode = disablePassiveMode
M.createSystem = createSystem
M.createCelestials = createCelestials
M.initCelestials = initCelestials
M.update = update
M.createForceField = createForceField
M.createCelestial = createCelestial
M.deleteSystem = deleteSystem
M.deleteCelestialFromInst = deleteCelestialFromInst
M.deleteCelestial = deleteCelestial
M.setSpectate = setSpectate
M.removeAllCelestials = removeAllCelestials
M.printResults = printResults
return M
