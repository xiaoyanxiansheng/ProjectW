--[[ 
动画事件模块
负责管理技能释放过程中的动画事件序列
包括角色动画的播放、切换和控制
提供事件注册、更新和执行功能
支持不同类型的动画效果和参数
作为技能时间线系统的组成部分，处理技能释放过程中的视觉表现
可以控制技能施放者或目标的动画状态
支持动画的同步和异步播放模式
--]]

---@class LineEventAnimation : SkillLineEvent
LineEventAnimation = Classnew("LineEventAnimation" , SkillLineEvent)
-- 子类继承 TimeLine 启动的时候会统一调用

function LineEventAnimation:ctor(skill,eventType , config,timeLineIndex)
    SkillLineEvent.ctor(self,skill,eventType, config,timeLineIndex)

    self._animationName = self._config[3]
    ---@type number
    self._animationTime = self._config[4] and tonumber(self._config[4]) or 0
end

function LineEventAnimation:OnReset()
    
end

-- 子类继承 LineEvent时间触发
function LineEventAnimation:OnInvoke()
    local doSkillData = self:GetSkill():GetDoSkillData()
    local casterInsId = doSkillData.CasterInsId
    PlayAnimation(casterInsId, self._animationName, self._animationTime)
end