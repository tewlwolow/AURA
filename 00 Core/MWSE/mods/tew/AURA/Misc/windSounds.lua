local cellData = require("tew.AURA.cellData")
local common = require("tew.AURA.common")
local config = require("tew.AURA.config")
local defaults = require("tew.AURA.defaults")
local modules = require("tew.AURA.modules")
local moduleData = modules.data
local sounds = require("tew.AURA.sounds")
local fader = require("tew.AURA.fader")
local moduleName = "wind"
local playInteriorWind = config.playInteriorWind
local windType, cell
local windTypeLast, cellLast
local interiorTimer, altitudeWindTimer
local MIN_ALT, MAX_ALT = 0, 15000 -- Maybe do lower for max. 15k is Red Mountain, rest of the world is considerably lower on average

local debugLog = common.debugLog

-- These have their own wind sounds --
local blockedWeathers = moduleData[moduleName].blockedWeathers

-- Determine wind type per cloud speed values, set in Watch the Skies --
local function getWindType(cSpeed)
    local cloudSpeed = cSpeed * 100
    if cloudSpeed < 150 then
        return "quiet"
    elseif cloudSpeed <= 320 then
        return "warm"
    elseif cloudSpeed <= 1800 then
        return "cold"
    else
        return nil
    end
end

local function updateAltitudeStats()
    local mp = tes3.mobilePlayer
    if not mp
    or mp.waiting
    or mp.sleeping
    or mp.traveling
    or not cellData.cell
    or not cellData.cell.isOrBehavesAsExterior then
        cellData.altitude = nil
        return
    end

    -- FIXME: Weird edge case I can't reproduce: negative z when ext->int when clearly above ground
    -- Occurred at Seyda Neen Lighthouse top entrance with collision off (tcl bug?)
    local altitude = mp.position:copy().z
    cellData.altitude = altitude
    if (not altitude) then return end
    local minVol = config.volumes.misc.altitudeWindVolMin / 100
    local maxVol = config.volumes.misc.altitudeWindVolMax / 100
    local min, max = minVol, maxVol
    if min > max then min = maxVol max = minVol end
    local vol = math.round(math.remap(math.clamp(altitude, MIN_ALT, MAX_ALT), MIN_ALT, MAX_ALT, min, max), 2)
    cellData.altitudeWindVolume = cellData.playerUnderwater and min or vol
end

local function updateConditions(resetInteriorTimerFlag)
	if resetInteriorTimerFlag
	and interiorTimer
	and not cell.isOrBehavesAsExterior
	and not table.empty(cellData.windoors) then
		interiorTimer:reset()
	end
    altitudeWindTimer:reset()
    windTypeLast = windType
    cellLast = cell
end

local function stopWindoors(immediateFlag)
    local remove = immediateFlag and sounds.removeImmediate or sounds.remove
    if not table.empty(cellData.windoors) then
        for _, windoor in ipairs(cellData.windoors) do
            local track = modules.getTempDataEntry("track", windoor, moduleName) or moduleData[moduleName].new
            if windoor ~= nil and common.getTrackPlaying(track, windoor) then
                remove { module = moduleName, track = track, reference = windoor }
            end
        end
    end
end

local function playWindoors()
    if table.empty(cellData.windoors) then return end
    debugLog("Updating interior doors and windows.")
    local playerPos = tes3.player.position:copy()
    
    for _, windoor in ipairs(cellData.windoors) do
        
        local track = modules.getTempDataEntry("track", windoor, moduleName)
        
        if windoor ~= nil and playerPos:distance(windoor.position:copy()) < 1800
        and not common.getTrackPlaying(track, windoor) then
            sounds.play {
                module = moduleName,
                track = track,
                reference = windoor,
                noQueue = true,
                noCrossfade = true,
            }
        end
    end
end

-- Resolve data and play or remove wind sounds --
local function windCheck(e)
    -- Gets messy otherwise --
    local mp = tes3.mobilePlayer
    if (not mp) or (mp and (mp.waiting or mp.traveling or mp.sleeping)) then
        return
    end

    debugLog("Cell changed or time check triggered. Running cell check.")

    -- Cell resolution --
    cell = tes3.getPlayerCell()
    if (not cell) then
		debugLog("No cell detected. Returning.")
        sounds.remove { module = moduleName }
		return
	end
	debugLog("Cell: " .. cell.editorName)

    -- Weather resolution --
    local regionObject = tes3.getRegion(true)
    if not regionObject then regionObject = common.getFallbackRegion() end
    local weather
    if e and e.to then
        debugLog("Weather transitioning.")
        weather = e.to
    else
        weather = regionObject.weather
    end

    debugLog("Weather: " .. weather.index)

    -- Bugger off if weather is blocked --
    if blockedWeathers[weather.index] then
        debugLog("Uneligible weather detected. Removing sounds.")
        stopWindoors(true)
        sounds.remove { module = moduleName }
        updateConditions()
        return
    end

    -- Get wind type after resolving clouds speed --
    local cloudsSpeed = weather.cloudsSpeed
    debugLog("Current clouds speed: " .. tostring(cloudsSpeed))
    windType = getWindType(cloudsSpeed)

    -- If it's super slow then bugger off, no sound for ya --
    if not windType then
        debugLog("Wind type is nil. Returning.")
        sounds.remove { module = moduleName }
        updateConditions()
        return
    end
    debugLog("Wind type: " .. windType)

    local useLast = (windType == windTypeLast) or false

    -- Transition filter chunk --
    -- TODO: don't call sounds.play when ext->ext in same region if same conditions. OA too.
    if (windType == windTypeLast)
    and (common.checkCellDiff(cell, cellLast) == false)
    and not (cell ~= cellLast) then
        debugLog("Same conditions. Returning.")
        updateConditions(true)
        return
    end
    if common.checkCellDiff(cell, cellLast) then
		debugLog("Cell type changed. Removing module sounds.")
		sounds.removeImmediate { module = moduleName }
	end

    if (windTypeLast ~= windType) or (cell ~= cellLast) then

        local track = sounds.getTrack{
            module = moduleName,
            type = windType,
            last = useLast,
        }

        debugLog(string.format("[#] old: %s | new: %s | useLast: %s | nextTrack: %s", moduleData[moduleName].old, moduleData[moduleName].new, useLast, track))

        if (config.altitudeWind) then
            updateAltitudeStats()
            debugLog("altitudeWindVolume: " .. tostring(cellData.altitudeWindVolume))
        end

        if (cell.isOrBehavesAsExterior) then
            -- Using the same track when entering int/ext in same area; time/weather change will randomise it again --
            debugLog(string.format("Found exterior cell. useLast: %s", useLast))
            sounds.play { module = moduleName, track = track, cell = cell, saveVolume = config.altitudeWind }
        else
            debugLog("Found interior cell.")
            stopWindoors(true)
            if (cell ~= cellLast) then
                sounds.removeImmediate { module = moduleName } -- Needed to catch previous interior cell sounds --
            end
            if not playInteriorWind then
                debugLog("Found interior cell and playInteriorWind off. Removing sounds.")
                sounds.removeImmediate { module = moduleName }
                updateConditions()
                return
            end
            if common.getCellType(cell, common.cellTypesSmall) == true
            or common.getCellType(cell, common.cellTypesTent) == true then
                debugLog(string.format("Found small interior cell. useLast: %s", useLast))
                sounds.play { module = moduleName, track = track, cell = cell }
            else
                debugLog("Found big interior cell.")
                if not table.empty(cellData.windoors) then
                    debugLog("Found " ..
                    #cellData.windoors .. " windoor(s). Playing interior loops. useLast: " .. tostring(useLast))
                    for _, windoor in ipairs(cellData.windoors) do
                        modules.setTempDataEntry("track", track, windoor, moduleName)
                    end
                    updateConditions(true)
                    return
                end
            end
        end
    end
    updateConditions()
    debugLog("Cell check complete.")
end

local function altitudeCheck()
    if cellData.playerUnderwater
    or fader.isRunning { module = moduleName }
    or common.isTimerAlive(moduleData[moduleName].nextTrackTimer)
    then
        return
    end

    local playing = modules.getCurrentlyPlaying(moduleName)
    local lastVol = moduleData[moduleName].lastVolume
    if not playing or not lastVol then return end

    updateAltitudeStats()
    local altitude = cellData.altitude
    local newVol = cellData.altitudeWindVolume

    if (altitude) and (newVol) and (newVol ~= lastVol) then
        debugLog(string.format("[altitudeWind] altitude: %s | newVol: %s", altitude, newVol))
        local track, ref = table.unpack(playing)
        local delta = math.abs(newVol - lastVol)
        fader.fade {
            module = moduleName,
            fadeType = (newVol < lastVol) and "out" or "in",
            track = track,
            reference = ref,
            volume = delta,
            duration = 3,
            saveVolume = true,
        }
    end
end

-- Pause interior timer on condition change trigger --
local function onConditionChanged(e)
    if interiorTimer then interiorTimer:pause() end
    if altitudeWindTimer then altitudeWindTimer:pause() end
    windCheck(e)
end

-- Check every half an hour --
local function runHourTimer()
    timer.start({ duration = 0.5, callback = windCheck, iterations = -1, type = timer.game })
end

-- Run hour timer, start and pause interiorTimer on loaded --
local function onLoaded()
    runHourTimer()
	if playInteriorWind then
		if not interiorTimer then
			interiorTimer = timer.start{
				duration = 1,
				iterations = -1,
				callback = playWindoors,
				type = timer.simulate
			}
		end
		interiorTimer:pause()
	end
    if config.altitudeWind then
        cellData.altitudeWindVolume = nil
        cellData.altitude = nil
        if not altitudeWindTimer then
            altitudeWindTimer = timer.start{
                duration = 1,
				iterations = -1,
				callback = altitudeCheck,
				type = timer.simulate
            }
        end
        altitudeWindTimer:pause()
    end
end

-- Waiting/travelling check --
local function waitCheck(e)
    local element = e.element
    element:registerAfter("destroy", function()
        timer.start {
            type = timer.game,
            duration = 0.01,
            callback = onConditionChanged
        }
    end)
end

-- Reset windoors when exiting underwater --
local function resetWindoors(e)
    if table.empty(cellData.windoors)
    or not playInteriorWind
    or not modules.getWindoorPlaying(moduleName) then
        return
    end
    if interiorTimer then interiorTimer:pause() end
    debugLog("Resetting windoors.")
    stopWindoors(true)
    if interiorTimer then interiorTimer:reset() end
end

-- Timer here so that sky textures can work ok... something fishy with weatherTransitionStarted event for sure --
local function transitionStartedWrapper(e)
    timer.start {
        duration = 1.5, -- Can be increased if not enough for sky texture pop-in
        type = timer.simulate, -- Switched to simulate b/c 0.1 duration is a bit too much if using timer.game along with a low timescale tes3globalVariable. E.g.: With a timescale of 10, a 0.1 timer.game timer will actually kick in AFTER weatherTransitionFinished, which is too late
        iterations = 1,
        callback = function()
            onConditionChanged(e)
        end
    }
end

local function runResetter()
    cell, cellLast, windType, windTypeLast = nil, nil, nil, nil
end

event.register("weatherChangedImmediate", onConditionChanged, { priority = -100 })
event.register("weatherTransitionImmediate", onConditionChanged, { priority = -100 })
event.register("weatherTransitionStarted", transitionStartedWrapper, { priority = -100 })
event.register("weatherTransitionFinished", onConditionChanged, { priority = -100 })
event.register("AURA:exitedUnderwater", resetWindoors, { priority = -100 })
event.register("loaded", onLoaded, { priority = -160 })
event.register("load", runResetter)
event.register("uiActivated", waitCheck, { filter = "MenuTimePass", priority = 10 })
event.register("cellChanged", onConditionChanged, { priority = -100 })
