local mode = select(1, ...)

-- TODO: error on invalid metadata or animation list

local usage = [[
Valid arguments:

animations animations_list_source_path animations_include_destination_path

dependencies animations_list_source_path entity_skin_source_directory_path entity_skin_destination_directory_path

build animations_list_source_path entity_skin_source_directory_path entity_skin_destination_directory_path
]]

local tileSize = math.tointeger(8 * 8 * 2 / 8) -- width * height * bits per pixel / bits per byte
local metasprite2x2Size = tileSize * 2 * 2

local function exitError(message)
	if not message:find("\n$") then -- Enforce terminating line break
		message = message .. "\n"
	end
	io.stderr:write(message)
	os.exit(false)
end

local function exitAssert(condition, message)
	if not condition then
		exitError(message)
	end
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

local function reverseByte(byteValue)
	local ret = byteValue
	ret = (ret & 0xF0) >> 4 | (ret & 0x0F) << 4
	ret = (ret & 0xCC) >> 2 | (ret & 0x33) << 2
	ret = (ret & 0xAA) >> 1 | (ret & 0x55) << 1
	return ret
end

local function flip2x2Metasprite(data)
	local ret = ""
	local getTileAhead = false -- Gets flipped immediately
	for i = 1, #data do
		if (i - 1) % tileSize == 0 then
			getTileAhead = not getTileAhead
		end
		local indexToUse = getTileAhead and i + tileSize or i - tileSize
		local inByte = string.byte(data:sub(indexToUse, indexToUse))
		local append = reverseByte(inByte)
		ret = ret .. string.char(append)
	end
	return ret
end

local function constructInfoByteString(flagsTable)
	local foundTrue = false
	for _, v in pairs(flagsTable) do
		if v then
			foundTrue = true
			break
		end
	end
	if not foundTrue then
		return "0"
	end
	-- At least one flag will appear

	local ret = ""
	if flagsTable.flipped then
		ret = ret .. "ENTITY_SKIN_METASPRITE_FLAGS_FLIPPED_MASK |"
	end

	ret = ret:sub(1, -3) -- Remove terminating " |"
	return ret
end

local function getAnimations(animationsListSourcePath)
	-- Name used for by name is snake case name

	local asArray, byName = {}, {}
	local i = 0

	local animationsListSourceFile = io.open(animationsListSourcePath, "r")
	exitAssert(animationsListSourceFile, "Could not open file " .. animationsListSourcePath .. " for reading")
	for line in animationsListSourceFile:lines() do
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
	local animationsListSourcePath = select(2, ...)
	local animationsIncludeDestinationPath = select(3, ...)

	local animationsAsArray = getAnimations(animationsListSourcePath)

	local animationsIncludeDestinationString =
		"RSRESET\n\n" ..
		"SECTION \"Animation Type Table\", ROM0\n\n" ..
		"AnimationTypeTable::\n"
	for i, animation in ipairs(animationsAsArray) do
		if i > 256 then
			exitError("Too many animations! Ids are not 8-bit (limit is 256)")
		end
		animationsIncludeDestinationString = animationsIncludeDestinationString ..
			indentString .. "DEF ANIM_TYPE_ID_" .. animation.nameScreamingCase .. " RB\n" ..
			indentString .. "DEF ANIM_FRAMES_" .. animation.nameScreamingCase .. " EQU " .. animation.frames .. "\n" ..
			indentString .. "DEF ANIM_SPEED_" .. animation.nameScreamingCase .. " EQU " .. animation.speed .."\n" ..
			indentString .. "EXPORT ANIM_TYPE_ID_" .. animation.nameScreamingCase .. "\n" ..
			indentString .. "EXPORT ANIM_FRAMES_" .. animation.nameScreamingCase .. "\n" ..
			indentString .. "EXPORT ANIM_SPEED_" .. animation.nameScreamingCase .. "\n" ..
			indentString .. "db ANIM_FRAMES_" .. animation.nameScreamingCase .. ", ANIM_SPEED_" .. animation.nameScreamingCase .. "\n\n"
	end
	animationsIncludeDestinationString = animationsIncludeDestinationString:sub(1, -2) -- Remove one of the double trailing newlines

	local animationsIncludeDestinationFile = io.open(animationsIncludeDestinationPath, "w+")
	exitAssert(animationsIncludeDestinationFile, "Could not open file " .. animationsIncludeDestinationPath .. " for writing")
	animationsIncludeDestinationFile:write(animationsIncludeDestinationString)
	animationsIncludeDestinationFile:close()
elseif mode == "dependencies" then
	local animationsListSourcePath = select(2, ...)
	local entitySkinSourceDirectoryPath = select(3, ...)
	local entitySkinDestinationDirectoryPath = select(4, ...)

	-- Ensure trailing slash for direcory paths
	if not entitySkinSourceDirectoryPath:find("/$") then
		entitySkinSourceDirectoryPath = entitySkinSourceDirectoryPath .. "/"
	end
	if not entitySkinDestinationDirectoryPath:find("/$") then
		entitySkinDestinationDirectoryPath = entitySkinDestinationDirectoryPath .. "/"
	end

	local entitySkinMetadataSourcePath = entitySkinSourceDirectoryPath .. "metadata.txt"
	local entitySkinDependenciesDestinationPath = entitySkinDestinationDirectoryPath .. "dependencies.mk"

	local _, animationsByName = getAnimations(animationsListSourcePath)

	local entitySkinDependenciesDestinationString = ""

	local lineNumber = 1
	local entitySkinMetadataSourceFile = io.open(entitySkinMetadataSourcePath, "r")
	exitAssert(entitySkinMetadataSourceFile, "Could not open file " .. entitySkinMetadataSourcePath .. " for reading")
	for line in entitySkinMetadataSourceFile:lines() do
		local words = {}
		for word in line:gmatch("%S+") do
			words[#words + 1] = word
		end

		if lineNumber > 1 then
			local animationName = words[1]
			exitAssert(animationsByName[animationName], "Animation " .. animationName .. " does not exist. Is it in the right case (snake_case)?")
			entitySkinDependenciesDestinationString = entitySkinDependenciesDestinationString ..
				entitySkinDestinationDirectoryPath .. "include.inc " .. entitySkinDestinationDirectoryPath .. "graphics.2bpp: " ..
				entitySkinDestinationDirectoryPath .. animationName .. ".2bpp\n"
		end

		lineNumber = lineNumber + 1
	end
	
	local entitySkinDependenciesDestinationFile = io.open(entitySkinDependenciesDestinationPath, "w+")
	exitAssert(entitySkinDependenciesDestinationFile, "Could not open file " .. entitySkinDependenciesDestinationPath .. " for writing")
	entitySkinDependenciesDestinationFile:write(entitySkinDependenciesDestinationString)
	entitySkinDependenciesDestinationFile:close()
elseif mode == "build" then
	local animationsListSourcePath = select(2, ...)
	local entitySkinSourceDirectoryPath = select(3, ...)
	local entitySkinDestinationDirectoryPath = select(4, ...)

	-- Ensure trailing slash for direcory paths
	if not entitySkinSourceDirectoryPath:find("/$") then
		entitySkinSourceDirectoryPath = entitySkinSourceDirectoryPath .. "/"
	end
	if not entitySkinDestinationDirectoryPath:find("/$") then
		entitySkinDestinationDirectoryPath = entitySkinDestinationDirectoryPath .. "/"
	end

	local entitySkinMetadataSourcePath = entitySkinSourceDirectoryPath .. "metadata.txt"
	local entitySkinIncludeDestinationPath = entitySkinDestinationDirectoryPath .. "include.inc"
	local entitySkinIncludeDestinationString = ""

	local animationsAsArray, animationsByName = getAnimations(animationsListSourcePath)

	local byAnimationTableLabel, graphicsDataLabel
	local pascalCaseEntityName, screamingCaseEntityGfxName

	local presentAnimationNames = {}
	local highestAnimationIndex = nil
	local lineNumber = 1
	local entitySkinMetadataSourceFile = io.open(entitySkinMetadataSourcePath, "r")
	exitAssert(entitySkinMetadataSourceFile, "Could not open file " .. entitySkinMetadataSourcePath .. " for reading")
	for line in entitySkinMetadataSourceFile:lines() do
		local words = {}
		for word in line:gmatch("%S+") do
			words[#words + 1] = word
		end

		if lineNumber == 1 then
			pascalCaseEntityName = words[1]
			screamingCaseEntityGfxName = words[2]

			byAnimationTableLabel = "x" .. pascalCaseEntityName .. "EntitySkinPointersByAnimation"
			graphicsDataLabel = "x" .. pascalCaseEntityName .. "EntitySkinGraphicsData"

			entitySkinIncludeDestinationString = entitySkinIncludeDestinationString ..
				"DEF ENTITY_SKIN_" .. screamingCaseEntityGfxName .. " RB\n" ..
				"EXPORT ENTITY_SKIN_" .. screamingCaseEntityGfxName .. "\n\n" ..
				"SECTION FRAGMENT \"Entity Skins Pointer Table\", ROM0\n\n" ..
				indentString .. "db BANK(" .. byAnimationTableLabel .. ")\n" ..
				indentString .. "dw " .. byAnimationTableLabel .. "\n\n" ..
				"SECTION \"" .. pascalCaseEntityName .. " Entity Skin\", ROMX\n\n" ..
				byAnimationTableLabel .. ":\n"
		else
			-- Animations
			local animationName = words[1]
			exitAssert(animationsByName[animationName], "Animation " .. animationName .. " does not exist. Is it in the right case (snake_case)?")
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

	local entitySkinGraphicsDataString = ""

	local addressesAndInfo, metaspriteAddresses = {}, {}

	for _, animation in ipairs(animationsAsArray) do
		if animation.index > highestAnimationIndex then
			break
		end
		if presentAnimationNames[animation.nameSnakeCase] then
			local animationSpritesheetPath = entitySkinDestinationDirectoryPath .. animation.nameSnakeCase .. ".2bpp"
			local animationSpritesheetFile = io.open(animationSpritesheetPath, "rb")
			exitAssert(animationSpritesheetFile, "Could not open file " .. animationSpritesheetPath .. " for reading")
			local animationSpritesheetData = animationSpritesheetFile:read("a")
			animationSpritesheetFile:close()
			local index = #addressesAndInfo + 1
			local addressesAndInfoThisAnimation = {
				animationName = animation.nameSnakeCase,
				index = index,
				frames = {}
			}
			addressesAndInfo[animation.nameSnakeCase] = addressesAndInfoThisAnimation
			addressesAndInfo[index] = addressesAndInfoThisAnimation
			local curAddress = #entitySkinGraphicsDataString
			for frame = 0, animation.frames - 1 do
				local addressesAndInfoThisFrame = {}
				for directionName, directionIndex in directions() do
					local rowSize = #directionNames * tileSize * 2
					local topLeftTileOffset = tileSize * 2 * directionIndex + frame * rowSize * 2
					local bottomLeftTileOffset = topLeftTileOffset + rowSize
					local topRightTileOffset = topLeftTileOffset + tileSize
					local bottomRightTileOffset = topRightTileOffset + rowSize
					local metasprite =
						animationSpritesheetData:sub(topLeftTileOffset + 1, topLeftTileOffset + tileSize) ..
						animationSpritesheetData:sub(bottomLeftTileOffset + 1, bottomLeftTileOffset + tileSize) ..
						animationSpritesheetData:sub(topRightTileOffset + 1, topRightTileOffset + tileSize) ..
						animationSpritesheetData:sub(bottomRightTileOffset + 1, bottomRightTileOffset + tileSize)
					local flipped = flip2x2Metasprite(metasprite)
					if metaspriteAddresses[metasprite] then
						addressesAndInfoThisFrame[directionName] = {infoByte = {
							flipped = false
						}, offset = metaspriteAddresses[metasprite]}
					elseif metaspriteAddresses[flipped] then
						addressesAndInfoThisFrame[directionName] = {infoByte = {
							flipped = true
						}, offset = metaspriteAddresses[flipped]}
					else
						entitySkinGraphicsDataString = entitySkinGraphicsDataString .. metasprite
						addressesAndInfoThisFrame[directionName] = {infoByte = {
							flipped = false
						}, offset = curAddress}
						metaspriteAddresses[metasprite] = curAddress
						curAddress = curAddress + metasprite2x2Size
					end
				end
				addressesAndInfoThisAnimation.frames[frame] = addressesAndInfoThisFrame
			end
		end
	end

	local entitySkinGraphicsDataPath = entitySkinDestinationDirectoryPath .. "graphics.2bpp"
	local entitySkinGraphicsDataFile = io.open(entitySkinGraphicsDataPath, "w+b")
	exitAssert(entitySkinGraphicsDataFile, "Could not open file " .. entitySkinGraphicsDataPath .. " for writing")
	entitySkinGraphicsDataFile:write(entitySkinGraphicsDataString)
	entitySkinGraphicsDataFile:close()

	for _, animation in ipairs(animationsAsArray) do
		if animation.index > highestAnimationIndex then
			break
		end
		if presentAnimationNames[animation.nameSnakeCase] then
			entitySkinIncludeDestinationString = entitySkinIncludeDestinationString ..
				indentString .. "dw x" .. pascalCaseEntityName .. "GraphicsPointers" .. animation.namePascalCase .. "\n"
		else
			entitySkinIncludeDestinationString = entitySkinIncludeDestinationString ..
				indentString .. "dw 0\n" -- Null pointer
		end
	end

	entitySkinIncludeDestinationString = entitySkinIncludeDestinationString .. "\n"

	for _, animation in ipairs(animationsAsArray) do
		if animation.index > highestAnimationIndex then
			break
		end
		if presentAnimationNames[animation.nameSnakeCase] then
			entitySkinIncludeDestinationString = entitySkinIncludeDestinationString ..
				"x" .. pascalCaseEntityName .. "GraphicsPointers" .. animation.namePascalCase .. ":\n"
			for frame = 0, animation.frames - 1 do
				entitySkinIncludeDestinationString = entitySkinIncludeDestinationString ..
					indentString .. "dw .frame" .. frame .. "\n"
			end
			for frame = 0, animation.frames - 1 do
				entitySkinIncludeDestinationString = entitySkinIncludeDestinationString ..
					".frame" .. frame .. ":\n"
				for directionName in directions() do
					local addressAndInfo = addressesAndInfo[animation.nameSnakeCase].frames[frame][directionName]
					entitySkinIncludeDestinationString = entitySkinIncludeDestinationString ..
						indentString .. "db " .. constructInfoByteString(addressAndInfo.infoByte) .. "\n" ..
						indentString .. "dw " .. graphicsDataLabel .. " + " .. addressAndInfo.offset .. "\n"
				end
			end
			entitySkinIncludeDestinationString = entitySkinIncludeDestinationString .. "\n"
		end
	end

	entitySkinIncludeDestinationString = entitySkinIncludeDestinationString ..
		graphicsDataLabel .. ":\n" ..
		"INCBIN \"" .. entitySkinDestinationDirectoryPath .. "graphics.2bpp\"\n"

	local entitySkinIncludeDestinationFile = io.open(entitySkinIncludeDestinationPath, "w+")
	exitAssert(entitySkinIncludeDestinationFile, "Could not open file " .. entitySkinIncludeDestinationPath .. " for writing")
	entitySkinIncludeDestinationFile:write(entitySkinIncludeDestinationString)
	entitySkinIncludeDestinationFile:close()
else
	exitError(usage)
end
