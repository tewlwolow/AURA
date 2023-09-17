local serviceVoicesData = require("tew.AURA.Service Voices.serviceVoicesData")
local config = require("tew.AURA.config")
local common = require("tew.AURA.common")

local UIvol, SVvol = config.volumes.misc.UIvol / 100, config.volumes.misc.SVvol / 100
local moduleUI = config.moduleUI

local raceNames = serviceVoicesData.raceNames
local commonVoices = serviceVoicesData.commonVoices
local travelVoices = serviceVoicesData.travelVoices
local spellVoices = serviceVoicesData.spellVoices
local trainingVoices = serviceVoicesData.trainingVoices

local UISpells = config.UISpells
local serviceFlags = {
	serviceRepair = config.serviceRepair,
	serviceSpells = config.serviceSpells,
	serviceTraining = config.serviceTraining,
	serviceSpellmaking = config.serviceSpellmaking,
	serviceEnchantment = config.serviceEnchantment,
	serviceTravel = config.serviceTravel,
	serviceBarter = config.serviceBarter
}

local newVoice, lastVoice = "init", "init"

local debugLog = common.debugLog

local function getServiceVoiceData(e, voiceData)
	local npcId = tes3ui.getServiceActor(e)
	local raceId = npcId.object.race.id
	local raceLet = raceNames[raceId]
	local sexLet = npcId.object.female and "f" or "m"

	return voiceData[raceLet] and voiceData[raceLet][sexLet] or commonVoices[raceLet] and commonVoices[raceLet][sexLet]
end

local function playServiceVoice(npcId, raceLet, sexLet, serviceFeed)
	if #serviceFeed > 0 then
		while newVoice == lastVoice or newVoice == nil do
			newVoice = serviceFeed[math.random(1, #serviceFeed)]
		end

		tes3.removeSound { reference = npcId }
		tes3.say {
			volume = 0.9 * SVvol,
			soundPath = string.format("Vo\\%s\\%s\\%s.mp3", raceLet, sexLet, newVoice),
			reference = npcId
		}
		lastVoice = newVoice
		debugLog("NPC says a comment for the service.")
	end
end

local function handleServiceGreet(e, voiceData, closeButtonName, playMysticGateSound, playMenuClickSound)
	local closeButton = e.element:findChild(tes3ui.registerID(closeButtonName))
	if closeButton then
		closeButton:register("mouseDown", function()
			if playMenuClickSound then
				tes3.playSound { sound = "Menu Click", reference = tes3.player }
			end
		end)
	end

	local npcId = tes3ui.getServiceActor(e)
	local raceId = npcId.object.race.id
	local raceLet = raceNames[raceId]
	local sexLet = npcId.object.female and "f" or "m"

	local serviceFeed = getServiceVoiceData(e, voiceData) or {}

	playServiceVoice(npcId, raceLet, sexLet, serviceFeed)

	if playMysticGateSound and UISpells and moduleUI then
		tes3.playSound { soundPath = "FX\\MysticGate.wav", reference = tes3.player, volume = 0.2 * UIvol, pitch = 1.8 }
		debugLog("Opening spell menu sound played.")
	end
end

local function registerGreetEvent(serviceFlag, greetFunction, filter, closeButtonName, playMysticGateSound, playMenuClickSound)
	if serviceFlags[serviceFlag] then
		event.register("uiActivated", function(e)
			handleServiceGreet(e, greetFunction, closeButtonName, playMysticGateSound, playMenuClickSound)
		end, { filter = filter, priority = -10 })
	end
end

registerGreetEvent("serviceTravel", travelVoices, "MenuServiceTravel", "", false, true) -- Play Menu Click
registerGreetEvent("serviceBarter", commonVoices, "MenuBarter", "", false, true) -- Play Menu Click
registerGreetEvent("serviceTraining", trainingVoices, "MenuServiceTraining", "MenuServiceTraining_Okbutton", false, true) -- Play Menu Click
registerGreetEvent("serviceEnchantment", commonVoices, "MenuEnchantment", "", false, true) -- Play Menu Click
registerGreetEvent("serviceSpellmaking", spellVoices, "MenuSpellmaking", "MenuSpellmaking_Cancelbutton", false, true) -- Play Menu Click
registerGreetEvent("serviceSpells", spellVoices, "MenuServiceSpells", "MenuServiceSpells_Okbutton", true, true) -- Play both Mystic Gate and Menu Click
registerGreetEvent("serviceRepair", commonVoices, "MenuServiceRepair", "MenuServiceRepair_Okbutton", false, true) -- Play Menu Click
