---@class BuffEventAttackDamageTimes : NewBuffEvent
BuffEventAttackDamageTimes = Classnew("BuffEventAttackDamageTimes", NewBuffEvent)

BuffEventAttackDamageTimesData = {
    EntityId = 0,
    BuffId = 0,
    AttackDamageTimes = 1.0,
}

-- 构造函数
function BuffEventAttackDamageTimes:ctor()
    NewBuffEvent.ctor(self, BuffEvent.AttackDamageTimes)

    ---@type table<integer,table<integer,table>> 实体ID -> BuffID -> AttackDamageTimesData
    self._entityAttackDamageTimesDataList = {}
end

-- Buff重置回调
function BuffEventAttackDamageTimes:OnReset(buff)
    local doBuffData = buff:GetDoBuffData()
    local entityId = doBuffData.EntityId
    local buffId = doBuffData.BuffId
    local buffLevel = doBuffData.BuffLevel

    if not self._entityAttackDamageTimesDataList[entityId] then
        self._entityAttackDamageTimesDataList[entityId] = {}
    end

    local params = self:GetEffectParams(entityId, buffId)
    local data = clone(BuffEventAttackDamageTimesData)
    data.EntityId = entityId
    data.BuffId = buffId
    
    -- 根据Buff等级获取攻击次数倍率 (params是一组等级值)
    if params and #params > 0 then
        -- 使用GetConfDataLevel来处理等级值
        data.AttackDamageTimes = GetConfDataLevel(params[1], buffLevel)
    else
        -- 如果没有参数，默认为1倍攻击次数
        data.AttackDamageTimes = 1.0
    end
    
    -- 计算堆叠效果
    local stackCountEffect = BuffManagerInstance:GetStackCountEffect(buff, self._buffEventId)
    data.AttackDamageTimes = data.AttackDamageTimes * stackCountEffect
    
    self._entityAttackDamageTimesDataList[entityId][buffId] = data

    DebugSKillLog_DoSkillData(DebugSKillLogLayer.All, "BuffEventAttackDamageTimes:OnReset", self._entityAttackDamageTimesDataList )
end

function BuffEventAttackDamageTimes:OnRemove(buff)
    local doBuffData = buff:GetDoBuffData()
    local entityId = doBuffData.EntityId
    local buffId = doBuffData.BuffId

    if self._entityAttackDamageTimesDataList[entityId] and self._entityAttackDamageTimesDataList[entityId][buffId] then
        self._entityAttackDamageTimesDataList[entityId][buffId] = nil
    end
end

function BuffEventAttackDamageTimes:OnUpdate(delta, buff)
    -- 攻击次数Buff不需要每帧更新，跟着buff的增删走
end

-- 获取实体的总攻击次数倍率（所有buff相乘）
---@param entityId integer 实体ID
---@return number 攻击次数倍率
function BuffEventAttackDamageTimes:GetAttackDamageTimes(entityId)
    local attackDamageTimesDataList = self._entityAttackDamageTimesDataList[entityId]
    if not attackDamageTimesDataList then
        return 1.0 -- 如果没有攻击次数数据，返回默认值1.0
    end
    
    local totalAttackDamageTimes = 1.0
    
    -- 遍历该实体的所有buff攻击次数，相乘计算
    for _, attackDamageTimesData in pairs(attackDamageTimesDataList) do
        if attackDamageTimesData then
            totalAttackDamageTimes = totalAttackDamageTimes * attackDamageTimesData.AttackDamageTimes
        end
    end
    
    DebugSKillLog_DoSkillData(DebugSKillLogLayer.All, "BuffEventAttackDamageTimes:GetAttackDamageTimes", {entityId , totalAttackDamageTimes})
    return totalAttackDamageTimes
end