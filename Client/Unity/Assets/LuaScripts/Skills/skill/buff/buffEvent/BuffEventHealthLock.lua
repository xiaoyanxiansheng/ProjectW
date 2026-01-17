---@class BuffEventHealthLock : NewBuffEvent
BuffEventHealthLock = Classnew("BuffEventHealthLock",NewBuffEvent)

       
function BuffEventHealthLock:ctor()
    NewBuffEvent.ctor(self ,BuffEvent.HealthLock )
end