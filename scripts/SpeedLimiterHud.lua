SpeedLimiterHud = {}
SpeedLimiterHud.modDirectory = g_currentModDirectory
SpeedLimiterHud.modName = g_currentModName

SpeedLimiterHud.BACKGROUND_SLICE = "gui.shortcutBox2"
SpeedLimiterHud.MAX_BORDER_PX = 14
SpeedLimiterHud.BACKGROUND_ALPHA_FACTOR = 0.5
SpeedLimiterHud.DEFAULT_X = 0.93
SpeedLimiterHud.DEFAULT_Y = 0.30
SpeedLimiterHud.PADDING_PX = 8
SpeedLimiterHud.GAP_PX = 4
SpeedLimiterHud.MIN_WIDTH_PX = 68
SpeedLimiterHud.ICON_SIZE_PX = 22
SpeedLimiterHud.ICON_ASPECT = 96 / 71
SpeedLimiterHud.LIMIT_TEXT_PX = 16
SpeedLimiterHud.HINT_TEXT_PX = 13
SpeedLimiterHud.FALLBACK_BACKGROUND = { 0.004, 0.005, 0.004, 0.65 }
SpeedLimiterHud.FALLBACK_ACTIVE = { 0.3, 0.8, 0.1, 1 }
SpeedLimiterHud.COLOR_INACTIVE = { 1, 1, 1, 1 }

SpeedLimiterHud.posX = SpeedLimiterHud.DEFAULT_X
SpeedLimiterHud.posY = SpeedLimiterHud.DEFAULT_Y
SpeedLimiterHud.isDragging = false
SpeedLimiterHud.dragOffsetX = 0
SpeedLimiterHud.dragOffsetY = 0
SpeedLimiterHud.rect = { x = 0, y = 0, w = 0, h = 0 }
SpeedLimiterHud.settingsLoaded = false
SpeedLimiterHud.pieces = nil

function SpeedLimiterHud.pxX(px)
    local uiScale = g_gameSettings ~= nil and g_gameSettings:getValue(GameSettings.SETTING.UI_SCALE) or 1
    return px * uiScale * (g_aspectScaleX or 1) / (g_referenceScreenWidth or 1920)
end

function SpeedLimiterHud.pxY(px)
    local uiScale = g_gameSettings ~= nil and g_gameSettings:getValue(GameSettings.SETTING.UI_SCALE) or 1
    return px * uiScale * (g_aspectScaleY or 1) / (g_referenceScreenHeight or 1080)
end

function SpeedLimiterHud.getSettingsPaths()
    local base = getUserProfileAppPath() .. "modSettings/"
    local dir = base .. SpeedLimiterHud.modName .. "/"
    return base, dir, dir .. "hud.xml"
end

function SpeedLimiterHud.loadSettings()
    SpeedLimiterHud.settingsLoaded = true
    local _, _, path = SpeedLimiterHud.getSettingsPaths()
    if fileExists(path) then
        local xml = loadXMLFile("SpeedLimiterHud", path)
        if xml ~= nil and xml ~= 0 then
            SpeedLimiterHud.posX = getXMLFloat(xml, "speedLimiterHud#x") or SpeedLimiterHud.DEFAULT_X
            SpeedLimiterHud.posY = getXMLFloat(xml, "speedLimiterHud#y") or SpeedLimiterHud.DEFAULT_Y
            delete(xml)
        end
    end
end

function SpeedLimiterHud.saveSettings()
    local base, dir, path = SpeedLimiterHud.getSettingsPaths()
    createFolder(base)
    createFolder(dir)
    local xml = createXMLFile("SpeedLimiterHud", path, "speedLimiterHud")
    if xml ~= nil and xml ~= 0 then
        setXMLFloat(xml, "speedLimiterHud#x", SpeedLimiterHud.posX)
        setXMLFloat(xml, "speedLimiterHud#y", SpeedLimiterHud.posY)
        saveXMLFile(xml)
        delete(xml)
    end
end

function SpeedLimiterHud.parseSlicePixelSize(slice)
    local numbers = {}
    for n in string.gmatch(slice.sizeStr or "", "[%d%.]+") do
        table.insert(numbers, tonumber(n))
    end
    return numbers[1], numbers[2]
end

function SpeedLimiterHud.createBackground(bgColor)
    local slice = g_overlayManager:getSliceInfoById(SpeedLimiterHud.BACKGROUND_SLICE)
    local pxW, pxH
    if slice ~= nil and slice.uvs ~= nil and #slice.uvs >= 8 then
        pxW, pxH = SpeedLimiterHud.parseSlicePixelSize(slice)
    end

    if pxW == nil or pxH == nil or pxW < 4 or pxH < 4 then
        local single = g_overlayManager:createOverlay(SpeedLimiterHud.BACKGROUND_SLICE, 0, 0, 0, 0)
        if single == nil and g_plainColorSliceId ~= nil then
            single = g_overlayManager:createOverlay(g_plainColorSliceId, 0, 0, 0, 0)
        end
        if single ~= nil then
            single:setColor(bgColor[1], bgColor[2], bgColor[3], bgColor[4])
        end
        SpeedLimiterHud.single = single
        return
    end

    local border = math.min(SpeedLimiterHud.MAX_BORDER_PX, math.floor(math.min(pxW, pxH) / 2) - 1)
    border = math.max(border, 1)
    SpeedLimiterHud.borderPx = border

    local uMin, uMax, vMin, vMax = math.huge, -math.huge, math.huge, -math.huge
    for i = 1, 8, 2 do
        uMin = math.min(uMin, slice.uvs[i])
        uMax = math.max(uMax, slice.uvs[i])
        vMin = math.min(vMin, slice.uvs[i + 1])
        vMax = math.max(vMax, slice.uvs[i + 1])
    end

    local fx = border / pxW
    local fy = border / pxH
    local cols = { { 0, fx }, { fx, 1 - fx }, { 1 - fx, 1 } }
    local rows = { { 0, fy }, { fy, 1 - fy }, { 1 - fy, 1 } }

    local pieces = {}
    for r = 1, 3 do
        pieces[r] = {}
        for c = 1, 3 do
            local u0 = uMin + cols[c][1] * (uMax - uMin)
            local u1 = uMin + cols[c][2] * (uMax - uMin)
            local v0 = vMin + rows[r][1] * (vMax - vMin)
            local v1 = vMin + rows[r][2] * (vMax - vMin)
            local overlay = g_overlayManager:createOverlay(SpeedLimiterHud.BACKGROUND_SLICE, 0, 0, 0, 0)
            overlay:setUVs({ u0, v0, u0, v1, u1, v0, u1, v1 })
            overlay:setColor(bgColor[1], bgColor[2], bgColor[3], bgColor[4])
            pieces[r][c] = overlay
        end
    end
    SpeedLimiterHud.pieces = pieces
end

function SpeedLimiterHud.createOverlays()
    local hasHudColors = HUD ~= nil and HUD.COLOR ~= nil and HUD.COLOR.BACKGROUND ~= nil
    local baseColor = hasHudColors and HUD.COLOR.BACKGROUND or SpeedLimiterHud.FALLBACK_BACKGROUND
    local bgColor = { baseColor[1], baseColor[2], baseColor[3], baseColor[4] * SpeedLimiterHud.BACKGROUND_ALPHA_FACTOR }
    local activeColor = hasHudColors and HUD.COLOR.ACTIVE or SpeedLimiterHud.FALLBACK_ACTIVE
    activeColor = activeColor or SpeedLimiterHud.FALLBACK_ACTIVE
    SpeedLimiterHud.colorActive = { activeColor[1], activeColor[2], activeColor[3], activeColor[4] }

    SpeedLimiterHud.createBackground(bgColor)

    if g_plainColorSliceId ~= nil then
        SpeedLimiterHud.outline = g_overlayManager:createOverlay(g_plainColorSliceId, 0, 0, 0, 0)
    end

    local iconPath = SpeedLimiterHud.modDirectory .. "scripts/Fahrpedal_Symbol.dds"
    SpeedLimiterHud.icon = Overlay.new(iconPath, 0, 0, 0, 0)

    SpeedLimiterHud.overlaysCreated = true
end

function SpeedLimiterHud.requestCursorToggle()
    if SpeedLimiterHud.cursorRequest == nil and g_inputBinding ~= nil then
        SpeedLimiterHud.cursorRequest = g_inputBinding:getShowMouseCursor()
    end
end

function SpeedLimiterHud:update(dt)
    local before = SpeedLimiterHud.cursorRequest
    if before ~= nil then
        SpeedLimiterHud.cursorRequest = nil
        if g_inputBinding:getShowMouseCursor() == before and not (g_gui ~= nil and g_gui:getIsGuiVisible()) then
            g_inputBinding:setShowMouseCursor(not before)
        end
    end
end

function SpeedLimiterHud.getIsEditing()
    if g_inputBinding == nil or not g_inputBinding:getShowMouseCursor() then
        return false
    end
    if g_gui ~= nil and g_gui:getIsGuiVisible() then
        return false
    end
    local vehicle = g_localPlayer ~= nil and g_localPlayer:getCurrentVehicle() or nil
    return vehicle ~= nil and vehicle.spec_speedLimiterMod ~= nil
end

function SpeedLimiterHud:mouseEvent(posX, posY, isDown, isUp, button)
    if not SpeedLimiterHud.getIsEditing() then
        if SpeedLimiterHud.isDragging then
            SpeedLimiterHud.isDragging = false
            SpeedLimiterHud.saveSettings()
        end
        return
    end

    local r = SpeedLimiterHud.rect

    if isDown and button == Input.MOUSE_BUTTON_LEFT then
        if posX >= r.x and posX <= r.x + r.w and posY >= r.y and posY <= r.y + r.h then
            SpeedLimiterHud.isDragging = true
            SpeedLimiterHud.dragOffsetX = posX - SpeedLimiterHud.posX
            SpeedLimiterHud.dragOffsetY = posY - SpeedLimiterHud.posY
        end
    end

    if SpeedLimiterHud.isDragging then
        SpeedLimiterHud.posX = math.clamp(posX - SpeedLimiterHud.dragOffsetX, 0, math.max(0, 1 - r.w))
        SpeedLimiterHud.posY = math.clamp(posY - SpeedLimiterHud.dragOffsetY, 0, math.max(0, 1 - r.h))
    end

    if isUp and button == Input.MOUSE_BUTTON_LEFT and SpeedLimiterHud.isDragging then
        SpeedLimiterHud.isDragging = false
        SpeedLimiterHud.saveSettings()
    end
end

function SpeedLimiterHud.renderBox(overlay, x, y, w, h)
    overlay:setPosition(x, y)
    overlay:setDimension(w, h)
    overlay:render()
end

function SpeedLimiterHud.drawBackground(x, y, w, h)
    local pieces = SpeedLimiterHud.pieces
    if pieces == nil then
        if SpeedLimiterHud.single ~= nil then
            SpeedLimiterHud.renderBox(SpeedLimiterHud.single, x, y, w, h)
        end
        return
    end

    local bx = SpeedLimiterHud.pxX(SpeedLimiterHud.borderPx)
    local by = SpeedLimiterHud.pxY(SpeedLimiterHud.borderPx)
    local xs = { x, x + bx, x + w - bx }
    local ws = { bx, w - 2 * bx, bx }
    local ys = { y, y + by, y + h - by }
    local hs = { by, h - 2 * by, by }

    for r = 1, 3 do
        for c = 1, 3 do
            SpeedLimiterHud.renderBox(pieces[r][c], xs[c], ys[r], ws[c], hs[r])
        end
    end
end

function SpeedLimiterHud.drawOutline(x, y, w, h)
    local overlay = SpeedLimiterHud.outline
    if overlay == nil then
        return
    end
    local lw = 2 / g_screenWidth
    local lh = 2 / g_screenHeight
    local c = SpeedLimiterHud.colorActive
    overlay:setColor(c[1], c[2], c[3], c[4])
    SpeedLimiterHud.renderBox(overlay, x, y, w, lh)
    SpeedLimiterHud.renderBox(overlay, x, y + h - lh, w, lh)
    SpeedLimiterHud.renderBox(overlay, x, y, lw, h)
    SpeedLimiterHud.renderBox(overlay, x + w - lw, y, lw, h)
end

function SpeedLimiterHud.getIsHudVisible(speedMeter)
    local hud = g_currentMission ~= nil and g_currentMission.hud or nil
    if hud == nil then
        return false
    end
    if hud.getIsVisible ~= nil and not hud:getIsVisible() then
        return false
    end
    if hud.isVisible == false then
        return false
    end
    if speedMeter ~= nil and speedMeter.getVisible ~= nil and not speedMeter:getVisible() then
        return false
    end
    return true
end

function SpeedLimiterHud.draw(speedMeter)
    if g_localPlayer == nil or not SpeedLimiterHud.getIsHudVisible(speedMeter) then
        return
    end

    local vehicle = g_localPlayer:getCurrentVehicle()
    if vehicle == nil or vehicle.spec_speedLimiterMod == nil then
        return
    end

    if not SpeedLimiterHud.overlaysCreated then
        SpeedLimiterHud.createOverlays()
    end
    if not SpeedLimiterHud.settingsLoaded then
        SpeedLimiterHud.loadSettings()
    end

    local spec = vehicle.spec_speedLimiterMod
    local isActive = spec.active
    local color = isActive and SpeedLimiterHud.colorActive or SpeedLimiterHud.COLOR_INACTIVE

    local padX = SpeedLimiterHud.pxX(SpeedLimiterHud.PADDING_PX)
    local padY = SpeedLimiterHud.pxY(SpeedLimiterHud.PADDING_PX)
    local gap = SpeedLimiterHud.pxY(SpeedLimiterHud.GAP_PX)
    local unit = g_i18n:getText("speedlimiter_unit")
    local sampleText = "888 " .. unit
    local limitSize = SpeedLimiterHud.pxY(SpeedLimiterHud.LIMIT_TEXT_PX)
    local iconH = SpeedLimiterHud.pxY(SpeedLimiterHud.ICON_SIZE_PX)
    local iconW = SpeedLimiterHud.pxX(SpeedLimiterHud.ICON_SIZE_PX * SpeedLimiterHud.ICON_ASPECT)

    setTextBold(true)
    local limitH = getTextHeight(limitSize, sampleText)
    local limitW = getTextWidth(limitSize, sampleText)
    setTextBold(false)

    local w = math.max(iconW, limitW, SpeedLimiterHud.pxX(SpeedLimiterHud.MIN_WIDTH_PX) - 2 * padX) + 2 * padX
    local limitY = padY
    local iconY = limitY + limitH + gap
    local h = iconY + iconH + padY

    local x = math.clamp(SpeedLimiterHud.posX, 0, math.max(0, 1 - w))
    local y = math.clamp(SpeedLimiterHud.posY, 0, math.max(0, 1 - h))
    SpeedLimiterHud.rect.x = x
    SpeedLimiterHud.rect.y = y
    SpeedLimiterHud.rect.w = w
    SpeedLimiterHud.rect.h = h

    SpeedLimiterHud.drawBackground(x, y, w, h)

    SpeedLimiterHud.icon:setColor(color[1], color[2], color[3], color[4])
    SpeedLimiterHud.renderBox(SpeedLimiterHud.icon, x + (w - iconW) / 2, y + iconY, iconW, iconH)

    local centerX = x + w / 2
    setTextAlignment(RenderText.ALIGN_CENTER)

    setTextBold(true)
    setTextColor(color[1], color[2], color[3], color[4])
    local shownLimit = vehicle:getSpeedLimiterValue()
    local limitText = string.format("%d %s", shownLimit, unit)
    renderText(centerX, y + limitY, limitSize, limitText)

    if SpeedLimiterHud.getIsEditing() then
        SpeedLimiterHud.drawOutline(x, y, w, h)
        setTextBold(true)
        setTextColor(1, 1, 1, 1)
        local hintSize = SpeedLimiterHud.pxY(SpeedLimiterHud.HINT_TEXT_PX)
        local hintY = y + h + SpeedLimiterHud.pxY(4)
        if hintY > 0.97 then
            hintY = y - hintSize - SpeedLimiterHud.pxY(4)
        end
        renderText(centerX, hintY, hintSize, g_i18n:getText("speedlimiter_editHint"))
    end

    setTextColor(1, 1, 1, 1)
    setTextAlignment(RenderText.ALIGN_LEFT)
    setTextBold(false)
end

function SpeedLimiterHud.delete()
    if SpeedLimiterHud.pieces ~= nil then
        for r = 1, 3 do
            for c = 1, 3 do
                SpeedLimiterHud.pieces[r][c]:delete()
            end
        end
        SpeedLimiterHud.pieces = nil
    end
    for _, key in ipairs({ "single", "outline", "icon" }) do
        if SpeedLimiterHud[key] ~= nil then
            SpeedLimiterHud[key]:delete()
            SpeedLimiterHud[key] = nil
        end
    end
    SpeedLimiterHud.overlaysCreated = false
end

addModEventListener(SpeedLimiterHud)
SpeedMeterDisplay.draw = Utils.appendedFunction(SpeedMeterDisplay.draw, SpeedLimiterHud.draw)
FSBaseMission.delete = Utils.prependedFunction(FSBaseMission.delete, SpeedLimiterHud.delete)
