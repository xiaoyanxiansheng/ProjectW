--[[ 
Buff事件位移模块
负责管理Buff事件的位移效果
包括位移的计算和处理
提供Buff事件的触发和处理
支持不同类型的位移方式
]]--

---@class BuffEventDisplacement : NewBuffEvent
BuffEventDisplacement = Classnew("BuffEventDisplacement",NewBuffEvent)

---@class BuffEventDisplacementData
---@field public Duration number 位移持续时间
---@field public StartPosition Vector 起始位置
---@field public EndPosition Vector 目标位置
---@field public Height number 位移高度
---@field public IsFinish boolean 是否完成位移
---@field public PassTime number 已经过的时间
BuffEventDisplacementData = {
    Duration = 0,        -- 位移持续时间
    StartPosition = Vector(0,0,0),   -- 起始位置
    EndPosition = Vector(0,0,0),     -- 目标位置
    Height = 0,          -- 位移高度

    IsFinish = false;    -- 是否完成位移
    PassTime = 0,        -- 已经过的时间

    MoveFinishBreakSkill = false, -- 位移结束是否中断技能
    Skill = nil
}

--- 构造函数，初始化位移Buff事件
function BuffEventDisplacement:ctor()
    NewBuffEvent.ctor(self ,BuffEvent.Displacement)

    ---@type table<integer,table<integer,BuffEventDisplacementData>> @<实体ID,<BuffID,位移数据>>
    self._displacements = {}
end

--- 添加Buff时的处理函数
---@param buff NewBuff 被添加的Buff对象
function BuffEventDisplacement:OnAdd(buff)
    self:InitData(buff)
    local doBuffData = buff:GetDoBuffData()
    local entityId = doBuffData.EntityId
    local buffId = doBuffData.BuffId

    -- 停止单位的所有移动命令，防止移动命令干扰位移
    local entity = GetEntityByInsId(entityId)
    if entity and entity:IsValid() and entity:IsAlive() then
        entity:StopButNotBreak()
        -- local dotaEntity = entity:GetDotaEntity()
        -- if dotaEntity then
        --     -- 发出停止命令，取消所有移动指令
        --     ExecuteOrderFromTable({
        --         UnitIndex = dotaEntity:entindex(),
        --         OrderType = DOTA_UNIT_ORDER_STOP,
        --     })
        -- end
    end

    DebugSKillLog_DoSkillData(DebugSKillLogLayer.All,"BuffEventDisplacement:OnAdd" ,self._displacements[entityId][buffId])
end

--- 重置Buff时的处理函数
---@param buff NewBuff 被重置的Buff对象
function BuffEventDisplacement:OnReset(buff)
    self:InitData(buff)
    local doBuffData = buff:GetDoBuffData()
    local entityId = doBuffData.EntityId
    local buffId = doBuffData.BuffId
    DebugSKillLog_DoSkillData(DebugSKillLogLayer.All,"BuffEventDisplacement:OnReset", self._displacements[entityId][buffId])
end

--- 移除Buff时的处理函数
---@param buff NewBuff 被移除的Buff对象
function BuffEventDisplacement:OnRemove(buff)
    local doBuffData = buff:GetDoBuffData()
    local entityId = doBuffData.EntityId
    local buffId = doBuffData.BuffId

    SetFindClearSpaceForUnit(entityId)

    -- 位移结束后，确保单位的角度被重置为正常状态
    local entity = GetEntityByInsId(entityId)
    if entity and entity:IsValid() and entity:IsAlive() then
        local dotaEntity = entity:GetDotaEntity()
        if dotaEntity then
            -- 重置单位的pitch和roll为0，保持模型直立
            local currentAngles = dotaEntity:GetAnglesAsVector()
            dotaEntity:SetAngles(0, currentAngles.y, 0)
        end
    end

    if self._displacements[entityId]
        and self._displacements[entityId][buffId] then
        self._displacements[entityId][buffId] = nil
        -- BuffManagerInstance:RemoveBuff(entityId , buffId)
    end
end

--- 更新Buff时的处理函数
---@param delta number 时间增量
---@param buff NewBuff 需要更新的Buff对象
function BuffEventDisplacement:OnUpdate(delta, buff)
    local doBuffData = buff:GetDoBuffData()
    local entityId = doBuffData.EntityId
    local buffId = doBuffData.BuffId

    if not self._displacements[entityId]
        or not self._displacements[entityId][buffId] then
        SetEntityValidPosition(entityId,nil)
        return
    end

    local data = self._displacements[entityId][buffId]
    if data.IsFinish then
        BuffManagerInstance:RemoveBuff(entityId , buffId)
        return
    end

    -- 更新经过时间
    data.PassTime = data.PassTime + delta
    local t = data.PassTime / data.Duration

    local newPosition = Vector(0,0,0)
    newPosition.x = data.EndPosition.x
    newPosition.y = data.EndPosition.y
    newPosition.z = data.EndPosition.z
    -- 检查是否击飞结束
    if t >= 1 then
        data.IsFinish = true
    else
        -- X方向计算
        local startPos = data.StartPosition or Vector(0,0,0)
        newPosition.x = Lerp(startPos.x, data.EndPosition.x, t)
        newPosition.y = Lerp(startPos.y, data.EndPosition.y, t)

        -- Y方向计算
        if t <= 0.5 then
            -- 上升阶段
            newPosition.z = Lerp(startPos.z, startPos.z + data.Height, t * 2)
            local validNewPosition = GetEntityValidPosition(entityId,newPosition)
            if validNewPosition then
                if newPosition.z < validNewPosition.z then
                    newPosition.z = validNewPosition.z
                end
            end
        else
            -- 下降阶段
            local p1 = Vector(newPosition.x,newPosition.y,startPos.z + data.Height)
            local validNewPosition = GetEntityValidPosition(entityId,p1)
            if validNewPosition then
                if p1.z < validNewPosition.z then
                    p1.z = validNewPosition.z
                end
            end
            local p2 = GetEntityValidPosition(entityId,newPosition)
            if p2 then
                newPosition.z = Lerp(p1.z, p2.z, (t - 0.5) * 2)
            end
        end
    end

    local entity = GetEntityByInsId(entityId)
    if entity and entity:IsAlive() then
        local rposition = GetEntityValidPosition(entityId,newPosition)
        if rposition then
            entity:SetPosition(newPosition)
            
            -- 重要：重置单位的角度，防止因为玩家点击地面导致模型朝地面旋转
            -- Dota 2 的 MoveToPosition 会让单位贴合地形并调整 pitch/roll 角度
            -- 这里强制重置角度为正常的水平状态
            local dotaEntity = entity:GetDotaEntity()
            if dotaEntity then
                -- 重置单位的pitch和roll为0，保持模型直立
                -- 参数：pitch, yaw, roll
                local currentAngles = dotaEntity:GetAnglesAsVector()
                dotaEntity:SetAngles(0, currentAngles.y, 0)
            end
        else
            data.IsFinish = true
        end
    end

    self:CheckMoveFinish(entityId , data)
end

--- 初始化位移数据
---@param buff NewBuff Buff对象
function BuffEventDisplacement:InitData(buff)
    local doBuffData = buff:GetDoBuffData()
    local buffTableLine = buff:GetBuffTableLine()
    local entityId = doBuffData.EntityId
    local buffId = doBuffData.BuffId
    local buffLevel = doBuffData.BuffLevel
    local endPosition = doBuffData.EndPosition or GetEntityPosition(entityId)

    local entity = GetEntityByInsId(entityId)
    if not entity then
        return
    end

    local buffEffect = self:GetEffectParams(entityId , buffId)
    local buffPrams = GetConfDataLevel(buffEffect,buffLevel)
    if not buffPrams then
        return
    end

    -- 瞬时每个实体对象只会存在一个位移
    local moveData = clone(BuffEventDisplacementData)
    moveData.Duration = math.max(0.01, GetConfDataLevel(buffTableLine.Duration, buffLevel))    -- 边界保护
    moveData.StartPosition = entity:GetPosition()
    moveData.EndPosition = endPosition or moveData.StartPosition
    moveData.Height = buffPrams[1] * doBuffData.AddTimes
    moveData.Skill = doBuffData.Skill
    moveData.MoveFinishBreakSkill = doBuffData.MoveFinishBreakSkill

    if not self._displacements[entityId] then
        self._displacements[entityId] = {}
    end
    self._displacements[entityId][buffId] = moveData

    -- 如果不可移动就直接结束
    self:CheckMoveFinish(entityId , moveData)
end

function BuffEventDisplacement:CheckMoveFinish(entityId , moveData)
    local cantDisplacement = BuffManagerInstance:InEventState(entityId , BuffEvent.CantDisplacement)
    local cantCantDisplacement = BuffManagerInstance:InEventState(entityId , BuffEvent.CantCantDisplacement)
    if (not cantCantDisplacement) and cantDisplacement then
        moveData.IsFinish = true
        if moveData.Skill and moveData.MoveFinishBreakSkill then
            SkillManagerInstance:DoFinishSkill(moveData.Skill)
        end
    end
end

function BuffEventDisplacement:IsMoveFinished(entityId , buffId)
    if not self._displacements[entityId]
        or not self._displacements[entityId][buffId] then
        return true
    end

    local data = self._displacements[entityId][buffId]
    return data.IsFinish
end

