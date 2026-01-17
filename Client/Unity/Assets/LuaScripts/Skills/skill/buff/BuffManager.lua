---@diagnostic disable: need-check-nil
--[[ 
Buff管理器模块
负责管理游戏中所有实体的Buff效果
提供Buff的添加、移除、查询和更新功能
处理Buff事件的分发和响应
维护实体的属性修改和状态变化
支持Buff的持续时间、叠加和互斥逻辑
作为技能系统的核心组件，连接技能效果和实体状态
提供Buff数据的缓存和优化
支持不同类型的Buff事件处理器
实现Buff之间的优先级和覆盖规则
]]--

require("critcore.skill.buff.Buff")
require("critcore.skill.buff.buffEvent.BuffEvent")
require("critcore.skill.buff.buffEvent.BuffEventCantMagic")
require("critcore.skill.buff.buffEvent.BuffEventDisplacement")
require("critcore.skill.buff.buffEvent.BuffEventCantDisplacement")
require("critcore.skill.buff.buffEvent.BuffEventCantSlowSpeed")
require("critcore.skill.buff.buffEvent.BuffEventCantSlowAttackSpeed")
require("critcore.skill.buff.buffEvent.BuffEventCantDamage")
require("critcore.skill.buff.buffEvent.BuffEventCantSelect")
require("critcore.skill.buff.buffEvent.BuffEventAttr")
require("critcore.skill.buff.buffEvent.BuffEventCantNormalAttack")
require("critcore.skill.buff.buffEvent.BuffEventContinueSkill")
require("critcore.skill.buff.buffEvent.BuffEventHealthDamage")
require("critcore.skill.buff.buffEvent.BuffEventDoSkill")
require("critcore.skill.buff.buffEvent.BuffEventReduceSkillCD")
require("critcore.skill.buff.buffEvent.BuffEventHitCountDamange")
require("critcore.skill.buff.buffEvent.BuffEventBreakSkill")
require("critcore.skill.buff.buffEvent.BuffEventDeBuffCountDamage")
require("critcore.skill.buff.buffEvent.BuffEventFear")
require("critcore.skill.buff.buffEvent.BuffEventEffectShare")
require("critcore.skill.buff.buffEvent.BuffEventHealthLock")
require("critcore.skill.buff.buffEvent.BuffEventNoDraw")
require("critcore.skill.buff.buffEvent.BuffEventMsgTranslateBuff")
require("critcore.skill.buff.buffEvent.BuffEventCantCantMagic")
require("critcore.skill.buff.buffEvent.BuffEventCantCantNormalAttack")
require("critcore.skill.buff.buffEvent.BuffEventCantCantDisplacement")
require("critcore.skill.buff.buffEvent.BuffEventShield")
require("critcore.skill.buff.buffEvent.BuffEventNearEntity")
require("critcore.skill.buff.buffEvent.BuffEventDamageHPMP")
require("critcore.skill.buff.buffEvent.BuffEventIgnore")
require("critcore.skill.buff.buffEvent.BuffEventCantRecover")
require("critcore.skill.buff.buffEvent.BuffEventRevive")
require("critcore.skill.buff.buffEvent.BuffEventDamageRebound")
require("critcore.skill.buff.buffEvent.BuffEventSkillDamageRebound")
require("critcore.skill.buff.buffEvent.BuffEventInRange")
require("critcore.skill.buff.buffEvent.BuffEventState")
require("critcore.skill.buff.buffEvent.BuffEventAttackDamageTimes")

BuffDesignType = {
    None = 0,
    Control = 1
}

---@class BuffManager : Classnew
BuffManager = Classnew("BuffManager", nil)

-- 构造函数，初始化Buff管理器
function BuffManager:ctor()
    -- 存储所有实体的Buff
    self._entitieBuffs = {}

    -- 存储Buff来源信息
    self._buffSourceInfo = {}
    
    -- 延迟添加的Buff列表（用于优化大量Buff同时添加的性能）
    self._delayedBuffList = {}
    
    -- 延迟Reset的Buff列表（用于优化大量Buff同时Reset的性能）
    self._delayedResetBuffList = {}

    -- Buff事件类型到对应处理脚本的映射
    self._buffEventToScript = {
        [BuffEvent.State]               = BuffEventState.New(BuffEvent.State),
        [BuffEvent.CantMagic]           = BuffEventCantMagic.New(BuffEvent.CantMagic),
        [BuffEvent.Displacement]        = BuffEventDisplacement.New(BuffEvent.Displacement),
        [BuffEvent.CantDisplacement]    = BuffEventCantDisplacement.New(BuffEvent.CantDisplacement),
        [BuffEvent.ContinueSkill]       = BuffEventContinueSkill.New(BuffEvent.ContinueSkill),
        [BuffEvent.CantDamage]          = BuffEventCantDamage.New(BuffEvent.CantDamage),
        [BuffEvent.CantSelect]          = BuffEventCantSelect.New(BuffEvent.CantSelect),
        [BuffEvent.Attr]                = BuffEventAttr.New(BuffEvent.Attr),
        [BuffEvent.CantNormalAttack]    = BuffEventCantNormalAttack.New(BuffEvent.CantNormalAttack),
        [BuffEvent.HealthDamage]        = BuffEventHealthDamage.New(BuffEvent.HealthDamage),
        [BuffEvent.DoSkill]             = BuffEventDoSkill.New(BuffEvent.DoSkill),
        [BuffEvent.ReduceSkillCD]       = BuffEventReduceSkillCD.New(BuffEvent.ReduceSkillCD),
        [BuffEvent.HitCountDamange]     = BuffEventHitCountDamange.New(BuffEvent.HitCountDamange),
        [BuffEvent.BreakSkill]          = BuffEventBreakSkill.New(BuffEvent.BreakSkill),
        [BuffEvent.DeBuffCountDamage]   = BuffEventDeBuffCountDamage.New(BuffEvent.DeBuffCountDamage),
        [BuffEvent.Fear]                = BuffEventFear.New(BuffEvent.Fear),
        [BuffEvent.EffectShare]         = BuffEventEffectShare.New(BuffEvent.EffectShare),
        [BuffEvent.HealthLock]          = BuffEventHealthLock.New(BuffEvent.HealthLock),
        [BuffEvent.NoDraw]              = BuffEventNoDraw.New(BuffEvent.NoDraw),
        [BuffEvent.MsgTranslateBuff]    = BuffEventMsgTranslateBuff.New(BuffEvent.MsgTranslateBuff),
        [BuffEvent.CantCantMagic]       = BuffEventCantCantMagic.New(BuffEvent.CantCantMagic),
        [BuffEvent.CantCantNormalAttack] = BuffEventCantCantNormalAttack.New(BuffEvent.CantCantNormalAttack),
        [BuffEvent.CantCantDisplacement]  = BuffEventCantCantDisplacement.New(BuffEvent.CantCantDisplacement),
        [BuffEvent.Shield]              = BuffEventShield.New(BuffEvent.Shield),
        [BuffEvent.NearEntity]          = BuffEventNearEntity.New(BuffEvent.NearEntity),
        [BuffEvent.DamageHPMP]          = BuffEventDamageHPMP.New(BuffEvent.DamageHPMP),
        [BuffEvent.Ignore]              = BuffEventIgnore.New(BuffEvent.Ignore),
        [BuffEvent.CantRecover]         = BuffEventCantRecover.New(BuffEvent.CantRecover),
        [BuffEvent.Revive]              = BuffEventRevive.New(BuffEvent.Revive),
        [BuffEvent.DamageRebound]       = BuffEventDamageRebound.New(BuffEvent.DamageRebound),
        [BuffEvent.SkillDamageRebound]  = BuffEventSkillDamageRebound.New(BuffEvent.SkillDamageRebound),
        [BuffEvent.AttackDamageTimes]   = BuffEventAttackDamageTimes.New(BuffEvent.AttackDamageTimes),
        [BuffEvent.InRange]             = BuffEventInRange.New(BuffEvent.InRange),
    }

    ---@type table<integer,table<integer,number>> @<insId,<attr,value>>
    self._attrData = {}

    -- 属性缓存列表
    self._attrCacheList = {}

    self._pool = PoolManagerInstance:CreateAndRegister("Buff",self, self.createCall)

    -- 注册实体原始属性更新消息
    RegisterMessage(MsgConst.ENTITY_PRIMEVALATTR_UPDATE , self.MSG_ENTITY_PRIMEVALATTR_UPDATE , self)
    RegisterMessage(MsgConst.ENTITY_DEATH_2 , self.MSG_ENTITY_DEATH , self)
end

function BuffManager:createCall(handle, onStartCall, onResetCall, onEndCall , modifyCall)
    return NewBuff.New(handle, onStartCall, onResetCall, onEndCall , modifyCall)
end

function BuffManager:PoolGet(modifyBuffCall)
    return self._pool:Get(self, self.OnBuffStart , self.OnBuffReset , self.OnBuffEnd , modifyBuffCall)
end

function BuffManager:PoolBack(skill)
    self._pool:Back(skill)
end

-- 给实体增加一个Buff
---@param doBuffData DoBuffData Buff数据
---@param modifyBuffCall function|nil 可选的Buff修改回调函数
function BuffManager:AddBuff(doBuffData, modifyBuffCall)
    -- 优化检查：如果标记为优化，延迟添加
    if self:AddBuffOptimized(doBuffData, modifyBuffCall) then
        return
    end
    
    self:AddBuffCore(doBuffData, modifyBuffCall)
end

-- 给实体增加一个Buff（核心逻辑）
---@param doBuffData DoBuffData Buff数据
---@param modifyBuffCall function|nil 可选的Buff修改回调函数
function BuffManager:AddBuffCore(doBuffData, modifyBuffCall)
    local buffId = doBuffData.BuffId
    if buffId == nil or buffId == 0 then
        return
    end

    local entityId = doBuffData.EntityId
    local entity = GetEntityByInsId(entityId)
    if not entity then
        return
    end

    ---@type BuffTableLine
    local buffTableLine = clone(GetBuffLine(doBuffData.BuffId))
    if not buffTableLine then
        print("BuffManager.AddBuff error 技能配置表中不存在 Id：", doBuffData.BuffId)
        return
    end


    if self:IsIgnoreBuff(entityId,buffId) then
        DebugSKillLog_DoSkillData(DebugSKillLogLayer.All  , "BuffManager:AddBuff Buff已经被忽略" , {doBuffData.EntityId,doBuffData.BuffId} , table.tostring(buffTableLine,nil,nil))
        return
    end

    DebugSKillLog_DoSkillData(DebugSKillLogLayer.All  , "BuffManager:AddBuff 0 " , {doBuffData.EntityId,doBuffData.BuffId} , table.tostring(buffTableLine,nil,nil))
    if not self._entitieBuffs[entityId] then
        self._entitieBuffs[entityId] = {}
    end

    ---@type NewBuff
    local buff = self._entitieBuffs[entityId][buffId]
    -- 如果Buff已存在且叠加类型为忽略，则直接返回
    if self._entitieBuffs[entityId][buffId] and buffTableLine.OverlayType == BuffOverlayType.Ignore then
        if buff then
            buff:SetDoBuffData(doBuffData,buffTableLine)
            -- 被动修改
            self:CheckPassiveSkill(buff)
        end
        return
    end

    -- 如果Buff已存在且叠加类型为堆叠，则重置Buff并增加堆叠层数
    if buff and buffTableLine.OverlayType == BuffOverlayType.Stack then
        buff:SetDoBuffData(doBuffData,buffTableLine)
        -- 被动修改
        self:CheckPassiveSkill(buff)
        buff:Reset( doBuffData.AddStackCount)
        return
    end

    -- 如果Buff已存在且叠加类型为同类型覆盖不同类型叠加
    if buff and buffTableLine.OverlayType == BuffOverlayType.TypeDependent then
        local isSameType = false
        
        -- 获取已保存的来源信息
        local sourceInfo = self._buffSourceInfo[entityId] and self._buffSourceInfo[entityId][buffId]
        
        if sourceInfo then
            -- 判断是否同类型(通过对比来源信息)
            if not sourceInfo.hasSkill and not doBuffData.Skill then
                -- 两个buff都没有Skill字段，视为同类型
                isSameType = true
            elseif sourceInfo.hasSkill and doBuffData.Skill and 
                   sourceInfo.casterInsId == doBuffData.Skill:GetDoSkillData().CasterInsId then
                -- 两个buff都有Skill字段且CasterInsId相同，视为同类型
                isSameType = true
            end
        end
        
        -- 更新来源信息(如果是不同类型的话)
        if not isSameType then
            if not self._buffSourceInfo[entityId] then
                self._buffSourceInfo[entityId] = {}
            end
            self._buffSourceInfo[entityId][buffId] = {
                hasSkill = doBuffData.Skill ~= nil,
                casterInsId = doBuffData.Skill and doBuffData.Skill:GetDoSkillData().CasterInsId or 0
            }
        end
        
        -- 应用Buff数据
        buff:SetDoBuffData(doBuffData, buffTableLine)
        self:CheckPassiveSkill(buff)
        
        -- 根据是否同类型决定处理方式
        if isSameType then
            -- 同类型，执行覆盖但保持当前层数
            buff:Reset(0)
        else
            -- 不同类型，增加一层
            buff:Reset(doBuffData.AddStackCount)  -- 叠加处理方式
        end
        return
    end

    -- 如果Buff已存在且叠加类型为覆盖，则重置Buff
    if buff and buffTableLine.OverlayType == BuffOverlayType.Override then
        buff:SetDoBuffData(doBuffData,buffTableLine)
        -- 被动修改
        self:CheckPassiveSkill(buff)
        buff:Reset(0)
        return
    end

    -- 如果Buff不存在，则创建新的Buff
    if not self._entitieBuffs[entityId][buffId] then
        self._entitieBuffs[entityId][buffId] = self:PoolGet(modifyBuffCall)
        
        -- 保存来源信息
        if not self._buffSourceInfo[entityId] then
            self._buffSourceInfo[entityId] = {}
        end
        self._buffSourceInfo[entityId][buffId] = {
            hasSkill = doBuffData.Skill ~= nil,
            casterInsId = doBuffData.Skill and doBuffData.Skill:GetDoSkillData().CasterInsId or 0
        }
    end

    ---@type NewBuff
    buff = self._entitieBuffs[entityId][buffId]
    buff:SetDoBuffData(doBuffData,buffTableLine)
    -- 被动修改
    self:CheckPassiveSkill(buff)
    buff:Apply()

    DebugSKillLog_DoSkillData(DebugSKillLogLayer.All  , "BuffManager:AddBuff 1 " , {doBuffData.EntityId,doBuffData.BuffId} , table.tostring(buffTableLine,nil,nil))
end

--- 优化的Buff添加（分散性能开销）
---@param doBuffData DoBuffData Buff数据
---@param modifyBuffCall function|nil 可选的Buff修改回调函数
---@return boolean 是否优化（true表示已添加到延迟队列）
function BuffManager:AddBuffOptimized(doBuffData, modifyBuffCall)
    -- 只有标记为优化的Buff才延迟添加
    if doBuffData.IsOptimized then
        -- 随机0-0.5秒延迟，分散Buff添加的性能峰值
        local delay = math.random(0, 100) / 200.00
        table.insert(self._delayedBuffList, {doBuffData, modifyBuffCall, delay})
        return true
    end
    return false
end

--- 优化的Buff Reset（分散性能开销）
---@param insId integer 实体ID
---@param buffId integer BuffID
---@param stackCount integer 层数
---@return boolean 是否优化（true表示已添加到延迟队列）
function BuffManager:ResetBuffOptimized(insId, buffId, stackCount)
    -- 随机0-0.5秒延迟，分散Buff Reset的性能峰值
    local delay = math.random(0, 100) / 200.00
    table.insert(self._delayedResetBuffList, {insId, buffId, stackCount, delay})
    return true
end

-- 检查被动技能对Buff的影响
---@param buff NewBuff Buff对象
function BuffManager:CheckPassiveSkill(buff)
    if not buff then
        return
    end

    local insId = buff:GetDoBuffData().EntityId

    local condition = PassiveSkillManagerInstance:TRIGGERCONDITION(PassiveSkillVariable.IsAddBuff,insId,nil,buff:GetDoBuffData().Skill,nil,buff)
    PassiveSkillManagerInstance:ModifyBuff(buff,condition)
end

-- 检查被动技能对Buff的影响
---@param buff NewBuff Buff对象
function BuffManager:CheckFinishedPassiveSkill(buff)
    if not buff then
        return
    end

    local insId = buff:GetDoBuffData().EntityId

    local condition = PassiveSkillManagerInstance:TRIGGERCONDITION(PassiveSkillVariable.IsFinishedBuff,insId,nil,nil,nil,buff)
    PassiveSkillManagerInstance:ModifyBuff(buff,condition)
end

-- 移除实体上的特定Buff
---@param insId integer 实体ID
---@param buffId integer BuffID
function BuffManager:RemoveBuff(insId , buffId)
    if insId and buffId
        and self._entitieBuffs[insId] and
        self._entitieBuffs[insId][buffId] then
        ---@type NewBuff
        local buff = self._entitieBuffs[insId][buffId]
        buff:End()
        self._entitieBuffs[insId][buffId] = nil
        
        -- 清除来源信息
        if self._buffSourceInfo[insId] then
            self._buffSourceInfo[insId][buffId] = nil
        end
        
        DebugSKillLog(DebugSKillLogLayer.All  , "BuffManager:RemoveBuff " , insId , buffId)
    end
end

-- 移除实体上的所有Buff
---@param insId integer 实体ID
function BuffManager:RemoveBuffAll(insId)
    if insId and self._entitieBuffs[insId] then
        for _, buff in pairs(self._entitieBuffs[insId]) do
            buff:End()
        end
        self._entitieBuffs[insId] = nil
        
        -- 清除所有来源信息
        if self._buffSourceInfo[insId] then
            self._buffSourceInfo[insId] = nil
        end
    end
end

-- Buff开始时的回调函数
---@param buff NewBuff Buff对象
function BuffManager:OnBuffStart(buff )
    if not buff then
        return
    end

    local buffTableLine = buff:GetBuffTableLine()
    local doBuffData = buff:GetDoBuffData()
    local entityId = doBuffData.EntityId
    local buffId = doBuffData.BuffId
    local buffLevel = doBuffData.BuffLevel
    local duration = GetConfDataLevel(buffTableLine.Duration, buffLevel)

    --if buffTableLine.ClientShow == 1 then
        local msg = BeginMessage(MsgConst.BUFF_ADD);
        msg.params = {insid = entityId ,buffid = buffId ,bufflevel = buffLevel , buffduration = duration}
        SendMessage(msg)
    --end

    -- 注册Buff事件
    for _, event in pairs(BuffEvent) do
        if event >= 0 then
            local inEvent = table.ContainValue(buff.BuffEvent,event)
            if inEvent > 0 then
                ---@type NewBuffEvent
                local eventScript = self._buffEventToScript[event]
                if eventScript then
                    eventScript:Add(buff)
                end
            end
        end
    end
end

-- Buff重置时的回调函数
---@param buff NewBuff Buff对象
function BuffManager:OnBuffReset(buff)
    for _, event in pairs(BuffEvent) do
        if event >= 0 then
            local inEvent = table.ContainValue(buff.BuffEvent,event)
            if inEvent > 0 then
                ---@type NewBuffEvent
                local eventScript = self._buffEventToScript[event]
                if eventScript then
                    eventScript:Reset(buff)
                end
            end
        end
    end

    local buffTableLine = buff:GetBuffTableLine()
    --if buffTableLine.ClientShow == 1 then
        local buffData = buff:GetDoBuffData()
        local msg = {insid=buffData.EntityId,buffid=buffData.BuffId,bufflevel=buffData.BuffLevel,stack=buff:GetStackCount(),buffduration=buff:GetDuration(),notupdatebuffduration=false}
        SendBeginMessage(MsgConst.BUFF_OVERLAY_UPDATE,msg)
    --end
end

-- 设置
function BuffManager:SetStackCount(insId , buffId , stackCount)
    local buff = self:GetEntityBuff(insId , buffId)

    if not buff then
        return
    end

    buff:SetStackCount(stackCount)

    local buffData = buff:GetDoBuffData()
    buffData.InitStackCount = stackCount
    local msg = {insid=buffData.EntityId,buffid=buffData.BuffId,bufflevel=buffData.BuffLevel,stack=buff:GetStackCount(),buffduration=buff:GetDuration(),notupdatebuffduration=true}
    SendBeginMessage(MsgConst.BUFF_OVERLAY_UPDATE,msg)
end

-- 移除实体上的特定 NewBuff
---@param buff NewBuff Buff对象
function BuffManager:OnBuffEnd(buff)
    if not buff then
        return
    end

    local doBuffData = buff:GetDoBuffData()
    local buffTableLine = buff:GetBuffTableLine()
    local entityId = doBuffData.EntityId
    local buffId = doBuffData.BuffId

    -- LayeredAttributeSystem.Delete(buffTableLine)

    if self._entitieBuffs[entityId] == nil
        or self._entitieBuffs[entityId][buffId] == nil then
        return
    end

    self:CheckFinishedPassiveSkill(buff)

    -- 移除Buff事件
    for _, event in pairs(BuffEvent) do
        if event >= 0 then
            local inEvent = table.ContainValue(buff.BuffEvent,event)
            if inEvent > 0 then
                ---@type NewBuffEvent
                local eventScript = self._buffEventToScript[event]
                if eventScript then
                    eventScript:Remove(buff)
                end
            end
        end
    end

    self._entitieBuffs[entityId][buffId] = nil

    DebugSKillLog_DoSkillData(DebugSKillLogLayer.All  , "BuffManager:OnBuffEnd " , doBuffData , table.tostring(buffTableLine,nil,nil))

    self:PoolBack(buff)

    --if buffTableLine.ClientShow == 1 then
        local msg = BeginMessage(MsgConst.BUFF_REMOVE)
        msg.params = {insid=entityId , buffid=buffId}
        SendMessage(msg)
    --end

    -- 是否有后续技能
    local skillId = GetConfDataLevel(buffTableLine.DurationSkillId,doBuffData.BuffLevel)
    if skillId and skillId > 0 then
        local doSkillData = doBuffData.Skill and doBuffData.Skill:GetDoSkillData() or DoSkillData.New()
        doSkillData.SkillId = skillId
        doSkillData.SkillLevel = doBuffData.BuffLevel
        SkillManagerInstance:DoSkill(doSkillData)
    end

    -- 是否有结束Buff
    local durationBuffId = GetConfDataLevel(buffTableLine.DurationBuffId,doBuffData.BuffLevel)
    if durationBuffId and durationBuffId > 0 then
        BuffManagerInstance:AddBuffHelper(entityId, durationBuffId, doBuffData.BuffLevel)
    end
end

-- 更新所有实体的 NewBuff
---@param delta number 每帧更新的时间
function BuffManager:Update(delta)
    -- 处理延迟添加的Buff（倒序遍历以安全删除）
    for i = #self._delayedBuffList, 1, -1 do
        local val = self._delayedBuffList[i]
        local doBuffData = val[1]
        local modifyBuffCall = val[2]
        local duration = val[3]
        duration = duration - delta
        if duration <= 0 then
            table.remove(self._delayedBuffList, i)
            -- 直接调用核心逻辑，避免递归检查优化
            self:AddBuffCore(doBuffData, modifyBuffCall)
        else
            val[3] = duration
        end
    end
    
    -- 处理延迟Reset的Buff（倒序遍历以安全删除）
    for i = #self._delayedResetBuffList, 1, -1 do
        local val = self._delayedResetBuffList[i]
        local insId = val[1]
        local buffId = val[2]
        local stackCount = val[3]
        local duration = val[4]
        duration = duration - delta
        if duration <= 0 then
            table.remove(self._delayedResetBuffList, i)
            -- 直接执行Reset，高效且不走AddBuff流程
            local buff = self:GetEntityBuff(insId, buffId)
            if buff then
                buff:Reset(stackCount)
            end
        else
            val[4] = duration
        end
    end
    
    -- 更新所有Buff事件
    for _, eventScript in pairs(self._buffEventToScript) do
        eventScript:Update(delta)
    end

    -- 更新所有实体的所有Buff
    for _, buffs in pairs(self._entitieBuffs) do
        for _, buff in pairs(buffs) do
            buff:Update(delta)
        end
    end
end

-- 获取实体的 NewBuff 列表
---@param entityId integer 实体ID
---@return NewBuff[] 实体的所有Buff
function BuffManager:GetEntityBuffs(entityId)
    return self._entitieBuffs[entityId] or {}
end

-- 获取特定 NewBuff 的信息
---@param entityId integer 实体ID
---@param buffId integer BuffID
---@return NewBuff | nil 返回Buff对象或nil
function BuffManager:GetEntityBuff(entityId, buffId)
    local entityBuffs = self._entitieBuffs[entityId]
    if entityBuffs and entityBuffs[buffId] then
        return entityBuffs[buffId]
    end
    return nil
end

function BuffManager:IsEntityBuff(entityId, buffId)
    return self:GetEntityBuff(entityId, buffId) ~= nil
end

-- 是否处于某种BuffEvent状态
---@param entityId integer 实体ID
---@param buffEvent integer Buff事件类型
---@return boolean 是否处于该事件状态
---@return NewBuffEvent | nil 事件脚本
function BuffManager:InEventState(entityId , buffEvent)
    ---@type NewBuffEvent
    local event = self._buffEventToScript[buffEvent]
    if not event then
        return false
    end
    return event:InEventState(entityId)  , event
end

-- 获取实体的BuffID列表
---@param entityId integer 实体ID
---@param buffEvent integer Buff事件类型
---@return integer[] BuffID列表
function BuffManager:GetBuffIds(entityId , buffEvent)
    ---@type NewBuffEvent
    local event = self._buffEventToScript[buffEvent]
    if not event then
        return {}
    end
    return event:GetBuffIds(entityId)
end

-- 获取实体的属性值
---@param insId integer 实体ID
---@param attrId integer 属性ID
---@return table | nil {[value]:integer, [ratio]:integer} 属性值和比率
function BuffManager:GetAttr(insId, attrId)
    if not self._attrCacheList[insId] or not self._attrCacheList[insId][attrId] then
        self:ReGetAttr(insId,attrId)
    end

    if self._attrCacheList[insId] and self._attrCacheList[insId][attrId] then
        return self._attrCacheList[insId][attrId]
    end

    return nil
end

---清除指定实体的属性缓存（下次 GetAttr 时惰性重算）
---@param insId integer 实体ID
---@param attrIds table<integer, any> 需要清除的属性ID表（key为attrId）
function BuffManager:ClearAttrCache(insId, attrIds)
    if not self._attrCacheList[insId] then
        return
    end
    for attrId, _ in pairs(attrIds) do
        self._attrCacheList[insId][attrId] = nil
    end
end

-- 重新获取实体的属性值
---@param insId integer 实体ID
---@param attrId integer 属性ID
function BuffManager:ReGetAttr(insId, attrId)
    -- local entity = GetEntityByInsId(insId)
    -- if not entity then
    --     return
    -- end

    local attrEvent = self._buffEventToScript[BuffEvent.Attr]
    if attrEvent then
        self:ReGetAttrHelper(insId,attrId,attrEvent:GetAttr(insId))
    end

    local nearEntityEvent = self._buffEventToScript[BuffEvent.NearEntity]
    if nearEntityEvent then
        self:ReGetAttrHelper(insId,attrId,nearEntityEvent:GetAttr(insId))
    end
end

function BuffManager:ReGetAttrHelper(insId,attrId,attrs)
    if not attrs then
        return
    end
    local value = 0.0
    local ratio = 0.0
    local convert = nil
    local set = nil
    -- 计算属性值、比率、转换和设置
    for _, buffAttrs in pairs(attrs) do
        for tempAttrId, attr in pairs(buffAttrs) do
            if attrId == -1 or tempAttrId == attrId then
                local overlay = attr[1]
                local overlayValue = attr[2]
                if overlay == 1 then
                    value = value + overlayValue
                elseif overlay == 2 then
                    ratio = ratio + overlayValue
                elseif overlay == 3 then
                    if convert == nil then
                        convert = {}
                    end
                    for key, value in pairs(attr.values) do
                        table.insert(convert,{attrid=value[2],ratio=value[1],insid=value[3],toratio=value[4]})
                    end
                elseif overlay == 4 then
                    if set == nil then
                        set = 0
                    end
                    set = set + overlayValue
                end
            end
        end
    end

    -- 更新属性缓存
    if not self._attrCacheList[insId] then
        self._attrCacheList[insId] = {}
    end

    if not self._attrCacheList[insId][attrId] then
        if value ~= 0 or ratio ~= 0 or convert ~= nil or set ~= nil then
            self._attrCacheList[insId][attrId] = {value = value , ratio = ratio , convert = convert , set = set}
        end
    else
        self._attrCacheList[insId][attrId].value = value
        self._attrCacheList[insId][attrId].ratio = ratio
        self._attrCacheList[insId][attrId].convert = convert    -- TODO 这样有问题 转化的属性是双向的
        self._attrCacheList[insId][attrId].set = set
    end
end

-- 检查是否为连续技能
---@param insId integer 实体ID
---@param skillId integer 技能ID
---@return boolean 是否为连续技能
function BuffManager:IsContinueSkill(insId , skillId)
---@type BuffEventContinueSkill
    local script = self._buffEventToScript[BuffEvent.ContinueSkill]
    return script:IsContinueSkill(insId , skillId)
end

-- 连续技能伤害效果倍数
---@param insId integer 实体ID
---@param skillId integer 技能ID
---@return number 伤害效果倍数
function BuffManager:GetContinueSkillEffect(insId , skillId)
    ---@type BuffEventContinueSkill
    local script = self._buffEventToScript[BuffEvent.ContinueSkill]
    return script:GetContinueSkillEffect(insId , skillId)
end

-- 获取堆叠效果
---@param buff NewBuff Buff对象
---@param eventId integer 事件ID
---@return number 堆叠效果值
function BuffManager:GetStackCountEffect(buff , eventId)
    local stackCountParams = buff:GetBuffTableLine().Effect[eventId].StackCountParams
    local levelParams = GetConfDataLevel(stackCountParams, buff:GetBuffLevel())
    local stackCountParam = GetConfDataLevel(levelParams, buff:GetStackCount())
    return stackCountParam or 1
end

-- 实体原始属性更新消息处理
---@param msg table 消息数据
function BuffManager:MSG_ENTITY_PRIMEVALATTR_UPDATE(msg)
    local param = msg.params
    self:ReGetAttr(param.insid,param.attrid)
end

-- 实体死亡消息处理
---@param msg table 消息数据
function BuffManager:MSG_ENTITY_DEATH(msg)
    local param = msg.params
    if param.thorough then
        self:RemoveBuffAll(param.insid)
    end
end

-- 获取Buff几率加成
---@param casterInsId integer 施法者实体ID
---@param targetInsId integer 目标实体ID
---@param attrType integer 属性类型
---@return number Buff几率加成
function BuffManager:GetBuffOddsAdd(casterInsId , targetInsId , attrType )
    local radio = 0.0
    local caster = GetEntityByInsId(casterInsId)
    if attrType ~= nil and caster then
        radio = caster:GetAttr_BuffOddsAdd(attrType)
    end
    local target = GetEntityByInsId(targetInsId)
    if attrType ~= nil and target then
        radio = radio - target:GetAttr_BuffOddsMinus(attrType)
    end

    radio = 1 + radio
    if radio < 0 then
        radio = 0
    end

    return radio
end

-- 获取Buff时间加成
---@param casterInsId integer 施法者实体ID
---@param targetInsId integer 目标实体ID
---@param attrType integer 属性类型
---@return number Buff时间加成
function BuffManager:GetBuffTimeAdd(casterInsId , targetInsId , attrType)
    local radio = 0.0
    local caster = GetEntityByInsId(casterInsId)
    if attrType ~= nil and caster then
        radio = caster:GetAttr_BuffTimeAdd(attrType)
    end
    local target = GetEntityByInsId(targetInsId)
    if attrType ~= nil and target then
        radio = radio - target:GetAttr_BuffTimeMinus(attrType)
    end

    radio = 1 + radio
    if radio < 0 then
        radio = 0
    end

    return radio
end

-- 获取命中计数伤害次数
---@param insId integer 实体ID
---@param skillId integer 技能Id，普攻为1
---@return number 命中计数伤害次数
function BuffManager:GetHitCountDamageTimes(insId, skillId)
    ---@type BuffEventHitCountDamange
    local script = self._buffEventToScript[BuffEvent.HitCountDamange]
    return script:GetHitCountTimes(insId , skillId)
end

-- 获取命中计数次数
---@param insId integer 实体ID
---@return number 命中计数次数
function BuffManager:GetHitDebuffCountTimes(insId)
    ---@type BuffEventDeBuffCountDamage
    local script = self._buffEventToScript[BuffEvent.DeBuffCountDamage]
    return script:GetHitDebuffCountTimes(insId)
end

-- 返回效果共享的实体Id列表
---@param insId integer 实体ID
---@return table<integer,integer[]>
function BuffManager:GetEffectShareInsIds(insId)
    ---@type BuffEventEffectShare
    local script = self._buffEventToScript[BuffEvent.EffectShare]
    return script:GetEfectShareInsIds(insId)
end

-- 判断位移是否结束
---@param entityId integer 实体ID
---@param buffId integer BuffID
---@return boolean 是否结束
function BuffManager:IsMoveFinished(entityId , buffId)
    ---@type BuffEventDisplacement
    local script = self._buffEventToScript[BuffEvent.Displacement]
    return script:IsMoveFinished(entityId , buffId)
end

-- 获取实体的护盾值
---@param insId integer 实体ID
---@return number 护盾值
function BuffManager:GetTotalShieldValue(insId)
    ---@type BuffEventShield
    local script = self._buffEventToScript[BuffEvent.Shield]
    return script:GetTotalShieldValue(insId)
end

-- 清空实体的护盾值
---@param insId integer 实体ID
function BuffManager:ClearEntityShield(insId)
    ---@type BuffEventShield
    local script = self._buffEventToScript[BuffEvent.Shield]
    script:ClearEntityShield(insId)
end

-- 清楚负面控制Buff
---@param insId integer 实体ID
function BuffManager:ClearNegativeControlBuff(insId)
    -- 状态
    local eventControlList = {
        BuffEvent.CantDisplacement,
        BuffEvent.Fear
    }
    for _, event in pairs(eventControlList) do
        local inEventState , eventScript = self:InEventState(insId,event)
        if inEventState then
            local buffIds = eventScript:GetBuffIds(insId)
            for _, buffId in pairs(buffIds) do
                self:RemoveBuff(insId, buffId)
            end
        end
    end
end

function BuffManager:GetDamageHPMP(insId)
    ---@type BuffEventDamageHPMP
    local script = self._buffEventToScript[BuffEvent.DamageHPMP]
    return script:GetDamageHPMP(insId)
end

-- 判断是否为忽略Buff
---@param insId integer 实体ID
---@param buffId integer BuffID
---@return boolean 是否为忽略Buff
function BuffManager:IsIgnoreBuff(insId,buffId)
    local buffConfig = GetBuffLine(buffId)
    if not buffConfig then
        error("BuffManager.IsIgnoreBuff error Buff配置表中不存在 Id：", buffId)
        return false
    end

    ---@type BuffEventIgnore
    local script = self._buffEventToScript[BuffEvent.Ignore]
    local buffToIgnoreTypes = script:GetIgnoreType(insId)
    for _, ignoreTypes in pairs(buffToIgnoreTypes) do
        if table.ContainValue(ignoreTypes, buffConfig.DesignType) ~= 0 then
            return true
        end
    end

    return false
end

function BuffManager:GetCantRecoverAttrList(insId)
    ---@type BuffEventCantRecover
    local script = self._buffEventToScript[BuffEvent.CantRecover]
    return script:GetCantRecoverAttrList(insId)
end

function BuffManager:GetState(insId)
    ---@type BuffEventState
    local script = self._buffEventToScript[BuffEvent.State]
    return script:GetState(insId)
end

function BuffManager:AddBuffHelper(insId , buffId , buffLevel, modifyBuffCall , stackCount , effectTimes , isOptimized)
    local buff = self:GetEntityBuff(insId, buffId)
    if buff then
        if effectTimes ~= nil then
            buff:GetDoBuffData().EffectTimes = effectTimes
        end
        -- Buff已存在，执行Reset
        if isOptimized then
            -- 优化模式：延迟Reset
            self:ResetBuffOptimized(insId, buffId, stackCount or 1)
        else
            -- 正常模式：立即Reset
            buff:Reset(stackCount or 1)
        end
    else
        -- Buff不存在，创建新的
        local doBuffData = DoBuffData.New()
        doBuffData.EntityId = insId
        doBuffData.BuffId = buffId
        doBuffData.BuffLevel = buffLevel or 1
        doBuffData.InitStackCount = stackCount or 1
        doBuffData.EffectTimes = effectTimes or 1
        doBuffData.IsOptimized = isOptimized or false
        BuffManagerInstance:AddBuff(doBuffData, modifyBuffCall)
    end
end

function BuffManager:CheckAndGetPosition(entityId , position)
    local buffEvent = self._buffEventToScript[BuffEvent.InRange]
    if buffEvent then
        return buffEvent:CheckAndGetPosition(entityId , position)
    end
    return position , false
end

-- 获取实体的攻击伤害倍率
---@param entityId integer 实体ID
---@return number 攻击伤害倍率
function BuffManager:GetAttackDamageTimes(entityId)
    ---@type BuffEventAttackDamageTimes
    local buffEvent = self._buffEventToScript[BuffEvent.AttackDamageTimes]
    if buffEvent then
        return buffEvent:GetAttackDamageTimes(entityId)
    end
    return 1.0  -- 默认攻击伤害倍率为1
end

function BuffManager:Clear()
    -- 清理所有Buff
    for _, buffs in pairs(self._entitieBuffs) do
        for _, buff in pairs(buffs) do
            buff:End()
        end
    end
    self._entitieBuffs = {}
    self._buffSourceInfo = {}
    self._delayedBuffList = {}
    self._delayedResetBuffList = {}

    -- 清理对象池
    self._pool:Clear()
end

-- 判断Buff是否为控制类型
---@param buffId integer BuffID
---@return boolean 是否为控制类型
function BuffManager:IsControllType(buffId)
    local buffTableLine = GetBuffLine(buffId)
    if not buffTableLine then
        error("BuffManager.IsControllType error Buff配置表中不存在 Id：", buffId)
        return false
    end
    return (buffTableLine.DesignType or 0) == BuffDesignType.Control
end

-- 判断Buff是否是减益类型
---@param buffId integer BuffID
---@return boolean 是否是减益类型
function BuffManager:IsDebuffType(buffId)
    local buffTableLine = GetBuffLine(buffId)
    if not buffTableLine then
        error("BuffManager.IsDebuffType error Buff配置表中不存在 Id：", buffId)
        return false
    end
    return (buffTableLine.DesignType or 0) > BuffDesignType.None
end