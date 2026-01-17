--[[ 
Buff事件禁止伤害模块
负责管理Buff事件禁止伤害的效果
包括伤害的计算和处理
提供Buff事件的触发和处理
支持不同类型的伤害限制
]]--

---@class BuffEventCantDamage : NewBuffEvent
BuffEventCantDamage = Classnew("BuffEventCantDamage",NewBuffEvent)

function BuffEventCantDamage:ctor()
    NewBuffEvent.ctor(self , BuffEvent.CantDamage)
end