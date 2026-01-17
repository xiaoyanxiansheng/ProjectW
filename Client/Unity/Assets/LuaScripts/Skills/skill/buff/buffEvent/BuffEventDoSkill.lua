--[[ 
Buff事件释放技能模块
负责管理Buff事件释放技能的效果
包括技能的触发和处理
提供Buff事件的触发和处理
支持不同类型的技能释放方式
]]--

---@class BuffEventDoSkill : NewBuffEvent
BuffEventDoSkill = Classnew("BuffEventDoSkill",NewBuffEvent)
      
function BuffEventDoSkill:ctor()
    NewBuffEvent.ctor(self ,BuffEvent.DoSkill)
end

---@param buff NewBuff
function BuffEventDoSkill:OnAdd(buff)
    local doBuffData = buff:GetDoBuffData()
    local entityId = doBuffData.EntityId
    local buffId = doBuffData.BuffId
    local buffLevel = doBuffData.BuffLevel

    local params = self:GetEffectParams(entityId,buffId)
    local skillId = GetConfDataLevel(params,buffLevel)[1]
    ---@type NewBuff
    local data = self._buffs[entityId][buffId]
    ---@type DoSkillData
    local doSkillData = DoSkillData.New()
    doSkillData.CasterInsId = data:GetDoBuffData().EntityId
    doSkillData.TargetInsId = doSkillData.CasterInsId
    doSkillData.SkillId = skillId
    doSkillData.SkillLevel = buffLevel
    SkillManagerInstance:DoSkill(doSkillData)
end