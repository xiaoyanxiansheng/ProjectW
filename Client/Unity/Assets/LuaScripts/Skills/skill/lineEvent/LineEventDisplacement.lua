--[[ 
位移事件模块
负责管理技能释放过程中的位移事件序列
包括位移的计算、执行和控制
提供事件注册、更新和执行功能
支持不同类型的位移方式和参数
作为技能时间线系统的组成部分，处理技能释放过程中的位移效果
--]]

---@class LineEventDisplacement : SkillLineEvent
LineEventDisplacement = Classnew("LineEventDisplacement" , SkillLineEvent)

function LineEventDisplacement:ctor(skill,eventType , config,timeLineIndex)
    SkillLineEvent.ctor(self,skill,eventType, config,timeLineIndex)

        ---@type table
    local ps = string.split_lite(tostring(self._config[3]),"_")
    self._followType = tonumber(ps[1])
    self._followTypeP1 = ps[2] and tonumber(ps[2]) or 0
    ---@type integer
---@diagnostic disable-next-line: assign-type-mismatch
    self._buffId = tonumber(self._config[4]) or 0
    ---@type number
---@diagnostic disable-next-line: assign-type-mismatch
    self._speed = tonumber(self._config[5])
    ---@type integer
---@diagnostic disable-next-line: assign-type-mismatch
    self._skillId = tonumber(self._config[6]) or 0

    self._isActive = false
    self._duration = 0.0
end

-- 子类继承 LineEvent时间触发
function LineEventDisplacement:OnInvoke()
    local doSkillData = self:GetDoSkillData()
    local caster = GetEntityByInsId(doSkillData.CasterInsId)
    if not caster then
        return
    end

    self._isActive = true

    local position = self:GetTargetPosition(self._followType,self._followTypeP1)
    ---@type Vector
---@diagnostic disable-next-line: assign-type-mismatch
    local direction = position - caster:GetPosition()
---@diagnostic disable-next-line: undefined-field
    SetEntityForwardVector(doSkillData.CasterInsId,direction:Normalized())
    self._duration = direction:Length() / self._speed
    ---@type DoBuffData
    local doBuffData = DoBuffData.New()
    doBuffData.EntityId = doSkillData.CasterInsId
    doBuffData.Skill = self:GetSkill()
    doBuffData.BuffId = self._buffId
    doBuffData.BuffLevel = doSkillData.SkillLevel
    doBuffData.EndPosition = position
    BuffManagerInstance:AddBuff(doBuffData , function(buff)
        buff:SetDuration(self._duration)
    end)
end

-- 子类继承 处理多段LineEvent
function LineEventDisplacement:OnUpdate(delta)
    if not self._isActive then
        return
    end

    if self._duration <= 0 then
        self._isActive = false
        SkillManagerInstance:DoFinishSkill(self:GetSkill())
        if self._skillId ~= 0 then
            local doSkillData = self:GetDoSkillData()
            ---@type DoSkillData
            local newDoSKillData = clone(doSkillData)
            newDoSKillData.SkillId = self._skillId
            newDoSKillData.ParentSkill =  self:GetSkill()
            SkillManagerInstance:DoSkill(newDoSKillData)
        end
    end
    self._duration = self._duration - delta
end

function LineEventDisplacement:OnEnd()

end