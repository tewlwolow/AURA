local healthFlag, fatigueFlag, magickaFlag, diseaseFlag, blightFlag = 0, 0, 0, 0, 0

local healthTimer, fatigueTimer, magickaTimer, diseaseTimer, blightTimer
local genderFatigue, genderDisease = "", ""
local player

local config = require("tew.AURA.config")
local PChealth = config.PChealth
local PCfatigue = config.PCfatigue
local PCmagicka = config.PCmagicka
local PCDisease = config.PCDisease
local PCBlight = config.PCBlight
local vsVol = config.volumes.misc.vsVol / 100

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
    if not diseaseTimer then
        diseaseTimer = timer.start { type = timer.real, duration = math.random(45, 90), iterations = -1, callback = function()
            tes3.playSound { soundPath = "tew\\A\\PC\\" .. genderDisease .. math.random(5) .. ".wav", volume = 0.7 * vsVol, reference = player }
        end }
    else
        diseaseTimer:resume()
    end
    diseaseFlag = 1
end

-- Shudder before Ur! --
local function playBlight()
    if blightFlag == 1 then return end
    if not blightTimer then
        blightTimer = timer.start { type = timer.real, duration = math.random(35, 45), iterations = -1, callback = function()
            tes3.playSound { soundPath = "tew\\A\\PC\\blight" .. math.random(5) .. ".wav", volume = 0.9 * vsVol, reference = player }
        end }
    else
        blightTimer:resume()
    end
    blightFlag = 1
end

-- Thum thum, thum thum --
-- Actually it plays nicely with "starving" effect from Ashfall as well --
local function playHealth()
    if healthFlag == 1 then return end
    if not healthTimer then
        healthTimer = timer.start { type = timer.real, duration = math.random(10, 20) / 10, iterations = -1, callback = function()
            tes3.playSound { soundPath = "tew\\A\\PC\\health.wav", volume = 0.7 * vsVol, pitch = math.remap(player.health.normalized, 0.0, 0.33, 1.05, 0.95), reference = player }
        end }
    else
        healthTimer:resume()
    end
    healthFlag = 1
end

-- Me when standing up for a minute: --
local function playFatigue()
    if fatigueFlag == 1 then return end
    if not fatigueTimer then
        fatigueTimer = timer.start { type = timer.real, duration = math.random(10, 20), iterations = -1, callback = function()
            tes3.playSound { soundPath = "tew\\A\\PC\\" .. genderFatigue .. math.random(5) .. ".wav", volume = vsVol, pitch = math.remap(player.fatigue.normalized, 0.0, 0.33, 1.05, 0.95), reference = player }
        end }
    else
        fatigueTimer:resume()
    end
    fatigueFlag = 1
end

-- Weeeeeuuuuiii no casting for ya --
local function playMagicka()
    if magickaFlag == 1 then return end
    if not magickaTimer then
        magickaTimer = timer.start { type = timer.real, duration = math.random(12, 25), iterations = -1, callback = function()
            tes3.playSound { soundPath = "tew\\A\\PC\\magicka.wav", volume = 0.6 * vsVol, pitch = math.remap(player.magicka.normalized, 0.0, 0.33, 1.05, 0.95), reference = player }
        end }
    else
        magickaTimer:resume()
    end
    magickaFlag = 1
end

-- Centralised vitals resolver --
local function playVitals()
    if PChealth then
        local health = player.health.normalized

        if health < 0.33 then
            playHealth()
        else
            if healthTimer then
                healthTimer:pause()
            end
            healthFlag = 0
        end
    end

    if PCfatigue then
        if isPlayerUnderWater() then
            if fatigueTimer then
                fatigueTimer:pause()
            end
            fatigueFlag = 0
            return
        end

        local fatigue = player.fatigue.normalized

        if fatigue < 0.33 then
            playFatigue()
        else
            if fatigueTimer then
                fatigueTimer:pause()
            end
            fatigueFlag = 0
        end
    end

    if PCmagicka then
        local magicka = player.magicka.normalized

        if magicka < 0.33 then
            playMagicka()
        else
            if magickaTimer then
                magickaTimer:pause()
            end
            magickaFlag = 0
        end
    end


    if PCDisease then
        local disease = checkDisease(player)
        if disease == "Disease" then
            playDisease()
        else
            if diseaseTimer then
                diseaseTimer:pause()
            end
            diseaseFlag = 0
        end
    end

    if PCBlight then
        local blight = checkBlight(player)
        if blight == "Blight" then
            playBlight()
        else
            if blightTimer then
                blightTimer:pause()
            end
            blightFlag = 0
        end
    end
end

-- For underwater stuff --
local function positionCheck()
    if PCfatigue then
        if fatigueTimer then
            fatigueTimer:pause()
        end
        fatigueFlag = 0
    end
    if PCDisease then
        if diseaseTimer then
            diseaseTimer:pause()
        end
        diseaseFlag = 0
    end

    if PCBlight then
        if blightTimer then
            blightTimer:pause()
        end
        blightFlag = 0
    end
end

event.register("uiActivated", onStatReview, { filter = "MenuStatReview" })
event.register("uiActivated", positionCheck, { filter = "MenuSwimFillBar" })
event.register("loaded", onLoaded)
event.register("simulate", playVitals)
