local config = require("tew.AURA.config")
local cellData = require("tew.AURA.cellData")
local common = require("tew.AURA.common")
local debugLog = common.debugLog

local this = {}

this.data = {
    ["outdoor"] = {
        active = config.moduleAmbientOutdoor,
        old = nil,
        new = nil,
        oldRefHandle = nil,
        newRefHandle = nil,
        nextTrack = nil,
        nextTrackTimer = nil,
        tempDataKey = "OUT",
        lastVolume = nil,
        playWindoors = true,
        playUnderwater = true,
        blockedWeathers = {
            [5] = true,
            [6] = true,
            [7] = true,
            [9] = true,
        },
        soundConfig = {
            ["big"] = {
                [0] = { pitch = 0.8 },
                [1] = { pitch = 0.8 },
                [2] = { pitch = 0.78 },
                [3] = { pitch = 0.79 },
                [4] = { pitch = 0.79 },
                [8] = { pitch = 0.82 },
            },
            ["sma"] = {
                [0] = { pitch = 0.85 },
                [1] = { pitch = 0.85 },
                [2] = { pitch = 0.83 },
                [3] = { pitch = 0.82 },
                [4] = { pitch = 0.8 },
                [8] = { pitch = 0.87 },
            },
            ["ten"] = {
                [0] = { pitch = 0.85 },
                [1] = { pitch = 0.85 },
                [2] = { pitch = 0.83 },
                [3] = { pitch = 0.82 },
                [4] = { pitch = 0.8 },
                [8] = { pitch = 0.87 },
            },
            ["exterior"] = { pitch = 1.0 },
        },
        faderConfig = { ["out"] = { duration = 5.0 }, ["in"] = { duration = 5.0 } },
    },
    ["populated"] = {
        active = config.moduleAmbientPopulated,
        old = nil,
        new = nil,
        oldRefHandle = nil,
        newRefHandle = nil,
        nextTrack = nil,
        nextTrackTimer = nil,
        tempDataKey = "POP",
        lastVolume = nil,
        playUnderwater = true,
        blockedWeathers = {
            [4] = true,
            [5] = true,
            [6] = true,
            [7] = true,
            [8] = true,
            [9] = true,
        },
        soundConfig = {
            ["exterior"] = { pitch = 1.0 },
        },
        faderConfig = { ["out"] = { duration = 4.0 }, ["in"] = { duration = 4.0 } },
    },
    ["interior"] = {
        active = config.moduleAmbientInterior,
        old = nil,
        new = nil,
        oldRefHandle = nil,
        newRefHandle = nil,
        nextTrack = nil,
        nextTrackTimer = nil,
        tempDataKey = "INT",
        lastVolume = nil,
        playUnderwater = true,
        soundConfig = {},
        faderConfig = { ["out"] = { duration = 3.0 }, ["in"] = { duration = 3.0 } },
    },
    ["interiorToExterior"] = {
        active = config.moduleAmbientInterior and config.moduleInteriorToExterior,
        old = nil,
        new = nil,
        oldRefHandle = nil,
        newRefHandle = nil,
        nextTrack = nil,
        nextTrackTimer = nil,
        tempDataKey = "IE",
        lastVolume = nil,
        playExteriorDoors = true,
        playUnderwater = false,
        soundConfig = {
            ["exterior"] = { pitch = 0.9 },
            ["interior"] = { pitch = 0.92 },
        },
        faderConfig = { ["out"] = { duration = 1.0 }, ["in"] = { duration = 1.0 } },
    },
    ["interiorWeather"] = {
        active = config.moduleInteriorWeather,
        old = nil,
        new = nil,
        oldRefHandle = nil,
        newRefHandle = nil,
        nextTrack = nil,
        nextTrackTimer = nil,
        tempDataKey = "IW",
        lastVolume = nil,
        playWindoors = true,
        playUnderwater = true,
        blockedWeathers = {
            [0] = true,
            [1] = true,
            [2] = true,
            [3] = true,
            [8] = true,
        },
        soundConfig = {
            ["big"] = {
                [4] = { mult = 0.85, pitch = 1.0 },
                [5] = { mult = 0.8, pitch = 1.0 },
                [6] = { mult = 0.4, pitch = 0.75 },
                [7] = { mult = 0.4, pitch = 0.75 },
                [9] = { mult = 0.4, pitch = 0.75 },
            },
            ["sma"] = {
                [4] = { mult = 0.75, pitch = 1.0 },
                [5] = { mult = 0.65, pitch = 1.0 },
                [6] = { mult = 0.35, pitch = 0.6 },
                [7] = { mult = 0.35, pitch = 0.6 },
                [9] = { mult = 0.35, pitch = 0.6 },
            },
            ["ten"] = {
                [4] = { mult = 1.0, pitch = 1.0 },
                [5] = { mult = 0.9, pitch = 1.0 },
                [6] = { mult = 0.4, pitch = 0.8 },
                [7] = { mult = 0.4, pitch = 0.8 },
                [9] = { mult = 0.4, pitch = 0.8 },
            },
        },
        faderConfig = { ["out"] = { duration = 5.0 }, ["in"] = { duration = 5.0 } },
    },
    ["wind"] = {
        active = config.windSounds,
        old = nil,
        new = nil,
        oldRefHandle = nil,
        newRefHandle = nil,
        nextTrack = nil,
        nextTrackTimer = nil,
        tempDataKey = "WIND",
        lastVolume = nil,
        playWindoors = true,
        playUnderwater = true,
        blockedWeathers = {
            [6] = true,
            [7] = true,
            [9] = true,
        },
        soundConfig = {
            ["big"] = {
                [0] = { pitch = 0.82 },
                [1] = { pitch = 0.82 },
                [2] = { pitch = 0.81 },
                [3] = { pitch = 0.8 },
                [4] = { pitch = 0.8 },
                [5] = { pitch = 0.79 },
                [8] = { pitch = 0.78 },
            },
            ["sma"] = {
                [0] = { pitch = 0.8 },
                [1] = { pitch = 0.8 },
                [2] = { pitch = 0.79 },
                [3] = { pitch = 0.78 },
                [4] = { pitch = 0.78 },
                [5] = { pitch = 0.77 },
                [8] = { pitch = 0.76 },
            },
            ["ten"] = {
                [0] = { pitch = 0.8 },
                [1] = { pitch = 0.8 },
                [2] = { pitch = 0.79 },
                [3] = { pitch = 0.78 },
                [4] = { pitch = 0.78 },
                [5] = { pitch = 0.77 },
                [8] = { pitch = 0.76 },
            },
            ["exterior"] = { pitch = 1.0 },
        },
        faderConfig = { ["out"] = { duration = 5.0 }, ["in"] = { duration = 5.0 } },
    },
    ["rainOnStatics"] = {
        active = config.playRainOnStatics,
        old = nil,
        new = nil,
        oldRefHandle = nil,
        newRefHandle = nil,
        nextTrack = nil,
        nextTrackTimer = nil,
        tempDataKey = "ROS",
        lastVolume = nil,
        playUnderwater = false,
        blockedWeathers = {
            [0] = true,
            [1] = true,
            [2] = true,
            [3] = true,
            [6] = true,
            [7] = true,
            [8] = true,
            [9] = true,
        },
        soundConfig = {
            ["light"] = {
                [4] = { mult = 1.0, pitch = 0.9 },
                [5] = { mult = 1.0, pitch = 0.9 },
            },
            ["medium"] = {
                [4] = { mult = 0.8, pitch = 0.9 },
                [5] = { mult = 0.9, pitch = 0.9 },
            },
            ["heavy"] = {
                [4] = { mult = 0.7, pitch = 0.9 },
                [5] = { mult = 0.8, pitch = 0.9 },
            },
        },
        faderConfig = { ["out"] = { duration = 1 }, ["in"] = { duration = 1 } },
    },
    ["shelterRain"] = {
        active = config.playRainInsideShelter,
        old = nil,
        new = nil,
        oldRefHandle = nil,
        newRefHandle = nil,
        nextTrack = nil,
        nextTrackTimer = nil,
        tempDataKey = "SHRAIN",
        lastVolume = nil,
        playUnderwater = false,
        blockedWeathers = {
            [0] = true,
            [1] = true,
            [2] = true,
            [3] = true,
            [6] = true,
            [7] = true,
            [8] = true,
            [9] = true,
        },
        soundConfig = {
            ["light"] = {
                [4] = { mult = 1.0, pitch = 1.0 },
                [5] = { mult = 1.0, pitch = 1.0 },
            },
            ["medium"] = {
                [4] = { mult = 0.7, pitch = 1.0 },
                [5] = { mult = 0.8, pitch = 1.0 },
            },
            ["heavy"] = {
                [4] = { mult = 0.7, pitch = 1.0 },
                [5] = { mult = 0.8, pitch = 1.0 },
            },
        },
        faderConfig = { ["out"] = { duration = 1.5 }, ["in"] = { duration = 1.5 } },
    },
    ["shelterWind"] = {
        active = config.playWindInsideShelter,
        old = nil,
        new = nil,
        oldRefHandle = nil,
        newRefHandle = nil,
        nextTrack = nil,
        nextTrackTimer = nil,
        tempDataKey = "SHWIND",
        lastVolume = nil,
        playUnderwater = false,
        blockedWeathers = {
            [0] = true,
            [1] = true,
            [2] = true,
            [3] = true,
            [4] = true,
            [8] = true,
        },
        soundConfig = {
            ["light"] = {
                [5] = { mult = 0.6, pitch = 1.0 },
            },
            ["medium"] = {
                [5] = { mult = 0.7, pitch = 1.0 },
            },
            ["heavy"] = {
                [5] = { mult = 1.0, pitch = 1.0 },
            },
            [6] = { mult = 1.0, pitch = 1.0 },
            [7] = { mult = 1.0, pitch = 1.0 },
            [9] = { mult = 1.0, pitch = 1.0 },
        },
        faderConfig = { ["out"] = { duration = 1.5 }, ["in"] = { duration = 1.5 } },
    },
    ["shelterWeather"] = {
        active = config.shelterWeather,
        old = nil,
        new = nil,
        oldRefHandle = nil,
        newRefHandle = nil,
        nextTrack = nil,
        nextTrackTimer = nil,
        tempDataKey = "SHWEA",
        lastVolume = nil,
        playUnderwater = false,
        blockedWeathers = {
            [0] = true,
            [1] = true,
            [2] = true,
            [3] = true,
            [8] = true,
        },
        soundConfig = {
            ["light"] = {
                [4] = { mult = 0.01 },
                [5] = { mult = 0.015 },
            },
            ["medium"] = {
                [4] = { mult = 0.02 },
                [5] = { mult = 0.025 },
            },
            ["heavy"] = {
                [4] = { mult = 0.03 },
                [5] = { mult = 0.03 },
            },
            [6] = { mult = 0.05 },
            [7] = { mult = 0.05 },
            [9] = { mult = 0.03 },
        },
        faderConfig = { ["out"] = { duration = 1.5 }, ["in"] = { duration = 1.5 } },
    },
    ["ropeBridge"] = {
        active = config.playRopeBridge,
        old = nil,
        new = nil,
        oldRefHandle = nil,
        newRefHandle = nil,
        lastVolume = nil,
        tempDataKey = "RB",
    },
    ["photodragons"] = {
        active = config.playPhotodragons,
        old = nil,
        new = nil,
        oldRefHandle = nil,
        newRefHandle = nil,
        lastVolume = nil,
        tempDataKey = "PD",
    },
    ["bannerFlap"] = {
        active = config.playBannerFlap,
        old = nil,
        new = nil,
        oldRefHandle = nil,
        newRefHandle = nil,
        lastVolume = nil,
        tempDataKey = "BF",
        soundConfig = {
            -- 0-4 and 8: light breeze
            -- 5-7 and 9: strong breeze
            [0] = {pitch = 0.75},
            [1] = {pitch = 0.75},
            [2] = {pitch = 0.73},
            [3] = {pitch = 0.72},
            [4] = {pitch = 0.74},
            [5] = {pitch = 0.85},
            [6] = {pitch = 0.85},
            [7] = {pitch = 0.85},
            [8] = {pitch = 0.75},
            [9] = {pitch = 0.85},
        },
    },
}

function this.getTempData(ref, key)
    return key and ref and ref.tempData
        and ref.tempData.tew
        and ref.tempData.tew.AURA
        and ref.tempData.tew.AURA[key]
end

function this.initRefTempData(moduleName, ref)
    local key = this.data[moduleName] and this.data[moduleName].tempDataKey
    if not key and ref and ref.tempData then return end

    if not ref.tempData.tew then ref.tempData.tew = {} end
    if not ref.tempData.tew.AURA then ref.tempData.tew.AURA = {} end
    if not ref.tempData.tew.AURA[key] then ref.tempData.tew.AURA[key] = {} end
end

function this.getTempDataEntry(entry, ref, moduleName)
    local key = this.data[moduleName].tempDataKey
    local tempData = this.getTempData(ref, key)
    return tempData and entry and tempData[entry]
end

function this.setTempDataEntry(entry, value, ref, moduleName)
    this.initRefTempData(moduleName, ref)
    local key = this.data[moduleName].tempDataKey
    if entry and value and this.getTempData(ref, key) then
        ref.tempData.tew.AURA[key][entry] = value
    end
end

function this.unsetTempDataEntry(entry, ref, moduleName)
    local key = this.data[moduleName].tempDataKey
    if entry and this.getTempData(ref, key) then
        ref.tempData.tew.AURA[key][entry] = nil
    end
end

function this.getCurrentlyPlaying(moduleName, newOrOld)
    if not this.data[moduleName] then return end
    local oldTrack = this.data[moduleName].old
    local newTrack = this.data[moduleName].new
    local oldRefHandle = this.data[moduleName].oldRefHandle
    local newRefHandle = this.data[moduleName].newRefHandle
    local track = (newOrOld == "old") and oldTrack or newTrack
    local refHandle = (newOrOld == "old") and oldRefHandle or newRefHandle

    if refHandle then
        local ref = refHandle:getObject()
        if common.getTrackPlaying(track, ref) then
            return { track, ref }
        end
    end
end

function this.getRefTrackPlaying(ref, moduleName)
    local track = this.getTempDataEntry("track", ref, moduleName)
    return common.getTrackPlaying(track, ref)
end

function this.getWindoorPlaying(moduleName)
    if not this.data[moduleName] then return end
    if not this.data[moduleName].playWindoors
        or not cellData.windoors
        or table.empty(cellData.windoors) then
        return
    end
    local oldTrack = this.data[moduleName].old
    local newTrack = this.data[moduleName].new
    for _, door in pairs(cellData.windoors) do
        local tempDataTrack = this.getTempDataEntry("track", door, moduleName)
        if door ~= nil then
            if common.getTrackPlaying(tempDataTrack, door) then
                return { tempDataTrack, door }
            end
            if common.getTrackPlaying(newTrack, door) then
                return { newTrack, door }
            end
            if common.getTrackPlaying(oldTrack, door) then
                return { oldTrack, door }
            end
        end
    end
end

function this.getExteriorDoorPlaying(moduleName)
    if not this.data[moduleName] then return end
    if not this.data[moduleName].playExteriorDoors
        or not cellData.exteriorDoors
        or table.empty(cellData.exteriorDoors) then
        return
    end
    for _, door in pairs(cellData.exteriorDoors) do
        if door ~= nil then
            local track = this.getTempDataEntry("track", door, moduleName)
            if common.getTrackPlaying(track, door) then
                return { track, door }
            end
        end
    end
end

function this.getEligibleWeather(moduleName, weatherIndex)
    local cell = cellData.cell
    if not this.data[moduleName] or not cell then return end
    local weather = weatherIndex or common.getWeather(cell)
    local blockedWeathers = this.data[moduleName].blockedWeathers
    if (weather) and not (blockedWeathers and blockedWeathers[weather]) then
        return weather
    end
end

function this.isActive(moduleName)
    if not this.data[moduleName] then return end
    return this.data[moduleName].active
end

local function clearModuleData()
    debugLog("Clearing module data.")
    for moduleName, data in pairs(this.data) do
        data.new = nil
        data.old = nil
        data.newRefHandle = nil
        data.oldRefHandle = nil
        --data.lastVolume = nil -- should we?
        if data.nextTrackTimer then
            data.nextTrackTimer:cancel()
        end
        data.nextTrackTimer = nil
        data.nextTrack = nil
    end
end
event.register(tes3.event.loaded, clearModuleData)

local function removeAll()
    debugLog("Removing module sounds.")
    for moduleName, data in pairs(this.data) do
        local playing = this.getCurrentlyPlaying(moduleName)
        while playing do
            local track, ref = table.unpack(playing)
            tes3.removeSound { sound = track, reference = ref }
            playing = this.getCurrentlyPlaying(moduleName)
        end
        if data.nextTrackTimer then
            data.nextTrackTimer:cancel()
        end
        data.nextTrackTimer = nil
        data.nextTrack = nil
    end
end
event.register(tes3.event.load, removeAll, { priority = -5 })

return this
