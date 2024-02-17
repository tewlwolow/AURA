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

-- Helper functions
local isInterior = common.cellIsInterior
local checkCellDiff = common.checkCellDiff

-- Constants
local MAX = 1
local MIN = 0

-- Resolve options and return the randomised track per conditions given --
function this.getTrack(options)
	--debugLog("Parsing passed options.")
	local moduleName = options.module

	if not moduleName then debugLog("No module detected. Returning.") end

	-- There's no escaping useLast :( --
	local useLast = options.last
	local nextTrack = moduleData[moduleName].nextTrack
	local nextTrackTimer = common.isTimerAlive(moduleData[moduleName].nextTrackTimer)

	if useLast and nextTrack and nextTrackTimer then
		return nextTrack
	elseif useLast and moduleData[moduleName].new then
		return moduleData[moduleName].new
	end

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
	if (not table) or (#table == 0) then
		debugLog("No table found (or empty table). Returning.")
		return
	end

	local newTrack = table[math.random(1, #table)]
	if moduleData[moduleName].new and #table > 1 then
		while newTrack.id == moduleData[moduleName].new.id do
			newTrack = table[math.random(1, #table)]
		end
	end

	debugLog("Selected track: " .. newTrack.id)

	return newTrack
end

function this.isStopping(moduleName)
	local old = modules.getCurrentlyPlaying(moduleName, "old") or {}
	local new = modules.getCurrentlyPlaying(moduleName, "new") or {}
	local oldTrack, oldRef = table.unpack(old)
	local newTrack, newRef = table.unpack(new)

	return oldTrack
		and (fader.isRunning { module = moduleName, track = oldTrack, reference = oldRef, fadeType = "out", removeTrack = true }
			or fader.isRunning { module = moduleName, track = newTrack, reference = newRef, fadeType = "out", removeTrack = true })
		and not (fader.isRunning { module = moduleName, track = newTrack, reference = newRef, fadeType = "in" }
			or fader.isRunning { module = moduleName, track = oldTrack, reference = oldRef, fadeType = "in" })
end

-- Sometimes we need to just remove the sounds without fading --
-- If fade is in progress for the given track and ref, we'll cancel the fade first --
function this.removeImmediate(options)
	local moduleName = options.module

	local function rem(track, ref)
		fader.cancel(moduleName, track, ref)
		tes3.removeSound { sound = track, reference = ref }
	end

	local targetTrack = common.getTrackPlaying(options.track, options.reference)
	if targetTrack then
		rem(targetTrack, options.reference)
		return
	end

	local newRefHandle = moduleData[options.module].newRefHandle
	local newRef = newRefHandle and newRefHandle:getObject()
	local newTrack = common.getTrackPlaying(moduleData[options.module].new, newRef)
	if newTrack then
		debugLog(string.format("[%s] Immediately removing new track %s -> %s.", moduleName, newTrack.id,
		tostring(newRef)))
		rem(newTrack, newRef)
	end

	local oldRefHandle = moduleData[options.module].oldRefHandle
	local oldRef = oldRefHandle and oldRefHandle:getObject()
	local oldTrack = common.getTrackPlaying(moduleData[options.module].old, oldRef)
	if oldTrack then
		debugLog(string.format("[%s] Immediately removing old track %s -> %s.", moduleName, oldTrack.id,
		tostring(oldRef)))
		rem(oldTrack, oldRef)
	end
end

-- Remove the sound for a given module, but with fade out --
function this.remove(options)
	local moduleName = options.module
	local targetTrack = common.getTrackPlaying(options.track, options.reference)
	local oldRefHandle = moduleData[moduleName].oldRefHandle
	local newRefHandle = moduleData[moduleName].newRefHandle
	local oldRef = oldRefHandle and oldRefHandle:getObject()
	local newRef = newRefHandle and newRefHandle:getObject()
	local oldTrack = common.getTrackPlaying(moduleData[moduleName].old, oldRef)
	local newTrack = common.getTrackPlaying(moduleData[moduleName].new, newRef)

	local function fadeOut(track, ref)
		fader.cancel(moduleName, track, ref)
		fader.fade{
			module = moduleName,
			fadeType = "out",
			track = track,
			reference = ref,
			removeTrack = true,
		}
	end

	if targetTrack then
		fadeOut(targetTrack, options.reference)
		return
	end

	if newTrack then fadeOut(newTrack, newRef) end
	if (oldTrack) and (oldTrack ~= newTrack) then fadeOut(oldTrack, oldRef) end
end

-- Sometiems we need to play a sound immediately as well.
-- This function doesn't remove sounds on its own. It's the module's
-- decision to remove sounds before immediately playing anything else.
function this.playImmediate(options)
	local moduleName = options.module
	local ref = options.reference or tes3.mobilePlayer and tes3.mobilePlayer.reference
	local track = options.track or this.getTrack(options)

	if track and ref and not tes3.getSoundPlaying { sound = track, reference = ref } then
		local volume = math.clamp(math.round(options.volume or getVolume { module = moduleName }, 2), MIN, MAX)
		local pitch = options.pitch or volumeController.getPitch(moduleName)
		if tes3.playSound {
			sound = track,
			reference = ref,
			volume = volume,
			pitch = pitch,
			loop = true,
		} then
			debugLog(string.format("[%s] Successfully played with volume %s: %s -> %s", moduleName, volume, track.id, tostring(ref)))
			moduleData[moduleName].lastVolume = volume
			moduleData[moduleName].old = moduleData[moduleName].new
			moduleData[moduleName].oldRefHandle = moduleData[moduleName].newRefHandle
			moduleData[moduleName].new = track
			moduleData[moduleName].newRefHandle = tes3.makeSafeObjectHandle(ref)
			return true
		end
	end
	return false
end

-- Supporting kwargs here
-- Main entry point, resolves all data received and decides what to do next --
function this.play(options)
	local moduleName = options.module
	local nextTrack = moduleData[moduleName].nextTrack
	local nextTrackTimer = moduleData[moduleName].nextTrackTimer
	local callerCell = options.cell

	local function clearQueue()
		if nextTrackTimer then nextTrackTimer:cancel() end
		moduleData[moduleName].nextTrack = nil
	end

	local oldTrack, newTrack, oldRef, newRef, fadeOutOpts, fadeInOpts, removeTrack, trackFading
	newTrack = options.track or this.getTrack(options)
	newRef = options.reference or tes3.mobilePlayer and tes3.mobilePlayer.reference
	if not (newTrack and newRef) then
		--debugLog(string.format("[!][%s] newTrack: %s | newRef: %s. Returning.", moduleName, newTrack, newRef))
		clearQueue()
		return
	end

	-- Suspending additional fade/crossfade requests until ongoing fades for the caller module are finished --
	-- If more calls are received while suspended, the previous suspended call will be canceled and the newer one will become suspended --
	-- The suspended call will also be canceled if a "cellDiff" has occurred since the initial call --
	-- Should cover edge case where module becomes stale (no tracks playing) if changing cells too fast during crossfades --
	if not options.noQueue and callerCell then
		trackFading = fader.isRunning{module = moduleName}
		if trackFading then
			if nextTrackTimer then nextTrackTimer:cancel() end
			debugLog(string.format("[###][%s->%s] Fader is running (%s). Trying later.", moduleName, newTrack, trackFading.id))
			moduleData[moduleName].nextTrack = newTrack
			moduleData[moduleName].nextTrackTimer = timer.start {
				callback = function()
					local cellNow = tes3.getPlayerCell()
					if not cellNow then return end
					debugLog(string.format("[###][%s->%s] cellNow: %s | callerCell: %s", moduleName, newTrack, cellNow, callerCell))
					local differentCell = callerCell ~= cellNow
					local intToInt = differentCell and isInterior(callerCell) and isInterior(cellNow)
					local cellDiff = checkCellDiff(cellNow, callerCell)
					if cellDiff or intToInt then
						debugLog(string.format("[###][%s->%s] cellDiff or intToInt. Discarding request.", moduleName, newTrack))
						return
					end
					debugLog(string.format("[###][%s->%s] Retrying.", moduleName, newTrack))
					this.play(options)
				end,
				type = timer.real,
				iterations = 1,
				duration = 2,
			}
			return
		end
	end

	clearQueue()

	-- Move the queue forward --
	moduleData[moduleName].old = moduleData[moduleName].new
	moduleData[moduleName].oldRefHandle = moduleData[moduleName].newRefHandle

	-- If old track is playing, then we'll first fade it out. Otherwise, we'll just fade in the new track --
	if not options.noCrossfade then
		local oldRefHandle = moduleData[moduleName].oldRefHandle
		if oldRefHandle and oldRefHandle:valid() then
			oldRef = oldRefHandle:getObject()
			debugLog(string.format("[%s] oldRef: %s", moduleName, oldRef))
			oldTrack = common.getTrackPlaying(moduleData[moduleName].old, oldRef)
			debugLog(string.format("[%s] oldTrack: %s", moduleName, oldTrack))
		end
	end

	debugLog(string.format("[%s] newRef: %s", moduleName, newRef))
	debugLog(string.format("[%s] newTrack: %s", moduleName, newTrack))

	-- Remove old track by default when crossfading, unless instructed otherwise --
	removeTrack = (options.removeTrack == nil) and true or options.removeTrack

	if oldTrack and oldTrack ~= newTrack then
		fadeOutOpts = table.copy(options)
		fadeOutOpts.fadeType = "out"
		fadeOutOpts.track = oldTrack
		fadeOutOpts.reference = oldRef
		fadeOutOpts.removeTrack = removeTrack
		fader.fade(fadeOutOpts)
	end

	if newTrack and this.playImmediate {
		module = moduleName,
		reference = newRef,
		track = newTrack,
		volume = MIN,
		pitch = options.pitch,
	} then
		fadeInOpts = table.copy(options)
		fadeInOpts.fadeType = "in"
		fadeInOpts.track = newTrack
		fadeInOpts.reference = newRef
		fadeInOpts.volume = fadeInOpts.volume or getVolume(fadeInOpts)
		fader.fade(fadeInOpts)
	end
end

return this
