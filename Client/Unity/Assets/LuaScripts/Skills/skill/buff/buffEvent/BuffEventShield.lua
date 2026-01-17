--[[ 
Buff事件护盾模块
负责管理Buff事件的护盾效果
包括护盾的添加、消耗和移除
提供护盾值计算和伤害吸收
支持多重护盾叠加和优先级消耗
维护实体的护盾列表
]]--
---@diagnostic disable: need-check-nil

---@class BuffEventShield : NewBuffEvent
BuffEventShield = Classnew("BuffEventShield", NewBuffEvent)

-- 构造函数，初始化护盾事件
function BuffEventShield:ctor()
    NewBuffEvent.ctor(self, BuffEvent.Shield) -- 假设已在BuffEvent中定义了Shield类型

    ---@type table<integer,{buffId:integer,value:number}[]> 实体ID -> 护盾数组(按添加顺序)
    self._shieldList = {}

    RegisterMessage(MsgConst.SHIELD_UPDATE_REDUCE , self.SHIELD_UPDATE_REDUCE , self)
    RegisterMessage(MsgConst.ENTITY_DEATH_2 , self.ENTITY_DEATH_2 , self)
end

-- Buff添加回调，初始化实体的护盾
---@param buff NewBuff
function BuffEventShield:OnAdd(buff)
    local doBuffData = buff:GetDoBuffData()
    local entityId = doBuffData.EntityId
    local buffId = doBuffData.BuffId

    -- 初始化实体的护盾列表
    ---@type table<integer,table<{buffId:integer,value:number}>>
    if not self._shieldList[entityId] then
        self._shieldList[entityId] = {}
    end

    -- 检查该buff是否已有护盾
    local inIndex = table.ContainValue(self._shieldList[entityId], buffId , "buffId")
    if inIndex == 0 then
        -- 如果不存在，在列表末尾添加一个新护盾条目
        table.insert(self._shieldList[entityId], {buffId = buffId, value = 0})
    end
end

-- Buff重置回调，重新计算护盾值
function BuffEventShield:OnReset(buff)
    local doBuffData = buff:GetDoBuffData()
    local entityId = doBuffData.EntityId
    local buffId = doBuffData.BuffId
    local buffLevel = doBuffData.BuffLevel

    -- 获取护盾效果参数
    local params = self:GetEffectParams(entityId, buffId)
    if params and #params > 0 then
        -- 计算堆叠效果
        local stackCountEffect = BuffManagerInstance:GetStackCountEffect(buff, self._buffEventId)
        
        -- 根据Buff等级计算护盾值
        local baseShieldValue = GetConfDataLevel(params[1] , buffLevel + 1)
        local shieldValue = baseShieldValue * stackCountEffect
        
        local t = params[1][1]
        if t == 1 then
            local entity = GetEntityByInsId(entityId)
            local maxhp = entity:GetAttr_MaxHP()
            shieldValue = shieldValue * maxhp
        end

        -- 更新护盾值
        for i, shield in ipairs(self._shieldList[entityId]) do
            if shield.buffId == buffId then
                shield.value = shieldValue
                break
            end
        end
        SendBeginMessage(MsgConst.SHIELD_UPDATE_VALUE , {insid = entityId, totalvalue = self:GetTotalShieldValue(entityId)})
    end
end

-- Buff移除回调，清除护盾效果
---@param buff NewBuff
function BuffEventShield:OnRemove(buff)
    local doBuffData = buff:GetDoBuffData()
    local entityId = doBuffData.EntityId
    local buffId = doBuffData.BuffId

    -- 从护盾列表中移除
    if self._shieldList[entityId] then
        local inIndex = table.ContainValue(self._shieldList[entityId], buffId , "buffId")
        if inIndex > 0 then
            table.remove(self._shieldList[entityId], inIndex)
            -- 发送护盾移除消息到客户端
            SendBeginMessage(MsgConst.SHIELD_UPDATE_VALUE , {insid = entityId, totalvalue = self:GetTotalShieldValue(entityId)})
        end
    end
end

function BuffEventShield:ENTITY_DEATH_2(msg)
    if msg.params.thorough then
        local insid = msg.params.insid
        self._shieldList[insid] = nil
    end
end

-- 获取实体的总护盾值
---@param entityId integer 实体ID
---@return number 总护盾值
function BuffEventShield:GetTotalShieldValue(entityId)
    local total = 0.0
    if self._shieldList[entityId] then
        for _, shield in ipairs(self._shieldList[entityId]) do
            total = total + shield.value
        end
    end
    return total
end

-- 清空实体的护盾值
---@param insId integer 实体ID
function BuffEventShield:ClearEntityShield(insId)
    self:ReduceShield(insId,999999999)
end

-- 核心方法：减少护盾值，按添加顺序消耗多个护盾
-- 返回实际被护盾吸收的伤害值
---@param entityId integer 实体ID
---@param reduceValue number 要减少的护盾值/伤害量
function BuffEventShield:ReduceShield(entityId, reduceValue)
    if not self._shieldList[entityId] or #self._shieldList[entityId] == 0 then
        return 0
    end
    
    local remainingDamage = reduceValue
    local buffsToRemove = {}
    
    -- 按照添加顺序依次扣减护盾
    for i, shield in ipairs(self._shieldList[entityId]) do
        if remainingDamage <= 0 then
            break
        end
        
        if shield.value > 0 then
            -- 计算此护盾能吸收的伤害
            local absorbByThisShield = math.min(remainingDamage, shield.value)
            
            -- 更新护盾值和剩余伤害
            shield.value = shield.value - absorbByThisShield
            remainingDamage = remainingDamage - absorbByThisShield
            
            -- 如果护盾已耗尽，标记为需要移除
            if shield.value <= 0 then
                table.insert(buffsToRemove, shield.buffId)
            end
        end
    end
    
    -- 移除耗尽的护盾Buff
    for _, buffId in ipairs(buffsToRemove) do
        BuffManagerInstance:RemoveBuff(entityId, buffId)
    end

    -- 消耗的护盾总量
    local totalConsumedShield = reduceValue - remainingDamage
    PassiveSkillManagerInstance:TRIGGER(PassiveSkillVariable.IsShieldChange,entityId,function(condition)
        condition[PassiveSkillVariable.ShieldChangeIns] = {insid = entityId, reduceshieldvalue = totalConsumedShield}
    end)
end

function BuffEventShield:SHIELD_UPDATE_REDUCE(msg)
    local insid = msg.params.insid
    local reduceshieldvalue = msg.params.reduceshieldvalue
    self:ReduceShield(insid, reduceshieldvalue)
    SendBeginMessage(MsgConst.SHIELD_UPDATE_VALUE , {insid = insid, totalvalue = self:GetTotalShieldValue(insid)})
end

function BuffEventShield:GetBuffIds(insId)
    return self._shieldList[insId]
end