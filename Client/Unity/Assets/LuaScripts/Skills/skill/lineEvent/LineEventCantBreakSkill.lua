--[[ 
技能时间线事件模块
负责管理技能释放过程中的时间线事件序列
包括预警、动画、特效、位移、伤害结算等各类事件的触发和执行
提供事件注册、更新、执行和清理的功能
支持复杂技能的时序控制和连锁效果
--]]

---@class LineEventCantBreakSkill : SkillLineEvent
LineEventCantBreakSkill = Classnew("LineEventCantBreakSkill" , SkillLineEvent)

function LineEventCantBreakSkill:ctor(skill,eventType , config,timeLineIndex)
    SkillLineEvent.ctor(self,skill,eventType, config,timeLineIndex)
end

-- 子类继承 TimeLine 启动的时候会统一调用
function LineEventCantBreakSkill:OnReset()
    
end

-- 子类继承 LineEvent时间触发
function LineEventCantBreakSkill:OnInvoke()
    local doSkillData = self:GetDoSkillData()
    self._cantBreakSkill = self._config[3] and tonumber(self._config[3]) == 1
    -- TODO 通过API判断
    -- local msg = BeginMessage(MsgConst.Skill_DO_BREAK)
    -- msg.params = {insid=doSkillData.CasterInsId,skillid=doSkillData.SkillId,cantbreakskill=self._cantBreakSkill}
    -- SendMessage(msg)
end

-- 子类继承 处理多段LineEvent
function LineEventCantBreakSkill:OnUpdate()

end

-- 技能释放过程中能否被打断
function LineEventCantBreakSkill:CantBreakSkill()
    return self._cantBreakSkill
end