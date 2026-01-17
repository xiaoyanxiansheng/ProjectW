--[[ 
结算对象事件模块
负责管理技能释放过程中的结算对象事件
包括伤害计算、击中判定、效果应用等
提供结算事件的注册、更新和执行功能
支持不同类型的结算范围和判定方式
处理技能命中目标后的各种效果和状态变化
支持多种结算类型和伤害计算方式
作为技能时间线系统的核心组成部分，处理技能效果的最终应用
--]]


---@class LineEventSettlementObject : SkillLineEvent
LineEventSettlementObject = Classnew("LineEventSettlementObject" , SkillLineEvent)

DoSettlementData = Classnew("DoSettlementData", nil)

--- 构造函数，初始化Buff数据
function DoSettlementData:ctor(timeLineIndex)
    self.TimeLineIndex = timeLineIndex
end

---@param skillTimeLine SkillTimeLine
---@param eventType integer
---@param config table
function LineEventSettlementObject:ctor(skillTimeLine,eventType , config, timeLineIndex, settlementTableLine)
    SkillLineEvent.ctor(self,skillTimeLine,eventType, config, timeLineIndex)
    self._doSettlementData = DoSettlementData.New(timeLineIndex)
    self._settementId = tonumber(self._config[3])
    self._followType = SettlementFlollowType.Caster
    self._forwardType = SettlementForwardType.None
    self._followTypeP1 = 0.0
    if self._config[4] then
        ---@type table
        local ps = string.split_lite(tostring(self._config[4]),"_")
---@diagnostic disable-next-line: assign-type-mismatch
        self._followType = tonumber(ps[1])
---@diagnostic disable-next-line: assign-type-mismatch
        self._followTypeP1 = ps[2] and tonumber(ps[2]) or 0
    end
---@diagnostic disable-next-line: assign-type-mismatch
    if self._config[5] then self._forwardType = tonumber(self._config[5]) end
    self._offsetForward = 0.0
    self._offsetRight = 0.0
    if self._config[6] then
        ---@type integer[]
        local offsetForwardRight = string.split_lite(tostring(self._config[6]),"_")
---@diagnostic disable-next-line: assign-type-mismatch
        self._offsetForward = tonumber(offsetForwardRight[1])
---@diagnostic disable-next-line: assign-type-mismatch
        self._offsetRight = offsetForwardRight[2] and tonumber(offsetForwardRight[2]) or 0
    end
    self._damageType = self:GetSkill():GetSkillTableLine().DamageType
    if self._config[7] then
        ---@type integer
---@diagnostic disable-next-line: assign-type-mismatch
        local damageType = tonumber(self._config[7])
        self._damageType = damageType
    end

    self._settlementTableLine = settlementTableLine

    self:OldSkillHardCode()
end

-- 子类继承 LineEvent时间触发
function LineEventSettlementObject:OnInvoke()
    self._maxHitCount = self._settlementTableLine.MaxHitCount or 0
    self._duration = self._settlementTableLine.MaxLifeTime or 0
    self._passTime = 0.0
    self._hitIntervalTime = self._settlementTableLine.HitInterval or 0
    self._isActive = false
    self._activePosition = Vector(0,0,0)
    self._activeForward = Vector(0,0,0)
    self._hitOnce = self._settlementTableLine.HitOnce and self._settlementTableLine.HitOnce == 1
    self._hitInsIdList = nil

    local doSkillData = self:GetDoSkillData()

    local entity = GetEntityByInsId(doSkillData.CasterInsId)
    if not entity then
        return
    end

    DebugSKillLog_DoSkillData(DebugSKillLogLayer.All , "LineEventSettlementObject:OnInvoke settlementTableLine "  , self._settlementTableLine , self._timeLineIndex)

    self._isActive = true

    local forward = self:GetForward(self._forwardType)
    self._activeForward = Vector(forward.x,forward.y,forward.z)
    self._activePosition = self:GetTargetPosition(self._followType,self._followTypeP1)

    if self._duration == 0 then
        self._isActive = false
        self:HitTarget()
    end
end

-- 子类继承 处理多段LineEvent
function LineEventSettlementObject:OnUpdate(delta)
    if self._isActive then
        self._isActive = false
        self:HitTarget()
    else
        if self._passTime + delta <= self._duration then
            self._hitIntervalTime = self._hitIntervalTime - delta;
            if self._hitIntervalTime < math.epsilon then
                self._isActive = true;
                self._hitIntervalTime = self._settlementTableLine.HitInterval + self._hitIntervalTime
            end
        else
            
        end
    end
    self._passTime = self._passTime + delta
end

function LineEventSettlementObject:HitTarget()
    local doSkillData = self:GetDoSkillData()
    -- DebugSKillLog_DoSkillData(DebugSKillLogLayer.All ,  "LineEventSettlementObject:HitTarget 0 : entityId settementId",doSkillData,self._settementId)
    local casterInsId = doSkillData.CasterInsId
    local targetInsId = doSkillData.TargetInsId
    local caster = GetEntityByInsId(casterInsId)
    if caster == nil then
        return
    end

    local settlementInsList = {}
    local rangeType = self._settlementTableLine.RangeType
    local maxHitCount = self._maxHitCount
    local settementCount = 0
    if rangeType == 0 then
        settementCount = 1
        self:HitTargetOne(targetInsId,settementCount)
        table.insert(settlementInsList,targetInsId)
    else
        -- 标记发生了范围结算
        local skillInsId = self:GetSkill():GetSkillInsId()
        SkillManagerInstance:MarkAreaHit(skillInsId)
        
        local rangeParamLerp = {}
        local rangeParam = self._settlementTableLine.RangeParam
        local rangeParamMax = self._settlementTableLine.RangeParamMax
        if rangeParamMax and self._duration > 0 then
            table.Lerp(rangeParamLerp,rangeParam,rangeParamMax,self._passTime / self._duration)
        else
            rangeParamLerp = rangeParam
        end

        if self._followType == SettlementFlollowType.DynCaster
            or self._followType == SettlementFlollowType.DynTarget
            or self._followType == SettlementFlollowType.DynAgent then
            self._activePosition = self:GetTargetPosition(self._followType,self._followTypeP1)
        end

        if self._forwardType == SettlementForwardType.DynamicCasterForward then
            self._activeForward = self:GetForward(self._forwardType)
        end

        local units = nil
        if rangeType == 1 then
            units = self:FindUnitsInFan(self._activePosition,self._activeForward,rangeParamLerp)
        elseif rangeType == 2 then
            units = self:FindUnitsInFanRing(self._activePosition,self._activeForward,rangeParamLerp)
        elseif rangeType == 3 then
            units = self:FindUnitsInRectangle(self._activePosition,self._activeForward,rangeParamLerp)
        end
        if units then
            local camp = self._damageType
            for _,entity in pairs(units) do
                if maxHitCount > 0 or self._maxHitCount == 0 then
                    if entity ~= nil then
                        local entityInsId = entity:GetInsid()
                        if self._settlementTableLine.IgnoreCurTarget and targetInsId and targetInsId == entityInsId then
                        else
                            local entityCamp = entity:GetCamp()
                            if entityCamp ~= 0 then
                                if camp == 0
                                    or (camp == SettlementCampType.DIF_CAMP and caster:GetCamp() ~= entityCamp)
                                    or (camp == SettlementCampType.SAME_CAMP and caster:GetCamp() == entityCamp) then
                                    maxHitCount = maxHitCount - 1
                                    settementCount = settementCount + 1
                                    self:HitTargetOne(entityInsId,settementCount)
                                    table.insert(settlementInsList,entityInsId)
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- 被动 击中
    if #settlementInsList > 0 then
        PassiveSkillManagerInstance:TRIGGER(PassiveSkillVariable.IsHit,casterInsId,function(condition)
        condition[PassiveSkillVariable.SettlementCount] = settementCount
        condition[PassiveSkillVariable.SettlementInsList] = settlementInsList
        end,self:GetSkill() , self)
    end
end

function LineEventSettlementObject:HitTargetOne(targetId, settementCount)
    local casterInsId = self:GetDoSkillData().CasterInsId

    if self._hitOnce then
        local inIndex = table.ContainValue(self._hitInsIdList , targetId , nil ,nil)
        if inIndex == 0 then
            if not self._hitInsIdList then
                self._hitInsIdList = {}
            end
            table.insert(self._hitInsIdList,targetId)
        else
            return
        end
    end

    local doSkillData = self:GetDoSkillData()

    -- 记录技能命中
    local skillInsId = self:GetSkill():GetSkillInsId()
    SkillManagerInstance:RecordSkillHit(skillInsId, targetId)

    DebugSKillLog(DebugSKillLogLayer.All , "LineEventSettlementObject:HitTarget 1: casterId targetId settementId " , doSkillData.CasterInsId,targetId,self._settementId)

    local EffectTimes = 1.0

    -- buff数量对效果的影响
    local effectBuffTimes = self._settlementTableLine.BuffECountffectTimes
    if effectBuffTimes then
        local t = effectBuffTimes[1]
        local r = effectBuffTimes[2] or 1.0
        local buffs = SkillAPI.GetEntityBuffs(targetId , t)
        EffectTimes = EffectTimes * #buffs * r
    end

    -- 击中数量对伤害的影响
    local hitCountEffectTimes = self._settlementTableLine.HitCountEffectTimes
    if hitCountEffectTimes then
        local times = GetConfDataLevel(hitCountEffectTimes,settementCount)
        EffectTimes = EffectTimes * times
    end

    if self._settlementTableLine.HitDisplace then
        self:DoHitDisplace(targetId, EffectTimes)
    end

    if self._settlementTableLine.CasterHitBuffId then
        for _, buffId in ipairs(self._settlementTableLine.CasterHitBuffId) do
            self:AddBuff(buffId,casterInsId, EffectTimes,nil)
        end
    end

    if self._settlementTableLine.TargetHitBuffId then
        for _, buffId in ipairs(self._settlementTableLine.TargetHitBuffId) do
            self:AddBuff(buffId,targetId,EffectTimes,nil)
        end
    end

    self:GetSkill():SettlementHitTarget(self._settlementTableLine.HitBreakSkill,targetId)

    -- 被动 受击
    PassiveSkillManagerInstance:TRIGGER(PassiveSkillVariable.IsHitRcv,targetId,nil,self:GetSkill(),self)
end

---@param position Vector
---@param rangeParam table
---@param forward Vector|nil
function LineEventSettlementObject:FindUnitsInFan(position,  forward,rangeParam)
    local radius = rangeParam[1]
    local angle = rangeParam[2]

    DrawDebugFan(position, radius, angle,forward,0.2,nil)

    ---@type table<integer, CUnitBase>
---@diagnostic disable-next-line: assign-type-mismatch
    local units = Units:GetUnitsByArea(position,radius,nil,true, true)

    if angle == nil or angle == 360 then
        return units
    end

    local result = {}
    local halfAngle = angle / 2
    local cosHalfAngle = math.cos(math.rad(halfAngle))

    -- 遍历圆内单位进行扇形判定
    for _, unit in pairs(units) do
        local unitPosition = unit:GetPosition()
---@diagnostic disable-next-line: undefined-field
        local direction = (unitPosition - position):Normalized()

        -- 判断是否在半径范围内
---@diagnostic disable-next-line: undefined-field
        local distance = (unitPosition - position):Length2D()
        if distance <= radius then
            -- 计算点积，判断是否在角度范围内
---@diagnostic disable-next-line: need-check-nil
            local dotProduct = forward:Dot(direction)
            if dotProduct >= cosHalfAngle then
                table.insert(result, unit)
            end
        end
    end

    return result
end

function LineEventSettlementObject:FindUnitsInRectangle(center, forward, rangeParam)
    local width = rangeParam[1]  -- 矩形宽度
    local length = rangeParam[2] -- 矩形长度

    -- 调试绘制矩形
    DrawDebugRectangle(center, width, length, forward, 0.2, nil)

    -- 矩形边界计算
    local forwardDir = forward:Normalized()
    local right = RotateVector(forwardDir, 90) -- 垂直于 forward 的方向
    local halfWidth = width / 2
    local halfLength = length / 2

    -- 计算四个顶点（逆时针顺序）
    local C1 = center + forwardDir * halfLength + right * halfWidth   -- 前右
    local C2 = center + forwardDir * halfLength - right * halfWidth   -- 前左
    local C3 = center - forwardDir * halfLength - right * halfWidth   -- 后左
    local C4 = center - forwardDir * halfLength + right * halfWidth   -- 后右

    -- 使用新接口直接获取矩形内的单位（自动处理碰撞半径）
    ---@type table<integer, CUnitBase>
    local units = Units:GetUnitsByRectArea(C1, C2, C3, C4, nil, true, true)
    
    -- 转换为数组格式返回
    local result = {}
    for _, unit in pairs(units) do
        table.insert(result, unit)
    end

    return result
end

---@param position Vector
---@param rangeParam table
---@param forward Vector|nil
function LineEventSettlementObject:FindUnitsInFanRing(position,  forward,rangeParam)
    local radius = rangeParam[1]
    local innerRadius = rangeParam[2]
    local angle = rangeParam[3]

    DrawDebugFanRing(position, radius, innerRadius, angle,forward,0.2,nil)

    ---@type table<integer, CUnitBase>
---@diagnostic disable-next-line: assign-type-mismatch
    local units = Units:GetUnitsByArea(position,radius,nil,true, true)

    if angle == nil then
        return units
    end

    local result = {}
    local halfAngle = angle / 2
    local cosHalfAngle = math.cos(math.rad(halfAngle))

    -- 遍历圆内单位进行扇形判定
    for _, unit in pairs(units) do
        local unitPosition = unit:GetPosition()
---@diagnostic disable-next-line: undefined-field
        local direction = (unitPosition - position):Normalized()

        -- 判断是否在半径范围内
---@diagnostic disable-next-line: undefined-field
        local distance = (unitPosition - position):Length2D()
        if distance <= radius and distance >= innerRadius then
            -- 计算点积，判断是否在角度范围内
---@diagnostic disable-next-line: need-check-nil
            local dotProduct = forward:Dot(direction)
            if dotProduct >= cosHalfAngle then
                table.insert(result, unit)
            end
        end
    end

    return result
end

-- 位移
---@param targetId integer 目标ID
---@param EffectTimes number 效果次数
function LineEventSettlementObject:DoHitDisplace(targetId , EffectTimes)
    local casterInsId = self:GetDoSkillData().CasterInsId
    local hitDisplace = self._settlementTableLine.HitDisplace
    ---@type table
    local ps = string.split_lite(tostring(hitDisplace[2]),"_")
    local followType = tonumber(ps[1]) or 0
    local followTypeP1 = ps[2] and tonumber(ps[2]) or 0
    local buffId = hitDisplace[1]
    local targetPosition = self:GetTargetPosition(followType,followTypeP1) or Vector(0,0,0)
    local entity = GetEntityByInsId(targetId)
    if not entity or not entity:IsAlive() then
        return
    end
    local startPostition = entity:GetPosition()
    ---@type Vector
---@diagnostic disable-next-line: assign-type-mismatch
    local distanceForward = targetPosition - startPostition
    local distance = distanceForward:Length2D()
    local forward = distanceForward:Normalized()
    local endPosition = Vector(0,0,0)
    local modifyBuffCall = nil
    local attrType = GetBuffLine(buffId).AttrType
    local addTimes = BuffManagerInstance:GetBuffTimeAdd(casterInsId,targetId , attrType)
    local hitDisplace4 = (hitDisplace[4] or 0.0)
    -- 如果是代理模式
    if hitDisplace[3] == 3 then
        local agentPosition = self:GetTargetPosition(SettlementFlollowType.Target,0)
        local offsetPosition = startPostition - agentPosition
        endPosition = targetPosition + offsetPosition * hitDisplace4 -- 保持偏移
        endPosition = Lerp2(startPostition,endPosition,addTimes)
        -- 同步代理速度
        if hitDisplace[5] == 1 then
            modifyBuffCall = function(buff)
---@diagnostic disable-next-line: undefined-field
                local duration = (endPosition - startPostition):Length2D()
                local bulletSpeed = self:GetSkill():GetAgentSpeed() or 1.0
                buff:SetDuration(duration / bulletSpeed)
            end
        end
    else
        if not hitDisplace[3] then
            hitDisplace[3] = 1
            error("hitDisplace[3] is nil" .. tostring(self._settlementTableLine.Id))
        end
        if not hitDisplace[4] then
            hitDisplace[4] = distance
            error("hitDisplace[4] is nil" .. tostring(self._settlementTableLine.Id))
        end
        endPosition = hitDisplace[3] == 1
        and (distance > hitDisplace[4] and (startPostition + forward*hitDisplace4) or targetPosition)
---@diagnostic disable-next-line: need-check-nil
        or (targetPosition + forward * hitDisplace4)
        endPosition = Lerp2(startPostition,endPosition,addTimes)
    end

    if self._settlementTableLine.DisplaceDistanceEffectTimes then
        EffectTimes = EffectTimes * distance * self._settlementTableLine.DisplaceDistanceEffectTimes
    end

    self:AddBuff(buffId,targetId, EffectTimes,endPosition, modifyBuffCall,addTimes)
end

function LineEventSettlementObject:AddBuff(buffId,insId,EffectTimes,endPosition, modifyBuffCall,addTimes)
    local skill = self:GetSkill()
    ---@type DoBuffData
    local doBuffData = DoBuffData.New()
    doBuffData.EntityId = insId
    doBuffData.BuffId = buffId
    doBuffData.BuffLevel = skill:GetDoSkillData().SkillLevel
    doBuffData.Skill = skill
    doBuffData.EffectTimes = EffectTimes
    doBuffData.EndPosition = endPosition
    doBuffData.AddTimes = addTimes or 1.0
    BuffManagerInstance:AddBuff(doBuffData,modifyBuffCall)
end

---@param followType integer
---@param followTypeP1 number
---@return Vector
function LineEventSettlementObject:GetTargetPosition(followType,followTypeP1)
    local position = SkillLineEvent.GetTargetPosition(self,followType,followTypeP1)
    position = Vector(position.x,position.y,position.z)
    if self._offsetForward ~= 0 or self._offsetRight ~= 0 then
        local endPosition = SkillLineEvent.GetTargetPosition(self,SettlementFlollowType.Position,followTypeP1)
---@diagnostic disable-next-line: undefined-field
        local forward = (position - endPosition):Normalized()
        if self._offsetForward ~= 0 then
---@diagnostic disable-next-line: assign-type-mismatch
            position = position + forward * self._offsetForward
        end

        if self._offsetRight ~= 0 then
            local upVec = Vector(0, 0, 1)
            local right = forward:Cross(upVec):Normalized()
---@diagnostic disable-next-line: assign-type-mismatch
            position = position + right * self._offsetRight
        end
    end
    return position
end

function LineEventSettlementObject:GetSettlementTableLine()
    return self._settlementTableLine
end

function LineEventSettlementObject:OnSkillFinish()
    -- LayeredAttributeSystem.Delete(self._settlementTableLine)
    return SkillLineEvent.OnSkillFinish(self)
end

-- 开放到被动中的接口 尽量简单
function LineEventSettlementObject:getdata()
    return self._doSettlementData
end

function LineEventSettlementObject:gettable()
    return self._settlementTableLine
end

function LineEventSettlementObject:getlocaltable()
    return GetSettlementLine(self._settementId)
end

-- TODO 老技能硬编码 老技能机制后续不在使用，所以不在增加技能逻辑，直接硬编码处理
function LineEventSettlementObject:OldSkillHardCode()
    local doSkillData = self:GetDoSkillData()
    local skillId = doSkillData.SkillId
    local skillLevel = doSkillData.SkillLevel
    -- 技能1110070 专武配置 9级增加范围50
    if skillId == 1110070 then
        if skillLevel == 9 then
            self._settlementTableLine.RangeParamMax[1] = self._settlementTableLine.RangeParamMax[1] + 50
            self._settlementTableLine.RangeParamMax[2] = self._settlementTableLine.RangeParamMax[2] + 50
        end
    end
end