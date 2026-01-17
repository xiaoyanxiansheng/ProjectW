--[[ 
目标选择事件模块
负责管理技能释放过程中的目标选择事件序列
包括目标选择的方式和条件
提供目标选择事件的注册、更新和执行功能
支持目标选择的不同策略和条件
--]]

---@class LineEventTargetSelect : SkillLineEvent
LineEventTargetSelect = Classnew("LineEventTargetSelect" , SkillLineEvent)

function LineEventTargetSelect:ctor(skill,eventType , config,timeLineIndex)
    SkillLineEvent.ctor(self,skill,eventType, config,timeLineIndex)

    -- 跟随类型
    ---@type table
    local ps = string.split_lite(tostring(self._config[3]),"_")
    self._followType = tonumber(ps[1])
    self._followTypeP1 = ps[2] and tonumber(ps[2]) or 0
    -- 选择半径
    ---@type number
---@diagnostic disable-next-line: assign-type-mismatch
    self._selectRadius = tonumber(self._config[4])
    -- 检测是否已经击中过
    self._checkHited = tonumber(self._config[5]) == 1
    -- 如果不选择最近的就随机
    self._selectNearest = tonumber(self._config[6]) == 1
end

function LineEventTargetSelect:OnInvoke()
    local doSkillData = self:GetDoSkillData()
    local casterInsId = doSkillData.CasterInsId
    local targetInsId = doSkillData.TargetInsId
    local skillId = doSkillData.SkillId

    local caster = GetEntityByInsId(casterInsId)
    if not caster then
        return
    end

    local position = self:GetTargetPosition(self._followType,self._followTypeP1)
    DrawDebugFan(position, self._selectRadius, 360, Vector(1,0,0), 0.2 ,Vector(0, 255, 0))

    ---@type table<integer, CUnitBase>
---@diagnostic disable-next-line: assign-type-mismatch
    local units = Units:GetUnitsByArea(position,self._selectRadius,nil,true)
    local selectTargetInsId = 0
    local minDistance = 100000
    local camp = self:GetSkill():GetSkillTableLine().DamageType
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
                        if self._selectNearest then
                            local entity = GetEntityByInsId(entityInsId)
                            if entity then
    ---@diagnostic disable-next-line: undefined-field
                                local distance = (position - entity:GetPosition()):Length()
                                if distance < minDistance then
                                    minDistance = distance
                                    selectTargetInsId = entityInsId
                                end
                            end
                        else
                            selectTargetInsId = entityInsId
                            break
                        end
                    end
                end
            end
        end
    end

    if selectTargetInsId > 0 then
        self:SetTarget(selectTargetInsId)
        SkillManagerInstance:AddHitedEntityList(doSkillData, selectTargetInsId)
    else
        -- 没有目标技能结束
        SkillManagerInstance:DoFinishSkill(self:GetSkill())
    end
end