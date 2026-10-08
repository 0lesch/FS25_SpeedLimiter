SpeedLimiterEvent = {}
local SpeedLimiterEvent_mt = Class(SpeedLimiterEvent, Event)

InitEventClass(SpeedLimiterEvent, "SpeedLimiterEvent")

function SpeedLimiterEvent.emptyNew()
    return Event.new(SpeedLimiterEvent_mt)
end

function SpeedLimiterEvent.new(vehicle, limit, active)
    local self = SpeedLimiterEvent.emptyNew()
    self.vehicle = vehicle
    self.limit = limit
    self.active = active
    return self
end

function SpeedLimiterEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObject(streamId, self.vehicle)
    streamWriteUInt8(streamId, self.limit)
    streamWriteBool(streamId, self.active)
end

function SpeedLimiterEvent:readStream(streamId, connection)
    self.vehicle = NetworkUtil.readNodeObject(streamId)
    self.limit = streamReadUInt8(streamId)
    self.active = streamReadBool(streamId)
    self:run(connection)
end

function SpeedLimiterEvent:run(connection)
    if not connection:getIsServer() then
        g_server:broadcastEvent(SpeedLimiterEvent.new(self.vehicle, self.limit, self.active), nil, connection, self.vehicle)
    end

    if self.vehicle ~= nil and self.vehicle:getIsSynchronized() then
        self.vehicle:setSpeedLimiterState(self.limit, self.active, true)
    end
end

function SpeedLimiterEvent.sendEvent(vehicle, limit, active, noEventSend)
    if noEventSend == nil or noEventSend == false then
        if g_server ~= nil then
            g_server:broadcastEvent(SpeedLimiterEvent.new(vehicle, limit, active), nil, nil, vehicle)
        else
            g_client:getServerConnection():sendEvent(SpeedLimiterEvent.new(vehicle, limit, active))
        end
    end
end
