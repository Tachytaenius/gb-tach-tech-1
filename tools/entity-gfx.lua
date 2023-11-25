local mode = select(1, ...)

-- TODO: exitError on more cases!

local usage = [[
Valid arguments:

animations animations-data-path-in animations-data-path-out

dependencies animations-data-path-in entity-data-path-in entity-graphics-directory-path-out

build animations-data-path-in entity-data-path-in entity-graphics-directory-path-out
]]

local tileSize = math.tointeger(8*8*2/8) -- width * height * bits per pixel / bits per byte
local metasprite2x2Size = tileSize * 4

local function exitError(message)
	io.stderr:write(message)
	os.exit(false)
end

local indentString = "\t"

-- Convenient iterator
local directionNames = {"right", "down", "left", "up"}
local function directions()
	local i = 1
	return function()
		local directionName = directionNames[i]
		if not directionName then
			return
		end
		i = i + 1
		return directionName, i - 1 - 1 -- One subtraction for starting at 0, another to cancel the increment
	end
end

local function getAnimations(animationsDataPath)
	-- Name used for by name is snake case name

	local asArray, byName = {}, {}
	local i = 0

	for line in io.lines(animationsDataPath) do
		local words = {}
		for word in line:gmatch("%S+") do
			words[#words + 1] = word
		end

		local animation = {
			index = i,
			nameSnakeCase = words[1], -- For filenames
			namePascalCase = words[2], -- For assembly labels
			nameScreamingCase = words[3], -- For assembly constants
			frames = tonumber(words[4]),
			speed = tonumber(words[5])
		}

		asArray[#asArray + 1] = animation -- #asArray + 1 == i + 1
		byName[animation.nameSnakeCase] = animation

		i = i + 1
	end

	return asArray, byName
end

if mode == "animations" then
	local animationsDataPath = select(2, ...)
	local animationIncPath = select(3, ...)

	local animationsAsArray = getAnimations(animationsDataPath)

	local animationIncString =
		"RSRESET\n\n" ..
		"SECTION \"Animation Type Table\", ROM0\n\n" ..
		"AnimationTypeTable::\n"
	for i, animation in ipairs(animationsAsArray) do
		if i > 256 then
			exitError("Too many animations! Ids are not 8-bit (limit is 256)")
		end
		animationIncString = animationIncString ..
			indentString .. "DEF ANIM_TYPE_ID_" .. animation.nameScreamingCase .. " RB\n" ..
			indentString .. "DEF ANIM_FRAMES_" .. animation.nameScreamingCase .. " EQU " .. animation.frames .. "\n" ..
			indentString .. "DEF ANIM_SPEED_" .. animation.nameScreamingCase .. " EQU " .. animation.speed .."\n" ..
			indentString .. "EXPORT ANIM_TYPE_ID_" .. animation.nameScreamingCase .. "\n" ..
			indentString .. "EXPORT ANIM_FRAMES_" .. animation.nameScreamingCase .. "\n" ..
			indentString .. "EXPORT ANIM_SPEED_" .. animation.nameScreamingCase .. "\n" ..
			indentString .. "db ANIM_FRAMES_" .. animation.nameScreamingCase .. ", ANIM_SPEED_" .. animation.nameScreamingCase .. "\n\n"
	end
	animationIncString = animationIncString:sub(1, -2) -- Remove one of the double trailing newlines

	local animationIncFile = io.open(animationIncPath, "w+")
	animationIncFile:write(animationIncString)
	animationIncFile:close()
elseif mode == "dependencies" then
	local animationsDataPath = select(2, ...)
	local entityGraphicsInputDirectoryPath = select(3, ...)
	local entityGraphicsOutputDirectoryPath = select(4, ...)

	-- Ensure trailing slash for direcory paths
	if not entityGraphicsInputDirectoryPath:find("/$") then
		entityGraphicsInputDirectoryPath = entityGraphicsInputDirectoryPath .. "/"
	end
	if not entityGraphicsOutputDirectoryPath:find("/$") then
		entityGraphicsOutputDirectoryPath = entityGraphicsOutputDirectoryPath .. "/"
	end

	local entityGraphicsDataPath = entityGraphicsInputDirectoryPath .. "data.txt"
	local entityGraphicsDependenciesPath = entityGraphicsOutputDirectoryPath .. "dependencies.mk"

	local _, animationsByName = getAnimations(animationsDataPath)

	local entityGraphicsDependenciesString = ""

	local lineNumber = 1
	for line in io.lines(entityGraphicsDataPath) do
		local words = {}
		for word in line:gmatch("%S+") do
			words[#words + 1] = word
		end

		if lineNumber > 1 then
			local animationName = words[1]
			assert(animationsByName[animationName], "Animation " .. animationName .. " does not exist. Is it in the right case (snake_case)?")
			entityGraphicsDependenciesString = entityGraphicsDependenciesString ..
				entityGraphicsOutputDirectoryPath .. "include.inc " .. entityGraphicsOutputDirectoryPath .. "graphics.2bpp: " .. entityGraphicsOutputDirectoryPath .. animationName .. ".2bpp\n"
		end

		lineNumber = lineNumber + 1
	end
	
	local entityGraphicsDependenciesFile = io.open(entityGraphicsDependenciesPath, "w+")
	entityGraphicsDependenciesFile:write(entityGraphicsDependenciesString)
	entityGraphicsDependenciesFile:close()
elseif mode == "build" then
	local animationsDataPath = select(2, ...)
	local entityGraphicsInputDirectoryPath = select(3, ...)
	local entityGraphicsOutputDirectoryPath = select(4, ...)

	-- Ensure trailing slash for direcory paths
	if not entityGraphicsInputDirectoryPath:find("/$") then
		entityGraphicsInputDirectoryPath = entityGraphicsInputDirectoryPath .. "/"
	end
	if not entityGraphicsOutputDirectoryPath:find("/$") then
		entityGraphicsOutputDirectoryPath = entityGraphicsOutputDirectoryPath .. "/"
	end

	local entityGraphicsDataPath = entityGraphicsInputDirectoryPath .. "data.txt"
	local entityGraphicsIncludePath = entityGraphicsOutputDirectoryPath .. "include.inc"
	local entityGraphicsIncludeString = ""

	local animationsAsArray, animationsByName = getAnimations(animationsDataPath)

	local byAnimationTableLabel, graphicsDataLabel
	local pascalCaseEntityName, screamingCaseEntityGfxName

	local presentAnimationNames = {}
	local highestAnimationIndex = nil
	local lineNumber = 1
	for line in io.lines(entityGraphicsDataPath) do
		local words = {}
		for word in line:gmatch("%S+") do
			words[#words + 1] = word
		end

		if lineNumber == 1 then
			pascalCaseEntityName = words[1]
			screamingCaseEntityGfxName = words[2]

			byAnimationTableLabel = "x" .. pascalCaseEntityName .. "EntityGraphicsPointersByAnimation"
			graphicsDataLabel = "x" .. pascalCaseEntityName .. "EntityGraphicsData"

			entityGraphicsIncludeString = entityGraphicsIncludeString ..
				"DEF ENTITY_GFX_TYPE_" .. screamingCaseEntityGfxName .. " RB\n" ..
				"EXPORT ENTITY_GFX_TYPE_" .. screamingCaseEntityGfxName .. "\n\n" ..
				"SECTION FRAGMENT \"Entity Graphics Pointer Table\", ROM0\n\n" ..
				indentString .. "db BANK(" .. byAnimationTableLabel .. ")\n" ..
				indentString .. "dw " .. byAnimationTableLabel .. "\n\n" ..
				"SECTION \"" .. pascalCaseEntityName .. " Entity Graphics\", ROMX\n\n" ..
				byAnimationTableLabel .. ":\n"
		else
			-- Animations
			local animationName = words[1]
			assert(animationsByName[animationName], "Animation " .. animationName .. " does not exist. Is it in the right case (snake_case)?")
			local animationIndex = animationsByName[animationName].index
			if highestAnimationIndex then
				highestAnimationIndex = math.max(highestAnimationIndex, animationIndex)
			else
				highestAnimationIndex = animationIndex
			end
			presentAnimationNames[animationName] = true
		end
		lineNumber = lineNumber + 1
	end

	local graphicsData = ""

	local addresses, sprites = {}, {}

	for _, animation in ipairs(animationsAsArray) do
		if animation.index > highestAnimationIndex then
			break
		end
		if presentAnimationNames[animation.nameSnakeCase] then
			local animationSpritesheetPath = entityGraphicsOutputDirectoryPath .. animation.nameSnakeCase .. ".2bpp"
			local animationSpritesheetFile = io.open(animationSpritesheetPath, "rb")
			local animationSpritesheetData = animationSpritesheetFile:read("a")
			animationSpritesheetFile:close()
			local index = #addresses + 1
			local addressesThisAnimation = {
				animationName = animation.nameSnakeCase,
				index = index,
				frames = {}
			}
			addresses[animation.nameSnakeCase] = addressesThisAnimation
			addresses[index] = addressesThisAnimation
			local curAddress = #graphicsData
			for frame = 0, animation.frames - 1 do
				local addressThisFrame = {}
				for directionName, directionIndex in directions() do
					local rowSize = #directionNames * tileSize * 2
					local topTilesStartOffset = tileSize * 2 * directionIndex + frame * rowSize * 2
					local topTilesEndOffset = topTilesStartOffset + tileSize * 2
					local bottomTilesStartOffset = topTilesStartOffset + rowSize
					local bottomTilesEndOffset = topTilesEndOffset + rowSize
					graphicsData = graphicsData ..
						animationSpritesheetData:sub(topTilesStartOffset + 1, topTilesEndOffset) ..
						animationSpritesheetData:sub(bottomTilesStartOffset + 1, bottomTilesEndOffset)

					addressThisFrame[directionName] = curAddress
					curAddress = curAddress + metasprite2x2Size
				end
				addressesThisAnimation.frames[frame] = addressThisFrame
			end
		end
	end

	local graphicsDataPath = entityGraphicsOutputDirectoryPath .. "graphics.2bpp"
	local graphicsDataFile = io.open(graphicsDataPath, "w+b")
	graphicsDataFile:write(graphicsData)
	graphicsDataFile:close()

	for _, animation in ipairs(animationsAsArray) do
		if animation.index > highestAnimationIndex then
			break
		end
		if presentAnimationNames[animation.nameSnakeCase] then
			entityGraphicsIncludeString = entityGraphicsIncludeString ..
				indentString .. "dw x" .. pascalCaseEntityName .. "GraphicsPointers" .. animation.namePascalCase .. "\n"
		else
			entityGraphicsIncludeString = entityGraphicsIncludeString ..
				indentString .. "dw 0\n" -- Null pointer
		end
	end

	entityGraphicsIncludeString = entityGraphicsIncludeString .. "\n"

	for _, animation in ipairs(animationsAsArray) do
		if animation.index > highestAnimationIndex then
			break
		end
		if presentAnimationNames[animation.nameSnakeCase] then
			entityGraphicsIncludeString = entityGraphicsIncludeString ..
				"x" .. pascalCaseEntityName .. "GraphicsPointers" .. animation.namePascalCase .. ":\n"
			for frame = 0, animation.frames - 1 do
				entityGraphicsIncludeString = entityGraphicsIncludeString ..
					indentString .. "dw .frame" .. frame .. "\n"
			end
			for frame = 0, animation.frames - 1 do
				entityGraphicsIncludeString = entityGraphicsIncludeString ..
					".frame" .. frame .. ":\n"
				for directionName in directions() do
					local offset = addresses[animation.nameSnakeCase].frames[frame][directionName]
					entityGraphicsIncludeString = entityGraphicsIncludeString ..
						indentString .. "dw " .. graphicsDataLabel .. " + " .. offset .. " ; " .. directionName .. "\n"
				end
			end
			entityGraphicsIncludeString = entityGraphicsIncludeString .. "\n"
		end
	end

	entityGraphicsIncludeString = entityGraphicsIncludeString ..
		graphicsDataLabel .. ":\n" ..
		indentString .. "INCBIN \"" .. entityGraphicsOutputDirectoryPath .. "graphics.2bpp\"\n"

	local entityGraphicsIncludeFile = io.open(entityGraphicsIncludePath, "w+")
	entityGraphicsIncludeFile:write(entityGraphicsIncludeString)
	entityGraphicsIncludeFile:close()
else
	exitError(usage)
end
