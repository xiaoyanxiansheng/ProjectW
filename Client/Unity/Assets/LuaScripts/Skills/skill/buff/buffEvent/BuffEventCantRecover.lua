---@class BuffEventCantRecover : NewBuffEvent
BuffEventCantRecover = Classnew("BuffEventCantRecover",NewBuffEvent)

function BuffEventCantRecover:ctor()
    NewBuffEvent.ctor(self ,BuffEvent.CantRecover)

    ---@type table<integer,table<integer,integer[]>> 实体Id -> 效果叠加BuffId -> 禁止恢复的属性列表
    self._cantRecoverInsIds = {}
end

-- Buff添加回调，初始化实体的属性列表
---@param buff NewBuff
function BuffEventCantRecover:OnAdd(buff)
    local buffId = buff:GetDoBuffData().BuffId
    local doBuffData = buff:GetDoBuffData()
    local entityId = doBuffData.EntityId

    if not self._cantRecoverInsIds[entityId] then
        self._cantRecoverInsIds[entityId] = {}
    end
    self._cantRecoverInsIds[entityId][buffId] = {}
end

function BuffEventCantRecover:OnRemove(buff)
    local buffId = buff:GetDoBuffData().BuffId
    local entityId = buff:GetDoBuffData().EntityId
    if self._cantRecoverInsIds[entityId] ~= nil then
        self._cantRecoverInsIds[entityId][buffId] = nil
    end
end

---重置Buff事件
---@param buff NewBuff Buff对象
---@return nil
function BuffEventCantRecover:OnReset(buff)
    local doBuffData = buff:GetDoBuffData()
    local entityId = doBuffData.EntityId
    local buffId = doBuffData.BuffId

    local params = self:GetEffectParams(entityId, buffId)
    self._cantRecoverInsIds[entityId][buffId] = params[1]
end

-- 获取禁止恢复的属性列表
---@param entityId integer 实体Id
---@return integer[] 禁止恢复的属性列表
function BuffEventCantRecover:GetCantRecoverAttrList(entityId)
    local cantRecoverAttrList = {}
    if self._cantRecoverInsIds[entityId] ~= nil then
        for _, buffIds in pairs(self._cantRecoverInsIds[entityId]) do
            for _, attrId in ipairs(buffIds) do
                if table.ContainValue(cantRecoverAttrList , attrId) == 0 then
                    table.insert(cantRecoverAttrList, attrId)
                end
            end
        end
    end
    return cantRecoverAttrList
end