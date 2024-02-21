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
    this.id_slider = tes3ui.registerID("AURA:MenuAdjustVolume_slider")
    this.id_sliderLabel = tes3ui.registerID("AURA:MenuAdjustVolume_sliderLabel")
    this.id_buttonBlock = tes3ui.registerID("AURA:MenuAdjustVolume_buttonBlock")
    this.id_buttonLabel = tes3ui.registerID("AURA:MenuAdjustVolume_buttonLabel")
    this.id_buttonUndo = tes3ui.registerID("AURA:MenuAdjustVolume_buttonUndo")
    this.id_buttonRestoreDefaults = tes3ui.registerID("AURA:MenuAdjustVolume_buttonRestoreDefaults")
    volumeController.printConfigVolumes()
end

local tooltipConfig = {
    ["moduleAmbientOutdoor"] = {
        moduleName = "outdoor",
        mcmTab = messages.mainSettings,
        description = messages.OADesc,
    },
    ["playInteriorAmbient"] = {
        moduleName = "outdoor",
        mcmTab = messages.OA,
        description = messages.playInteriorAmbient,
    },
    ["moduleInteriorWeather"] = {
        moduleName = "interiorWeather",
        mcmTab = messages.mainSettings,
        description = messages.IWDesc,
    },
    ["moduleAmbientInterior"] = {
        moduleName = "interior",
        mcmTab = messages.mainSettings,
        description = messages.IADesc,
    },
    ["moduleInteriorToExterior"] = {
        moduleName = "interiorToExterior",
        mcmTab = messages.IA,
        description = messages.enableInteriorToExterior,
    },
    ["moduleAmbientPopulated"] = {
        moduleName = "populated",
        mcmTab = messages.mainSettings,
        description = messages.PADesc,
    },
    ["windSounds"] = {
        moduleName = "wind",
        mcmTab = messages.misc,
        description = messages.windSounds,
    },
    ["playInteriorWind"] = {
        moduleName = "wind",
        mcmTab = messages.OA,
        description = messages.playInteriorWind,
    },
    ["altitudeWind"] = {
        moduleName = "wind",
        mcmTab = messages.misc,
        description = messages.altitudeWind,
    },
    ["playRainOnStatics"] = {
        moduleName = "rainOnStatics",
        mcmTab = messages.SS,
        description = messages.rainOnStaticsSounds,
    },
    ["playRainInsideShelter"] = {
        moduleName = "shelterRain",
        mcmTab = messages.SS,
        description = messages.shelterRain,
    },
    ["playWindInsideShelter"] = {
        moduleName = "shelterWind",
        mcmTab = messages.SS,
        description = messages.shelterWind,
    },
    ["shelterWeather"] = {
        moduleName = "shelterWeather",
        mcmTab = messages.SS,
        description = messages.shelterWeather,
    },
    ["playRopeBridge"] = {
        moduleName = "ropeBridge",
        mcmTab = messages.SS,
        description = messages.ropeBridge,
    },
    ["playPhotodragons"] = {
        moduleName = "photodragons",
        mcmTab = messages.SS,
        description = messages.photodragons,
    },
    ["playBannerFlap"] = {
        moduleName = "bannerFlap",
        mcmTab = messages.SS,
        description = messages.bannerFlap,
    },
    ["underwaterRain"] = {
        moduleName = "underwater",
        mcmTab = messages.misc,
        description = messages.underwaterRain,
    },
}

local function getLastVolumePercent(moduleName)
    local lastVolume = moduleData[moduleName].lastVolume
    return lastVolume and (math.round(lastVolume, 2) * 100)
end

local function addTooltip(elem, data)
    local moduleName = tooltipConfig[data.configOption].moduleName
    local mcmTab = data.mcmTab or tooltipConfig[data.configOption].mcmTab
    local description = data.description or tooltipConfig[data.configOption].description
    local extraInfo = data.extraInfo
    local tip = ("%s: %s\n%s: %s\n%s: %s\n\n%s: %s"):format(
        messages.module, moduleName,
        messages.configOption, data.configOption,
        messages.mcmTab, mcmTab,
        messages.description, description)
    if extraInfo then
        tip = tip .. ("\n\n%s"):format(extraInfo)
    end
    elem:register(tes3.uiEvent.help, function(e)
        local tooltip = tes3ui.createTooltipMenu()
        local label = tooltip:createLabel { text = tip }
        label.wrapText = true
    end)
end

local function updateExtraInfo(trackInfo, sc)
    local moduleVol = sc.volumeTableCurrent["volume"]
    local lastVolumePercent = getLastVolumePercent(sc.moduleName)
    local extVol = moduleVol
    local intVol = lastVolumePercent or moduleVol
    local ev = messages.exteriorVolume
    local iv = messages.interiorVolume
    local tooltipExtraInfo = string.format("%s: %s%%\n%s: %s%%", ev, extVol, iv, intVol)
    trackInfo:unregister(tes3.uiEvent.help)
    sc.tooltipData.extraInfo = tooltipExtraInfo
    addTooltip(trackInfo, sc.tooltipData)
    trackInfo:getTopLevelMenu():updateLayout()
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
    create = mwse.mcm.createSlider,
    labelFmt = "%%  (" .. messages.default .. ": %s%%)",
    sliderMin = 0,
    sliderMax = 100,
    sliderStep = 1,
    sliderJump = 5,
    decimalPlaces = 0,
}
local sliderCoefficient = {
    create = mwse.mcm.createDecimalSlider,
    labelFmt = " x " .. messages.exteriorVolume:lower() .. "  (" .. messages.default .. ": %s)",
    sliderMin = 0,
    sliderMax = 0.6,
    sliderStep = 0.01,
    sliderJump = 0.05,
    decimalPlaces = 2,
}

local function createSlider(parent, sc)
    local trackInfo = parent:findChild(this.id_trackInfo)

    sc.sliderType.create(
        parent,
        {
            label = messages.current,
            min = sc.sliderType.sliderMin,
            max = sc.sliderType.sliderMax,
            step = sc.sliderType.sliderStep,
            jump = sc.sliderType.sliderJump,
            decimalPlaces = sc.sliderType.decimalPlaces,
            variable = mwse.mcm.createTableVariable {
                id = sc.key,
                table = sc.volumeTableCurrent,
                defaultSetting = sc.volumeTableDefault[sc.key],
            },
            callback = function(self)
                sc.volumeTableCurrent[sc.key] = self.variable.value
                if sc.moduleName then
                    adjustVolume { module = sc.moduleName, config = config }
                    common.setInsert(this.adjustedModules, sc.moduleName)
                elseif sc.track then
                    setVolume(sc.track, self.variable.value / 100)
                end
                if sc.showExtIntVol then
                    updateExtraInfo(trackInfo, sc)
                end
            end,
            convertToLabelValue = function(_, variableValue)
                local postfix = (sc.sliderType.labelFmt):format(sc.volumeTableDefault[sc.key])
                return string.format("%s%s", variableValue, postfix)
            end,
        }
    )
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
            addTooltip(trackInfo, {configOption = "shelterWeather"})
            return
        end

        local sc = {}
        sc.key = cw.name
        sc.track = track
        sc.sliderType = sliderPercent
        sc.volumeTableDefault = defaults.volumes.extremeWeather
        sc.volumeTableCurrent = config.volumes.extremeWeather
        trackInfo.text = string.format("%s: %s", cw.name, track.id)

        if cellData.playerUnderwater and config.underwaterRain then
            trackInfo.text = string.format("%s\n%s: %s%% [?]", trackInfo.text, messages.adjustingAuto,
                math.round(track.volume, 2) * 100)
            addTooltip(trackInfo, {configOption = "underwaterRain"})
            return
        end

        createSlider(entry, sc)
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
        trackInfo.text = string.format("%s (%s): %s\n%s: %s%% [?]", cw.name, rainType, track.id, messages.adjustingAuto,
            math.round(track.volume, 2) * 100)
        addTooltip(trackInfo, {configOption = "shelterWeather"})
        return
    end

    local sc = {}
    sc.key = rainType
    sc.track = track
    sc.sliderType = sliderPercent
    sc.volumeTableDefault = defaults.volumes.rain[cw.name]
    sc.volumeTableCurrent = config.volumes.rain[cw.name]
    trackInfo.text = string.format("%s (%s): %s", cw.name, rainType, track.id)

    if cellData.playerUnderwater and config.underwaterRain then
        trackInfo.text = string.format("%s\n%s: %s%% [?]", trackInfo.text, messages.adjustingAuto,
            math.round(track.volume, 2) * 100)
        addTooltip(trackInfo, {configOption = "underwaterRain"})
        return
    end

    createSlider(entry, sc)
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
        local configOption
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
        sc.volumeTableCurrent = config.volumes.modules[moduleName]

        local lastVolumePercent = getLastVolumePercent(moduleName)
        local isExterior = this.cell.isOrBehavesAsExterior
        local interiorType = common.getInteriorType(this.cell):gsub("ten", "sma")
        local createTooltip, tooltipExtraInfo


        if moduleName == "outdoor" then
            if isExterior then
                configKey = "volume"
                configOption = "moduleAmbientOutdoor"
                createTooltip = true
                sc.sliderType = sliderPercent
            else
                configKey = interiorType
                configOption = "playInteriorAmbient"
                createTooltip = true
                sc.sliderType = sliderCoefficient
                sc.showExtIntVol = true
            end
        elseif moduleName == "interior" then
            configKey = "volume"
            configOption = "moduleAmbientInterior"
            createTooltip = true
            sc.sliderType = sliderPercent
        elseif moduleName == "interiorWeather" then
            configKey = "volume"
            configOption = "moduleInteriorWeather"
            createTooltip = true
            sc.sliderType = sliderPercent
        elseif moduleName == "interiorToExterior" then
            configKey = "volume"
            configOption = "moduleInteriorToExterior"
            createTooltip = true
            sc.sliderType = sliderPercent
            local info = {}
            for _, door in pairs(cellData.exteriorDoors) do
                if door ~= nil then
                    local doorTrack = common.getTrackPlaying(modules.getTempDataEntry("track", door, moduleName), door)
                    if doorTrack then
                        table.insert(info, string.format("%s: %s", doorTrack.id, door.destination.cell.name))
                    end
                end
            end
            trackInfo.text = string.format("%s: %s: %s", moduleName, messages.tracksPlaying, tostring(#info))
            tooltipExtraInfo = ("[%s]: [%s]\n%s"):format(messages.track, messages.doorDestinationCell, table.concat(info, "\n"))
        elseif moduleName == "wind" then
            if isExterior then
                configKey = "volume"
                sc.sliderType = sliderPercent
                if config.altitudeWind then
                    configOption = "altitudeWind"
                    trackInfo.text = string.format("%s: %s\n%s: %s%% [?]", moduleName, track.id, messages.adjustingAuto, lastVolumePercent)
                    addTooltip(trackInfo, {
                        configOption = configOption,
                        extraInfo = ("%s: %s"):format(messages.altitude, math.round(cellData.altitude or 0, 1))
                    })
                    goto nextModule
                end
                configOption = "windSounds"
                createTooltip = true
            else
                configKey = interiorType
                configOption = "playInteriorWind"
                createTooltip = true
                sc.sliderType = sliderCoefficient
                sc.showExtIntVol = true
            end
        elseif moduleName == "populated" then
            configKey = "volume"
            configOption = "moduleAmbientPopulated"
            createTooltip = true
            sc.sliderType = sliderPercent
        elseif moduleName == "rainOnStatics" then
            configKey = "volume"
            configOption = "playRainOnStatics"
            createTooltip = true
            sc.sliderType = sliderPercent
        elseif moduleName == "shelterRain" then
            configKey = "volume"
            configOption = "playRainInsideShelter"
            createTooltip = true
            sc.sliderType = sliderPercent
        elseif moduleName == "shelterWind" then
            configKey = "volume"
            configOption = "playWindInsideShelter"
            createTooltip = true
            sc.sliderType = sliderPercent
        elseif moduleName == "ropeBridge" then
            configKey = "volume"
            configOption = "playRopeBridge"
            createTooltip = true
            sc.sliderType = sliderPercent
        elseif moduleName == "photodragons" then
            configKey = "volume"
            configOption = "playPhotodragons"
            createTooltip = true
            sc.sliderType = sliderPercent
        elseif moduleName == "bannerFlap" then
            configKey = "volume"
            configOption = "playBannerFlap"
            createTooltip = true
            sc.sliderType = sliderPercent
        end


        if cellData.playerUnderwater then
            configKey = "und"
            sc.sliderType = sliderCoefficient
        end

        sc.key = configKey
        sc.moduleName = moduleName
        sc.tooltipData = {configOption = configOption, extraInfo = tooltipExtraInfo}

        if not trackInfo.text or trackInfo.text == "" then
            trackInfo.text = string.format("%s: %s", moduleName, track.id)
        end

        if createTooltip then
            trackInfo.text = trackInfo.text .. " [?]"
            addTooltip(trackInfo, sc.tooltipData)
        end

        if sc.showExtIntVol then
            updateExtraInfo(trackInfo, sc)
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
    menu.width = config.volumeSave.width
    menu.height = config.volumeSave.height

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

    menu.width = config.volumeSave.width
    menu.height = config.volumeSave.height
    menu:updateLayout()
    menu.visible = true
end

local function redraw()
    local menu = tes3ui.findMenu(this.id_menu)
    local trackList = menu:findChild(this.id_trackList)
    trackList:destroy()
    mwse.saveConfig("AURA", config)
    this.configPrevious = table.deepcopy(config)
    cellData.isWeatherVolumeDynamic = false
    for _, moduleName in ipairs(this.adjustedModules) do
        adjustVolume { module = moduleName, config = config }
    end
    table.clear(this.adjustedModules)
    volumeController.setConfigVolumes()
    createBody()
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
            this.configPrevious = table.deepcopy(config)
            createWindow()
            if (not tes3ui.menuMode()) then
                tes3ui.enterMenuMode(this.id_menu)
            end
            debugLog("Toggle on.")
        else
            this.positionX = menu.positionX
            this.positionY = menu.positionY
            config.volumeSave.width = menu.width
            config.volumeSave.height = menu.height
            menu:destroy()
            if (tes3ui.menuMode()) then
                tes3ui.leaveMenuMode()
            end
            mwse.saveConfig("AURA", config)
            this.configPrevious = nil
            this.entries = 0
            table.clear(this.adjustedModules)
            debugLog("Toggle off.")
        end
    end
end

function this.onUndo(e)
    debugLog("Reverting changes.")
    config.volumes.modules = this.configPrevious.volumes.modules
    config.volumes.rain = this.configPrevious.volumes.rain
    config.volumes.extremeWeather = this.configPrevious.volumes.extremeWeather
    redraw()
end

function this.onRestoreDefaults(e)
    debugLog("Restoring defaults.")
    config.volumes.modules = defaults.volumes.modules
    config.volumes.rain = defaults.volumes.rain
    config.volumes.extremeWeather = defaults.volumes.extremeWeather
    redraw()
    tes3.messageBox { message = messages.defaultsRestored }
end

this.init()
event.register(tes3.event.keyDown, this.toggle, { filter = config.volumeSave.keyCode })
