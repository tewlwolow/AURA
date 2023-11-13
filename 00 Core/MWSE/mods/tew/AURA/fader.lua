local this = {}

local common = require("tew.AURA.common")
local debugLog = common.debugLog
local modules = require("tew.AURA.modules")
local moduleData = modules.data
local volumeController = require("tew.AURA.volumeController")

local TICK = 0.1
local MAX = 1
local MIN = 0

this.inProgress = { ["in"] = {}, ["out"] = {} }

local function getInProgressCount(moduleName, fadeType)
    local count = 0
    for _, fade in ipairs(this.inProgress[fadeType]) do
        if (fade.moduleName == moduleName) then
            count = count + 1
        end
    end
    return count
end

function this.fade(options)
    local moduleName = options.module or "n/a"
    local mData = moduleData[moduleName]
    local fadeType = options.fadeType
    local fadeTypeOpposite = (fadeType == "out") and "in" or "out"
    local track = options.track
    local trackId = track and track.id
    local ref = options.reference
    local removeTrack = options.removeTrack -- Whether to remove the track after fading it out
    local isTrackUnattached = not ref

    if not (fadeType and track) then
        debugLog(string.format("[!][%s] Track: %s, fadeType: %s. Returning.", moduleName, tostring(track),
            tostring(fadeType)))
        return
    end

    if this.isRunning {
            module = moduleName,
            fadeType = fadeType,
            track = track,
            reference = ref,
        } then
        return
    end

    if this.isRunning {
            module = moduleName,
            fadeType = fadeTypeOpposite,
            track = track,
            reference = ref,
        } then
        debugLog(string.format("[%s] wants to fade %s %s but fade %s is in progress for this track. Trying later.",
            moduleName, fadeType, trackId, fadeTypeOpposite))
        timer.start {
            callback = function()
                this.fade(options)
            end,
            type = timer.real,
            iterations = 1,
            duration = 2,
        }
        return
    end

    if (ref) and (not tes3.getSoundPlaying { sound = track, reference = ref }) then
        debugLog(string.format("[%s] Track %s not playing on ref %s, cannot fade %s. Returning.", moduleName, trackId,
            tostring(ref), fadeType))
        return
    end

    local targetDuration = options.duration or (mData and mData.faderConfig and mData.faderConfig[fadeType].duration) or
    1
    local trackVolume = math.round(track.volume, 2)
    local lastVolume = mData and mData.lastVolume
    local currentVolume = lastVolume or trackVolume
    debugLog("------------" .. moduleName .. "------------")
    debugLog("currentVolume: " .. currentVolume)

    -- The volume param specifies the volume difference relative to the
    -- last known volume for this module (or the current sound object
    -- volume) after which the fader should stop fading in or out.
    -- One can for example, fade out a track that is playing at volume
    -- 0.9, down to 0.75 by passing a volume param of 0.15.
    local delta = math.round(options.volume or currentVolume, 2)
    debugLog("delta: " .. delta)

    local step = TICK * delta / targetDuration
    debugLog("step: " .. step)
    local iters = math.ceil(delta / step) -- corner case: (0 / 0) = NaN
    iters = iters ~= iters and 1 or iters -- if NaN, set ITERS to 1 in order to avoid infinite iterations on iterTimer
    debugLog("iters: " .. iters)
    local fadeDuration = TICK * iters
    local targetVolume = (fadeType == "out") and (currentVolume - delta) or (currentVolume + delta)
    targetVolume = math.clamp(math.round(targetVolume, 2), MIN, MAX)
    debugLog("targetVolume: " .. targetVolume)

    local fadeInProgress = {} -- Needs to be inited before the local fader function
    local iterCount = 0

    local function fader()
        iterCount = iterCount + 1

        if fadeType == "in" then
            currentVolume = math.clamp(currentVolume + step, MIN, targetVolume)
        else
            currentVolume = math.clamp(currentVolume - step, targetVolume, MAX)
        end

        -- This is like cheating, but man, floating point maths be trippin' sometimes
        if iterCount == iters then currentVolume = math.round(currentVolume, 2) end

        if (not track) or (isTrackUnattached and not track:isPlaying()) or (ref and not tes3.getSoundPlaying { sound = track, reference = ref }) then
            debugLog(string.format("[%s] %s suddenly not playing on ref %s. Canceling fade %s timers.", moduleName,
                trackId, ref and tostring(ref) or "(unattached)", fadeType))
            fadeInProgress.iterTimer:cancel()
            fadeInProgress.fadeTimer:cancel()
            common.setRemove(this.inProgress[fadeType], fadeInProgress)

            -- Set back original volume if track was playing unattached
            if isTrackUnattached then volumeController.setVolume(tes3.getSound(trackId), trackVolume) end
            return
        end

        volumeController.adjustVolume {
            module = moduleName,
            track = track,
            reference = ref,
            volume = currentVolume,
            inOrOut = fadeType,
        }
    end

    debugLog(string.format("[%s] Running fade %s for %s -> %s", moduleName, fadeType, trackId,
        ref and tostring(ref) or "(unattached)"))

    fadeInProgress.moduleName = moduleName
    fadeInProgress.track = track
    fadeInProgress.ref = ref
    fadeInProgress.iterTimer = timer.start {
        iterations = iters,
        duration = TICK,
        callback = fader,
    }
    fadeInProgress.fadeTimer = timer.start {
        iterations = 1,
        duration = fadeDuration + 0.1,
        callback = function()
            debugLog(string.format("[%s] Fade %s for %s -> %s finished in %.3f s.", moduleName, fadeType, trackId,
                ref and tostring(ref) or "(unattached)", fadeDuration))
            if (ref) and (fadeType == "out") and (removeTrack) then
                if tes3.getSoundPlaying { sound = track, reference = ref } then
                    tes3.removeSound { sound = track, reference = ref }
                    debugLog(string.format("[%s] Track %s removed from -> %s.", moduleName, trackId, tostring(ref)))
                end
            end
            common.setRemove(this.inProgress[fadeType], fadeInProgress)
            if mData then
                mData.old = track
                mData.lastVolume = currentVolume
                debugLog(string.format("[%s] lastVolume is now: %s", moduleName, currentVolume))
            end
        end,
    }
    common.setInsert(this.inProgress[fadeType], fadeInProgress)
    local inProgressCount = getInProgressCount(moduleName, fadeType)
    debugLog(string.format("[%s] Fade %ss in progress: %s", moduleName, fadeType, inProgressCount))
end

function this.isRunning(options)
    local options = options or {}
    local moduleName = options.module
    local track = options.track
    local ref = options.reference
    local fadeType = options.fadeType

    local function typeRunning(fadeType)
        for _, fade in ipairs(this.inProgress[fadeType]) do
            if (fade.moduleName == moduleName) and (fade.track == track) and (fade.ref == ref) then
                return true
            end
        end
    end

    local function timerRunning(fadeType)
        for _, fade in ipairs(this.inProgress[fadeType]) do
            if (fade.moduleName == moduleName)
                and (common.isTimerAlive(fade.iterTimer) or common.isTimerAlive(fade.fadeTimer)) then
                return true
            end
        end
    end

    if fadeType and track then
        return typeRunning(fadeType)
    elseif track then
        return typeRunning("out") or typeRunning("in")
    elseif moduleName then
        return timerRunning("out") or timerRunning("in")
    elseif table.empty(options) then
        for mName in pairs(moduleData) do
            moduleName = mName
            if timerRunning("out") or timerRunning("in") then
                return mName
            end
        end
    end
end

-- Cancels any fade in/out currently in progress for the given module,
-- or just in/out for the given track and ref. Does not remove tracks.
-- Make sure to remove tracks after calling this function if necessary.
function this.cancel(moduleName, track, ref)
    for fadeType, data in pairs(this.inProgress) do
        for k, fade in ipairs(data) do
            if (moduleName == fade.moduleName) or (moduleName == "__all") then
                if track and ref then
                    if not (fade.track == track and fade.ref == ref) then
                        goto continue
                    end
                end
                fade.iterTimer:cancel()
                fade.fadeTimer:cancel()
                local fadeTrack = fade.track and fade.track.id
                local fadeRef = fade.ref and tostring(fade.ref) or "(unattached)"
                debugLog(string.format("[%s] Fade %s canceled for track %s -> %s.", moduleName, fadeType, fadeTrack,
                    fadeRef))
                data[k] = nil
            end
            :: continue ::
        end
    end
end

local function onLoad()
    debugLog("Canceling all ongoing fades.")
    this.cancel("__all")
end
event.register(tes3.event.load, onLoad)

local function onLoaded()
    debugLog("Resetting fader data.")
    this.inProgress["in"] = {}
    this.inProgress["out"] = {}
end
event.register(tes3.event.loaded, onLoaded)

return this
