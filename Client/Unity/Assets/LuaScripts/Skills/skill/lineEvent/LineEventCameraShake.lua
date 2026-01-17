--[[ 
相机震动事件模块
负责管理技能释放过程中的相机震动效果
包括震动的强度、持续时间和类型的控制
提供事件注册、更新和执行功能
支持不同类型的相机震动效果和参数
作为技能时间线系统的组成部分，处理技能释放过程中的视觉反馈
--]]

---@class LineEventCameraShake : SkillLineEvent
LineEventCameraShake = Classnew("LineEventCameraShake" , SkillLineEvent)

-- 子类继承 TimeLine 启动的时候会统一调用
function LineEventCameraShake:OnReset()

end

-- 子类继承 LineEvent时间触发
function LineEventCameraShake:OnInvoke()

end

-- 子类继承 处理多段LineEvent
function LineEventCameraShake:OnUpdate()

end