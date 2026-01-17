--[[ 
位移事件模块
负责管理技能释放过程中的位移事件序列
包括位移的计算、执行和控制
提供事件注册、更新和执行功能
支持不同类型的位移方式和参数
作为技能时间线系统的组成部分，处理技能释放过程中的位移效果
--]]

---@class LineEventDisplacementNew : SkillLineEvent
LineEventDisplacementNew = Classnew("LineEventDisplacementNew" , SkillLineEvent)

function LineEventDisplacementNew:ctor(skill,eventType , config,timeLineIndex)
    SkillLineEvent.ctor(self,skill,eventType, config,timeLineIndex)

    ---@type integer
---@diagnostic disable-next-line: assign-type-mismatch
    self._buffId = tonumber(self._config[3])
    ---@type integer
---@diagnostic disable-next-line: assign-type-mismatch
    self._skillId = tonumber(self._config[4]) or 0
    ---@type integer
---@diagnostic disable-next-line: assign-type-mismatch
    self._notUseSkillForward = tonumber(self._config[5]) or 0

    local bulletProcessSkillParams = self._config[6] and string.split_lite(self._config[6],"_") or nil
    self._bulletProcessSkillId = 0
    self._bulletProcessSkillInterval = 0.0
    self._bulletProcessSkillPassTime = 0.0
    if bulletProcessSkillParams then
---@diagnostic disable-next-line: assign-type-mismatch
        self._bulletProcessSkillId = tonumber(bulletProcessSkillParams[1])
---@diagnostic disable-next-line: assign-type-mismatch
        self._bulletProcessSkillInterval = tonumber(bulletProcessSkillParams[2])
    end
end

-- 子类继承 LineEvent时间触发
function LineEventDisplacementNew:OnInvoke()
    local doSkillData = self:GetDoSkillData()
    local caster = GetEntityByInsId(doSkillData.CasterInsId)
    if not caster then
        return
    end

    local position = self:GetNewPosition()
    local targetPosition = self:GetNewTargetPosition()
    local moveSpeed = self:GetNewMoveSpeed()
    if self._notUseSkillForward == 0 then
        SetEntityForwardVector(doSkillData.CasterInsId,self:GetNewForward())
    end
---@diagnostic disable-next-line: undefined-field
    local duration = (targetPosition-position):Length() / moveSpeed
    ---@type DoBuffData
    local doBuffData = DoBuffData.New()
    doBuffData.EntityId = doSkillData.CasterInsId
    doBuffData.Skill = self:GetSkill()
    doBuffData.BuffId = self._buffId
    doBuffData.BuffLevel = doSkillData.SkillLevel
    doBuffData.EndPosition = targetPosition
    doBuffData.MoveFinishBreakSkill = true
    BuffManagerInstance:AddBuff(doBuffData , function(buff)
        buff:SetDuration(duration)
    end)
end

-- 子类继承 处理多段LineEvent
function LineEventDisplacementNew:OnUpdate(delta)
    -- 过程技能
    if self._bulletProcessSkillId > 0 then
        if self._bulletProcessSkillPassTime <= 0 then
            self._bulletProcessSkillPassTime = self._bulletProcessSkillInterval
            local doSkillData = self:GetDoSkillData()
            local position = self:GetNewPosition()
            local newDoSKillData = clone(doSkillData)
            newDoSKillData.SkillId = self._bulletProcessSkillId
            newDoSKillData.StartPosition = position
            newDoSKillData.ParentSkill =  self:GetSkill()
            SkillManagerInstance:DoSkill(newDoSKillData)
        end
        self._bulletProcessSkillPassTime = self._bulletProcessSkillPassTime - delta
    end
end

function LineEventDisplacementNew:OnSkillFinish()
    if self._skillId ~= 0 then
        local doSkillData = self:GetDoSkillData()
        ---@type DoSkillData
        local newDoSKillData = clone(doSkillData)
        newDoSKillData.SkillId = self._skillId
        newDoSKillData.StartPosition = self:GetNewTargetPosition()
        newDoSKillData.ParentSkill =  self:GetSkill()
        SkillManagerInstance:DoSkill(newDoSKillData)
    end
end