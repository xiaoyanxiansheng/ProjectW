---@class BuffEventEffectShare : NewBuffEvent
BuffEventEffectShare = Classnew("BuffEventEffectShare",NewBuffEvent)
      
function BuffEventEffectShare:ctor()
    NewBuffEvent.ctor(self ,BuffEvent.EffectShare)

    ---@type table<integer,table<integer,table<integer,integer[]>>> 实体Id -> 效果叠加BuffId -> 效果叠加实体Id列表
    self._effectShareInsIds = {}
end


-- Buff添加回调，初始化实体的属性列表
---@param buff NewBuff
function BuffEventEffectShare:OnAdd(buff)
    local buffId = buff:GetDoBuffData().BuffId
    local doBuffData = buff:GetDoBuffData()
    local entityId = doBuffData.EntityId

    if self._effectShareInsIds[entityId] == nil then
        self._effectShareInsIds[entityId] = {}
    end

    local params = self:GetEffectParams(entityId,buffId)
    if params and params[1] and params[1][1] == 1 then
        local effectShareInsIds = doBuffData.InsIds
        for _, insId in ipairs(effectShareInsIds) do
            if not self._effectShareInsIds[entityId][insId] then
                self._effectShareInsIds[entityId][insId] = {}
            end
            self._effectShareInsIds[entityId][insId][buffId] = {entityId}
        end
    else
        local effectShareInsIds = doBuffData.InsIds
        if not self._effectShareInsIds[entityId][entityId] then
            self._effectShareInsIds[entityId][entityId] = {}
        end
        self._effectShareInsIds[entityId][entityId][buffId] = effectShareInsIds
    end

    DebugSKillLog_DoSkillData(DebugSKillLogLayer.All, "BuffEventEffectShare:OnAdd2" , self._effectShareInsIds)
end

function BuffEventEffectShare:OnRemove(buff)
    local doBuffData = buff:GetDoBuffData()
    local buffId = doBuffData.BuffId
    local entityId = doBuffData.EntityId
    local params = self:GetEffectParams(entityId,buffId)
    if not self._effectShareInsIds[entityId] then
        return
    end

    if params and params[1] and params[1][1] == 1 then
        local effectShareInsIds = doBuffData.InsIds
        for _, insId in ipairs(effectShareInsIds) do
            if self._effectShareInsIds[entityId][insId] ~= nil 
                and self._effectShareInsIds[entityId][insId][buffId] ~= nil then
                self._effectShareInsIds[entityId][insId][buffId] = nil
            end
        end
    else
        if self._effectShareInsIds[entityId][entityId] ~= nil then
            self._effectShareInsIds[entityId][entityId][buffId] = nil
        end
    end
end

---重置Buff事件
---@param buff NewBuff Buff对象
---@return nil
function BuffEventEffectShare:OnReset(buff)
    
end

-- 返回效果共享的实体Id列表
---@param insId integer 实体Id
---@return table<integer,integer[]>
function BuffEventEffectShare:GetEfectShareInsIds(insId)
    local effectShareInsIds = {}
    for _, entityInsIds in pairs(self._effectShareInsIds) do
        for _id, buffInsIds in pairs(entityInsIds) do
            if _id == insId then
                for buffId, shareInsIds in pairs(buffInsIds) do
                    effectShareInsIds[buffId] = shareInsIds
                end
            end
        end
    end
    return effectShareInsIds
end
