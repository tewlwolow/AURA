local common = require("tew.AURA.common")
local defaults = require("tew.AURA.defaults")
local soundData = require("tew.AURA.soundData")

local debugLog = common.debugLog

local ids = {
    "flora_ash_grass",
    "flora_bc_fern",
    "flora_bc_grass",
    "flora_bittergreen",
    "flora_black_anther",
    "flora_black_lichen",
    "flora_bm_belladonna",
    "flora_bm_grass",
    "flora_bm_holly",
    "flora_bm_shrub",
    "flora_bm_wolfsbane",
    "flora_bush",
    "flora_chokeweed",
    "flora_comberry",
    "flora_corkbulb",
    "flora_fire_fern",
    "flora_gold_kanet",
    "flora_grass",
    "flora_green_lichen",
    "flora_hackle-lo",
    "flora_heather",
    "flora_kreshweed",
    "flora_marshmerrow",
    "flora_plant",
    "flora_red_lichen",
    "flora_rm_scathecraw",
    "flora_roobrush",
    "flora_saltrice",
    "flora_sedge",
    "flora_stoneflower",
    "flora_wickwheat",
    "flora_willow_flower",
}

local playingBlocked = false
local lastPlayerPos
local function playFlora()

    if (playingBlocked) or (not tes3.mobilePlayer) then return end

    local player = tes3.mobilePlayer.reference
    local playerPos = player.position

    -- If we just played a sound, don't play anymore if we're in the same spot
    if lastPlayerPos then
        if playerPos:copy():distance(lastPlayerPos) > 200 then
            lastPlayerPos = nil
        else
            return
        end
    end

    local playerHeight = tes3.player.object.boundingBox and tes3.player.object.boundingBox.max.z or 0
    local hitResult = tes3.rayTest{
        position = {
            player.position.x,
            player.position.y,
            player.position.z + (playerHeight / 2)
        },
        direction = {0, 0, -1},
        findAll = false,
        maxDistance = (playerHeight / 2) + 50,
        ignore = {player},
        useModelCoordinates = true,
        useBackTriangles = false,
    }

    local object = hitResult and hitResult.reference and hitResult.reference.object

    if not object
    or not (object.objectType == tes3.objectType.static
            or object.objectType == tes3.objectType.container)
    or not common.getMatch(ids, object.id:lower())
    or (object.deleted or object.disabled) then
        return
    end

    local config = mwse.loadConfig("AURA", defaults)
    local volume = config.volumes.misc.floraVol / 100
    local sound = table.choice(soundData.flora)
    if not sound then return end

    tes3.playSound{
        sound = sound,
        reference = hitResult.reference,
        volume = volume,
        pitch = 1,
        loop = false,
    }
    debugLog('Played ' .. sound.id)
    playingBlocked = true
    lastPlayerPos = playerPos:copy()
    timer.start{
        type = timer.simulate,
        iterations = 1,
        duration = 2,
        callback = function() playingBlocked = false end,
    }
end
event.register(tes3.event.simulate, playFlora)