--[[ 
预警事件模块
负责管理技能释放过程中的预警事件序列
包括预警的类型、位置、范围和参数
提供预警事件的注册、更新和执行功能
支持不同类型的预警和触发条件
--]]
---@class LineEventPreWarning : SkillLineEvent
LineEventPreWarning = Classnew("LineEventPreWarning" , SkillLineEvent)

-- 子类继承 TimeLine 启动的时候会统一调用
function LineEventPreWarning:OnReset()

end

-- 子类继承 LineEvent时间触发
function LineEventPreWarning:OnInvoke()

end

-- 子类继承 处理多段LineEvent
function LineEventPreWarning:OnUpdate()

end