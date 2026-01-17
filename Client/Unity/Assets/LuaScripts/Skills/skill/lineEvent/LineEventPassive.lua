--[[ 
被动技能事件模块
负责管理技能释放过程中的被动技能效果
包括添加、移除和触发被动技能效果
支持不同类型的被动技能（技能、buff、结算）
作为技能时间线系统的组成部分，处理技能释放过程中的被动效果
可以为施法者添加持续性的被动效果
支持被动效果的条件检查和触发
可以在技能结束时自动清理被动效果
--]]


---@class LineEventPassive : SkillLineEvent
LineEventPassive = Classnew("LineEventPassive" , SkillLineEvent)

LineEventPassive.PassiveType = {
    Skill = 1,
    Buff = 2,
    Settlement = 3
}

function LineEventPassive:ctor(skillTimeLine,eventType , config, timeLineIndex)
    SkillLineEvent.ctor(self,skillTimeLine,eventType, config, timeLineIndex)

    ---@type integer
---@diagnostic disable-next-line: assign-type-mismatch
    self._passiveId = self._config[3] and tonumber(self._config[3]) or -1
    local p4 = self._config[4]
    ---@type number[]
    local p4s = string.split_lite(tostring(p4),"_")
    -- 类型
    ---@type integer
---@diagnostic disable-next-line: assign-type-mismatch
    self._ptype = tonumber(p4s[1])
    if #p4s == 2 then
        -- 参数
            ---@type integer
---@diagnostic disable-next-line: assign-type-mismatch
        self._ptypeV = tonumber(p4s[2])
    end

    self._deltaInterval = 0.0
end

-- 子类继承 LineEvent时间触发
function LineEventPassive:OnInvoke()
    local doSkillData = self:GetDoSkillData()

    self._moveSpeed = 0.0
    self._moveDistance = 0.0

    PassiveSkillManagerInstance:Add(doSkillData.CasterInsId, self._passiveId,doSkillData.SkillLevel,true)
end

function LineEventPassive:OnUpdate(delta)
    -- 间隔0.1秒触发
    self._deltaInterval = self._deltaInterval - delta
    if self._deltaInterval <= 0 then
        self._deltaInterval = 0.1
        return false
    end

    local entity = GetEntityByInsId(self:GetDoSkillData().CasterInsId)
    local curPosition = entity:GetPosition()  -- 获取当前位置
    if self._prePosition == nil then
        self._prePosition = curPosition
    end
---@diagnostic disable-next-line: undefined-field
    local deltaDistance = (curPosition - self._prePosition):Length()
    self._prePosition = curPosition

    self._moveSpeed = deltaDistance / (delta * 10)
    self._moveDistance = self._moveDistance + deltaDistance

    self:CheckAndPlayPassive(function(condition)
        condition.movespeed = self._moveSpeed
        condition.movedistance = self._moveDistance
    end)

    return true
end

-- 子类继承 技能结束时的回调
function LineEventPassive:OnSkillFinish()
    local doSkillData = self:GetDoSkillData()
    PassiveSkillManagerInstance:Remove(doSkillData.CasterInsId, self._passiveId)
    return true
end

function LineEventPassive:CheckAndPlayPassive(modifyCall)
    local doSkillData = self:GetDoSkillData()
    local casterInsId = doSkillData.CasterInsId
    local passiveSkill = PassiveSkillManagerInstance:GetEntityPassive(casterInsId,self._passiveId)
    if not passiveSkill then
        return false
    end

    local skill = self:GetSkill()
    if self._ptype == LineEventPassive.PassiveType.Skill then
        local condition = PassiveSkillManagerInstance:TRIGGERCONDITION(PassiveSkillVariable.IsDoSkill , casterInsId, function(condition) modifyCall(condition) end,skill)
        passiveSkill:CheckAndApply(condition)
        passiveSkill:CheckAndRemove(condition)
    elseif self._ptype == LineEventPassive.PassiveType.Buff then
        local buffId = self._ptypeV
        local buff = BuffManagerInstance:GetEntityBuff(casterInsId,buffId)
        if not buff then
            return false
        end

        local condition = PassiveSkillManagerInstance:TRIGGERCONDITION(PassiveSkillVariable.IsDoSkill , casterInsId,function(condition) modifyCall(condition) end,skill , nil, buff)
        passiveSkill:CheckAndApply(condition)
        passiveSkill:CheckAndRemove(condition)
    elseif self._ptype == LineEventPassive.PassiveType.Settlement then
        local skillTimeLineIndex = self._ptypeV
        local skillTimeLine = self:GetSkillTimeLine()
        local settlementObject = skillTimeLine:GetSettlementObject(skillTimeLineIndex)
        if not settlementObject then
            return false
        end

        local condition = PassiveSkillManagerInstance:TRIGGERCONDITION(PassiveSkillVariable.IsDoSkill , casterInsId,function(condition) modifyCall(condition) end,skill, settlementObject)
        passiveSkill:CheckAndApply(condition)
        passiveSkill:CheckAndRemove(condition)
    else
        local condition = PassiveSkillManagerInstance:TRIGGERCONDITION(PassiveSkillVariable.IsDoSkill , casterInsId,function(condition) modifyCall(condition) end,skill)
        passiveSkill:CheckAndApply(condition)
        passiveSkill:CheckAndRemove(condition)
    end

    return true
end