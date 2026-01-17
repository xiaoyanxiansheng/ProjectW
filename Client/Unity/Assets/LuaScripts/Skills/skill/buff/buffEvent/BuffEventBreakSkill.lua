--[[ 
Buff事件打断技能模块
负责管理Buff事件打断技能的效果
包括技能的打断和处理
提供Buff事件的触发和处理
支持不同类型的技能打断方式
]]--

---@class BuffEventBreakSkill : NewBuffEvent
BuffEventBreakSkill = Classnew("BuffEventBreakSkill",NewBuffEvent)
    
---构造函数，初始化打断技能事件对象
---@return nil
function BuffEventBreakSkill:ctor()
    NewBuffEvent.ctor(self ,BuffEvent.BreakSkill)
end

---当Buff添加时触发的事件处理函数
---@param buff NewBuff Buff对象
---@return nil
function BuffEventBreakSkill:OnAdd(buff)
    -- 获取Buff数据
    local doBuffData = buff:GetDoBuffData()
    -- 获取实体ID
    local entityId = doBuffData.EntityId
    -- 初始化技能ID和等级
    local SkillId = 0
    local SkillInsId = 0
    local SkillLevel = 0
    -- 如果存在技能数据，则获取技能ID和等级
    if doBuffData.Skill then
        local doSkillData = doBuffData.Skill:GetDoSkillData()
        SkillId = doSkillData.SkillId
        SkillLevel = doSkillData.SkillLevel
        SkillInsId = doBuffData.Skill:GetSkillInsId()
    end

    -- 调用技能管理器打断当前技能
    SkillManagerInstance:BreakSkill(entityId)

    -- 发送技能打断消息通知
    local msg = BeginMessage(MsgConst.Skill_DO_BREAK)
    msg.params = {insid=entityId,skillid=SkillId,skillinsid=SkillInsId,skilllevel=SkillLevel}
    SendMessage(msg)
end