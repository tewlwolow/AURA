local common = require("tew.AURA.common")
local config = require("tew.AURA.config")
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
    "ab_flora_acsapling01",
    "ab_flora_acsapling02",
    "ab_flora_acsapling03",
    "ab_flora_acsapling04",
    "ab_flora_aisapling01",
    "ab_flora_aisapling02",
    "ab_flora_aisapling03",
    "ab_flora_aisapling04",
    "ab_flora_bcsapling01",
    "ab_flora_bcsapling02",
    "ab_flora_bcsapling03",
    "ab_flora_glsapling01",
    "ab_flora_glsapling02",
    "ab_flora_wgsapling01",
    "ab_flora_wgsapling02",
    "ab_flora_wgsapling03",
    "ab_flora_wgsapling04",
    "ab_flora_goldreed01",
    "ab_flora_goldreed02",
    "ab_flora_goldreed03",
    "ab_flora_goldreed04",
    "ab_flora_goldreedgrass",
    "ab_flora_goldreedgroup01",
    "ab_flora_goldreedgroup02",
    "ab_flora_goldreedgroup03",
    "ab_flora_mvgrass_01",
    "ab_f_bloodgrass_01",
    "ab_f_bloodgrass_02",
    "ab_f_bluekanet_01",
    "ab_f_bluekanet_02",
    "ab_f_hacklelo3_o",
    "ab_f_hacklelo4_o",
    "ab_f_hacklelo5_o",
    "ab_f_hacklelo6_o",
    "ab_f_pomegranatetree01",
    "ab_f_pomegranatetree02",
    "t_bkm_flora_somnfern01",
    "t_cyr_flora_alkanet01",
    "t_cyr_flora_chokeberr01",
    "t_cyr_flora_monkshood01",
    "t_cyr_flora_morninggl01",
    "t_cyr_flora_morninggl02",
    "t_cyr_flora_morninggl03",
    "t_cyr_flora_motherw01",
    "t_cyr_flora_peony01",
    "t_cyr_flora_peony02",
    "t_cyr_flora_poisonlil01",
    "t_cyr_flora_primrose01",
    "t_cyr_flora_primrose02",
    "t_cyr_flora_primrose03",
}

local lastPlayerPos

local function playFlora()
    if not tes3.mobilePlayer then return end

    local player = tes3.mobilePlayer.reference
    local playerPos = player.position

    -- If we just played a sound, don't play anymore if we're in the same spot
    if lastPlayerPos then
        if playerPos:copy():distance(lastPlayerPos) > 150 then
            lastPlayerPos = nil
        else
            return
        end
    end

    local playerHeight = tes3.player.object.boundingBox and tes3.player.object.boundingBox.max.z or 0
    local hitResult = tes3.rayTest {
        position = {
            player.position.x,
            player.position.y,
            player.position.z + (playerHeight / 2),
        },
        direction = { 0, 0, -1 },
        findAll = false,
        maxDistance = (playerHeight / 2) + 50,
        ignore = { player },
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

    local sound = table.choice(soundData.flora)
    if not sound then return end

    local volume = config.volumes.misc.floraVol / 100
    local pitch = math.random(80, 130) / 100

    tes3.playSound {
        sound = sound,
        reference = hitResult.reference,
        volume = volume,
        pitch = pitch,
        loop = false,
    }
    debugLog("Played " .. sound.id)
    lastPlayerPos = playerPos:copy()
end

local function runResetter()
    event.unregister(tes3.event.simulate, playFlora)
    lastPlayerPos = nil
end

local function onLoaded()
    runResetter()
    event.register(tes3.event.simulate, playFlora)
end

event.register(tes3.event.load, runResetter)
event.register(tes3.event.loaded, onLoaded)
