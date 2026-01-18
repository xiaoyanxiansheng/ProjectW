--[[
SkillCapabilityScanner：技能能力扫描器（测试环境用）
读取 Config/Skill.lua 的技能配置，把时间线用到的事件类型列出来，帮助快速定位测试重点。
--]]

local _M = {}

require("critcore.skill.lib.Define") -- ESkillEventType

local function _buildIdToName()
    local map = {}
    if ESkillEventType ~= nil then
        for k, v in pairs(ESkillEventType) do
            map[v] = k
        end
    end
    return map
end

local function _collectTypes(skillCfg)
    local set = {}
    local list = {}
    if skillCfg == nil then
        return list
    end

    local tl = skillCfg.TimeLine
    if tl == nil then
        return list
    end

    for _, e in pairs(tl) do
        local t = e and e.Type
        if type(t) == "number" and set[t] ~= true then
            set[t] = true
            table.insert(list, t)
        end
    end

    table.sort(list, function(a, b) return a < b end)
    return list
end

local function _hintForType(typeId)
    if typeId == ESkillEventType.SettlementObject then return "旧版结算（SettlementObject）" end
    if typeId == ESkillEventType.PositionNew then return "关键：位置/朝向计算（NewPosition）" end
    if typeId == ESkillEventType.SettlementObjectNew then return "关键：范围/结算（扇形/矩形/环形/单体）" end
    if typeId == ESkillEventType.TargetSelect then return "旧版选目标（TargetSelect）" end
    if typeId == ESkillEventType.TargetSelectNew then return "关键：选目标（TargetSelectNew）" end
    if typeId == ESkillEventType.Displacement then return "旧版位移（Displacement）" end
    if typeId == ESkillEventType.DisplacementNew then return "关键：位移（持续插值/合法位置）" end
    if typeId == ESkillEventType.ParticleNew then return "表现：特效（可先桩）" end
    if typeId == ESkillEventType.BulletNew then return "关键：子弹（碰撞/命中）" end
    return ""
end

function _M.ScanToText(skillId)
    local cfg = nil
    if ConfData ~= nil and ConfData.GetLine ~= nil then
        cfg = ConfData:GetLine("Skill", skillId)
    else
        return "ConfData:GetLine 不可用"
    end

    if cfg == nil then
        return "Skill配置不存在：SkillId=" .. tostring(skillId)
    end

    local idToName = _buildIdToName()
    local types = _collectTypes(cfg)

    local lines = {}
    table.insert(lines, string.format("SkillId=%s  TimeLineEventTypes=%d", tostring(skillId), #types))
    local named = {}
    for _, typeId in ipairs(types) do
        local name = idToName[typeId] or "Unknown"
        local hint = _hintForType(typeId)
        table.insert(named, string.format("%d(%s)", typeId, name))
        if hint ~= "" then
            table.insert(lines, string.format("- %d (%s)  %s", typeId, name, hint))
        else
            table.insert(lines, string.format("- %d (%s)", typeId, name))
        end
    end
    if #named > 0 then
        table.insert(lines, 3, "TypesNamed=" .. table.concat(named, ", "))
    end
    return table.concat(lines, "\n")
end

function SkillCapability_ScanToText(skillId)
    return _M.ScanToText(skillId)
end

return _M

