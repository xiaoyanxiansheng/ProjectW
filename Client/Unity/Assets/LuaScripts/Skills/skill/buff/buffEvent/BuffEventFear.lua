--[[ 
Buff事件恐惧模块
负责管理Buff事件的恐惧效果
包括恐惧的转向和移动范围
提供Buff事件的触发和处理
支持不同类型的恐惧效果
]]--

BuffEventFearMoveData = {
    TurnTime = 0.0,
    Radius = 0.0,
    NextMoveTime = 0.0,
    InitialPosition = nil,
}

---@diagnostic disable: need-check-nil
---@class BuffEventFear : NewBuffEvent
BuffEventFear = Classnew("BuffEventFear", NewBuffEvent)

--- 构造函数，初始化恐惧Buff事件
function BuffEventFear:ctor()
    NewBuffEvent.ctor(self, BuffEvent.Fear)

    -- 恐惧只处理最后一个
    -- self._turnTime = 0.0      -- 转向时间
    -- self._radius = 0.0         -- 移动范围半径
    -- self._nextMoveTime = 0.0   -- 下一次移动的时间
    -- self._initialPosition = nil  -- 初始位置

    self._moveDatas = {}
end

--- 重置Buff时的处理函数
---@param buff NewBuff 被重置的Buff对象
function BuffEventFear:OnReset(buff)
    local doBuffData = buff:GetDoBuffData()
    local insId = doBuffData.EntityId
    local entity = GetEntityByInsId(insId)
    if not entity then
        return
    end

    -- 获取恐惧效果参数
    local params = self:GetEffectParams(doBuffData.EntityId, doBuffData.BuffId)
    local fearParams = GetConfDataLevel(params, doBuffData.BuffLevel)
    self._turnTime = fearParams[1]  -- 转向时间
    self._radius = fearParams[2]  -- 移动范围
    self._nextMoveTime = 0.0 -- 立即移动
    self._initialPosition = entity:GetPosition()
    local moveData = clone(BuffEventFearMoveData)
    moveData.TurnTime = self._turnTime
    moveData.Radius = self._radius
    moveData.NextMoveTime = self._nextMoveTime
    moveData.InitialPosition = self._initialPosition
    if not self._moveDatas[insId] then
        self._moveDatas[insId] = {}
    end
    self._moveDatas[insId][doBuffData.BuffId] = moveData
end

function BuffEventFear:OnRemove(buff)
    local doBuffData = buff:GetDoBuffData()
    local insId = doBuffData.EntityId
    local buffId = doBuffData.BuffId
    if self._moveDatas[insId] and self._moveDatas[insId][buffId] then
        self._moveDatas[insId][buffId] = nil
    end
end

--- 更新Buff时的处理函数
---@param delta number 时间增量
---@param buff NewBuff 需要更新的Buff对象
function BuffEventFear:OnUpdate(delta,buff)
    local doBuffData = buff:GetDoBuffData()
    local insId = doBuffData.EntityId
    local buffId = doBuffData.BuffId
    local entity = GetEntityByInsId(insId)
    if not entity then
        return
    end

    local moveData = self._moveDatas[insId][buffId]
    if not moveData then
        return
    end

    -- 恐惧状态下，每帧强制保持移动能力
    -- 因为CheckEntityMove会返回false导致系统禁用移动能力
    -- 但恐惧需要单位能执行"被动移动"（由Buff驱动）
    local dotaEntity = entity.__DotaEntity
    if IsValidEntity(dotaEntity) then
        dotaEntity:SetMoveCapability(DOTA_UNIT_CAP_MOVE_GROUND)
    end

    -- 当达到下一次移动时间时，计算随机移动方向和位置
    if moveData.NextMoveTime <= 0 then
        local radius = moveData.Radius
        local initialPosition = moveData.InitialPosition
        local currentPosition = entity:GetPosition()
        
        -- 生成随机角度和移动向量
        local randomAngle = RandomFloat(0, 360)
        local randomVector = Vector(math.cos(math.rad(randomAngle)), math.sin(math.rad(randomAngle)), 0)
        -- 计算新位置，在半径的一半到全部范围内随机
        local randomDistance = RandomFloat(radius * 0.5, radius)
        local newPosistion = initialPosition + randomVector * randomDistance

        -- 限制单位移动范围，确保不超出指定半径
---@diagnostic disable-next-line: undefined-field
        local distanceToInitial = (newPosistion - initialPosition):Length2D()
        if distanceToInitial > radius then
---@diagnostic disable-next-line: undefined-field
            newPosistion = initialPosition + (newPosistion - initialPosition):Normalized() * radius
        end
        
        -- 发出移动指令（移动能力已在OnUpdate开头确保可用）
---@diagnostic disable-next-line: invisible
        dotaEntity:MoveToPosition(newPosistion)
        
        -- 重置下一次移动时间
        moveData.NextMoveTime = moveData.TurnTime
    end
    
    -- 更新下一次移动的时间
    moveData.NextMoveTime = moveData.NextMoveTime - delta
end