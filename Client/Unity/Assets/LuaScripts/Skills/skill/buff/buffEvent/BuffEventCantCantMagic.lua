--- BuffEventCantMagic 模块
--- 禁魔效果事件处理
--- 当单位被施加禁魔效果时，无法使用魔法技能

---@class BuffEventCantCantMagic : NewBuffEvent
BuffEventCantCantMagic = Classnew("BuffEventCantCantMagic",NewBuffEvent)

       
function BuffEventCantCantMagic:ctor()
    NewBuffEvent.ctor(self ,BuffEvent.CantCantMagic)
end