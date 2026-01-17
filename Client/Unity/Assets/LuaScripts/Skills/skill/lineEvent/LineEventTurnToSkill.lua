--[[ 
转向目标事件模块
负责管理技能释放过程中的转向目标事件序列
包括转向目标的计算和执行
提供事件注册、更新、执行和清理的功能
支持复杂技能的时序控制和连锁效果
--]]
---@class LineEventTurnToSkill : SkillLineEvent
LineEventTurnToSkill = Classnew("LineEventTurnToSkill" , SkillLineEvent)

function LineEventTurnToSkill:ctor(skill,eventType , config,timeLineIndex)
    SkillLineEvent.ctor(self,skill,eventType, config,timeLineIndex)
end

-- 子类继承 LineEvent时间触发
function LineEventTurnToSkill:OnInvoke()
    local forward = self:GetNewForward()
    local casterInsId = self:GetDoSkillData().CasterInsId
    SetEntityForwardVector(casterInsId,forward)
end

-- 子类继承 处理多段LineEvent
function LineEventTurnToSkill:OnUpdate()

end