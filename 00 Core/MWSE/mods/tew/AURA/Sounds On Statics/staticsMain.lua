local cellData = require("tew.AURA.cellData")
local common = require("tew.AURA.common")
local config = require("tew.AURA.config")
local modules = require("tew.AURA.modules")
local moduleData = modules.data
local sounds = require("tew.AURA.sounds")
local soundData = require("tew.AURA.soundData")
local fader = require("tew.AURA.fader")
local staticsData = require("tew.AURA.Sounds On Statics.staticsData")
local volumeController = require("tew.AURA.volumeController")
local getVolume = volumeController.getVolume
local debugLog = common.debugLog

local raining
local playingBlocked = false
local rainOnStaticsBlocked = false
local weatherVolumeDelta = 0
local INTERVAL = 0.55

local currentShelter = cellData.currentShelter
local staticsCache = cellData.staticsCache

local bridgeStatics = staticsData.modules["ropeBridge"].ids
local rainyStatics = staticsData.modules["rainOnStatics"].ids
local shelterStatics = staticsData.shelterStatics

local mainTimer


---------------------------------------------------------------------
local function playing(sound, ref)
    return common.getTrackPlaying(sound, ref)
end
local function play(moduleName, sound, ref)
    sounds.play { module = moduleName, newTrack = sound, newRef = ref }
end
local function playImmediate(moduleName, sound, ref)
    sounds.playImmediate { module = moduleName, track = sound, reference = ref }
end
local function remove(moduleName, ref)
    sounds.remove { module = moduleName, reference = ref }
end
local function removeImmediate(moduleName)
    sounds.removeImmediate { module = moduleName }
end
local function removeRefSound(ref)
    for _, track in pairs(soundData.interiorRainLoops["ten"]) do
        if playing(track, ref) then
            debugLog("Track " .. track.id .. " playing on ref " .. tostring(ref) .. ", now removing it.")
            tes3.removeSound { sound = track, reference = ref }
        end
    end
end
local function removeRainOnStatics()
    for _, ref in ipairs(staticsCache) do
        removeRefSound(ref)
    end
end
---------------------------------------------------------------------


local function runResetter()
    if mainTimer then mainTimer:reset() end
    table.clear(currentShelter)
    weatherVolumeDelta = 0
    cellData.isWeatherVolumeDynamic = false
end

local function restoreWeatherVolumes()
    if cellData.isWeatherVolumeDynamic then
        debugLog("[shelterWeather] Restoring original volumes for weather tracks.")
        fader.cancel("shelterWeather")
        volumeController.setConfigVolumes()
        weatherVolumeDelta = 0
        cellData.isWeatherVolumeDynamic = false
    end
end

local function fadeWeatherTrack(fadeType, track)
    if not (track and track:isPlaying()) then return end
    debugLog(("Fading %s weather track: %s"):format(fadeType, track.id))
    fader.fade {
        module = "shelterWeather",
        fadeType = fadeType,
        track = track,
        volume = weatherVolumeDelta,
    }
end

local function adjustWeatherVolume()
    local moduleName = "shelterWeather"

    if not modules.isActive(moduleName) then return end

    local weatherTrack = common.getWeatherTrack()
    local cw = common.getCurrentWeather()
    local weather = cw and cw.index

    local isNonVariableRain = weather
        and (weather == 4 or weather == 5)
        and not cellData.rainType[weather]

    local ready = weatherTrack and weather
        and not isNonVariableRain
        and not cellData.playerUnderwater

    if not ready then
        restoreWeatherVolumes()
        return
    end

    local mData = moduleData[moduleName]
    local sheltered = cellData.currentShelter.ref

    if (not cellData.isWeatherVolumeDynamic) and (sheltered) then
        local trackVolume = math.round(weatherTrack.volume, 2)
        weatherVolumeDelta = getVolume { module = moduleName, trackVolume = trackVolume }
        if (weatherVolumeDelta == 0) then return end
        mData.lastVolume = trackVolume
        fadeWeatherTrack("out", weatherTrack)
        cellData.isWeatherVolumeDynamic = true
    elseif (cellData.isWeatherVolumeDynamic) and (not sheltered) and (weatherVolumeDelta > 0) then
        fadeWeatherTrack("in", weatherTrack)
        local duration = mData.faderConfig["in"].duration
        timer.start { duration = duration + 0.2, callback = function() cellData.isWeatherVolumeDynamic = false end }
    end
end

local function playRainOnStatic(ref)
    local moduleName = "rainOnStatics"
    local sound = sounds.getTrack { module = moduleName }

    -- If this ref is a shelter and we're not playing rain _insde_ shelters
    -- then we're not going to play rain _on_ this ref either because the
    -- sound will be heard when the player does get sheltered by this ref
    local noShelterRain = ref and not modules.isActive("shelterRain")
        and common.getMatch(shelterStatics, ref.object.id:lower())


    local ready = ref and sound
        and not playing(sound, ref)
        and not noShelterRain
        and not cellData.playerUnderwater

    if not ready then return end

    -- Checking if this ref is sheltered as we approach it instead of only
    -- when being added to the cache is more expensive but more realistic
    -- because the ref might have changed location in the mean time
    if common.isRefSheltered {
            originRef = ref,
            ignoreList = staticsData.modules[moduleName].ignore,
            quiet = true,
        } then
        return
    end

    debugLog(string.format("[%s] Adding sound %s for -> %s", moduleName, sound.id, ref))

    playImmediate(moduleName, sound, ref)
end

local function playShelterRain()
    local moduleName = "shelterRain"

    if not modules.isActive(moduleName) then return end

    local shelter = cellData.currentShelter.ref
    local sound = sounds.getTrack { module = moduleName }

    if not (shelter and sound) then
        remove(moduleName)
        return
    end

    -- Don't want to hear shelter rain if this shelter is sheltered
    -- by something else. Awnings are exempted from this because RayTest
    -- results for awnings may return some false positives
    if not string.find("awning", shelter.object.id:lower()) then
        if common.isRefSheltered {
                originRef = shelter,
                ignoreList = staticsData.modules[moduleName].ignore,
                quiet = true,
            } then
            remove(moduleName)
            return
        end
    end

    if cellData.playerUnderwater then
        removeImmediate(moduleName)
        return
    end
    if modules.getCurrentlyPlaying(moduleName) then return end

    local doCrossfade = playing(sound, shelter) ~= nil
    debugLog(string.format("[%s] Playing rain track: %s | crossfade: %s", moduleName, sound.id, doCrossfade))

    if doCrossfade then remove("rainOnStatics", shelter) end
    play(moduleName, sound)
end

local function playShelterWind()
    local moduleName = "shelterWind"

    if not modules.isActive(moduleName) then return end

    local supportedShelterTypes = staticsData.modules[moduleName].ids
    local shelter = cellData.currentShelter.ref
    local isValidShelterType = shelter and common.getMatch(supportedShelterTypes, shelter.object.id:lower())
    local sound = sounds.getTrack { module = moduleName }
    local weather = modules.getEligibleWeather(moduleName)
    local weatherTrack = common.getWeatherTrack()

    local ready = isValidShelterType and sound and weather and weatherTrack
    if not ready then
        remove(moduleName)
        return
    end

    if cellData.playerUnderwater then
        removeImmediate(moduleName)
        return
    end
    if modules.getCurrentlyPlaying(moduleName) then return end

    debugLog(string.format("[%s] Playing track: %s", moduleName, sound.id))

    play(moduleName, sound)
end

local function playRopeBridge(ref)
    local moduleName = "ropeBridge"
    local sound = tes3.getSound("tew_ropebridge")

    if sound and not playing(sound, ref) then
        debugLog(string.format("[%s] Adding sound %s for -> %s", moduleName, sound.id, tostring(ref)))
        playImmediate(moduleName, sound, ref)
    end
end

local function playPhotodragons(ref)
    local moduleName = "photodragons"
    local sound = tes3.getSound("tew_photodragons")

    if sound and not playing(sound, ref) then
        debugLog(string.format("[%s] Adding sound %s for -> %s", moduleName, sound.id, tostring(ref)))
        playImmediate(moduleName, sound, ref)
    end
end




local function onInsideShelter()
    if config.playRainInsideShelter then playShelterRain() end
    if config.playWindInsideShelter then playShelterWind() end
    if config.shelterWeather then adjustWeatherVolume() end
end

local function onExitedShelter()
    remove("shelterRain")
    remove("shelterWind")
    adjustWeatherVolume()
end

local function onShelterDeactivated()
    removeImmediate("shelterRain")
    removeImmediate("shelterWind")
    restoreWeatherVolumes()
end

local function onConditionsNotMet()
    removeRainOnStatics()
    onShelterDeactivated()
end

local function isSafeRef(ref)
    -- We are interested in both statics and activators. Skipping location
    -- markers because they are invisible in-game. Also checking if
    -- the ref is deleted because even if they are, they get caught by
    -- cell:iterateReferences. As for ref.disabled, some mods disable
    -- instead of delete refs, but it's actually useful if used correctly.
    -- Gotta be extra careful not to call this function when a ref is
    -- deactivated, because its "disabled" property will be true.
    -- Also skipping refs with no implicit tempData tables because they're
    -- most likely not interesting to us. A location marker is one of them.

    return ref and ref.object
        and ((ref.object.objectType == tes3.objectType.static) or
            ((ref.object.objectType == tes3.objectType.activator)))
        and (not ref.object.isLocationMarker)
        and (not (ref.deleted or ref.disabled))
        and (ref.tempData)
end

-- Cheking to see whether this static should be processed by any of our modules --
local function isRelevantForModule(moduleName, ref)
    local data = staticsData.modules[moduleName]

    if common.getMatch(data.blocked, ref.object.id:lower()) then
        debugLog(string.format("[%s] Skipping blocked static: %s", moduleName, tostring(ref)))
        return false
    end
    if common.getMatch(data.ids, ref.object.id:lower()) then
        return true
    end

    return false
end

local function addToCache(ref)
    -- Resetting the timer on every add to kind of block it
    -- from running while the cache is being populated.
    if mainTimer then mainTimer:reset() end

    if common.cellIsInterior(ref.cell) or not isSafeRef(ref) then return end

    local relevantModule

    for moduleName in pairs(staticsData.modules) do
        if modules.isActive(moduleName) and isRelevantForModule(moduleName, ref) then
            relevantModule = moduleName
            break
        end
    end

    if not relevantModule then return end

    if not table.find(staticsCache, ref) then
        table.insert(staticsCache, ref)
        debugLog("Added static " .. tostring(ref) .. " to cache. staticsCache: " .. #staticsCache)
    else
        --debugLog("Already in cache: " .. tostring(ref))
    end
end

local function removeFromCache(ref)
    if mainTimer then mainTimer:reset() end
    if (#staticsCache == 0) then return end

    local index = table.find(staticsCache, ref)
    if not index then return end

    removeRefSound(ref)
    table.remove(staticsCache, index)

    if (currentShelter.ref)
        and (currentShelter.ref == ref) then
        debugLog("Current shelter deactivated.")
        onShelterDeactivated()
        currentShelter.ref = nil
    end

    debugLog("Removed static " .. tostring(ref) .. " from cache. staticsCache: " .. #staticsCache)
end

local function proximityCheck(ref)
    local playerPos = tes3.player.position:copy()
    local refPos = ref.position:copy()
    local objId = ref.object.id:lower()
    local isShelter = common.getMatch(shelterStatics, objId)
    local playerRef = tes3.player

    ------------------------ Shelter stuff --------------------------
    if (not currentShelter.ref)
        and (isShelter)
        and (playerPos:distance(refPos) < 280)
        and (common.isRefSheltered { targetRef = ref }) then
        debugLog("Player entered shelter.")
        currentShelter.ref = ref
        onInsideShelter()
        return
    end

    if (currentShelter.ref == ref)
        and (not common.isRefSheltered { originRef = playerRef, targetRef = ref }) then
        debugLog("Player exited shelter.")
        currentShelter.ref = nil
        onExitedShelter()
        return
    end
    -----------------------------------------------------------------

    ---------------------- Point of no return -----------------------

    if currentShelter.ref == ref then
        onInsideShelter()
    end

    ------------------------- Rainy statics -------------------------
    if modules.isActive("rainOnStatics") and raining
        and common.getMatch(rainyStatics, objId)
        and not currentShelter.ref
        and (playerPos:distance(refPos) < 800) then
        rainOnStaticsBlocked = false
        playRainOnStatic(ref)
    end
    -----------------------------------------------------------------

    --------------------------- Bridges -----------------------------
    if modules.isActive("ropeBridge")
        and common.getMatch(bridgeStatics, objId)
        and playerPos:distance(refPos) < 800 then
        playRopeBridge(ref)
    end
    --------------------------- Insects -----------------------------
    if modules.isActive("photodragons")
        and common.getMatch(staticsData.modules["photodragons"].ids, objId)
        and playerPos:distance(refPos) < 700 then
        playPhotodragons(ref)
    end
    -----------------------------------------------------------------
    --                            etc                              --
    -----------------------------------------------------------------
end


local function conditionsAreMet()
    return cellData.cell and cellData.cell.isOrBehavesAsExterior
end

local function tick()
    for moduleName in pairs(staticsData.modules) do
        if fader.isRunning { module = moduleName } then
            debugLog(string.format("Fader is running for module %s. Returning.", moduleName))
            return
        end
    end
    if conditionsAreMet() then
        playingBlocked = false
        raining = common.getRainLoopSoundPlaying()

        for _, ref in ipairs(staticsCache) do proximityCheck(ref) end

        if not raining and not rainOnStaticsBlocked then
            removeRainOnStatics()
            rainOnStaticsBlocked = true
        end
    elseif (not playingBlocked) then
        debugLog("Conditions not met. Removing statics sounds.")
        onConditionsNotMet()
        playingBlocked = true
        runResetter() -- Clear everything when not outside
    end
end

local function onReferenceActivated(e)
    addToCache(e.reference)
end

local function onReferenceDeactivated(e)
    removeFromCache(e.reference)
end

local function registerActivationEvents()
    event.register(tes3.event.referenceActivated, onReferenceActivated)
    event.register(tes3.event.referenceDeactivated, onReferenceDeactivated)
end

local function unregisterActivationEvents()
    event.unregister(tes3.event.referenceActivated, onReferenceActivated)
    event.unregister(tes3.event.referenceDeactivated, onReferenceDeactivated)
end

-- Unmodified references will not trigger `referenceActivated`
-- when loading a save that's in the same cell as the player
local function refreshCache()
    if mainTimer then mainTimer:pause() end
    local activeCells = tes3.getActiveCells()
    for cell in tes3.iterate(activeCells) do
        if cell.isOrBehavesAsExterior then
            for ref in cell:iterateReferences() do
                addToCache(ref)
            end
        end
    end
    debugLog("staticsCache currently holds " .. #staticsCache .. " statics.")
    if mainTimer then mainTimer:reset() end
end

local function onWeatherTransitionFinished()
    if mainTimer then mainTimer:pause() end
    debugLog("[weatherTransitionFinished] Resetting all sounds.")
    -- Remove all sounds and refresh the cache. If the weather has
    -- changed, we want all the sounds that are currently playing
    -- to update according to the new weather type.
    removeRainOnStatics()
    onExitedShelter()
    restoreWeatherVolumes()
    refreshCache()
end

local function onLoaded()
    unregisterActivationEvents()
    runResetter()
    refreshCache()
    registerActivationEvents()
    debugLog("Starting timer.")
    if mainTimer then
        mainTimer:reset()
    else
        mainTimer = timer.start {
            type = timer.simulate,
            duration = INTERVAL,
            iterations = -1,
            callback = tick,
        }
    end
end


event.register(tes3.event.weatherTransitionFinished, onWeatherTransitionFinished)
event.register(tes3.event.load, runResetter)

-- Make sure rainSounds.lua does its thing first, so lower priority here
event.register(tes3.event.loaded, onLoaded, { priority = -250 })
