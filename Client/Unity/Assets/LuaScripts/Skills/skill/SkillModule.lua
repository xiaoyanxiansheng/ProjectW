--- 技能模块
--- 负责管理游戏中的技能系统，包括技能释放、Buff效果和被动技能
--- 提供技能系统的初始化、更新和管理功能

-- 引入基础库
require("critcore.skill.lib.Classnew")    -- 类系统
require("critcore.skill.lib.Define")      -- 常量定义
require("critcore.skill.lib.Message")     -- 消息系统
require("critcore.skill.lib.Debug")       -- 调试工具
require("critcore.skill.lib.pool_manager") -- 对象池管理器

-- 引入技能相关组件
require("critcore.skill.lib.LayeredAttributeSystem") -- 分层属性
require("critcore.skill.SkillManager")    -- 技能管理器
require("critcore.skill.buff.BuffManager") -- Buff管理器
require("critcore.skill.passive.PassiveSkillManager") -- 被动技能管理器
require("critcore.skill.SkillAPI")        -- 技能API接口

---@type SKillManager 技能管理器实例，负责技能的创建、释放和结束
---@diagnostic disable-next-line: assign-type-mismatch
SkillManagerInstance = nil
---@type BuffManager Buff管理器实例，负责Buff的添加、移除和更新
---@diagnostic disable-next-line: assign-type-mismatch
BuffManagerInstance = nil
---@type PassiveSkillManager 被动技能管理器实例，负责被动技能的触发和效果应用
---@diagnostic disable-next-line: assign-type-mismatch
PassiveSkillManagerInstance = nil

--- 技能模块主体
SkillModule = {}

local _M = SkillModule

--- 初始化技能模块
--- 创建各个管理器实例并设置更新循环
function _M.Init()
    -- 创建各个管理器实例
    SkillManagerInstance = SkillManager.New()
    BuffManagerInstance = BuffManager.New()
    PassiveSkillManagerInstance = PassiveSkillManager.New()
    PassiveSkillManagerInstance:Setup()

    -- 设置技能模块的更新循环
    -- 原项目通过 Dota 的 SetThink 驱动；在Unity版本中，Update由C#侧主动驱动。
    -- 这里保留调用仅为兼容，不依赖其真正调度能力。
    if GameRules and GameRules.GetGameModeEntity then
        ---@diagnostic disable-next-line: param-type-mismatch, missing-parameter
        GameRules:GetGameModeEntity():SetThink("Update", _M)
    end
end

-- 清空技能模块
function _M.Clear()
    SkillManagerInstance:Clear()
    BuffManagerInstance:Clear()
    PassiveSkillManagerInstance:Clear()
end

--- 技能模块的更新函数
--- 由游戏引擎定期调用，更新所有技能相关系统
--- @return number 返回下一次调用的时间间隔
function _M.Update()
    -- 获取当前帧时间间隔
    local delta = FrameTime()
    
    -- 更新各个管理器
    SkillManagerInstance:Update(delta)    -- 更新技能状态
    BuffManagerInstance:Update(delta)     -- 更新Buff效果
    PassiveSkillManagerInstance:Update(delta) -- 更新被动技能

    -- 返回下一帧的更新间隔
    return delta
end
