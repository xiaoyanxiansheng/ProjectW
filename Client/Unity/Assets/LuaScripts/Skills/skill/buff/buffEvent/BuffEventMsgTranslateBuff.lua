---@class BuffEventMsgTranslateBuff : NewBuffEvent
BuffEventMsgTranslateBuff = Classnew("BuffEventMsgTranslateBuff",NewBuffEvent)

function BuffEventMsgTranslateBuff:ctor()
    NewBuffEvent.ctor(self ,BuffEvent.MsgTranslateBuff )

    self._translateBuffs = {}
end

function BuffEventMsgTranslateBuff:OnAdd(buff)
    local doBuffData = buff:GetDoBuffData()
    local entityId = doBuffData.EntityId
    local buffId = doBuffData.BuffId
    local buffLevel = doBuffData.BuffLevel
    local buffEffect = self:GetEffectParams(entityId , buffId)
    local buffPrams = GetConfDataLevel(buffEffect,buffLevel)

    local translateBuffId = buffPrams[1]
    local msgId = buffPrams[2]
    local msgParam1 = buffPrams[3]

    if not self._translateBuffs[entityId] then
        self._translateBuffs[entityId] = {}
    end
    table.insert(self._translateBuffs[entityId],{buffId,translateBuffId,msgId,msgParam1})

    RegisterMessage(msgId , self.TranslateBuff , self)
end

function BuffEventMsgTranslateBuff:OnRemoveEnd(buff)
    local doBuffData = buff:GetDoBuffData()
    local entityId = doBuffData.EntityId
    local buffId = doBuffData.BuffId
    if not self._translateBuffs[entityId] then
        return
    end
    for i = #self._translateBuffs[entityId], 1 , -1 do
        local buff = self._translateBuffs[entityId][i]
        if buff[1] == buffId then
            table.remove(self._translateBuffs[entityId],i)
        end
    end
end

function BuffEventMsgTranslateBuff:TranslateBuff(msg)
    local eventMsgId = msg.name
    local eventMsgParams = msg.params
    local eventInsId = eventMsgParams.insid or eventMsgParams.casterinsid
    for entityId, buffs in pairs(self._translateBuffs) do
        if entityId == eventInsId then
            for i = 1, #buffs do
                local buffParams = buffs[i]
                local buffId = buffParams[1]
                local translateBuffId = buffParams[2]
                local msgId = buffParams[3]
                local msgParam1 = buffParams[4]
                if eventMsgId == msgId and (msgParam1 == nil or (msgParam1 and eventMsgParams[msgParam1])) then
                    local buff = BuffManagerInstance:GetEntityBuff(eventInsId,buffId)
                    if buff then
                        local newDoBuffData = clone(buff:GetDoBuffData())
                        newDoBuffData.BuffId = translateBuffId
                        BuffManagerInstance:RemoveBuff(eventInsId,buffId)
                        BuffManagerInstance:AddBuff(newDoBuffData)
                    end
                end
            end
        end
    end
end