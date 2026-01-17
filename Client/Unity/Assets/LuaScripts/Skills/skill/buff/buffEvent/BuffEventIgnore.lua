---@class BuffEventIgnore : NewBuffEvent
BuffEventIgnore = Classnew("BuffEventIgnore", NewBuffEvent)

-- 构造函数
function BuffEventIgnore:ctor()
    NewBuffEvent.ctor(self, BuffEvent.Ignore)

    ---@type table<integer, table<integer, integer[]>> 实体ID -> BuffID -> 忽略类型
    self._entityIgnoreList = {}
end

-- Buff重置回调
function BuffEventIgnore:OnReset(buff)
    local doBuffData = buff:GetDoBuffData()
    local entityId = doBuffData.EntityId
    local buffId = doBuffData.BuffId
    local buffLevel = doBuffData.BuffLevel

    local params = self:GetEffectParams(entityId, buffId)
    if not self._entityIgnoreList[entityId] then
        self._entityIgnoreList[entityId] = {}
    end
    self._entityIgnoreList[entityId][buffId] = params[1]

    DebugSKillLog_DoSkillData(DebugSKillLogLayer.All  , "BuffEventIgnore:OnReset" , self._entityIgnoreList)

    -- 先收集需要移除的buffid，避免在遍历过程中修改buffs导致问题
    local removeBuffIds = {}
    local buffs = BuffManagerInstance:GetEntityBuffs(entityId)
    for _, buff in pairs(buffs) do
        local buffDoBuffData = buff:GetDoBuffData()
        if BuffManagerInstance:IsIgnoreBuff(entityId, buffDoBuffData.BuffId) and
            table.ContainValue(removeBuffIds, buffDoBuffData.BuffId) == 0 then
            table.insert(removeBuffIds, buffDoBuffData.BuffId)
        end
    end
    for _, buffid in ipairs(removeBuffIds) do
        BuffManagerInstance:RemoveBuff(entityId, buffid)
    end
end

function BuffEventIgnore:OnRemove(buff)
    local doBuffData = buff:GetDoBuffData()
    local entityId = doBuffData.EntityId
    self._entityIgnoreList[entityId][doBuffData.BuffId] = nil
end

-- 获取忽略类型
---@param insId integer 实体ID
---@return table<integer, integer[]> 忽略类型
function BuffEventIgnore:GetIgnoreType(insId)
    return self._entityIgnoreList[insId] or {}
end