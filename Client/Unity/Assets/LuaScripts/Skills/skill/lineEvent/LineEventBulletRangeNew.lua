---@class LineEventBulletRangeNew : SkillLineEvent
LineEventBulletRangeNew = Classnew("LineEventBulletRangeNew", SkillLineEvent)

LineEventBulletRangeType = {
    Point = 0,
    Fan = 1,
    Rect = 2,
}

function LineEventBulletRangeNew:ctor(skill,eventType,config,timeLineIndex)
    SkillLineEvent.ctor(self,skill,eventType,config,timeLineIndex)

    local skillLevel = skill:GetSkill():GetDoSkillData().SkillLevel
    self._duration = tonumber(self._config[3])
    self._bulletSkillId = tonumber(self._config[4])
    ---@type string[]
    local shapeParams = string.split_lite(self._config[5],"_")
    self._distributeType = tonumber(self._config[6])
    local arrowCounts = string.split_lite(tostring(self._config[7]),"/")
    self._arrowCount = tonumber(GetConfDataLevel(arrowCounts,skillLevel))
    ---@type number
    ---@diagnostic disable-next-line: assign-type-mismatch
    self._interval = self._config[8] and tonumber(self._config[8]) or 0
    self._isOptimized = self._config[9] and tonumber(self._config[9]) == 1 or false

    self._intervalPassTime = 0.0
    self._shapeParams = {}
    for index, value in ipairs(shapeParams) do
        local ps = string.split_lite(tostring(value),"/")
        self._shapeParams[index] = tonumber(GetConfDataLevel(ps,skillLevel))
    end
end

-- 事件触发时初始化并激活子弹范围
function LineEventBulletRangeNew:OnInvoke()
    DebugSKillLog_DoSkillData(DebugSKillLogLayer.All, "LineEventBulletRangeNew:OnInvoke" , self._config)
    self._intervalPassTime = 0.0
    if self._duration <= 0.0001 then
        self._duration = self:GetNewDuration()
    end
    self._isAcitve = true
    self:Setup()
end

-- 设置子弹范围的位置和显示效果
function LineEventBulletRangeNew:Setup()
    local position = self:GetNewPosition()
    local forward = self:GetNewForward()
    local showDuration = self._duration
    if self._shapeParams[1] == LineEventBulletRangeType.Point then
    elseif self._shapeParams[1] == LineEventBulletRangeType.Rect then
        DrawDebugRectangle(position, self._shapeParams[2], self._shapeParams[3], forward, showDuration,Vector(0,255,0))
    else
        DrawDebugFan(position, self._shapeParams[2],self._shapeParams[3], forward,showDuration,Vector(0,255,0))
    end
end

-- 更新子弹范围状态，处理间隔发射和持续时间
function LineEventBulletRangeNew:OnUpdate(delta)
    if not self._isAcitve then return end

    if self._interval <= 0.0001 then
        self._isAcitve = false
    end

    self._duration = self._duration - delta
    if self._duration <= 0 then
        self._isAcitve = false
    end

    if self._intervalPassTime <= 0 then
        self._intervalPassTime = self._intervalPassTime + self._interval

        self:Setup()
        local position = self:GetNewPosition()
        local forward = self:GetNewForward()

        local pointPairs = self:GeneratePointPairs(position, forward)
        self:DoFirePoints(pointPairs)
    end

    self._intervalPassTime = self._intervalPassTime - delta
end

-- 根据类型和模式生成点对列表 {{start,end}, {start,end}, ...}
function LineEventBulletRangeNew:GeneratePointPairs(targetPos, forward)
    local shapeType = self._shapeParams[1]
    if shapeType == LineEventBulletRangeType.Point then
        return self:GenerateFixPoints( targetPos)
    elseif shapeType == LineEventBulletRangeType.Fan then
        return self:GenerateConePoints( targetPos, forward)
    elseif shapeType == LineEventBulletRangeType.Rect then
        return self:GenerateRectPoints( targetPos, forward)
    end
    return {}
end

-- 固定点生成，返回目标位置点对
function LineEventBulletRangeNew:GenerateFixPoints(targetPos)
    return {{targetPos, targetPos}}
end

-- 扇形点生成，根据分布类型生成扇形区域内的点对
function LineEventBulletRangeNew:GenerateConePoints(targetPos , forward)
    local radius = self._shapeParams[2]
    local spreadAngle = self._shapeParams[3]

    local points = {}
    local halfSpread = spreadAngle / 2

    if self._distributeType == 4 then
        for i = 1, self._arrowCount do
            local isFind , p , insId = self:RandomTargetPointInRange(targetPos, forward, spreadAngle, radius)
            if isFind then
                table.insert(points, {p, p, insId})
            end
        end
    elseif self._distributeType == 3 then
        -- 模式2：随机点 {P,P}
        for i = 1, self._arrowCount do
            local p = self:RandomPointInCone(targetPos, forward, spreadAngle, radius)
            table.insert(points, {p, p})
        end
    else
        -- selectionMode == 1
        if self._distributeType == 1 then
            -- 随机模式(模式1)：固定半径，随机角度
            for i=1, self._arrowCount do
                local angle = math.random()*spreadAngle - halfSpread
                local dir = self:RotateVector(forward, angle)
                local endP = targetPos + dir * radius
                table.insert(points, {targetPos, endP})
            end
        else
            -- 固定模式下：等角度分布
            if self._arrowCount == 1 then
                local endP = targetPos + forward * radius
                table.insert(points, {targetPos, endP})
            else
                local angleStep = spreadAngle / (self._arrowCount - 1)
                local startAngle = -halfSpread
                for i=0, self._arrowCount-1 do
                    local currentAngle = startAngle + i * angleStep
                    local dir = self:RotateVector(forward, currentAngle)
                    local endP = targetPos + dir * radius
                    if self._distributeType == 2 then
                    table.insert(points, {targetPos, endP})
                    elseif self._distributeType == 5 then
                        table.insert(points, {endP, endP})
                    end
                end
            end
        end
    end

    return points
end

-- 矩形点生成，根据分布类型生成矩形区域内的点对
function LineEventBulletRangeNew:GenerateRectPoints(targetPos , forward)
    local rectWidth = self._shapeParams[2]
    local rectLength = self._shapeParams[3]
    targetPos = targetPos - rectLength*0.5*forward

    local points = {}
    local right = self:RotateVector(forward, 90)

    if self._distributeType == 3 then
        -- 模式2：{P,P} 随机点
        for i=1, self._arrowCount do
            local p = self:RandomPointInRect(targetPos, forward, right, rectWidth, rectLength)
            table.insert(points, {p, p})
        end
    else
        -- selectionMode == 1
        if self._distributeType == 1 then
            -- 随机模式：横向随机偏移
            for i=1, self._arrowCount do
                local r = math.random()
                local randomOffset = (r - 0.5) * rectWidth
                local startP = targetPos + right * randomOffset
                local endP = startP + forward * rectLength
                table.insert(points, {startP, endP})
            end
        else
            -- 固定模式：等距分布
            if self._arrowCount == 1 then
                local startP = targetPos
                local endP = startP + forward * rectLength
                table.insert(points, {startP, endP})
            else
                for i=0, self._arrowCount-1 do
                    local offset = ((i/(self._arrowCount-1)) - 0.5) * rectWidth
                    local startP = targetPos + right * offset
                    local endP = startP + forward * rectLength
                    table.insert(points, {startP, endP})
                end
            end
        end
    end

    return points
end

-- 对所有生成的点对执行发射操作
function LineEventBulletRangeNew:DoFirePoints(pointPairs)
    for _, pair in ipairs(pointPairs) do
        self:LaunchArrow(pair[1], pair[2], pair[3])
    end
end

-- 范围内随机目标点 - 在扇形范围内查找并返回随机目标位置
function LineEventBulletRangeNew:RandomTargetPointInRange(center, forward, spreadAngle, radius)
    local casterInsId = self:GetDoSkillData().CasterInsId
    local caster = GetEntityByInsId(casterInsId)
    local casterCamp = caster:GetCamp()
    local units = Units:GetUnitsByArea(center,radius,EnumUnitCamp.Monster,true)
    local es = {}
    local camp = self:GetSkill():GetSkillTableLine().DamageType
    local halfSpread = spreadAngle / 2
    
    for _,entity in pairs(units) do
        if entity ~= nil then
            local entityCamp = entity:GetCamp()
            if entityCamp ~= 0 then
                if camp == 0
                    or (camp == SettlementCampType.DIF_CAMP and casterCamp ~= entityCamp)
                    or (camp == SettlementCampType.SAME_CAMP and casterCamp == entityCamp) then
                    
                    -- 检查目标是否在扇形范围内
                    local targetPos = entity:GetPosition()
                    local toTarget = targetPos - center
                    local distance = toTarget:Length()
                    
                    if distance <= radius and distance > 0 then
                        -- 计算目标相对于forward方向的角度
                        local targetDir = toTarget:Normalized()
                        local forwardDir = forward:Normalized()
                        
                        -- 计算角度差（使用点积）
                        local dot = targetDir:Dot(forwardDir)
                        local angle = math.acos(math.max(-1, math.min(1, dot)))
                        local angleDegrees = math.deg(angle)
                        
                        -- 检查是否在扇形角度范围内
                        if angleDegrees <= halfSpread then
                            table.insert(es,entity)
                        end
                    end
                end
            end
        end
    end
    if #es == 0 then
        return false , nil
    end
    local unit = es[math.random(1, #es)]
    return true , unit:GetPosition() , unit:GetInsid()
end

-- 在扇形范围内随机点(随机半径、随机角度)
function LineEventBulletRangeNew:RandomPointInCone(center, forward, spreadAngle, radius)
    local halfSpread = spreadAngle / 2
    local angle = math.random()*spreadAngle - halfSpread
    local dist = math.sqrt(math.random()) * radius
    local dir = self:RotateVector(forward, angle)
    return center + dir * dist
end

-- 在矩形范围内随机点
function LineEventBulletRangeNew:RandomPointInRect(center, forward, right, width, length)
    local randWidth = (math.random()-0.5)*width
    local randLength = math.random()*length
    return center + right*randWidth + forward*randLength
end

-- 向量旋转计算
function LineEventBulletRangeNew:RotateVector(vector, angle)
    local rad = math.rad(angle)
    local cosT = math.cos(rad)
    local sinT = math.sin(rad)
    return Vector(vector.x*cosT - vector.y*sinT, vector.x*sinT + vector.y*cosT, vector.z)
end

-- 发射子弹，使用技能系统创建子弹
function LineEventBulletRangeNew:LaunchArrow(arrowPosition, targetPosition, insId)
    arrowPosition.z = arrowPosition.z
    targetPosition.z = targetPosition.z

    local skillData = DoSkillData.New()
    skillData:Copy(self:GetDoSkillData())
    skillData.TargetInsId = insId or skillData.TargetInsId
    skillData.SkillId = self._bulletSkillId
    skillData.StartPosition = arrowPosition
    skillData.Position = targetPosition
    skillData.ParentSkill = self:GetSkill()
    skillData.IsOptimized = self._isOptimized
    SkillManagerInstance:DoSkill(skillData)
end