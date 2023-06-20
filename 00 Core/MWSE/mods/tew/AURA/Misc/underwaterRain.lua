local common = require("tew.AURA.common")
local debugLog = common.debugLog

local weatherSounds = {
	"Rain",
	"rain heavy",
	"Blight",
	"Ashstorm",
	"BM Blizzard",
	"tew_b_rainlight",
	"tew_b_rainmedium",
	"tew_b_rainheavy",
	"tew_s_rainlight",
	"tew_s_rainmedium",
	"tew_s_rainheavy",
	"tew_t_rainlight",
	"tew_t_rainmedium",
	"tew_t_rainheavy",
	"tew_rain_light",
	"tew_rain_medium",
	"tew_rain_heavy",
	"tew_thunder_light",
	"tew_thunder_medium",
	"tew_thunder_heavy"
}

local function setVolume(track, volume)
	local rounded = math.round(volume, 2)
    debugLog(string.format("Setting volume for track %s to %s", track.id, rounded))
    track.volume = rounded
end

local function modifyVolume()
	if not tes3.player or not tes3.mobilePlayer then return end
	local waterLevel = tes3.player.cell.waterLevel or 0
	local playerPosZ = tes3.player.position.z
	for _, id in ipairs(weatherSounds) do
		if playerPosZ < waterLevel and tes3.getSound(id):isPlaying() then
			local sound = tes3.getSound(id)
			local volume = math.clamp(1 - math.remap(waterLevel - playerPosZ, 0, 1500, 0, 1), 0.0, 1.0)
			setVolume(sound, volume)
		else
			local sound = tes3.getSound(id)
			setVolume(sound, 1.0)
		end
	end
end

local underwaterPrev
---@param e simulateEventData
local function underWaterCheck(e)
	local mp = tes3.mobilePlayer
	if mp then
		if mp.isSwimming and not underwaterPrev then
			underwaterPrev = true
			event.trigger("AURA:enteredUnderwater")
			return
		end

		if not mp.isSwimming and underwaterPrev then
			underwaterPrev = false
			event.trigger("AURA:exitedUnderwater")
		end
	end
end

local function registerModify()
	event.unregister(tes3.event.simulate, underWaterCheck)
	event.unregister(tes3.event.simulate, modifyVolume)
	event.register(tes3.event.simulate, modifyVolume)
end

local function unRegisterModify()
	event.unregister(tes3.event.simulate, underWaterCheck)
	event.register(tes3.event.simulate, underWaterCheck)
	event.unregister(tes3.event.simulate, modifyVolume)
	modifyVolume()
end

event.unregister(tes3.event.simulate, underWaterCheck)
event.register(tes3.event.simulate, underWaterCheck)

event.register("AURA:enteredUnderwater", registerModify)
event.register("AURA:exitedUnderwater", unRegisterModify)