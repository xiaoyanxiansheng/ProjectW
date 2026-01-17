--[[ 
转向目标事件模块
负责管理技能释放过程中的转向目标事件序列
包括转向目标的计算和执行
提供事件注册、更新、执行和清理的功能
支持复杂技能的时序控制和连锁效果
--]]
---@class LineEventTurnToTarget : SkillLineEvent
LineEventTurnToTarget = Classnew("LineEventTurnToTarget" , SkillLineEvent)

function LineEventTurnToTarget:ctor(skill,eventType , config,timeLineIndex)
    SkillLineEvent.ctor(self,skill,eventType, config,timeLineIndex)

    ---@type integer
---@diagnostic disable-next-line: assign-type-mismatch
    self._forwardType = tonumber(self._config[3])
end

-- 子类继承 LineEvent时间触发
function LineEventTurnToTarget:OnInvoke()
    local forward = Vector(0,0,0)
    if self:GetSkillTimeLine():IsNewPosition() then
        forward = self:GetNewForward()
    else
        forward = self:GetForward(self._forwardType)
    end
    local casterInsId = self:GetDoSkillData().CasterInsId
    SetEntityForwardVector(casterInsId,forward)
end

-- 子类继承 处理多段LineEvent
function LineEventTurnToTarget:OnUpdate()

end