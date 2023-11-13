local common = require("tew.AURA.common")
local defaults = require("tew.AURA.defaults")
local debugLog = common.debugLog
local cellData = require("tew.AURA.cellData")
local soundData = require("tew.AURA.soundData")

local lastPlayedThunder, minVol, maxVol, addDelay

local function isVanillaThunder(soundId)
    for _, thunId in pairs(common.thunArray) do
        if soundId:lower() == thunId:lower() then return true end
    end
end

local function onSoundObjectPlay(e)

    if not cellData.cell
    or cellData.cell.isInterior
	or not e.sound or not isVanillaThunder(e.sound.id) then
        return
    end

    -- Don't play our thunder if some other mod is trying to play
    -- a thunder with the same sound id as the vanilla thunder

    local sourceMod = e.sound.sourceMod
    if sourceMod and sourceMod:lower() ~= "morrowind.esm" then
        debugLog(string.format("Got vanilla thunder from mod: %s. Returning.", sourceMod))
        return
    end


    -- For future reference, in case we want to intercept vanilla thunders
    -- in interior cells, these are some cells we either need to dodge or
    -- make sure we play our thunders without a delay, since these are
    -- scripted thunders that need to play at precise times:

    -- [cell name]                                             [CS script]
    -- Bamz-Amschend, Skybreak Gallery                 (tr_weathermachine)
    -- Ald Daedroth, Inner Shrine                     (SheogorathBlessing)
    -- Vivec, Puzzle Canal, Center                           (puzzlecanal)
    -- Hlormaren, Propylon Chamber                            (Warp_Andra)
    -- Berandas, Propylon Chamber                             (Warp_Andra)
    -- Falasmaryon, Propylon Chamber                          (Warp_Beran)
    -- Andasreth, Propylon Chamber                            (Warp_Beran)

    -- Also for reference, thunder sound ids from Distant Thunder mod:
    -- Distant_Thunder_00, Distant_Thunder_01, Distant_Thunder_02, Distant_Thunder_03

    local delay = math.random(1, 25) / 10 -- Light travels faster than sound
    local config = mwse.loadConfig("AURA", defaults)
    minVol = config.volumes.misc.thunderVolMin
    maxVol = config.volumes.misc.thunderVolMax
    addDelay = config.thunderSoundsDelay

    local thunder, lower, upper = nil, minVol, maxVol
    if lower > upper then lower = maxVol upper = minVol end
    while (not thunder) or (thunder == lastPlayedThunder) do
        thunder = table.choice(soundData.thunders)
    end

    local volume = math.random(lower, upper) / 100
    local pitch = math.random(65, 130) / 100

	timer.start{
		duration = addDelay and delay or 0.001,
		type = timer.simulate,
		callback = function()
            debugLog(string.format("Playing thunder: %s | vol: %s | pitch: %s", thunder.id, volume, pitch))
            thunder:play{volume = volume, pitch = pitch}
        end,
	}

    lastPlayedThunder = thunder

    e.block = true
end
event.register(tes3.event.soundObjectPlay, onSoundObjectPlay)

local modList = tes3.getModList() or {}
for _, mod in ipairs(modList) do
    if string.startswith(mod, "Distant Thunder") then
        tes3.messageBox("Distant Thunder is active, AURA thunders will not play.")
    end
end
