--[[ 
Buff事件复活模块
负责管理Buff事件的复活效果
包括复活的计算和处理
提供Buff事件的触发和处理
支持不同类型的复活方式
]]--

---@class BuffEventRevive : NewBuffEvent
BuffEventRevive = Classnew("BuffEventRevive",NewBuffEvent)

BuffEventReviveData = {
    reviveInsId = 0,
    reviveBuffId = 0,
    reviveCountMax = 1,
    revivedCount = 0,
}

function BuffEventRevive:ctor()
    NewBuffEvent.ctor(self ,BuffEvent.Revive )

    RegisterMessage(MsgConst.ENTITY_DEATH , self.MSG_ENTITY_DEATH , self)

    self._revivedInsIdList = {}
end

function BuffEventRevive:OnAdd(buff)
    local entityId = buff:GetDoBuffData().EntityId
    if self._revivedInsIdList[entityId] then
        return
    end

    local buffId = buff:GetDoBuffData().BuffId
    local buffLevel = buff:GetDoBuffData().BuffLevel

    local params = self:GetEffectParams(entityId,buffId)
    params = GetConfDataLevel(params,buffLevel)
    local reviveData = clone(BuffEventReviveData)
    reviveData.reviveInsId = entityId
    reviveData.reviveBuffId = buffId
    reviveData.reviveCountMax = (params and params[1]) and tonumber(params[1]) or 1
    reviveData.revivedCount = 0
    self._revivedInsIdList[entityId] = reviveData

    DebugSKillLog_DoSkillData(DebugSKillLogLayer.All, "BuffEventRevive:OnAdd" , {entityId, buffId})
end

function BuffEventRevive:OnRemove(buff)
    local entityId = buff:GetDoBuffData().EntityId
    local buffId = buff:GetDoBuffData().BuffId
    self._revivedInsIdList[entityId] = nil

    DebugSKillLog_DoSkillData(DebugSKillLogLayer.All, "BuffEventRevive:OnRemove" , {entityId , buffId})
end

function BuffEventRevive:MSG_ENTITY_DEATH(msg)
    -- 真的死亡 不可复活
    if msg.params.thorough then
        return
    end

    local insid = msg.params.insid
    -- 假死亡 可以复活
    local reviveData = self._revivedInsIdList[insid]
    if not reviveData then
        return
    end

    local buffId = reviveData.reviveBuffId
    if not buffId then
        return
    end

    local unit = GetEntityByInsId(insid)
    if unit then
        if reviveData.revivedCount < reviveData.reviveCountMax then
            reviveData.revivedCount = reviveData.revivedCount + 1
            unit:Respawn(true)
        end

        if reviveData.revivedCount >= reviveData.reviveCountMax then
            self._revivedInsIdList[insid] = nil
            BuffManagerInstance:RemoveBuff(insid, buffId)
        end
    end
end