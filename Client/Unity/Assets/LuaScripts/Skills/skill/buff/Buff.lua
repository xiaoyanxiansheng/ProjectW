--[[ 
Buff模块
负责管理单个Buff实例的生命周期和效果
提供Buff的初始化、更新和结束功能
处理Buff的持续时间、叠加次数和效果计算
管理Buff相关的粒子效果
提供Buff数据的访问接口
支持Buff概率触发和持续时间计算
实现Buff的堆叠和刷新逻辑
处理Buff的视觉和音效表现
作为BuffManager和实体之间的连接层
支持不同类型的Buff效果实现
]]--


---@class DoBuffData : Classnew
---@field public EntityId integer 实体ID
---@field public BuffId integer Buff ID
---@field public BuffLevel integer Buff等级
---@field public Skill SkillLogic|nil 技能实例
---@field public InitStackCount integer 初始叠加层数
---@field public EffectTimes number 效果次数
---@field public EndPosition Vector 结束位置
---@field public InsIds integer[]
---@field public HealthDamageParams table|nil 健康伤害参数
---@field public MoveFinishBreakSkill boolean 位移结束是否中断技能
---@field public IsOptimized boolean 是否启用优化（延迟添加以分散性能）
DoBuffData = Classnew("DoBuffData", nil)

--- 构造函数，初始化Buff数据
function DoBuffData:ctor()
    self.EntityId = 0
    self.BuffId = 0
    self.BuffLevel = 1
    self.Skill = nil

    self.InitStackCount = 1
    self.AddStackCount = 1
    self.EffectTimes = 1.0
    self.EndPosition = nil      -- 结束位置
    self.InsIds = nil
    self.HealthDamageParams = nil

    self.MoveFinishBreakSkill = false
    self.AddTimes = 1.0
    
    -- 优化标记：用于延迟添加大量Buff以分散性能开销
    self.IsOptimized = false
end

function DoBuffData:GetCasterInsId()
    return self.Skill and self.Skill:GetDoSkillData().CasterInsId or self.EntityId
end

function DoBuffData:GetTargetInsId()
    return self.Skill and self.Skill:GetDoSkillData().TargetInsId or self.EntityId
end

---@class NewBuff : Classnew
NewBuff = Classnew("NewBuff", nil)

--- 构造函数，初始化Buff对象
---@param handle userdata Buff句柄
---@param onStartCall function<NewBuff> Buff开始时的回调函数
---@param onResetCall function<NewBuff> Buff重置时的回调函数
---@param onEndCall function<NewBuff> Buff结束时的回调函数
function NewBuff:ctor(handle, onStartCall, onResetCall, onEndCall , modifyCall)
    self._handle = handle
    self._onStartCall = onStartCall
    self._onResetCall = onResetCall
    self._onEndCall = onEndCall
    self._modifyCall = modifyCall
    ---@type ParticleAttachment_t
---@diagnostic disable-next-line: assign-type-mismatch
    self.PATTACH_ATTACHMENT_FOLLOW = 100
    self._attachments = {
        PATTACH_ABSORIGIN = PATTACH_ABSORIGIN,  -- 绝对位置
        PATTACH_CUSTOMORIGIN = PATTACH_CUSTOMORIGIN, -- 自定义位置
        PATTACH_WORLDORIGIN = PATTACH_WORLDORIGIN, -- 世界位置
        PATTACH_MAIN_VIEW = PATTACH_MAIN_VIEW, -- 主视角
        PATTACH_ABSORIGIN_FOLLOW = PATTACH_ABSORIGIN_FOLLOW, -- 绝对位置跟随
        PATTACH_POINT_FOLLOW = PATTACH_POINT_FOLLOW, -- 点跟随
        PATTACH_EYES_FOLLOW = PATTACH_EYES_FOLLOW, -- 眼睛跟随
        PATTACH_OVERHEAD_FOLLOW = PATTACH_OVERHEAD_FOLLOW, -- 头顶跟随
        PATTACH_ROOTBONE_FOLLOW = PATTACH_ROOTBONE_FOLLOW, -- 根骨骼跟随
        PATTACH_ATTACHMENT_FOLLOW = self.PATTACH_ATTACHMENT_FOLLOW, -- 绑定点跟随
    }

    self._initStackCount = 0
    self._stackCount = 0
end

--- 初始化Buff数据，设置事件、持续时间和概率
function NewBuff:InitBuffData()
    local buffConfig = self._buffTableLine
    self.BuffEvent = {}
    if buffConfig.Effect then
        local effect = buffConfig.Effect
        for evet, _ in pairs(effect) do
            table.insert(self.BuffEvent,evet)
        end
    end

    self._attrType = self._buffTableLine.AttrType or 0

    self:SetDuration(self:GetCalDuration())
    self._defaultActiveProb = self:GetCalActiveProb()

    self._position = Vector(0,0,0)
    self._positionCP = self._buffTableLine.ParticlePathCP or 0
    self._attachment = self._attachments.PATTACH_WORLDORIGIN
    self._attachmentPoint = ""
    local attachmentParams = self._buffTableLine.ParticleAttachment and string.split_lite(self._buffTableLine.ParticleAttachment, "|") or nil
    if attachmentParams ~= nil then
        self._attachment = self._attachments[attachmentParams[1]]
        self._attachmentPoint = attachmentParams[2] and attachmentParams[2] or ""
    end

    -- 最后一次修改数据的机会
    if self._modifyCall then
        self._modifyCall(self)
    end
end

--- 设置Buff数据
---@param doBuffData DoBuffData Buff数据
function NewBuff:SetDoBuffData(doBuffData,buffTableLine)
    self._doBuffData = doBuffData
    self._buffTableLine = buffTableLine
end

function NewBuff:Apply()
    self:InitBuffData()

    if not self:IsActiveProb() then
        -- self._onStartCall(self._handle,self)
        -- self._onResetCall(self._handle,self)
        self._onEndCall(self._handle,self)
        return
    end

    self._active = true

    self._stackCount = self._initStackCount > 0 and self._initStackCount or self._doBuffData.InitStackCount
    self:Start()
    self._onResetCall(self._handle,self)
end

--- 重置Buff状态，处理Buff叠加逻辑
---@param count integer 叠加层数
function NewBuff:Reset(count)
    local doBuffData = self._doBuffData
    -- 是否存在连续攻击Buff
    -- 如果存在切换目标后清空层级
    local isResetStackCount = false
    local skillId = doBuffData.Skill and doBuffData.Skill:GetSkillId() or 0
    local isContinueSkill = false
    if doBuffData.Skill then
        isContinueSkill = BuffManagerInstance:IsContinueSkill(doBuffData:GetCasterInsId(),skillId)
    end
    local skill = self._doBuffData.Skill
    if isContinueSkill
        and skill and doBuffData.Skill
        and skill:GetDoSkillData().TargetInsId ~= doBuffData:GetTargetInsId() then
        isResetStackCount = true
    end

    self._doBuffData = doBuffData
    self:InitBuffData()

    if not self:IsActiveProb() then
        return
    end

    self._active = true

    local buffConfig = self._buffTableLine

    if isResetStackCount then
        self._stackCount = 0
    end

    -- 是否已达到最高层数
    local maxStack = GetConfDataLevel(buffConfig.MaxStack,self._doBuffData.BuffLevel) or 0
    self._stackCount = self._stackCount + count
    self._stackCount = math.min(maxStack,self._stackCount)
    if maxStack > 1 or (maxStack == 1 and self._modifyCall) or buffConfig.OverlayType == 1 or buffConfig.OverlayType == 2 then
        self._onResetCall(self._handle,self)
    end

    if self._stackCount >= maxStack then
        if buffConfig.MaxStackBuffId and buffConfig.MaxStackBuffId > 0 then
            local newDoBuffData = clone(doBuffData)
            newDoBuffData.BuffId = buffConfig.MaxStackBuffId
            BuffManagerInstance:AddBuff(newDoBuffData)
        end
        if buffConfig.MaxStackReset and buffConfig.MaxStackReset == 1 then
            self._stackCount = 0
        end
    end

    self._stackCount = math.max(1,self._stackCount)
end

--- 检查Buff是否根据概率激活
---@return boolean 是否激活
function NewBuff:IsActiveProb()
    local prob = math.random(1,10000)
    return self._defaultActiveProb >= prob
end

--- Buff开始时的处理，调用开始回调并播放粒子效果
function NewBuff:Start()
    if self._onStartCall then
        self._onStartCall(self._handle, self)
    end

    self:PlayParticle()
end

--- 更新Buff状态，处理持续时间和粒子效果
---@param delta number 时间增量
function NewBuff:Update(delta)
    if not self._active then
        return
    end

    self:UpdateParticle()

    local isDelete = false

    self._duration = self._duration - delta
    if self._duration <= 0 then
        self:End()
        return
    end

    if not isDelete then
        if self._buffTableLine.MaxStackDelete then
            local maxStack = GetConfDataLevel(self._buffTableLine.MaxStack,self._doBuffData.BuffLevel) or 0
            if self._stackCount >= maxStack then
                self:End()
                return
            end
        end
    end
end

--- Buff结束时的处理，停止粒子效果并调用结束回调
function NewBuff:End()
    self._active = false

    self:StopParticle()

    if self._onEndCall then
        self._onEndCall(self._handle, self)
    end
end

--- 播放Buff相关的粒子效果
function NewBuff:PlayParticle()
    local buffTableLine = self._buffTableLine
    if buffTableLine.ParticlePath == "" then
        return
    end

    local entity = GetEntityByInsId(self._doBuffData.EntityId)
    if not entity then
        return
    end

    local entityPosition = entity:GetPosition()
    self._position.x = entityPosition.x
    self._position.y = entityPosition.y
    self._position.z = entityPosition.z + (buffTableLine.ParticleOffsetZ or 0)
    if self._attachment == self.PATTACH_ATTACHMENT_FOLLOW then
        local offset = Vector(0,0,buffTableLine.ParticleOffsetZ or 0)
        self._particleIns = ParticleManager:CreateParticle(buffTableLine.ParticlePath, PATTACH_POINT_FOLLOW, entity.__DotaEntity)
        ParticleManager:SetParticleControlEnt(self._particleIns, self._positionCP, entity.__DotaEntity, PATTACH_POINT_FOLLOW, self._attachmentPoint, offset, true)
    else
        self._particleIns = ParticleManager:CreateParticle(buffTableLine.ParticlePath, self._attachment, entity.__DotaEntity)
        if self._attachment == PATTACH_CUSTOMORIGIN or self._attachment == PATTACH_WORLDORIGIN then
            ParticleManager:SetParticleControl(self._particleIns, self._positionCP, self._position)
        end
    end
end

--- 更新Buff粒子效果的位置
function NewBuff:UpdateParticle()
    local entity = GetEntityByInsId(self._doBuffData.EntityId)
    if not entity then
        return
    end

    if self._attachment ~= PATTACH_CUSTOMORIGIN and self._attachment ~= PATTACH_WORLDORIGIN then
        return
    end

    local buffTableLine = self._buffTableLine
    local entityPosition = entity:GetPosition()
    self._position.x = entityPosition.x
    self._position.y = entityPosition.y
    self._position.z = entityPosition.z + (buffTableLine.ParticleOffsetZ or 0)
    UpdateFxPosition(self._particleIns, self._positionCP,self._position)
end

--- 停止Buff粒子效果
function NewBuff:StopParticle()
    StopFx(self._particleIns , true)
    self._particleIns = 0
end

--- 计算Buff的激活概率，考虑属性加成
---@return number 激活概率
function NewBuff:GetCalActiveProb()
    local buffTableLine = self._buffTableLine
    local activeProb = GetConfDataLevel(buffTableLine.ActiveProb,self._doBuffData.BuffLevel)
    local activeProb = activeProb or 0
    if self._attrType ~= 0 then
        local skill = self._doBuffData.Skill
        local casterInsId = skill and skill:GetDoSkillData().CasterInsId or 0
        activeProb = activeProb * BuffManagerInstance:GetBuffOddsAdd(casterInsId,self._doBuffData.EntityId , self._attrType)
    end
    return activeProb
end

--- 计算Buff的持续时间，考虑属性加成
---@return number 持续时间
function NewBuff:GetCalDuration()
    local buffTableLine = self._buffTableLine
    local duration = GetConfDataLevel(buffTableLine.Duration,self._doBuffData.BuffLevel)
    local activeDuration = duration or 0
    if self._attrType ~= 0 then
        local skill = self._doBuffData.Skill
        local casterInsId = skill and skill:GetDoSkillData().CasterInsId or 0
        activeDuration = activeDuration * BuffManagerInstance:GetBuffTimeAdd(casterInsId,self._doBuffData.EntityId , self._attrType)
    end
    return activeDuration
end

function NewBuff:SetDuration(duration)
    self._buffTableLine.Duration = {duration}
    self._defalutDuration = self:GetCalDuration()
    self._duration = self._defalutDuration
end

function NewBuff:ResetDuration()
    self._duration = self._defalutDuration

    local buffData = self:GetDoBuffData()
    local msg = {insid=buffData.EntityId,buffid=buffData.BuffId,bufflevel=buffData.BuffLevel,stack=self:GetStackCount(),buffduration=self:GetDuration(),notupdatebuffduration=false}
    SendBeginMessage(MsgConst.BUFF_OVERLAY_UPDATE,msg)
end

--- 获取Buff数据
---@return DoBuffData Buff数据
function NewBuff:GetDoBuffData()
    return self._doBuffData
end

--- 获取Buff配置表行
---@return BuffTableLine Buff配置表行
function NewBuff:GetBuffTableLine()
    return self._buffTableLine
end

--- 获取Buff当前叠加层数
---@return integer 叠加层数
function NewBuff:GetStackCount()
    return self._stackCount
end

function NewBuff:SetStackCount(stackCount)
    self._initStackCount = stackCount
    self._stackCount = stackCount
end

--- 获取Buff等级
---@return integer Buff等级
function NewBuff:GetBuffLevel()
    return self._doBuffData.BuffLevel
end

--- 获取Buff持续时间
---@return number 持续时间
function NewBuff:GetDuration()
    return self._defalutDuration
end

-- 开放到被动中的接口 尽量简单
function NewBuff:getdata()
    return self._doBuffData
end

function NewBuff:getskilldata()
    return self._doBuffData.Skill and self._doBuffData.Skill:getdata() or nil
end

function NewBuff:gettable()
    return self._buffTableLine
end

function NewBuff:getlocaltable()
    return GetBuffLine(self._doBuffData.BuffId)
end