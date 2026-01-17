BuffEventNearEntityData = {
    EffectAttrId = 0,
    Range = 0.0,
    EffectTimes = 1.0,
    Camp = 0,
    CheckClone = 0,
}

---@diagnostic disable: need-check-nil
---@class BuffEventNearEntity : NewBuffEvent
BuffEventNearEntity = Classnew("BuffEventNearEntity", NewBuffEvent)

--- 构造函数，初始化恐惧Buff事件
function BuffEventNearEntity:ctor()
    NewBuffEvent.ctor(self, BuffEvent.NearEntity)

    self._nearEntityData = {}
    self._attrList = {}

    self._intervalTime = 0.0
end

--- 重置Buff时的处理函数
---@param buff NewBuff 被重置的Buff对象
function BuffEventNearEntity:OnReset(buff)
    local doBuffData = buff:GetDoBuffData()
    local insId = doBuffData.EntityId
    local buffId = doBuffData.BuffId

    local params = self:GetEffectParams(insId, buffId)[1]
    local nearEntityData = clone(BuffEventNearEntityData)
    nearEntityData.EffectAttrId = params[1]
    local offsetPs = string.split_lite(tostring(params[2]),"/")
    nearEntityData.Range = tonumber(GetConfDataLevel(offsetPs,doBuffData.BuffLevel))
    nearEntityData.EffectTimes = params[3]
    nearEntityData.Camp = params[4]
    nearEntityData.CheckClone = params[5]
    if not self._nearEntityData[insId] then
        self._nearEntityData[insId] = {}
    end
    self._nearEntityData[insId][buffId] = nearEntityData

    if not self._attrList[insId] then
        self._attrList[insId] = {}
    end
    if not self._attrList[insId][buffId] then
        self._attrList[insId][buffId] = {}
    end
    if not self._attrList[insId][buffId][nearEntityData.EffectAttrId] then
        self._attrList[insId][buffId][nearEntityData.EffectAttrId] = {}
    end
end

function BuffEventNearEntity:OnRemove(buff)
    local doBuffData = buff:GetDoBuffData()
    local insId = doBuffData.EntityId
    local buffId = doBuffData.BuffId

    if self._nearEntityData[insId]
        and self._nearEntityData[insId][buffId] then
        self._nearEntityData[insId][buffId] = nil
    end

    if self._attrList[insId]
        and self._attrList[insId][buffId] then
        local attrList = self._attrList[insId][buffId]
        self._attrList[insId][buffId] = nil
        -- 清除缓存（下次 GetAttr 时惰性重算）
        BuffManagerInstance:ClearAttrCache(insId, attrList)
        -- 发一条消息通知属性变更
        SendBeginMessage(MsgConst.BUFF_ATTR_UPDATE, {insid = insId})
    end
end

--- 更新Buff时的处理函数
---@param delta number 时间增量
---@param buff NewBuff 需要更新的Buff对象
function BuffEventNearEntity:OnUpdate(delta,buff)
    if self._intervalTime > 0.0 then
        self._intervalTime = self._intervalTime - delta
        return
    end
    self._intervalTime = 0.1 + self._intervalTime

    local doBuffData = buff:GetDoBuffData()
    local insId = doBuffData.EntityId
    local buffId = doBuffData.BuffId
    local entity = GetEntityByInsId(insId)
    local position = entity:GetPosition()
    local nearEntityData = self._nearEntityData[insId][buffId]
    local radius = nearEntityData.Range
    local camp = nearEntityData.Camp
    local effectTimes = nearEntityData.EffectTimes * doBuffData.EffectTimes
    local effectAttrId = nearEntityData.EffectAttrId

    DrawDebugFan(position, radius, 360, Vector(1,0,0), 0.2 ,Vector(0, 255, 0))

    local campCount = 0
    local units = Units:GetUnitsByArea(position,radius,nil,true)
    local camp1 = entity:GetCamp()
    for _,unit in pairs(units) do
        local camp2 = unit:GetCamp()
        -- 不是中立单位
        if camp2 ~= 0 then
            -- 克隆单位检测
            if not (nearEntityData.CheckClone == 1 and unit:GetOwner() ~= nil) then
                -- 阵营检测
                if camp == 0
                    or (camp == SettlementCampType.DIF_CAMP and camp1 ~= camp2)
                    or (camp == SettlementCampType.SAME_CAMP and camp1 == camp2) then
                    campCount = campCount + 1
                end
            end
        end
    end

    if campCount > 0 then
        self._attrList[insId][buffId][effectAttrId] = {1, effectTimes * campCount}

        -- 清除缓存（下次 GetAttr 时惰性重算）
        BuffManagerInstance:ClearAttrCache(insId, self._attrList[insId][buffId])
        -- 每个单位只发一条消息通知属性变更
        SendBeginMessage(MsgConst.BUFF_ATTR_UPDATE, {insid = insId})
    end
end

-- 获取实体的所有属性列表
---@param insId integer 实体ID
---@return table 属性列表
function BuffEventNearEntity:GetAttr(insId)
    return self._attrList[insId]
end