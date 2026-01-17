---@diagnostic disable: missing-parameter, param-type-mismatch, invisible, undefined-field, need-check-nil
-- spawnunit 10001 2 -12458.840820 -13762.625000 128.000000

------------------------ 命令 ------------------------
function ReloadSkillModule(fileName)
    if fileName == "skill" then
        for moduleName, _ in pairs(package.loaded) do
            if moduleName:match("^critcore.skill") or moduleName:match("^confdata") then
                package.loaded[moduleName] = nil
            end
        end
        
        ConfData._game_conf = {}
        local status, module = pcall(require, "critcore.skill.SkillModule")
        SkillModule.Init()
        if status then
            print( "技能模块加载成功")
        else
            print("技能模块加载失败" .. ": " .. module)
        end
    else
        local fullPath = fileName

        -- 清除缓存并重新加载指定的脚本
        package.loaded[fullPath] = nil
        local status, module = pcall(require, fullPath)

        if status then
            print(fileName .. "加载成功")
        else
            print("加载失败 " .. fileName .. ": " .. module)
        end
    end
end

-- 注册一个控制台命令，用户可以输入文件名来重载脚本
Convars:RegisterCommand("reload_lua", function(commandName, fileName , reloadPassive)
    -- 被动数据需要重新加载
    local cachePassiveSkillList = {}
    local passiveSkillList = PassiveSkillManagerInstance._passiveSkillList
    for insId, passiveSkills in pairs(passiveSkillList) do
        for passiveSkillId, passiveSkill in pairs(passiveSkills) do
            table.insert(cachePassiveSkillList,{insId , passiveSkillId , passiveSkill._passiveSkillLevel , passiveSkill._bindSkill})
        end
    end

    ReloadSkillModule(fileName)

    if reloadPassive == "1" then
        for _, cache in ipairs(cachePassiveSkillList) do
            PassiveSkillManagerInstance:Add(cache[1] , cache[2] , cache[3] , cache[4])
        end
    end
end, "Reloads a Lua script from the skill folder", FCVAR_CHEAT)

-- ConfData:Get(表名, ID, 字段名, 缺省值) -- 返回具体的字段值，如果字段没有配置会返回缺省值
-- ConfData:GetLine(表名, ID) -- 返回指定ID的数据，如果ID不存在会返回nil
-- ConfData:GetTable(表名) -- 返回整个表
-- ConfData:CheckAndGetLine(表名, ID) -- 返回指定ID的数据，没有ID会报错
-- ConfData:CheckAndGet(表名, ID, 字段名) -- 返回具体的字段值，没有ID、没有字段都会报错
-- ConfData:GetGameConfig(key)  -- 返回GameConfig表的值

local moster = nil
Convars:RegisterCommand("debug_spawn_uint", function(commandName, insid)
    ---@type any
    local entitys = Units:SpawnUnit(tonumber(insid), 'count',1,  Vector(-12458.840820 ,-13762.625000, 128.000000))
    for _, entity in pairs(entitys) do
        moster = entity
        break
    end
end, "Command to cast skill on entity by entityId", FCVAR_CHEAT)

Convars:RegisterCommand("DebugSkill_DoSkill", function(commandName, skillId)

    local players = Lobby:GetAllPlayers()
    for _, value in pairs(players) do
        local caster = value:GetController()
        
        local insId = caster:GetInsid()
        skillId = tonumber(skillId)
        local doSkillData = DoSkillData.New()
        doSkillData.CasterInsId = insId
        doSkillData.TargetInsId = moster and moster:GetInsid() or nil
        doSkillData.SkillId = skillId
        doSkillData.SkillLevel = 1
        doSkillData.Position = moster and moster:GetPosition() or nil
        SkillAPI.DoSkill(doSkillData)

        -- print(insId,moster:GetInsid())
        -- SkillAPI.DoEvent(MsgConst.ENTITY_ATTACK, {casterinsid=insId, targetinsid=moster:GetInsid()})
    end

end, "Command to cast skill on entity by entityId", FCVAR_CHEAT)

Convars:RegisterCommand("DebugSkill_AddPassive", function(commandName, passiveSkillId)
    local players = Lobby:GetAllPlayers()
    for _, value in pairs(players) do
        ---@type integer
---@diagnostic disable-next-line: assign-type-mismatch
        local insId = value:GetController():GetInsid()
        ---@type integer
---@diagnostic disable-next-line: assign-type-mismatch
        passiveSkillId = tonumber(passiveSkillId)
        PassiveSkillManagerInstance:Add(insId , passiveSkillId,1)
    end

end, "Command to cast skill on entity by entityId", FCVAR_CHEAT)

Convars:RegisterCommand("DebugSkill_AddBuff", function(commandName, buffId)

    local players = Lobby:GetAllPlayers()
    for _, value in pairs(players) do
        local insId = value:GetController():GetInsid()
        buffId = tonumber(buffId)
        local doBuffData = DoBuffData.New()
        doBuffData.EntityId = insId
        doBuffData.BuffId = buffId
        doBuffData.BuffLevel = 1
        BuffManagerInstance:AddBuff(doBuffData)
    end

end, "Command to cast skill on entity by entityId", FCVAR_CHEAT)

---@type any
local weaponEntity = nil
Convars:RegisterCommand("ToggleWeapon", function(commandName, weaponAseetPath)

    local players = Lobby:GetAllPlayers()
    for _, value in pairs(players) do
        local insId = value:GetController():GetInsid()
        if weaponEntity and IsValidEntity(weaponEntity) then
            weaponEntity:RemoveSelf()
        end

        weaponEntity = SpawnEntityFromTableSynchronous("prop_dynamic", {
            -- model = "mode/pc_avata/dot_pc_sword_f_02/dot_pc_sword_f_02_weapon_1.vmdl",
            model = weaponAseetPath,
            origin = Vector(0,0,0)
            })
        local entity = GetEntityByInsId(insId)
        weaponEntity:FollowEntityMerge(entity.__DotaEntity, "Attach_ACT_DOTA_ATTACK1")
    end

end, "Command to cast skill on entity by entityId", FCVAR_CHEAT)

local weaponEntity = nil
Convars:RegisterCommand("Card", function(commandName, weaponAseetPath)

    local players = Lobby:GetAllPlayers()
    for _, value in pairs(players) do
        -- local insId = value:GetController():GetInsid()
        local pid = value:GetIndex()
        ---@type any
        local player = PlayerResource:GetPlayer(pid)
        CustomGameEventManager:Send_ServerToPlayer(player, "show_card_scene_local", {})
        break
    end

end, "Command to cast skill on entity by entityId", FCVAR_CHEAT)

local weaponEntity = nil
---@diagnostic disable-next-line: redundant-parameter
Convars:RegisterCommand("lua", function(p, v1, v2)
    _G[v1] = tonumber(v2)
end, "error", FCVAR_CHEAT)

Convars:RegisterCommand("reloadtable", function()
    local tableNames = {"Skill","SkillBuff","SkillPassive","SkillSettlement"}
    for _, tableName in pairs(tableNames) do
        local moduleName = "confdata." .. tableName
        ConfData._game_conf[tableName] = nil
        package.loaded[moduleName] = nil
    end
    PassiveSkillManagerInstance:ClearStringCache()
    for _, passiveSkills in pairs(PassiveSkillManagerInstance._passiveSkillList) do
        for _, passiveSkill in pairs(passiveSkills) do
            passiveSkill:Reset(passiveSkill._passiveSkillLevel)
        end
    end
    
    print("reloadtable " , tableNames)
end, "error", FCVAR_CHEAT)

-- Convars:RegisterCommand("performance_reset", function()
--     Performance_analyzer.reset_all()
-- end, "error", FCVAR_CHEAT)

-- Convars:RegisterCommand("performance_print_all", function()
--     Performance_analyzer.print_function_stats()
-- end, "error", FCVAR_CHEAT)

-- Convars:RegisterCommand("performance_print_tree", function(t,path)
--     Performance_analyzer.print_path_call_tree(path)
-- end, "error", FCVAR_CHEAT)

-- Convars:RegisterCommand("print_call_tree_stats", function(t,path)
--     Performance_analyzer.print_call_tree_stats()
-- end, "error", FCVAR_CHEAT)

-- 注册一个控制台命令
Convars:RegisterCommand("show_model_test", function()
    print("show_model_test")
    -- 发送事件到UI层
    CustomGameEventManager:Send_ServerToAllClients("show_model_test", {})
end, "打开模型测试界面", 0)

------------------------ 打印 ------------------------
DebugSkillLog = ConfData:GetSystemConfig('SkillLogLevel')
DebugSkillRange = 0 --关闭伤害范围显示

DebugSKillLogLayer = {
    Common = 0,
    All = 1,
    Warning = 2
}

local ShowDebugSKillLogLayer = DebugSKillLogLayer.All

function DebugSKillLog(layer , ...)
    if DebugSkillLog == 0 then
        return
    end

    if layer == DebugSKillLogLayer.Common and ShowDebugSKillLogLayer == DebugSKillLogLayer.All 
        or ShowDebugSKillLogLayer == DebugSKillLogLayer.All 
        or layer == DebugSKillLogLayer.Warning 
        or layer == DebugSKillLogLayer.All then
        local ps = {...}
        local p = {"DebugSKill " , Time()}
        for _, value in ipairs(ps) do
            if type(value) == "table" and value.__cname == nil then 
                if value.x and value.y and value.z then 
                    table.insert(p,string.format("{x:%f y:%f z:%f}",value.x,value.y,value.z))
                else
                    for _, v in ipairs(value) do
                        table.insert(p,v)
                    end
                end
            else
                table.insert(p,value)
            end
        end
        if layer == DebugSKillLogLayer.Warning then
            error(table.tostring(p,nil))
        else
            print(unpack(p))
        end
        print("\r\n")
    end
end

---@param data any
function DebugSKillLog_DoSkillData(layer, s ,data, ...)
    if DebugSkillLog == 0 then
        return
    end

    local printdata = clone(data)
    printdata.ParentSkill = nil
    printdata.class = nil
    if printdata.DoSkillData then
        printdata.DoSkillData.class = nil
        printdata.DoSkillData.ParentSkill = nil
    end
    DebugSKillLog(layer,s,table.tostring(printdata,nil,nil), ...)
end

function DrawDebugFan(position, radius, angle, forward, duration , c)
    if DebugSkillRange == 0 then
        return
    end

    c = c or Vector(255, 0, 0)
    local segments = 36  -- 扇形分段数，越多越平滑
    local halfAngle = math.rad(angle / 2)  -- 半角（弧度制）
    local step = angle / segments          -- 每段的角度
    local forwardVector = forward:Normalized()
    local startAngle = math.atan2(forwardVector.y, forwardVector.x) - halfAngle

    -- 存储所有分段点坐标
    local points = {}
    for i = 0, segments do
        local currentAngle = math.rad(step * i) + startAngle
        local x = position.x + radius * math.cos(currentAngle)
        local y = position.y + radius * math.sin(currentAngle)
        table.insert(points, Vector(x, y, position.z))
    end

    if angle < 360 then
        -- 如果是小于360度的扇形
        -- 先画扇形的弧线部分
        for i = 1, #points do
            local prev = points[i-1]
            local curr = points[i]
            if prev and curr then
                DebugDrawLineEX(prev, curr, c.x, c.y, c.z, true, duration)
            end
        end

        -- 再画从中心到弧线两端点的线
        DebugDrawLineEX(position, points[1], c.x, c.y, c.z, true, duration)
        DebugDrawLineEX(position, points[#points], c.x, c.y, c.z, true, duration)
    else
        -- 如果是360度的情况，形成一个完整的圆
        -- 只需要画环形，不画中心线
        for i = 2, #points do
            local prev = points[i-1]
            local curr = points[i]
            DebugDrawLineEX(prev, curr, c.x, c.y, c.z, true, duration)
        end
        -- 闭合圆弧
        DebugDrawLineEX(points[#points], points[1], c.x, c.y, c.z, true, duration)
    end
end

function DrawDebugFanRing(position,radius , innerRadius, angle, forward, duration, c)
    if DebugSkillRange == 0 then
        return
    end

    c = c or Vector(255, 0, 0)
    local segments = 36
    local halfAngle = math.rad(angle / 2)
    local step = angle / segments
    local forwardVector = forward:Normalized()
    local startAngle = math.atan2(forwardVector.y, forwardVector.x) - halfAngle

    local outerPoints = {}
    local innerPoints = {}

    -- 生成外弧点
    for i = 0, segments do
        local currentAngle = math.rad(step * i) + startAngle
        local ox = position.x + radius * math.cos(currentAngle)
        local oy = position.y + radius * math.sin(currentAngle)
        table.insert(outerPoints, Vector(ox, oy, position.z))
    end

    -- 生成内弧点
    for i = 0, segments do
        local currentAngle = math.rad(step * i) + startAngle
        local ix = position.x + innerRadius * math.cos(currentAngle)
        local iy = position.y + innerRadius * math.sin(currentAngle)
        table.insert(innerPoints, Vector(ix, iy, position.z))
    end

    if angle < 360 then
        -- 非360度环形扇区
        -- 绘制外弧
        for i = 2, #outerPoints do
            DebugDrawLineEX(outerPoints[i-1], outerPoints[i], c.x, c.y, c.z, true, duration)
        end

        -- 绘制内弧
        for i = 2, #innerPoints do
            DebugDrawLineEX(innerPoints[i-1], innerPoints[i], c.x, c.y, c.z, true, duration)
        end

        -- 连接外弧与内弧的两端点形成扇区边界
        DebugDrawLineEX(outerPoints[1], innerPoints[1], c.x, c.y, c.z, true, duration)
        DebugDrawLineEX(outerPoints[#outerPoints], innerPoints[#innerPoints], c.x, c.y, c.z, true, duration)
    else
        -- 360度环形
        -- 外弧闭合
        for i = 2, #outerPoints do
            DebugDrawLineEX(outerPoints[i-1], outerPoints[i], c.x, c.y, c.z, true, duration)
        end
        DebugDrawLineEX(outerPoints[#outerPoints], outerPoints[1], c.x, c.y, c.z, true, duration)

        -- 内弧闭合
        for i = 2, #innerPoints do
            DebugDrawLineEX(innerPoints[i-1], innerPoints[i], c.x, c.y, c.z, true, duration)
        end
        DebugDrawLineEX(innerPoints[#innerPoints], innerPoints[1], c.x, c.y, c.z, true, duration)
    end
end

function DrawDebugRectangle(center, width, length, forward, duration, c)
    if DebugSkillRange == 0 then
        return
    end

    c = c or Vector(255, 0, 0)
    -- 计算垂直于forward的right方向
    local right = RotateVector(forward:Normalized(), 90)

    local halfWidth = width / 2
    local halfLength = length / 2

    -- 计算四个顶点
    local C1 = center + forward * halfLength + right * halfWidth
    local C2 = center + forward * halfLength - right * halfWidth
    local C3 = center - forward * halfLength - right * halfWidth
    local C4 = center - forward * halfLength + right * halfWidth

    -- 绘制矩形四条边
    DebugDrawLineEX(C1, C2, c.x, c.y, c.z, true, duration)
    DebugDrawLineEX(C2, C3, c.x, c.y, c.z, true, duration)
    DebugDrawLineEX(C3, C4, c.x, c.y, c.z, true, duration)
    DebugDrawLineEX(C4, C1, c.x, c.y, c.z, true, duration)
end

function DebugDrawLineEX(origin, target, r, g, b, ztest, duration)
    origin = GetGroundPosition(origin,nil)
    target = GetGroundPosition(target,nil)
    DebugDrawLine(origin, target, r, g, b, ztest, duration)
end

-- 辅助函数：旋转向量，假设二维平面（z不变），angle为度数
function RotateVector(vec, angle)
    local radian = math.rad(angle)
    local cosTheta = math.cos(radian)
    local sinTheta = math.sin(radian)
    return Vector(vec.x * cosTheta - vec.y * sinTheta, vec.x * sinTheta + vec.y * cosTheta, vec.z)
end


-- -- 示例调用
-- local center = Vector(0, 0, 0)     -- 扇形中心点
-- local forward = Vector(1, 0, 0)    -- 扇形朝向
-- local radius = 300                 -- 扇形半径
-- local angle = 90                   -- 扇形角度（度）
-- local rgb = Vector(255, 0, 0)      -- 颜色（红色）
-- local alpha = 255                  -- 透明度（目前无效）
-- local duration = 5                 -- 显示时间
-- local ztest = false                -- 深度测试

-- DebugDrawSolidSector(center, forward, radius, angle, rgb, alpha, duration, ztest)


RegisterMessage(MsgConst.BUFF_ADD , function(msg)
    DebugSKillLog(DebugSKillLogLayer.All,"MsgConst.BUFF_ADD" , table.tostring(msg.params))
end , nil)

RegisterMessage(MsgConst.BUFF_REMOVE , function(msg)
    DebugSKillLog(DebugSKillLogLayer.All,"MsgConst.BUFF_REMOVE" , table.tostring(msg.params))
end , nil)

RegisterMessage(MsgConst.BUFF_EVENT_ADD , function(msg)
    DebugSKillLog(DebugSKillLogLayer.All,"MsgConst.BUFF_EVENT_ADD" , table.tostring(msg.params))
end , nil)

RegisterMessage(MsgConst.BUFF_EVENT_REMOVE , function(msg)
    DebugSKillLog(DebugSKillLogLayer.All,"MsgConst.BUFF_EVENT_REMOVE" , table.tostring(msg.params))
end , nil)

RegisterMessage(MsgConst.SKILL_TIMELINE_EVENT_STATE , function(msg)
    DebugSKillLog(DebugSKillLogLayer.All,"MsgConst.SKILL_TIMELINE_EVENT_STATE" , table.tostring(msg.params))
end , nil)

RegisterMessage(MsgConst.SKill_DO_START , function(msg)
    DebugSKillLog(DebugSKillLogLayer.All,"MsgConst.SKill_DO_START" , table.tostring(msg.params))
end , nil)

RegisterMessage(MsgConst.SKill_DO_FINISH , function(msg)
    DebugSKillLog(DebugSKillLogLayer.All,"MsgConst.SKill_DO_FINISH" , table.tostring(msg.params))
end , nil)

RegisterMessage(MsgConst.SKILL_ENTER_CD , function(msg)
    DebugSKillLog(DebugSKillLogLayer.All,"MsgConst.SKILL_ENTER_CD" , table.tostring(msg.params))
end , nil)

RegisterMessage(MsgConst.Skill_DO_BREAK , function(msg)
    DebugSKillLog(DebugSKillLogLayer.All,"MsgConst.Skill_DO_BREAK" , table.tostring(msg.params))
end , nil)

RegisterMessage(MsgConst.BUFF_OVERLAY_UPDATE , function(msg)
    DebugSKillLog(DebugSKillLogLayer.All,"MsgConst.BUFF_OVERLAY_UPDATE",table.tostring(msg.params))
end , nil)

RegisterMessage(MsgConst.ENTITY_PRIMEVALATTR_UPDATE , function(msg)
    DebugSKillLog(DebugSKillLogLayer.All,"MsgConst.ENTITY_PRIMEVALATTR_UPDATE" , table.tostring(msg.params))
end , nil)

RegisterMessage(MsgConst.ENTITY_DEATH , function(msg)
    DebugSKillLog(DebugSKillLogLayer.All,"MsgConst.ENTITY_DEATH" , table.tostring(msg.params))
end , nil)

RegisterMessage(MsgConst.ENTITY_KILL , function(msg)
    DebugSKillLog(DebugSKillLogLayer.All,"MsgConst.ENTITY_KILL" , table.tostring(msg.params))
end , nil)

RegisterMessage(MsgConst.SHIELD_UPDATE_VALUE , function(msg)
    DebugSKillLog(DebugSKillLogLayer.All,"MsgConst.SHIELD_UPDATE_VALUE" , table.tostring(msg.params))
end , nil)

RegisterMessage(MsgConst.SHIELD_UPDATE_REDUCE , function(msg)
    DebugSKillLog(DebugSKillLogLayer.All,"MsgConst.SHIELD_UPDATE_REDUCE" , table.tostring(msg.params))
end , nil)

RegisterMessage(MsgConst.BUFF_ATTR_UPDATE , function(msg)
    DebugSKillLog(DebugSKillLogLayer.All,"MsgConst.BUFF_ATTR_UPDATE" , table.tostring(msg.params),table.tostring(BuffManagerInstance._attrCacheList[msg.params.insid]),table.tostring(BuffManagerInstance._attrCacheList))
end , nil)