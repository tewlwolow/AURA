local cellData = require("tew.AURA.cellData")
local common = require("tew.AURA.common")
local config = require("tew.AURA.config")
local defaults = require("tew.AURA.defaults")
local messages = require(config.language).messages
local modules = require("tew.AURA.modules")
local moduleData = modules.data
local soundData = require("tew.AURA.soundData")
local fader = require("tew.AURA.fader")
local volumeController = require("tew.AURA.volumeController")
local adjustVolume = volumeController.adjustVolume
local getVolume = volumeController.getVolume
local setVolume = volumeController.setVolume
local debugLog = common.debugLog

local this = {}

function this.init()
    this.entries = 0
    this.adjustedModules = {}
    this.id_menu = tes3ui.registerID("AURA:MenuAdjustVolume")
    this.id_header = tes3ui.registerID("AURA:MenuAdjustVolume_header")
    this.id_headerLabel = tes3ui.registerID("AURA:MenuAdjustVolume_headerLabel")
    this.id_scrollPane = tes3ui.registerID("AURA:MenuAdjustVolume_scrollPane")
    this.id_trackList = tes3ui.registerID("AURA:MenuAdjustVolume_trackList")
    this.id_trackBlock = tes3ui.registerID("AURA:MenuAdjustVolume_trackBlock")
    this.id_trackInfo = tes3ui.registerID("AURA:MenuAdjustVolume_trackInfo")
    this.id_sliderLabel = tes3ui.registerID("AURA:MenuAdjustVolume_sliderLabel")
    this.id_buttonBlock = tes3ui.registerID("AURA:MenuAdjustVolume_buttonBlock")
    this.id_buttonLabel = tes3ui.registerID("AURA:MenuAdjustVolume_buttonLabel")
    this.id_buttonUndo = tes3ui.registerID("AURA:MenuAdjustVolume_buttonUndo")
    this.id_buttonRestoreDefaults = tes3ui.registerID("AURA:MenuAdjustVolume_buttonRestoreDefaults")
    volumeController.printConfigVolumes()
end

local function getTextInputFocus()
    return tes3.worldController.menuController.inputController.textInputFocus
end

local function textInputIsActive()
    local inputFocus = getTextInputFocus()

    -- Patch for mods that don't release text input after leaving menu mode (UIExp, etc)
    if not tes3ui.menuMode() and inputFocus then
        tes3ui.acquireTextInput(nil)
        inputFocus = getTextInputFocus()
    end

    if inputFocus and inputFocus.visible and not inputFocus.disabled then
        return true
    end
    return false
end

local sliderPercent = {
    labelFmt = "%d%%  (%s = %d%%)",
    sliderMult = 1,
    sliderMin = 0,
    sliderMax = 100,
    sliderStep = 1,
    sliderJump = 5,
}
local sliderCoefficient = {
    labelFmt = "[%.2f x " .. messages.exteriorVolume .. "]  (%s = %.2fx)",
    sliderMult = 100,
    sliderMin = 0,
    sliderMax = 60,
    sliderStep = 1,
    sliderJump = 5,
}

local function createSlider(parent, sc)
    local current = sc.volumeTableCurrent[sc.key] * sc.sliderType.sliderMult
    local default = sc.volumeTableDefault[sc.key] * sc.sliderType.sliderMult
    local slider = parent:createSlider {
        current = current,
        min = sc.sliderType.sliderMin,
        max = sc.sliderType.sliderMax,
        step = sc.sliderType.sliderStep,
        jump = sc.sliderType.sliderJump,
    }
    slider.widthProportional = 0.99
    slider.borderTop = 5
    slider.borderBottom = 5
    local sliderLabel = parent:createLabel { id = this.id_sliderLabel, text = "" }
    sliderLabel.text = string.format(sc.sliderType.labelFmt, current / sc.sliderType.sliderMult, messages.default,
        default / sc.sliderType.sliderMult)
    slider:register("PartScrollBar_changed", function(e)
        local sliderValue = slider:getPropertyInt("PartScrollBar_current")
        local newValue = sliderValue / sc.sliderType.sliderMult
        sliderLabel.text = string.format(sc.sliderType.labelFmt, newValue, messages.default,
            default / sc.sliderType.sliderMult)
        sc.volumeTableCurrent[sc.key] = newValue
        if sc.moduleName then
            adjustVolume { module = sc.moduleName, config = this.config }
            common.setInsert(this.adjustedModules, sc.moduleName)
        else
            setVolume(sc.track, newValue / 100)
        end
    end)
end

local function createEntry(id)
    local menu = tes3ui.findMenu(this.id_menu)
    local trackList = menu:findChild(this.id_trackList)
    local trackBlock = trackList:createBlock { id = id or this.id_trackBlock }
    trackBlock.widthProportional = 1
    trackBlock.autoHeight = true
    trackBlock.flowDirection = tes3.flowDirection.topToBottom
    trackBlock.borderTop = 5
    trackBlock.borderBottom = 20
    local trackInfo = trackBlock:createLabel { id = this.id_trackInfo, text = "" }
    trackInfo.wrapText = true
    this.entries = this.entries + 1
    return trackBlock
end

local function doExtremes()
    local cw = tes3.worldController.weatherController.currentWeather
    if (this.cell.isOrBehavesAsExterior) and (cw) and (cw.index == 6 or cw.index == 7 or cw.index == 9) then
        local menu = tes3ui.findMenu(this.id_menu)
        local track
        if cw.name == "Ashstorm" then
            track = tes3.getSound("Ashstorm")
        elseif cw.name == "Blight" then
            track = tes3.getSound("Blight")
        elseif cw.name == "Blizzard" then
            track = tes3.getSound("BM Blizzard")
        end
        if not track:isPlaying() then return end

        local entry = createEntry()
        local trackInfo = entry:findChild(this.id_trackInfo)

        if fader.isRunning { module = "shelterWeather" } or cellData.isWeatherVolumeDynamic then
            trackInfo.text = string.format("%s: %s\n%s: %s%%", cw.name, track.id, messages.adjustingAuto,
                math.round(track.volume, 2) * 100)
            menu:updateLayout()
            return
        end

        local sc = {}
        sc.key = cw.name
        sc.track = track
        sc.sliderType = sliderPercent
        sc.volumeTableDefault = defaults.volumes.extremeWeather
        sc.volumeTableCurrent = this.config.volumes.extremeWeather
        trackInfo.text = string.format("%s: %s", cw.name, track.id)
        if cellData.playerUnderwater and config.underwaterRain then
            trackInfo.text = string.format("%s\n%s: %s%%", trackInfo.text, messages.adjustingAuto,
                math.round(track.volume, 2) * 100)
        else
            createSlider(entry, sc)
        end
        menu:updateLayout()
    end
end

local function doRain()
    local track, rainType
    local cw = tes3.worldController.weatherController.currentWeather
    if (this.cell.isOrBehavesAsExterior) and cw and cw.rainLoopSound and cw.rainLoopSound:isPlaying() then
        track = cw.rainLoopSound
        rainType = cellData.rainType[cw.index]
        if not rainType then return end -- Needs variable rain sounds. TODO: maybe add tooltip
    else
        return
    end

    local menu = tes3ui.findMenu(this.id_menu)
    local entry = createEntry()
    local trackInfo = entry:findChild(this.id_trackInfo)

    if fader.isRunning { module = "shelterWeather" } or cellData.isWeatherVolumeDynamic then
        trackInfo.text = string.format("%s (%s): %s\n%s: %s%%", cw.name, rainType, track.id, messages.adjustingAuto,
            math.round(track.volume, 2) * 100)
        menu:updateLayout()
        return
    end

    local sc = {}
    sc.key = rainType
    sc.track = track
    sc.sliderType = sliderPercent
    sc.volumeTableDefault = defaults.volumes.rain[cw.name]
    sc.volumeTableCurrent = this.config.volumes.rain[cw.name]

    trackInfo.text = string.format("%s (%s): %s", cw.name, rainType, track.id)

    if cellData.playerUnderwater and config.underwaterRain then
        trackInfo.text = string.format("%s\n%s: %s%%", trackInfo.text, messages.adjustingAuto,
            math.round(track.volume, 2) * 100)
    else
        createSlider(entry, sc)
    end
    menu:updateLayout()
end

local function doModules()
    local menu = tes3ui.findMenu(this.id_menu)
    local mp = tes3.mobilePlayer
    if not mp then return end
    for moduleName in pairs(moduleData) do
        -- This one has a special regime, doesn't play on any reference
        if moduleName == "shelterWeather" then goto nextModule end

        local playing = modules.getCurrentlyPlaying(moduleName)
            or modules.getWindoorPlaying(moduleName)
            or modules.getExteriorDoorPlaying(moduleName)

        if not playing then goto nextModule end
        local track, ref = table.unpack(playing)

        local configKey
        local sc = {}
        local entry = createEntry()
        local trackInfo = entry:findChild(this.id_trackInfo)

        -- No point adjusting tracks attached to refs other than player's while underwater
        if cellData.playerUnderwater and (ref ~= mp.reference) then
            entry:destroy()
            goto nextModule
        end
        if fader.isRunning { module = moduleName } then
            trackInfo.text = string.format("%s: %s", moduleName, messages.fadeInProgress)
            goto nextModule
        end

        sc.volumeTableDefault = defaults.volumes.modules[moduleName]
        sc.volumeTableCurrent = this.config.volumes.modules[moduleName]

        if not this.cell.isOrBehavesAsExterior
            and (moduleName ~= "interiorToExterior")
            and (moduleName ~= "interiorWeather")
            and (moduleName ~= "interior") then
            configKey = common.getInteriorType(this.cell):gsub("ten", "sma")
            sc.sliderType = sliderCoefficient
        else
            configKey = "volume"
            sc.sliderType = sliderPercent
        end

        if moduleName == "interiorToExterior" then
            local info = {}
            for _, door in pairs(cellData.exteriorDoors) do
                if door ~= nil then
                    local doorTrack = common.getTrackPlaying(modules.getExteriorDoorTrack(door), door)
                    if doorTrack then
                        table.insert(info, string.format("%s: %s", doorTrack.id, door.destination.cell.name))
                    end
                end
            end
            trackInfo.text = string.format("%s: %s: %s [?]", moduleName, messages.currentlyPlayingDoors, tostring(#info))
            trackInfo:register(tes3.uiEvent.help, function(e)
                local tooltip = tes3ui.createTooltipMenu()
                local tip = table.concat(info, "\n")
                tooltip:createLabel { text = tip }
            end)
        end

        if cellData.playerUnderwater then
            configKey = "und"
            sc.sliderType = sliderCoefficient
        end

        sc.key = configKey
        sc.moduleName = moduleName

        if not trackInfo.text or trackInfo.text == "" then
            trackInfo.text = string.format("%s: %s", moduleName, track.id)
        end

        createSlider(entry, sc)

        :: nextModule ::
    end
    menu:updateLayout()
end

local function updateHeader()
    local menu = tes3ui.findMenu(this.id_menu)
    local trackList = menu:findChild(this.id_trackList)
    local hLabel = menu:findChild(this.id_headerLabel)
    local cellType
    if (trackList) and (this.entries > 0) and cellData.playerUnderwater then
        hLabel.text = messages.adjustForUnderwater
    elseif (trackList) and (this.entries > 0) and not this.cell.isOrBehavesAsExterior then
        cellType = common.getInteriorType(this.cell):gsub("^sma$", messages.small):gsub("^ten$", messages.small):gsub(
            "^big$", messages.big)
        hLabel.text = string.format("%s (%s)", messages.adjustForInterior, cellType)
    elseif (trackList) and (this.entries > 0) and this.cell.isOrBehavesAsExterior then
        hLabel.text = messages.adjustForExterior
    else
        hLabel.text = messages.noTracksPlaying
    end
end

local function createHeader()
    local menu = tes3ui.findMenu(this.id_menu)
    local headerBlock = menu:createBlock { id = this.id_header }
    headerBlock.widthProportional = 1
    headerBlock.autoHeight = true
    headerBlock.flowDirection = tes3.flowDirection.topToBottom
    headerBlock.borderTop = 20
    headerBlock.borderBottom = 25
    local hLabel = headerBlock:createLabel { id = this.id_headerLabel, text = "" }
    hLabel.widthProportional = 1
    hLabel.wrapText = true
    hLabel.justifyText = "center"
end

local function createFooter()
    local menu = tes3ui.findMenu(this.id_menu)
    local buttonBlock = menu:createBlock { id = this.id_buttonBlock }
    buttonBlock.absolutePosAlignX = 0.99
    buttonBlock.absolutePosAlignY = 0.99
    buttonBlock.autoWidth = true
    buttonBlock.autoHeight = true

    local buttonRestoreDefaults = buttonBlock:createButton { id = this.id_buttonRestoreDefaults, text = messages.restoreDefaults }
    local buttonUndo = buttonBlock:createButton { id = this.id_buttonUndo, text = messages.undo }

    -- Don't want to restore default volumes while we're dynamically adjusting weather track volume
    if fader.isRunning { module = "shelterWeather" } then
        local function notify()
            tes3.messageBox { message = messages.fadeInProgress }
        end
        debugLog("Fade in progress for shelterWeather. Disabling footer buttons.")
        buttonRestoreDefaults:register(tes3.uiEvent.mouseClick, notify)
        buttonUndo:register(tes3.uiEvent.mouseClick, notify)
        return
    end


    buttonRestoreDefaults:register(tes3.uiEvent.mouseClick, this.onRestoreDefaults)
    buttonUndo:register(tes3.uiEvent.mouseClick, this.onUndo)
end

local function createBody()
    if not this.cell then return end
    local menu = tes3ui.findMenu(this.id_menu)
    local trackList = menu:findChild(this.id_trackList)
    if not trackList then
        this.entries = 0
        trackList = menu:createVerticalScrollPane { id = this.id_trackList }
        trackList.widthProportional = 0.99
        trackList.heightProportional = 0.9
    end
    doExtremes()
    doRain()
    doModules()
    updateHeader()
end

local function createWindow()
    local menu = tes3ui.createMenu { id = this.id_menu, dragFrame = true }

    menu.text = "AURA"
    menu.width = 430
    menu.height = 600

    if this.positionX and this.positionY then
        menu.positionX = this.positionX
        menu.positionY = this.positionY
    else
        menu.positionX = menu.maxWidth / 2 - menu.width
        menu.positionY = menu.maxHeight / 2
        menu:loadMenuPosition()
    end

    createHeader()
    createBody()

    if this.entries > 0 then createFooter() end

    updateHeader()

    menu.width = 430
    menu.height = 600
    menu:updateLayout()
    menu.visible = true
end

local function redraw()
    local menu = tes3ui.findMenu(this.id_menu)
    local trackList = menu:findChild(this.id_trackList)
    trackList:destroy()
    mwse.saveConfig("AURA", this.config)
    this.config = mwse.loadConfig("AURA", defaults)
    this.configPrevious = table.deepcopy(this.config)
    cellData.isWeatherVolumeDynamic = false
    createBody()
    for _, moduleName in ipairs(this.adjustedModules) do
        adjustVolume { module = moduleName, config = this.config }
    end
    table.clear(this.adjustedModules)
    volumeController.setConfigVolumes()
    menu:updateLayout()
end

function this.toggle(e)
    if textInputIsActive() then
        debugLog("Text input active, returning.")
        return
    end

    if e.isShiftDown then
        local menu = tes3ui.findMenu(this.id_menu)

        if (not menu) then
            this.cell = cellData.cell
            this.config = mwse.loadConfig("AURA", defaults)
            this.configPrevious = table.deepcopy(this.config)
            createWindow()
            if (not tes3ui.menuMode()) then
                tes3ui.enterMenuMode(this.id_menu)
            end
            debugLog("Toggle on.")
        else
            this.positionX = menu.positionX
            this.positionY = menu.positionY
            menu:destroy()
            if (tes3ui.menuMode()) then
                tes3ui.leaveMenuMode()
            end
            if this.config then mwse.saveConfig("AURA", this.config) end
            this.configPrevious = nil
            this.entries = 0
            table.clear(this.adjustedModules)
            debugLog("Toggle off.")
        end
    end
end

function this.onUndo(e)
    debugLog("Reverting changes.")
    this.config.volumes.modules = this.configPrevious.volumes.modules
    this.config.volumes.rain = this.configPrevious.volumes.rain
    this.config.volumes.extremeWeather = this.configPrevious.volumes.extremeWeather
    redraw()
end

function this.onRestoreDefaults(e)
    debugLog("Restoring defaults.")
    this.config.volumes.modules = defaults.volumes.modules
    this.config.volumes.rain = defaults.volumes.rain
    this.config.volumes.extremeWeather = defaults.volumes.extremeWeather
    redraw()
    tes3.messageBox { message = messages.defaultsRestored }
end

this.init()
event.register(tes3.event.keyDown, this.toggle, { filter = config.volumeSave.keyCode })
