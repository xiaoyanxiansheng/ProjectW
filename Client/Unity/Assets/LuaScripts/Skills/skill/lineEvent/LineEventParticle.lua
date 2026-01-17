--[[ 
特效事件模块
负责管理技能释放过程中的特效事件序列
包括特效的播放、停止、位置和方向控制
提供特效事件的注册、更新和执行功能
支持不同类型的特效和控制参数
作为技能时间线系统的组成部分，处理技能释放过程中的特效效果
--]]

---@class LineEventParticle : SkillLineEvent
LineEventParticle = Classnew("LineEventParticle" , SkillLineEvent)

function LineEventParticle:ctor(skill,eventType , config,timeLineIndex)
    SkillLineEvent.ctor(self,skill,eventType, config,timeLineIndex)

    self._particlePath = self._config[3]
    self._duration = tonumber(self._config[4])
    self._settlementId = 0
    self._timeLineIndex = 0
    local p = tonumber(self._config[5])
    if p > 1000 then
        ---@type integer
---@diagnostic disable-next-line: assign-type-mismatch
        self._settlementId = p
    else
        ---@type integer
---@diagnostic disable-next-line: assign-type-mismatch
        self._timeLineIndex = p
    end
    self._forward = tonumber(self._config[6])
        ---@type table
    local ps = string.split_lite(tostring(self._config[7]),"_")
    self._targetFollow = tonumber(ps[1])
    self._targetFollowP1 = ps[2] and tonumber(ps[2]) or 0
    self._targetOffsetZ = self._config[8] and tonumber(self._config[8]) or 0
    ---@type number[]
    local targetOffsetFrontRight = string.split_lite(tostring(self._config[9]),"_")
    self._targetOffsetFront = tonumber(targetOffsetFrontRight[1])
    self._targetOffsetRight = targetOffsetFrontRight[2] and tonumber(targetOffsetFrontRight[2]) or 0
    ---@type integer
---@diagnostic disable-next-line: assign-type-mismatch
    self._targetCP = self._config[10] and tonumber(self._config[10]) or -1
    ---@type integer
---@diagnostic disable-next-line: assign-type-mismatch
    self._radiusCP = self._config[11] and tonumber(self._config[11]) or -1
    ---@type integer
---@diagnostic disable-next-line: assign-type-mismatch
    self._forwordCP = self._config[12] and tonumber(self._config[12]) or -1
    ---@type number[]
    local speedParams = string.split_lite(tostring(self._config[13]),"_")
    ---@type integer
---@diagnostic disable-next-line: assign-type-mismatch
    self._speedCP = tonumber(speedParams[1]) or -1
    self._speedCPParam = Vector(speedParams[2] and tonumber(speedParams[2]) or 0 , 0 , 0)
    self._startFollow = self._config[14] and tonumber(self._config[14]) or 0
    self._startFollowP1 = 0
    self._startOffsetZ = self._config[15] and tonumber(self._config[15]) or 0
    self._startOffsetFront = 0.0
    self._startOffsetRight = 0.0
    if self._config[16] then
        ---@type number[]
        local startOffsetFrontRight = string.split_lite(tostring(self._config[16]),"_")
        self._startOffsetFront = tonumber(startOffsetFrontRight[1])
        self._startOffsetRight = startOffsetFrontRight[2] and tonumber(startOffsetFrontRight[2]) or 0
    end
    ---@type integer
---@diagnostic disable-next-line: assign-type-mismatch
    self._startCP = self._config[17] and tonumber(self._config[17]) or -1
    
    self._rotationFollow = 0.0
    self._rotationSpeed = 0.0
    if self._config[18] then
        ---@type number[]
        local rotationParams = string.split_lite(tostring(self._config[18]),"_")
        self._rotationFollow = tonumber(rotationParams[1])
        self._rotationSpeed = tonumber(rotationParams[2]) * 10
    end

    self._particleIns = 0

    self._passTime = 0
end

-- 子类继承 TimeLine 启动的时候会统一调用
function LineEventParticle:OnReset()
    self:StopParticle()
end

-- 子类继承 LineEvent时间触发
function LineEventParticle:OnInvoke()
    self._passTime = 0
    if self._duration == 0 then
---@diagnostic disable-next-line: assign-type-mismatch
        self._duration = self:GetSkill():GetDuration()
    end

    local position1 = self:GetStartPosition()
    self._activeStartPosition = Vector(position1.x,position1.y,position1.z)
    local position2 = self:GetTargetPosition()
    self._activeTargetPosition = Vector(position2.x,position2.y,position2.z)

    self:PlayParticle()
end

-- 子类继承 处理多段LineEvent
function LineEventParticle:OnUpdate(delta)
    if self._particleIns == 0 then
        return
    end

    local isUpdatePosition = false
    if self._startFollow == SettlementFlollowType.DynCaster
        or self._startFollow == SettlementFlollowType.DynTarget
        or self._startFollow == SettlementFlollowType.DynAgent then
        local position1 = self:GetStartPosition()
        isUpdatePosition = true
        self._activeStartPosition = Vector(position1.x,position1.y,position1.z)
    end
    if self._targetFollow == SettlementFlollowType.DynCaster
        or self._targetFollow == SettlementFlollowType.DynTarget
        or self._targetFollow == SettlementFlollowType.DynAgent then
        isUpdatePosition = true
        local position2 = self:GetTargetPosition()
        self._activeTargetPosition = Vector(position2.x,position2.y,position2.z)
    end

    -- isUpdatePosition = self:UpdateRotation(delta)

    if isUpdatePosition then
        self:UpdatePosition()
    end

    self:UpdateRadius()

    if self._passTime > self._duration then
        self:StopParticle()
    end
    self._passTime = self._passTime + delta
end

function LineEventParticle:PlayParticle()
    if self._particleIns == 0 then
        self._particleIns = ParticleManager:CreateParticle(self._particlePath, PATTACH_WORLDORIGIN, nil)
    end

    -- 同步结算范围
    self:UpdateRadius()
    -- 同步位置
    self:UpdatePosition()
    -- 同步方向
    self:UpdateForward()
    -- 同步速度
    self:UpdateSpeed()
end

function LineEventParticle:UpdatePosition()
    if self._particleIns == 0 then
        return
    end

    -- print("====UpdatePosition3",self._activeTargetPosition)

    if self._targetCP ~= -1 then
        ParticleManager:SetParticleControl(self._particleIns, self._targetCP, self._activeTargetPosition)
    end
    if self._startFollow ~= 0 and self._startCP ~= -1 then
        ParticleManager:SetParticleControl(self._particleIns, self._startCP, self._activeStartPosition)
    end
end

function LineEventParticle:UpdateForward()
    if self._forwordCP ~= -1 then
        local direction = self:GetForward(self._forward)
---@diagnostic disable-next-line: undefined-field
        local yaw = math.deg(math.atan2(direction.y, direction.x))
        if yaw < 0 then yaw = yaw + 360 end
        yaw = 360 - yaw
        local rotation = QAngle(0, yaw, 0)
        local targetPosition = self:GetTargetPosition()
        ParticleManager:SetParticleControlTransform(self._particleIns, self._forwordCP, targetPosition , rotation)
    end
end

function LineEventParticle:UpdateSpeed()
    if self._speedCP == -1 then
        return
    end

    local speed = self._speedCPParam
    if speed.x == 0 then
        local startPosition = self:GetStartPosition()
        local targetPosition = self:GetTargetPosition()
        ---@type Vector
---@diagnostic disable-next-line: assign-type-mismatch
        local distance = (startPosition - targetPosition) / self._duration
        speed = Vector(distance.x, distance.y, distance.z)
    end

    ParticleManager:SetParticleControl(self._particleIns, self._speedCP, speed)
end

function LineEventParticle:UpdateRadius()
    if self._radiusCP ~= -1 and (self._settlementId > 0 or self._timeLineIndex > 0) then
        ---@type any
        local rangeParamLerp = {}

        local rangeParam = nil
        local rangeParamMax = nil

        if self._settlementId > 0 then
            rangeParam = GetSettlementLine(self._settlementId).RangeParam
            rangeParamMax = GetSettlementLine(self._settlementId).RangeParamMax
        elseif self._timeLineIndex > 0 then
            local settlementTableLine = self:GetSkill():GetSettlementTableLine(self._timeLineIndex)
            rangeParam = settlementTableLine and settlementTableLine.RangeParam or nil
            rangeParamMax = settlementTableLine and settlementTableLine.RangeParamMax or nil
        end
        
        if rangeParam == nil then
            error("特效配置的结算TimeLineIndex配置错误！！！")
            return
        end

        if rangeParamMax and self._duration > 0 then
            table.Lerp(rangeParamLerp,rangeParam,rangeParamMax,self._passTime / self._duration)
        else
            rangeParamLerp = rangeParam
        end
        local radius = 0
        if rangeParamLerp then
---@diagnostic disable-next-line: need-check-nil
            radius = rangeParamLerp[1]
        end
        ParticleManager:SetParticleControl(self._particleIns,self._radiusCP,Vector(radius,radius,radius))
    end
end

function LineEventParticle:StopParticle()
    if self._particleIns == 0 then
        return
    end

    ParticleManager:DestroyParticle(self._particleIns, false)
    ParticleManager:ReleaseParticleIndex(self._particleIns)
    self._particleIns = 0
end

function LineEventParticle:OnClear()
    self:StopParticle()
end

function LineEventParticle:GetStartPosition()
    local startPosition = SkillLineEvent.GetTargetPosition(self,self._startFollow,self._startFollowP1)
    local position = Vector(startPosition.x,startPosition.y,startPosition.z)
    if self._startOffsetZ ~= 0 then
        position.z = position.z + self._startOffsetZ
    end
    if self._startOffsetFront ~= 0 or self._startOffsetRight ~= 0 then
        local targetPosition = SkillLineEvent.GetTargetPosition(self,self._targetFollow,self._targetFollowP1)
---@diagnostic disable-next-line: undefined-field
        local forward = (targetPosition - startPosition):Normalized()
        if self._startOffsetFront ~= 0 then
            position = position + forward * self._startOffsetFront
        end
        if self._startOffsetRight ~= 0 then
            local upVec = Vector(0, 0, 1)
            local right = forward:Cross(upVec):Normalized()
            position = position + right * self._startOffsetRight
        end
    end
    return position
end

function LineEventParticle:GetTargetPosition()
    local targetPosition = SkillLineEvent.GetTargetPosition(self,self._targetFollow,self._targetFollowP1)
    local position = Vector(targetPosition.x,targetPosition.y,targetPosition.z)
    if self._targetOffsetZ ~= 0 then
        position.z = position.z + self._targetOffsetZ
    end
    if self._targetOffsetFront ~= 0 or self._targetOffsetRight ~= 0 then
        local startPosition = SkillLineEvent.GetTargetPosition(self,self._startFollow,self._startFollowP1)
        local forward = (position - startPosition):Normalized()
        if self._targetOffsetFront ~= 0 then
            if self._targetFollow == SettlementFlollowType.Caster or self._targetFollow == SettlementFlollowType.DynCaster then
                forward = self:GetForward(SettlementForwardType.CasterForward)
            end
            position = position + forward * self._targetOffsetFront
        end
        if self._targetOffsetRight ~= 0 then
            local upVec = Vector(0, 0, 1)
            local right = forward:Cross(upVec):Normalized()
            position = position + right * self._targetOffsetRight
        end
    end

    return position
end

function LineEventParticle:UpdateRotation(delta)
    if self._rotationFollow ~= 0 then
        local position = self._activeTargetPosition
        -- print("====UpdateRotation1",position)
        local angle = self._rotationSpeed * delta
        local rotationPoint = SkillLineEvent.GetTargetPosition(self,self._rotationFollow,0)
        
        -- Convert angle to radians
        local angleRad = math.rad(angle)
        
        -- Calculate rotated position using rotation matrix components
        local cosA = math.cos(angleRad)
        local sinA = math.sin(angleRad)
        
        -- Get the vector from rotation point to position
        local toPosition = position - rotationPoint
        
        -- Apply rotation in XY plane only
---@diagnostic disable-next-line: undefined-field
        local rotatedX = toPosition.x * cosA - toPosition.y * sinA
---@diagnostic disable-next-line: undefined-field
        local rotatedY = toPosition.x * sinA + toPosition.y * cosA
        
        -- Create new rotated position (keep Z unchanged)
---@diagnostic disable-next-line: undefined-field
        self._activeTargetPosition = Vector(rotatedX, rotatedY, toPosition.z) + rotationPoint
        -- print("====UpdateRotation2",self._activeTargetPosition,angle)
        -- self:UpdatePosition()
        return true
    end
    return false
end