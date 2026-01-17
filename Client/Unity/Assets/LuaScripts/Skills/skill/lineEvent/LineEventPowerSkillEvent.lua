--[[ 
技能事件模块
负责管理技能释放过程中的事件序列
包括技能的触发、状态变化和效果应用
提供事件注册、更新和执行功能
支持复杂技能的时序控制和连锁效果
--]]

---@class LineEventPowerSkillEvent : SkillLineEvent
LineEventPowerSkillEvent = Classnew("LineEventPowerSkillEvent" , SkillLineEvent)

-- 子类继承 TimeLine 启动的时候会统一调用
function LineEventPowerSkillEvent:OnReset()

end

-- 子类继承 LineEvent时间触发
function LineEventPowerSkillEvent:OnInvoke()

end

-- 子类继承 处理多段LineEvent
function LineEventPowerSkillEvent:OnUpdate()

end