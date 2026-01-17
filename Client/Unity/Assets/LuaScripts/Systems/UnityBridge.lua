---@diagnostic disable: undefined-global, undefined-field
--[[ 
Unity兼容层（Phase1）
目标：尽量不改原技能逻辑，仅补齐其依赖的全局对象/函数，让 SkillModule.Init/Update 能跑起来。

这里优先提供：
- bit.lshift 等位运算（用于BuffEvent标志位）
- Vector 类型（支持 + - * /，以及 :Length() :Normalized() :Cross()）
- ConfData:GetLine（直接读取 LuaScripts/Config 下的Lua配置表）
- Units / GetEntityByInsId / GetEntityPosition（Phase1使用Mock实体）
- GameRules:GetGameModeEntity():SetThink（由Unity侧Update驱动，这里仅做兼容不报错）
--]]

------------------------------------------------------------
-- bit 库（只要能支持 lshift，后续需要再补齐 band/bor）
------------------------------------------------------------
if bit == nil then
    bit = {}
end

if bit.lshift == nil then
    ---@param x integer
    ---@param n integer
    ---@return integer
    function bit.lshift(x, n)
        -- 用算术近似实现32位左移（用于flag足够）
        if n <= 0 then return x end
        local v = x * (2 ^ n)
        -- 限制到32位正数范围
        v = v % 4294967296
        return v
    end
end

------------------------------------------------------------
-- Vector 类型（Lua侧实现，满足现有技能代码用法）
------------------------------------------------------------
local VectorMT = {}
VectorMT.__index = VectorMT

function VectorMT:Length()
    return math.sqrt(self.x * self.x + self.y * self.y + self.z * self.z)
end

function VectorMT:Normalized()
    local len = self:Length()
    if len < 1e-6 then
        return Vector(0, 0, 0)
    end
    return Vector(self.x / len, self.y / len, self.z / len)
end

function VectorMT:Cross(b)
    return Vector(
        self.y * b.z - self.z * b.y,
        self.z * b.x - self.x * b.z,
        self.x * b.y - self.y * b.x
    )
end

function VectorMT:Dot(b)
    return self.x * b.x + self.y * b.y + self.z * b.z
end

function VectorMT:Length2D()
    return math.sqrt(self.x * self.x + self.y * self.y)
end

function VectorMT.__add(a, b)
    return Vector(a.x + b.x, a.y + b.y, a.z + b.z)
end

function VectorMT.__sub(a, b)
    return Vector(a.x - b.x, a.y - b.y, a.z - b.z)
end

function VectorMT.__mul(a, b)
    if type(a) == "number" then
        return Vector(a * b.x, a * b.y, a * b.z)
    elseif type(b) == "number" then
        return Vector(a.x * b, a.y * b, a.z * b)
    end
    -- 向量点乘目前不需要（需要时再补）
    return 0
end

function VectorMT.__div(a, b)
    if type(b) == "number" then
        return Vector(a.x / b, a.y / b, a.z / b)
    end
    return Vector(0, 0, 0)
end

function VectorMT.__tostring(v)
    return string.format("Vector(%.3f, %.3f, %.3f)", v.x, v.y, v.z)
end

---构造Vector
---@param x number
---@param y number
---@param z number
---@return Vector
function Vector(x, y, z)
    return setmetatable({ x = x or 0, y = y or 0, z = z or 0 }, VectorMT)
end

------------------------------------------------------------
-- table.tostring（日志/调试用）
------------------------------------------------------------
if table.tostring == nil then
    local function _tostring(v, depth, visited)
        depth = depth or 0
        if depth > 4 then
            return "..."
        end
        local tv = type(v)
        if tv == "string" then
            return string.format("%q", v)
        elseif tv ~= "table" then
            return tostring(v)
        end
        visited = visited or {}
        if visited[v] then
            return "<cycle>"
        end
        visited[v] = true
        local parts = {}
        for k, vv in pairs(v) do
            table.insert(parts, "[" .. _tostring(k, depth + 1, visited) .. "]=" .. _tostring(vv, depth + 1, visited))
        end
        return "{" .. table.concat(parts, ",") .. "}"
    end

    function table.tostring(t)
        return _tostring(t, 0, {})
    end
end

------------------------------------------------------------
-- string.split_lite（部分LineEvent会用）
------------------------------------------------------------
if string.split_lite == nil then
    ---@param s string
    ---@param sep string
    ---@return string[]
    function string.split_lite(s, sep)
        if s == nil then return {} end
        sep = sep or "_"
        local result = {}
        local pattern = "([^" .. sep .. "]+)"
        for part in tostring(s):gmatch(pattern) do
            table.insert(result, part)
        end
        return result
    end
end

------------------------------------------------------------
-- 基础系统桩：GameRules（SkillModule.Init 会调用 SetThink）
------------------------------------------------------------
GameRules = GameRules or {}
local _gameModeEntity = _gameModeEntity or {}

function GameRules:GetGameModeEntity()
    return _gameModeEntity
end

-- 兼容Dota接口：这里只记录，不做真正调度（Unity侧会主动每帧调用 SkillModule.Update）
function _gameModeEntity:SetThink(funcName, obj)
    self.__thinkFuncName = funcName
    self.__thinkObj = obj
end

------------------------------------------------------------
-- 控制台命令系统（Debug.lua 会在加载时 RegisterCommand）
------------------------------------------------------------
Convars = Convars or {}
FCVAR_CHEAT = FCVAR_CHEAT or 0
function Convars:RegisterCommand(_, _, _, _)
    -- Unity版本不需要Dota控制台命令；这里仅确保加载阶段不报错
end

------------------------------------------------------------
-- Config：直接加载Lua配置表（LuaScripts/Config/*.lua return table）
------------------------------------------------------------
ConfData = ConfData or {}
ConfData.__cache = ConfData.__cache or {}
ConfData.__gameConfig = ConfData.__gameConfig or {
    SkillDefaultSound = "",
    SkillInitialHitRate = 0,
}

function ConfData:GetGameConfig(key)
    return self.__gameConfig[key]
end

-- 系统配置（Debug.lua 会读取 SkillLogLevel 等）
function ConfData:GetSystemConfig(_)
    return 0
end

function ConfData:GetTable(name)
    if self.__cache[name] == nil then
        -- 约定：name == "Skill" -> require("Config.Skill")
        local moduleName = "Config." .. name
        local ok, tbl = pcall(require, moduleName)
        if not ok then
            error("ConfData:GetTable load failed: " .. tostring(moduleName) .. " err=" .. tostring(tbl))
        end
        self.__cache[name] = tbl
    end
    return self.__cache[name]
end

function ConfData:GetLine(name, id)
    local t = self:GetTable(name)
    if t == nil then return nil end
    return t[id]
end

------------------------------------------------------------
-- Phase1：实体系统（Mock）
------------------------------------------------------------
require("Systems.MockEntity")

-- 对外接口（Define.lua 里会用）
function GetEntityByInsId(insId)
    return Units:GetUnitByInsid(insId)
end

function GetEntityPosition(insId)
    local e = GetEntityByInsId(insId)
    if e == nil then return Vector(0, 0, 0) end
    return e:GetPosition()
end

------------------------------------------------------------
-- 其他系统桩（后续Phase3/4再替换为真实实现）
------------------------------------------------------------
GridNav = GridNav or {}
function GridNav:IsTraversable(_) return true end
function GridNav:IsBlocked(_) return false end

function GetGroundPosition(position, _) return position end
function GetGroundHeight(_, _) return 0 end

ParticleManager = ParticleManager or { __id = 0 }
PATTACH_WORLDORIGIN = PATTACH_WORLDORIGIN or 0
function ParticleManager:CreateParticle(_, _, _) self.__id = self.__id + 1; return self.__id end
function ParticleManager:SetParticleControl(_, _, _) end
function ParticleManager:SetParticleControlTransform(_, _, _, _) end
function ParticleManager:DestroyParticle(_, _) end
function ParticleManager:ReleaseParticleIndex(_) end

-- QAngle（用于某些Particle事件设置朝向；Unity版本仅占位）
function QAngle(pitch, yaw, roll)
    return { pitch = pitch or 0, yaw = yaw or 0, roll = roll or 0 }
end

Fight = Fight or {}
function Fight:ApplyDamage(attacker, targeter, skill_id, skill_level, times, _)
    if attacker == nil or targeter == nil then
        return
    end
    if targeter.IsAlive and (not targeter:IsAlive()) then
        return
    end

    -- Phase3：先用“可跑”的简化伤害模型（后续接入真实战斗系统）
    local base = 10
    local dmg = math.floor(base * (times or 1))
    if dmg < 0 then dmg = 0 end

    if targeter.AddHP then
        targeter:AddHP(-dmg)
    end

    if MsgConst and SendBeginMessage and attacker.GetInsid and targeter.GetInsid then
        SendBeginMessage(MsgConst.ENTITY_DAMAGED, {
            casterinsid = attacker:GetInsid(),
            targetinsid = targeter:GetInsid(),
            skillid = skill_id or 0,
            damage = dmg,
            isdie = targeter.IsAlive and (not targeter:IsAlive()) or false,
            damage_type = 0,
        })
    end
end

function Fight:ApplyHeal(_, targeter, _, _, times, _)
    if targeter == nil then return end
    local base = 10
    local heal = math.floor(base * (times or 1))
    if heal < 0 then heal = 0 end
    if targeter.AddHP then
        targeter:AddHP(heal)
    end
end

Lobby = Lobby or {}
function Lobby:GetAllPlayers() return {} end
function Lobby:IsOpenSound(_) return false end
function EmitSoundOnEntityForPlayer(_, _, _) end

CustomGameEventManager = CustomGameEventManager or {}
function CustomGameEventManager:Send_ServerToAllClients(_, _) end

-- 阵营枚举（Phase1占位，后续接入真实阵营系统）
EnumUnitCamp = EnumUnitCamp or { Monster = 2 }

-- 战斗伤害类型（被动技能会用）
EnumFightDamageType = EnumFightDamageType or {
    Normal = 0,
    Critical = 2,
}

