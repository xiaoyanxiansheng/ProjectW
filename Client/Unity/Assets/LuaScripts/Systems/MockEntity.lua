---@diagnostic disable: undefined-global, undefined-field
--[[ 
Phase1 Mock实体系统
目标：让技能系统能跑起来，不关心真实Unity对象。

约定：
- insId 是技能系统里使用的“实例ID”
- Units:GetUnitByInsid(insId) 返回一个带基础接口的实体对象：
  - IsAlive()
  - GetPosition()/SetPosition()
  - GetForwardVector()
  - GetSkillLevel(skillId)
--]]

local MockEntity = {}
MockEntity.__index = MockEntity

------------------------------------------------------------
-- Dota实体代理（中间层兼容）
-- 目标：不修改 Skills/ 下的原始Lua技能逻辑，通过提供 __DotaEntity + 常用方法桩保证不报错。
------------------------------------------------------------
---@param owner table
---@return table
local function CreateDotaEntityProxy(owner)
    local proxy = {
        __owner = owner,
        __angles = Vector(0, 0, 0), -- pitch/yaw/roll
    }

    function proxy:entindex()
        return (owner and owner._insId) or 0
    end

    function proxy:IsNull()
        return owner == nil
    end

    function proxy:GetAbsOrigin()
        if owner and owner.GetPosition then
            return owner:GetPosition()
        end
        return Vector(0, 0, 0)
    end

    function proxy:SetAbsOrigin(pos)
        if owner and owner.SetPosition then
            owner:SetPosition(pos)
        end
    end

    function proxy:GetForwardVector()
        if owner and owner.GetForwardVector then
            return owner:GetForwardVector()
        end
        return Vector(1, 0, 0)
    end

    function proxy:SetForwardVector(dir)
        if owner and owner.SetForwardVector then
            owner:SetForwardVector(dir)
        end
    end

    function proxy:StartGestureWithFadeAndPlaybackRate(_, _, _, _)
        -- Unity版本动画由表现层处理；这里只做占位
    end

    function proxy:AddNoDraw()
        -- Unity版本可由Renderer控制；这里仅占位
    end

    function proxy:RemoveNoDraw()
        -- Unity版本可由Renderer控制；这里仅占位
    end

    function proxy:SetMoveCapability(_)
        -- Unity版本移动能力由控制器/状态机决定；这里仅占位
    end

    function proxy:FollowEntityMerge(_, _)
        -- Debug/武器跟随等Dota接口占位
    end

    function proxy:GetAnglesAsVector()
        return self.__angles or Vector(0, 0, 0)
    end

    function proxy:SetAngles(pitch, yaw, roll)
        self.__angles = Vector(pitch or 0, yaw or 0, roll or 0)
    end

    return proxy
end

function MockEntity.New(insId)
    local o = {
        _insId = insId,
        _alive = true,
        _hp = 100,
        _pos = Vector(0, 0, 0),
        _forward = Vector(1, 0, 0),
        _camp = 1,
        _skillLevel = {}, -- [skillId]=level
    }
    -- Skills系统大量使用 entity.__DotaEntity:*（Dota句柄），这里提供代理对象做兼容。
    o.__DotaEntity = CreateDotaEntityProxy(o)
    return setmetatable(o, MockEntity)
end

function MockEntity:IsAlive()
    return self._alive
end

function MockEntity:IsValid()
    return true
end

function MockEntity:GetInsid()
    return self._insId
end

function MockEntity:StopButNotBreak()
    -- Unity版本忽略
end

function MockEntity:GetDotaEntity()
    return self.__DotaEntity
end

function MockEntity:SetAlive(alive)
    self._alive = alive and true or false
end

function MockEntity:GetHP()
    return self._hp or 0
end

function MockEntity:SetHP(hp)
    hp = hp or 0
    if hp < 0 then hp = 0 end
    self._hp = hp
    if self._hp <= 0 then
        self._alive = false
    end
end

function MockEntity:AddHP(delta)
    self:SetHP((self._hp or 0) + (delta or 0))
end

function MockEntity:GetPosition()
    return self._pos
end

function MockEntity:SetPosition(pos)
    self._pos = pos
end

function MockEntity:GetForwardVector()
    return self._forward
end

function MockEntity:SetForwardVector(f)
    self._forward = f
end

function MockEntity:GetSkillLevel(skillId)
    return self._skillLevel[skillId] or 1
end

-- ===== 属性接口（Phase1：默认值，后续接入真实属性系统）=====
function MockEntity:GetAttr_MaxHP()
    return 100
end

function MockEntity:GetAttr_BuffOddsAdd(_)
    return 0
end

function MockEntity:GetAttr_BuffOddsMinus(_)
    return 0
end

function MockEntity:GetAttr_BuffTimeAdd(_)
    return 0
end

function MockEntity:GetAttr_BuffTimeMinus(_)
    return 0
end

function MockEntity:GetCamp()
    return self._camp or 0
end

function MockEntity:SetCamp(camp)
    self._camp = camp or 0
end

function MockEntity:SetSkillLevel(skillId, level)
    self._skillLevel[skillId] = level
end

------------------------------------------------------------
-- Units 单例（Define.lua 里会用）
------------------------------------------------------------
Units = Units or {}
Units.__units = Units.__units or {}
Units.__EntityidToInsid = Units.__EntityidToInsid or {}

function Units:GetUnitByInsid(insId)
    return self.__units[insId]
end

function Units:AddUnit(insId, entity)
    self.__units[insId] = entity
end

function Units:RemoveUnit(insId)
    self.__units[insId] = nil
end

-- ===== 范围查询（Phase1：简化实现，满足技能系统逻辑）=====
function Units:GetUnitsByArea(center, radius, _, includeAlive, _)
    local result = {}
    if center == nil then
        return result
    end
    radius = radius or 9999999
    for _, unit in pairs(self.__units) do
        if unit then
            if includeAlive == false or unit:IsAlive() then
                local d = (unit:GetPosition() - center):Length2D()
                if d <= radius then
                    table.insert(result, unit)
                end
            end
        end
    end
    return result
end

function Units:GetUnitsByRectArea(_, _, _, _, _, includeAlive, _)
    -- 简化：先退化为返回全部单位（后续Phase2再精确实现）
    local result = {}
    for _, unit in pairs(self.__units) do
        if unit then
            if includeAlive == false or unit:IsAlive() then
                table.insert(result, unit)
            end
        end
    end
    return result
end

function Units:SpawnUnit(_, _, _, _)
    return {}
end

function Units:SpawnSpecial(_, _, _)
    return {}
end

-- Dota2单位缩放（与UnityBridge/CoordAdapter保持一致）
local DOTA_UNIT_SCALE = 0.0254
local function UnityToSkill(u)
    return u / DOTA_UNIT_SCALE
end

-- Phase1：创建两个默认实体，方便验证（1=施法者，2=目标）
if Units:GetUnitByInsid(1) == nil then
    local caster = MockEntity.New(1)
    caster:SetCamp(1)
    caster:SetPosition(Vector(0, 0, 0))
    Units:AddUnit(1, caster)
end

if Units:GetUnitByInsid(2) == nil then
    local target = MockEntity.New(2)
    target:SetCamp(2)
    -- Unity(5,0,0) -> Skill(5/scale,0,0)
    target:SetPosition(Vector(UnityToSkill(5), 0, 0))
    Units:AddUnit(2, target)
end

-- PhaseB：额外的Dummy实体（用于范围/结算/选目标测试）
local function _addDummy(insId, camp, skillPos)
    if Units:GetUnitByInsid(insId) ~= nil then
        return
    end
    local e = MockEntity.New(insId)
    e:SetCamp(camp)
    e:SetPosition(skillPos)
    Units:AddUnit(insId, e)
end

-- 注意：Lua技能坐标系 x/y平面，z高度；Unity中 Dummy_<id> 初始位置为 (x, y, z)
-- 并应用 Dota2 -> Unity 缩放：Unity(6,0,1) -> Skill(6/scale,0,1/scale)
_addDummy(3, 2, Vector(0, UnityToSkill(6), UnityToSkill(1)))
_addDummy(4, 2, Vector(UnityToSkill(6), 0, UnityToSkill(1)))
_addDummy(5, 2, Vector(UnityToSkill(-6), 0, UnityToSkill(1)))
_addDummy(6, 2, Vector(0, UnityToSkill(-6), UnityToSkill(1)))
_addDummy(7, 2, Vector(UnityToSkill(4), UnityToSkill(4), UnityToSkill(1)))
_addDummy(8, 2, Vector(UnityToSkill(-4), UnityToSkill(4), UnityToSkill(1)))

return MockEntity

