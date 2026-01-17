--[[ 
子弹事件模块
负责管理技能释放过程中的子弹事件序列
包括子弹的生成、发射和控制
提供事件注册、更新和执行功能
支持不同类型的子弹范围和分布方式
作为技能时间线系统的组成部分，处理技能释放过程中的子弹效果
--]]

---@class LineEventBullet : SkillLineEvent
LineEventBullet = Classnew("LineEventBullet" , SkillLineEvent)

function LineEventBullet:ctor(skill,eventType , config,timeLineIndex)
    SkillLineEvent.ctor(self,skill,eventType, config,timeLineIndex)

    ---@type integer
---@diagnostic disable-next-line: assign-type-mismatch
    self._spawnId =  tonumber(self._config[3])
    ---@type table
    local ps = string.split_lite(tostring(self._config[4]),"_")
    self._followType = tonumber(ps[1])
    self._followTypeP1 = ps[2] and tonumber(ps[2]) or 0 -- 用法不太一样，子弹的用法是起点
    local speedPs = string.split_lite(tostring(self._config[5]),"_")
    local speedParams = string.split_lite(tostring(speedPs[1]),"/")
    self._bulletSpeed = tonumber(GetConfDataLevel(speedParams, self:GetDoSkillData().SkillLevel))
    self._isBulletSpeedFinishEndSkill = #speedPs>=2 and tonumber(speedPs[2]) or 0
    ---@type integer
---@diagnostic disable-next-line: assign-type-mismatch
    self._bulletHitSkillId = tonumber(self._config[6])
    ---@type integer
---@diagnostic disable-next-line: assign-type-mismatch
    self._bulletFinishSkillId = tonumber(self._config[7])
    ---@type number[]
    local bulletProcessSkillParams = self._config[8] and string.split_lite(self._config[8],"_") or nil

    self._rotationFollow = 0
    self._rotationSpeed = 0.0
    if self._config[9] and self._config[9] ~= 0 then
        ---@type number[]
        local rotationParams = string.split_lite(tostring(self._config[9]),"_")
---@diagnostic disable-next-line: assign-type-mismatch
        self._rotationFollow = tonumber(rotationParams[1])
        self._rotationSpeed = tonumber(rotationParams[2])
    end

    self._bulletProcessSkillId = 0
    self._bulletProcessSkillInterval = 0.0
    self._bulletProcessSkillPassTime = 0.0
    if bulletProcessSkillParams then
---@diagnostic disable-next-line: assign-type-mismatch
        self._bulletProcessSkillId = tonumber(bulletProcessSkillParams[1])
---@diagnostic disable-next-line: assign-type-mismatch
        self._bulletProcessSkillInterval = tonumber(bulletProcessSkillParams[2])
    end

    self._passTime = 0

    self._bulletFinish = false
    self._bulletInsId = 0

    self._bulletRotation = 0.0
    self._bulletSpeedDelta = 0.0
    self._startPosition = Vector(0,0,0)
    self._activeRotationPoint = Vector(0,0,0)
    self._activeTargetPosition = Vector(0,0,0)
end

-- 子类继承 TimeLine 启动的时候会统一调用
function LineEventBullet:OnReset()

end

-- 子类继承 LineEvent时间触发
function LineEventBullet:OnInvoke()
    local doSkillData = self:GetDoSkillData()

    local caster = GetEntityByInsId(doSkillData.CasterInsId)
    if not caster then
        return
    end

    self._startPosition = self:GetStartPosition(self._bulletSpeed == 0 and self._followTypeP1 or 0)
    local bullets = Units:SpawnSpecial(self._spawnId,1,self._startPosition)
    for insId, _ in pairs(bullets) do
        self._bulletInsId = insId
    end

    self._activeRotationPoint = self:GetTargetPosition(self._rotationFollow,0)
    self._activeTargetPosition = self:GetTargetPosition(self._followType,self._followTypeP1)

    self:SetAgent(self._bulletInsId , self._bulletSpeed)
end

-- 子类继承 处理多段LineEvent
function LineEventBullet:OnUpdate(delta)
    if self._bulletFinish then
        return
    end

    if self._bulletInsId == nil 
        or self._bulletInsId == 0 then
        return
    end

    local bullet = GetEntityByInsId(self._bulletInsId)
    if not bullet then
        return
    end

    if self._rotationFollow == SettlementFlollowType.DynCaster
        or self._rotationFollow == SettlementFlollowType.DynTarget
        or self._rotationFollow == SettlementFlollowType.DynAgent then
        self._activeRotationPoint = self:GetTargetPosition(self._rotationFollow,0)
    end

    if self._followType == SettlementFlollowType.DynCaster
        or self._followType == SettlementFlollowType.DynTarget
        or self._followType == SettlementFlollowType.DynAgent then
        self._activeTargetPosition = self:GetTargetPosition(self._followType,self._followTypeP1)
    end

    -- 计算目标方向
    local doSkillData = self:GetDoSkillData()
    ---@type Vector
    local bulletPosition = bullet:GetPosition()
    -- 一直更新旋转目标
    local targetPosition = self:UpdateRotation(delta,self._activeTargetPosition)
---@diagnostic disable-next-line: undefined-field
    local direciton = (targetPosition - self._startPosition):Normalized()
    local position = self._startPosition + direciton * self._bulletSpeedDelta
    self._bulletSpeedDelta = self._bulletSpeedDelta + self._bulletSpeed * delta
---@diagnostic disable-next-line: undefined-field
    local entityDirection = (position - bulletPosition):Normalized()
    
    -- 过程技能
    if self._bulletProcessSkillId > 0 then
        if self._bulletProcessSkillPassTime <= 0 then
            self._bulletProcessSkillPassTime = self._bulletProcessSkillInterval
            ---@type DoSkillData
            local newDoSKillData = clone(doSkillData)
            newDoSKillData.SkillId = self._bulletProcessSkillId
            newDoSKillData.StartPosition = bulletPosition
            newDoSKillData.TargetInsId = doSkillData.TargetInsId
            newDoSKillData.StartAgentId = self._bulletInsId
            newDoSKillData.AgentInsId = self._bulletInsId
            newDoSKillData.ParentSkill =  self:GetSkill()
            SkillManagerInstance:DoSkill(newDoSKillData)
        end
        self._bulletProcessSkillPassTime = self._bulletProcessSkillPassTime - delta
    end

    if self._bulletSpeed > 0 then
---@diagnostic disable-next-line: undefined-field
        local bulletMoveDistance = (bulletPosition - self._startPosition):Length2D()
---@diagnostic disable-next-line: undefined-field
        local startTargetDistance = (targetPosition - self._startPosition):Length2D()
        local distanceToTarget = math.abs(startTargetDistance - bulletMoveDistance)
        local speed = self._bulletSpeed * delta
    
        if distanceToTarget <= speed then
            self._bulletFinish = true
    
            -- 循环技能
            if (doSkillData.FinishLoopCount > 0) then
                ---@type DoSkillData
                local newDoSKillData = clone(doSkillData)
                newDoSKillData.StartPosition = bulletPosition
                newDoSKillData.StartAgentId = doSkillData.TargetInsId
                newDoSKillData.AgentInsId = self._bulletInsId
                SkillManagerInstance:DoSkill(newDoSKillData)
            end
    
            -- 结束技能
            if self._bulletFinishSkillId > 0 then
                ---@type DoSkillData
                local newDoSKillData = clone(doSkillData)
                newDoSKillData.SkillId = self._bulletFinishSkillId
                newDoSKillData.StartPosition = bulletPosition
                newDoSKillData.TargetInsId = doSkillData.TargetInsId
                newDoSKillData.StartAgentId = self._bulletInsId
                newDoSKillData.AgentInsId = self._bulletInsId
                newDoSKillData.ParentSkill =  self:GetSkill()
                SkillManagerInstance:DoSkill(newDoSKillData)
            end

            if self._isBulletSpeedFinishEndSkill == 1 then
                SkillManagerInstance:DoFinishSkill(self:GetSkill(),true)
            end
        else
            -- 更新位置
            SetEntityForwardVector(self._bulletInsId,entityDirection)
            bullet:SetPosition(position)
        end
    else
        -- 更新位置
        SetEntityForwardVector(self._bulletInsId,entityDirection)
        bullet:SetPosition(targetPosition)
    end
end

function LineEventBullet:OnSkillFinish()
    local bullet = GetEntityByInsId(self._bulletInsId)
    if not bullet then
        return
    end
    bullet:Remove()
    self._bulletInsId = 0
end

---@param targetId integer
function LineEventBullet:SettlementHitTarget(targetId)
    SkillLineEvent.SettlementHitTarget(self,targetId)

    local target = GetEntityByInsId(targetId)
    if not target then
        return
    end

    if self._bulletHitSkillId > 0 then
        ---@type DoSkillData
        local newDoSKillData = clone(self:GetDoSkillData())
        newDoSKillData.SkillId = self._bulletHitSkillId
        newDoSKillData.Position = target:GetPosition()
        newDoSKillData.StartPosition = target:GetPosition()
        newDoSKillData.StartAgentId = targetId
        newDoSKillData.AgentInsId = targetId
        newDoSKillData.ParentSkill =  self:GetSkill()
        SkillManagerInstance:DoSkill(newDoSKillData)
    end
end

function LineEventBullet:UpdateRotation(delta,position)
    if self._rotationFollow == 0 then
        return position
    end

    self._bulletRotation = self._bulletRotation + delta * self._rotationSpeed
    local angle = self._bulletRotation
    local rotationPoint = self._activeRotationPoint

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
    return Vector(rotatedX, rotatedY, toPosition.z) + rotationPoint
end

function LineEventBullet:GetSpeed()
    return self._bulletSpeed
end

