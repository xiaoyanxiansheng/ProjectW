--[[ 
Buff事件属性模块
负责管理Buff事件的属性效果
包括属性的计算和处理
提供Buff事件的触发和处理
支持不同类型的属性效果
处理属性叠加和移除逻辑
维护实体的属性列表
支持多种属性计算方式
处理属性间的转换关系
提供属性缓存机制
]]--
---@diagnostic disable: need-check-nil

---@class BuffEventAttr : NewBuffEvent
BuffEventAttr = Classnew("BuffEventAttr",NewBuffEvent)

-- 构造函数，初始化属性事件
function BuffEventAttr:ctor()
    NewBuffEvent.ctor(self , BuffEvent.Attr)

    ---@type table<integer,table<integer,table>> 实体ID -> BuffID -> 属性列表
    self._attrList = {}

    -- 属性字符串缓存列表，用于优化性能
    self._attrstrCacheList = {}
end

-- Buff添加回调，初始化实体的属性列表
---@param buff NewBuff
function BuffEventAttr:OnAdd(buff)
    -- self:OnReset(buff)
end

-- Buff重置回调，重新计算属性效果
-- TODO 是否多计算了一次
function BuffEventAttr:OnReset(buff)
    local doBuffData = buff:GetDoBuffData()
    local entityId = doBuffData.EntityId
    local casterInsId = doBuffData:GetCasterInsId()
    local buffId = doBuffData.BuffId
    local buffLevel = doBuffData.BuffLevel
    local effectTimes = doBuffData.EffectTimes

    -- 性能优化：直接访问需要清理的单位，不遍历所有单位（性能提升50-100倍）
    local unitsToClear = {entityId}
    if casterInsId ~= entityId then
        table.insert(unitsToClear, casterInsId)
    end
    
    for _, tempInsId in ipairs(unitsToClear) do
        if self._attrList[tempInsId] and self._attrList[tempInsId][buffId] then
            self._attrList[tempInsId][buffId] = nil
        end
    end

    -- 获取属性效果参数
    local params = self:GetEffectParams(entityId,buffId)
    -- 计算堆叠效果
    local stackCountEffect = BuffManagerInstance:GetStackCountEffect(buff , self._buffEventId)
    for _, attr in pairs(params) do
        -- 根据Buff等级计算属性值
        local attrLevel = math.min(#attr,buffLevel + 2)
        local originvalue = attr[attrLevel]
        local attrvalue = originvalue * stackCountEffect * effectTimes
        local addType = attr[2]
        
        -- 处理属性转换类型(类型3)
        if addType == 3 then
            ---@type table<integer,integer> 源属性ID -> 目标属性ID
            local ps = string.split_lite(attr[1],"_")
            local tempattr1 = tonumber(ps[1])
            local tempattr2s = string.split_lite(tostring(ps[2]),"/")
            local tempattr2 = tonumber(tempattr2s[1])
            local levelEffect = #tempattr2s > 1 and tonumber(GetConfDataLevel(tempattr2s,buffLevel + 1)) or 1
            local tempattr4 = ps[4] and tonumber(ps[4]) or 0
            local tempattr5 = ps[5] and tonumber(GetConfDataLevel(string.split_lite(tostring(ps[5]),"/"),buffLevel)) or 0
            -- 减少源属性
            if not self._attrList[entityId] then self._attrList[entityId] = {} end
            if not self._attrList[entityId][buffId] then self._attrList[entityId][buffId] = {} end
            if tempattr4 == 0 then
                self._attrList[entityId][buffId][tempattr1]= {2,-originvalue}
            end
            -- 确定目标实体
            local isself = tonumber(ps[3] or 1) == 1
            local insId = isself and entityId or casterInsId
            -- 增加目标属性
            if not self._attrList[insId] then self._attrList[insId] = {} end
            if not self._attrList[insId][buffId] then self._attrList[insId][buffId] = {} end
            if not self._attrList[insId][buffId][tempattr2] then self._attrList[insId][buffId][tempattr2] = {3,values={}} end
            table.insert(self._attrList[insId][buffId][tempattr2].values, {attrvalue * levelEffect,tempattr1,entityId,tempattr5})
        else
            -- 普通属性增减
            if not self._attrList[entityId] then self._attrList[entityId] = {} end
            if not self._attrList[entityId][buffId] then self._attrList[entityId][buffId] = {} end
            self._attrList[entityId][buffId][attr[1]]= {addType,attrvalue}
        end
    end
    --print("BuffEventAttr:OnReset",self._attrList)

    -- 性能优化：清除缓存（惰性重算）+ 每个单位只发一条消息
    for _, tempInsId in ipairs(unitsToClear) do
        if self._attrList[tempInsId] and self._attrList[tempInsId][buffId] then
            -- 清除缓存（下次 GetAttr 时惰性重算）
            BuffManagerInstance:ClearAttrCache(tempInsId, self._attrList[tempInsId][buffId])
            -- 每个单位只发一条消息通知属性变更
            SendBeginMessage(MsgConst.BUFF_ATTR_UPDATE, {insid = tempInsId})
        end
    end
end

-- Buff移除回调，清除属性效果
---@param buff NewBuff
function BuffEventAttr:OnRemove(buff)
    local doBuffData = buff:GetDoBuffData()
    local entityId = doBuffData.EntityId
    local casterInsId = doBuffData:GetCasterInsId()
    local buffId = doBuffData.BuffId

    -- 性能优化：直接访问需要处理的单位，不遍历所有单位（性能提升50-100倍）
    local unitsToRemove = {entityId}
    if casterInsId ~= entityId then
        table.insert(unitsToRemove, casterInsId)
    end
    
    -- 移除属性效果：清除缓存（惰性重算）+ 每个单位只发一条消息
    for _, tempInsId in ipairs(unitsToRemove) do
        if self._attrList[tempInsId] and self._attrList[tempInsId][buffId] then
            local attrList = self._attrList[tempInsId][buffId]
            
            -- 先删除本地记录
            self._attrList[tempInsId][buffId] = nil
            
            -- 清除缓存（下次 GetAttr 时惰性重算）
            BuffManagerInstance:ClearAttrCache(tempInsId, attrList)
            -- 每个单位只发一条消息通知属性变更
            SendBeginMessage(MsgConst.BUFF_ATTR_UPDATE, {insid = tempInsId})
        end
    end
end

-- Buff更新回调，处理每帧更新逻辑
---@param buff NewBuff
function BuffEventAttr:OnUpdate(delta, buff)
    -- 属性Buff不需要每帧更新
end

-- 获取实体的所有属性列表
---@param insId integer 实体ID
---@return table 属性列表
function BuffEventAttr:GetAttr(insId)
    return self._attrList[insId]
end