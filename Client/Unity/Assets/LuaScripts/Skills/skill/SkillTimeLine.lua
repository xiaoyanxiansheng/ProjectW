--- 技能时间线模块
--- 负责管理技能释放过程中的时间线事件序列
--- 包括预警、动画、特效、位移、伤害结算等各类事件的触发和执行
--- 提供事件注册、更新、执行和清理的功能
--- 支持复杂技能的时序控制和连锁效果

require("critcore.skill.lineEvent.SkillLineEvent")
require("critcore.skill.lineEvent.LineEventPreWarning")
require("critcore.skill.lineEvent.LineEventAnimation")
require("critcore.skill.lineEvent.LineEventBuff")
require("critcore.skill.lineEvent.LineEventBullet")
require("critcore.skill.lineEvent.LineEventSettlementObject")
require("critcore.skill.lineEvent.LineEventSound")
require("critcore.skill.lineEvent.LineEventParticle")
require("critcore.skill.lineEvent.LineEventCameraShake")
require("critcore.skill.lineEvent.LineEventDisplacement")
require("critcore.skill.lineEvent.LineEventEnterCD")
require("critcore.skill.lineEvent.LineEventTurnToTarget")
require("critcore.skill.lineEvent.LineEventPowerSkillEvent")
require("critcore.skill.lineEvent.LineEventTimeLineState")
require("critcore.skill.lineEvent.LineEventCanBreakSkill")
require("critcore.skill.lineEvent.LineEventSummon")
require("critcore.skill.lineEvent.LineEventBulletRange")
require("critcore.skill.lineEvent.LineEventTargetSelect")
require("critcore.skill.lineEvent.LineEventDoSkill")
require("critcore.skill.lineEvent.LineEventTransferbuff")
require("critcore.skill.lineEvent.LineEventBuffTogether")
require("critcore.skill.lineEvent.LineEventPassive")
require("critcore.skill.lineEvent.LineEventNewPosition")
require("critcore.skill.lineEvent.LineEventSettlementObjectNew")
require("critcore.skill.lineEvent.LineEventTargetSelectNew")
require("critcore.skill.lineEvent.LineEventDisplacementNew")
require("critcore.skill.lineEvent.LineEventParticleNew")
require("critcore.skill.lineEvent.LineEventBulletNew")
require("critcore.skill.lineEvent.LineEventBulletRangeNew")
require("critcore.skill.lineEvent.LineEventBuffNew")
require("critcore.skill.lineEvent.LineEventTurnToSkill")
require("critcore.skill.lineEvent.LineEventSummonNew")
--- 技能时间线 不能暂停
---@class SkillTimeLine : Classnew
SkillTimeLine = Classnew("SkillTimeLine", nil)

--- 事件类型到事件处理类的映射表
---@type table<integer , SkillLineEvent>
LineEventToScritp = {
    [ESkillEventType.PreWarning] = LineEventPreWarning,
    [ESkillEventType.Animation] = LineEventAnimation,
    [ESkillEventType.Buff] = LineEventBuff,
    [ESkillEventType.Bullet] = LineEventBullet,
    [ESkillEventType.SettlementObject] = LineEventSettlementObject,
    [ESkillEventType.Sound] = LineEventSound,
    [ESkillEventType.Particle] = LineEventParticle,
    [ESkillEventType.CameraShake] = LineEventCameraShake,
    [ESkillEventType.Displacement] = LineEventDisplacement,
    [ESkillEventType.EnterCD] = LineEventEnterCD,
    [ESkillEventType.TurnToTarget] = LineEventTurnToTarget,
    [ESkillEventType.State] = LineEventTimeLineState,
    [ESkillEventType.CanBreakSkill] = LineEventCanBreakSkill,
    [ESkillEventType.Summon] = LineEventSummon,
    [ESkillEventType.BulletRange] = LineEventBulletRange,
    [ESkillEventType.TargetSelect] = LineEventTargetSelect,
    [ESkillEventType.DoSkill] = LineEventDoSkill,
    [ESkillEventType.TransferDebuff] = LineEventTransferbuff,
    [ESkillEventType.BuffTogether] = LineEventBuffTogether,
    [ESkillEventType.Passive] = LineEventPassive,
    [ESkillEventType.PositionNew] = LineEventNewPosition,
    [ESkillEventType.SettlementObjectNew] = LineEventSettlementObjectNew,
    [ESkillEventType.TargetSelectNew] = LineEventTargetSelectNew,
    [ESkillEventType.DisplacementNew] = LineEventDisplacementNew,
    [ESkillEventType.ParticleNew] = LineEventParticleNew,
    [ESkillEventType.BulletNew] = LineEventBulletNew,
    [ESkillEventType.BulletRangeNew] = LineEventBulletRangeNew,
    [ESkillEventType.BuffNew] = LineEventBuffNew,
    [ESkillEventType.TurnToSkill] = LineEventTurnToSkill,
    [ESkillEventType.SummonNew] = LineEventSummonNew,
}

--- 构造函数，初始化时间线对象
function SkillTimeLine:ctor()
    ---@type SkillLineEvent[] 时间线事件列表
    self._lineEvents = {}

    --- 时间线已经经过的时间
    self._passTime = 0.0

    self._pool = PoolManagerInstance:CreateAndRegister("skillTimeLineEvent",self, self.PoolCreateCall)
end

function SkillTimeLine:PoolCreateCall(handle, eventType,config,index, settlementTableLine)
    return LineEventToScritp[eventType].New(handle, eventType,config,index, settlementTableLine)
end

function SkillTimeLine:PoolGet(eventType,config,index, settlementTableLine)
    return self._pool:Get(self,eventType,config,index, settlementTableLine)
end

function SkillTimeLine:PoolBack(skillTimeLineEvent)
    self._pool:Back(skillTimeLineEvent)
end

--- 初始化时间线，根据技能配置创建事件序列
---@param skill SkillLogic 技能逻辑对象
---@param timeLine table 时间线配置数据
function SkillTimeLine:Init(skill , timeLine  )
    self._skill = skill
    if not timeLine then
        return
    end
    
    local doSkillData = self._skill:GetDoSkillData()
    local skillId = doSkillData.SkillId
    local skillLevel = doSkillData.SkillLevel
    local hasSound = false
    -- local passiveCondition = {}
    for index, c in ipairs(timeLine) do
        -- 检查技能等级是否符合事件触发条件
        local isLevel = skillLevel >= c.Level[1] and skillLevel <= c.Level[2]
        if isLevel and c.Active==1 then
            -- 构建事件配置
            ---@type table
            local config = {c.Time, c.Type}
            table.InsertRange(config , c.Params)
            local eventType = tonumber(config[2])
            if LineEventToScritp[eventType] ~= nil then
                -- 特殊处理结算对象事件
                if eventType == ESkillEventType.SettlementObject
                    or eventType == ESkillEventType.SettlementObjectNew then
                    local settementId = tonumber(config[3])
                    ---@type SettlementLine
                    local settlementTableLine = clone(GetSettlementLine(settementId))
                    ---@type LineEventSettlementObject | LineEventSettlementObjectNew
                    local event = LineEventToScritp[eventType]
                    local settlement = self._pool:Get(self,eventType,config,index, settlementTableLine)
                    self:CheckSkillSettlement(settlement)
                    self:AddLineEvent(settlement)
                else
                    -- 创建普通事件
                    ---@type SkillLineEvent
                    local event = LineEventToScritp[eventType]
                    self:AddLineEvent(self._pool:Get(self,eventType,config))
                end
            end
            if eventType == ESkillEventType.Sound then
                hasSound = true
            end
        end
    end
    if not hasSound then
        self:AddLineEvent(self._pool:Get(self,ESkillEventType.Sound,{0,ESkillEventType.Sound,ConfData:GetGameConfig("SkillDefaultSound")}))
    end
end

--- 添加时间线事件到事件列表
---@param event SkillLineEvent 要添加的事件对象
function SkillTimeLine:AddLineEvent(event)
    table.insert(self._lineEvents, event)
end

--- 重置指定的时间线事件
---@param event SkillLineEvent 要重置的事件对象
function SkillTimeLine:LineEventReset(event)
    event:Reset()
end

--- 开始执行时间线
--- 重置时间计数器和所有事件状态
function SkillTimeLine:Start()
    self._passTime = 0
    ---@param event SkillLineEvent
    for _, event in pairs(self._lineEvents) do
        self:LineEventReset(event)
    end
end

--- 结束技能时间线
--- 通知所有事件技能已结束
function SkillTimeLine:SKillFinish()
    ---@param event SkillLineEvent
    for _, event in pairs(self._lineEvents) do
        event:SKillFinish()
        self:PoolBack(event)
    end
    self._lineEvents = {}
end

--- 更新时间线
--- 推进时间并更新所有事件
---@param delta number 时间增量
function SkillTimeLine:Update(delta)
    self._passTime = self._passTime + delta
    for _, event in pairs(self._lineEvents) do
        event:Update(self._passTime,delta)
    end
end

--- 通知所有事件有目标被命中
---@param targetId integer 被命中目标的ID
function SkillTimeLine:SettlementHitTarget(targetId)
    for _, event in pairs(self._lineEvents) do
        event:SettlementHitTarget(targetId)
    end
end

function SkillTimeLine:OnSetTarget(targetInsId)
    for _, event in pairs(self._lineEvents) do
        event:OnSetTarget(targetInsId)
    end
end

--- 根据时间线索引获取结算表配置
---@param timeLineIndex integer 时间线索引
---@return SettlementLine|nil 返回结算表配置，如果未找到则返回nil
function SkillTimeLine:GetSettlementTableLine(timeLineIndex)
    local settlementObject = self:GetSettlementObject(timeLineIndex)
    if settlementObject then
        return settlementObject:GetSettlementTableLine()
    end
    return nil
end

--- 根据时间线索引获取事件
---@param timeLineIndex integer 时间线索引
---@return LineEventSettlementObject|nil 返回事件，如果未找到则返回nil
function SkillTimeLine:GetSettlementObject(timeLineIndex)
    for _, event in pairs(self._lineEvents) do
        if event:IsTimeLine(timeLineIndex) then
---@diagnostic disable-next-line: return-type-mismatch
            return event
        end
    end
    return nil
end

--- 检查技能是否可以被打断
---@return boolean 如果技能可以被打断返回true，否则返回false
function SkillTimeLine:CanBreakSkill()
    for i = #self._lineEvents, 1, -1 do
        local event = self._lineEvents[i]
        if event and event:IsEvent(ESkillEventType.CanBreakSkill) and event:IsInvoke() then
---@diagnostic disable-next-line: undefined-field
            if event:CanBreakSkill() then
                return true
            end
        end
    end
    return false
end

--- 设置技能代理对象
---@param agentInsId integer 代理对象ID
---@param speed number 代理对象速度
function SkillTimeLine:SetAgent(agentInsId, speed)
    self:GetSkill():GetDoSkillData().AgentInsId = agentInsId
    self:GetSkill():GetDoSkillData().AgentInsSpeed = speed
end

--- 获取技能代理速度
---@return number 技能代理速度
function SkillTimeLine:GetAgentSpeed()
    for _, event in pairs(self._lineEvents) do
        if event:IsEvent(ESkillEventType.Bullet) then
            ---@type any
            local bulletEvent = event
            return bulletEvent:GetSpeed()
        end
    end
    return 0.0
end

function SkillTimeLine:IsNewPosition()
    for i = #self._lineEvents, 1, -1 do
        local event = self._lineEvents[i]
        if event ~= nil and event:IsEvent(ESkillEventType.PositionNew) and event:IsInvoke() then
            return true
        end
    end
    return false
end

function SkillTimeLine:GetNewPosition()
    for i = #self._lineEvents, 1, -1 do
        local event = self._lineEvents[i]
        if event ~= nil and event:IsEvent(ESkillEventType.PositionNew) and event:IsInvoke() then
            ---@type LineEventNewPosition
            ---@diagnostic disable-next-line: assign-type-mismatch
            local newPositionEvent = event
            return newPositionEvent:GetPosition()
        end
    end
    return Vector(0,0,0)
end

function SkillTimeLine:GetNewTargetPosition()
    for i = #self._lineEvents, 1, -1 do
        local event = self._lineEvents[i]
        if event ~= nil and event:IsEvent(ESkillEventType.PositionNew) and event:IsInvoke() then
            ---@type LineEventNewPosition
            ---@diagnostic disable-next-line: assign-type-mismatch
            local newPositionEvent = event
            return newPositionEvent:GetTargetPosition2()
        end
    end
    return Vector(0,0,0)
end 

function SkillTimeLine:GetNewStartPosition()
    for i = #self._lineEvents, 1, -1 do
        local event = self._lineEvents[i]
        if event ~= nil and event:IsEvent(ESkillEventType.PositionNew) and event:IsInvoke() then
            ---@type LineEventNewPosition
            ---@diagnostic disable-next-line: assign-type-mismatch
            local newPositionEvent = event
            return newPositionEvent:GetStartPosition2()
        end
    end
    return Vector(0,0,0)
end

function SkillTimeLine:GetNewMoveSpeed()
    for i = #self._lineEvents, 1, -1 do
        local event = self._lineEvents[i]
        if event ~= nil and event:IsEvent(ESkillEventType.PositionNew) and event:IsInvoke() then
            ---@type LineEventNewPosition
            ---@diagnostic disable-next-line: assign-type-mismatch
            local newPositionEvent = event
            return newPositionEvent:GetMoveSpeed()
        end
    end
    return 0
end

function SkillTimeLine:GetNewForward()
    for i = #self._lineEvents, 1, -1 do
        local event = self._lineEvents[i]
        if event ~= nil and event:IsEvent(ESkillEventType.PositionNew) and event:IsInvoke() then
            ---@type LineEventNewPosition
            ---@diagnostic disable-next-line: assign-type-mismatch
            local newPositionEvent = event
            return newPositionEvent:GetForward2()
        end
    end
    return Vector(0,0,0)
end

function SkillTimeLine:GetNewRangeParams()
    for i = #self._lineEvents, 1, -1 do
        local event = self._lineEvents[i]
        if event ~= nil and event:IsEvent(ESkillEventType.PositionNew) and event:IsInvoke() then
            ---@type LineEventNewPosition
            ---@diagnostic disable-next-line: assign-type-mismatch
            local newPositionEvent = event
            return newPositionEvent:GetRangeParams()
        end
    end
    return Vector(0,0,0)
end

function SkillTimeLine:GetNewDuration()
    for i = #self._lineEvents, 1, -1 do
        local event = self._lineEvents[i]
        if event ~= nil and event:IsEvent(ESkillEventType.PositionNew) and event:IsInvoke() then
            ---@type LineEventNewPosition
            ---@diagnostic disable-next-line: assign-type-mismatch
            local newPositionEvent = event
            return newPositionEvent:GetDuration()
        end
    end
    return 0
end

function SkillTimeLine:MoveToTargetPositionCallBack()
    for i = #self._lineEvents, 1, -1 do
        ---@type SkillLineEvent
        local event = self._lineEvents[i]
        event:MoveToTargetPositionCallBack()
    end
end

--- 获取关联的技能逻辑对象
---@return SkillLogic 技能逻辑对象
function SkillTimeLine:GetSkill()
    return self._skill
end

--- 检查技能结算并应用被动技能效果
---@param settlement LineEventSettlementObject | LineEventSettlementObjectNew 结算事件对象
function SkillTimeLine:CheckSkillSettlement(settlement)
    local skill = self:GetSkill()
    local casterInsId = skill:GetDoSkillData().CasterInsId
    local condition = PassiveSkillManagerInstance:TRIGGERCONDITION(PassiveSkillVariable.IsDoSettlement,casterInsId,nil,skill,settlement,nil)
    PassiveSkillManagerInstance:ModifySettlement(skill , settlement,condition)
end

function SkillTimeLine:GetNewTargetPositionType()
    for i = #self._lineEvents, 1, -1 do
        local event = self._lineEvents[i]
        if event ~= nil and event:IsEvent(ESkillEventType.PositionNew) and event:IsInvoke() then
            ---@type LineEventNewPosition
            ---@diagnostic disable-next-line: assign-type-mismatch
            local newPositionEvent = event
            return newPositionEvent:GetTargetPositionType()
        end
    end
end