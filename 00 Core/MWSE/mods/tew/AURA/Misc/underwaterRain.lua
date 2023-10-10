local common = require("tew.AURA.common")
local debugLog = common.debugLog
local soundData = require("tew.AURA.soundData")

local originalVolumes = {}

local function setVolume(track, volume)
	local rounded = math.round(volume, 2)
	debugLog(string.format("Setting volume for track %s to %s", track.id, rounded))
	track.volume = rounded
end

local function storeOriginalVolumes()
    debugLog("Storing current weather volumes.")
    table.clear(originalVolumes)
    for _, sound in pairs(soundData.weatherLoops) do
        originalVolumes[sound.id] = sound.volume
	end
end

local function modifyVolume()
	if not tes3.player or not tes3.mobilePlayer then return end
	local waterLevel = tes3.player.cell.waterLevel or 0
	local playerPosZ = tes3.player.position.z
    local playerHeight = tes3.player.object.boundingBox and tes3.player.object.boundingBox.max.z or 0
    for _, sound in pairs(soundData.weatherLoops) do
        local originalVol = originalVolumes[sound.id]
		if playerPosZ + playerHeight < waterLevel and sound:isPlaying() then
			local volume = math.clamp(1 - math.remap(waterLevel - (playerPosZ + playerHeight), 0, 1500, 0, originalVol), 0.0, originalVol)
			setVolume(sound, volume)
		end
	end
end

local underwaterPrev

local function underWaterCheck(e)
	local mp = tes3.mobilePlayer
	if mp then
		if mp.isSwimming and not underwaterPrev then
			underwaterPrev = true
            debugLog("Player is swimming.")
			event.trigger("AURA:enteredUnderwater")
		elseif not mp.isSwimming and underwaterPrev then
			underwaterPrev = false
            debugLog("Player is not swimming.")
			event.trigger("AURA:exitedUnderwater")
		end
	end
end

local function registerModify()
    storeOriginalVolumes() -- Store once more when going underwater, in case volumeSave has been used since `load`
	event.unregister(tes3.event.simulate, modifyVolume)
	event.register(tes3.event.simulate, modifyVolume)
    debugLog("Started underwater volume scaling.")
end

local function unRegisterModify()
	event.unregister(tes3.event.simulate, underWaterCheck)
	event.unregister(tes3.event.simulate, modifyVolume)
    timer.start{
        duration = 1,
        callback = function()
            debugLog("Stopped underwater volume scaling, restoring original volumes.")
            for id, originalVol in pairs(originalVolumes) do
                local sound = tes3.getSound(id)
                setVolume(sound, originalVol)
            end
            event.register(tes3.event.simulate, underWaterCheck)
        end,
    }
end

event.unregister(tes3.event.simulate, underWaterCheck)
event.register(tes3.event.simulate, underWaterCheck)

event.register("AURA:enteredUnderwater", registerModify)
event.register("AURA:exitedUnderwater", unRegisterModify)

-- First we need to need to globally set all config volumes, then store them.
-- i.e.: set vanilla rain tracks volume to 0 if using variable rain sounds
-- The `load` event callback in volumeController should trigger first. And then this one.
event.register(tes3.event.load, storeOriginalVolumes, { priority = -50 })