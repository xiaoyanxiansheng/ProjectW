---@class BuffEventInRange : NewBuffEvent
BuffEventInRange = Classnew("BuffEventInRange", NewBuffEvent)

BuffEventInRangeData = {
    EntityId = 0,
    Position = Vector(0,0,0),
    Radius = 0,
}

-- 构造函数
function BuffEventInRange:ctor()
    NewBuffEvent.ctor(self, BuffEvent.InRange)

    self._entityInRangeDataList = {}
end

-- Buff重置回调
function BuffEventInRange:OnReset(buff)
    local doBuffData = buff:GetDoBuffData()
    local entityId = doBuffData.EntityId
    local buffId = doBuffData.BuffId
    local skill = doBuffData.Skill
    local buffLevel = doBuffData.BuffLevel

    if not skill then
        error("BuffEventInRange:OnReset skill is nil" , buffId)
        return
    end

    if not self._entityInRangeDataList[entityId] then
        self._entityInRangeDataList[entityId] = {}
    end
    if not self._entityInRangeDataList[entityId][buffId] then
        self._entityInRangeDataList[entityId][buffId] = {}
    end

    local params = self:GetEffectParams(entityId, buffId)
    local data = clone(BuffEventInRangeData)
    data.EntityId = entityId
    data.BuffId = buffId
    data.Radius = GetConfDataLevel(params[1] , buffLevel)
    data.Position = skill:GetSkillTimeLine():GetNewPosition()
    self._entityInRangeDataList[entityId][buffId] = data

    DebugSKillLog_DoSkillData(DebugSKillLogLayer.All  , "BuffEventInRange:OnReset" , self._entityInRangeDataList)
    DrawDebugFan(data.Position, data.Radius, 360, Vector(1,0,0), buff:GetDuration() ,Vector(0, 255, 0))
end

function BuffEventInRange:OnRemove(buff)
    local doBuffData = buff:GetDoBuffData()
    local entityId = doBuffData.EntityId
    local buffId = doBuffData.BuffId

    if self._entityInRangeDataList[entityId] and self._entityInRangeDataList[entityId][buffId] then
        self._entityInRangeDataList[entityId][buffId] = nil
    end
end

function BuffEventInRange:OnUpdate(delta, buff)
    local doBuffData = buff:GetDoBuffData()
    local entityId = doBuffData.EntityId
    local buffId = doBuffData.BuffId
    local skill = doBuffData.Skill
    
    if not skill then
        error("BuffEventInRange:OnReset skill is nil" , buffId)
        return
    end

    local entity = GetEntityByInsId(entityId)
    if not entity then
        return
    end

    -- 获取实体当前位置
    local currentPosition = GetEntityPosition(entityId)
    
    -- 检查并获取调整后的位置
    local adjustedPosition , isOutRange = self:CheckAndGetPosition(entityId, currentPosition)
    
    -- 检查位置是否需要调整（使用距离阈值避免浮点数精度问题）
    local positionDifference = (adjustedPosition - currentPosition):Length()
    if positionDifference > 0.01 then  -- 使用小的阈值来避免浮点数精度问题
        SetEntityPosition(entityId, adjustedPosition)
    end

    if isOutRange then
        if skill:GetDoSkillData().CasterInsId == entityId then
            SkillManagerInstance:DoFinishSkill(skill)
        end
    end
end

function BuffEventInRange:CheckAndGetPosition(entityId , position)
    local isOutRange = false

    local inRangeDatas = self._entityInRangeDataList[entityId]
    if not inRangeDatas then
        return position , isOutRange -- 如果没有范围限制数据，返回原位置
    end
    
    local adjustedPosition = position
    
    -- 遍历该实体的所有buff范围限制
    for _, inRangeData in pairs(inRangeDatas) do
        if inRangeData then
            local centerPos = inRangeData.Position
            local radius = inRangeData.Radius
            
            -- 计算当前位置到圆心的距离
            local deltaX = adjustedPosition.x - centerPos.x
            local deltaY = adjustedPosition.y - centerPos.y
            local distance = math.sqrt(deltaX * deltaX + deltaY * deltaY)
            
            -- 如果超出圆形范围，需要调整到边缘位置
            if distance > radius then
                isOutRange = true
                -- 计算从圆心到目标位置的单位向量
                local unitX = deltaX / distance
                local unitY = deltaY / distance
                
                -- 计算圆形边缘的位置
                adjustedPosition = Vector(
                    centerPos.x + unitX * radius,
                    centerPos.y + unitY * radius,
                    adjustedPosition.z -- 保持z坐标不变
                )
            end
        end
    end
    
    return adjustedPosition , isOutRange
end