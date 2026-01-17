---@class BuffEventDamageRebound : NewBuffEvent
BuffEventDamageRebound = Classnew("BuffEventDamageRebound",NewBuffEvent)

    
function BuffEventDamageRebound:ctor()
    NewBuffEvent.ctor(self ,BuffEvent.DamageRebound )
end