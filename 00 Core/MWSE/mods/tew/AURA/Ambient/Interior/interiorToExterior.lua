local data = require("tew.AURA.Ambient.Interior.interiorData")
local config = require("tew.AURA.config")
local sounds = require("tew.AURA.sounds")
local common = require("tew.AURA.common")
local cellData = require("tew.AURA.cellData")
local modules = require("tew.AURA.modules")

local moduleName = "interiorToExterior"
local debugLog = common.debugLog

local exteriorTimer, cellLast

local function getEligibleCellType(cellType, NPCCount)
    if cellType and cellType ~= "" then
        if (cellType ~= "tom") and (data.names[cellType] or data.tavernNames[cellType])
            and (NPCCount) and (NPCCount < 2) then
            --debugLog("Too few people inside for interior type %s: %s", cellType, NPCCount)
            return nil
        end
        return cellType
    end
end

local function cellCheck()
    local mp = tes3.mobilePlayer
    if (not mp) or (mp and (mp.waiting or mp.traveling)) then return end

    exteriorTimer:pause()

    local cell = tes3.getPlayerCell()
    if not cell then return end

    if (not cell.isOrBehavesAsExterior)
        or (cellLast and not cellLast.isOrBehavesAsExterior and cell.isOrBehavesAsExterior) then
        table.clear(cellData.exteriorDoors)
    end

    local modData = tes3.player.data.AURA

    debugLog("Searching for eligible doors.")

    for door in cell:iterateReferences(tes3.objectType.door) do
        if not (door.destination and door.destination.cell and not door.destination.cell.isOrBehavesAsExterior and door.tempData) then
            goto nextDoor
        end
        local cellId = door.destination.cell.id:lower()
        local visitedInteriorCellData = modData and modData.visitedInteriorCells and modData.visitedInteriorCells[cellId]
        local interiorCellData = visitedInteriorCellData or data.preprocessed[cellId]

        if not interiorCellData then
            goto nextDoor
        end

        -- Not checking for NPC count eligibility here because we're doing it on timer check
        local cellType = getEligibleCellType(data.overrides[cellId] or interiorCellData.cellType)
        if cellType then
            debugLog('Parsing door: "%s" | destination cell: %s', door, cellId)

            if interiorCellData.lastVisited then
                local now = tes3.getSimulationTimestamp(true)
                local last = interiorCellData.lastVisited
                debugLog("Last time visited: %.5f game hours ago.", (now - last))
            end

            modules.setTempDataEntry("cellType", cellType, door, moduleName)
            modules.setTempDataEntry("NPCCount", interiorCellData.NPCCount, door, moduleName)
            modules.setTempDataEntry("lastVisited", interiorCellData.lastVisited, door, moduleName)

            if not table.find(cellData.exteriorDoors, door) then
                table.insert(cellData.exteriorDoors, door)
            end
        end
        :: nextDoor ::
    end

    if #cellData.exteriorDoors > 0 then
        debugLog("Tracking " .. #cellData.exteriorDoors .. " door(s). Resuming exterior timer.")
        exteriorTimer:reset()
    else
        debugLog("Found none of interest.")
    end
    cellLast = cell
end

local function playExteriorDoors()
    if table.empty(cellData.exteriorDoors) then return end
    debugLog("Updating exterior doors.")
    local playerPos = tes3.player.position:copy()
    for _, door in pairs(cellData.exteriorDoors) do
        if door ~= nil and door.destination.cell
            and playerPos:distance(door.position:copy()) < 800 then
            local tempData = modules.getTempData(door, modules.data[moduleName].tempDataKey)
            if not tempData then goto continue end
            local doorTrack = common.getTrackPlaying(tempData.track, door)
            local now = tes3.getSimulationTimestamp(true)
            local last = tempData.lastVisited
            local cellType = tempData.cellType
            local NPCCount
            if (last) and (now - last) >= 72 then
                NPCCount = tempData.NPCCount
            else
                NPCCount = last and common.getNPCCount(door.destination.cell) or tempData.NPCCount
            end
            local isEligible = getEligibleCellType(cellType, NPCCount)
            local cellId = door.destination.cell.id:lower()
            if isEligible and not doorTrack then
                debugLog('Door destination is eligible, adding sound. | door: "%s" | cellId: %s | NPCCount: %s',
                    door, cellId, NPCCount)
                -- Get new track every time we approach a door, for variety
                -- Unless we want to trade variety for ultra-realism
                -- Naaa, using the same track is boooorin'
                local track = sounds.getTrack {
                    module = moduleName,
                    type = cellType,
                }
                sounds.playImmediate {
                    module = moduleName,
                    track = track,
                    reference = door,
                }
                modules.setTempDataEntry("track", track, door, moduleName)
            elseif not isEligible and doorTrack then
                debugLog('Door destination is not eligible, removing sound. | door: "%s" | cellId: %s | NPCCount: %s',
                    door, cellId, NPCCount)
                sounds.removeImmediate {
                    module = moduleName,
                    track = doorTrack,
                    reference = door,
                }
                modules.unsetTempDataEntry("track", door, moduleName)
            end
        end
        :: continue ::
    end
end

local function runResetter()
    if exteriorTimer then exteriorTimer:pause() end
    table.clear(cellData.exteriorDoors)
    cellLast = nil
end

local function onLoaded()
    runResetter()
    if not exteriorTimer then
        exteriorTimer = timer.start {
            duration = 1,
            iterations = -1,
            callback = playExteriorDoors,
            type = timer.simulate,
        }
    end
    exteriorTimer:pause()
end

event.register(tes3.event.load, runResetter)
event.register(tes3.event.cellChanged, cellCheck, { priority = -240 })
event.register(tes3.event.weatherChangedImmediate, cellCheck, { priority = -240 })

-- The `loaded` event callback in interiorMain.lua should always trigger first
-- because we need mod data to be inited before this module kicks in.
event.register(tes3.event.loaded, onLoaded, { priority = -200 })
