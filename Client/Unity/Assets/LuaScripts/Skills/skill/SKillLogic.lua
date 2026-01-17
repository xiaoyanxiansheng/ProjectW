
-- 技能逻辑模块
-- 负责处理单个技能的生命周期、效果应用和状态管理
-- 包含技能的初始化、执行、结束和子技能管理
-- 通过时间轴控制技能的各个阶段和效果触发
-- 提供技能数据访问和状态查询的接口

require("critcore.skill.SkillTimeLine")

SkillInsId = 0

---@class SkillLogic : Classnew
---@field private _skillTableLine SkillTableLine 技能配置表数据
---@field private _doSkillData DoSkillData 技能释放数据
---@field private _handle SkillLogic 技能处理器
---@field private _onStartSkill function 技能开始回调
---@field private _onFinishSkill function 技能结束回调
---@field private _sonSkills SkillLogic[] 子技能列表
---@field private _timeLine SkillTimeLine 技能时间轴
---@field private _duration number 技能持续时间
---@field private _active boolean 技能是否激活
---@field private _skillRange any 技能范围
SkillLogic = Classnew("SkillLogic", nil)

---@param doSkillData DoSkillData 技能释放数据
---@param skillTableLine SkillTableLine 技能配置表数据
---@param handle SkillLogic 技能处理器
---@param onStartSkill function 技能开始回调
---@param onFinishSkill function 技能结束回调
function SkillLogic:ctor(handle,doSkillData, skillTableLine, onStartSkill , onFinishSkill)
    SkillInsId = SkillInsId + 1
    self._insId = SkillInsId
    self._doSkillData = doSkillData
    self._skillTableLine = skillTableLine
    self._handle = handle
    self._onStartSkill = onStartSkill
    self._onFinishSkill = onFinishSkill

    self._sonSkills = {}
end

function SkillLogic:Init()
    ---@type SkillTimeLine
    self._timeLine = nil;
    self._duration = 0

    if self._doSkillData.ParentSkill then
        self._doSkillData.ParentSkill:AddSonSkill(self)
    end

    self._skillRange = nil
end

---添加子技能
---@param sonSkill SkillLogic | nil 要添加的子技能
function SkillLogic:AddSonSkill(sonSkill)
    if sonSkill then
        table.insert(self._sonSkills , sonSkill)
    end
end

---开始释放技能
function SkillLogic:DoSkill()
    if self._active then
        return
    end

    self._active = true

    self._duration = GetConfDataLevel(self._skillTableLine.Duration,self._doSkillData.SkillLevel)
    self._timeLine = SkillTimeLine.New()
    self._timeLine:Init(self,self._skillTableLine.TimeLine)
    self._timeLine:Start()

    self._onStartSkill(self._handle, self)
end

---更新技能状态
---@param delta number 时间增量
function SkillLogic:Update(delta)
    if not self._active then
        return
    end

    -- 如果选中目标已经死亡，则结束技能 TODO

    self._timeLine:Update(delta)

    self._duration = self._duration - delta
    if self._duration <= 0 then
        self:Finish(false , true)
    end
end

---结束技能
---@param isEndParent boolean|nil 是否同时结束父技能
---@param isNoEndSon boolean|nil 是否不结束子技能
function SkillLogic:Finish(isEndParent , isNoEndSon)
    if not self._active then
        return
    end
    self._active = false

    -- 结束当前技能
    self._timeLine:SKillFinish()
    self._onFinishSkill(self._handle, self)

    -- 结束父技能
    if self._doSkillData.ParentSkill and isEndParent then
        self._doSkillData.ParentSkill:Finish(true)
    end

    if not isNoEndSon then
        -- 结束子技能
        for _, skill in pairs(self._sonSkills) do
            skill:Finish(false)
        end
        self._sonSkills = {}
    end
end

---设置技能代理
---@param agentId integer 代理ID
---@param speed number 速度
function SkillLogic:SetAgent(agentId , speed)
    self._timeLine:SetAgent(agentId , speed)
end

---设置技能目标
---@param targetInsId integer 目标实体ID
function SkillLogic:SetTarget(targetInsId)
    self._doSkillData.TargetInsId = targetInsId
    self._doSkillData.PositionNew:SetTargetInsId(targetInsId)
    if self._timeLine then self._timeLine:OnSetTarget(targetInsId) end
end

---结算击中目标
---@param hitBreakSkill integer|nil 击中打断技能标记(0|nil:忽略继续执行,1:停止当前技能,2:停止整个技能链)
---@param targetId integer 目标ID
function SkillLogic:SettlementHitTarget(hitBreakSkill, targetId)
    -- 停止整个技能链
    self._timeLine:SettlementHitTarget(targetId)
    if hitBreakSkill and hitBreakSkill > 0 then
        self:Finish(hitBreakSkill == 2)
    end

    -- -- 释放循环技能
    -- SkillManagerInstance:DoLoopSkill(clone(self._doSkillData))
end

---获取结算配置
---@param timeLineIndex integer 时间轴索引
---@return SettlementLine | nil 结算配置数据
function SkillLogic:GetSettlementTableLine(timeLineIndex)
    return self._timeLine:GetSettlementTableLine(timeLineIndex)
end

-- 检查技能是否可以被打断
---@return boolean 返回技能是否可以被打断
function SkillLogic:CanBreakSkill()
    if self._timeLine ~= nil then
        return self._timeLine:CanBreakSkill()
    end
    return false
end

-- 获取技能数据
---@return DoSkillData 返回技能数据对象
function SkillLogic:GetDoSkillData()
    return self._doSkillData
end

-- 判断是否为子技能
---@return boolean 如果是子技能返回true，否则返回false
function SkillLogic:IsSubSkill()
    return self._doSkillData.ParentSkill ~= nil
end

-- 判断技能是否处于激活状态
---@return boolean 如果技能激活返回true，否则返回false
function SkillLogic:IsActive()
    return self._active
end

function SkillLogic:GetSkillTimeLine()
    return self._timeLine
end

-- 获取技能配置表行数据
---@return SkillTableLine 返回技能配置表中的数据
function SkillLogic:GetSkillTableLine()
    return self._skillTableLine
end

---@return number 返回技能持续时间
function SkillLogic:GetDuration()
    return self._duration
end

---@return number 返回技能CD
function SkillLogic:GetSkillCD()
    return GetConfDataLevel(self._skillTableLine.Cd, self._doSkillData.SkillLevel)
end

function SkillLogic:GetSkillInsId()
    return self._insId
end

function SkillLogic:GetSkillId()
    return self._doSkillData.SkillId
end

---@return number 返回技能代理速度
function SkillLogic:GetAgentSpeed()
    return self._timeLine:GetAgentSpeed()
end

-- 开放到被动中的接口 尽量简单
function SkillLogic:ismain()
    return self._doSkillData.ParentSkill == nil
end

function SkillLogic:getdata()
    return self._doSkillData
end
function SkillLogic:gettable()
    return self._skillTableLine
end

function SkillLogic:getlocaltable()
    return GetSkillLine(self._doSkillData.SkillId)
end

function SkillLogic:GetNewTargetPositionType()
    return self._timeLine:GetNewTargetPositionType()
end