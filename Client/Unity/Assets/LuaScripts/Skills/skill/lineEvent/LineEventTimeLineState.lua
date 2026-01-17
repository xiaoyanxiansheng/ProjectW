--[[ 
技能时间线状态事件模块
负责管理技能释放过程中的时间线状态变化
包括状态参数的处理和事件触发
提供状态事件的注册、更新和执行功能
支持向其他系统发送状态变化消息
作为技能时间线系统的组成部分，处理技能释放过程中的状态控制
--]]

---@class LineEventTimeLineState : SkillLineEvent
LineEventTimeLineState = Classnew("LineEventTimeLineState" , SkillLineEvent)

-- 子类继承 TimeLine 启动的时候会统一调用
function LineEventTimeLineState:OnReset()
    self._stateParams = clone(self._config)
    table.remove(self._stateParams,1)
    table.remove(self._stateParams,1)
end

-- 子类继承 LineEvent时间触发
function LineEventTimeLineState:OnInvoke()
    local doSkillData = self:GetDoSkillData()
    local skill = self:GetSkill()
    local msg = BeginMessage(MsgConst.SKILL_TIMELINE_EVENT_STATE)
    msg.params = {insid = doSkillData.CasterInsId, skillid = doSkillData.SkillId , skillinsid = skill:GetSkillInsId() , skilllevel = doSkillData.SkillLevel ,params = self._stateParams}
    SendMessage(msg)
end

-- 子类继承 处理多段LineEvent
function LineEventTimeLineState:OnUpdate()

end