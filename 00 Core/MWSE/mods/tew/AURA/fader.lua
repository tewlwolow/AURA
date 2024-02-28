local this = {}

local config = require("tew.AURA.config")
local common = require("tew.AURA.common")
local defaults = require("tew.AURA.defaults")
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
    local saveVolume = options.saveVolume -- Save resulting targetVolume to config after fade?
    local onSuccess = options.onSuccess -- Function to execute after successful fade
    local onFail = options.onFail -- Function to execute if failure arises during fade
    local isTrackUnattached = not ref

    local function tryLater(options)
        timer.start {
            callback = function()
                this.fade(options)
            end,
            type = timer.real,
            iterations = 1,
            duration = 2,
        }
    end

    if not (fadeType and track) then
        debugLog("[!][%s] Track: %s, fadeType: %s. Returning.", moduleName, track, fadeType)
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
        debugLog("[%s] wants to fade %s %s but fade %s is in progress for this track. Trying later.",
            moduleName, fadeType, trackId, fadeTypeOpposite)
        tryLater(options)
        return
    end

    if (ref) and (not tes3.getSoundPlaying { sound = track, reference = ref }) then
        debugLog("[%s] Track %s not playing on ref %s, cannot fade %s. Returning.", moduleName, trackId, ref, fadeType)
        return
    end

    local configDuration = mData and mData.faderConfig and mData.faderConfig[fadeType].duration
    local targetDuration = options.duration or configDuration or 1
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

        -- ### Fail state begin ### --
        if (not track) or (isTrackUnattached and not track:isPlaying()) or (ref and not tes3.getSoundPlaying { sound = track, reference = ref }) then
            debugLog("[%s] %s suddenly not playing on ref %s. Canceling fade %s timers.", moduleName, trackId, ref or "(unattached)", fadeType)

            fadeInProgress.iterTimer:cancel()

            -- Set back original volume if track was playing unattached
            if isTrackUnattached then
                debugLog("[%s] Restoring original volume for unattached track: %s.", moduleName, trackId)
                volumeController.setVolume(tes3.getSound(trackId), trackVolume)
            end

            if type(onFail) == "function" then
                debugLog("[%s] Running fail state hook.", moduleName)
                onFail()
            end

            fadeInProgress.fadeTimer:cancel()
            common.setRemove(this.inProgress[fadeType], fadeInProgress)
            return
        end
        -- ### Fail state end ### --

        volumeController.adjustVolume {
            module = moduleName,
            track = track,
            reference = ref,
            volume = currentVolume,
            inOrOut = fadeType,
            quiet = not (((iterCount % 10) == 0) or (iterCount == 1) or (iterCount == iters)),
        }
    end

    debugLog("[%s] Running fade %s for %s -> %s", moduleName, fadeType, trackId, ref or "(unattached)")

    fadeInProgress.moduleName = moduleName
    fadeInProgress.fadeType = fadeType
    fadeInProgress.track = track
    fadeInProgress.ref = ref
    fadeInProgress.removeTrack = removeTrack
    fadeInProgress.iterTimer = timer.start {
        iterations = iters,
        duration = TICK,
        callback = fader,
    }
    fadeInProgress.fadeTimer = timer.start {
        iterations = 1,
        duration = fadeDuration + 0.1,
        callback = function()
            -- ### Success state ### --
            debugLog("[%s] Fade %s for %s -> %s finished in %.3f s.", moduleName, fadeType, trackId,
                ref or "(unattached)", fadeDuration)
            if (ref) and (fadeType == "out") and (removeTrack == true) then
                if tes3.getSoundPlaying { sound = track, reference = ref } then
                    tes3.removeSound { sound = track, reference = ref }
                    debugLog("[%s] Track %s removed from -> %s.", moduleName, trackId, ref)
                end
            end
            if (saveVolume == true) and (mData) then
                debugLog("[%s] Saving current volume to config.", moduleName)
                config.volumes.modules[moduleName].volume = currentVolume * 100
                mwse.saveConfig("AURA", config)
            end
            if type(onSuccess) == "function" then
                debugLog("[%s] Running success state hook.", moduleName)
                onSuccess()
            end
            common.setRemove(this.inProgress[fadeType], fadeInProgress)
            debugLog("[%s] currentVolume: %s", moduleName, currentVolume)
        end,
    }
    common.setInsert(this.inProgress[fadeType], fadeInProgress)
    local inProgressCount = getInProgressCount(moduleName, fadeType)
    debugLog("[%s] Fade %ss in progress: %s", moduleName, fadeType, inProgressCount)
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
                if (options.removeTrack) and (not fade.removeTrack) then goto continue end
                --return true
                return fade.track
            end
            :: continue ::
        end
    end

    local function timerRunning(fadeType)
        for _, fade in ipairs(this.inProgress[fadeType]) do
            if (fade.moduleName == moduleName)
                and (common.isTimerAlive(fade.iterTimer) or common.isTimerAlive(fade.fadeTimer)) then
                --return true
                return fade.track
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
    local canceled = {}
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
                local trackId = fade.track and fade.track.id
                local refId = fade.ref and tostring(fade.ref) or "(unattached)"
                debugLog("[%s] Fade %s canceled for track %s -> %s.", moduleName, fadeType, trackId, refId)
                table.insert(canceled, fade)
            end
            :: continue ::
        end
    end
    for _, fade in ipairs(canceled) do
        local fadeType = fade.fadeType
        common.setRemove(this.inProgress[fadeType], fade)
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
