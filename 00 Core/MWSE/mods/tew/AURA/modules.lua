local config = require("tew.AURA.config")
local cellData = require("tew.AURA.cellData")
local common = require("tew.AURA.common")

local this = {}

this.data = {
    ["outdoor"] = {
        active = config.moduleAmbientOutdoor,
        old = nil,
        new = nil,
        oldRef = nil,
        newRef = nil,
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
        oldRef = nil,
        newRef = nil,
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
        oldRef = nil,
        newRef = nil,
        lastVolume = nil,
        playUnderwater = true,
        soundConfig = {},
        faderConfig = { ["out"] = { duration = 3.0 }, ["in"] = { duration = 3.0 } },
    },
    ["interiorToExterior"] = {
        active = config.moduleAmbientInterior and config.moduleInteriorToExterior,
        old = nil,
        new = nil,
        oldRef = nil,
        newRef = nil,
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
        oldRef = nil,
        newRef = nil,
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
        oldRef = nil,
        newRef = nil,
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
        oldRef = nil,
        newRef = nil,
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
        oldRef = nil,
        newRef = nil,
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
        oldRef = nil,
        newRef = nil,
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
        oldRef = nil,
        newRef = nil,
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
        oldRef = nil,
        newRef = nil,
        lastVolume = nil,
    },
}

function this.getCurrentlyPlaying(moduleName)
    local oldTrack = this.data[moduleName].old
    local newTrack = this.data[moduleName].new
    local oldRef = this.data[moduleName].oldRef
    local newRef = this.data[moduleName].newRef

    if common.getTrackPlaying(newTrack, newRef) then
        return { newTrack, newRef }
    end
    if common.getTrackPlaying(oldTrack, oldRef) then
        return { oldTrack, oldRef }
    end
end

function this.getWindoorPlaying(moduleName)
    if not this.data[moduleName].playWindoors
        or not cellData.windoors
        or table.empty(cellData.windoors) then
        return
    end
    local oldTrack = this.data[moduleName].old
    local newTrack = this.data[moduleName].new
    for _, door in pairs(cellData.windoors) do
        if door ~= nil then
            if common.getTrackPlaying(newTrack, door) then
                return { newTrack, door }
            end
            if common.getTrackPlaying(oldTrack, door) then
                return { oldTrack, door }
            end
        end
    end
end

function this.getExteriorDoorTrack(ref)
    return ref and ref.tempData
        and ref.tempData.tew
        and ref.tempData.tew.AURA
        and ref.tempData.tew.AURA.IE
        and ref.tempData.tew.AURA.IE.track
end

function this.getExteriorDoorPlaying(moduleName)
    if not this.data[moduleName].playExteriorDoors
        or not cellData.exteriorDoors
        or table.empty(cellData.exteriorDoors) then
        return
    end
    for _, door in pairs(cellData.exteriorDoors) do
        if door ~= nil then
            local track = this.getExteriorDoorTrack(door)
            if common.getTrackPlaying(track, door) then
                return { track, door }
            end
        end
    end
end

function this.getEligibleWeather(moduleName)
    local regionObject = common.getRegion()
    local weather = regionObject and regionObject.weather.index
    local blockedWeathers = this.data[moduleName].blockedWeathers
    if (weather) and not (blockedWeathers and blockedWeathers[weather]) then
        return weather
    end
end

function this.isActive(moduleName)
    return this.data[moduleName].active
end

return this
