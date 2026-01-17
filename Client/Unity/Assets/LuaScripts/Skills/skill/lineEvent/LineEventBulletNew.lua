---@class LineEventBulletNew : SkillLineEvent
LineEventBulletNew = Classnew("LineEventBulletNew" , SkillLineEvent)

function LineEventBulletNew:ctor(skill,eventType , config,timeLineIndex)
    SkillLineEvent.ctor(self,skill,eventType, config,timeLineIndex)

    local bulletHitParams = string.split_lite(tostring(self._config[3]),"_")
    self._bulletHitSkillId = tonumber(bulletHitParams[1])
    self._isBulletHitFinishSkill = bulletHitParams[2] and tonumber(bulletHitParams[2]) == 1 or false

    ---@type integer
---@diagnostic disable-next-line: assign-type-mismatch
    self._bulletFinishSkillId = self._config[4] and tonumber(self._config[4]) or 0

    local bulletProcessSkillParams = self._config[5] and string.split_lite(self._config[5],"_") or nil
    self._bulletProcessSkillId = 0
    self._bulletProcessSkillInterval = 0.0
    self._bulletProcessSkillPassTime = 0.0
    if bulletProcessSkillParams then
---@diagnostic disable-next-line: assign-type-mismatch
        self._bulletProcessSkillId = tonumber(bulletProcessSkillParams[1])
---@diagnostic disable-next-line: assign-type-mismatch
        self._bulletProcessSkillInterval = tonumber(bulletProcessSkillParams[2])
    end

    local loopSkillParams = self._config[6] and string.split_lite(self._config[6],"_") or nil
    self._loopSkill = false
    self._loopSkillDuration = 0.0
    self._hitLoopSkill = false
    if loopSkillParams then
        local doSkillData = self:GetDoSkillData()
        self._loopSkill = true
        local loopSkillCountParams = string.split_lite(tostring(loopSkillParams[1]),"/")
        ---@type integer
        ---@diagnostic disable-next-line: assign-type-mismatch
        local loopSkillCount = tonumber(GetConfDataLevel(loopSkillCountParams , doSkillData.SkillLevel))
        self._loopSkillDuration = tonumber(loopSkillParams[2])
        self._hitLoopSkill = loopSkillParams[3] and tonumber(loopSkillParams[3]) == 1 or false
        if doSkillData.NewFinishLoopCount == -1 then
            doSkillData.NewFinishLoopCount = loopSkillCount
            doSkillData.DefaultNewFinishLoopCount = loopSkillCount
        end
    end
end

function LineEventBulletNew:OnInvoke()

end

function LineEventBulletNew:OnUpdate(delta)
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

    if self._loopSkill and not self._hitLoopSkill then
        if self._loopSkillDuration <= 0 then
            self._loopSkill = false
            self:DoLoopSkill()
        end
        self._loopSkillDuration = self._loopSkillDuration - delta
    end
end

function LineEventBulletNew:DoLoopSkill()
    local doSkillData = self:GetDoSkillData()
    if (doSkillData.NewFinishLoopCount > 0) then
        doSkillData.NewFinishLoopCount = doSkillData.NewFinishLoopCount - 1
        ---@type DoSkillData
        local newDoSKillData = clone(doSkillData)
        newDoSKillData.StartPosition = self:GetNewPosition()
        SkillManagerInstance:DoSkill(newDoSKillData)
    end
end

---@param targetId integer
function LineEventBulletNew:SettlementHitTarget(targetId)
    SkillLineEvent.SettlementHitTarget(self,targetId)

    local target = GetEntityByInsId(targetId)
    if not target then
        return
    end

    local doSkillData = self:GetDoSkillData()
    local position = target:GetPosition()


    if self._bulletHitSkillId > 0 then
        ---@type DoSkillData
        local newDoSKillData = clone(doSkillData)
        newDoSKillData.SkillId = self._bulletHitSkillId
        newDoSKillData.TargetInsId = targetId
        newDoSKillData.StartPosition = position
        newDoSKillData.ParentSkill =  self:GetSkill()
        SkillManagerInstance:DoSkill(newDoSKillData)
    end

    if self._loopSkill and self._hitLoopSkill then
        self:DoLoopSkill()
    end

    -- 是否结束当前技能
    if self._isBulletHitFinishSkill then
        SkillManagerInstance:DoFinishSkill(self:GetSkill(),true)
    end
end

function LineEventBulletNew:OnSkillFinish()
    local doSkillData = self:GetDoSkillData()
    local position = self:GetNewPosition()

    -- 结束技能
    if self._bulletFinishSkillId > 0 then
        ---@type DoSkillData
        local newDoSKillData = clone(doSkillData)
        newDoSKillData.SkillId = self._bulletFinishSkillId
        newDoSKillData.StartPosition = position
        newDoSKillData.ParentSkill =  self:GetSkill()
        SkillManagerInstance:DoSkill(newDoSKillData)
    end
end

