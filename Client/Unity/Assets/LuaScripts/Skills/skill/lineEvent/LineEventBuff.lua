--[[ 
Buff事件模块
负责管理技能释放过程中的Buff事件序列
包括Buff的添加、移除和控制
提供事件注册、更新和执行功能
支持不同类型的Buff和控制参数
作为技能时间线系统的组成部分，处理技能释放过程中的Buff效果
--]]

---@class LineEventBuff : SkillLineEvent
LineEventBuff = Classnew("LineEventBuff" , SkillLineEvent)

function LineEventBuff:ctor(skill,eventType , config,timeLineIndex)
    SkillLineEvent.ctor(self,skill,eventType, config,timeLineIndex)

    ---@type integer
---@diagnostic disable-next-line: assign-type-mismatch
    self._buffId = tonumber(self._config[3])
    self._targetType = self._config[4] and tonumber(self._config[4]) or 0
end

-- 子类继承 TimeLine 启动的时候会统一调用
function LineEventBuff:OnReset()

end

-- 子类继承 LineEvent时间触发
function LineEventBuff:OnInvoke()
    local skill = self:GetSkill()
    local doSkillData = self:GetDoSkillData()
    if self._targetType == 2 then
        local caster = GetEntityByInsId(doSkillData.CasterInsId)
        if caster and caster:IsAlive() then
            ---@type UnitSummonsMessage[]
            local summons = caster:GetSummons()
            if summons then
                for insId, _ in pairs(summons) do
                    ---@type DoBuffData
                    local doBuffData = DoBuffData.New()
                    doBuffData.EntityId = insId
                    doBuffData.Skill = skill
                    doBuffData.BuffId = self._buffId
                    doBuffData.BuffLevel = doSkillData.SkillLevel
                    BuffManagerInstance:AddBuff(doBuffData)
                end
            end
        end
        return
    end

    ---@type DoBuffData
    local doBuffData = DoBuffData.New()
    doBuffData.EntityId = self._targetType == 0 and doSkillData.CasterInsId or doSkillData.TargetInsId
    doBuffData.Skill = skill
    doBuffData.BuffId = self._buffId
    doBuffData.BuffLevel = doSkillData.SkillLevel
    BuffManagerInstance:AddBuff(doBuffData)
end

-- 子类继承 处理多段LineEvent
function LineEventBuff:OnUpdate()

end