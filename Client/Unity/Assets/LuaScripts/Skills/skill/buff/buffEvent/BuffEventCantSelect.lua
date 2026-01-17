--[[ 
Buff事件禁止选择模块
负责管理Buff事件禁止选择的效果
包括选择目标的计算和处理
提供Buff事件的触发和处理
支持不同类型的选择目标限制
]]--
---@class BuffEventCantSelect : NewBuffEvent
BuffEventCantSelect = Classnew("BuffEventCantSelect",NewBuffEvent)

       
function BuffEventCantSelect:ctor()
    NewBuffEvent.ctor(self ,BuffEvent.CantSelect)
end