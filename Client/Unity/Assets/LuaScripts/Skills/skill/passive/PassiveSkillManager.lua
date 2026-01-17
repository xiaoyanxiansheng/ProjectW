--[[ 
被动技能管理器模块
负责管理和处理游戏中的被动技能系统
包括被动技能的触发条件检查、效果应用和状态维护
提供被动技能的注册、触发和修改接口
作为被动技能系统的核心控制器，协调被动技能与其他游戏系统的交互
--]]

require("critcore.skill.passive.PassiveSkill")

---@class PassiveSkillManager : Classnew
PassiveSkillManager = Classnew("PassiveSkillManager" , nil)

-- 被动技能变量定义，用于条件判断和触发检查
-- 配置表中配置实例
PassiveSkillVariable = {
    -- 类型
    IsDoSkill           = "isdoskill",          -- 是否释放技能
    IsDoFinishSkill     = "isdofinishskill",   -- 是否结束技能
    IsSkillEnterCD      = "isskillentercd",     -- 是否技能进入CD
    IsDoSettlement      = "isdosettlement",     -- 是否结算
    IsAddBuff           = "isaddbuff",          -- 是否添加Buff
    IsUpdateBuff        = "isupdatebuff",       -- 是否更新Buff
    IsFinishedBuff      = "isfinishedbuff",     -- 是否结束Buff
    IsAddPassive        = "isaddpassive",       -- 添加被动
    IsPassiveUpdate     = "ispassiveupdate",    -- 被动更新
    IsHit               = "ishit",              -- 击中
    IsHitRcv            = "ishitrcv",           -- 受击
    IsCritical          = "iscritical",         -- 暴击
    IsKill              = "iskill",             -- 击杀
    IsDeath             = "isdeath",            -- 死亡
    IsDamage            = "isdamage",           -- 伤害
    IsHPChange          = "ishpchange",         -- 血量变化
    IsShieldChange      = "isshieldchange",     -- 护盾变化

-- 公用参数
    CasterIns           = "casterins",          -- 施法者
    TargetIns           = "targetins",          -- 受击者
    SkillIns            = "skillins",           -- 技能
    SettlementIns       = "settlementins",      -- 结算
    PassiveIns          = "passiveins",         -- 被动
    BuffIns             = "buffins",            -- buff
    LearnedPassive      = "learnedpassive",     -- 学习过被动
    LearnedBuff         = "learnedbuff",        -- 学习过buff

--专用
    HPChangeIns         = "hpchangeins",        -- 血量变化专用
    ShieldChangeIns     = "shieldchangeins",    -- 护盾变化专用
    SettlementCount     = "settlementcount",    -- 击中专用
    SettlementInsList   = "settlementinslist",  -- 受击专用
    SupposedDie         = "supposeddie",       -- 本应该死亡
    MoveDistance        = "movedistance",       -- 移动距离（技能绑定被动）
    MoveSpeed           = "movespeed",          -- 移动速度（技能绑定被动）
}

learnedpassive = nil
---@diagnostic disable-next-line: lowercase-global
learnedbuff = nil
-- 初始化设置
function PassiveSkillManager:Setup()
    learnedpassive = function(insId, passiveId)
        return PassiveSkillManagerInstance:IsLearnedPassiveSkill(insId, passiveId)
    end
---@diagnostic disable-next-line: lowercase-global
    learnedbuff = function(insId, buffId)
        return BuffManagerInstance:IsEntityBuff(insId, buffId)
    end
end

-- 构造函数，初始化被动技能管理器
function PassiveSkillManager:ctor()
    ---@type table<integer,table<integer,PassiveSkill>>
    self._passiveSkillList = {}  -- 存储所有实体的被动技能列表
    self._stringCache = {}       -- 字符串缓存，用于优化性能

    -- 注册消息监听
    -- RegisterMessage(MsgConst.PASSIVESKILL_TRIGGER_CHECK , self.MSG_PASSIVESKILL_TRIGGER_CHECK , self)
    RegisterMessage(MsgConst.ENTITY_ATTACK , self.MSG_ENTITY_ATTACK , self)
    RegisterMessage(MsgConst.ENTITY_ATTACKED , self.MSG_ENTITY_ATTACKED , self)
    RegisterMessage(MsgConst.ENTITY_DAMAGED , self.MSG_ENTITY_DAMAGED , self)
    RegisterMessage(MsgConst.ENTITY_KILL , self.MSG_ENTITY_KILL , self)
    RegisterMessage(MsgConst.ENTITY_DEATH , self.ENTITY_DEATH , self)
    RegisterMessage(MsgConst.ENTITY_DEATH_1 , self.ENTITY_DEATH_1 , self)
    RegisterMessage(MsgConst.ENTITY_HP_CHANGE , self.ENTITY_HP_CHANGE , self)

    self._pool = PoolManagerInstance:CreateAndRegister("PassiveSkill",self, self.createCall)
    self._addBuffList = {}
    self._addSkillList = {}
end

function PassiveSkillManager:createCall(insId, passiveId , passiveLevel, bindSkill)
    return PassiveSkill.New(insId, passiveId , passiveLevel, bindSkill)
end

function PassiveSkillManager:PoolGet(insId, passiveId , passiveLevel, bindSkill)
    return self._pool:Get(insId, passiveId , passiveLevel, bindSkill)
end

function PassiveSkillManager:PoolBack(skill)
    self._pool:Back(skill)
end

-- 添加被动技能到指定实体
---@param insId integer 实体ID
---@param passiveId integer 被动技能ID
---@param passiveLevel integer 被动技能等级
function PassiveSkillManager:Add(insId, passiveId, passiveLevel,isBindSkill)
    if not self._passiveSkillList[insId] then
        self._passiveSkillList[insId] = {}
    end

    -- 重置或创建被动技能实例
    if self._passiveSkillList[insId][passiveId] then
        self._passiveSkillList[insId][passiveId]:Reset(passiveLevel)
    else
        self._passiveSkillList[insId][passiveId] = self._pool:Get(insId,passiveId,passiveLevel,isBindSkill)
    end

    DebugSKillLog(DebugSKillLogLayer.All, "PassiveSkillManager:Register passiveSkillList insId passiveId passiveLevel" ,self._passiveSkillList, insId , passiveId , passiveLevel)

    self:TRIGGER(PassiveSkillVariable.IsAddPassive,insId)
end

-- 移除指定实体的特定被动技能
---@param insId integer 实体ID
---@param passiveId integer 被动技能ID
function PassiveSkillManager:Remove(insId , passiveId)
    if self._passiveSkillList[insId]
        and self._passiveSkillList[insId][passiveId] then
        self._pool:Back(self._passiveSkillList[insId][passiveId])
        
        self._passiveSkillList[insId][passiveId]:Remove()
        self._passiveSkillList[insId][passiveId] = nil
    end

    DebugSKillLog(DebugSKillLogLayer.All, "PassiveSkillManager:Remove insId passiveId " , insId , passiveId)
end

-- 移除指定实体的所有被动技能
---@param insId integer 实体ID
function PassiveSkillManager:RemoveAll(insId)
    if self._passiveSkillList[insId]
        and self._passiveSkillList[insId] then
        self._passiveSkillList[insId] = nil
    end

    DebugSKillLog(DebugSKillLogLayer.All, "PassiveSkillManager:RemoveAll insId " , insId)
end

-- -- 处理被动技能触发检查消息
-- ---@param msg table 消息数据
-- function PassiveSkillManager:MSG_PASSIVESKILL_TRIGGER_CHECK(msg)
--     self:Trigger(msg.params.InsId,msg.params)
-- end

-- 处理实体攻击消息
---@param msg table 消息数据
function PassiveSkillManager:MSG_ENTITY_ATTACK(msg)
    local casterId = msg.params.casterinsid
    local caster = GetEntityByInsId(casterId)
    if not caster then
        return
    end

    if not caster:IsRangedAttacker() then
        return
    end

    -- 远程使用分裂
    self:MSG_ENTITY_ATTACK_PASSIVE(casterId, msg.params.targetinsid, msg.params.splitinsids)
end

-- 处理实体被攻击消息
---@param msg table 消息数据
function PassiveSkillManager:MSG_ENTITY_ATTACKED(msg)
    local casterId = msg.params.casterinsid
    local caster = GetEntityByInsId(casterId)
    if not caster then
        return
    end

    if caster:IsRangedAttacker() then
        return
    end

    -- 近战使用溅射
    self:MSG_ENTITY_ATTACK_PASSIVE(casterId, msg.params.targetinsid, msg.params.splashinsids)
end

function PassiveSkillManager:MSG_ENTITY_ATTACK_PASSIVE(casterId, targetId, hitList)
    hitList = hitList or {}
    table.insert(hitList , targetId)
    local doSkillData = DoSkillData.New()
    doSkillData.CasterInsId = casterId
    doSkillData.TargetInsId = targetId
    doSkillData.SkillId = 1
    doSkillData.SkillLevel = 1
    local skill = SkillLogic.New(nil,doSkillData)
    local settlementCount = #hitList
    self:TRIGGER(PassiveSkillVariable.IsHit,casterId,function(condition)
            condition[PassiveSkillVariable.SettlementCount] = settlementCount
            condition[PassiveSkillVariable.SettlementInsList] = hitList
        end,skill)

    for _, insId in pairs(hitList) do
        local doSkillData = DoSkillData.New()
        doSkillData.CasterInsId = casterId
        doSkillData.TargetInsId = insId
        doSkillData.SkillId = 1
        doSkillData.SkillLevel = 1
        local skill = SkillLogic.New(nil,doSkillData)
        self:TRIGGER(PassiveSkillVariable.IsHitRcv,insId,nil,skill)
    end
end

-- 处理实体受伤害消息
---@param msg table 消息数据
function PassiveSkillManager:MSG_ENTITY_DAMAGED(msg)
    if msg.params.damage_type == EnumFightDamageType.Critical then
        local doSkillData = DoSkillData.New()
        doSkillData.CasterInsId = msg.params.casterinsid
        doSkillData.TargetInsId = msg.params.targetinsid
        doSkillData.SkillId = msg.params.skillid <= 0 and 1 or msg.params.skillid
        local skill = SkillLogic.New(nil,doSkillData)
        self:TRIGGER(PassiveSkillVariable.IsCritical,doSkillData.CasterInsId,function(condition)
            condition[PassiveSkillVariable.SupposedDie] = msg.params.supposed_die
        end,skill)
    end

    local doSkillData = DoSkillData.New()
    doSkillData.CasterInsId = msg.params.casterinsid
    doSkillData.TargetInsId = msg.params.targetinsid
    doSkillData.SkillId = msg.params.skillid == 0 and 1 or msg.params.skillid
    doSkillData.Damage = msg.params.damage
    doSkillData.DamageType = msg.params.damage_type
    local skill = SkillLogic.New(nil,doSkillData)
    self:TRIGGER(PassiveSkillVariable.IsDamage,doSkillData.CasterInsId,function(condition)
        condition[PassiveSkillVariable.SupposedDie] = msg.params.supposed_die
    end,skill)
    self:TRIGGER(PassiveSkillVariable.IsDamage,doSkillData.TargetInsId,function(condition)
        condition[PassiveSkillVariable.SupposedDie] = msg.params.supposed_die
    end,skill)
end

-- 处理实体击杀消息
---@param msg table 消息数据
function PassiveSkillManager:MSG_ENTITY_KILL(msg)
    if msg.params.attackinsid == nil or msg.params.attackinsid == 0 then
        return
    end
    if msg.params.targetinsid == nil or msg.params.targetinsid == 0 then
        return
    end
    local caster = GetEntityByInsId(msg.params.attackinsid)
    local target = GetEntityByInsId(msg.params.targetinsid)
    if not caster or not target then
        return
    end

    local doSkillData = DoSkillData.New()
    doSkillData.CasterInsId = msg.params.attackinsid
    doSkillData.TargetInsId = msg.params.targetinsid
    doSkillData.SkillId = 1
    doSkillData.Position = target:GetPosition()
    doSkillData.CasterCamp = caster:GetCamp()
    doSkillData.TargetCamp = target:GetCamp()
    local skill = SkillLogic.New(nil,doSkillData)
    self:TRIGGER(PassiveSkillVariable.IsKill,doSkillData.CasterInsId,nil,skill)
end

function PassiveSkillManager:ENTITY_HP_CHANGE(msg)
    self:TRIGGER(PassiveSkillVariable.IsHPChange,msg.params.insid,function(condition)
        condition[PassiveSkillVariable.HPChangeIns] = msg.params
    end)
end

function PassiveSkillManager:ENTITY_DEATH(msg)
    if not msg.params.thorough then
        return
    end
    SendBeginMessage(MsgConst.ENTITY_DEATH_1, msg.params)
    SendBeginMessage(MsgConst.ENTITY_DEATH_2, msg.params)
end

-- 处理实体死亡消息
---@param msg table 消息数据
function PassiveSkillManager:ENTITY_DEATH_1(msg)
    local doSkillData = DoSkillData.New()
    doSkillData.CasterInsId = msg.params.insid
    doSkillData.TargetInsId = msg.params.insid
    doSkillData.SkillId = 1
    doSkillData.SkillLevel = 1
    local entity = GetEntityByInsId(doSkillData.TargetInsId)
    if entity then
        doSkillData.Position = entity:GetPosition()
        doSkillData.TargetCamp = entity:GetCamp()
    else
        -- print("PassiveSkillManager:ENTITY_DEATH error " ,doSkillData.TargetInsId)
        return
    end
    local skill = SkillLogic.New(nil, doSkillData)
    self:TRIGGER(PassiveSkillVariable.IsDeath,msg.params.insid,nil,skill)
end

-- 更新所有被动技能状态
---@param delta number 时间增量
function PassiveSkillManager:Update(delta)
    local addBuffCount = #self._addBuffList
    for i=addBuffCount, 1, -1 do
        BuffManagerInstance:AddBuff(table.remove(self._addBuffList, i))
    end
    local addSkillCount = #self._addSkillList
    for i=addSkillCount, 1, -1 do
        SkillManagerInstance:DoSkill(table.remove(self._addSkillList, i))
    end

    for insId, passiveSkills in pairs(self._passiveSkillList) do
        if passiveSkills then
            local entity = GetEntityByInsId(insId)
            if entity then
                for _, passiveSkill in pairs(passiveSkills) do
                    if passiveSkill then
                        passiveSkill:Update(delta)
                    end
                end
            end
        end
    end
end

-- 触发指定实体的被动技能
---@param insId integer 实体ID
---@param conditdata table 触发条件数据
function PassiveSkillManager:Trigger(insId,conditdata)
    if not self._passiveSkillList[insId] then
        return
    end

    for _, passiveSkill in pairs(self._passiveSkillList[insId]) do
        if passiveSkill and not passiveSkill:IsBindSkill() then
            passiveSkill:CheckAndRemove(conditdata)
            passiveSkill:CheckAndApply(conditdata)
        end
    end
end

-- 修改Buff属性
---@param buff NewBuff 新Buff
---@param conditdata table 条件数据
function PassiveSkillManager:ModifyBuff(buff, conditdata)
    local doBuffData = buff:GetDoBuffData()
    local insId = doBuffData.EntityId

    if not self._passiveSkillList[insId] then
        return
    end

    self:Trigger(insId , conditdata)
end

-- 修改技能属性
---@param skill SkillLogic 技能逻辑对象
---@param conditdata table 条件数据
function PassiveSkillManager:ModifySkill(skill, conditdata)
    local doSkillData = skill:GetDoSkillData()
    local insId = doSkillData.CasterInsId

    if not self._passiveSkillList[insId] then
        return
    end

    self:Trigger(insId , conditdata)
end

-- 修改结算属性
---@param skill SkillLogic 技能逻辑对象
---@param settlement LineEventSettlementObject | LineEventSettlementObjectNew 结算事件对象
---@param conditdata table 条件数据
function PassiveSkillManager:ModifySettlement(skill , settlement, conditdata)
    local doSkillData = skill:GetDoSkillData()
    if not self._passiveSkillList[doSkillData.CasterInsId] then
        return
    end

    self:Trigger(doSkillData.CasterInsId , conditdata)
end

-- 修改被动技能属性
---@param insId integer 实体ID
---@param conditdata table 条件数据
---@param passiveTableLine PassiveTableLine 被动技能配置行
function PassiveSkillManager:ModifySkillPassive(insId, conditdata, passiveTableLine)
    if not self._passiveSkillList[insId] then
        return
    end

    self:Trigger(insId , conditdata)
end

-- 检查字符串是否已缓存
---@param str string 要检查的字符串
---@return boolean 是否已缓存
function PassiveSkillManager:IsStringCache(str)
    return self._stringCache[str] ~= nil
end

-- 设置字符串缓存
---@param str string 要缓存的字符串
---@param table table 缓存的表
function PassiveSkillManager:SetStringCache(str , table)
    self._stringCache[str] = table
end

-- 获取字符串缓存，如果不存在则创建
---@param str string 要获取的字符串
---@return any 缓存的值
function PassiveSkillManager:GetStringCache(str,isReturn)
    if not self._stringCache[str] then
---@diagnostic disable-next-line: param-type-mismatch
        local f = load(isReturn and "return " .. str or str)
        if not f then
            print("PassiveSkillManager:GetStringCache loadstring error " ,str)
            return nil
        end
        self._stringCache[str] = f()
    end
    return self._stringCache[str]
end

function PassiveSkillManager:ClearStringCache()
    self._stringCache = {}
end

-- 创建触发条件表
---@param t string | nil 触发类型
---@param insId integer 实体ID
---@param modifyCall function|nil 修改回调函数
---@param skillIns SkillLogic | nil 技能实例
---@param settlementIns LineEventSettlementObject | LineEventSettlementObjectNew | nil 结算实例
---@param buffIns NewBuff | nil Buff实例
---@return table 触发条件表
function PassiveSkillManager:TRIGGERCONDITION(t,insId  ,modifyCall,skillIns , settlementIns , buffIns)
    ---@type table<string,any>
    local condition = {}
    -- local casterInsId = insId
    -- local targetInsId = insId
    -- if skillIns then
    --     local doSkillData = skillIns:GetDoSkillData()
    --     casterInsId = doSkillData.CasterInsId
    --     targetInsId = doSkillData.TargetInsId
    -- elseif settlementIns then
    --     local doSkillData = settlementIns:GetSkill():GetDoSkillData()
    --     casterInsId = doSkillData.CasterInsId
    --     targetInsId = doSkillData.TargetInsId
    -- elseif buffIns then
    --     local doBuffData = buffIns:GetDoBuffData()
    --     casterInsId = doBuffData.EntityId
    --     if doBuffData.Skill then
    --         targetInsId = doBuffData.Skill:GetDoSkillData().TargetInsId
    --     end
    -- -- else
    -- --     print("PassiveSkillManager:TRIGGERCONDITION error " ,t)
    -- --     return {}
    -- end

    if t then
        condition[t] = true
    end
    condition.insid = insId
    condition.InsId = insId

    if not self._passiveSkillList[insId] then
        return condition
    end

    condition[PassiveSkillVariable.CasterIns] = GetEntityByInsId(insId)
    if skillIns then
        condition[PassiveSkillVariable.TargetIns] = GetEntityByInsId(skillIns:GetDoSkillData().TargetInsId)
    end
    condition[PassiveSkillVariable.SkillIns] = skillIns
    condition[PassiveSkillVariable.SettlementIns] = settlementIns
    condition[PassiveSkillVariable.BuffIns] = buffIns

    -- condition.tableadd = function(t,modValue, ...)
    --     LayeredAttributeSystem.Add(t,modValue, ...)
    -- end
    -- condition.tablemul = function(t,modValue, ...)
    --     LayeredAttributeSystem.Mul(t,modValue, ...)
    -- end
    -- condition.tableset = function(t,modValue, ...)
    --     LayeredAttributeSystem.Set(t,modValue, ...)
    -- end
    -- condition.tablesub = function(t,modValue, ...)
    --     LayeredAttributeSystem.Sub(t,modValue, ...)
    -- end
    -- condition.tablediv = function(t,modValue, ...)
    --     LayeredAttributeSystem.Div(t,modValue, ...)
    -- end

    if modifyCall then
        modifyCall(condition)
    end

    return condition
end

-- 触发被动技能检查
---@param t string 触发类型
---@param insId integer 实体ID
---@param modifyCall function|nil 修改回调函数
---@param skillIns SkillLogic | nil 技能实例
---@param settlementIns LineEventSettlementObject | LineEventSettlementObjectNew | nil 结算实例
---@param buffIns NewBuff | nil Buff实例
---@param passiveIns PassiveSkill | nil 被动技能实例
function PassiveSkillManager:TRIGGER(t,insId , modifyCall,skillIns , settlementIns , buffIns)
    local condition = self:TRIGGERCONDITION(t ,insId ,modifyCall,skillIns , settlementIns , buffIns)
    -- SendBeginMessage(MsgConst.PASSIVESKILL_TRIGGER_CHECK, condition)
    self:Trigger(condition.InsId,condition)
end

-- 检查实体是否已学习指定被动技能
---@param insId integer 实体ID
---@param passiveId integer 被动技能ID
---@return boolean 是否已学习
function PassiveSkillManager:IsLearnedPassiveSkill(insId , passiveId)
    if self._passiveSkillList[insId]
        and self._passiveSkillList[insId][passiveId] then
        return true
    end
    return false
end

function PassiveSkillManager:GetAttr(insId , attrId)
    local entity = GetEntityByInsId(insId)
    if entity then
        return entity:GetAttr(attrId)
    end
    return 0
end

function PassiveSkillManager:GetEntityPassive(insId , passiveId)
    if not self._passiveSkillList[insId] then
        return nil
    end
    return self._passiveSkillList[insId][passiveId]
end

-- 获取实体学习过的被动技能ID列表
---@param insId integer 实体ID
---@return integer[] 被动技能ID列表
function PassiveSkillManager:GetLearnedPassiveSkillIds(insId)
    local passiveSkillIds = {}
    if not self._passiveSkillList[insId] then
        return {}
    end
    for passiveId, _ in pairs(self._passiveSkillList[insId]) do
        table.insert(passiveSkillIds, passiveId)
    end
    return passiveSkillIds
end

-- 加入后下一帧执行
---@param doBuffData DoBuffData 添加的Buff数据
function PassiveSkillManager:AddBuff(doBuffData)
    table.insert(self._addBuffList, doBuffData)
end

-- 加入后下一帧执行
---@param doSkillData DoSkillData 添加的技能数据
function PassiveSkillManager:DoSkill(doSkillData)
    table.insert(self._addSkillList, doSkillData)
end

function PassiveSkillManager:Clear()
    self._pool:Clear()
    self._passiveSkillList = {}
    self._stringCache = {}
    self._addBuffList = {}
    self._addSkillList = {}
end