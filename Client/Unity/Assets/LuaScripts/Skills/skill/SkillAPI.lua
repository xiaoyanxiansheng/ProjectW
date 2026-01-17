---@diagnostic disable: undefined-field, undefined-global, undefined-doc-class, undefined-doc-name
--[[ 
技能API模块
提供技能系统的对外接口和数据结构定义
包含技能事件触发、技能数据结构和技能操作的公共方法
作为技能系统与其他模块交互的桥梁，提供统一的接口调用方式
--]]

---@class SkillAPI
SkillAPI = {}

---触发技能事件
---@param message_type MsgConst
---@param params any
function SkillAPI.DoEvent(message_type, params)
    local msg = BeginMessage(message_type)
    msg.params = params
    SendMessage(msg)
end

--------------------------------------- 技能 ----------------------------------------------
DoSkillDataPosition = Classnew("DoSkillDataPosition", nil)
---@class DoSkillDataPosition
---@field public CasterInsId integer 施法者
---@field public TargetInsId  integer 被施法者
---@field public StartPosition Vector 施法位置 可能和施法者位置相同
---@field public EndPosition Vector|nil 结束位置
function DoSkillDataPosition:ctor()
    self.CasterInsId = nil
    self.TargetInsId = nil
    self.StartPosition = nil
    self.EndPosition = nil
end

function DoSkillDataPosition:Init(casterInsId, targetInsId, startPosition, endPosition)
    self.CasterInsId = casterInsId
    self.TargetInsId = targetInsId
    self.StartPosition = startPosition
    self.EndPosition = endPosition
    if self.StartPosition == nil then
        self.StartPosition = GetEntityPosition(self.CasterInsId)
    end
    if self.EndPosition == nil then
        self.EndPosition = GetEntityPosition(self.TargetInsId)
    end
end

function DoSkillDataPosition:SetTargetInsId(targetInsId)
    self.TargetInsId = targetInsId
    self.EndPosition = GetEntityPosition(self.TargetInsId)
end

---@class DoSkillData : Classnew
---@field public CasterInsId integer
---@field public TargetInsId  integer
---@field public SkillId  integer
---@field public SkillLevel  integer
---@field public Position  Vector
---@field public StartPosition Vector
---@field public StartAgentId integer
---@field public ParentSkill SkillLogic | nil
---@field public HitedEntityList table
---@field public AgentInsId integer
---@field public AgentInsSpeed number
---@field public FinishLoopCount integer
---@field public NewFinishLoopCount integer
DoSkillData = Classnew("DoSkillData", nil)
function DoSkillData:ctor()
    -- 外部使用
    self.CasterInsId = 0        -- 施法者
    self.TargetInsId = 0        -- 被施法者|0
    self.SkillId = 1            -- 技能Id
    self.SkillLevel = 1         -- 技能等级
    self.Position = nil         -- 施法位置|nil

    -- 内部使用
    self.ParentSkill = nil      -- 父技能|nil
    self.StartPosition = nil    -- 技能开始的位置|nil
    self.StartAgentId = nil     -- 代理开始|nil
    self.AgentInsId = nil       -- 代理结束|nil
    self.AgentInsSpeed = 0      -- 代理速度
    self.HitedEntityList = nil  -- 已经击中列表|nil
    self.FinishLoopCount = -1   -- 生命周期次数
    self.NewFinishLoopCount = -1 -- 新生命周期次数
    self.DefaultNewFinishLoopCount = -1 -- 默认新生命周期次数
    self.EffectTimes = 1        -- 效果倍数
    self.GP = nil               -- 给被动使用
    self.IsOptimized = false   -- 是否优化

    -- 为了兼容 重新定义一套位置系统
    self.PositionNew = DoSkillDataPosition.New()
    self.IsManual = false -- 是否是手动释放

    -- 一些数据
    self.CasterCamp = 0
    self.TargetCamp = 0
end

function DoSkillData:Copy(doSkillData)
    -- 外部使用
    self.CasterInsId = doSkillData.CasterInsId        -- 施法者
    self.TargetInsId = doSkillData.TargetInsId        -- 被施法者|0
    self.SkillId = doSkillData.SkillId            -- 技能Id
    self.SkillLevel = doSkillData.SkillLevel         -- 技能等级
    self.Position = doSkillData.Position         -- 施法位置|nil

    -- 内部使用
    self.ParentSkill = doSkillData.ParentSkill      -- 父技能|nil
    self.StartPosition = doSkillData.StartPosition    -- 技能开始的位置|nil
    self.StartAgentId = doSkillData.StartAgentId     -- 代理开始|nil
    self.AgentInsId = doSkillData.AgentInsId       -- 代理结束|nil
    self.AgentInsSpeed = doSkillData.AgentInsSpeed      -- 代理速度
    self.HitedEntityList = doSkillData.HitedEntityList  -- 已经击中列表|nil
    self.FinishLoopCount = doSkillData.FinishLoopCount   -- 生命周期次数
    self.NewFinishLoopCount = doSkillData.NewFinishLoopCount -- 新生命周期次数
    self.DefaultNewFinishLoopCount = doSkillData.DefaultNewFinishLoopCount -- 默认新生命周期次数
    self.EffectTimes = doSkillData.EffectTimes        -- 效果倍数
    self.GP = doSkillData.GP               -- 给被动使用

    -- 为了兼容 重新定义一套位置系统
    self.PositionNew = DoSkillDataPosition.New()
    self.IsManual = doSkillData.IsManual or false -- 是否是手动释放
    
    -- 一些数据
    self.CasterCamp = doSkillData.CasterCamp
    self.TargetCamp = doSkillData.TargetCamp
end

function DoSkillData:InitNewPosition()
    self.PositionNew:Init(self.CasterInsId, self.TargetInsId, self.StartPosition, self.Position)
end

-- 获取技能的根技能ID
-- 如果当前技能有父技能，则递归向上查找父技能
-- 直到找到最顶层的技能，返回其ID
-- 如果没有找到有效技能，返回-1
function DoSkillData:GetSkillId()
    local skill = self
    while true do
        if skill.ParentSkill then
            skill = skill.ParentSkill:GetDoSkillData()
        else
            break
        end
    end
    return skill and skill.SkillId or -1
end

-- 释放技能
---@param doSkillData DoSkillData
function SkillAPI.DoSkill(doSkillData)
    doSkillData.IsManual = true -- 设置为手动释放
    DebugSKillLog_DoSkillData(DebugSKillLogLayer.All, "SkillAPI.DoSkill",doSkillData)
    SkillManagerInstance:DoSkill(doSkillData)
end

-- 打断技能 打断当前的所有技能
---@param insId integer        实体 InsId
---@param forceBreak boolean | nil      强行打断
function SkillAPI.BreakSkill(insId , forceBreak)
    if forceBreak then
        SkillManagerInstance:BreakSkill(insId)
    else
        SkillManagerInstance:CanBreakSkill(insId)
    end
end

-- 是否在释放技能阶段
---@param casterInsId integer       技能释放者 InsId
function SkillAPI.CheckEntityInSKill(casterInsId)
    return SkillManagerInstance:InSkill(casterInsId)
end

-- 获取普通攻击的伤害提升倍数 默认:1倍
---@return number
function SkillAPI.GetAttackContinueDamage(insId, targetInsId)
    -- 连续攻击伤害倍数
    local continueSkillTimes = BuffManagerInstance:GetContinueSkillEffect(insId , 1)
    -- 攻击数量伤害倍数
    local hitCountDamageTimes = BuffManagerInstance:GetHitCountDamageTimes(insId , 1)
    -- 目标身上debuff数量伤害倍数
    local debuffCountDamageTimes = BuffManagerInstance:GetHitDebuffCountTimes(targetInsId)
    -- 攻击伤害倍率
    local attackDamageTimes = BuffManagerInstance:GetAttackDamageTimes(insId)
    return continueSkillTimes * hitCountDamageTimes * debuffCountDamageTimes * attackDamageTimes
end

--------------------------------------- 被动技能 ----------------------------------------------
-- 增加被动
---@param insId integer 实体 InsId
---@param passiveSkillId integer 被动Id
---@param passiveSkillLevel integer 被动等级
function SkillAPI.AddPassiveSkill(insId , passiveSkillId, passiveSkillLevel)
    PassiveSkillManagerInstance:Add(insId, passiveSkillId, passiveSkillLevel)
end

-- 删除被动
---@param insId integer 实体 InsId
---@param passiveSkillId integer 被动Id
function SkillAPI.RemovePassiveSkill(insId , passiveSkillId)
    PassiveSkillManagerInstance:Remove(insId , passiveSkillId)
end

-- 删除所有被动
---@param insId integer 实体 InsId
function SkillAPI.RemovePassiveSkillAll(insId)
    PassiveSkillManagerInstance:RemoveAll(insId)
end

-- 是否学习过被动技能
---@param insId integer 实体 InsId
---@param passiveSkillId integer 被动技能Id
---@return boolean
function SkillAPI.IsLearnedPassiveSkill(insId , passiveSkillId)
    return PassiveSkillManagerInstance:IsLearnedPassiveSkill(insId , passiveSkillId)
end

-- 获取实体学习过的被动技能ID列表
---@param insId integer 实体ID
---@return integer[] 被动技能ID列表
function SkillAPI.GetLearnedPassiveSkillIds(insId)
    return PassiveSkillManagerInstance:GetLearnedPassiveSkillIds(insId)
end

-- 获取实体的技能数据
---@param insId integer 实体ID
---@param skillId integer 技能ID
---@return DoSkillData | nil
function SkillAPI.GetDoSkillData(insId, skillId)
    return SkillManagerInstance:GetDoSkillData(insId, skillId)
end

-- ---@param insId integer 实体 InsId
-- ---@return [number,number] | nil @[每多一个敌人减少的伤害，减少伤害的上限]
-- function SkillAPI.GetAttackDamage(insId)
--     return PassiveSkillManagerInstance:GetTriggerAttackDamage(insId)
-- end
--------------------------------------- Buff ----------------------------------------------

---@param insId integer
---@param buffId integer
---@param buffLevel integer
---@param initStackCount integer|nil
---@param modifyBuffCall function|nil
function SkillAPI.AddEntityBuff(insId , buffId , buffLevel , initStackCount , modifyBuffCall)
    local doBuffData = DoBuffData.New()
    doBuffData.EntityId = insId
    doBuffData.BuffId = buffId
    doBuffData.BuffLevel = buffLevel
    doBuffData.InitStackCount = initStackCount or 1
    BuffManagerInstance:AddBuff(doBuffData, modifyBuffCall)
end

---@param insId integer
---@param buffId integer
function SkillAPI.RemoveEntityBuff(insId , buffId)
    BuffManagerInstance:RemoveBuff(insId , buffId)
end

-- 获取实体Buff列表
---@description 获取指定实体身上的所有Buff列表，可以根据增益/减益类型进行过滤
---@param insId integer 实体 InsId
---@param gainorde integer 0 全部 -1 减益 1 增益
---@return table[] 返回buff信息列表，每个元素包含以下字段:
function SkillAPI.GetEntityBuffs(insId , gainorde)
    -- 初始化返回的buff列表
    local buffs = {}
    -- 从BuffManager获取实体所有的buff
    local buffClasss = BuffManagerInstance:GetEntityBuffs(insId)
    if buffClasss then
        -- 遍历所有buff
        for _, buffClass in pairs(buffClasss) do
            if buffClass then
                -- 获取buff的基本信息
                local buffId = buffClass:GetDoBuffData().BuffId
                -- 获取buff配置
                local config = GetBuffLine(buffId)
                -- 根据增益/减益类型过滤
                -- gainorde为0时获取全部，否则需要匹配buff的增益/减益类型
                if (gainorde == 0 or gainorde == config.GainOrDeBuff) then --and config.ClientShow == 1 then
                    -- 获取buff等级和叠加层数
                    local buffLevel = buffClass:GetDoBuffData().BuffLevel
                    local stack = buffClass:GetStackCount()
                    -- 将buff信息添加到返回列表中
                    table.insert(buffs,{insid=insId,buffid=buffId,bufflevel=buffLevel,stack=stack})
                end
            end
        end
    end
    return buffs
end

-- 获取指定实体的指定Buff
---@param insId integer
---@param buffId integer
---@return NewBuff | nil
function SkillAPI.GetEntityBuff(insId , buffId)
    return BuffManagerInstance:GetEntityBuff(insId , buffId)
end

-- 是否可以移动
-- 被动移动中 不可位移状态
---@param insId integer       实体 InsId
function SkillAPI.CheckEntityMove(insId)
    local displacement = BuffManagerInstance:InEventState(insId , BuffEvent.Displacement)
    local cantDisplacement = BuffManagerInstance:InEventState(insId , BuffEvent.CantDisplacement)
    local cantCantDisplacement = BuffManagerInstance:InEventState(insId , BuffEvent.CantCantDisplacement)
    local fear = BuffManagerInstance:InEventState(insId , BuffEvent.Fear)
    return (not fear) and (not displacement) and ((not cantDisplacement) or (cantDisplacement and  cantCantDisplacement))
end

-- 是否可以释放技能
-- 被动移动中 不可施法
---@param casterInsId integer       技能释放者 InsId
---@param skillId integer|nil       技能 Id
function SkillAPI.CheckEntityDoSKill(casterInsId, skillId)
    if skillId and skillId ~= 0 then
        local skillTable = GetSkillLine(skillId)
        if skillTable then
            if skillTable.DoIgnoreBuffs and skillTable.DoIgnoreBuffs == 1 then
                return true
            end
        end
    end

    local cantMagic = BuffManagerInstance:InEventState(casterInsId, BuffEvent.CantMagic)
    local cantCantMagic = BuffManagerInstance:InEventState(casterInsId, BuffEvent.CantCantMagic)
    local fear = BuffManagerInstance:InEventState(casterInsId, BuffEvent.Fear)
    return ((not cantMagic) or (cantMagic and cantCantMagic)) and (not fear)
end

-- 实体是否可以被选中
---@param insId integer       Entity InsId
function SkillAPI.CheckEntityCantSelect(insId)
    return BuffManagerInstance:InEventState(insId , BuffEvent.CantSelect)
end

-- 是否能进行普通攻击
function SkillAPI.CheckEntityCanNormalAttack(insId)
    local cantNormalAttack = BuffManagerInstance:InEventState(insId , BuffEvent.CantNormalAttack)
    local cantCantNormalAttack = BuffManagerInstance:InEventState(insId , BuffEvent.CantCantNormalAttack)
    local fear = BuffManagerInstance:InEventState(insId, BuffEvent.Fear)
    return ((not cantNormalAttack) or (cantNormalAttack and cantCantNormalAttack)) and (not fear)
end

-- 获取锁血状态
---@param insId integer 实体Id
---@return boolean 是否处于锁血状态
function SkillAPI.CheckEntityHealthLock(insId)
    local state = BuffManagerInstance:InEventState(insId, BuffEvent.HealthLock)
    return state
end

-- 获取伤害反弹状态
---@param insId integer 实体Id
---@return boolean 是否处于普攻伤害反弹状态
function SkillAPI.CheckEntityDamageRebound(insId)
    local state = BuffManagerInstance:InEventState(insId, BuffEvent.DamageRebound)
    return state
end

-- 获取技能伤害反弹状态
---@param insId integer 实体Id
---@return boolean 是否处于技能伤害反弹状态
function SkillAPI.CheckEntitySkillDamageRebound(insId)
    local state = BuffManagerInstance:InEventState(insId, BuffEvent.SkillDamageRebound)
    return state
end

-- 获取复活状态
---@param insId integer 实体Id
---@return boolean 是否处于复活状态
function SkillAPI.CheckEntityRevive(insId)
    local state = BuffManagerInstance:InEventState(insId, BuffEvent.Revive)
    return state
end

-- 获取血魔转化比例
---@param insId integer 实体Id
---@return number 血魔转化比例 0 表示没有血魔转化
function SkillAPI.GetDamageHPMP(insId)
    return BuffManagerInstance:GetDamageHPMP(insId)
end

-- 获取禁止恢复的属性列表
---@param insId integer 实体Id
---@return integer[] 禁止恢复的属性列表
function SkillAPI.GetCantRecoverAttrList(insId)
    return BuffManagerInstance:GetCantRecoverAttrList(insId)
end

-- 获取实体Buff属性 Buff增量的数值
-- 返回一个包含buff属性修改信息的表:
-- value: 固定值增减
-- ratio: 百分比增减
-- convert: 属性转换列表,每项包含:
--   - insid: 目标实体id
--   - attrId: 目标属性id  
--   - ratio: 来源转换比例
--   - toratio: 目标转换比例（计算后的增量属性每点转换为目标属性的比例）,如果存在
-- set: 属性设置值,存在时直接设置属性为此值
---@param insId integer 实体 InsId
---@param attrId integer 属性Id
---@return table | nil {value=0, ratio=0 , convert={insid=0,attrId=0,ratio=0.2}[], set=0|nil , toratio=0|nil}
function SkillAPI.GetEntityBuffAttr(insId , attrId)
    return BuffManagerInstance:GetAttr(insId , attrId)
end

-- 返回效果共享的实体Id列表
---@param insId integer 实体Id
---@return table<integer,integer[]> @table<buffId,insId[]>
function SkillAPI.GetEffectShareInsIds(insId)
    return BuffManagerInstance:GetEffectShareInsIds(insId)
end

-- 获取实体的护盾值
---@param insId integer 实体Id
---@return number 护盾值
function SkillAPI.GetTotalShieldValue(insId)
    return BuffManagerInstance:GetTotalShieldValue(insId)
end

-- 清空实体的护盾值
---@param insId integer 实体Id
function SkillAPI.ClearEntityShield(insId)
    BuffManagerInstance:ClearEntityShield(insId)
end

-- 获取实体的自定义Buff状态
---@param insId integer 实体Id
---@return table<integer,any[][]> | nil ---@ integer:buffId, any[][]:表格中定义的参数
function SkillAPI.GetEntityCustomBuffState(insId)
    return BuffManagerInstance:GetState(insId)
end

-- 获取实体的攻击伤害倍率
---@param entityId integer 实体ID
---@return number 攻击伤害倍率
function SkillAPI.GetAttackDamageTimes(entityId)
    return BuffManagerInstance:GetAttackDamageTimes(entityId)
end

-- 清空技能模块
function SkillAPI.Clear()
    SkillModule.Clear()
end