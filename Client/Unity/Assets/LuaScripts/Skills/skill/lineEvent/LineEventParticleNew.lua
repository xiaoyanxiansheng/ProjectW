---@class LineEventParticleNew : SkillLineEvent
LineEventParticleNew = Classnew("LineEventParticleNew" , SkillLineEvent)

function LineEventParticleNew:ctor(skill,eventType , config,timeLineIndex)
    SkillLineEvent.ctor(self,skill,eventType, config,timeLineIndex)

    --@type number
    local durationParams = string.split_lite(tostring(self._config[3]), "_")
    self._duration = tonumber(durationParams[1])
    self._immediateDelete = (durationParams[2] and tonumber(durationParams[2]) or 0) == 1
    self._followCaster = (durationParams[3] and tonumber(durationParams[3]) or 0) == 1

    self._particlePath = self._config[4]

    local targetParamss = string.split_lite(tostring(self._config[5]), "_")
    self._targetCP = tonumber(targetParamss[1])
    self._targetOffsetZ = targetParamss[2] and tonumber(targetParamss[2]) or 0
    self._targetOffsetX = targetParamss[3] and tonumber(targetParamss[3]) or 0
    self._isFixHeight = targetParamss[4] and tonumber(targetParamss[4]) or 1
    ---@type integer
---@diagnostic disable-next-line: assign-type-mismatch
    self._radiusCP = self._config[6] and tonumber(self._config[6]) or -1
    ---@type integer
---@diagnostic disable-next-line: assign-type-mismatch
    self._forwordCP = self._config[7] and tonumber(self._config[7]) or -1
    ---@type integer
---@diagnostic disable-next-line: assign-type-mismatch
    self._speedCP = self._config[8] and tonumber(self._config[8]) or -1
    local startParams = self._config[9] and string.split_lite(tostring(self._config[9]), "_") or {}
    self._startCP = startParams[1] and tonumber(startParams[1]) or -1
    self._startOffsetZ = startParams[2] and tonumber(startParams[2]) or 0
    self._startOffsetX = startParams[3] and tonumber(startParams[3]) or 0

    self._particleIns = 0
    self._passTime = 0.0
    self._isFinish = false
end

-- 子类继承 LineEvent时间触发
function LineEventParticleNew:OnInvoke()
    self._passTime = 0
    if self._duration <= 0.00001 then
        self._duration = self:GetNewDuration()
    end

    if self._followCaster then
        local entity = GetEntityByInsId(self:GetDoSkillData().CasterInsId)
        self._particleIns = ParticleManager:CreateParticle(self._particlePath, PATTACH_POINT_FOLLOW, entity.__DotaEntity)
    else
        self._particleIns = ParticleManager:CreateParticle(self._particlePath, PATTACH_WORLDORIGIN, nil)
    end
end

-- 子类继承 处理多段LineEvent
function LineEventParticleNew:OnUpdate(delta)
    if self._isFinish then
        return
    end

    if self._passTime > self._duration then
        self._isFinish = true
        self:StopParticle()
        return
    end
    self._passTime = self._passTime + delta

    -- -- 同步结算范围
    self:UpdateRadius()
    -- -- 同步位置
    self:UpdatePosition()
    -- -- -- 同步方向
    self:UpdateForward()
    -- -- -- 同步速度
    self:UpdateSpeed()
end

function LineEventParticleNew:UpdatePosition()
    if self._targetCP ~= -1 then
        local position = self:GetNewPosition()
        local forward = self:GetNewForward()
        position = position + forward * self._targetOffsetX
        local newPosition = position
        if self._isFixHeight == 1 then
            newPosition = GetPositionFixHeight(newPosition , self._targetOffsetZ)
        else
            newPosition = Vector(newPosition.x,newPosition.y,newPosition.z + self._targetOffsetZ)
        end

        ParticleManager:SetParticleControl(self._particleIns, self._targetCP, newPosition)
    end
    if self._startCP ~= -1 then
        local startPosition = self:GetNewStartPosition()
        local forward = self:GetNewForward()
        startPosition = startPosition + forward * self._startOffsetX
        local newStartPosition = startPosition
        if self._isFixHeight == 1 then
            newStartPosition = GetPositionFixHeight(newStartPosition , self._startOffsetZ)
        else
            newStartPosition = Vector(newStartPosition.x,newStartPosition.y,newStartPosition.z + self._startOffsetZ)
        end
        ParticleManager:SetParticleControl(self._particleIns, self._startCP, newStartPosition)
    end
end

function LineEventParticleNew:UpdateForward()
    if self._forwordCP ~= -1 then
        local position = self:GetNewPosition()
        local forward = self:GetNewForward()
        local yaw = math.deg(math.atan2(forward.y, forward.x))
        if yaw < 0 then yaw = yaw + 360 end
        local rotation = QAngle(0, -yaw, 0)
        ParticleManager:SetParticleControlTransform(self._particleIns, self._forwordCP, position , rotation)
    end
end

function LineEventParticleNew:UpdateSpeed()
    if self._speedCP ~= -1 then
        local speed = self:GetNewMoveSpeed()
        ParticleManager:SetParticleControl(self._particleIns, self._speedCP, Vector(speed,speed,speed))
    end
end

function LineEventParticleNew:UpdateRadius()
    if self._radiusCP ~= -1 then
        local rangeParam = self:GetNewRangeParams()
        local radius = rangeParam.y
        ParticleManager:SetParticleControl(self._particleIns,self._radiusCP,Vector(radius,radius,radius))
    end
end

function LineEventParticleNew:StopParticle()
    if self._particleIns == 0 then
        return
    end

    ParticleManager:DestroyParticle(self._particleIns, self._immediateDelete)
    ParticleManager:ReleaseParticleIndex(self._particleIns)
    self._particleIns = 0
end

function LineEventParticleNew:MoveToTargetPositionCallBack()
    self:StopParticle()
end

function LineEventParticleNew:OnClear()
    self:StopParticle()
    self._particleIns = 0
end