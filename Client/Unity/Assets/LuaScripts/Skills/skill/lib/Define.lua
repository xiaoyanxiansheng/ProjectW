--[[ 
技能系统定义模块
负责定义技能系统中使用的常量、枚举和数据结构
包括技能类型、Buff事件、结算类型等基础定义
提供系统中各模块共用的常量和类型定义
支持位运算和标志位操作
作为技能系统的基础组件，为其他模块提供类型支持
定义了技能时间线事件类型和处理方式
支持不同类型的技能效果和参数
]]--

Bit = bit

bitlshift = bit.lshift

-- table EX
---@param t table|nil 要搜索的表
---@param value any 要查找的值
---@param param1 string|nil 如果查找的是表中的表的属性，指定第一层属性名
---@param param2 string|nil 如果查找的是表中的表的表的属性，指定第二层属性名
---@return integer 找到值的索引，未找到返回0
function table.ContainValue(t,value,param1,param2)
    local containIndex = 0;
    if t then
        for i, v in pairs(t) do
            if not param1 then
                if v == value then
                    containIndex = i;
                    break;
                end
            elseif not param2 then
                if v[param1] == value then
                    containIndex = i;
                    break;
                end
            else
                if v[param1][param2] == value then
                    containIndex = i;
                    break;
                end
            end
        end
    end
    return containIndex;
end

-- 将一个表的所有元素插入到另一个表中
---@param t table 目标表
---@param r table 源表
---@param key string|nil 如果源表是表，指定key
function table.InsertRange(t , r,key)
    if t == nil or r == nil then
        return
    end

    if key then
        for _, value in ipairs(r) do
            table.insert(t, value[key])
        end
    else
        for _, value in ipairs(r) do
            table.insert(t, value)
        end
    end
end

-- 计算表中非nil元素的数量
---@param t table 要计算的表
---@return integer 非nil元素的数量
function table.nillength(t)
    local n = 0
    for k, v in pairs(t) do
        if v ~= nil then
            n = n + 1
        end
    end
    return n
end

-- 定义浮点数最小精度
math.epsilon = 1.401298e-45

-- 线性插值函数
---@param a number 起始值
---@param b number 结束值
---@param t number 插值系数(0-1)
---@return number 插值结果
function Lerp(a, b, t)
    t = math.max(0,math.min(1,t))
    return a + (b - a) * t
end

-- 线性插值函数
---@param a number 起始值
---@param b number 结束值
---@param t number 插值系数(0-1)
---@return number 插值结果
function Lerp2(a, b, t)
    return a + (b - a) * t
end

-- 表中所有元素的线性插值
---@param t table 结果表
---@param t0 table 起始表
---@param t1 table 结束表
---@param l number 插值系数
function table.Lerp(t,t0,t1,l)
    for k, v0 in pairs(t0) do
        local v1 = t1[k]
        t[k] = Lerp(v0,v1,l)
    end
end

-- 播放特效
---@param path string 特效路径
---@param p integer 控制点
---@param pos Vector 位置
---@return integer 特效ID
function PlayFx(path, p, pos)
    local particle = ParticleManager:CreateParticle(path, PATTACH_WORLDORIGIN, nil)
    ParticleManager:SetParticleControl(particle, p, pos)
    return particle
end

-- 在 Update 中更新粒子位置
---@param particle integer 特效ID
---@param p integer 控制点
---@param pos Vector 新位置
function UpdateFxPosition(particle , p, pos)
    if particle then
        ParticleManager:SetParticleControl(particle, p, pos)
    end
end

-- 需要移除粒子时调用
---@param particle integer 特效ID
---@param immediately boolean 是否立即移除
function StopFx(particle , immediately)
    if particle then
        ParticleManager:DestroyParticle(particle, immediately)
        ParticleManager:ReleaseParticleIndex(particle)
    end
end

function GetEntitySkillLevel(entityId , skillId)
    ---@type CUnitBase
    local entity = GetEntityByInsId(entityId)
    if not entity then
        return 1
    end
    local level = entity:GetSkillLevel(skillId)
    return level == 0 and 1 or level
end

-- 播放音效
---@param path string 音效路径
---@param entityId integer 实体ID
function PlaySound(path , entityId)
    local entity = GetEntityByInsId(entityId)
    if not entity then
        return
    end
    -- GetEntityByInsId 返回的是框架实体对象（如 CUnitBase），需要取 Dota 原生实体句柄才能播放声音
    ---@diagnostic disable-next-line: undefined-field
    local dotaEntity = entity.__DotaEntity
    if not dotaEntity then
        return
    end

    -- 统一使用“按玩家3D播放”接口，保证每个玩家可独立开关音效
    -- 注意：EmitSoundOnEntityForPlayer 不支持像 EmitSoundParams 那样直接传 volume/pitch/delay，这里保留函数签名仅为兼容旧调用。
    local players = (Lobby.GetAllValidPlayers and Lobby:GetAllValidPlayers()) or Lobby:GetAllPlayers()
    if not players then
        return
    end
    for pid, _ in pairs(players) do
        if Lobby:IsOpenSound(pid) then
            EmitSoundOnEntityForPlayer(path, dotaEntity, pid)
        end
    end
end

-- 播放动画
---@param targetId integer 目标实体ID
---@param name string 动画名称
---@param time number 动画时间
function PlayAnimation(targetId, name , time)
    local entity = GetEntityByInsId(targetId)
    if not entity then
        return
    end

---@diagnostic disable-next-line: undefined-field
    entity.__DotaEntity:StartGestureWithFadeAndPlaybackRate(_G[name],0.5,0.5, time)
end

-- 获取当前时间
---@return number 当前时间(秒)
function GetCurTime()
    return Time()
end

-- 表达式缓存
Expressions = {

}
-- 执行表达式并缓存结果
---@param expression string 表达式字符串
---@param T table 表达式参数
---@return any 表达式执行结果
function DoExpression(expression , T)
    if not Expressions[expression] then 
---@diagnostic disable-next-line: param-type-mismatch
        local func = load("return function(T) return " .. expression .. " end")
        if func == nil then
            DebugSKillLog(DebugSKillLogLayer.Warning,"DoExpression error ", expression)
            return 0
        else
            Expressions[expression] = func()
        end
    end
    return Expressions[expression](T)
end

-- 通过实例ID获取实体
---@param insId integer | number 实例ID
---@return any 实体对象
function GetEntityByInsId(insId)
    return Units:GetUnitByInsid(insId)
end

-- 实体ID转换为实例ID
---@param entitId integer 实体ID
---@return integer 实例ID
function EntityIdToInsId(entitId)
    return Units.__EntityidToInsid[entitId]
end

-- 获取实体位置
---@param insId integer 实例ID
---@return Vector 实体位置
function GetEntityPosition(insId)
    local entity = GetEntityByInsId(insId)
    if not entity then
        return Vector(0,0,0)
    end

    -- if not entity:IsAlive() then
    --     return Vector(0,0,0)
    -- end

    return entity:GetPosition()
end

-- 设置实体位置
---@param insId integer 实例ID
---@param pos Vector 目标位置
function SetEntityPosition(insId , pos)
    local entity = GetEntityByInsId(insId)
    if not entity then
        return
    end

    if not entity:IsAlive() then
        return
    end

    entity:SetPosition(pos)
end

-- 设置实体朝向
---@param entityId integer 实体ID
---@param direction Vector 朝向向量
function SetEntityForwardVector(entityId,direction)
    local entity = GetEntityByInsId(entityId)
    if not entity then
        return
    end

    if not entity:IsAlive() then
        return
    end

    -- Dota版本：entity.__DotaEntity:SetForwardVector(direction)
    -- Unity版本：MockEntity/后续Unity实体直接实现 SetForwardVector
    ---@diagnostic disable-next-line: invisible
    if entity.__DotaEntity and entity.__DotaEntity.SetForwardVector then
        entity.__DotaEntity:SetForwardVector(direction)
    elseif entity.SetForwardVector then
        entity:SetForwardVector(direction)
    end
end

-- 设置实体有效位置(考虑地形)
---@param insId integer 实例ID
---@param position Vector | nil 目标位置，为nil则使用当前位置
function SetEntityValidPosition(insId , position)
    local entity = GetEntityByInsId(insId)
    local newPosition = GetEntityValidPosition(insId , position)
    if newPosition then
        entity:SetPosition(newPosition)
    end
end

function GetEntityValidPosition(insId , position)
    local entity = GetEntityByInsId(insId)
    if entity == nil then
        return nil
    end

    if not entity:IsAlive() then
        return nil
    end

    if not position then
        position = entity:GetPosition()
    end
---@diagnostic disable-next-line: invisible
    position = GetGroundPosition(position, entity.__DotaEntity)   -- TODO
---@diagnostic disable-next-line: undefined-field
    if GridNav:IsTraversable(position) 
---@diagnostic disable-next-line: undefined-field
        and not GridNav:IsBlocked(position) then
        return position
    end

    return nil
end

function GetPositionFixHeight(position , fixHeight)
    local groundHeight = GetGroundHeight(position, nil)
    return Vector(position.x,position.y,groundHeight + fixHeight)
end

function IsEntityValid(insId)
    local entity = GetEntityByInsId(insId)
    if not entity then
        return false
    end
   if not entity:IsAlive() then
        return false
    end
    return true
end

-- 为单位寻找空位
---@param insId integer 实例ID
function SetFindClearSpaceForUnit(insId)
    local entity = GetEntityByInsId(insId)
    if not entity then
        return
    end

    if not entity:IsAlive() then
        return
    end

    -- Dota版本：FindClearSpaceForUnit(dotaEntity, position, true)
    -- Unity版本：无需处理；这里保证不报错
    if entity.__DotaEntity and FindClearSpaceForUnit then
        FindClearSpaceForUnit(entity.__DotaEntity, entity:GetPosition(), true)
    end
end

-- 获取配置表行数据
---@param name string 配置表名称
---@param id integer 配置ID
---@return any 配置行数据
function GetConfDataLine(name , id)
    local line = ConfData:GetLine(name , id)
    if not line then
        error(string.format("请检测配置表！！！ 配置表 %s 中没有Id %s" , name , id))
    end
    return line
end

-- 根据等级获取配置数据
---@param t table 配置数据表
---@param level integer 等级
---@return any 对应等级的配置数据
function GetConfDataLevel(t,level)
    if not t then
        return nil
    end

    if level <= #t then
        return t[level]
    end
    return t[#t]
end
---@class SkillTableLineLevel
---@field Index integer
---@field Active integer
---@field Level integer[]
---@field Time number
---@field Type integer
---@field Params table
---@class SkillTableLine
---@field id number                     技能Id
---@field SkillPassiveId integer    自身被动 
---@field DamageType integer            0 无阵营 1 友方 2 敌方
---@field MaxLevel  integer
---@field Duration number[]               技能持续时间
---@field Radius number         技能施法范围
---@field Cd number[]             技能Cd
---@field MPCost number         技能消耗
---@field CastTime number       前摇时间
---@field FinishLoopCount number[]      技能的循环次数
---@field DoIgnoreBuffs integer      释放技能忽略Buff影响
---@field TimeLine SkillTableLineLevel[]       技能时间线
---@return SkillTableLine
function GetSkillLine(id)
    return GetConfDataLine("Skill" , id)
end

---@class BuffTableLineLevel
---@field Type integer
---@field Params    table
---@field StackCountParams table
---@field HealthParams table
---@field DamageParams table
---@class BuffTableLine
---@field Id integer             事件Id（自定义）
---@field ClientShow integer 客户端显示
---@field DesignType integer Buff类型
---@field AttrType integer
---@field GainOrDeBuff integer -1 减益 1 增益 0 无
---@field ActiveProb number[]
---@field Duration number[]       持续时间（秒）
---@field DurationSkillId integer[] 结束技能
---@field DurationBuffId integer[] 结束Buff
---@field OverlayType number    叠加类型：1-叠加，2-覆盖，3-忽略
---@field MaxStack number[]       最大叠加层数
---@field MaxStackBuffId number[]   最高层级Buff
---@field MaxStackReset number[]  最大叠加层数 重置
---@field ParticlePathCP integer 特效位置控制点
---@field ParticlePath string   特效路径
---@field ParticleAttachment string 特效附着点
---@field ParticleOffsetZ number 偏移
---@field Anim string           动作
---@field Effect BuffTableLineLevel[]
---@return BuffTableLine
function GetBuffLine(id)
    return GetConfDataLine("SkillBuff" , id)
end

---@class PassiveTableLineLevel
---@field Id                integer
---@field Change            integer[]
---@field BuffId            integer[]
---@field SkillId           integer[]
---@field SkillModify       string
---@field SettlementModify  string
---@field BuffModify        string
---@field PassiveModify        string
---@field DistanceModifySkillRange [integer[],integer,number[]]
---@field Summon            table
---@field AddCondition      string
---@field RemoveCondition   string
---@class PassiveTableLine
---@field Id                integer
---@field Cd                integer[]
---@field Duration          integer[]
---@field Interval          integer[]
---@field AddTriggerProb    integer[] 触发概率
---@field RemoveTriggerProb integer[] 触发概率
---@field Level             PassiveTableLineLevel[]
---@return PassiveTableLine
function GetPassiveSkillLine(id)
    return GetConfDataLine("SkillPassive" , id)
end

---@class SettlementLine
---@field Id integer             结算Id
---@field RangeType integer      结算类型 SettlementType
---@field RangeParam table      结算范围
---@field RangeParamMax table   最大结算范围
---@field HitInterval number    结算间隔
---@field MaxHitCount integer    结算数量上限
---@field HitOnce integer       结算一次
---@field MaxLifeTime number    结算持续时间
---@field HitBreakSkill integer 击中是否打断技能
---@field IgnoreCurTarget integer   忽略当前选择目标
---@field CasterHitBuffId integer[] 结算Buff
---@field TargetHitBuffId integer[] 结算Buff
---@field TargetHitBuffDuration number[] 目标Buff持续时间
---@field HitDisplace number[]
---@field DisplaceDistanceEffectTimes number
---@field HitCountEffectTimes number[]
---@field BuffECountffectTimes number[]
---@return SettlementLine
function GetSettlementLine(id)
    return GetConfDataLine("SkillSettlement" , id)
end

---@class HitShowTableLine
---@field Id integer                 受击表现Id
---@field HitAnim string            受击动作
---@field HitParticlePath string    受击特效
---@field HitBuffId number          受击Buff
---@field HitDuration number        受击Buff    持续时间
---@field HitDistance number        受击Buff    距离
---@field HitHeight number          受击Buff    高度
---@return HitShowTableLine
function GetHitShowLine(id)
    return GetConfDataLine("SkillHitShow" , id)
end


---@return {Id: integer, FollowType: integer, EndType: integer, MoveEquation: string, MoveDuration: number, MoveSpeed: number, SettlementID: number, StartFx: string}
function GetBulletLine(id)
    return GetConfDataLine("SkillBullet" , id)
end

-- Buff事件表 和角色状态强绑定
---@type table<string, integer>
BuffEvent = {
    State                   = 0,                        --自定义状态
    CantMagic               = bitlshift(1,0),      --不可施法
    CantCantMagic           = bitlshift(1,3),      --不可不可施法
    Displacement            = bitlshift(1,1),      --位移
    CantDisplacement        = bitlshift(1,2),      --不可位移
    CantCantDisplacement    = bitlshift(1,24),      --不可不可位移
    CantSlowSpeed           = bitlshift(1,4),      --不可被减速
    DamageRebound          = bitlshift(1,5),       --伤害反弹
    SkillDamageRebound      = bitlshift(1,30),       --技能伤害反弹
    Revive                  = bitlshift(1,6),      --复活
    ContinueSkill           = bitlshift(1,7),      --连续攻击
    CantDamage              = bitlshift(1,8),      --不可受到伤害
    CantSelect              = bitlshift(1,9),      --不可选中
    Attr                    = bitlshift(1,10),     --属性
    CantNormalAttack        = bitlshift(1,11),     --不可普通攻击
    CantCantNormalAttack    = bitlshift(1,23),      --不可不可普通攻击
    HealthDamage            = bitlshift(1,12),     --恢复/伤害
    DoSkill                 = bitlshift(1,13),     --释放技能
    ReduceSkillCD           = bitlshift(1,14),     --减少技能CD
    HitCountDamange         = bitlshift(1,15),     --击中数量伤害加成
    BreakSkill              = bitlshift(1,16),     --打断技能
    DeBuffCountDamage       = bitlshift(1,17),     --debuff数量伤害加成
    Fear                    = bitlshift(1,18),     --恐惧
    EffectShare             = bitlshift(1,19),     --效果叠加
    HealthLock              = bitlshift(1,20),     --锁血
    NoDraw                  = bitlshift(1,21),     --不可显示
    MsgTranslateBuff        = bitlshift(1,22),     --转移Buff
    Shield                  = bitlshift(1,25),     --护盾
    NearEntity              = bitlshift(1,26),     --附近单位
    DamageHPMP              = bitlshift(1,27),     --血魔转化
    Ignore                  = bitlshift(1,28),     --忽略
    CantRecover             = bitlshift(1,29),     --不可恢复
    AttackDamageTimes       = 5,                   --攻击伤害倍率
    InRange                 = 3,                   --范围内
}

-- Buff事件表 每个Buff都需要一个 里面集合多个BuffEvent
---@type table<string, integer>
BuffEventCollect = {
    SlowSpeed           = BuffEvent.SlowSpeed,                          -- 减速
    SuperArmor          = 0,
    Stun                = BuffEvent.CantMagic+BuffEvent.Displacement,   -- 不可施法 不可位移
    Invincible          = 0,
    HpShield            = 0,
    Freeze              = 0,
    Frozen              = 0,
    Displacement        = BuffEvent.Displacement,                       -- 不可位移
}

-- Buff的叠加方式
BuffOverlayType = {
    Stack = 1,            -- 叠加
    Override = 2,         -- 覆盖
    Ignore = 3,           -- 忽略
    TypeDependent = 4     -- 同类型覆盖不同类型叠加
}

-- 被动技能触发类型
PassiveTriggerType = {
    All = 0,              -- 所有
    HP = 1,               -- 生命值
    Crit = 2,             -- 暴击
    MoveSpeed = 4,        -- 移动速度
}
-- 被动技能触发叠加类型
PassiveTriggerOverlayType = {
    AND = 1,              -- 与
    OR = 2                -- 或
}

--技能时间线事件
ESkillEventType = {
    PreWarning = 0,             --预警                  未做
    Animation = 1,              --动作                  未做
    Buff = 2,                   --Buff                  未做
    Bullet = 3,                 --子弹                  创建实体-->释放技能
    SettlementObject = 4,       --结算物体             TimeLine：结算Id|0不跟随/1跟随|偏移|(时间|间隔)
    Sound = 5,                  --音效                  未做
    Particle = 6,               --特效                 TimeLine：特效路径|0不跟随/1跟随|偏移(延时)(时间|间隔|延时)
    CameraShake = 7,            --镜头震动事件          未做
    Displacement = 8,           --位移事件              位移公式|距离|时间
    EnterCD = 9,                --进入CD                TimeLine: 0不可打断|1可打断
    TurnToTarget = 10,          --转向目标              未做
    State       = 11 ,          --技能状态              TimeLine: 状态      对外发送消息
    DoSkill = 12,               --释放技能
    Summon          = 13,       --召唤
    BulletRange     = 14,       --范围子弹
    TargetSelect    = 15,       --目标选择
    CanBreakSkill  = 16,        --技能不能被打断
    TransferDebuff  = 17,       --转移自身debuff
    BuffTogether    = 18,       --Buff绑定
    Passive         = 19,       --被动
    PositionNew     = 20,       --位置
    SettlementObjectNew = 21,   --结算物体
    ParticleNew     = 22,       --特效
    TargetSelectNew = 23,       --目标选择
    DisplacementNew = 24,       --位移
    BulletNew       = 25,       --子弹
    BulletRangeNew  = 26,       --范围子弹
    BuffNew         = 27,       --Buff
    TurnToSkill     = 28,       --转向技能
    SummonNew       = 29,       --召唤
    EventEnd = 99
}

---@type table<string, integer>
SettlementType = 
{
    Single = 0,             --单体
    Fan = 1,                --扇形
    Circle = 2,             --圆形
    Rectangle = 3,          --方形
    Bullet = 4,             --子弹
    Accurately = 5,         -- 必中，不判断距离
}

---@class SettlementCampType
SettlementCampType = {
    None        = 0,
    SAME_CAMP   = 1,        -- 相同阵营
    DIF_CAMP    = 2,        -- 不同阵营
}

-- 结算跟随类型(技能位置定义)
SettlementFlollowType = {
    Position = 1,           -- 固定位置
    Caster = 2,             -- 跟随施法者
    Target = 3,             -- 跟随目标
    Agent = 4,              -- 跟随代理（新版本废弃）
    DynCaster = 5,          -- 动态跟随施法者
    DynTarget = 6,          -- 动态跟随目标
    DynAgent = 7,           -- 动态跟随代理（新版本废弃）
    StartPosition = 8,      -- 起始位置
    DynPosition = 9,        -- 动态位置
}

-- 结算朝向类型
SettlementForwardType = {
    None = 0,                -- 无朝向
    CasterForward = 1,       -- 施法者朝向
    StartTargetForward = 2,  -- 起始目标朝向
    DynamicCasterForward = 3 -- 动态施法者朝向
}

---@param attacker CUnitBase 攻击者
---@param targeter CUnitBase 目标
---@param skill_id integer 技能，非技能传0
---@param skill_level integer|nil 技能等级，缺省为1
---@param times number|nil 伤害倍数，缺省为1，表示100%伤害
---@param params table|nil 技能伤害参数，配置在技能表，原原本本传递
function FightApplyDamage(attacker, targeter, skill_id, skill_level, times, params)
    if params then 
        table.insert(params, {21,0,201,tonumber(ConfData:GetGameConfig("SkillInitialHitRate"))})
    end
    Fight:ApplyDamage(attacker, targeter, skill_id, skill_level, times, params)
end