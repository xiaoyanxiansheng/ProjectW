--[[
TraceRecorder：结构化Trace记录器（测试环境用）
目标：不改技能核心逻辑，通过消息系统观测关键事件，便于定位偏差来源。

记录内容（第一版）：
- 技能开始/结束/打断
- 时间线状态事件
- 结算命中列表
- Buff增删/叠加/事件增删/属性更新

注意：只用于测试与验证，不参与正式玩法逻辑。
--]]

local _M = {}

require("critcore.skill.lib.Define")       -- table.ContainValue 等工具方法（Message.lua依赖）
require("critcore.skill.lib.Message")      -- 确保 RegisterMessage/SendMessage 等全局存在
require("critcore.skill.lib.MessageConst") -- 确保 MsgConst 全局存在

local _maxLines = 200
local _lines = {}
local _inited = false

local function _pushLine(tag, params)
    local t = 0
    if Time ~= nil then t = Time() end

    local p = ""
    if params ~= nil then
        if type(params) == "table" and table.tostring ~= nil then
            p = table.tostring(params)
        else
            p = tostring(params)
        end
    end

    local line = string.format("[%.3f] %s %s", t, tag, p)
    table.insert(_lines, line)
    if #_lines > _maxLines then
        table.remove(_lines, 1)
    end
end

function _M.Init()
    if _inited then return end
    _inited = true

    -- 技能事件
    RegisterMessage(MsgConst.SKill_DO_START, function(msg) _pushLine("SKill_DO_START", msg and msg.params) end)
    RegisterMessage(MsgConst.SKill_DO_FINISH, function(msg) _pushLine("SKill_DO_FINISH", msg and msg.params) end)
    RegisterMessage(MsgConst.Skill_DO_BREAK, function(msg) _pushLine("Skill_DO_BREAK", msg and msg.params) end)

    -- 时间线/结算
    RegisterMessage(MsgConst.SKILL_TIMELINE_EVENT_STATE, function(msg) _pushLine("SKILL_TIMELINE_EVENT_STATE", msg and msg.params) end)
    RegisterMessage(MsgConst.SKILL_TIMELINE_EVENT_READLINE, function(msg) _pushLine("SKILL_TIMELINE_EVENT_READLINE", msg and msg.params) end)
    RegisterMessage(MsgConst.SKILL_TIMELINE_EVENT_SETTLEMENT_HIT, function(msg) _pushLine("SKILL_TIMELINE_EVENT_SETTLEMENT_HIT", msg and msg.params) end)

    -- Buff
    RegisterMessage(MsgConst.BUFF_ADD, function(msg) _pushLine("BUFF_ADD", msg and msg.params) end)
    RegisterMessage(MsgConst.BUFF_REMOVE, function(msg) _pushLine("BUFF_REMOVE", msg and msg.params) end)
    RegisterMessage(MsgConst.BUFF_OVERLAY_UPDATE, function(msg) _pushLine("BUFF_OVERLAY_UPDATE", msg and msg.params) end)
    RegisterMessage(MsgConst.BUFF_EVENT_ADD, function(msg) _pushLine("BUFF_EVENT_ADD", msg and msg.params) end)
    RegisterMessage(MsgConst.BUFF_EVENT_REMOVE, function(msg) _pushLine("BUFF_EVENT_REMOVE", msg and msg.params) end)
    RegisterMessage(MsgConst.BUFF_ATTR_UPDATE, function(msg) _pushLine("BUFF_ATTR_UPDATE", msg and msg.params) end)

    _pushLine("TraceRecorder.Init", nil)
end

function _M.Clear()
    _lines = {}
end

function _M.GetRecentLines(n)
    n = n or 20
    if n <= 0 then return "" end

    local start = math.max(1, #_lines - n + 1)
    local buff = {}
    for i = start, #_lines do
        table.insert(buff, _lines[i])
    end
    return table.concat(buff, "\n")
end

-- C#侧直接调用的全局函数（避免每次DoString拼Lua）
function TraceRecorder_GetRecentLines(n)
    return _M.GetRecentLines(n)
end

function TraceRecorder_Clear()
    return _M.Clear()
end

return _M

