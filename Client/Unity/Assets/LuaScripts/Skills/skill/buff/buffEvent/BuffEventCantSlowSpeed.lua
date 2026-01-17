--[[ 
Buff事件禁止减速模块
负责管理Buff事件禁止减速的效果
包括减速的计算和处理
提供Buff事件的触发和处理
支持不同类型的减速效果
]]--

---@class BuffEventCantSlowSpeed : NewBuffEvent
BuffEventCantSlowSpeed = Classnew("BuffEventCantSlowSpeed",NewBuffEvent)

        
function BuffEventCantSlowSpeed:ctor()
    NewBuffEvent.ctor(self ,BuffEvent.CantSlowSpeed )
end