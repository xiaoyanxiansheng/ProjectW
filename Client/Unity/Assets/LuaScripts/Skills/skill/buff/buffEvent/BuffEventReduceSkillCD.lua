--[[ 
Buff事件减少技能CD模块
负责管理Buff事件减少技能CD的效果
包括技能CD的计算和减少
提供Buff事件的触发和处理
支持不同类型的技能CD减少方式
作为BuffManager和技能系统之间的连接层
处理Buff事件的逻辑和效果
支持Buff事件的优先级和覆盖规则
实现Buff事件的触发和处理
支持不同类型的技能CD减少方式
]]--

---@class BuffEventReduceSkillCD : NewBuffEvent
BuffEventReduceSkillCD = Classnew("BuffEventReduceSkillCD",NewBuffEvent)
      
--- 构造函数，初始化减少技能CD的Buff事件
function BuffEventReduceSkillCD:ctor()
    NewBuffEvent.ctor(self ,BuffEvent.ReduceSkillCD)
end

--- 重置Buff时的处理函数，应用减少技能CD的效果
---@param buff NewBuff 被重置的Buff对象
function BuffEventReduceSkillCD:OnReset(buff)
    local doBuffData = buff:GetDoBuffData()
    local entityId = doBuffData.EntityId
    local buffId = doBuffData.BuffId
    local buffLevel = doBuffData.BuffLevel

    -- 获取实体对象
    local entity = GetEntityByInsId(entityId)
    if not entity then
        return
    end

    -- 获取减少CD的参数
    local params = self:GetEffectParams(entityId,buffId)
    local reduceCDParam = GetConfDataLevel(params,buffLevel)
    local p = reduceCDParam[1]           -- 技能ID或概率
    local reduceType = reduceCDParam[2]  -- 减少类型：1=固定值，2=百分比
    local reduceValue = reduceCDParam[3] -- 减少的数值

    DebugSKillLog(DebugSKillLogLayer.All,"BuffEventReduceSkillCD:OnReset 减少技能CD" , table.tostring(reduceCDParam))

    -- 根据参数p的值决定减少CD的方式
    if p == 0 then
        -- 减少所有技能的CD
        if reduceType == 1 then
            entity:MinusAllSkillCD(reduceValue,0)  -- 固定值减少
        elseif reduceType == 2 then
            entity:MinusAllSkillCD(0,reduceValue)  -- 百分比减少
        end
    elseif p < 100 then
        -- 按概率p减少任意技能的CD
        if reduceType == 1 then
            entity:MinusAnySkillCD(reduceValue,0,p)  -- 固定值减少
        elseif reduceType == 2 then
            entity:MinusAnySkillCD(0,reduceValue,p)  -- 百分比减少
        end
    else
        -- 减少指定技能ID的CD
        if reduceType == 1 then
            entity:MinusSkillCDBySkillid(p,reduceValue,0)  -- 固定值减少
        elseif reduceType == 2 then
            entity:MinusSkillCDBySkillid(p,0,reduceValue)  -- 百分比减少
        end
    end
end