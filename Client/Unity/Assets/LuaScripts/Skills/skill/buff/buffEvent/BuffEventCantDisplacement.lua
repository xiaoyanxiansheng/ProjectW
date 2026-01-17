--[[ 
Buff事件禁止位移模块
负责管理Buff事件禁止位移的效果
包括位移的计算和处理
提供Buff事件的触发和处理
支持不同类型的位移限制
]]--

---@class BuffEventCantDisplacement : NewBuffEvent
BuffEventCantDisplacement = Classnew("BuffEventCantDisplacement",NewBuffEvent)

    
function BuffEventCantDisplacement:ctor()
    NewBuffEvent.ctor(self ,BuffEvent.CantDisplacement )
end