--[[ 
Buff转移事件模块
负责管理技能释放过程中的Buff转移事件
包括从施法者向目标转移指定类型的Buff
支持转移Debuff、全部类型Buff或特定BuffId
提供事件注册、更新、执行和清理的功能
可配置转移的Buff数量和类型
--]]

---@class LineEventTransferbuff : SkillLineEvent
LineEventTransferbuff = Classnew("LineEventTransferbuff" , SkillLineEvent)

function LineEventTransferbuff:ctor(skill,eventType , config,timeLineIndex)
    SkillLineEvent.ctor(self,skill,eventType, config,timeLineIndex)

    self._isTransfer = tonumber(self._config[3]) == 0
    -- 0是Debuff 1是全部类型 2 指定BuffId
    self._p1 = tonumber(self._config[4])
    -- 0为全部数量
    self._p2 = tonumber(self._config[5])
    -- 是否反转
    self._p3 = self._config[6] and tonumber(self._config[6]) or 0
end

function LineEventTransferbuff:OnInvoke()
    local doSkillData = self:GetDoSkillData()
    local casterInsId = doSkillData.CasterInsId
    local targetInsId = doSkillData.TargetInsId
    if self._p3 == 1 then
        casterInsId, targetInsId = targetInsId, casterInsId
    end

    local buffs = BuffManagerInstance:GetEntityBuffs(casterInsId)
    local count = self._p2 or 0
    
    -- 先收集需要处理的Buff
    local buffsToProcess = {}
    for buffId, buff in pairs(buffs) do
        local buffLineTable = buff:GetBuffTableLine()

        local isPass = false
        if self._p1 == 2 then  -- 指定BuffId
            if buffId == self._p2 then
                isPass = true
            end
        else  -- Debuff或全部类型
            if (self._p1 == 0 and buffLineTable.GainOrDeBuff == -1)
                or self._p1 == 1 then
                if self._p2 > 0 then
                    if count > 0 then
                        isPass = true
                        count = count - 1
                    end
                else  -- 全部数量
                    isPass = true
                end
            end
        end
        
        if isPass then
            table.insert(buffsToProcess, {
                buffId = buffId,
                buff = buff
            })
        end
        
        -- 如果有数量限制且已达到限制，跳出循环
        if self._p2 > 0 and count <= 0 then
            break
        end
    end
    
    -- 处理收集的Buff
    for _, buffData in ipairs(buffsToProcess) do
        local buffId = buffData.buffId
        local buff = buffData.buff
        local doBuffData = buff:GetDoBuffData()
        
        BuffManagerInstance:RemoveBuff(casterInsId, buffId)
        if self._isTransfer then
            doBuffData.EntityId = targetInsId
            BuffManagerInstance:AddBuff(doBuffData)
        end
    end
end