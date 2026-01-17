--- 血魔转化，开启后每次受到伤害，优先扣除魔法


---@diagnostic disable: need-check-nil

---@class BuffEventDamageHPMP : NewBuffEvent
BuffEventDamageHPMP = Classnew("BuffEventDamageHPMP", NewBuffEvent)

-- 构造函数
function BuffEventDamageHPMP:ctor()
    NewBuffEvent.ctor(self, BuffEvent.DamageHPMP)

    self._mphpList = {}
end

-- Buff添加回调
---@param buff NewBuff
function BuffEventDamageHPMP:OnAdd(buff)
    
end

-- Buff重置回调
function BuffEventDamageHPMP:OnReset(buff)
    local doBuffData = buff:GetDoBuffData()
    local entityId = doBuffData.EntityId
    local buffId = doBuffData.BuffId
    local buffLevel = doBuffData.BuffLevel
    local effectTimes = doBuffData.EffectTimes

    local params = self:GetEffectParams(entityId, buffId)
    local stackCountEffect = BuffManagerInstance:GetStackCountEffect(buff, self._buffEventId)

    local value = GetConfDataLevel(params[1] , buffLevel)
    value = value * stackCountEffect * effectTimes
    self._mphpList[entityId] = value
end

-- Buff移除回调
---@param buff NewBuff
function BuffEventDamageHPMP:OnRemove(buff)
    local doBuffData = buff:GetDoBuffData()
    local entityId = doBuffData.EntityId
    local buffId = doBuffData.BuffId

    self._mphpList[entityId] = nil
end

-- 获取血魔转化比例
---@param entityId integer 实体ID
---@return number 血魔转化比例
function BuffEventDamageHPMP:GetDamageHPMP(entityId)
    return self._mphpList[entityId] or 0
end