local data = require("tew.AURA.Ambient.Interior.interiorData")
local config = require("tew.AURA.config")
local sounds = require("tew.AURA.sounds")
local common = require("tew.AURA.common")
local cellData = require("tew.AURA.cellData")
local modules = require("tew.AURA.modules")
local findWholeWords = common.findWholeWords
local interiorMusic = config.interiorMusic

local played = false
local musicPath, lastMusicPath
local moduleName = "interior"
local debugLog = common.debugLog

local cellLast

local disabledTaverns = config.disabledTaverns
local function isEnabled(cellName)
    if disabledTaverns[cellName] and disabledTaverns[cellName] == true then
        return false
    else
        return true
    end
end

local function getByArchitecture(maxCount, cell)
    local count = 0
    local typeCell
    for stat in cell:iterateReferences(tes3.objectType.static) do
        for cellType, typeArray in pairs(data.statics) do
            for _, statName in ipairs(typeArray) do
                if string.startswith(stat.object.id:lower(), statName) then
                    count = count + 1
                    typeCell = cellType
                    if count >= maxCount then
                        debugLog("Enough statics. Cell type: " .. typeCell)
                        return typeCell
                    end
                end
            end
        end
    end
end

local function getByName(cell)
    for cellType, nameTable in pairs(data.names) do
        for _, pattern in pairs(nameTable) do
            if findWholeWords(cell.name, pattern) then
                return cellType
            end
        end
    end
end

local function getByTavernName(cell)
    for race, taverns in pairs(data.tavernNames) do
        for _, pattern in ipairs(taverns) do
            if string.find(cell.name, pattern) then
                return race
            end
        end
    end
end

local function getByRace(cell)
    for npc in cell:iterateReferences(tes3.objectType.npc) do
        if (npc.object.class.id == "Publican"
            or npc.object.class.id == "T_Sky_Publican"
            or npc.object.class.id == "T_Cyr_Publican")
            and (npc.object.mobile and not npc.object.mobile.isDead) then

            local race = npc.object.race.id
            if race ~= "Imperial"
                and race ~= "Nord"
                and race ~= "Dark Elf" then
                race = "Dark Elf"
            end
            race = string.sub(race, 1, 3):lower()
            return race
        end
    end
end

-- See if the cell warrants populated sounds - or whether you killed them all, you bastard --
local function getEligibleCellType(cellType, actorCount)
    if cellType then
        if (data.names[cellType] or data.tavernNames[cellType])
        and (actorCount) and (actorCount < 2) then
            debugLog(string.format("Too few people inside for interior type %s: %s", cellType, actorCount))
            return nil
        end
        return cellType
    end
end

-- Music bit per culture --
local musicArrays = {
    ["imp"] = {},
    ["dar"] = {},
    ["nor"] = {},
}
local function playMusic()
    if not interiorMusic then return end
    lastMusicPath = musicPath
    --debugLog("Playing music track: "..musicPath)
    tes3.streamMusic {
        path = musicPath,
        situation = tes3.musicSituation.explore,
        --crossfade = 0,
    }
    played = true
end

local function stopMusic()
    if interiorMusic and played == true then
        debugLog("Removing music.")
        tes3.streamMusic {
            path = "tew\\AURA\\Special\\silence.mp3",
        }
        played = false
    end
end

-- Get music tracks from folders --
for folder in lfs.dir("Data Files\\Music\\tew\\AURA") do
    if folder ~= "Special" then
        for soundfile in lfs.dir("Data Files\\Music\\tew\\AURA\\" .. folder) do
            if soundfile and soundfile ~= ".." and soundfile ~= "." and string.endswith(soundfile, ".mp3") then
                local ok = pcall(table.insert, musicArrays[folder], soundfile)
                if not ok then goto continue end
                debugLog("Adding music file: " .. soundfile)
            end
            :: continue ::
        end
    end
end

local function cellCheck()

    -- Gets messy otherwise
    local mp = tes3.mobilePlayer
    if (not mp) or (mp and (mp.waiting or mp.traveling)) then
        return
    end


    local cell = tes3.getPlayerCell()

    -- Bugger off if we're not inside --
    if not (cell) or (cell.isOrBehavesAsExterior) then
        debugLog("Exterior cell. Removing player ref sound.")
        sounds.removeImmediate { module = moduleName }
        stopMusic()
    else
        -- If we got this far let's recycle whatever might have been playing before for that module (useful for guild service travel etc.) --
        if cell ~= cellLast then sounds.removeImmediate { module = moduleName } stopMusic() end

        debugLog("Parsing interior cell: " .. cell.name)

        -- Use the same track that was playing on the door that was leading to this interior cell.
        -- But not the other way around, for more sound variety.
        local track
        for _, door in pairs(cellData.exteriorDoors) do
            if (door ~= nil) and (door.destination.cell == cell) and (door.tempData.tew.track) then
                local doorIntOrExt = door.cell.isInterior and "Interior" or "Exterior"
                debugLog(string.format("%s->Interior transition, using last known door track.", doorIntOrExt))
                track = door.tempData.tew.track
                break
            end
        end

        local actorCount = common.getActorCount(cell)
        local typeByArchitecture = getByArchitecture(5, cell)
        local typeByTavernName = getByTavernName(cell)
        local typeByName = getByName(cell)
        local typeByRace = getByRace(cell)

        local cellType = typeByArchitecture or typeByTavernName or typeByName or typeByRace
        local isEligible = getEligibleCellType(cellType, actorCount)

        if isEligible then
            if not modules.getCurrentlyPlaying(moduleName) then
                debugLog("Found appropriate cell. Playing interior ambient sound for interior type: " .. cellType)
                sounds.playImmediate{
                    module = moduleName,
                    type = cellType,
                    track = track,
                }
            end
        else
            debugLog("Interior not eligible. Removing sounds.")
            sounds.removeImmediate { module = moduleName }
        end

        if interiorMusic and cell.name and not cell.behavesAsExterior and actorCount > 2 then
            if not isEnabled(cell.name) then
                debugLog("Tavern blacklisted: " .. cell.name .. ". Not playing music.")
                stopMusic()
            -- Do we want to stop music if say, we go on a killing spree inside a tavern until
            -- just the barmaid and that shady lizard in the corner are the only ones alive?
            -- Then just ditch the actorCount check above and uncomment below.
            --[[
            elseif actorCount < 3 then
                stopMusic()
            --]]
            else
                local race = typeByTavernName or typeByRace
                if race and not played then
                    while musicPath == lastMusicPath do
                        musicPath = "tew\\AURA\\" .. race .. "\\" .. musicArrays[race][math.random(1, #musicArrays[race])]
                    end
                    playMusic()
                end
            end
        end


        local cellId = cell.id:lower()
        local modData = tes3.player.data.AURA

        if not modData.visitedInteriorCells[cellId] then
            debugLog("Adding interior cell as visited: " .. cellId)
            modData.visitedInteriorCells[cellId] = {}
        end

        debugLog("Updating interior cell data: " .. cellId)
        modData.visitedInteriorCells[cellId].type = cellType
        modData.visitedInteriorCells[cellId].actorCount = actorCount
        modData.visitedInteriorCells[cellId].lastVisited = tes3.getSimulationTimestamp(true)
    end
    cellLast = cell
end

-- Make sure any law-breakers, murderes and maniacs are covered.
-- Keep track of how many people are still inside. If not enough,
-- sounds will be removed and exterior doors won't play anymore.
local function deathCheck(e)
    local modData = tes3.player.data.AURA
    local cellId = cellData.cell and cellData.cell.isInterior and cellData.cell.id:lower()
    local cellType = cellId and modData.visitedInteriorCells[cellId] and modData.visitedInteriorCells[cellId].type
    if cellType and not data.statics[cellType] and e.reference and e.reference.baseObject.objectType == tes3.objectType.npc then
        debugLog("NPC died in appropriate interior, running cell check.")
        cellCheck()
    end
end

event.register("cellChanged", cellCheck, { priority = -200 })
event.register("weatherTransitionImmediate", cellCheck, { priority = -160 })
event.register("weatherChangedImmediate", cellCheck, { priority = -160 })
event.register("loaded", common.initModData, { priority = -150 })
event.register("death", deathCheck)
if interiorMusic then
    event.register("musicSelectTrack", onMusicSelection)
end