--[[ 
技能进入CD事件模块
负责管理技能释放过程中的进入CD事件序列
包括CD的计算和触发
提供事件注册、更新和执行功能
支持不同类型的CD计算和触发条件
--]]

---@class LineEventEnterCD : SkillLineEvent
LineEventEnterCD = Classnew("LineEventEnterCD" , SkillLineEvent)

function LineEventEnterCD:ctor(skill,eventType , config,timeLineIndex)
    SkillLineEvent.ctor(self,skill,eventType, config,timeLineIndex)
end

-- 子类继承 TimeLine 启动的时候会统一调用
function LineEventEnterCD:OnReset()
    
end

-- 子类继承 LineEvent时间触发
function LineEventEnterCD:OnInvoke()
    local skill = self:GetSkill()
    local doSkillData = self:GetDoSkillData()
    -- local msg = BeginMessage(MsgConst.SKILL_ENTER_CD)
    -- msg.params = {insid=doSkillData.CasterInsId , skillid = doSkillData.SkillId , skillinsid = skill:GetSkillInsId() , skilllevel = doSkillData.SkillLevel}
    -- SendMessage(msg)
end

-- 子类继承 处理多段LineEvent
function LineEventEnterCD:OnUpdate()

end