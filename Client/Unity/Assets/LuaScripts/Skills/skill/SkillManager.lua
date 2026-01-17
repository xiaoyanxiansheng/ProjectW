-- 技能管理器
-- 负责管理游戏中所有技能的创建、释放、更新和结束
-- 维护实体与技能的关联关系，处理技能的生命周期
-- 支持技能链、子技能和循环技能的管理
-- 提供技能状态查询和打断功能

-- 技能结束的两种模式:
-- 1. 外部结束: 通过SkillId指定要结束的技能，由外部系统触发
-- 2. 内部结束: 通过Skill对象直接结束，由技能自身逻辑或时间轴触发

require("critcore.skill.SKillLogic")

---@class SKillManager : Classnew
SkillManager = Classnew("SkillManager" , nil)

---构造函数，初始化技能管理器
function SkillManager:ctor()
    self._entitySkillList = {}

    self._delayedChildSkillList = {} -- 持续时间技能列表

    self._pool = PoolManagerInstance:CreateAndRegister("Skill",self, self.PoolCreateCall)

    -- 技能命中追踪
    self._skillHitTracking = {}      -- {[mainSkillInsId] = {hitUnits={}, allSkills={}, finishedSkills={}}}
    self._skillToMainMapping = {}    -- {[skillInsId] = mainSkillInsId}

    RegisterMessage(MsgConst.SKILL_ENTER_CD, self.MSG_SKILL_ENTER_CD, self)
    RegisterMessage(MsgConst.ENTITY_DEATH_2 , self.MSG_ENTITY_DEATH , self)
end

function SkillManager:PoolCreateCall(handle, doSkillData, skillTableLine, onStartSkill, onFinishSkill)
    return SkillLogic.New(handle, doSkillData, skillTableLine, onStartSkill , onFinishSkill)
end

function SkillManager:PoolGet(doSkillData, skillTableLine)
    return self._pool:Get(self, doSkillData, skillTableLine , self.OnStartSkill , self.OnFinishSkill)
end

function SkillManager:PoolBack(skill)
    self._pool:Back(skill)
end

---在某个位置释放技能
---@param doSkillData DoSkillData 技能释放数据
---@return SkillLogic|nil 技能逻辑对象
function SkillManager:DoSkill(doSkillData)
    if self:DoSkillOptimized(doSkillData) then
        return
    end

    local skill = self:DoSkillCore(doSkillData)
    return skill
end

function SkillManager:DoSkillCore(doSkillData)
    -- 初始化新位置
    doSkillData:InitNewPosition()

    ---@type SkillTableLine
    local skillTableLine = clone(GetSkillLine(doSkillData.SkillId))
    if not skillTableLine then
        print("SkillManager.DoSKill error 技能配置表中不存在 Id：", doSkillData.SkillId)
        return nil
    end

    if doSkillData.CasterInsId == 0 or doSkillData.SkillId == 0 then
        return nil
    end

    local caster = GetEntityByInsId(doSkillData.CasterInsId)
    if caster == nil then
        return nil
    end

    if not caster:IsAlive() then
        return nil
    end

    -- 释放技能
    local casterId = doSkillData.CasterInsId
    if not self._entitySkillList[casterId] then
        self._entitySkillList[casterId] = {}
    end
    ---@type SkillLogic
    local skill = self:PoolGet(doSkillData, skillTableLine)
    table.insert(self._entitySkillList[casterId],skill)

    -- 注册技能追踪
    self:RegisterSkillTracking(skill, doSkillData)

    self:AddSelfPassiveSkill(skill)

    -- 被动技能
    self:CheckPassiveSkill(PassiveSkillVariable.IsDoSkill, skill)

    -- 检测循环
    local hitLoopCount = GetConfDataLevel(skillTableLine.FinishLoopCount , doSkillData.SkillLevel)
    self:CheckLoop(doSkillData, hitLoopCount)

    skill:Init()

    DebugSKillLog_DoSkillData(DebugSKillLogLayer.All, "SkillManager:DoSkill doSkillData skillTableLine",skill:GetDoSkillData(),table.tostring(skillTableLine,nil,nil))
    skill:DoSkill()

    return skill
end

--- 优化的技能释放
---@param doSkillData DoSkillData 技能释放数据
---@return boolean 是否优化
function SkillManager:DoSkillOptimized(doSkillData)
    if doSkillData.ParentSkill and doSkillData.IsOptimized then
        -- 随机0-0.1秒延迟
        local delay = math.random(0, 100) / 500.0
        table.insert(self._delayedChildSkillList, {doSkillData,delay})
        return true
    end
    return false
end

---结束指定技能
---@param skill SkillLogic 要结束的技能逻辑对象
---@param isNoEndSon boolean|nil 是否不结束子技能
function SkillManager:DoFinishSkill(skill , isNoEndSon)
    if not skill then
        return
    end

    local casterInsId = skill:GetDoSkillData().CasterInsId
    local inIndex = table.ContainValue(self._entitySkillList[casterInsId],skill,nil,nil)
    if inIndex == 0 then
        return
    end
    
    table.remove(self._entitySkillList[casterInsId], inIndex)
    skill:Finish(false, isNoEndSon)
    DebugSKillLog_DoSkillData(DebugSKillLogLayer.All, "SkillManager:DoFinishSkill doSkillData",skill:GetDoSkillData())
end

---添加技能自身的被动效果
---@param skill SkillLogic 技能逻辑对象
function SkillManager:AddSelfPassiveSkill(skill)
    local doSkillData = skill:GetDoSkillData()
    local skillTableLine = skill:GetSkillTableLine()
    if skillTableLine.SkillPassiveId == nil or skillTableLine.SkillPassiveId == 0 then
        return
    end
    PassiveSkillManagerInstance:Add(doSkillData.CasterInsId, skillTableLine.SkillPassiveId,doSkillData.SkillLevel)
end

---检查技能的被动效果
---@param skill SkillLogic 技能逻辑对象
function SkillManager:CheckPassiveSkill(passiveSkillVariable , skill)
    local casterId = skill:GetDoSkillData().CasterInsId
    local condition = PassiveSkillManagerInstance:TRIGGERCONDITION(passiveSkillVariable,casterId,nil,skill,nil,nil)
    PassiveSkillManagerInstance:ModifySkill(skill, condition)
end

---检查技能循环次数
---@param doSkillData DoSkillData 技能释放数据
---@param hitLoopCount integer 技能循环次数
function SkillManager:CheckLoop(doSkillData, hitLoopCount)
    if hitLoopCount == nil then
        return
    end

    local targetId = doSkillData.TargetInsId
    if not targetId then
        return
    end

    local target = GetEntityByInsId(targetId)
    if target == nil then
        return
    end
    if not target:IsAlive() then
        return
    end

    if doSkillData.FinishLoopCount ~= 0 then
        if doSkillData.FinishLoopCount == -1 then
            doSkillData.FinishLoopCount = hitLoopCount or 1
        else
            doSkillData.FinishLoopCount = doSkillData.FinishLoopCount - 1
        end
        self:AddHitedEntityList(doSkillData, targetId)
    end
end

---添加已击中的实体到列表中
---@param doSkillData DoSkillData 技能释放数据
---@param insId integer 实体ID
function SkillManager:AddHitedEntityList(doSkillData, insId)
    -- while(doSkillData.ParentSkill) do
    --     doSkillData = doSkillData.ParentSkill:GetDoSkillData()
    -- end

    if doSkillData.HitedEntityList == nil then
        doSkillData.HitedEntityList = {}
    end

    local inIndex = table.ContainValue(doSkillData.HitedEntityList,insId,nil,nil)
    if inIndex == 0 then
        table.insert(doSkillData.HitedEntityList,insId)
    end
end

---打断能打断的所有技能
---@param insId integer 实体ID
function SkillManager:CanBreakSkill(insId)
    if insId and self._entitySkillList[insId] then
        -- 先收集可以打断的技能到临时表中，避免在遍历过程中修改原表导致问题
        local skillsToBreak = {}
        for _, skill in pairs(self._entitySkillList[insId]) do
            if skill and skill:CanBreakSkill() then
                table.insert(skillsToBreak, skill)
            end
        end
        
        -- 遍历临时表来打断技能
        for _, skill in ipairs(skillsToBreak) do
            skill:Finish(false)
        end
    end
end

---打断指定实体的所有技能
---@param insId integer 实体ID
function SkillManager:BreakSkill(insId)
    if insId and self._entitySkillList[insId] then
        -- 先收集所有技能到临时表中，避免在遍历过程中修改原表导致问题
        local skillsToFinish = {}
        for _, skill in pairs(self._entitySkillList[insId]) do
            if skill then
                table.insert(skillsToFinish, skill)
            end
        end
        
        -- 遍历临时表来结束技能
        for _, skill in ipairs(skillsToFinish) do
            skill:Finish()
        end
        
        self._entitySkillList[insId] = nil
    end
end

--- 获取某个技能的技能逻辑对象
---@param skillId integer 技能ID
---@return SkillLogic|nil 技能逻辑对象
function SkillManager:GetSkillLogic(insId , skillId)
    if not self._entitySkillList[insId] then
        return nil
    end

    for _, skill in pairs(self._entitySkillList[insId]) do
        if skill:GetSkillId() == skillId then
            return skill
        end
    end
    return nil
end

function SkillManager:GetSkillCount(insId , skillId)
    if not self._entitySkillList[insId] then
        return 0
    end

    local count = 0
    for _, skill in pairs(self._entitySkillList[insId]) do
        if skill:GetSkillId() == skillId then
            count = count + 1
        end
    end

    return count
end

---更新所有技能状态
---@param delta number 时间增量
function SkillManager:Update(delta)
    -- 释放后要删除 持续时间技能列表（倒序遍历以安全删除）
    for i = #self._delayedChildSkillList, 1, -1 do
        local val = self._delayedChildSkillList[i]
        local doSkillData = val[1]
        local duration = val[2]
        duration = duration - delta
        if duration <= 0 then
            table.remove(self._delayedChildSkillList, i)
            self:DoSkillCore(doSkillData)
        else
            val[2] = duration
        end
    end

    for _, skills in pairs(self._entitySkillList) do
        for _, skill in pairs(skills) do
            if skill then 
                skill:Update(delta)
            end
        end
    end
end

---检查实体是否可以施法（不在不能施法或被位移状态）
---@param casterId integer 施法者ID
---@return boolean 是否可以施法
function SkillManager.CheckEntityDoSKill(casterId)
    local cantMagic = BuffManagerInstance:InEventState(casterId, BuffEvent.CantMagic)
    local displacement = BuffManagerInstance:InEventState(casterId, BuffEvent.Displacement)
    return not (cantMagic or displacement)
end

---检查实体是否有可以打断的技能
---@param entityId integer 实体ID
---@return boolean 是否有可以打断的技能
function SkillManager:CheckEntityCanBreakSkill(entityId)
    if not self._entitySkillList[entityId] then
        return false
    end

    for _, skill in pairs(self._entitySkillList[entityId]) do
        if skill ~= nil then
            if skill:CanBreakSkill() then
                return true
            end
        end
    end

    return false
end

---技能开始回调函数
---@param skill SkillLogic 技能逻辑对象
function SkillManager:OnStartSkill(skill)
    if not skill then
        return
    end

    local doSkillData = skill:GetDoSkillData()
    local casterInsId = doSkillData.CasterInsId
    local targetInsId = doSkillData.TargetInsId
    local skillId = doSkillData.SkillId
    local skillLevel = doSkillData.SkillLevel
    local position = doSkillData.Position
    local skillInsId = skill:GetSkillInsId()

    if skill:IsSubSkill() then
        return
    end

    if doSkillData.IsManual then
        local msg = BeginMessage(MsgConst.SKill_DO_START)
        msg.params = {casterinsid=casterInsId,skillid=skillId,skillinsid=skillInsId,skilllevel=skillLevel,targetinsid=targetInsId,position=position,skillcd=skill:GetSkillCD()}
        SendMessage(msg)
    end
end

---技能结束回调函数
---@param skill SkillLogic 技能逻辑对象
function SkillManager:OnFinishSkill(skill)
    if not skill then
        return
    end

    local doSkillData = skill:GetDoSkillData()
    local casterInsId = doSkillData.CasterInsId
    local targetInsId = doSkillData.TargetInsId
    local skillId = doSkillData.SkillId
    local skillLevel = doSkillData.SkillLevel
    local position = doSkillData.Position

    local skillTableLine = skill:GetSkillTableLine()
    if skillTableLine.SkillPassiveId ~= nil
        and skillTableLine.SkillPassiveId >= 0 then
        PassiveSkillManagerInstance:Remove(casterInsId,skillTableLine.SkillPassiveId)
    end

    LayeredAttributeSystem.Delete(skillTableLine)

    if not self._entitySkillList[casterInsId] then
        return
    end

    self:CheckPassiveSkill(PassiveSkillVariable.IsDoFinishSkill,skill)

    local inIndex = table.ContainValue(self._entitySkillList[casterInsId],skill,nil,nil)
    if inIndex > 0 then
        table.remove(self._entitySkillList[casterInsId],inIndex)
    end

    -- 标记技能完成并检查追踪
    local skillInsId = skill:GetSkillInsId()
    self:MarkSkillFinished(skillInsId)

    self:PoolBack(skill)

    -- 如果是子技能就不需要发送消息事件
    if skill:IsSubSkill() then
        return
    end

    -- 外部消息
    if doSkillData.IsManual then
        local msg = BeginMessage(MsgConst.SKill_DO_FINISH)
        msg.params = {casterinsid=casterInsId,skillid=skillId,skillinsid=skill:GetSkillInsId(),skilllevel=skillLevel,targetinsid=targetInsId,position=position}
        SendMessage(msg)
    end
end

---检查实体是否正在释放技能
---@param casterinsid integer 施法者ID
---@return boolean 是否正在释放技能
function SkillManager:InSkill(casterinsid)
    if casterinsid and self._entitySkillList[casterinsid] then
        return #self._entitySkillList[casterinsid] > 0
    end
    return false
end

function SkillManager:MSG_SKILL_ENTER_CD(msg)
    local insid = msg.params.insid
    local skillinsid = msg.params.skillinsid
    if self._entitySkillList[insid] then
        for _, skill in pairs(self._entitySkillList[insid]) do
            if skill and skill:GetSkillInsId() == skillinsid then
                self:CheckPassiveSkill(PassiveSkillVariable.IsSkillEnterCD, skill)
            end
        end
    end
end

function SkillManager:MSG_ENTITY_DEATH(msg)
    local insid = msg.params.insid
    SkillManagerInstance:BreakSkill(insid)
end

function SkillManager:DoSkillHelper(skillId,skillLevel,casterInsId,targetInsId,position)
    local doSkillData = DoSkillData.New()
    doSkillData.SkillId = skillId
    doSkillData.SkillLevel = skillLevel
    doSkillData.CasterInsId = casterInsId
    doSkillData.TargetInsId = targetInsId
    doSkillData.Position = position
    SkillManagerInstance:DoSkill(doSkillData)
end

function SkillManager:IsTimeLineSkill(skillId)
    local skillTableLine = GetSkillLine(skillId)
    return #(skillTableLine.TimeLine) > 0
end

function SkillManager:IsMainSkill(doSkillData)
    local isSkill = doSkillData.SkillId ~= 0 and doSkillData.SkillId ~= 1
    local isTimeLineSkill = self:IsTimeLineSkill(doSkillData.SkillId)
    local isNullParentSkill = doSkillData.ParentSkill == nil
    return isSkill and isTimeLineSkill and isNullParentSkill and doSkillData.IsManual
end

function SkillManager:Clear()
    -- 先收集所有技能到临时表中，避免在遍历过程中修改原表导致问题
    local allSkillsToFinish = {}
    for _, skills in pairs(self._entitySkillList) do
        for _, skill in pairs(skills) do
            if skill then
                table.insert(allSkillsToFinish, skill)
            end
        end
    end
    
    -- 遍历临时表来结束所有技能
    for _, skill in ipairs(allSkillsToFinish) do
        skill:Finish()
    end
    
    self._entitySkillList = {}
    self._delayedChildSkillList = {}

    -- 清理对象池
    self._pool:Clear()
end

function SkillManager:GetDoSkillData(insId, skillId)
    if not self._entitySkillList[insId] then
        return nil
    end

    for _, skill in pairs(self._entitySkillList[insId]) do
        if skill:GetSkillId() == skillId then
            return skill:GetDoSkillData()
        end
    end

    return nil
end

-- ========== 技能命中追踪系统 ==========

---注册技能到追踪系统
---@param skill SkillLogic 技能对象
---@param doSkillData DoSkillData 技能数据
function SkillManager:RegisterSkillTracking(skill, doSkillData)
    local skillInsId = skill:GetSkillInsId()
    
    -- 判断是否为主技能（没有ParentSkill）
    if not doSkillData.ParentSkill then
        -- 初始化主技能追踪
        self._skillHitTracking[skillInsId] = {
            hitUnits = {},                          -- 命中单位集合
            allSkills = {[skillInsId] = true},      -- 所有技能（包括主技能自己）
            finishedSkills = {},                    -- 已完成的技能
            casterInsId = doSkillData.CasterInsId,  -- 施法者ID
            skillId = doSkillData.SkillId,          -- 技能ID
            hasAreaHit = false,                     -- 是否发生过范围结算
        }
        self._skillToMainMapping[skillInsId] = skillInsId  -- 主技能映射到自己
    else
        -- 子技能：通过父技能的映射直接找到主技能（不追溯对象引用链）
        local parentInsId = doSkillData.ParentSkill:GetSkillInsId()
        local mainSkillInsId = self._skillToMainMapping[parentInsId]
        
        if mainSkillInsId and self._skillHitTracking[mainSkillInsId] then
            -- 注册子技能到主技能的追踪中
            self._skillHitTracking[mainSkillInsId].allSkills[skillInsId] = true
            self._skillToMainMapping[skillInsId] = mainSkillInsId
        else
            -- 父技能未注册到追踪系统，记录警告
            -- print("[WARNING] SkillManager:RegisterSkillTracking 父技能未在追踪系统中! ParentInsId=" .. parentInsId .. " ChildInsId=" .. skillInsId)
        end
    end
end

---记录技能命中单位
---@param skillInsId integer 技能实例ID
---@param targetInsId integer 目标单位ID
function SkillManager:RecordSkillHit(skillInsId, targetInsId)
    local mainSkillInsId = self._skillToMainMapping[skillInsId]
    if mainSkillInsId and self._skillHitTracking[mainSkillInsId] then
        self._skillHitTracking[mainSkillInsId].hitUnits[targetInsId] = 1
    end
end

---标记技能发生了范围结算
---@param skillInsId integer 技能实例ID
function SkillManager:MarkAreaHit(skillInsId)
    local mainSkillInsId = self._skillToMainMapping[skillInsId]
    if mainSkillInsId and self._skillHitTracking[mainSkillInsId] then
        self._skillHitTracking[mainSkillInsId].hasAreaHit = true
    end
end

---标记技能完成
---@param skillInsId integer 技能实例ID
function SkillManager:MarkSkillFinished(skillInsId)
    local mainSkillInsId = self._skillToMainMapping[skillInsId]
    if not mainSkillInsId or not self._skillHitTracking[mainSkillInsId] then
        return
    end
    
    local tracking = self._skillHitTracking[mainSkillInsId]
    tracking.finishedSkills[skillInsId] = true
    
    -- 检查是否所有技能都完成
    self:CheckAndFinishTracking(mainSkillInsId)
end

---检查追踪是否完成并触发回调
---@param mainSkillInsId integer 主技能实例ID
function SkillManager:CheckAndFinishTracking(mainSkillInsId)
    local tracking = self._skillHitTracking[mainSkillInsId]
    if not tracking then
        return
    end
    
    -- 检查是否所有技能都已完成
    for skillInsId, _ in pairs(tracking.allSkills) do
        if not tracking.finishedSkills[skillInsId] then
            return  -- 还有未完成的技能
        end
    end
    
    -- 只有发生过范围结算时才统计和发送消息
    if tracking.hasAreaHit then
        -- 统计命中数量
        local hitCount = 0
        for _, _ in pairs(tracking.hitUnits) do
            hitCount = hitCount + 1
        end
        
        -- 获取技能信息（在清理之前）
        local casterInsId = tracking.casterInsId
        local skillId = tracking.skillId
        
        -- 清理追踪数据
        self:ClearSkillTracking(mainSkillInsId)

        -- 发送统计消息
        local msg = BeginMessage(MsgConst.SKILL_HIT_UNIT_COUNT)
        msg.params = {casterinsid=casterInsId,skillid=skillId,hitcount=hitCount}
        SendMessage(msg)

    else
        -- 没有范围结算，只清理数据不发送消息
        self:ClearSkillTracking(mainSkillInsId)
    end
end

---清理技能追踪数据
---@param mainSkillInsId integer 主技能实例ID
function SkillManager:ClearSkillTracking(mainSkillInsId)
    local tracking = self._skillHitTracking[mainSkillInsId]
    if not tracking then
        return
    end
    
    -- 清理反向映射
    for skillInsId, _ in pairs(tracking.allSkills) do
        self._skillToMainMapping[skillInsId] = nil
    end
    
    -- 清理主追踪数据
    self._skillHitTracking[mainSkillInsId] = nil
end