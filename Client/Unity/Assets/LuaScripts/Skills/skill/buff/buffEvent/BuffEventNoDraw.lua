--[[ 
隐身Buff事件模块
负责处理实体隐身效果的添加和移除
当Buff添加时使实体进入隐身状态
当Buff移除时恢复实体的可见性
作为BuffManager的事件处理器之一
支持游戏中的隐身、潜行等机制
与实体的NoDraw状态直接关联
]]--


---@class BuffEventNoDraw : NewBuffEvent
BuffEventNoDraw = Classnew("BuffEventNoDraw",NewBuffEvent)

function BuffEventNoDraw:ctor()
    NewBuffEvent.ctor(self ,BuffEvent.NoDraw)
end

function BuffEventNoDraw:OnAdd(buff)
    local entity = GetEntityByInsId(buff:GetDoBuffData().EntityId)
    if entity then
        entity.__DotaEntity:AddNoDraw()
    end
end

function BuffEventNoDraw:OnRemove(buff)
    local entity = GetEntityByInsId(buff:GetDoBuffData().EntityId)
    if entity then
        entity.__DotaEntity:RemoveNoDraw()
    end
end