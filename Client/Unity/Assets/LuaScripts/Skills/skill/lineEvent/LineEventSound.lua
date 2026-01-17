--[[ 
音效事件模块
负责管理技能释放过程中的音效播放事件
包括技能音效的播放、停止和参数控制
提供音效事件的注册、更新和执行功能
支持不同类型的音效和播放模式
作为技能时间线系统的组成部分，处理技能释放过程中的音效反馈
--]]

---@class LineEventSound : SkillLineEvent
LineEventSound = Classnew("LineEventSound" , SkillLineEvent)

function LineEventSound:ctor(skill,eventType , config,timeLineIndex)
    SkillLineEvent.ctor(self,skill,eventType, config,timeLineIndex)
    self.soundPath =  self._config[3]
end

-- 子类继承 LineEvent时间触发
function LineEventSound:OnInvoke()
    if not self.soundPath or self.soundPath == "" then
        return
    end
    PlaySound(self.soundPath, self:GetDoSkillData().CasterInsId)
end