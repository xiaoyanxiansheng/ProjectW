--[[ 
技能执行事件模块
负责管理技能释放过程中的子技能执行事件序列
包括子技能的触发和参数传递
提供事件注册、更新和执行功能
支持技能连锁和组合技能的实现
作为技能时间线系统的组成部分，处理技能释放过程中的子技能触发
--]]

---@class LineEventDoSkill : SkillLineEvent
LineEventDoSkill = Classnew("LineEventDoSkill" , SkillLineEvent)

function LineEventDoSkill:ctor(skill,eventType , config,timeLineIndex)
    SkillLineEvent.ctor(self,skill,eventType, config,timeLineIndex)

    self._eventSkillId = tonumber(self._config[3])
end

-- 子类继承 TimeLine 启动的时候会统一调用
function LineEventDoSkill:OnReset()

end

-- 子类继承 LineEvent时间触发
function LineEventDoSkill:OnInvoke()
    ---@type DoSkillData
    local doSkillData = self:GetDoSkillData()
    local newDoSKillData = clone(doSkillData)
    newDoSKillData.SkillId = self._eventSkillId
    SkillManagerInstance:DoSkill(newDoSKillData)
end

-- 子类继承 处理多段LineEvent
function LineEventDoSkill:OnUpdate()

end