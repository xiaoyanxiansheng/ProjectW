
--[[ 
召唤事件模块
负责管理技能释放过程中的召唤单位事件
包括召唤单位的类型、数量、生命周期和属性扩展
提供事件注册、更新、执行和清理的功能
支持设置召唤物的最大数量限制
可配置召唤物的属性扩展参数
作为技能时间线系统的组成部分，处理技能释放过程中的召唤效果
--]]


---@class LineEventSummon : SkillLineEvent
LineEventSummon = Classnew("LineEventSummon" , SkillLineEvent)

function LineEventSummon:ctor(skill, eventType , config,timeLineIndex)
    SkillLineEvent.ctor(self,skill,eventType, config,timeLineIndex)

    local level = self:GetDoSkillData().SkillLevel
    self._unitid = tonumber(self._config[3])
    self._count = tonumber(GetConfDataLevel(string.split_lite(tostring(self._config[4]),"_"),level))
    self._life_time = tonumber(GetConfDataLevel(string.split_lite(tostring(self._config[5]),"_"),level))
    self._maxlimit = tonumber(GetConfDataLevel(string.split_lite(tostring(self._config[6]),"_"),level))
    self._attr_extend = self._config[7] and tonumber(self._config[7]) or nil
    self._isclone = self._config[8] and tonumber(self._config[8]) == 1 or false
    self._addTriggerProb = self._config[9] and tonumber(self._config[9]) or 10000
end

-- 子类继承 TimeLine 启动的时候会统一调用
function LineEventSummon:OnReset()

end

-- 子类继承 LineEvent时间触发
function LineEventSummon:OnInvoke()
    local prob = math.random(1,10000)  -- 随机概率
    if self._addTriggerProb == nil or self._addTriggerProb < prob then
        return false  -- 概率检查失败
    end

    local doSkillData = self:GetDoSkillData()
    local skillId = doSkillData.SkillId
    local casterInsId = doSkillData.CasterInsId
    local position = self:GetTargetPosition(SettlementFlollowType.Target,0)
    local entity = GetEntityByInsId(casterInsId)
    DebugSKillLog(DebugSKillLogLayer.All,tostring(self),"LineEventSummon:OnInvoke " , self._unitid, self._count, skillId, self._life_time, self._maxlimit, self._attr_extend)
    if entity then
        entity:Summon(self._unitid, self._count, skillId, position, self._life_time, self._maxlimit, self._attr_extend,nil,self._isclone)
    end
end

-- 子类继承 处理多段LineEvent
function LineEventSummon:OnUpdate()

end

function LineEventSummon:OnSkillFinish()

end