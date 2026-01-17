--[[ 
Buff事件DeBuff计数伤害模块
负责管理Buff事件的DeBuff计数伤害效果
包括DeBuff计数的计算和伤害的触发
提供Buff事件的触发和处理
支持不同类型的DeBuff计数伤害类型
]]--

-- 目前只做了普通攻击，可扩展支持技能

---@class BuffEventDeBuffCountDamage : NewBuffEvent
BuffEventDeBuffCountDamage = Classnew("BuffEventDeBuffCountDamage",NewBuffEvent)

--- 构造函数，初始化DeBuff计数伤害Buff事件
function BuffEventDeBuffCountDamage:ctor()
    NewBuffEvent.ctor(self ,BuffEvent.DeBuffCountDamage)
end

--- 获取根据DeBuff数量计算的伤害倍率
---@param insId integer 实体ID
---@return number 伤害倍率
function BuffEventDeBuffCountDamage:GetHitDebuffCountTimes(insId)
    local times = 1.0

    if not self._buffs[insId] then
        return times
    end

    -- 当前Entity身上的DeBuff数量
    local debuffCount = 0
    local entityBuffs = BuffManagerInstance:GetEntityBuffs(insId)
    for buffId, _ in pairs(entityBuffs) do
        local buffTableLine = GetBuffLine(buffId)
        if buffTableLine.GainOrDeBuff == -1 then
            debuffCount = debuffCount + 1
        end
    end

    -- 当前身上需要计算DeBuff效果的Buff
    if debuffCount > 0 then
        for buffId, buff in pairs(self._buffs[insId]) do
            local doBuffData = buff:GetDoBuffData()
            local buffLevel = doBuffData.BuffLevel
            local params = self:GetEffectParams(insId,buffId)
            params = GetConfDataLevel(params,buffLevel)
            times = times * GetConfDataLevel(params , debuffCount)
        end
    end

    return times
end