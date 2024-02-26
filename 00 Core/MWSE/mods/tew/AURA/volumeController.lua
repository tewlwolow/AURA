-- Volume Wonderland - A place for everything volume-related --

local this = {}

local cellData = require("tew.AURA.cellData")
local common = require("tew.AURA.common")
local defaults = require("tew.AURA.defaults")
local modules = require("tew.AURA.modules")
local moduleData = modules.data
local soundData = require("tew.AURA.soundData")
local debugLog = common.debugLog

local MAX = 1
local MIN = 0

function this.setVolume(track, volume)
    local magicMaths = math.clamp(math.round(volume, 2), MIN, MAX)
    debugLog(string.format("Setting volume for track %s to %s", track.id, magicMaths))
    track.volume = magicMaths
end

function this.getModuleSoundConfig(moduleName)
    local mData = moduleData[moduleName]
    local cell = cellData.cell
    local weather = modules.getEligibleWeather(moduleName)

    if not mData or not weather or not cell then return {} end

    local soundConfig = mData.soundConfig or {}

    local rainType = cellData.rainType[weather]
    local exterior = cell and cell.isOrBehavesAsExterior and "exterior"
    local interior = cell and not cell.isOrBehavesAsExterior and "interior"
    local interiorType = interior and common.getInteriorType(cell)

    return (exterior and soundConfig[exterior])
        or (interior and soundConfig[interior])
        or (interiorType and soundConfig[interiorType] and soundConfig[interiorType][weather])
        or (rainType and soundConfig[rainType] and soundConfig[rainType][weather])
        or (soundConfig[weather])
        or {}
end

function this.getPitch(moduleName)
    local moduleSoundConfig = this.getModuleSoundConfig(moduleName)
    local pitch = moduleSoundConfig.pitch or MAX

    if cellData.playerUnderwater then pitch = 0.5 end

    debugLog(string.format("Got pitch for %s: %s", moduleName, pitch))
    return pitch
end

function this.getVolume(options)
    local volume = MAX
    local moduleName = options.module
    local mData = moduleData[moduleName]

    if not mData then
        debugLog("No module passed, returning max volume.")
        return volume
    end

    local config = options.config or mwse.loadConfig("AURA", defaults)
    local moduleVol = options.moduleVol or config.volumes.modules[moduleName].volume / 100
    local moduleSoundConfig = this.getModuleSoundConfig(moduleName)
    local weatherMult = moduleSoundConfig.mult or 1

    local weather = common.getWeather(cellData.cell, mData.weatherPreference)
    local isEligibleWeather = (modules.getEligibleWeather(moduleName) ~= nil)

    local interiorType = common.getInteriorType(cellData.cell)
    local windoorsMult = (mData.playWindoors == true) and 0.005 or 0

    if not isEligibleWeather then
        debugLog("[%s] Not an eligible weather: %s. Setting volume to %s.", moduleName, weather, MIN)
        volume = MIN
    else
        debugLog("[%s] moduleVol: %s | weather: %s | weatherMult: %s", moduleName, moduleVol, weather, weatherMult)
        volume = moduleVol * weatherMult
    end

    if cellData.cell then
        if cellData.cell.isInterior
            and (moduleName == "interiorWeather")
            and (interiorType == "sma")
            and common.isOpenPlaza(cellData.cell) then
            if isEligibleWeather and (weather == 6 or weather == 7) then
                volume = 0
            else
                debugLog("[%s] Applying open plaza volume boost.", moduleName)
                volume = math.min(volume + 0.2, 1)
                this.setVolume(tes3.getSound("Rain"), 0)
                this.setVolume(tes3.getSound("rain heavy"), 0)
            end
        end

        if not cellData.cell.isOrBehavesAsExterior then
            if (interiorType == "big") then
                local bigMult = config.volumes.modules[moduleName].big
                debugLog("[%s] Applying big interior mult: %s", moduleName, bigMult)
                volume = (bigMult * volume) - (windoorsMult * #cellData.windoors)
            elseif (interiorType == "sma") or (interiorType == "ten") then
                local smaMult = config.volumes.modules[moduleName].sma
                debugLog("[%s] Applying small interior mult: %s", moduleName, smaMult)
                volume = smaMult * volume
            end
        end
    else
        debugLog("[%s] No cell. Setting volume to %s.", moduleName, MIN)
        volume = MIN
    end

    if cellData.playerUnderwater then
        local undMult = config.volumes.modules[moduleName].und
        debugLog("[%s] Applying underwater nerf: %s", moduleName, undMult)
        volume = undMult * volume
    end

    volume = math.clamp(math.round(volume, 2), MIN, MAX)
    debugLog("Got volume for %s: %s", moduleName, volume)
    return volume
end

function this.adjustVolume(options)
    local moduleName = options.module
    local mData = moduleData[moduleName]
    local adjustAllWindoors = modules.getWindoorPlaying(moduleName) and not options.track and not options.reference
    local adjustAllExteriorDoors = modules.getExteriorDoorPlaying(moduleName) and not options.track and
    not options.reference
    local isTrackUnattached = options.track and not options.reference

    local playing = modules.getCurrentlyPlaying(moduleName) or {}
    local currentTrack, currentRef = table.unpack(playing)
    local targetTrack = options.track or currentTrack
    local targetRef = options.reference or currentRef
    local targetVolume = options.volume
    local inOrOut = options.inOrOut or ""
    local quiet = options.quiet

    local function adjust(track, ref)
        local attached = (track and ref) and tes3.getSoundPlaying { sound = track, reference = ref }
        local unattached = (track and not ref) and track:isPlaying()
        if not (attached or unattached) then return end

        local volume = targetVolume or this.getVolume(options)
        if not quiet then
            local msgPrefix = string.format("Adjusting volume %s", inOrOut):gsub("%s+$", "")
            debugLog(string.format("%s for module %s: %s -> %s | %.3f", msgPrefix, moduleName, track.id,
                ref or "(unattached)", volume))
        end
        if attached then
            tes3.adjustSoundVolume {
                sound = track,
                reference = ref,
                volume = volume,
            }
        elseif unattached then
            this.setVolume(track, volume)
        end
        if mData then moduleData[moduleName].lastVolume = volume end
    end

    if adjustAllWindoors then
        debugLog("Adjusting all windoors.")
        for _, windoor in ipairs(cellData.windoors) do
            if windoor ~= nil then adjust(modules.getTempDataEntry("track", windoor, moduleName) or targetTrack, windoor) end
        end
    elseif adjustAllExteriorDoors then
        debugLog("Adjusting all exterior doors.")
        for _, door in pairs(cellData.exteriorDoors) do
            if (door ~= nil) then adjust(modules.getTempDataEntry("track", door, moduleName) or targetTrack, door) end
        end
    elseif isTrackUnattached then
        adjust(targetTrack)
    else
        adjust(targetTrack, targetRef)
    end
end

function this.setConfigVolumes()
    local config = mwse.loadConfig("AURA", defaults)

    debugLog("Setting config weather volumes.")

    -- Vanilla weather loops
    for _, sound in pairs(soundData.weatherLoops) do
        local id = sound.id:lower()
        if id == "rain" or id == "rain heavy" then
            this.setVolume(sound, config.rainSounds and 0 or sound.volume)
        elseif id == "ashstorm" then
            this.setVolume(sound, config.volumes.extremeWeather["Ashstorm"] / 100)
        elseif id == "blight" then
            this.setVolume(sound, config.volumes.extremeWeather["Blight"] / 100)
        elseif id == "bm blizzard" then
            this.setVolume(sound, config.volumes.extremeWeather["Blizzard"] / 100)
        end
    end

    -- AURA rain loops
    for weatherName, data in pairs(soundData.rainLoops) do
        for rainType, track in pairs(data) do
            if track then
                this.setVolume(track, config.volumes.rain[weatherName][rainType] / 100)
            end
        end
    end
end

function this.printConfigVolumes()
    local config = mwse.loadConfig("AURA", defaults)
    debugLog("Printing config volumes.")
    for configKey, volumeTable in pairs(config.volumes) do
        if configKey == "modules" then
            for moduleName, moduleVol in pairs(volumeTable) do
                debugLog(string.format("[%s] vol: %s, big: %s, sma: %s, und: %s", moduleName, moduleVol.volume,
                    moduleVol.big, moduleVol.sma, moduleVol.und))
            end
        elseif configKey == "rain" then
            for weatherName, weatherData in pairs(volumeTable) do
                debugLog(string.format("[%s] light: %s, medium: %s, heavy: %s", weatherName, weatherData.light,
                    weatherData.medium, weatherData.heavy))
            end
        else
            for volumeTableKey, volumeTableValue in pairs(volumeTable) do
                debugLog(string.format("[%s] %s: %s", configKey, volumeTableKey, volumeTableValue))
            end
        end
    end
end

-- It wouldn't be wise to set config weather volumes while there are
-- ongoing fades for weather tracks. So make sure the fader.lua callback
-- for `load` takes precedence over this one.
event.register(tes3.event.load, this.setConfigVolumes, { priority = -5 })

return this
