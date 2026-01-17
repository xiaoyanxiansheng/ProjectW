--[[ 
技能时间线事件模块
负责管理技能释放过程中的时间线事件序列
包括预警、动画、特效、位移、伤害结算等各类事件的触发和执行
提供事件注册、更新、执行和清理的功能
支持复杂技能的时序控制和连锁效果
--]]
---@class SkillLineEvent : Classnew
SkillLineEvent = Classnew("SkillLineEvent", nil);

---@param skillTimeLine SkillTimeLine 技能时间线对象
---@param eventType integer 事件类型
---@param config table 事件配置参数
---@param timeLineIndex number 时间线索引
function SkillLineEvent:ctor(skillTimeLine, eventType , config, timeLineIndex)
    self._timeLineIndex = timeLineIndex
    self._skillTimeLine = skillTimeLine
    self._eventType = eventType
    self._config = config;
    self._isInvoke = false;
end

-- 重置事件状态
function SkillLineEvent:Reset()
    self._IsInvoke = false
    self._activeTime = tonumber(self._config[1])
    if self:IsValidEntity() then
        self:OnReset()
    end
end

-- 获取技能释放位置
---@return Vector 技能释放位置坐标
function SkillLineEvent:GetStartPosition(flollowTypeP1)
    local position = Vector(0,0,0)
    local doSkillData = self:GetDoSkillData()
    local caster = GetEntityByInsId(doSkillData.CasterInsId)
    if caster then
        position = caster:GetPosition()
    end

    if doSkillData.StartAgentId then
        position = GetEntityPosition(doSkillData.StartAgentId)
    end

    if doSkillData.StartPosition then
        position = doSkillData.StartPosition
    end

    if flollowTypeP1 ~= 0 then
        local forward = self:GetForward(SettlementForwardType.CasterForward)
        position = position + forward * flollowTypeP1
    end

---@diagnostic disable-next-line: return-type-mismatch
    return position
end

-- 获取技能朝向向量
---@param forward number 朝向类型
---@return Vector 朝向向量
function SkillLineEvent:GetForward(forward)
    local doSkillData = self:GetDoSkillData()

    local rForward = Vector(1,0,0)
    local caster = GetEntityByInsId(doSkillData.CasterInsId)
    if caster then
        rForward = caster:GetForwardVector()
        if forward == SettlementForwardType.StartTargetForward then
            local targetPosition = self:GetDoSkillData().Position
            local startPosition = caster:GetPosition()
---@diagnostic disable-next-line: undefined-field
            rForward = (targetPosition - startPosition):Normalized()
        end
    end

    return rForward
end

-- 获取技能目标位置
---@param flollowType number 跟随类型
---@return Vector 目标位置坐标
function SkillLineEvent:GetTargetPosition(flollowType , flollowTypeP1)
    local doSkillData = self._skillTimeLine:GetSkill():GetDoSkillData()
    local casterPosition = GetEntityPosition(doSkillData.CasterInsId)
    local vec = self:GetDoSkillData().Position or casterPosition

    if flollowType == SettlementFlollowType.Position then
        vec = self:GetDoSkillData().Position or vec
        if flollowTypeP1 ~= 0 then
            local startPosition = self:GetStartPosition(0)
---@diagnostic disable-next-line: undefined-field
            local forward = (vec - startPosition):Normalized()
---@diagnostic disable-next-line: assign-type-mismatch
            vec = startPosition + forward * flollowTypeP1
        end
    elseif flollowType == SettlementFlollowType.Caster or flollowType == SettlementFlollowType.DynCaster then
        vec = casterPosition
        if flollowTypeP1 ~= 0 then
            local forward = self:GetForward(SettlementForwardType.CasterForward)
---@diagnostic disable-next-line: assign-type-mismatch
            vec = vec + forward * flollowTypeP1
        end
    elseif flollowType == SettlementFlollowType.Target or flollowType == SettlementFlollowType.DynTarget then
        local target = GetEntityByInsId(doSkillData.TargetInsId)
        vec = target and target:GetPosition() or vec
        if flollowTypeP1 ~= 0 then
            local startPosition = self:GetStartPosition(0)
---@diagnostic disable-next-line: undefined-field
            local forward = (vec - startPosition):Normalized()
---@diagnostic disable-next-line: assign-type-mismatch
            vec = startPosition + forward * flollowTypeP1
        end
    elseif flollowType == SettlementFlollowType.Agent or flollowType == SettlementFlollowType.DynAgent then
        local agent = GetEntityByInsId(doSkillData.AgentInsId)
        vec = agent and agent:GetPosition() or vec
    elseif flollowType == SettlementFlollowType.StartPosition then
        vec = self:GetDoSkillData().StartPosition or vec
    end

    return vec
end

---@param positionType integer 位置类型
---@return Vector 位置坐标
function SkillLineEvent:GetTypePosition(positionType)
    local newPosition = self:GetDoSkillData().PositionNew
    local casterInsId = newPosition.CasterInsId
    local targetInsId = newPosition.TargetInsId
    local endPosition = newPosition.EndPosition
    local startPosition = newPosition.StartPosition

    local vec = endPosition or startPosition

    if positionType == SettlementFlollowType.Position
        or positionType == SettlementFlollowType.DynPosition then
        vec = endPosition
    elseif positionType == SettlementFlollowType.Caster
        or positionType == SettlementFlollowType.DynCaster then
        local caster = GetEntityByInsId(casterInsId)
        if caster ~= nil then
            vec = caster:GetPosition()
        end
    elseif positionType == SettlementFlollowType.Target
        or positionType == SettlementFlollowType.DynTarget then
        local target = GetEntityByInsId(targetInsId)
        if target ~= nil then
            vec = target:GetPosition()
        end
    elseif positionType == SettlementFlollowType.StartPosition then
        vec = startPosition
    end

    if vec == nil then
        vec = Vector(0,0,0)
        error("LineEventNewPosition:CalculatePosition 目标位置定义错误 " .. positionType)
    end

    return vec
end

---@param position Vector 位置坐标
---@param forward Vector 朝向向量
---@param offsetForward number 偏移朝向
---@param offsetRight number 偏移右向
---@return Vector 偏移后的位置坐标
function SkillLineEvent:GetTypePostitionOffset(position , forward , offsetForward , offsetRight)
    position = position + forward * offsetForward
    if offsetRight ~= 0 then
        local upVec = Vector(0, 0, 1)
        local right = forward:Cross(upVec):Normalized()
        position = position + right * offsetRight
    end
---@diagnostic disable-next-line: return-type-mismatch
    return position
end

function SkillLineEvent:GetNewPosition()
    return self._skillTimeLine:GetNewPosition()
end

function SkillLineEvent:GetNewTargetPosition()
    return self._skillTimeLine:GetNewTargetPosition()
end

function SkillLineEvent:GetNewStartPosition()
    return self._skillTimeLine:GetNewStartPosition()
end

---@return number
function SkillLineEvent:GetNewMoveSpeed()
    return self._skillTimeLine:GetNewMoveSpeed()
end

function SkillLineEvent:GetNewForward()
    return self._skillTimeLine:GetNewForward()
end

function SkillLineEvent:GetNewRangeParams()
    return self._skillTimeLine:GetNewRangeParams()
end

function SkillLineEvent:GetNewDuration()
    return self._skillTimeLine:GetNewDuration()
end

function SkillLineEvent:MoveToTargetPositionCallBack()
    
end

function SkillLineEvent:CalForward(targetPosition,startPosition)
    local forward = targetPosition - startPosition
    if forward:Length() < 0.01 then
        local caster = GetEntityByInsId(self:GetDoSkillData().CasterInsId)
        local defaultForward = caster:GetForwardVector()
        forward = Vector(defaultForward.x,defaultForward.y,defaultForward.z)
    end
    forward = forward:Normalized()
    return forward
end

-- 触发事件执行
function SkillLineEvent:Invoke()
    if not self:GetSkill():IsActive() then
        return
    end

    if self._IsInvoke then
        return
    end

    --if self._eventType ~= ESkillEventType.SettlementObject then
    local doSkillData = self._skillTimeLine:GetSkill():GetDoSkillData()
    DebugSKillLog_DoSkillData(DebugSKillLogLayer.All, tostring(self)..self.__cname .. ":Invoke doSkillData:" , doSkillData)
    --end

    if self:IsValidEntity() then
        self:OnInvoke()
    end
end

-- 更新事件状态
---@param passTime number 已经过时间
---@param delta number 时间增量
function SkillLineEvent:Update(passTime , delta)
    if self._IsInvoke == false then
        if passTime >= self._activeTime then
            self:Invoke()
            self._IsInvoke = true
        end
    end

    if self._IsInvoke then
        if self:IsValidEntity() and self:GetSkill():IsActive() then
            self:OnUpdate(delta)
        end
    end
end

-- 技能结束时调用
function SkillLineEvent:SKillFinish()
    if self:IsValidEntity() then
        self:OnSkillFinish()
    end

    self:OnClear()
end

-- 获取事件类型
---@return number 事件类型
function SkillLineEvent:EventType()
    return self._eventType
end

-- 子类继承 TimeLine 启动的时候会统一调用
function SkillLineEvent:OnReset()
    
end

-- 子类继承 LineEvent时间触发
function SkillLineEvent:OnInvoke()
    
end

-- 子类继承 处理多段LineEvent
---@param delta number 时间增量
function SkillLineEvent:OnUpdate(delta)
    
end

-- 技能结束时的回调
function SkillLineEvent:OnSkillFinish()
    
end

-- 清理事件
function SkillLineEvent:OnClear()
    
end

-- 检查实体是否有效
---@return boolean 实体是否有效
function SkillLineEvent:IsValidEntity()
    local caster = GetEntityByInsId(self:GetDoSkillData().CasterInsId)
    if not caster then
        return false
    end

    if not caster:IsAlive() then
        return false
    end

    return true
end

-- 检查是否为指定事件类型
---@param eventType number 事件类型
---@return boolean 是否为指定事件类型
function SkillLineEvent:IsEvent(eventType)
    return self._eventType == eventType
end

-- 处理命中目标
---@param targetId number 目标ID
function SkillLineEvent:SettlementHitTarget(targetId)

end

-- 设置代理实体
---@param agentInsId integer 代理实体ID
---@param speed number 速度
function SkillLineEvent:SetAgent(agentInsId, speed)
    self:GetSkill():SetAgent(agentInsId , speed)
end

-- 设置目标
---@param targetInsId integer 目标实体ID
function SkillLineEvent:SetTarget(targetInsId)
    self:GetSkill():SetTarget(targetInsId)
end

function SkillLineEvent:OnSetTarget(targetInsId)
    
end

-- 获取技能逻辑对象
---@return SkillLogic 技能逻辑对象
function SkillLineEvent:GetSkill()
    return self._skillTimeLine:GetSkill()
end

-- 获取技能释放数据
---@return DoSkillData 技能释放数据
function SkillLineEvent:GetDoSkillData()
    return self:GetSkill():GetDoSkillData()
end

-- 获取技能配置表行
---@return SkillTableLine 技能配置表行
function SkillLineEvent:GetSkillTableLine()
    return self:GetSkill():GetSkillTableLine()
end

-- 获取技能时间轴
---@return SkillTimeLine 技能时间轴
function SkillLineEvent:GetSkillTimeLine()
    return self._skillTimeLine
end

-- 检查是否为指定时间线
---@param index number 时间线索引
---@return boolean 是否为指定时间线
function SkillLineEvent:IsTimeLine(index)
    return self._timeLineIndex == index
end

function SkillLineEvent:GetTimeLineIndex()
    return self._timeLineIndex
end

function SkillLineEvent:gettimelineindex()
    return self._timeLineIndex
end

function SkillLineEvent:IsInvoke()
    return self._IsInvoke
end