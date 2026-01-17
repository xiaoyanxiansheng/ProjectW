--[[ 
Buff事件模块
负责管理技能释放过程中的Buff事件序列
包括Buff的添加、移除和控制
提供事件注册、更新和执行功能
支持不同类型的Buff和控制参数
作为技能时间线系统的组成部分，处理技能释放过程中的Buff效果
--]]

---@class LineEventBuffNew : SkillLineEvent
LineEventBuffNew = Classnew("LineEventBuffNew" , SkillLineEvent)

function LineEventBuffNew:ctor(skill,eventType , config,timeLineIndex)
    SkillLineEvent.ctor(self,skill,eventType, config,timeLineIndex)

    ---@type integer
---@diagnostic disable-next-line: assign-type-mismatch
    self._buffId = tonumber(self._config[3])
    self._targetType = self._config[4] and tonumber(self._config[4]) or 0
    if self._config[5] then
        local buffDurationPs = string.split_lite(tostring(self._config[5]),"/")
        self._buffDuration = GetConfDataLevel(buffDurationPs,skill:GetSkill():GetDoSkillData().SkillLevel)
        self._buffDuration = tonumber(self._buffDuration)
    else
        self._buffDuration = -1
    end

    self._duration = self._config[6] and tonumber(self._config[6]) or 0
    self._interval = self._config[7] and tonumber(self._config[7]) or 0
end

-- 子类继承 LineEvent时间触发
function LineEventBuffNew:OnInvoke()
    if self._buffDuration == 0 then
        self._buffDuration = self:GetNewDuration()
    end

    self._nextBuffTime = 0.0
    if self._duration < 0.0001 then
        self._duration = self:GetNewDuration()
    end
    self:AddBuff()
end

-- 子类继承 处理多段LineEvent
function LineEventBuffNew:OnUpdate(delta)
    if self._interval < 0.0001 then
        return
    end

    if self._duration < 0.0001 then
        return
    end
    self._duration = self._duration - delta

    self._nextBuffTime = self._nextBuffTime + delta
    -- 检查是否到达间隔时间
    if self._nextBuffTime >= self._interval then
        self:AddBuff()
        self._nextBuffTime = self._nextBuffTime - self._interval
    end
end

function LineEventBuffNew:AddBuff()
    local skill = self:GetSkill()
    local doSkillData = self:GetDoSkillData()
    if self._targetType == 2 then
        local caster = GetEntityByInsId(doSkillData.CasterInsId)
        if caster ~= nil then
            if caster:IsAlive() then
                ---@type UnitSummonsMessage[]
                local summons = caster:GetSummons()
                for insId, _ in pairs(summons) do
                    ---@type DoBuffData
                    local doBuffData = DoBuffData.New()
                    doBuffData.EntityId = insId
                    doBuffData.Skill = skill
                    doBuffData.BuffId = self._buffId
                    doBuffData.BuffLevel = doSkillData.SkillLevel
                    doBuffData.EffectTimes = doSkillData.EffectTimes
                    BuffManagerInstance:AddBuff(doBuffData,function(buff)
                        if self._buffDuration ~= -1 then
                            buff:SetDuration(self._buffDuration)
                        end
                    end)
                end
            end
        end
        return
    end

    ---@type DoBuffData
    local doBuffData = DoBuffData.New()
    doBuffData.EntityId = self._targetType == 0 and doSkillData.CasterInsId or doSkillData.TargetInsId
    doBuffData.Skill = skill
    doBuffData.BuffId = self._buffId
    doBuffData.BuffLevel = doSkillData.SkillLevel
    doBuffData.EffectTimes = doSkillData.EffectTimes
    BuffManagerInstance:AddBuff(doBuffData,function(buff)
        if self._buffDuration ~= -1 then
            buff:SetDuration(self._buffDuration)
        end
    end)
end

