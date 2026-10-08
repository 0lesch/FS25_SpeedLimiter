SpeedLimiter = {}
SpeedLimiter.STEP = 1
SpeedLimiter.MIN = 1
SpeedLimiter.MAX = 200
SpeedLimiter.BAND = 3
SpeedLimiter.REPEAT_DELAY = 350
SpeedLimiter.REPEAT_INTERVAL = 70
SpeedLimiter.HOLD_GAP = 120
SpeedLimiter.ACTIONS = { "SPEEDLIMITER_TOGGLE", "SPEEDLIMITER_UP", "SPEEDLIMITER_DOWN", "SPEEDLIMITER_MOUSE" }
SpeedLimiter.HOLD_ACTIONS = { SPEEDLIMITER_UP = true, SPEEDLIMITER_DOWN = true }
SpeedLimiter.HIDDEN_ACTIONS = { SPEEDLIMITER_MOUSE = true }

function SpeedLimiter.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(Drivable, specializations)
       and SpecializationUtil.hasSpecialization(Motorized, specializations)
end

function SpeedLimiter.registerFunctions(vehicleType)
    SpecializationUtil.registerFunction(vehicleType, "setSpeedLimiterState", SpeedLimiter.setSpeedLimiterState)
    SpecializationUtil.registerFunction(vehicleType, "getSpeedLimiterValue", SpeedLimiter.getSpeedLimiterValue)
end

function SpeedLimiter.registerOverwrittenFunctions(vehicleType)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "updateVehiclePhysics", SpeedLimiter.updateVehiclePhysics)
end

function SpeedLimiter.registerEventListeners(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, "onLoad", SpeedLimiter)
    SpecializationUtil.registerEventListener(vehicleType, "onReadStream", SpeedLimiter)
    SpecializationUtil.registerEventListener(vehicleType, "onWriteStream", SpeedLimiter)
    SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", SpeedLimiter)
end

function SpeedLimiter.getMaxLimit(vehicle)
    local motor = vehicle.getMotor ~= nil and vehicle:getMotor() or nil
    if motor ~= nil and motor.getMaximumForwardSpeed ~= nil then
        local speed = motor:getMaximumForwardSpeed()
        if speed ~= nil and speed > 0 then
            return math.clamp(math.floor(speed * 3.6 + 0.5), SpeedLimiter.MIN, SpeedLimiter.MAX)
        end
    end
    return SpeedLimiter.MAX
end

function SpeedLimiter:onLoad(savegame)
    self.spec_speedLimiterMod = { limit = 0, active = false, actionEvents = {}, holdAction = nil, holdStart = 0, holdLastCall = 0, holdLastStep = 0 }
end

function SpeedLimiter:onReadStream(streamId, connection)
    local limit = streamReadUInt8(streamId)
    local active = streamReadBool(streamId)
    self:setSpeedLimiterState(limit, active, true)
end

function SpeedLimiter:onWriteStream(streamId, connection)
    local spec = self.spec_speedLimiterMod
    streamWriteUInt8(streamId, spec.limit)
    streamWriteBool(streamId, spec.active)
end

function SpeedLimiter:setSpeedLimiterState(limit, active, noEventSend)
    local spec = self.spec_speedLimiterMod
    if limit ~= spec.limit or active ~= spec.active then
        SpeedLimiterEvent.sendEvent(self, limit, active, noEventSend)
        spec.limit = limit
        spec.active = active
    end
end

function SpeedLimiter:getSpeedLimiterValue()
    local spec = self.spec_speedLimiterMod
    local maxLimit = SpeedLimiter.getMaxLimit(self)
    local value = spec.limit > 0 and spec.limit or maxLimit
    return math.clamp(value, SpeedLimiter.MIN, maxLimit)
end

function SpeedLimiter:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
    local spec = self.spec_speedLimiterMod
    if self.isClient then
        self:clearActionEventsTable(spec.actionEvents)
        if isActiveForInput or isActiveForInputIgnoreSelection then
            for _, name in ipairs(SpeedLimiter.ACTIONS) do
                local triggerAlways = SpeedLimiter.HOLD_ACTIONS[name] == true
                local _, eventId = self:addActionEvent(spec.actionEvents, InputAction[name], self, SpeedLimiter.onAction, false, true, triggerAlways, true, nil)
                g_inputBinding:setActionEventTextVisibility(eventId, SpeedLimiter.HIDDEN_ACTIONS[name] ~= true)
            end
        end
    end
end

function SpeedLimiter:onAction(actionName, inputValue)
    if actionName == "SPEEDLIMITER_MOUSE" then
        SpeedLimiterHud.requestCursorToggle()
        return
    end

    local spec = self.spec_speedLimiterMod
    local value = self:getSpeedLimiterValue()

    if actionName == "SPEEDLIMITER_TOGGLE" then
        self:setSpeedLimiterState(value, not spec.active)
        return
    end

    if inputValue <= 0 then
        return
    end

    local now = g_time
    local isHeld = spec.holdAction == actionName and (now - spec.holdLastCall) < SpeedLimiter.HOLD_GAP
    spec.holdLastCall = now

    if isHeld then
        if now - spec.holdStart < SpeedLimiter.REPEAT_DELAY or now - spec.holdLastStep < SpeedLimiter.REPEAT_INTERVAL then
            return
        end
    else
        spec.holdAction = actionName
        spec.holdStart = now
    end
    spec.holdLastStep = now

    local step = actionName == "SPEEDLIMITER_UP" and SpeedLimiter.STEP or -SpeedLimiter.STEP
    local newLimit = math.clamp(value + step, SpeedLimiter.MIN, SpeedLimiter.getMaxLimit(self))
    self:setSpeedLimiterState(newLimit, spec.active)
end

function SpeedLimiter:updateVehiclePhysics(superFunc, axisForward, axisSide, doHandbrake, dt)
    local spec = self.spec_speedLimiterMod
    if spec ~= nil and spec.active and spec.limit > 0 and axisForward ~= 0 and axisForward * self.movingDirection >= 0 then
        local factor = math.clamp((spec.limit - self:getLastSpeed()) / SpeedLimiter.BAND, 0, 1)
        axisForward = axisForward * factor
    end
    return superFunc(self, axisForward, axisSide, doHandbrake, dt)
end
