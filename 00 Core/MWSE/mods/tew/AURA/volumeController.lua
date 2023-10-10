-- Volume Wonderland - A place for everything volume-related --

local this = {}

local cellData = require("tew.AURA.cellData")
local common = require("tew.AURA.common")
local defaults = require("tew.AURA.defaults")
local moduleData = require("tew.AURA.moduleData")
local soundData = require("tew.AURA.soundData")
local debugLog = common.debugLog

local MAX = 1
local MIN = 0

function this.setVolume(track, volume)
    local magicMaths = math.round(volume, 2)
    debugLog(string.format("Setting volume for track %s to %s", track.id, magicMaths))
    track.volume = magicMaths
end

function this.getVolume(moduleName, conf)
    local volume = MAX
    local config = conf or mwse.loadConfig("AURA", defaults)
    local moduleVol = config.volumes.modules[moduleName].volume / 100
    local soundConfig = moduleData[moduleName].soundConfig
    local interiorType = common.getInteriorType(cellData.cell)
    local regionObject = tes3.getRegion(true)
    if not regionObject then regionObject = common.getFallbackRegion() end
    local weather = regionObject.weather.index
    local rainType = cellData.rainType[weather] or "light"
    local windoorsMult = (moduleData[moduleName].playWindoors == true) and 0.005 or 0
    if cellData.cell.isInterior and (moduleName == "interiorWeather") then
        volume = soundConfig[interiorType][weather].mult * moduleVol
        if (interiorType == "sma") and common.isOpenPlaza(cellData.cell) then
            debugLog("Applying open plaza volume boost.")
            volume = math.min(volume + 0.2, 1)
            this.setVolume(tes3.getSound("Rain"), 0)
            this.setVolume(tes3.getSound("rain heavy"), 0)
        end
    elseif moduleName == "rainOnStatics" then
        if weather == 4 or weather == 5 then
         volume = soundConfig[rainType][weather].mult * moduleVol
        else
            volume = 0
        end
    else
        volume = moduleVol
    end

    if cellData.cell.isInterior then
        if (interiorType == "big") then
            volume = (config.volumes.modules[moduleName].big * volume) - (windoorsMult * #cellData.windoors)
        elseif (interiorType == "sma") or (interiorType == "ten") then
            volume = config.volumes.modules[moduleName].sma * volume
        end
    end

    if (not cellData.cell.isInterior) or (cellData.cell.behavesAsExterior) then
        if moduleData[moduleName].playUnderwater and cellData.playerUnderwater then
            volume = config.volumes.modules[moduleName].und * volume
        end
    end

    volume = math.max(math.floor(volume * 100) / 100, 0)
    debugLog(string.format("Got volume for %s: %s", moduleName, volume))
    return volume
end

function this.adjustVolume(options)
    local moduleName = options.module
    local track = options.track or moduleData[moduleName].new
    local targetRef = options.reference
    local targetVolume = options.volume
    local config = options.config
    local inOrOut = options.inOrOut or ""
    local function adjust(reference)
        if not (track and reference) then return end
        if tes3.getSoundPlaying{sound = track, reference = reference} then
            local volume = targetVolume or this.getVolume(moduleName, config)
            local msgPrefix = string.format("Adjusting volume %s", inOrOut):gsub("%s+$", "")
            debugLog(string.format("%s for module %s: %s -> %s | %.2f", msgPrefix, moduleName, track.id, tostring(reference), volume))
            tes3.adjustSoundVolume{
                sound = track,
                reference = reference,
                volume = volume,
            }
            moduleData[moduleName].lastVolume = volume
        end
    end
    local function adjustAllWindoors()
        debugLog("Adjusting all windoors.")
        for _, windoor in ipairs(cellData.windoors) do
            adjust(windoor)
        end
    end

    if targetRef then
        adjust(targetRef)
    elseif moduleData[moduleName].playWindoors and not table.empty(cellData.windoors) then
        adjustAllWindoors()
    else
        adjust(moduleData[moduleName].newRef)
    end
end

function this.setConfigVolumes()
    local config = mwse.loadConfig("AURA", defaults)
    local vanillaRain = tes3.getSound("Rain")
    local vanillaStorm = tes3.getSound("rain heavy")
    local ashstorm = tes3.getSound("ashstorm")
    local blight = tes3.getSound("Blight")
    local blizzard = tes3.getSound("BM Blizzard")
    debugLog("Setting config volumes.")
    if config.rainSounds then
        debugLog("Using variable rain sounds.")
        if vanillaRain then this.setVolume(vanillaRain, 0) end
        if vanillaStorm then this.setVolume(vanillaStorm, 0) end
    end
    for weatherName, data in pairs(soundData.rainLoops) do
        for rainType, track in pairs(data) do
            if track then
                this.setVolume(track, config.volumes.rain[weatherName][rainType] / 100)
            end
        end
    end
    if ashstorm then this.setVolume(ashstorm, config.volumes.extremeWeather["Ashstorm"] / 100) end
    if blight then this.setVolume(blight, config.volumes.extremeWeather["Blight"] / 100) end
    if blizzard then this.setVolume(blizzard, config.volumes.extremeWeather["Blizzard"] / 100) end
end

function this.printConfigVolumes()
    local config = mwse.loadConfig("AURA", defaults)
    debugLog("Printing config volumes.")
    for configKey, volumeTable in pairs(config.volumes) do
        if configKey == "modules" then
            for moduleName, moduleVol in pairs(volumeTable) do
                debugLog(string.format("[%s] vol: %s, big: %s, sma: %s, und: %s", moduleName, moduleVol.volume, moduleVol.big, moduleVol.sma, moduleVol.und))
            end
        elseif configKey == "rain" then
            for weatherName, weatherData in pairs(volumeTable) do
                debugLog(string.format("[%s] light: %s, medium: %s, heavy: %s", weatherName, weatherData.light, weatherData.medium, weatherData.heavy))
            end
        else
            for volumeTableKey, volumeTableValue in pairs(volumeTable) do
                debugLog(string.format("[%s] %s: %s", configKey, volumeTableKey, volumeTableValue))
            end
        end
    end
end

event.register(tes3.event.load, this.setConfigVolumes)

return this