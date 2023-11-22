-- Library packaging
local this = {}

-- Imports
local cellData = require("tew.AURA.cellData")
local common = require("tew.AURA.common")
local fader = require("tew.AURA.fader")
local modules = require("tew.AURA.modules")
local moduleData = modules.data
local soundData = require("tew.AURA.soundData")
local volumeController = require("tew.AURA.volumeController")
local getVolume = volumeController.getVolume

-- Logger
local debugLog = common.debugLog

-- Constants
local MAX = 1
local MIN = 0

-- Resolve options and return the randomised track per conditions given --
function this.getTrack(options)
	--debugLog("Parsing passed options.")
	local moduleName = options.module

	if not moduleName then debugLog("No module detected. Returning.") end

	local table

	if moduleName == "outdoor" then
		debugLog("Got outdoor module.")
		if not (options.climate) or not (options.time) then
			-- Not implemented. This module only uses the clear weather table.
			-- This part of the if statement has no purpose as of now.
			if options.type == "quiet" then
				debugLog("Got quiet type.")
				table = soundData.quiet
			end
		else
			local climate = options.climate
			local time = options.time
			debugLog("Got " .. climate .. " climate and " .. time .. " time.")
			table = soundData.clear[climate][time]
		end
	elseif moduleName == "populated" then
		debugLog("Got populated module.")
		if options.type == "night" then
			debugLog("Got populated night.")
			table = soundData.populated["n"]
		elseif options.type == "day" then
			debugLog("Got populated day.")
			table = soundData.populated[options.typeCell]
		end
	elseif moduleName == "interior" then
		debugLog("Got interior module.")
		debugLog("Got interior " .. options.type .. " type.")
		local IsoundTable = soundData.interior
		table = IsoundTable[options.type] or IsoundTable["tav"][options.type]
	elseif moduleName == "interiorToExterior" then
		debugLog("Got interiorToExterior module.")
		debugLog("Got interior " .. options.type .. " type.")
		local IEsoundTable = soundData.interiorToExterior
		table = IEsoundTable[options.type] or IEsoundTable["tav"][options.type]
	elseif moduleName == "interiorWeather" then
		debugLog("Got interior weather module. Weather: " .. options.weather)
		debugLog("Got interior type: " .. options.type)
		local intWTrack = soundData.interiorWeather[options.type][options.weather]
		if intWTrack then
			debugLog("Got track: " .. intWTrack.id)
			return intWTrack
		else
			debugLog("No track found.")
			return
		end
	elseif moduleName == "wind" then
		if options.type == "quiet" then
			debugLog("Got wind quiet type.")
			table = soundData.quiet
		elseif options.type == "warm" then
			debugLog("Got warm type.")
			table = soundData.warm
		elseif options.type == "cold" then
			debugLog("Got cold type.")
			table = soundData.cold
		end
	elseif moduleName == "rainOnStatics" or moduleName == "shelterRain" then
		local weather = options.weather or modules.getEligibleWeather(moduleName)
		return weather and cellData.rainType[weather] and soundData.interiorWeather["ten"][weather]
	elseif moduleName == "shelterWind" then
		return tes3.getSound("tew_tentwind")
	end

	-- Can happen on fresh load etc. --
	if not table then
		debugLog("No table found. Returning.")
		return
	end

	local newTrack = table[math.random(1, #table)]
	if moduleData[moduleName].old and #table > 1 then
		while newTrack.id == moduleData[moduleName].old.id do
			newTrack = table[math.random(1, #table)]
		end
	end

	debugLog("Selected track: " .. newTrack.id)

	return newTrack
end

function this.isStopping(moduleName, ref)
	local oldTrack = moduleData[moduleName].old
	local newTrack = moduleData[moduleName].new
	return oldTrack
		and (fader.isRunning { module = moduleName, track = oldTrack, reference = ref, fadeType = "out" }
			or fader.isRunning { module = moduleName, track = newTrack, reference = ref, fadeType = "out" })
		and not (fader.isRunning { module = moduleName, track = newTrack, reference = ref, fadeType = "in" }
			or fader.isRunning { module = moduleName, track = oldTrack, reference = ref, fadeType = "in" })
end

-- Sometimes we need to just remove the sounds without fading --
-- If fade is in progress for the given track and ref, we'll cancel the fade first --
function this.removeImmediate(options)
	local ref = options.reference or tes3.mobilePlayer and tes3.mobilePlayer.reference

	-- Remove old file if playing --
	local oldTrack = common.getTrackPlaying(moduleData[options.module].old, ref)
	if oldTrack then
		debugLog(string.format("[%s] Immediately removing old track %s -> %s.", options.module, oldTrack.id,
			tostring(ref)))
		fader.cancel(options.module, oldTrack, ref)
		tes3.removeSound { sound = oldTrack, reference = ref }
	end

	-- Remove the new file as well --
	local newTrack = common.getTrackPlaying(moduleData[options.module].new, ref)
	if newTrack then
		debugLog(string.format("[%s] Immediately removing new track %s -> %s.", options.module, newTrack.id,
			tostring(ref)))
		fader.cancel(options.module, newTrack, ref)
		tes3.removeSound { sound = newTrack, reference = ref }
	end
end

-- Remove the sound for a given module, but with fade out --
function this.remove(options)
	local ref = options.reference or tes3.mobilePlayer and tes3.mobilePlayer.reference

	local oldTrack = common.getTrackPlaying(moduleData[options.module].old, ref)
	local newTrack = common.getTrackPlaying(moduleData[options.module].new, ref)

	local oldTrackOpts, newTrackOpts

	if oldTrack then
		oldTrackOpts = table.copy(options)
		oldTrackOpts.fadeType = "out"
		oldTrackOpts.reference = ref
		oldTrackOpts.track = oldTrack
		oldTrackOpts.removeTrack = true
		fader.fade(oldTrackOpts)
	end

	if newTrack then
		newTrackOpts = table.copy(options)
		newTrackOpts.fadeType = "out"
		newTrackOpts.reference = ref
		newTrackOpts.track = newTrack
		newTrackOpts.removeTrack = true
		fader.fade(newTrackOpts)
	end
end

-- Sometiems we need to play a sound immediately as well.
-- This function doesn't remove sounds on its own. It's the module's
-- decision to remove sounds before immediately playing anything else.
function this.playImmediate(options)
	local moduleName = options.module
	local ref = options.newRef or options.reference or tes3.mobilePlayer and tes3.mobilePlayer.reference
	local track = options.last and moduleData[moduleName].new or options.track or this.getTrack(options)

	if track then
		if not tes3.getSoundPlaying { sound = track, reference = ref } then
			local volume = math.clamp(math.round(options.volume or getVolume { module = moduleName }, 2), MIN, MAX)
			local pitch = options.pitch or volumeController.getPitch(moduleName)
			debugLog(string.format("[%s] Playing with volume %s: %s -> %s", moduleName, volume, track.id, tostring(ref)))
			tes3.playSound {
				sound = track,
				reference = ref,
				volume = volume,
				pitch = pitch,
				loop = true,
			}
			moduleData[moduleName].lastVolume = volume
			moduleData[moduleName].old = moduleData[moduleName].new
			moduleData[moduleName].new = track
			moduleData[moduleName].newRef = ref
			return true
		end
	end
	return false
end

local queue = {}
local function cancelModuleTimer(moduleName)
	local moduleTimer = queue[moduleName]
	if moduleTimer then moduleTimer:cancel() end
end

local function addToQueue(options)
	local moduleName = options.module
	cancelModuleTimer(moduleName)
	queue[moduleName] = timer.start {
		callback = function()
			this.play(options)
		end,
		type = timer.real,
		iterations = 1,
		duration = 2,
	}
end

-- Supporting kwargs here
-- Main entry point, resolves all data received and decides what to do next --
function this.play(options)
	-- Blocking additional fade/crossfade requests until ongoing fades for this module are finished --
	-- If multiple play requests arrive in this time, only the last request will pass through --
	-- Should cover edge case where module becomes stale (no tracks playing) if changing cells too fast during crossfades --
	if not options.noQueue then
		if fader.isRunning{module = options.module} then
			debugLog(string.format("[%s] Fader is running. Trying later.", options.module))
			addToQueue(options)
			return
		end
		cancelModuleTimer(options.module)
	end
	-- Get the last track so that we're not randomising each time we change int/ext cells within same conditions --
	-- Checking here explicitly for a boolean because we might as well get a table from timer calls
	if options.last == true and moduleData[options.module].new then
		this.playImmediate(options)
	else
		local oldTrack, newTrack, oldRef, newRef, fadeOutOpts, fadeInOpts, removeTrack
		-- Get the new track, if nothing is returned then bugger off (shouldn't really happen at all, but oh well) --
		newTrack = options.newTrack or this.getTrack(options)
		newRef = options.newRef or options.reference or tes3.mobilePlayer and tes3.mobilePlayer.reference
		if not newTrack then
			debugLog("No track selected. Returning.")
			return
		end

		-- If old track is playing, then we'll first fade it out. Otherwise, we'll just fade in the new track --
		oldRef = options.oldRef or moduleData[options.module].oldRef or options.reference
		oldTrack = common.getTrackPlaying(options.oldTrack or moduleData[options.module].old, oldRef)

		-- Remove old track by default when crossfading, unless instructed otherwise --
		removeTrack = (options.removeTrack == nil) and true or options.removeTrack

		-- Move the queue forward --
		moduleData[options.module].old = moduleData[options.module].new
		moduleData[options.module].new = newTrack
		moduleData[options.module].newRef = newRef

		if oldTrack then
			fadeOutOpts = table.copy(options)
			fadeOutOpts.fadeType = "out"
			fadeOutOpts.track = oldTrack
			fadeOutOpts.reference = oldRef
			fadeOutOpts.removeTrack = removeTrack
			fader.fade(fadeOutOpts)
		end
		if newTrack then
			if this.playImmediate {
					module = options.module,
					reference = newRef,
					track = newTrack,
					volume = MIN,
					pitch = options.pitch,
				} then
				fadeInOpts = table.copy(options)
				fadeInOpts.fadeType = "in"
				fadeInOpts.track = newTrack
				fadeInOpts.reference = newRef
				fadeInOpts.volume = fadeInOpts.volume or getVolume { module = fadeInOpts.module }
				fader.fade(fadeInOpts)
			end
		end
	end
end

return this
