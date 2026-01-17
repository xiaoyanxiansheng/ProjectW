--[[ 
Buff事件健康伤害模块
负责管理Buff事件的健康伤害效果
包括伤害和恢复的计算
提供Buff事件的触发和处理
支持不同类型的健康伤害类型
作为BuffManager和实体之间的连接层
处理Buff事件的逻辑和效果
支持Buff事件的优先级和覆盖规则
实现Buff事件的触发和处理
支持不同类型的健康伤害类型
]]--

---@class BuffEventHealthDamage : NewBuffEvent
BuffEventHealthDamage = Classnew("BuffEventHealthDamage",NewBuffEvent)

-- 健康伤害事件数据结构
BuffEventHealthData = {
    Interval = 0,           -- 触发间隔时间
    HealthDamangeType = 1,  -- 健康伤害类型: 1恢复 2伤害
    HealthTimes = 0,        -- 健康效果倍数
    HealthParams = nil,     -- 恢复相关参数
    DamageParams = nil,     -- 伤害相关参数
    
    PassTime = 0,           -- 已经过的时间
}

---构造函数
---@return nil
function BuffEventHealthDamage:ctor()
    NewBuffEvent.ctor(self ,BuffEvent.HealthDamage)
    
    -- 存储所有实体的健康伤害数据
    self._healthData = {}
end

---重置Buff事件
---@param buff NewBuff Buff对象
---@return nil
function BuffEventHealthDamage:OnReset(buff)
    local doBuffData = buff:GetDoBuffData()
    local buffTableLine = buff:GetBuffTableLine()
    local entityId = doBuffData.EntityId
    local buffId = doBuffData.BuffId
    local buffLevel = doBuffData.BuffLevel

    -- 初始化实体的健康伤害数据结构
    if not self._healthData[entityId] then
        self._healthData[entityId] = {}
    end

    -- 获取效果参数并初始化数据
    local params = self:GetEffectParams(entityId,buffId)[1]  -- 只获取一个
    local data = clone(BuffEventHealthData)

    data.HealthDamangeType = params[1]
    data.Interval = params[2]
    data.PassTime = data.Interval
    data.IsFinish = false
    data.HealthTimes = GetConfDataLevel(params,buffLevel + 2)
---@diagnostic disable-next-line: need-check-nil
    data.HealthParams =  buffTableLine.Effect[self._buffEventId].HealthParams
---@diagnostic disable-next-line: need-check-nil
    data.DamageParams =  buffTableLine.Effect[self._buffEventId].DamageParams
    self._healthData[entityId][buffId] = data
end

---移除Buff事件
---@param buff NewBuff Buff对象
---@return nil
function BuffEventHealthDamage:OnRemove(buff)
    local doBuffData = buff:GetDoBuffData()
    local entityId = doBuffData.EntityId
    local buffId = doBuffData.BuffId

    -- 清除实体对应的Buff健康伤害数据
    if self._healthData[entityId] then
        self._healthData[entityId][buffId] = nil
    end
end

---更新Buff事件
---@param delta number 时间增量
---@param buff NewBuff Buff对象
---@return nil
function BuffEventHealthDamage:OnUpdate(delta, buff)
    local doBuffData = buff:GetDoBuffData()
    local entityId = doBuffData.EntityId
    local casterInsId = doBuffData:GetCasterInsId()
    local buffId = doBuffData.BuffId

    -- 检查实体是否存在且存活
    local entity = GetEntityByInsId(entityId)
    if entity == nil then
        return
    end

    if not entity:IsAlive() then
        return
    end

    if self._healthData[entityId] == nil then
        return
    end

    -- 处理健康伤害效果
    local data = self._healthData[entityId][buffId]
    if data == nil then
        return
    end

    local buffLevel = doBuffData.BuffLevel
    local hitEffectTimes = doBuffData.EffectTimes or 1
    local skillId = doBuffData.Skill and doBuffData.Skill:GetSkillId() or 0
    local HealthDamageParams = doBuffData.HealthDamageParams

    if data.PassTime >= data.Interval and not data.IsFinish then
        if data.Interval < 0.0001 then
            data.IsFinish = true
        end
        data.PassTime = data.PassTime - data.Interval
        local caster = casterInsId and GetEntityByInsId(casterInsId) or nil
        ---@type any
        local target = GetEntityByInsId(entityId)
        if caster and target then
            
            -- 计算效果倍数
            local stackCountEffect = BuffManagerInstance:GetStackCountEffect(buff , self._buffEventId)
            local hitCountDamageTimes = 1;--BuffManagerInstance:GetHitCountDamageTimes(entityId)
            local effectTimes = data.HealthTimes * hitEffectTimes * stackCountEffect * hitCountDamageTimes
            
            -- 记录调试日志
            DebugSKillLog(DebugSKillLogLayer.Common ,"BuffEventHealthDamage", data.HealthDamangeType,caster:GetInsid(), target:GetInsid(), skillId, buffLevel, effectTimes,hitEffectTimes,stackCountEffect,table.tostring(data.HealthParams),table.tostring(data.DamageParams))
            -- 根据类型应用恢复或伤害效果
            if data.HealthDamangeType == 1 then
                Fight:ApplyHeal(caster, target, skillId, buffLevel, effectTimes, HealthDamageParams or data.HealthParams)
            elseif data.HealthDamangeType == 2 then
                FightApplyDamage(caster, target, skillId, buffLevel, effectTimes, HealthDamageParams or data.DamageParams)
            end
        else
            DebugSKillLog(DebugSKillLogLayer.All , "BuffEventHealthDamage:OnUpdate failed " ,casterInsId,  entityId)
        end
    end
    -- 更新经过的时间
    data.PassTime = data.PassTime + delta
end