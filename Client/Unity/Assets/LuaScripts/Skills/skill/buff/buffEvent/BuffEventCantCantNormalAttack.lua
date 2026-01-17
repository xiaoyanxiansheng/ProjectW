--[[ 
Buff事件禁止普通攻击模块
负责管理Buff事件禁止普通攻击的效果
包括普通攻击的限制和处理
提供Buff事件的触发和处理
支持不同类型的普通攻击限制
]]--

---@class BuffEventCantCantNormalAttack : NewBuffEvent
BuffEventCantCantNormalAttack = Classnew("BuffEventCantCantNormalAttack",NewBuffEvent)

function BuffEventCantCantNormalAttack:ctor()
    NewBuffEvent.ctor(self ,BuffEvent.CantCantNormalAttack)
end