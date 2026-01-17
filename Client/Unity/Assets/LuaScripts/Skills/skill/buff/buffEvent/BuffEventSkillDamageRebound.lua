---@class BuffEventSkillDamageRebound : NewBuffEvent
BuffEventSkillDamageRebound = Classnew("BuffEventSkillDamageRebound",NewBuffEvent)

    
function BuffEventSkillDamageRebound:ctor()
    NewBuffEvent.ctor(self ,BuffEvent.SkillDamageRebound )
end