local cellData = require("tew.AURA.cellData")
local climates = require("tew.AURA.Ambient.Outdoor.outdoorClimates")
local config = require("tew.AURA.config")
local common = require("tew.AURA.common")
local defaults = require("tew.AURA.defaults")
local modules = require("tew.AURA.modules")
local moduleData = modules.data
local sounds = require("tew.AURA.sounds")

local isOpenPlaza = common.isOpenPlaza

local moduleInteriorWeather = config.moduleInteriorWeather
local playInteriorAmbient = config.playInteriorAmbient

local moduleName = "outdoor"

local climateLast, weatherLast, timeLast
local climateNow, weatherNow, timeNow
local interiorTimer
local cell, cellLast
local WtC

local debugLog = common.debugLog

local blockedWeathers = moduleData[moduleName].blockedWeathers

-- Reset stuff on load to not pollute our logic --
local function runResetter()
	climateLast, weatherLast, timeLast = nil, nil, nil
	climateNow, weatherNow, timeNow = nil, nil, nil
end

local function updateConditions(resetTimerFlag)
	debugLog("Updating conditions.")

	if resetTimerFlag
		and interiorTimer
		and not cell.isOrBehavesAsExterior
		and not table.empty(cellData.windoors) then
		interiorTimer:reset()
	end
	timeLast = timeNow
	climateLast = climateNow
	weatherLast = weatherNow
	cellLast = cell
end

local function stopWindoors(immediateFlag)
	local remove = immediateFlag and sounds.removeImmediate or sounds.remove
	if not table.empty(cellData.windoors) then
		for _, windoor in ipairs(cellData.windoors) do
			if windoor ~= nil then
				remove { module = moduleName, reference = windoor }
			end
		end
	end
end

-- Because MW engine will otherwise scrap the sound and not put it up again. Dumb thing --
local function playWindoors()
	if table.empty(cellData.windoors) then return end
	debugLog("Updating interior doors and windows.")
	local playerPos = tes3.player.position:copy()

	for _, windoor in ipairs(cellData.windoors) do
		local track = windoor.tempData.tew.AURA.OUT.track

		if windoor ~= nil and playerPos:distance(windoor.position:copy()) < 1800
			and not common.getTrackPlaying(track, windoor) then
			sounds.play {
				module = moduleName,
				track = track,
				reference = windoor,
				noQueue = true,
				noCrossfade = true,
			}
		end
	end
end

local function cellCheck(e)
	-- Gets messy otherwise --
	-- We don't want to reset sounds when the player is waiting for a longer time --
	-- We'll resolve conditions after UI waiting element is destroyed --
	local mp = tes3.mobilePlayer
	if (not mp) or (mp and (mp.waiting or mp.traveling or mp.sleeping)) then
		return
	end

	debugLog("Cell changed or time check triggered. Running cell check.")

	cell = tes3.getPlayerCell()
	if (not cell) then
		debugLog("No cell detected. Returning.")
		return
	end
	debugLog("Cell: " .. cell.editorName)

	if common.checkCellDiff(cell, cellLast) then
		debugLog("Cell type changed. Removing module sounds.")
		sounds.removeImmediate { module = moduleName }
	end

	local regionObject = tes3.getRegion(true)

	-- Fallback
	if not regionObject then
		regionObject = common.getFallbackRegion()
	end

	local region = regionObject.id

	if e and e.to then
		debugLog("Weather transitioning.")
		weatherNow = e.to.index
	else
		weatherNow = regionObject.weather.index
	end
	debugLog("Weather: " .. weatherNow)

	-- Bugger off if weather is blocked --
	if blockedWeathers[weatherNow] then
		debugLog("Uneligible weather detected. Removing sounds.")
		stopWindoors(true)
		sounds.remove { module = moduleName }
		updateConditions()
		return
	end

	if region == nil then
		debugLog("No region detected. Returning.")
		return
	end

	-- Checking climate --
	climateNow = climates.regions[region]

	if not climateNow then
		debugLog("Blacklisted region - no climate detected. Returning.")
		return
	end
	debugLog("Climate: " .. climateNow)

	-- Checking time --
	local gameHour = tes3.worldController.hour.value
	if (gameHour >= WtC.sunriseHour - 3) and (gameHour < WtC.sunriseHour + 3) then
		timeNow = "sr"
	elseif (gameHour >= WtC.sunriseHour + 3) and (gameHour < WtC.sunsetHour - 3) then
		timeNow = "d"
	elseif (gameHour >= WtC.sunsetHour - 3) and (gameHour < WtC.sunsetHour + 3) then
		timeNow = "ss"
	elseif (gameHour >= WtC.sunsetHour + 3) or (gameHour < WtC.sunriseHour - 3) then
		timeNow = "n"
	end
	debugLog("Time: " .. timeNow)

	-- Randomising every time any of these change --
	local useLast = (timeNow == timeLast and weatherNow == weatherLast and climateNow == climateLast) or false

	-- Transition filter chunk --
	if useLast and (cell == cellLast) then
		debugLog("Found same cell, same conditions. Returning.")
		updateConditions(true)
		return
	end

	-- Exterior cells --
	if (cell.isOrBehavesAsExterior and not isOpenPlaza(cell)) then
		debugLog(string.format("Found exterior cell. useLast: %s", useLast))
		sounds.play {
			module = moduleName,
			climate = climateNow,
			time = timeNow,
			last = useLast,
		}
		-- Interior cells --
	elseif cell.isInterior then
		debugLog("Found interior cell.")
		stopWindoors(true)
		if (cell ~= cellLast) then
			sounds.removeImmediate { module = moduleName } -- Needed to catch previous interior cell sounds --
		end
		if (not playInteriorAmbient) or (playInteriorAmbient and isOpenPlaza(cell) and weatherNow == 3) then
			debugLog("Found interior cell and playInteriorAmbient off. Removing sounds.")
			sounds.removeImmediate { module = moduleName }
			updateConditions()
			return
		end
		if common.getCellType(cell, common.cellTypesSmall) == true
			or common.getCellType(cell, common.cellTypesTent) == true then
			debugLog("Found small interior cell. useLast: " .. tostring(useLast))
			sounds.play {
				module = moduleName,
				climate = climateNow,
				time = timeNow,
				last = useLast,
			}
		else
			debugLog("Found big interior cell.")
			if not moduleInteriorWeather then
				updateConditions()
				return
			end
			if not table.empty(cellData.windoors) then
				debugLog("Found " ..
					#cellData.windoors .. " windoor(s). Playing interior loops. useLast: " .. tostring(useLast))
				local windoorTrack = useLast and moduleData[moduleName].new or sounds.getTrack {
					module = moduleName,
					climate = climateNow,
					time = timeNow,
				}
				for _, windoor in ipairs(cellData.windoors) do
					local tempData = windoor.tempData
					if not tempData.tew then tempData.tew = {} end
					if not tempData.tew.AURA then tempData.tew.AURA = {} end
					if not tempData.tew.AURA.OUT then tempData.tew.AURA.OUT = {} end
					tempData.tew.AURA.OUT.track = windoorTrack
				end
				updateConditions(true)
				return
				-- Special case - where the lack of windoors in otherwise eligible 'big' interior would break our state and make it stale
				-- e.g. Ald-Ruhn Mages Guild -> Vivec Mages Guild -> Foreign Quarter Plaza
			else
				runResetter()
			end
		end
	end

	updateConditions()
	debugLog("Cell check complete.")
end

-- Pause interior timer on condition change trigger --
local function onConditionChanged(e)
	if interiorTimer then interiorTimer:pause() end
	cellCheck(e)
end

-- After waiting/travelling --
local function waitCheck(e)
	local element = e.element
	element:registerAfter("destroy", function()
		timer.start {
			type = timer.game,
			duration = 0.01,
			callback = onConditionChanged,
		}
	end)
end

-- Reset windoors when exiting underwater --
local function resetWindoors(e)
	if table.empty(cellData.windoors)
		or not moduleInteriorWeather
		or not playInteriorAmbient
		or not modules.getWindoorPlaying(moduleName) then
		return
	end
	if interiorTimer then interiorTimer:pause() end
	debugLog("Resetting windoors.")
	stopWindoors(true)
	if interiorTimer then interiorTimer:reset() end
end

-- Check for time changes --
local function runHourTimer()
	timer.start({ duration = 0.5, callback = cellCheck, iterations = -1, type = timer.game })
end

-- Run hour timer, start and pause interiorTimer on loaded --
local function onLoaded()
	runHourTimer()
	if moduleInteriorWeather then
		if not interiorTimer then
			interiorTimer = timer.start {
				duration = 1,
				iterations = -1,
				callback = playWindoors,
				type = timer.simulate,
			}
		end
		interiorTimer:pause()
	end
end


WtC = tes3.worldController.weatherController
event.register("loaded", onLoaded, { priority = -160 })
event.register("load", runResetter, { priority = -160 })
event.register("cellChanged", onConditionChanged, { priority = -160 })
event.register("weatherTransitionStarted", onConditionChanged, { priority = -160 })
event.register("weatherTransitionFinished", onConditionChanged, { priority = -160 })
event.register("weatherTransitionImmediate", onConditionChanged, { priority = -160 })
event.register("weatherChangedImmediate", onConditionChanged, { priority = -160 })
event.register("AURA:exitedUnderwater", resetWindoors, { priority = -160 })
event.register("uiActivated", waitCheck, { filter = "MenuTimePass", priority = -5 })
debugLog("Outdoor Ambient Sounds module initialised.")
