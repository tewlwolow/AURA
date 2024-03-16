local healthFlag, fatigueFlag, magickaFlag, diseaseFlag, blightFlag = 0, 0, 0, 0, 0

local healthTimer, fatigueTimer, magickaTimer, diseaseTimer, blightTimer
local genderFatigue, genderDisease = "", ""
local player

local config = require("tew.AURA.config")

-- People don't cough underwater I guess --
local function isPlayerUnderWater()
    local cell = tes3.getPlayerCell()
    if cell.hasWater then
        local waterHeight = cell.waterLevel or 0
        local playerZ = tes3.player.position.z
        local height = playerZ - waterHeight
        if height < -50 then
            return true
        end
    end
    return false
end

-- Determine player gender on load --
local function onLoaded()
    if tes3.player.object.female then
        genderFatigue = "fatigue_f_"
        genderDisease = "disease_f_"
    else
        genderFatigue = "fatigue_m_"
        genderDisease = "disease_m_"
    end
    player = tes3.mobilePlayer
    healthFlag = 0
    fatigueFlag = 0
    magickaFlag = 0
    diseaseFlag = 0
    blightFlag = 0
end

local function onStatReview(e)
    local element = e.element:findChild("MenuStatReview_Okbutton")

    element:registerAfter("mouseDown", function()
        onLoaded()
        event.unregister("uiActivated", onStatReview, { filter = "MenuStatReview" })
    end)
end


-- Check for disease, which is actually a spell type --
local function checkDisease(ref)
    local disease
    for spell in tes3.iterate(ref.object.spells.iterator) do
        if (spell.castType == tes3.spellType.disease) then
            disease = "Disease"
            break
        end
    end
    return disease
end

-- Same as above, just for Blight --
local function checkBlight(ref)
    local blight
    for spell in tes3.iterate(ref.object.spells.iterator) do
        if (spell.castType == tes3.spellType.blight) then
            blight = "Blight"
            break
        end
    end
    return blight
end

-- Play cough stuff if the player is diseased --
local function playDisease()
    if diseaseFlag == 1 then return end
    diseaseTimer = timer.start {
        type = timer.simulate,
        duration = math.random(45, 90),
        iterations = 1,
        callback = function()
            tes3.playSound {
                soundPath = "tew\\A\\PC\\" .. genderDisease .. math.random(5) .. ".wav",
                volume = 0.7 * (config.volumes.misc.vsVol / 100),
                reference = player,
            }
            diseaseFlag = 0
        end,
    }
    diseaseFlag = 1
end

-- Shudder before Ur! --
local function playBlight()
    if blightFlag == 1 then return end
    blightTimer = timer.start {
        type = timer.simulate,
        duration = math.random(35, 45),
        iterations = 1,
        callback = function()
            tes3.playSound {
                soundPath = "tew\\A\\PC\\blight_" .. math.random(6) .. ".wav",
                volume = 0.9 * (config.volumes.misc.vsVol / 100),
                reference = player,
            }
            blightFlag = 0
        end,
    }
    blightFlag = 1
end

-- Thum thum, thum thum --
-- Actually it plays nicely with "starving" effect from Ashfall as well --
local function playHealth()
    if healthFlag == 1 then return end
    healthTimer = timer.start {
        type = timer.simulate,
        duration = math.remap(player.health.normalized, 0.001, 0.33, 0.4, 1.25),
        iterations = 1,
        callback = function()
            tes3.playSound {
                soundPath = "tew\\A\\PC\\health.wav",
                volume = 0.7 * (config.volumes.misc.vsVol / 100),
                pitch = math.remap(player.health.normalized, 0.0, 0.33, 1.05, 0.95),
                reference = player,
            }
            healthFlag = 0
        end,
    }
    healthFlag = 1
end

-- Me when standing up for a minute: --
local function playFatigue()
    if fatigueFlag == 1 then return end

    local lower = math.remap(player.fatigue.normalized, 0.0, 0.33, 10, 15)
    local upper = math.remap(player.fatigue.normalized, 0.0, 0.33, 20, 25)

    fatigueTimer = timer.start {
        type = timer.simulate,
        duration = math.random(lower, upper),
        iterations = 1,
        callback = function()
            tes3.playSound {
                soundPath = "tew\\A\\PC\\" .. genderFatigue .. math.random(5) .. ".wav",
                volume = config.volumes.misc.vsVol / 100,
                pitch = math.random(95, 105) / 100,
                reference = player,
            }
            fatigueFlag = 0
        end,
    }
    fatigueFlag = 1
end

-- Weeeeeuuuuiii no casting for ya --
local function playMagicka()
    if magickaFlag == 1 then return end

    local lower = math.remap(player.magicka.normalized, 0.0, 0.33, 15, 20)
    local upper = math.remap(player.magicka.normalized, 0.0, 0.33, 25, 35)

    magickaTimer = timer.start {
        type = timer.simulate,
        duration = math.random(lower, upper),
        iterations = 1,
        callback = function()
            tes3.playSound {
                soundPath = "tew\\A\\PC\\magicka.wav",
                volume = 0.6 * (config.volumes.misc.vsVol / 100),
                pitch = math.remap(player.magicka.normalized, 0.0, 0.33, 1.05, 0.95),
                reference = player,
            }
            magickaFlag = 0
        end,
    }
    magickaFlag = 1
end

-- Centralised vitals resolver --
local function playVitals()
    if config.PChealth then
        local health = player.health.normalized

        if (not player.isDead) and (health ~= 0) and (health < 0.33) then
            playHealth()
        else
            if healthTimer then
                healthTimer:cancel()
            end
            healthFlag = 0
        end
    elseif healthTimer then
        healthTimer:cancel()
        healthFlag = 0
    end

    if config.PCfatigue then
        if isPlayerUnderWater() then
            if fatigueTimer then
                fatigueTimer:cancel()
            end
            fatigueFlag = 0
            return
        end

        local fatigue = player.fatigue.normalized

        if fatigue < 0.33 then
            playFatigue()
        else
            if fatigueTimer then
                fatigueTimer:cancel()
            end
            fatigueFlag = 0
        end
    elseif fatigueTimer then
        fatigueTimer:cancel()
        fatigueFlag = 0
    end

    if config.PCmagicka then
        local magicka = player.magicka.normalized

        if magicka < 0.33 then
            playMagicka()
        else
            if magickaTimer then
                magickaTimer:cancel()
            end
            magickaFlag = 0
        end
    elseif magickaTimer then
        magickaTimer:cancel()
        magickaFlag = 0
    end


    if config.PCDisease then
        local disease = checkDisease(player)
        if disease == "Disease" then
            playDisease()
        else
            if diseaseTimer then
                diseaseTimer:cancel()
            end
            diseaseFlag = 0
        end
    elseif diseaseTimer then
        diseaseTimer:cancel()
        diseaseFlag = 0
    end

    if config.PCBlight then
        local blight = checkBlight(player)
        if blight == "Blight" then
            playBlight()
        else
            if blightTimer then
                blightTimer:cancel()
            end
            blightFlag = 0
        end
    elseif blightTimer then
        blightTimer:cancel()
        blightFlag = 0
    end
end

-- For underwater stuff --
local function positionCheck()
    if fatigueTimer then
        fatigueTimer:cancel()
    end
    fatigueFlag = 0

    if diseaseTimer then
        diseaseTimer:cancel()
    end
    diseaseFlag = 0

    if blightTimer then
        blightTimer:cancel()
    end
    blightFlag = 0
end

event.register("uiActivated", onStatReview, { filter = "MenuStatReview" })
event.register("uiActivated", positionCheck, { filter = "MenuSwimFillBar" })
event.register("loaded", onLoaded)
event.register("simulate", playVitals)
