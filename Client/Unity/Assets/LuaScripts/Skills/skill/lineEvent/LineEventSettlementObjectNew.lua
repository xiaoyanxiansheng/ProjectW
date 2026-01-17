---@class LineEventSettlementObjectNew : SkillLineEvent
LineEventSettlementObjectNew = Classnew("LineEventSettlementObjectNew" , SkillLineEvent)

DoSettlementDataNew = Classnew("DoSettlementDataNew", nil)

-- 构造函数，初始化Buff数据
function DoSettlementDataNew:ctor(timeLineIndex)
    self.TimeLineIndex = timeLineIndex
end

---@param skillTimeLine SkillTimeLine
---@param eventType integer
---@param config table
function LineEventSettlementObjectNew:ctor(skillTimeLine,eventType , config, timeLineIndex, settlementTableLine)
    SkillLineEvent.ctor(self,skillTimeLine,eventType, config, timeLineIndex)
    self._doSettlementData = DoSettlementDataNew.New(timeLineIndex)
    ---@type integer
---@diagnostic disable-next-line: assign-type-mismatch
    self._settementId = tonumber(self._config[3])
    ---@type number
---@diagnostic disable-next-line: assign-type-mismatch
    self._duration = self._config[4] and tonumber(self._config[4]) or 0.0

    ---@type SettlementLine
    self._SettlementLineConfig = settlementTableLine
    self._maxHitCount = self._SettlementLineConfig.MaxHitCount or 0
    self._passTime = 0.0
    self._hitIntervalTime = self._SettlementLineConfig.HitInterval or 0
    self._isActive = false
    self._hitOnce = self._SettlementLineConfig.HitOnce and self._SettlementLineConfig.HitOnce == 1
    self._hitInsIdList = nil
    self._targetHitBuffId = self._SettlementLineConfig.TargetHitBuffId or {}
    self._targetHitBuffDuration = {}
    local targetHitBuffDurationParams = self._SettlementLineConfig.TargetHitBuffDuration or {}
    for _,durationParam in ipairs(targetHitBuffDurationParams) do
        local duration = string.split_lite(tostring(durationParam),"/")
        table.insert(self._targetHitBuffDuration,tonumber(GetConfDataLevel(duration,self:GetSkill():GetDoSkillData().SkillLevel)))
    end

    self._damageType = self:GetSkill():GetSkillTableLine().DamageType
    if self._config[5] then
        ---@type integer
---@diagnostic disable-next-line: assign-type-mismatch
        local damageType = tonumber(self._config[5])
        self._damageType = damageType
    end
end

-- 子类继承 LineEvent时间触发
function LineEventSettlementObjectNew:OnInvoke()
    if self._duration <= 0.0001 then
        self._duration = self:GetNewDuration()
    end

    local doSkillData = self:GetDoSkillData()

    local entity = GetEntityByInsId(doSkillData.CasterInsId)
    if not entity then
        return
    end

    DebugSKillLog_DoSkillData(DebugSKillLogLayer.All , "LineEventSettlementObjectNew:OnInvoke " , self:GetNewRangeParams() , {self._doSettlementData.TimeLineIndex , self._SettlementLineConfig.Id})

    self._isActive = true
    self._isFinish = false

    if self._hitIntervalTime <= 0.0001 then
        self._isFinish = true
        self:HitTarget()
    end
end

-- 子类继承 处理多段LineEvent
function LineEventSettlementObjectNew:OnUpdate(delta)
    if self._isFinish then
        return
    end

    if self._isActive then
        self._isActive = false
        self:HitTarget()
    else
        if self._passTime + delta <= self._duration then
            self._hitIntervalTime = self._hitIntervalTime - delta
            if self._hitIntervalTime < math.epsilon then
                self._isActive = true
                self._hitIntervalTime = self._SettlementLineConfig.HitInterval + self._hitIntervalTime
            end
        else
            self._isFinish = true
        end
    end
    self._passTime = self._passTime + delta
end

function LineEventSettlementObjectNew:HitTarget()
    local doSkillData = self:GetDoSkillData()
    -- DebugSKillLog_DoSkillData(DebugSKillLogLayer.All ,  "LineEventSettlementObjectNew:HitTarget 0 : entityId settementId",doSkillData,self._settementId)
    local casterInsId = doSkillData.CasterInsId
    local targetInsId = doSkillData.TargetInsId
    local caster = GetEntityByInsId(casterInsId)
    if caster == nil then
        return
    end

    local rangeParams = self:GetNewRangeParams()
    local rangeType = rangeParams.x
    local position = self:GetNewPosition()

    local forward = self:GetNewForward()
    local rangeParamLerp = Vector(rangeParams.y,rangeParams.z,0)
    
    local maxHitCount = self._maxHitCount
    local settementCount = 0
    local settlementInsList = {}
    if rangeType == 0 then
        local targetPositionType = self:GetSkill():GetNewTargetPositionType()
        if targetPositionType == SettlementFlollowType.Caster or targetPositionType == SettlementFlollowType.DynCaster then
            targetInsId = casterInsId
        end
        settementCount = 1
        local targetPosition = GetEntityPosition(targetInsId)
        local distance = (position - targetPosition):Length2D()
        local hitThreshold = 10 -- 默认阈值，可以根据需要调整
        if distance <= hitThreshold then
            self:HitTargetOne(targetInsId, settementCount)
            table.insert(settlementInsList,targetInsId)
        end
    else
        -- 标记发生了范围结算
        local skillInsId = self:GetSkill():GetSkillInsId()
        SkillManagerInstance:MarkAreaHit(skillInsId)
        
        local units = nil
        if rangeType == 1 then
            units = self:FindUnitsInFan(position,forward,rangeParamLerp)
        elseif rangeType == 2 then
            units = self:FindUnitsInFanRing(position,forward,rangeParamLerp)
        elseif rangeType == 3 then
            units = self:FindUnitsInRectangle(position,forward,rangeParamLerp)
        end
        if units then
            local camp = self._damageType
            for _,entity in pairs(units) do
                if maxHitCount > 0 or self._maxHitCount == 0 then
                    if entity ~= nil then
                        local entityInsId = entity:GetInsid()
                        if self._SettlementLineConfig.IgnoreCurTarget == 1 and targetInsId and targetInsId == entityInsId then
                        elseif self._SettlementLineConfig.IgnoreCurTarget == 2 and casterInsId == entityInsId then
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

    if #settlementInsList > 0 then
        -- 被动 击中
        PassiveSkillManagerInstance:TRIGGER(PassiveSkillVariable.IsHit,casterInsId,function(condition)
        condition[PassiveSkillVariable.SettlementCount] = settementCount
        condition[PassiveSkillVariable.SettlementInsList] = settlementInsList
        end,self:GetSkill() , self)
        self:GetSkill():SettlementHitTarget(self._SettlementLineConfig.HitBreakSkill,settlementInsList[#settlementInsList])
    end

    SendBeginMessage(MsgConst.SKILL_TIMELINE_EVENT_SETTLEMENT_HIT, {skillid = self:GetDoSkillData().SkillId, settlementInsList = settlementInsList})
end

function LineEventSettlementObjectNew:HitTargetOne(targetId, settementCount)
    local doSkillData = self:GetDoSkillData()
    local casterInsId = doSkillData.CasterInsId

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

    -- 记录技能命中
    local skillInsId = self:GetSkill():GetSkillInsId()
    SkillManagerInstance:RecordSkillHit(skillInsId, targetId)

    DebugSKillLog(DebugSKillLogLayer.All , "LineEventSettlementObjectNew:HitTarget 1: casterId targetId settementId " , doSkillData.CasterInsId,targetId,self._settementId)

    local EffectTimes = doSkillData.EffectTimes or 1.0

    -- buff数量对效果的影响
    local effectBuffTimes = self._SettlementLineConfig.BuffECountffectTimes
    if effectBuffTimes then
        local t = effectBuffTimes[1]
        local r = effectBuffTimes[2] or 1.0
        local buffs = SkillAPI.GetEntityBuffs(targetId , t)
        EffectTimes = EffectTimes * #buffs * r
    end

    -- 击中数量对伤害的影响
    local hitCountEffectTimes = self._SettlementLineConfig.HitCountEffectTimes
    if hitCountEffectTimes then
        local times = GetConfDataLevel(hitCountEffectTimes,settementCount)
        EffectTimes = EffectTimes * times
    end

    if self._SettlementLineConfig.HitDisplace then
        self:DoHitDisplace(targetId, EffectTimes)
    end

    if self._SettlementLineConfig.CasterHitBuffId then
        for _, buffId in ipairs(self._SettlementLineConfig.CasterHitBuffId) do
            self:AddBuff(buffId,casterInsId, EffectTimes,nil)
        end
    end

    for index, buffId in ipairs(self._targetHitBuffId) do
        local duration = self._targetHitBuffDuration[index]
        self:AddBuff(buffId,targetId,EffectTimes,nil,function(buff)
            if duration and duration > 0 then
                buff:SetDuration(duration)
            end
        end)
    end

    -- 被动 受击
    PassiveSkillManagerInstance:TRIGGER(PassiveSkillVariable.IsHitRcv,targetId,nil,self:GetSkill(),self)
end

---@param position Vector
---@param rangeParam table
---@param forward Vector|nil
function LineEventSettlementObjectNew:FindUnitsInFan(position,  forward,rangeParam)
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

function LineEventSettlementObjectNew:FindUnitsInRectangle(center, forward, rangeParam)
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
function LineEventSettlementObjectNew:FindUnitsInFanRing(position,  forward,rangeParam)
    local radius = rangeParam[1]
    local innerRadius = rangeParam[2]
    local angle = rangeParam[3]

    DrawDebugFanRing(position, radius, innerRadius, angle,forward,0.2,nil)

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
function LineEventSettlementObjectNew:DoHitDisplace(targetId , EffectTimes)
    local doSkillData = self:GetDoSkillData()
    local casterInsId = doSkillData.CasterInsId
    local hitDisplace = self._SettlementLineConfig.HitDisplace
    local buffId = hitDisplace[1]
    local positionType = hitDisplace[2]
    local forwardOffsetType = hitDisplace[3]
    local forwardOffset = hitDisplace[4]
    local speed = hitDisplace[5]
    local startPosition = GetEntityByInsId(targetId):GetPosition()
    local tempEndPosition = self:GetTypePosition(positionType)
    ---@type Vector
    ---@diagnostic disable-next-line: assign-type-mismatch
    local forward = tempEndPosition - startPosition
    local forwardNormalized = forward:Normalized()
    local attrType = GetBuffLine(buffId).AttrType
    local addTimes = BuffManagerInstance:GetBuffTimeAdd(casterInsId,targetId , attrType)
    local endPosition
    if forwardOffsetType == 1 then
        endPosition = self:GetTypePostitionOffset(startPosition,forwardNormalized,forwardOffset,0)
    else
        endPosition = self:GetTypePostitionOffset(tempEndPosition,forwardNormalized,forwardOffset,0)
    end
    endPosition = LerpVectors(startPosition,endPosition,addTimes)
    local distance = (endPosition - startPosition):Length2D()
    if self._SettlementLineConfig.DisplaceDistanceEffectTimes ~= nil then
        EffectTimes = EffectTimes * distance * self._SettlementLineConfig.DisplaceDistanceEffectTimes
    end

    local duration = distance / speed
    self:AddBuff(buffId,targetId, EffectTimes, endPosition,function(buff)
        buff:SetDuration(duration)
    end,addTimes)
end

function LineEventSettlementObjectNew:AddBuff(buffId,insId,EffectTimes,endPosition, modifyBuffCall,addTimes)
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

function LineEventSettlementObjectNew:AddTargetHitBuff(buffId)
    table.insert(self._targetHitBuffId,buffId)
end

function LineEventSettlementObjectNew:SetTargetHitBuffs(buffIds)
    self._targetHitBuffId = buffIds
end

function LineEventSettlementObjectNew:GetSettlementTableLine()
    return self._SettlementLineConfig
end

function LineEventSettlementObjectNew:OnSkillFinish()
    -- LayeredAttributeSystem.Delete(self._SettlementLineConfig)
    return SkillLineEvent.OnSkillFinish(self)
end

-- 开放到被动中的接口 尽量简单
function LineEventSettlementObjectNew:getdata()
    return self._doSettlementData
end

function LineEventSettlementObjectNew:gettable()
    return self._SettlementLineConfig
end

function LineEventSettlementObjectNew:getlocaltable()
    return GetSettlementLine(self._settementId)
end