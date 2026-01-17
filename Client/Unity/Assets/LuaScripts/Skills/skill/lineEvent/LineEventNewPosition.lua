---@class LineEventNewPosition : SkillLineEvent
LineEventNewPosition = Classnew("LineEventNewPosition" , SkillLineEvent)

function LineEventNewPosition:ctor(skill,eventType , config,timeLineIndex)
    SkillLineEvent.ctor(self,skill,eventType, config,timeLineIndex)

    -- 配置定义: 持续时间_目标位置定义_向前移动距离_前后偏移_左右偏移|范围定义_范围参数1_范围参数2_起始范围参数1_起始范围参数2|起始位置定义_速度_1达到目的是否结束技能2/达到目的地通知_前后偏移_左右偏移|旋转位置定义_速度_半径增大速度/s

    local skillLevel = self:GetSkill():GetDoSkillData().SkillLevel

    ---@type number
---@diagnostic disable-next-line: assign-type-mismatch
    self._duration = tonumber(self._config[3])
    -- 目标位置定义
    local ps = string.split_lite(tostring(self._config[4]),"_")
    ---@type integer
---@diagnostic disable-next-line: assign-type-mismatch
    self._targetPositionType = tonumber(ps[1])
    self._targetPositionForwardOffset = 0
    self._targetPositionRightOffset = 0
    if #ps >= 2 then
        local offsetPs = string.split_lite(tostring(ps[2]),"/")
        self._targetPositionForwardOffset = tonumber(GetConfDataLevel(offsetPs,skillLevel))
    end
    if #ps >= 3 then
        local offsetPs = string.split_lite(tostring(ps[3]),"/")
        self._targetPositionRightOffset = tonumber(GetConfDataLevel(offsetPs,skillLevel))
    end

    -- 范围定义: 0单体 1扇形_半径_角度 2扇形_宽度_长度
    self._rangeType = 0
    self._rangeValue = Vector(0,0,0)
    self._rangeValueStart = nil -- 如果不为空则说明是变换范围
    if self._config[5] then
        local ps = string.split_lite(tostring(self._config[5]),"_")
        self._rangeType = tonumber(ps[1])
        if #ps > 1 then
            local ps2 = string.split_lite(tostring(ps[2]),"/")
            self._rangeValue.x = tonumber(GetConfDataLevel(ps2,skillLevel))
            local ps3 = string.split_lite(tostring(ps[3]),"/")
            self._rangeValue.y = tonumber(GetConfDataLevel(ps3,skillLevel))
        end
        if #ps > 3 then
            local rangePs = string.split_lite(tostring(ps[4]),"/")
            local rangeValue = tonumber(GetConfDataLevel(rangePs,skillLevel))
            self._rangeValueStart = Vector(rangeValue,tonumber(ps[5]),0)
        end
    end

    -- 起始位置定义
    self._startPositionType = nil
    self._moveSpeed = 0
    self._startPositionForwardOffset = 0.0
    self._startPositionRightOffset = 0.0
    self._isMoveFinishEndSkill = 0
    if self._config[6] then
        local ps = string.split_lite(tostring(self._config[6]),"_")
        self._startPositionType = tonumber(ps[1])
        self._moveSpeed = #ps >= 2 and tonumber(ps[2]) or 0
        self._isMoveFinishEndSkill = #ps >= 3 and tonumber(ps[3]) or 0
        self._startPositionForwardOffset = #ps >= 4 and tonumber(ps[4]) or 0
        self._startPositionRightOffset = #ps >= 5 and tonumber(ps[5]) or 0
    end

    -- 旋转位置定义
    self._rotationPositionType = nil
    self._rotationSpeed = 0
    self._rotationRadiusSpeed = 0
    self._rotationMaxRadius = 0
    if self._config[7] then
        local ps = string.split_lite(tostring(self._config[7]),"_")
        if #ps > 1 then
            self._rotationPositionType = tonumber(ps[1])
            local speedPs = string.split_lite(tostring(ps[2]),"/")
            self._rotationSpeed = tonumber(GetConfDataLevel(speedPs,skillLevel))
            if ps[3] ~= nil then
                local radiusSpeedPs = string.split_lite(tostring(ps[3]),"/")
                self._rotationRadiusSpeed = tonumber(GetConfDataLevel(radiusSpeedPs,skillLevel))
            end
            if ps[4] ~= nil then
                local maxRadiusPs = string.split_lite(tostring(ps[4]),"/")
                self._rotationMaxRadius = tonumber(GetConfDataLevel(maxRadiusPs,skillLevel))
            end
        end
    end
    
    -- 添加一个初始的相对位置变量
    self._initialRelativePosition = nil
end

function LineEventNewPosition:OnInvoke()
    if self._duration <= 0.00001 then
        self._duration = self:GetSkill():GetDuration()
    end

    self._passTime = 0.0
    ---@type Vector
    self._position = Vector(0,0,0)
    ---@type Vector
    self._startPosition = Vector(0,0,0)
    ---@type Vector
    self._targetPosition = Vector(0,0,0)
    ---@type Vector
    self._defaultForward = Vector(0,0,1)
    ---@type Vector
    self._forward = Vector(0,0,1)
    --- 类型 参数1 参数2
    self._rangeParams = Vector(self._rangeType,0,0)

    self._defaultTargetPosition = self:GetTypePosition(self._targetPositionType)
    self._defaultStartPosition = self:GetTypePosition(self._startPositionType or SettlementFlollowType.StartPosition)
    self._defaultForward = self:CalForward(self._defaultTargetPosition,self._defaultStartPosition)
    self:CalculateDefault(0)
    self:CalculateRadius()
    if self._startPositionType ~= nil and self._moveSpeed > 0 then
        self._position = self._startPosition
    else
        self._position = self._targetPosition
    end
end

function LineEventNewPosition:OnUpdate(delta)
    if self._passTime > self._duration then
        -- 当前时间线结束
        return
    end

    self._passTime = self._passTime + delta

    self:CalculateDefault(delta)
    self:UpdatePosition(delta)
    self:CalculateRadius()
end

--- 1 定点
--- 2 起点到终点
--- 3 起点到终点链接
function LineEventNewPosition:CalculateDefault(delta)
    local updateStart = self._startPositionType == SettlementFlollowType.DynCaster
        or self._startPositionType == SettlementFlollowType.DynTarget
        or self._startPositionType == SettlementFlollowType.DynPosition
    local updateTarget = self._targetPositionType == SettlementFlollowType.DynCaster
        or self._targetPositionType == SettlementFlollowType.DynTarget
        or self._targetPositionType == SettlementFlollowType.DynPosition
    local updateRotation = self._rotationPositionType ~= nil and self._rotationSpeed > 0
    
    if updateStart then
        local startPosition = self:GetTypePosition(self._startPositionType or SettlementFlollowType.StartPosition)
        self._startPosition = startPosition
    else
        self._startPosition = self._defaultStartPosition
    end
    if updateTarget then
        local targetPosition = self:GetTypePosition(self._targetPositionType)
        self._targetPosition = targetPosition
    else
        self._targetPosition = self._defaultTargetPosition
    end
    local forward = nil
    if updateStart or updateTarget or updateRotation then
       forward = self:CalForward(self._targetPosition,self._startPosition)
    else
        forward = self._defaultForward
    end
    self._startPosition = self:GetTypePostitionOffset(self._startPosition , forward , self._startPositionForwardOffset , self._startPositionRightOffset)
    self._targetPosition = self:GetTypePostitionOffset(self._targetPosition , forward , self._targetPositionForwardOffset , self._targetPositionRightOffset)
    if updateRotation then
        if self._rotationPositionType ~= nil then
            local rotatePosition = self:GetTypePosition(self._rotationPositionType)
            self._targetPosition = self:GetRotatePosition(self._targetPosition , rotatePosition , delta)
        end
    end

    if updateStart or updateTarget or updateRotation then
        local startPosition = self._startPosition
        if updateRotation then
            startPosition = self:GetTypePosition(self._rotationPositionType)
        end
        self._forward = self:CalForward(self._targetPosition,startPosition)
    else
        self._forward = self._defaultForward
    end
end

function LineEventNewPosition:GetRotatePosition(position , rotationPoint , delta)
    -- 第一次调用时保存初始相对位置
    if self._initialRelativePosition == nil then
        local direction = position - rotationPoint
        self._initialRelativePosition = direction
        self._initialRelativeDirection = direction:Normalized()
    end
    self._initialRelativePosition = self._initialRelativePosition + self._initialRelativeDirection * delta * self._rotationRadiusSpeed;
    if self._rotationMaxRadius > 0 then
        self._initialRelativePosition = math.min(self._initialRelativePosition:Length(), self._rotationMaxRadius) * self._initialRelativeDirection
    end
    
    local angle = self._passTime * self._rotationSpeed
    local angleRad = math.rad(angle)
    local cosA = math.cos(angleRad)
    local sinA = math.sin(angleRad)
    
    -- 使用初始的相对位置进行旋转计算（顺时针旋转：交换sin的符号）
    local rotatedX = self._initialRelativePosition.x * cosA + self._initialRelativePosition.y * sinA
    local rotatedY = -self._initialRelativePosition.x * sinA + self._initialRelativePosition.y * cosA
    
    -- 将旋转后的相对位置加上当前的旋转点以获得新的绝对位置
    local newPosition = Vector(rotatedX, rotatedY, self._initialRelativePosition.z) + rotationPoint
    return newPosition
end

function LineEventNewPosition:UpdatePosition(delta)
    if self._startPositionType == nil or self._moveSpeed == 0 then
        self._position = self._targetPosition
        return
    end

    local toTarget = self._targetPosition - self._position
    local distanceToTarget = toTarget:Length()
    local moveDistance = self._moveSpeed * delta

    -- 如果移动距离大于或等于到目标的距离，直接到达目标位置
    if moveDistance >= distanceToTarget then
        self._position = self._targetPosition
        -- 已经到达目的地 结束技能
        if self._isMoveFinishEndSkill == 1 then
            SkillManagerInstance:DoFinishSkill(self:GetSkill(), true)
        elseif self._isMoveFinishEndSkill == 2 then
            self:GetSkillTimeLine():MoveToTargetPositionCallBack()
        end
    else
        -- 否则按照速度向目标位置移动
        local moveDirection = toTarget:Normalized()
        ---@diagnostic disable-next-line: assign-type-mismatch
        self._position = self._position + moveDirection * moveDistance
    end
end

function LineEventNewPosition:CalculateRadius()
    self._rangeParams.x = self._rangeType

    if self._rangeType == 0 then
        return
    end

    if self._rangeValueStart == nil then
        self._rangeParams.y = self._rangeValue.x
        self._rangeParams.z = self._rangeValue.y
    else
        local value = self._rangeValueStart:Lerp(self._rangeValue,self._passTime / self._duration)
        self._rangeParams.y = value.x
        self._rangeParams.z = value.y
    end
end

function LineEventNewPosition:OnSetTarget(targetInsId)
    self._targetPositionType = SettlementFlollowType.DynTarget
end

function LineEventNewPosition:GetRangeParams()
    return self._rangeParams
end

function LineEventNewPosition:GetPosition()
    return self._position
end

function LineEventNewPosition:GetTargetPosition2()
    return self._targetPosition
end

function LineEventNewPosition:GetStartPosition2()
    return self._startPosition
end

function LineEventNewPosition:GetForward2()
    return self._forward
end

function LineEventNewPosition:GetMoveSpeed()
    return self._moveSpeed
end

function LineEventNewPosition:GetDuration()
    return self._duration
end

function LineEventNewPosition:GetTargetPositionType()
    return self._targetPositionType
end