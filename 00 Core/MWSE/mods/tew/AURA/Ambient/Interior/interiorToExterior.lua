local data = require("tew.AURA.Ambient.Interior.interiorData")
local config = require("tew.AURA.config")
local sounds = require("tew.AURA.sounds")
local common = require("tew.AURA.common")
local cellData = require("tew.AURA.cellData")

local moduleName = "interiorToExterior"
local debugLog = common.debugLog

local exteriorTimer, cellLast

local function getEligibleCellType(cellType, actorCount)
    if cellType then
        if (data.names[cellType] or data.tavernNames[cellType])
            and (actorCount) and (actorCount < 2) then
            --debugLog(string.format("Too few people inside for interior type %s: %s", cellType, actorCount))
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
    if not modData or not modData.visitedInteriorCells then return end

    debugLog("Searching for eligible doors.")

    for door in cell:iterateReferences(tes3.objectType.door) do
        if not (door.destination and door.destination.cell and not door.destination.cell.isOrBehavesAsExterior and door.tempData) then
            goto nextDoor
        end
        local cellId = door.destination.cell.id:lower()
        local visitedCellData = modData.visitedInteriorCells[cellId]
        if (visitedCellData) and (visitedCellData.type) and (visitedCellData.lastVisited) then
            local now = tes3.getSimulationTimestamp(true)
            local last = visitedCellData.lastVisited

            debugLog("Parsing door destination cell: " .. cellId)
            debugLog(string.format("Last time visited: %.5f game hours ago.", (now - last)))

            if not door.tempData.tew then door.tempData.tew = {} end
            if not door.tempData.tew.AURA then door.tempData.tew.AURA = {} end
            if not door.tempData.tew.AURA.IE then door.tempData.tew.AURA.IE = {} end
            door.tempData.tew.AURA.IE.interiorType = visitedCellData.type
            door.tempData.tew.AURA.IE.actorCount = visitedCellData.actorCount
            door.tempData.tew.AURA.IE.lastVisited = visitedCellData.lastVisited
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
            local tempData = door.tempData.tew and door.tempData.tew.AURA and door.tempData.tew.AURA.IE
            if not tempData then goto continue end
            local doorTrack = common.getTrackPlaying(tempData.track, door)
            local now = tes3.getSimulationTimestamp(true)
            local last = tempData.lastVisited
            local interiorType = tempData.interiorType
            local actorCount
            if (last) and (now - last) >= 72 then
                actorCount = tempData.actorCount
            else
                actorCount = common.getActorCount(door.destination.cell)
            end
            local isEligible = getEligibleCellType(interiorType, actorCount)
            local cellId = door.destination.cell.id:lower()
            if isEligible and not doorTrack then
                debugLog(string.format("Door destination is eligible, adding sound. | cellId: %s | actorCount: %s",
                    cellId, actorCount))
                -- Get new track every time we approach a door, for variety
                -- Unless we want to trade variety for ultra-realism
                -- Naaa, using the same track is boooorin'
                local track = sounds.getTrack {
                    module = moduleName,
                    type = interiorType,
                }
                sounds.playImmediate {
                    module = moduleName,
                    track = track,
                    reference = door,
                }
                door.tempData.tew.AURA.IE.track = track
            elseif not isEligible and doorTrack then
                debugLog(string.format("Door destination is not eligible, removing sound. | cellId: %s | actorCount: %s",
                    cellId, actorCount))
                sounds.removeImmediate {
                    module = moduleName,
                    track = doorTrack,
                    reference = door,
                }
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
