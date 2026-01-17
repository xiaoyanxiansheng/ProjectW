--[[ 
子弹范围事件模块
负责管理技能释放过程中的子弹范围事件序列
包括子弹的生成、发射和控制
提供事件注册、更新和执行功能
支持不同类型的子弹范围和分布方式
作为技能时间线系统的组成部分，处理技能释放过程中的子弹效果
支持点、扇形和矩形三种范围类型
可以设置不同的分布模式和发射数量
提供动态跟随和固定位置两种模式
允许设置持续时间和发射间隔
--]]

---@class LineEventBulletRange : SkillLineEvent
LineEventBulletRange = Classnew("LineEventBulletRange", SkillLineEvent)

LineEventBulletRangeType = {
    Point = 0,
    Fan = 1,
    Rect = 2,
}

function LineEventBulletRange:ctor(skill,eventType,config,timeLineIndex)
    SkillLineEvent.ctor(self,skill,eventType,config,timeLineIndex)

    local skillLevel = skill:GetSkill():GetDoSkillData().SkillLevel
    self._isAcitve = false
    self._bulletSkillId = tonumber(self._config[3])
    ---@type table
    local ps = string.split_lite(tostring(self._config[4]),"_")
    self._followType = tonumber(ps[1])
    self._followTypeP1 = ps[2] and tonumber(ps[2]) or 0
    ---@type integer
---@diagnostic disable-next-line: assign-type-mismatch
    self._forwardType = tonumber(self._config[5])
    ---@type string[]
    local shapeParams = string.split_lite(self._config[6],"_")
    ---@type number[]
    local offsetPs = string.split_lite(tostring(self._config[7]),"/")
    self._offset = tonumber(GetConfDataLevel(offsetPs,skillLevel))
    ---@type integer
---@diagnostic disable-next-line: assign-type-mismatch
    self._distributeType = tonumber(self._config[8])
    ---@type integer
---@diagnostic disable-next-line: assign-type-mismatch
    self._arrowCount = tonumber(self._config[9])
    ---@type number
---@diagnostic disable-next-line: assign-type-mismatch
    self._duration = tonumber(self._config[10])
    ---@type number
---@diagnostic disable-next-line: assign-type-mismatch
    self._interval = tonumber(self._config[11])

    self._intervalPassTime = -0.0001
    self._shapeParams = {}
    for index, value in ipairs(shapeParams) do
        local ps = string.split_lite(tostring(value),"/")
        self._shapeParams[index] = tonumber(GetConfDataLevel(ps,skillLevel))
    end
end

-- 事件触发时初始化并激活子弹范围
function LineEventBulletRange:OnInvoke()
    self._isAcitve = true
    self._intervalPassTime = -0.0001

    self._forward = self:GetForward(self._forwardType)
    self:Setup()
end

-- 设置子弹范围的位置和显示效果
function LineEventBulletRange:Setup()
    local doSkillData = self:GetDoSkillData()
    local caster = GetEntityByInsId(doSkillData.CasterInsId)
    if not caster then return end

    if self._forwardType == SettlementForwardType.DynamicCasterForward then
        self._forward = self:GetForward(self._forwardType)
    end
    self._targetPosition = self:GetTargetPosition(self._followType,self._followTypeP1) + self._forward * self._offset

    local showDuration = self._duration
    if self._followType == SettlementFlollowType.DynCaster
        or self._followType == SettlementFlollowType.DynTarget
        or self._followType == SettlementFlollowType.DynAgent then
        showDuration = 1
    else
        showDuration = showDuration + 0.2
    end
    if self._shapeParams[1] == LineEventBulletRangeType.Point then

    elseif self._shapeParams[1] == LineEventBulletRangeType.Rect then
        DrawDebugRectangle(self._targetPosition, self._shapeParams[2], self._shapeParams[3], self._forward, showDuration,Vector(0,255,0))
    else
        DrawDebugFan(self._targetPosition, self._shapeParams[2],self._shapeParams[3], self._forward,showDuration,Vector(0,255,0))
    end
end

-- 更新子弹范围状态，处理间隔发射和持续时间
function LineEventBulletRange:OnUpdate(delta)
    if not self._isAcitve then return end

    if self._intervalPassTime < 0 then
        self._intervalPassTime = self._intervalPassTime + self._interval

        if self._followType == SettlementFlollowType.DynCaster
            or self._followType == SettlementFlollowType.DynTarget
            or self._followType == SettlementFlollowType.DynAgent then
            self:Setup()
        end

        local pointPairs = self:GeneratePointPairs(self._targetPosition, self._forward)
        self:DoFirePoints(pointPairs)
    end

    self._intervalPassTime = self._intervalPassTime - delta

    self._duration = self._duration - delta
    if self._duration < 0 then
        self._isAcitve = false
    end
end

-- 根据类型和模式生成点对列表 {{start,end}, {start,end}, ...}
function LineEventBulletRange:GeneratePointPairs(targetPos, forward)
    local shapeType = self._shapeParams[1]
    if shapeType == LineEventBulletRangeType.Point then
        return self:GenerateFixPoints( )
    elseif shapeType == LineEventBulletRangeType.Fan then
        return self:GenerateConePoints( targetPos, forward)
    elseif shapeType == LineEventBulletRangeType.Rect then
        return self:GenerateRectPoints( targetPos, forward)
    end
    return {}
end

-- 固定点生成，返回目标位置点对
function LineEventBulletRange:GenerateFixPoints()
    local targetPos = self:GetTargetPosition(self._followType,self._followTypeP1) + self._forward * self._offset
    return {{targetPos, targetPos}}
end

-- 扇形点生成，根据分布类型生成扇形区域内的点对
function LineEventBulletRange:GenerateConePoints(targetPos , forward)
    local radius = self._shapeParams[2]
    local spreadAngle = self._shapeParams[3]

    local points = {}
    local halfSpread = spreadAngle / 2

    if self._distributeType == 3 then
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
                    table.insert(points, {targetPos, endP})
                end
            end
        end
    end

    return points
end

-- 矩形点生成，根据分布类型生成矩形区域内的点对
function LineEventBulletRange:GenerateRectPoints(targetPos , forward)
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
function LineEventBulletRange:DoFirePoints(pointPairs)
    for _, pair in ipairs(pointPairs) do
        self:LaunchArrow(pair[1], pair[2])
    end
end

-- 在扇形范围内随机点(随机半径、随机角度)
function LineEventBulletRange:RandomPointInCone(center, forward, spreadAngle, radius)
    local halfSpread = spreadAngle / 2
    local angle = math.random()*spreadAngle - halfSpread
    local dist = math.sqrt(math.random()) * radius
    local dir = self:RotateVector(forward, angle)
    return center + dir * dist
end

-- 在矩形范围内随机点
function LineEventBulletRange:RandomPointInRect(center, forward, right, width, length)
    local randWidth = (math.random()-0.5)*width
    local randLength = math.random()*length
    return center + right*randWidth + forward*randLength
end

-- 向量旋转计算
function LineEventBulletRange:RotateVector(vector, angle)
    local rad = math.rad(angle)
    local cosT = math.cos(rad)
    local sinT = math.sin(rad)
    return Vector(vector.x*cosT - vector.y*sinT, vector.x*sinT + vector.y*cosT, vector.z)
end

-- 发射子弹，使用技能系统创建子弹
function LineEventBulletRange:LaunchArrow(arrowPosition, targetPosition)
    arrowPosition.z = arrowPosition.z
    targetPosition.z = targetPosition.z

    local skillData = DoSkillData.New()
    skillData:Copy(self:GetDoSkillData())
    skillData.SkillId = self._bulletSkillId
    skillData.StartPosition = arrowPosition
    skillData.Position = targetPosition
    skillData.ParentSkill = self:GetSkill()
    SkillManagerInstance:DoSkill(skillData)
end
