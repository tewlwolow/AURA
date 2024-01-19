local data = require("tew.AURA.Ambient.Interior.interiorData")
local config = require("tew.AURA.config")
local sounds = require("tew.AURA.sounds")
local common = require("tew.AURA.common")
local cellData = require("tew.AURA.cellData")
local modules = require("tew.AURA.modules")
local findWholeWords = common.findWholeWords

local played = false
local moduleName = "interior"
local debugLog = common.debugLog

local cellLast

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
local function getEligibleCellType(cellType, NPCCount)
    if cellType and cellType ~= "" then
        if (cellType ~= "tom")
            and (data.names[cellType] or data.tavernNames[cellType])
            and (NPCCount) and (NPCCount < 2) then
            debugLog(string.format("Too few people inside for interior type %s: %s", cellType, NPCCount))
            return nil
        end
        return cellType
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
    else
        -- If we got this far let's recycle whatever might have been playing before for that module (useful for guild service travel etc.) --
        if cell ~= cellLast then sounds.removeImmediate { module = moduleName } end

        debugLog("Parsing interior cell: " .. cell.name)

        -- Use the same track that was playing on the door that was leading to this interior cell.
        -- But not the other way around, for more sound variety.
        local track
        for _, door in pairs(cellData.exteriorDoors) do
            if (door ~= nil) and (door.destination.cell == cell) then
                local doorTrack = modules.getExteriorDoorTrack(door)
                if doorTrack then
                    local doorIntOrExt = door.cell.isOrBehavesAsExterior and "Exterior" or "Interior"
                    debugLog(string.format("%s->Interior transition, using last known door track.", doorIntOrExt))
                    track = tes3.getSound(doorTrack.id:lower():gsub("^ie_", "i_"))
                    break
                end
            end
        end

        local NPCCount = common.getNPCCount(cell)
        local typeByArchitecture = getByArchitecture(5, cell)
        local typeByTavernName = getByTavernName(cell)
        local typeByName = getByName(cell)
        local typeByRace = getByRace(cell)

        local cellId = cell.id:lower()
        local cellType = getEligibleCellType(
            data.overrides[cellId]
                or typeByArchitecture
                or typeByTavernName
                or typeByName
                or typeByRace
            , NPCCount)

        if cellType then
            if not modules.getCurrentlyPlaying(moduleName) then
                debugLog("Found appropriate cell. Playing interior ambient sound for interior type: " .. cellType)
                sounds.playImmediate {
                    module = moduleName,
                    type = cellType,
                    track = track,
                }
            end
        else
            debugLog("Interior not eligible. Removing sounds.")
            sounds.removeImmediate { module = moduleName }
        end

        local modData = tes3.player.data.AURA

        if modData and modData.visitedInteriorCells then
            if not modData.visitedInteriorCells[cellId] then
                debugLog("Adding interior cell as visited: " .. cellId)
                modData.visitedInteriorCells[cellId] = {}
            end

            debugLog("Updating interior cell data: " .. cellId)
            modData.visitedInteriorCells[cellId].cellType = cellType
            modData.visitedInteriorCells[cellId].NPCCount = NPCCount
            modData.visitedInteriorCells[cellId].lastVisited = tes3.getSimulationTimestamp(true)
        end
    end
    cellLast = cell
end

-- Make sure any law-breakers, murderes and maniacs are covered.
-- Keep track of how many people are still inside. If not enough,
-- sounds will be removed and exterior doors won't play anymore.
local function deathCheck(e)
    local modData = tes3.player.data.AURA
    local cellId = cellData.cell and not cellData.cell.isOrBehavesAsExterior and cellData.cell.id:lower()
    local cellType = cellId and modData.visitedInteriorCells[cellId] and modData.visitedInteriorCells[cellId].cellType
    if getEligibleCellType(cellType)
        and not data.statics[cellType]
        and cellType ~= "tom"
        and e.reference
        and e.reference.baseObject.objectType == tes3.objectType.npc then
        debugLog("NPC died in appropriate interior, running cell check.")
        cellCheck()
    end
end

event.register("cellChanged", cellCheck, { priority = -200 })
event.register("weatherTransitionImmediate", cellCheck, { priority = -160 })
event.register("weatherChangedImmediate", cellCheck, { priority = -160 })
event.register("loaded", common.initModData, { priority = -150 })
event.register("death", deathCheck)
