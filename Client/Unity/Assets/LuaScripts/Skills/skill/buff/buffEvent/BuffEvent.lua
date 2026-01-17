--[[ 
Buff事件模块
负责管理游戏中的Buff事件系统
包括各种Buff效果的触发和处理
提供统一的事件接口和处理机制
支持多种类型的Buff事件
]]--

-- 所有BuffEvent都必须继承NewBuffEvent
---@class NewBuffEvent : Classnew
NewBuffEvent = Classnew("NewBuffEvent",nil)

---@class NewBuffEventData : Classnew
NewBuffEventData = Classnew("NewBuffEventData" , nil )
function NewBuffEventData:ctor()
    self.EntityId = 0           -- 实体ID
    self.BuffId = 0             -- BuffID
    self.BuffLevel = 0          -- Buff等级
    self.Duration = 0           -- 持续时间
end

---@param buffEventId integer   BuffEvebtID
function NewBuffEvent:ctor(buffEventId  )
    self._buffEventId = buffEventId     -- Buff事件ID
    ---@type table<integer , table<integer , NewBuff>>
    self._buffs = {}                    -- 实体ID -> {BuffID -> Buff实例}
end

---@param buff NewBuff
function NewBuffEvent:Add(buff)
    local doBuffData = buff:GetDoBuffData()
    local entityId = doBuffData.EntityId
    local buffId = doBuffData.BuffId
    local buffLevel = doBuffData.BuffLevel

    -- 初始化实体的Buff表
    if not self._buffs[entityId] then
        self._buffs[entityId] = {}
    end

    -- 添加Buff到实体
    self._buffs[entityId][buffId] = buff

    -- 如果是实体的第一个此类事件Buff，调用首次添加处理
    if table.nillength(self._buffs[entityId]) == 1 then
        self:AddFirst(buff)
    end

    DebugSKillLog_DoSkillData(DebugSKillLogLayer.All, self.__cname..":OnAdd" , {doBuffData.BuffId})
    -- 调用添加事件处理
    self:OnAdd(buff)
    
    -- 发送Buff事件添加消息到客户端
    local msg = BeginMessage(MsgConst.BUFF_EVENT_ADD)
    msg.params = {insid = entityId , event = self._buffEventId , buffid = buffId,bufflevel = buffLevel}
    SendMessage(msg)
end

-- 重置Buff事件
function NewBuffEvent:Reset(buff)
    DebugSKillLog_DoSkillData(DebugSKillLogLayer.All, self.__cname..":OnReset" , {buff:GetDoBuffData().BuffId})
    self:OnReset(buff)
end

---@param buff NewBuff
function NewBuffEvent:Remove(buff)
    local doBuffData = buff:GetDoBuffData()
    local entityId = doBuffData.EntityId
    local buffId = doBuffData.BuffId

    -- 检查实体是否有Buff
    if not self._buffs[entityId] then
        return
    end

    -- 如果是实体的最后一个此类事件Buff，调用结束处理
    if self._buffs[entityId][buffId]
        and table.nillength(self._buffs[entityId]) == 1 then
        self:RemoveEnd(buff)
    end

    -- 调用移除事件处理
    self:OnRemove(buff)
    -- 从实体移除Buff
    self._buffs[entityId][buffId] = nil
    DebugSKillLog_DoSkillData(DebugSKillLogLayer.All,self.__cname..":OnRemove" , {doBuffData.BuffId})

    -- 发送Buff事件移除消息到客户端
    local msg = BeginMessage(MsgConst.BUFF_EVENT_REMOVE)
    msg.params = {insid = entityId , event = self._buffEventId}
    SendMessage(msg)
end

-- 更新所有实体的所有Buff
function NewBuffEvent:Update(delta)
    for _, buffs in pairs(self._buffs) do
        for _, buff in pairs(buffs) do
            self:OnUpdate(delta,buff)
        end
    end
end

---@param buff NewBuff
function NewBuffEvent:AddFirst(buff)
    self:OnAddFirst(buff)
end

---@param buff NewBuff
function NewBuffEvent:RemoveEnd(buff)
    self:OnRemoveEnd(buff)
end

-- 获取Buff效果参数，这里只判断等级，每种事件的解析方式是不一样的，各自子类自己负责
---@return table
function NewBuffEvent:GetEffectParams(entityId , buffId)
    local buff = self._buffs[entityId][buffId]
    if not buff then
        return {}
    end

    local params = buff:GetBuffTableLine().Effect[self._buffEventId].Params or {}
    return params
end

---@param buff NewBuff
function NewBuffEvent:OnUpdate(delta, buff)end  -- Buff每帧更新回调

---@param buff NewBuff
function NewBuffEvent:OnAdd(buff)end  -- Buff添加回调

---@param buff NewBuff
function NewBuffEvent:OnReset(buff)end  -- Buff重置回调

---@param buff NewBuff
function NewBuffEvent:OnRemove(buff)end  -- Buff移除回调

---@param buff NewBuff
function NewBuffEvent:OnAddFirst(buff)end  -- 实体首次添加此类Buff回调

---@param buff NewBuff
function NewBuffEvent:OnRemoveEnd(buff)end  -- 实体最后一个此类Buff移除回调

-- 检查实体是否处于此事件状态
function NewBuffEvent:InEventState(entityId)
    return self._buffs[entityId] and table.nillength(self._buffs[entityId]) > 0 or false
end

-- 检查实体是否只有一个指定的事件Buff
function NewBuffEvent:CheckEventStateOne(entityId , buffId , eventId)
    -- 检查事件ID是否匹配
    if eventId == self._buffEventId then
        return false
    end

    -- 检查实体是否有且仅有一个指定的Buff
    return self._buffs[entityId]
        and self._buffs[entityId][buffId]
        and table.nillength(self._buffs[entityId]) == 1
end

function NewBuffEvent:GetBuffIds(entityId)
    local buffIds = {}
    if self._buffs[entityId] ~= nil then
        for buffId, _ in pairs(self._buffs[entityId]) do
            table.insert(buffIds, buffId)
        end
    end
    return buffIds
end

function NewBuffEvent:CheckAndGetPosition(entityId , position)
    return position , false
end