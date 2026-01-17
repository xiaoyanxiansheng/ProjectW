--[[ 
Buff事件连续技能模块
负责管理Buff事件的连续技能效果
包括连续技能的触发和处理
提供Buff事件的触发和处理
支持不同类型的连续技能效果
]]--

-- 目前只能相同skillid才能触发

---@class BuffEventContinueSkill : NewBuffEvent
BuffEventContinueSkill = Classnew("BuffEventContinueSkill",NewBuffEvent)
    
--- 构造函数，初始化连续技能Buff事件
function BuffEventContinueSkill:ctor()
    NewBuffEvent.ctor(self ,BuffEvent.ContinueSkill)

    ---@type table<integer,table<integer,NewBuff>>> @<insId,<skillId,NewBuff>>>
    self._continueAttackList = {}  -- 存储实体ID和技能ID对应的连续攻击Buff
end

--- Buff事件开始时的处理函数
function BuffEventContinueSkill:OnStart()
    -- 当前无需特殊处理
end

--- 添加Buff时的处理函数
---@param buff NewBuff 被添加的Buff对象
function BuffEventContinueSkill:OnAdd(buff)
    local doBuffData = buff:GetDoBuffData()
    local entityId = doBuffData.EntityId  -- 获取实体ID

    if not doBuffData.Skill then
        print("BuffEventContinueSkill:OnAdd doBuffData.Skill is error")
        return
    end

    -- 初始化实体的连续攻击列表
    if not self._continueAttackList[entityId] then
        self._continueAttackList[entityId] = {}
    end

---@diagnostic disable-next-line: need-check-nil
    local skillId = doBuffData.Skill:GetSkillId()
    -- 同一技能只会存在一个连续攻击伤害提升
    self._continueAttackList[entityId][skillId] = buff
end

--- 移除Buff时的处理函数
---@param buff NewBuff 被移除的Buff对象
function BuffEventContinueSkill:OnRemove(buff)
    local doBuffData = buff:GetDoBuffData()
    local entityId = doBuffData.EntityId  -- 获取实体ID
    local buffId = doBuffData.BuffId      -- 获取Buff ID
    if not doBuffData.Skill then
        print("BuffEventContinueSkill:OnAdd doBuffData.Skill is error")
        return
    end

    local skillId = doBuffData.Skill:GetSkillId()
    -- 清除对应实体和技能ID的连续攻击Buff
    if self._continueAttackList[entityId] and
        self._continueAttackList[entityId][skillId] then
        self._continueAttackList[entityId][skillId] = nil
    end
end

--- 检查指定实体的指定技能是否为连续技能
---@param entityId integer 实体ID
---@param skillId integer 技能ID
---@return boolean 是否为连续技能
function BuffEventContinueSkill:IsContinueSkill(entityId,skillId)
    if not self._continueAttackList[entityId] or
        not self._continueAttackList[entityId][skillId] then
        return false
    end

    local buff = self._continueAttackList[entityId][skillId]
    local doBuffData = buff:GetDoBuffData()
    local buff = BuffManagerInstance:GetEntityBuff(entityId,doBuffData.BuffId)
    if not buff then
        return false
    end

    return true
end

--- 获取连续技能效果的倍率
---@param entityId integer 实体ID
---@param skillId integer 技能ID
---@return number 连续技能效果倍率，默认为1
function BuffEventContinueSkill:GetContinueSkillEffect(entityId,skillId)
    if self:IsContinueSkill(entityId , skillId) then
        local buff = self._continueAttackList[entityId][skillId]
        return BuffManagerInstance:GetStackCountEffect(buff, self._buffEventId)
    end
    return 1  -- 默认倍率为1
end