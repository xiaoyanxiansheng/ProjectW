if ClientParticleManager == nil then
    ClientParticleManager = class({})
end

-- 存储特效与玩家的对应关系
ClientParticleManager.particles = {}

-- 创建特效的替代函数 - 接口与ParticleManager:CreateParticle相同
function ClientParticleManager:CreateParticle(particlePath, attachType, entity, playerID)
    -- 生成唯一标识符
    local uniqueID = DoUniqueString("particle")
    -- 如果指定了玩家ID，则只发送给该玩家
    if playerID then
        local player = PlayerResource:GetPlayer(playerID)
        if player then
            CustomGameEventManager:Send_ServerToPlayer(player, "client_create_particle", {
                unique_id = uniqueID,
                particle_path = particlePath,
                attach_type = attachType,
                entity_index = entity and entity:entindex() or 0
            })
            
            -- 记录该特效
            if not self.particles[playerID] then
                self.particles[playerID] = {}
            end
            self.particles[playerID][uniqueID] = true
        end
    else
        -- 否则发送给所有玩家
        CustomGameEventManager:Send_ServerToAllClients("client_create_particle", {
            unique_id = uniqueID,
            particle_path = particlePath,
            attach_type = attachType,
            entity_index = entity and entity:entindex() or 0
        })
    end
    
    return uniqueID
end

-- 设置特效控制点 - 接口与ParticleManager:SetParticleControl相同
function ClientParticleManager:SetParticleControl(uniqueID, controlPoint, position, playerID)
    if playerID then
        local player = PlayerResource:GetPlayer(playerID)
        if player and self.particles[playerID] and self.particles[playerID][uniqueID] then
            CustomGameEventManager:Send_ServerToPlayer(player, "client_set_particle_control", {
                particle_id = uniqueID,
                control_point = controlPoint,
                position = {
                    x = position.x,
                    y = position.y,
                    z = position.z
                }
            })
        end
    else
        -- 发送给所有玩家
        CustomGameEventManager:Send_ServerToAllClients("client_set_particle_control", {
            particle_id = uniqueID,
            control_point = controlPoint,
            position = {
                x = position.x,
                y = position.y,
                z = position.z
            }
        })
    end
end

-- 销毁特效
function ClientParticleManager:DestroyParticle(uniqueID, immediate, playerID)
    if playerID then
        local player = PlayerResource:GetPlayer(playerID)
        if player and self.particles[playerID] and self.particles[playerID][uniqueID] then
            CustomGameEventManager:Send_ServerToPlayer(player, "client_destroy_particle", {
                particle_id = uniqueID,
                immediate = immediate or false
            })
            self.particles[playerID][uniqueID] = nil
        end
    else
        -- 发送给所有玩家
        CustomGameEventManager:Send_ServerToAllClients("client_destroy_particle", {
            particle_id = uniqueID,
            immediate = immediate or false
        })
    end
end

-- 释放特效索引
function ClientParticleManager:ReleaseParticleIndex(uniqueID, playerID)
    self:DestroyParticle(uniqueID, true, playerID)
end

return ClientParticleManager