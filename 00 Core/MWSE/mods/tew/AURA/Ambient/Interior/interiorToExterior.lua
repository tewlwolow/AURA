local data = require("tew.AURA.Ambient.Interior.interiorData")
local config = require("tew.AURA.config")
local sounds = require("tew.AURA.sounds")
local common = require("tew.AURA.common")
local cellData = require("tew.AURA.cellData")

local moduleName = "interiorToExterior"
local debugLog = common.debugLog

local exteriorTimer

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

local function cellCheck()
    local mp = tes3.mobilePlayer
    if (not mp) or (mp and (mp.waiting or mp.traveling)) then return end

    exteriorTimer:pause()

    local cell = tes3.getPlayerCell()
    if not cell then return end

    if cell.isInterior then table.clear(cellData.exteriorDoors) end

    local modData = tes3.player.data.AURA
    if not modData or not modData.visitedInteriorCells then return end

    debugLog("Searching for eligible doors.")

    for door in cell:iterateReferences(tes3.objectType.door) do
        if not (door.destination and door.destination.cell.isInterior and door.tempData) then
            goto nextDoor
        end
        local cellId = door.destination.cell.id:lower()
        local visitedCellData = modData.visitedInteriorCells[cellId]
        if (visitedCellData) and (visitedCellData.type) then
            debugLog("Parsing door destination cell: " .. cellId)
            -- Interior type is appropriate. But has something changed in
            -- the mean time? NPCs should have mobile objects attached now
            -- that the cell has been visited, so let's count them.
            local actorCount = common.getActorCount(door.destination.cell)
            if getEligibleCellType(visitedCellData.type, actorCount) then
                debugLog("Interior has been visited and is eligible.")
                if not door.tempData.tew then door.tempData.tew = {} end
                door.tempData.tew.interiorType = visitedCellData.type
                if not table.find(cellData.exteriorDoors, door) then
                    table.insert(cellData.exteriorDoors, door)
                end
            else
                debugLog("Interior has been visited, but is not eligible, skipping door.")
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
end

local function playExteriorDoors()
	if table.empty(cellData.exteriorDoors) then return end
	debugLog("Updating exterior doors.")
	local playerPos = tes3.player.position:copy()
	for _, door in pairs(cellData.exteriorDoors) do
		if door ~= nil and not sounds.getTrackPlaying(door.tempData.tew.track, door)
        and playerPos:distance(door.position:copy()) < 800 then
            -- Get new track every time we approach a door, for variety
            -- Unless we want to trade variety for ultra-realism
            -- Naaa, using the same track is boooorin'
            local track = sounds.getTrack{
                module = "interior",
                type = door.tempData.tew.interiorType,
            }
            sounds.playImmediate{
                module = moduleName,
                track = track,
                reference = door,
            }
            door.tempData.tew.track = track
		end
	end
end

local function onLoaded()
    if not exteriorTimer then
        exteriorTimer = timer.start{
            duration = 1,
            iterations = -1,
            callback = playExteriorDoors,
            type = timer.simulate
        }
    end
    exteriorTimer:pause()
end

local function onLoad()
    if exteriorTimer then exteriorTimer:pause() end
    table.clear(cellData.exteriorDoors)
end

event.register(tes3.event.load, onLoad)
event.register(tes3.event.cellChanged, cellCheck, { priority = -240 })
event.register(tes3.event.weatherChangedImmediate, cellCheck, { priority = -240 })

-- The `loaded` event callback in interiorMain.lua should always trigger first
-- because we need mod data to be inited before this module kicks in.
event.register(tes3.event.loaded, onLoaded, { priority = -200 })