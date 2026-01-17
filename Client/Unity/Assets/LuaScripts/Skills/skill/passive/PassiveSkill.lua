--[[ 
被动技能模块
负责管理被动技能的触发条件、效果应用和状态维护
包括被动技能的初始化、更新和效果处理
提供被动技能的注册、触发和修改接口
作为被动技能系统的核心控制器，协调被动技能与其他游戏系统的交互
--]]

DoPassiveSkillData = Classnew("DoPassiveSkillData" , nil)

function DoPassiveSkillData:ctor(insId, passiveId , passiveLevel)
    self.EntityId = insId
    self.PassiveId = passiveId
    self.PassiveLevel = passiveLevel
end

---@diagnostic disable: need-check-nil
---@class PassiveSkill : Classnew
PassiveSkill = Classnew("PassiveSkill" , nil)

-- 构造函数，初始化被动技能实例
---@param insId integer 实体ID
---@param passiveSkillId integer 被动技能ID
---@param passiveSkillLevel integer 被动技能等级
---@param bindSkill boolean 是否绑定技能
function PassiveSkill:ctor(insId , passiveSkillId , passiveSkillLevel , bindSkill)
    self._doPassiveSkillData = DoPassiveSkillData.New(insId, passiveSkillId , passiveSkillLevel)
    self._insId = insId                                      -- 实体ID
    self._passiveSkillId = passiveSkillId                    -- 被动技能ID
    self._bindSkill = bindSkill                              -- 是否绑定技能
    ---@type PassiveTableLineLevel
    self._activeLevelConfig = nil                            -- 当前等级配置
    self._activeTimeLineIndexs = {}                          -- 激活的时间线索引
    self._activeBuffChange = {}                              -- 激活的Buff变化
    ---@type table
    self._cacheCondition = nil                               -- 缓存的触发条件
    self._active = false                                     -- 是否激活
    self._remove = false                                     -- 是否移除

    -- CD相关
    self._cd = 0.0                                             -- CD时间
    self._cdPassTime = 0.0                                     -- CD已过时间
    self._cdCanActive = false                                -- CD是否可激活

    self._isUpdate = false
    self._isMove = false
    self._moveSpeed = 0.0
    self._moveDistance = 0.0
    -- 伴生技能
    -- self._associatedSkills = {}

    self:Reset(passiveSkillLevel)                            -- 重置技能状态
end

-- 重置被动技能状态
---@param passiveSkillLevel integer 被动技能等级
function PassiveSkill:Reset(passiveSkillLevel)
    self._passiveSkillConfig = GetPassiveSkillLine(self._passiveSkillId) -- 被动技能配置
    self._doPassiveSkillData.PassiveLevel = passiveSkillLevel
    self._passiveSkillLevel = passiveSkillLevel              -- 设置技能等级
    local duration = self._passiveSkillConfig.Duration       -- 持续时间配置
    local interval = self._passiveSkillConfig.Interval       -- 间隔时间配置
    self._duration = duration and GetConfDataLevel(duration, passiveSkillLevel) or 0  -- 计算持续时间
    self._interval = interval and GetConfDataLevel(interval, passiveSkillLevel) or 0  -- 计算间隔时间
    self._addTriggerProb = GetConfDataLevel(self._passiveSkillConfig.AddTriggerProb, passiveSkillLevel)  -- 添加触发概率
    self._removeTriggerProb = GetConfDataLevel(self._passiveSkillConfig.RemoveTriggerProb, passiveSkillLevel)  -- 移除触发概率
    self._activeLevelConfig = self:GetLevelConfig()          -- 获取当前等级配置

    local cd = self._passiveSkillConfig.Cd                   -- CD配置
    self._cd = cd and GetConfDataLevel(cd, passiveSkillLevel) or 0  -- 计算CD时间
    self._cdCanActive = self._cd == 0

    self._checkCD = math.max(self._interval, 0.1)
    self._checkCDTime = 0.0


    local AddCondition = self._activeLevelConfig.AddCondition or ""
    local RemoveCondition = self._activeLevelConfig.RemoveCondition or ""
    if AddCondition:find("ispassiveupdate") or RemoveCondition:find("ispassiveupdate") then
        self._isUpdate = true
        --if AddCondition:find("movespeed") or RemoveCondition:find("movespeed") or AddCondition:find("movedistance") or RemoveCondition:find("movedistance") then
            self._isMove = true
            self._moveSpeed = 0.0
            self._moveDistance = 0.0
        --end
    end
end

function PassiveSkill:Remove()
    -- for _, skill in ipairs(self._associatedSkills) do
    --     SkillManagerInstance:DoFinishSkill(skill)
    -- end
    -- self._associatedSkills = {}
end

-- 更新被动技能状态
---@param delta number 时间增量
function PassiveSkill:Update(delta)
    -- CD更新
    self._cdCanActive = self._cdPassTime >= self._cd  -- 检查CD是否可激活
    self._cdPassTime = self._cdPassTime + delta       -- 累加CD时间

    if self._isUpdate then
        if self._checkCDTime >= self._checkCD then
            self._checkCDTime = 0
            PassiveSkillManagerInstance:TRIGGER(PassiveSkillVariable.IsPassiveUpdate,self._insId,function(condition)
                if self._isMove then
                    local entity = GetEntityByInsId(condition.InsId)
                    local curPosition = entity:GetPosition()  -- 获取当前位置
                    if self._prePosition == nil then
                        self._prePosition = curPosition
                    end
                    if self._moveDistance == nil then
                        self._moveDistance = 0
                    end
                    local deltaDistance = (curPosition - self._prePosition):Length()
                    self._moveDistance = self._moveDistance + deltaDistance
                    self._prePosition = curPosition
                    local moveSpeed = deltaDistance / (delta * 10)
                    condition[PassiveSkillVariable.MoveSpeed] = moveSpeed
                    condition[PassiveSkillVariable.MoveDistance] = self._moveDistance
                end
            end)
        end
        self._checkCDTime = self._checkCDTime + delta
        return
    else
        -- 间隔更新
        if not self._active then
            return
        end

        if self._interval == 0 then
            if self._passInterval == 0 then
                self:StartEffect()  -- 开始效果
            end
            self._passInterval = self._passInterval + delta
        else
            if self._passInterval >= self._interval then
                self._passInterval = 0
                self:StartEffect()  -- 开始效果
            else
                self._passInterval = self._passInterval + delta
            end
        end

        if self._durationPassTime >= self._duration then
            self._active = false  -- 持续时间结束，停止激活
        end
        self._durationPassTime = self._durationPassTime + delta  -- 累加持续时间
    end
end

-- 检查并应用条件
---@param conditionData table 条件数据
---@return boolean 是否应用成功
function PassiveSkill:CheckAndApply(conditionData )
    if not self._cdCanActive then
        return false  -- CD未结束，不能激活
    end

    if self._active then
        return false  -- 已经激活，不能再次激活
    end

    local prob = math.random(1,10000)  -- 随机概率
    if self._addTriggerProb == nil or self._addTriggerProb < prob then
        return false  -- 概率检查失败
    end

    local AddCondition = self._activeLevelConfig.AddCondition
    if AddCondition == nil or AddCondition == "" then
        return false  -- 没有添加条件
    end

    -- DebugSKillLog(DebugSKillLogLayer.All, "0 PassiveSkill:CheckAndApply insId passiveSkillId passiveSkillLevel AddCondition conditionData" , self._insId, self._passiveSkillId , self._passiveSkillLevel , AddCondition, table.tostring(conditionData,nil,nil))

    if self:Check(AddCondition , conditionData) then
        self._cdPassTime = 0  -- 重置CD时间
        self._cacheCondition = conditionData  -- 缓存条件数据
        DebugSKillLog(DebugSKillLogLayer.All, "1 PassiveSkill:CheckAndApply insId passiveSkillId passiveSkillLevel AddCondition conditionData" , self._insId, self._passiveSkillId , self._passiveSkillLevel)
        self._durationPassTime = 0  -- 重置持续时间
        self._passInterval = self._interval  -- 设置间隔时间
        self._remove = false  -- 重置移除标记
        self._active = self._duration > 0  -- 设置激活状态
        if not self._active then
            self:StartEffect()  -- 如果不需要持续，直接开始效果
        end
        return true
    end

    return false
end

-- 检查并移除条件
---@param conditionData table 条件数据
function PassiveSkill:CheckAndRemove(conditionData)
    if self._remove then
        return  -- 已经移除，不需要再次检查
    end

    local prob = math.random(1,10000)  -- 随机概率
    if self._removeTriggerProb == nil or self._removeTriggerProb < prob then
        return  -- 概率检查失败
    end

    local RemoveCondition = self._activeLevelConfig.RemoveCondition
    if RemoveCondition == nil or RemoveCondition == "" then
        return  -- 没有移除条件
    end

    if self:Check(RemoveCondition , conditionData) then
        self._remove = true  -- 设置移除标记
        self._active = false  -- 停止激活
        self._cacheCondition = conditionData  -- 缓存条件数据
        self:EndEffect()  -- 结束效果
        DebugSKillLog(DebugSKillLogLayer.All, "1 PassiveSkill:CheckAndRemove insId passiveSkillId passiveSkillLevel RemoveCondition conditionData" , self._insId, self._passiveSkillId , self._passiveSkillLevel)
    end
end

-- 检查条件是否满足
---@param evaluateCondition string 条件表达式
---@param conditionData table 条件数据
---@return boolean 是否满足条件
function PassiveSkill:Check(evaluateCondition, conditionData)
    conditionData[PassiveSkillVariable.PassiveIns] = self
    
    -- 优化后的缓存结构
    local isCache = PassiveSkillManagerInstance:IsStringCache(evaluateCondition)
    if not isCache then
        -- 分割并存储每一行用于调试
        local expLines = {}
        local processedExp = evaluateCondition:gsub("\r\n", "\n"):gsub("\r", "\n")
        if not processedExp:match("\n$") then
            processedExp = processedExp .. "\n"
        end
        
        local i = 1
        for line in processedExp:gmatch("([^\n]*)\n") do
            expLines[i] = line
            i = i + 1
        end
        
        local func, err = load(processedExp, "expression_chunk")
        
        if not func then
            print("条件表达式加载错误:", err)
            print("原始表达式:\n", evaluateCondition)
            return false
        end
        
        local cacheEntry = { 
            func = func, 
            lines = expLines,
            original = evaluateCondition
        }
        PassiveSkillManagerInstance:SetStringCache(evaluateCondition, cacheEntry)
    end

    local cacheEntry = PassiveSkillManagerInstance:GetStringCache(evaluateCondition, false)
    if not cacheEntry then
        return false
    end
    
    local env = setmetatable(conditionData, {__index = _G})
    local success, result = pcall(setfenv(cacheEntry.func, env))
    if not success then
        -- 提取更详细的错误信息
        local errorMsg = tostring(result)
        local lineNum = tonumber(errorMsg:match(":(%d+):")) or 0
        
        print("===== Error:条件表达式运行错误详情 =====")
        print("原始错误: " .. errorMsg)
        
        -- 显示完整的表达式
        print("完整表达式:")
        for i, line in ipairs(cacheEntry.lines) do
            local marker = (i == lineNum) and "==>" or "   "
            print(string.format("%s %2d: %s", marker, i, line))
        end
        
        -- 对出错行进行更详细分析
        if lineNum > 0 and lineNum <= #cacheEntry.lines then
            local errorLine = cacheEntry.lines[lineNum]
            print("\n出错行详细分析:")
            print("行号: " .. lineNum)
            print("代码: " .. errorLine)
            
            -- 分析可能的nil值
            if errorMsg:find("attempt to index a nil value") then
                -- 提取可能为nil的变量
                local vars = {}
                for var in errorLine:gmatch("([%w_]+)[%.:]") do
                    table.insert(vars, var)
                end
                
                print("可能为nil的变量:")
                for _, var in ipairs(vars) do
                    local value = env[var]
                    local valueType = type(value)
                    local valueStr = (value == nil) and "nil" or 
                                    (valueType == "table") and ("table: " .. tostring(value)) or 
                                    tostring(value)
                    
                    print(string.format("  %s = %s", var, valueStr))
                    
                    -- 如果变量是表但为nil，检查相似名称的变量
                    if value == nil then
                        print("  检查相似变量名:")
                        for k, v in pairs(env) do
                            if type(k) == "string" and k:lower() == var:lower() and k ~= var then
                                print(string.format("    %s = %s", k, type(v)))
                            end
                        end
                    end
                end
            end
        end
        
        print("环境变量:")
        for k, v in pairs(env) do
            if type(v) ~= "function" and k ~= "_G" then
                local valueStr = (type(v) == "table") and ("table: " .. tostring(v)) or tostring(v)
                print(string.format("  %s = %s", k, valueStr))
            end
        end
        
        print("=================================")
        return false
    end

---@diagnostic disable-next-line: return-type-mismatch
    return success and result
end

-- 获取当前等级配置
---@return PassiveTableLineLevel | nil 等级配置
function PassiveSkill:GetLevelConfig()
    for _, levelConfig in pairs(self._passiveSkillConfig.Level) do
        if self._passiveSkillLevel >= levelConfig.Change[1] and self._passiveSkillLevel <= levelConfig.Change[2] then
            return levelConfig
        end
    end
    return nil
end

-- 开始应用效果
function PassiveSkill:StartEffect()
    if self._activeLevelConfig.BuffId then
        for key, buffId in ipairs(self._activeLevelConfig.BuffId) do
            ---@type DoBuffData
            local doBuffData = DoBuffData.New()
            doBuffData.EntityId = self._cacheCondition.InsId
            doBuffData.BuffId = buffId
            doBuffData.BuffLevel = self._passiveSkillLevel
            doBuffData.Skill = self._cacheCondition[PassiveSkillVariable.SkillIns]
            BuffManagerInstance:AddBuff(doBuffData)  -- 添加Buff
        end
    end

    if self._activeLevelConfig.SkillId ~= nil then
        local skillIns = self._cacheCondition[PassiveSkillVariable.SkillIns]
        for key, skillId in ipairs(self._activeLevelConfig.SkillId) do
            local doSkillData = skillIns and clone(skillIns:GetDoSkillData()) or DoSkillData.New()
            doSkillData.CasterInsId = self._insId
            doSkillData.SkillId = skillId
            doSkillData.SkillLevel = self._passiveSkillLevel
            doSkillData.ParentSkill = skillIns
            local skill = SkillManagerInstance:DoSkill(doSkillData)  -- 执行技能
            -- if skill then
            --     table.insert(self._associatedSkills, skill)
            -- end
        end
    end
end

-- 结束效果
function PassiveSkill:EndEffect()
    if self._activeLevelConfig.BuffId then
        for key, buffId in ipairs(self._activeLevelConfig.BuffId) do
            local entityId = self._cacheCondition[PassiveSkillVariable.TargetInsId]
        BuffManagerInstance:RemoveBuff(entityId , buffId)  -- 移除Buff
        end
    end
    -- if self._activeLevelConfig.SkillId ~= nil and self._activeLevelConfig.SkillId > 0 then
    --     SkillManagerInstance:DoFinishSkill( self._insId , self._activeLevelConfig.SkillId)
    -- end
    self._activeTimeLineIndexs = nil  -- 清空时间线索引
    self._activeBuffChange = nil      -- 清空Buff变化
end

-- 获取修改后的新值
---@param old any 原始值
---@param new any 新值
---@return any 修改后的值
function PassiveSkill:GetModifyNewValue(old , new)
    local rv = new
    local news = tostring(new)
    ---@type table
    local sp = string.split_lite(news , "#")
    if #sp == 2 then
        if type(old) == "number" then
            local v = tonumber(sp[1])
            local t = tonumber(sp[2])
            if t == 1 then
                rv = old + v  -- 加法修改
            elseif t == 2 then
                rv = old * v  -- 乘法修改
            end
        end
    end
    return rv
end

-- 是否绑定技能
---@return boolean 是否绑定技能
function PassiveSkill:IsBindSkill()
    return self._bindSkill
end

-- 开放到被动中的接口 尽量简单
function PassiveSkill:getdata()
    return self._doPassiveSkillData
end