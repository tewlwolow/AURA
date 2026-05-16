local config = require("tew.AURA.config")
local playerRace, playerSex
local serviceVoicesData = require("tew.AURA.Service Voices.serviceVoicesData")
local raceNames = serviceVoicesData.raceNames
local tauntsData = require("tew.AURA.PC.tauntsData")
local common = require("tew.AURA.common")
local playedTaunt = 0
local lastTaunt

local werewolfSounds = {
    "were moan",
    "were roar",
    "were scream",
    "weregrowl",
    "werehowl",
}

local debugLog = common.debugLog

local function getRandomTaunt(taunts)
    if not taunts or #taunts == 0 then
        return nil
    end

    -- Only one possible taunt.
    if #taunts == 1 then
        lastTaunt = taunts[1]
        return taunts[1]
    end

    local taunt

    repeat
        taunt = taunts[math.random(1, #taunts)]
    until taunt ~= lastTaunt

    lastTaunt = taunt

    return taunt
end

local function getNonRepeatingTaunt(preferredTaunt, fallbackTaunts)
    if preferredTaunt ~= lastTaunt then
        lastTaunt = preferredTaunt
        return preferredTaunt
    end

    return getRandomTaunt(fallbackTaunts)
end

--[[local function getArrays()

    local VDir = "Data Files\\Sound\\Vo"

    print("this.NPCtaunts = {\n")
    for race in lfs.dir(VDir) do
        if race ~= "." and race ~= ".." then
            for _, v in pairs(raceNames) do
                if race == v then
                    print("[\""..v.."\"]".." = {")
                    for gender in lfs.dir(VDir.."\\"..v) do
                        if gender ~= "." and gender ~= ".." then
                            print("[\""..gender.."\"]".." = {")
                            for file in lfs.dir(VDir.."\\"..v.."\\"..gender) do
                                if string.startswith(file, "Atk") then
                                    print("\""..file.."\",")
                                end
                            end
                            print("\n},")
                        end
                    end
                    print("\n},")
                end
            end
        end
    end
    print("\n}")

    print("this.Crtaunts = {\n")
    for race in lfs.dir(VDir) do
        if race ~= "." and race ~= ".." then
            for _, v in pairs(raceNames) do
                if race == v then
                    print("[\""..v.."\"]".." = {")
                    for gender in lfs.dir(VDir.."\\"..v) do
                        if gender ~= "." and gender ~= ".." then
                            print("[\""..gender.."\"]".." = {")
                            for file in lfs.dir(VDir.."\\"..v.."\\"..gender) do
                                if string.startswith(file, "CrAtk")
                                or string.startswith(file, "bAtk") then
                                    print("\""..file.."\",")
                                end
                            end
                            print("\n},")
                        end
                    end
                    print("\n},")
                end
            end
        end
    end
    print("\n}")

end]]

local function playerCheck()
    playedTaunt = 0

    playerSex = tes3.player.object.female and "f" or "m"
    playerRace = raceNames[tes3.player.object.race.id]

    debugLog("Determined player race: " .. tostring(playerRace))
    debugLog("Determined player sex: " .. tostring(playerSex))
end

local function onStatReview(e)
    local element = e.element:findChild("MenuStatReview_Okbutton")

    element:registerAfter("mouseDown", function()
        playerCheck()
    end)
end

---@param e attackEventData
local function combatCheck(e)
    if e.reference ~= tes3.player then
        return
    end

    if tes3.mobilePlayer and tes3.mobilePlayer.isDead then
        return
    end

    if playedTaunt == 1 then
        debugLog("Flag on. Returning.")
        return
    end

    if not e.targetMobile then
        return
    end

    local playerMobile = tes3.mobilePlayer
    local targetRef = e.targetReference

    if tes3.mobilePlayer.werewolf then
        local taunt = getRandomTaunt(werewolfSounds)

        tes3.playSound {
            sound = taunt,
            volume = 0.9 * (config.volumes.misc.tVol / 100),
            reference = playerMobile.reference,
        }

        playedTaunt = 1

        debugLog("Played werewolf battle taunt: " .. taunt)

        timer.start {
            type = timer.real,
            duration = 7,
            callback = function()
                playedTaunt = 0
            end,
        }

        return
    end

    if playerRace == nil or playerSex == nil then
        return
    end

    if config.tauntChance < math.random() then
        debugLog("Dice roll failed. Returning.")
        return
    end

    local taunt

    if targetRef.object.objectType == tes3.objectType.npc then
        local foeRace = targetRef.object.race.id

        debugLog("Foe race: " .. tostring(foeRace))

        local raceTaunts = tauntsData.raceTaunts

        if raceTaunts[playerRace]
            and raceTaunts[playerRace][playerSex]
            and raceTaunts[playerRace][playerSex][foeRace] then
            taunt = getNonRepeatingTaunt(
                raceTaunts[playerRace][playerSex][foeRace],
                tauntsData.NPCtaunts[playerRace][playerSex]
            )

            debugLog("Race-based taunt: " .. taunt)
        end

        if taunt == nil then
            local taunts = tauntsData.NPCtaunts

            taunt = getRandomTaunt(taunts[playerRace][playerSex])

            debugLog("NPC taunt: " .. taunt)
        end
    else
        local taunts = tauntsData.Crtaunts

        taunt = getRandomTaunt(taunts[playerRace][playerSex])

        debugLog("Creature taunt: " .. taunt)
    end

    if not taunt then
        debugLog("No taunt found. Returning.")
        return
    end

    tes3.say {
        volume = 0.9 * (config.volumes.misc.tVol / 100),
        soundPath = "Vo\\" .. playerRace .. "\\" .. playerSex .. "\\" .. taunt,
        reference = playerMobile.reference,
    }

    playedTaunt = 1

    debugLog("Played battle taunt: " .. taunt)

    timer.start {
        type = timer.real,
        duration = 6,
        callback = function()
            playedTaunt = 0
        end,
    }
end

event.register("loaded", playerCheck)
event.register("attack", combatCheck)
event.register("uiActivated", onStatReview, { filter = "MenuStatReview" })

--getArrays()
