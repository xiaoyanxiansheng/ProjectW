--- BuffEventCantMagic 模块
--- 禁魔效果事件处理
--- 当单位被施加禁魔效果时，无法使用魔法技能

---@class BuffEventCantMagic : NewBuffEvent
BuffEventCantMagic = Classnew("BuffEventCantMagic",NewBuffEvent)

       
function BuffEventCantMagic:ctor()
    NewBuffEvent.ctor(self ,BuffEvent.CantMagic)
end

function BuffEventCantMagic:OnAdd(buff)
    if buff:GetDoBuffData().Skill then
        return
    end
    SkillManagerInstance:BreakSkill(buff:GetDoBuffData().EntityId)
end