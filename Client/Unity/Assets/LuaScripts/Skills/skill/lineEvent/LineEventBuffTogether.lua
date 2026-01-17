---@class LineEventBuffTogether : SkillLineEvent
LineEventBuffTogether = Classnew("LineEventBuffTogether" , SkillLineEvent)

function LineEventBuffTogether:ctor(skill,eventType , config,timeLineIndex)
    SkillLineEvent.ctor(self,skill,eventType, config,timeLineIndex)

    ---@type integer
---@diagnostic disable-next-line: assign-type-mismatch
    self._buffId = tonumber(self._config[3])
    self._togetherInsId = tonumber(self._config[4]) == 2
    self._effectType = tonumber(self._config[5])
end

-- 子类继承 TimeLine 启动的时候会统一调用
function LineEventBuffTogether:OnReset()

end

-- 子类继承 LineEvent时间触发
function LineEventBuffTogether:OnInvoke()
    local doSkillData = self:GetDoSkillData()
    local casterInsId = doSkillData.CasterInsId
    local targetInsId = doSkillData.TargetInsId
    local togetherInsIds = {}
    if self._togetherInsId then
        if self._effectType == 1 then
            table.insert(togetherInsIds,targetInsId)
        elseif self._effectType == 2 then
            table.insert(togetherInsIds,casterInsId)
        else
            table.insert(togetherInsIds,targetInsId)
            table.insert(togetherInsIds,casterInsId)
        end
    else
        local otherAllPlayer = Lobby:GetOtherAllPlayer(casterInsId)
        local otherInsIds = {}
        for _, player in pairs(otherAllPlayer) do
            local controller = player:GetController()
            if controller then
                table.insert(otherInsIds,controller:GetInsid())
            end
        end
        if self._effectType == 1 then
            table.InsertRange(togetherInsIds,otherInsIds)
        elseif self._effectType == 2 then
            table.insert(togetherInsIds,casterInsId)
        else
            table.InsertRange(togetherInsIds,otherInsIds)
            table.insert(togetherInsIds,casterInsId)
        end
    end

    DebugSKillLog_DoSkillData(DebugSKillLogLayer.All, "LineEventBuffTogether:OnInvoke()" , self._config , table.tostring(togetherInsIds))

    for _, insId in pairs(togetherInsIds) do
        ---@type DoBuffData
        local doBuffData = DoBuffData.New()
        doBuffData.EntityId = insId
        doBuffData.Skill = self:GetSkill()
        doBuffData.BuffId = self._buffId
        doBuffData.BuffLevel = doSkillData.SkillLevel
        doBuffData.InsIds = togetherInsIds
        BuffManagerInstance:AddBuff(doBuffData)
    end
end