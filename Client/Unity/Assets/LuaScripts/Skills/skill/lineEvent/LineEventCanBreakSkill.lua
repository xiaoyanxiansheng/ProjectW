--[[
    LineEventCanBreakSkill 模块功能:
    
    该模块实现了一个可打断的技能线性事件，主要用于处理技能释放过程中的文本显示和打断逻辑。
    
    主要功能:
    1. 在技能释放过程中显示指定的文本
    2. 根据配置的持续时间控制文本显示
    3. 提供技能打断判断逻辑，当未达到配置的持续时间时，技能可被打断
    
    使用方式:
    在技能配置中添加该事件，并配置相应的持续时间和文本列表索引
]]

---@class LineEventCanBreakSkill : SkillLineEvent
LineEventCanBreakSkill = Classnew("LineEventCanBreakSkill" , SkillLineEvent)

function LineEventCanBreakSkill:ctor(skill,eventType , config,timeLineIndex)
    SkillLineEvent.ctor(self,skill,eventType, config,timeLineIndex)

    self._lineDuration = tonumber(self._config[3])
    self._lineTextListIndex = tonumber(self._config[4])

    self._passTime = 0.0
end

-- 子类继承 TimeLine 启动的时候会统一调用
function LineEventCanBreakSkill:OnReset()
    self._passTime = 0.0
end

-- 子类继承 LineEvent时间触发
function LineEventCanBreakSkill:OnInvoke()
    local doSkillData = self:GetDoSkillData()
    local skill = self:GetSkill()
    local msg = BeginMessage(MsgConst.SKILL_TIMELINE_EVENT_READLINE)
    local params = {duration=self._lineDuration,textlistindex=self._lineTextListIndex}
    msg.params = {insid = doSkillData.CasterInsId, skillid = doSkillData.SkillId , skillinsid = skill:GetSkillInsId() , skilllevel = doSkillData.SkillLevel ,params = params}
    SendMessage(msg)
end

-- 子类继承 处理多段LineEvent
function LineEventCanBreakSkill:OnUpdate(delta)
    self._passTime = self._passTime + delta
end

-- 技能释放过程中能否被打断
function LineEventCanBreakSkill:CanBreakSkill()
    return self._passTime < self._lineDuration
end