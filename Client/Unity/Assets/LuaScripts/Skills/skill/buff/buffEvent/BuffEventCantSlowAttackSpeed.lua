--[[ 
Buff事件禁止攻击速度减速模块
负责管理Buff事件禁止攻击速度减速的效果
包括攻击速度减速的计算和处理
提供Buff事件的触发和处理
支持不同类型的攻击速度减速效果
]]--

---@class BuffEventCantSlowAttackSpeed : NewBuffEvent
BuffEventCantSlowAttackSpeed = Classnew("BuffEventCantSlowAttackSpeed",NewBuffEvent)

       
function BuffEventCantSlowAttackSpeed:ctor()
    NewBuffEvent.ctor(self ,BuffEvent.CantSlowAttackSpeed )
end