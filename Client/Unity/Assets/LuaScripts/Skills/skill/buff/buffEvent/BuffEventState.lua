---@class BuffEventState : NewBuffEvent
BuffEventState = Classnew("BuffEventState",NewBuffEvent)

function BuffEventState:ctor()
    NewBuffEvent.ctor(self ,BuffEvent.State)

    self._state = {}
end

function BuffEventState:OnAdd(buff)
    local doBuffData = buff:GetDoBuffData()
    local entityId = doBuffData.EntityId
    local buffId = doBuffData.BuffId

    local state = self:GetEffectParams(entityId, buffId)
    if not self._state[entityId] then
        self._state[entityId] = {}
    end
    self._state[entityId][buffId] = state
end

function BuffEventState:OnRemove(buff)
    local doBuffData = buff:GetDoBuffData()
    local entityId = doBuffData.EntityId
    local buffId = doBuffData.BuffId
    if self._state[entityId] and self._state[entityId][buffId] then
        self._state[entityId][buffId] = nil
    end
end

function BuffEventState:GetState(insId)
    return self._state[insId]
end
