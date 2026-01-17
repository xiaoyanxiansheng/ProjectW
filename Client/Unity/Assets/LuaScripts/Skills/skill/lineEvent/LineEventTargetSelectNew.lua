---@class LineEventTargetSelectNew : SkillLineEvent
LineEventTargetSelectNew = Classnew("LineEventTargetSelectNew" , SkillLineEvent)

function LineEventTargetSelectNew:ctor(skill,eventType , config,timeLineIndex)
    SkillLineEvent.ctor(self,skill,eventType, config,timeLineIndex)

    local skillLevel = self:GetSkill():GetDoSkillData().SkillLevel

    -- 选择半径
    local radiusPs = string.split_lite(self._config[3],"/")
    self._selectRadius = tonumber(GetConfDataLevel(radiusPs,skillLevel))
    -- 检测是否已经击中过
    self._checkHited = tonumber(self._config[4]) == 1
    -- 如果不选择最近的就随机
    self._selectNearest = tonumber(self._config[5]) == 1
end

function LineEventTargetSelectNew:OnInvoke()
    local doSkillData = self:GetDoSkillData()
    local casterInsId = doSkillData.CasterInsId
    local targetInsId = doSkillData.TargetInsId

    local caster = GetEntityByInsId(casterInsId)
    if not caster then
        return
    end

    local position = self:GetNewPosition()
    DrawDebugFan(position, self._selectRadius, 360, Vector(1,0,0), 0.2 ,Vector(0, 255, 0))

    ---@type table<integer, CUnitBase>
---@diagnostic disable-next-line: assign-type-mismatch
    local units = Units:GetUnitsByArea(position,self._selectRadius,nil,true)
    local selectTargetInsId = 0
    local minDistance = 100000
    local camp = self:GetSkill():GetSkillTableLine().DamageType
    local unitList = {}
    for _, unit in pairs(units) do
        ---@type integer
---@diagnostic disable-next-line: assign-type-mismatch
        local entityInsId = unit:GetInsid()
        if targetInsId ~= entityInsId then
            local check = true
            if self._checkHited and doSkillData.HitedEntityList then
                check = table.ContainValue(doSkillData.HitedEntityList , entityInsId, nil,nil) == 0
            end
            if check then
                local entityCamp = unit:GetCamp()
                if entityCamp ~= 0 then
                    if camp == 0
                        or (camp == SettlementCampType.DIF_CAMP and caster:GetCamp() ~= entityCamp)
                        or (camp == SettlementCampType.SAME_CAMP and caster:GetCamp() == entityCamp) then
                        table.insert(unitList,unit)
                    end
                end
            end
        end
    end
    if #unitList > 0 then
        if self._selectNearest then
            for _, unit in pairs(unitList) do
                local entity = GetEntityByInsId(unit:GetInsid())
                if entity then
                    local distance = (position - entity:GetPosition()):Length()
                    if distance < minDistance then
                        minDistance = distance
                        selectTargetInsId = unit:GetInsid()
                    end
                end
            end
        else
            -- 随机先选择一个
            selectTargetInsId = unitList[math.random(1,#unitList)]:GetInsid()
        end
    end

    DebugSKillLog_DoSkillData(DebugSKillLogLayer.All, "ineEventTargetSelectNew Invoke selectTargetInsId" , {selectTargetInsId})
    if selectTargetInsId > 0 then
        self:SetTarget(selectTargetInsId)
        SkillManagerInstance:AddHitedEntityList(doSkillData, selectTargetInsId)
    else
        -- 没有目标技能结束
        SkillManagerInstance:DoFinishSkill(self:GetSkill())
    end
end