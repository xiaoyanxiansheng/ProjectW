
--[[ 
Buff事件命中计数伤害模块
负责统计实体攻击命中目标的次数
根据命中次数触发额外伤害效果
支持普通攻击的命中计数
可扩展支持技能的命中计数
提供命中目标的记录和管理
实现基于命中次数的伤害计算
作为BuffManager和战斗系统之间的连接层
处理多目标命中的统计和效果
支持不同类型的命中计数触发条件
]]--

---@class BuffEventHitCountDamange : NewBuffEvent
BuffEventHitCountDamange = Classnew("BuffEventHitCountDamange",NewBuffEvent)

---@brief 构造函数，初始化命中计数伤害事件
function BuffEventHitCountDamange:ctor()
    NewBuffEvent.ctor(self ,BuffEvent.HitCountDamange)

    -- 存储命中目标的实体ID列表，结构为 {casterinsid = {buffId = {skillId = {targetinsid1, targetinsid2, ...}}}}
    self._hitInsIdList = {}
end

---@brief Buff添加时注册实体攻击消息监听
---@param buff NewBuff 被添加的Buff对象
function BuffEventHitCountDamange:OnAdd(buff)
    RegisterMessage(MsgConst.ENTITY_ATTACK , self.MSG_ENTITY_ATTACK , self)
    RegisterMessage(MsgConst.ENTITY_ATTACKED , self.MSG_ENTITY_ATTACKED , self)
end

---@brief Buff移除时注销实体攻击消息监听
---@param buff NewBuff 被移除的Buff对象
function BuffEventHitCountDamange:OnRemove(buff)
    RemoveMessage(MsgConst.ENTITY_ATTACK , self.MSG_ENTITY_ATTACK)
    
    local entityId = buff:GetDoBuffData().EntityId
    local buffId = buff:GetDoBuffData().BuffId
    if self._hitInsIdList[entityId] and self._hitInsIdList[entityId][buffId] then
        self._hitInsIdList[entityId][buffId] = nil
    end
end

---@brief 实体攻击消息处理函数，记录攻击者命中的目标
---@param msg table 消息数据，包含攻击者和目标的实体ID
function BuffEventHitCountDamange:MSG_ENTITY_ATTACK(msg)
    local casterInsId = msg.params.casterinsid
    local targetInsId = msg.params.targetinsid
    self:ENTITY_ATTACK(casterInsId , targetInsId)

    if msg.params.splitinsids then
        for _, insId in pairs(msg.params.splitinsids) do
            self:ENTITY_ATTACK(casterInsId , insId)
        end
    end
end

function BuffEventHitCountDamange:MSG_ENTITY_ATTACKED(msg)
    local casterInsId = msg.params.casterinsid
    local targetInsId = msg.params.targetinsid
    self:ENTITY_ATTACK(casterInsId , targetInsId)

    if msg.params.splashinsids then
        for _, insId in pairs(msg.params.splashinsids) do
            self:ENTITY_ATTACK(casterInsId , insId)
        end
    end
end

function BuffEventHitCountDamange:ENTITY_ATTACK(casterInsId , targetInsId)
    if not self._buffs[casterInsId] then
        return
    end

    for buffId, _ in pairs(self._buffs[casterInsId]) do
        if self._hitInsIdList[casterInsId] == nil then
            self._hitInsIdList[casterInsId] = {}
        end
        if self._hitInsIdList[casterInsId][buffId] == nil then
            self._hitInsIdList[casterInsId][buffId] = {}
        end
        if self._hitInsIdList[casterInsId][buffId][1] == nil then
            self._hitInsIdList[casterInsId][buffId][1] = {}
        end

        local inIndex = table.ContainValue(self._hitInsIdList[casterInsId][buffId][1],targetInsId,nil,nil)
        if inIndex == 0 then
            table.insert(self._hitInsIdList[casterInsId][buffId][1],targetInsId)
        end
    end
end

---@brief 获取指定实体和技能的命中次数倍率
---@param insId integer 实体ID
---@param skillId integer 技能ID
---@return number 根据命中次数计算的伤害倍率
function BuffEventHitCountDamange:GetHitCountTimes(insId , skillId)
    local times = 1.0

    if self._hitInsIdList[insId] and self._buffs[insId] then
        for buffId, skillToInsIds in pairs(self._hitInsIdList[insId]) do
            if skillToInsIds[skillId] and self._buffs[insId][buffId] then
                local hitCount = table.length(skillToInsIds[skillId])
                local buff = self._buffs[insId][buffId]
                local doBuffData = buff:GetDoBuffData()
                local entityId = doBuffData.EntityId
                local buffId = doBuffData.BuffId
                local buffLevel = doBuffData.BuffLevel
                local params = self:GetEffectParams(entityId,buffId)
                params = GetConfDataLevel(params,buffLevel)
                times = times * GetConfDataLevel(params , hitCount)
            end
        end
    end

    return times
end