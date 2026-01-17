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
    return nil
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
    target:SetPosition(Vector(5, 0, 0))
    Units:AddUnit(2, target)
end

return MockEntity

