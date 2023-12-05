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
    "AB_Flora_AcSapling01",
    "AB_Flora_AcSapling02",
    "AB_Flora_AcSapling03",
    "AB_Flora_AcSapling04",
    "AB_Flora_AiSapling01",
    "AB_Flora_AiSapling02",
    "AB_Flora_AiSapling03",
    "AB_Flora_AiSapling04",
    "AB_Flora_BcSapling01",
    "AB_Flora_BcSapling02",
    "AB_Flora_BcSapling03",
    "AB_Flora_GlSapling01",
    "AB_Flora_GlSapling02",
    "AB_Flora_WgSapling01",
    "AB_Flora_WgSapling02",
    "AB_Flora_WgSapling03",
    "AB_Flora_WgSapling04",
    "AB_Flora_GoldReed01",
    "AB_Flora_GoldReed02",
    "AB_Flora_GoldReed03",
    "AB_Flora_GoldReed04",
    "AB_Flora_GoldReedGrass",
    "AB_Flora_GoldReedGroup01",
    "AB_Flora_GoldReedGroup02",
    "AB_Flora_GoldReedGroup03",
    "AB_Flora_MvGrass_01",
    "AB_f_Bloodgrass_01",
    "AB_f_Bloodgrass_02",
    "AB_f_BlueKanet_01",
    "AB_f_BlueKanet_02",
    "AB_f_HackleLo3_o",
    "AB_f_HackleLo4_o",
    "AB_f_HackleLo5_o",
    "AB_f_HackleLo6_o",
    "AB_f_PomegranateTree01",
    "AB_f_PomegranateTree02",
    "T_Bkm_Flora_SomnFern01",
    "T_Cyr_Flora_Alkanet01",
    "T_Cyr_Flora_Chokeberr01",
    "T_Cyr_Flora_Monkshood01",
    "T_Cyr_Flora_MorningGl01",
    "T_Cyr_Flora_MorningGl02",
    "T_Cyr_Flora_MorningGl03",
    "T_Cyr_Flora_Motherw01",
    "T_Cyr_Flora_Peony01",
    "T_Cyr_Flora_Peony02",
    "T_Cyr_Flora_PoisonLil01",
    "T_Cyr_Flora_Primrose01",
    "T_Cyr_Flora_Primrose02",
    "T_Cyr_Flora_Primrose03",
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

    local config = mwse.loadConfig("AURA", defaults)
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
