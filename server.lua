--[[
    dps-carmenu server
    /carmenu opens a category browser over qbx_core's vehicle registry.
    Spawning runs server-side through qbx.spawnVehicle, same as /car.
]]

lib.addCommand('carmenu', {
    help = 'Browse and spawn any registered vehicle (admin)',
    restricted = 'group.admin'
}, function(source)
    TriggerClientEvent('dps-carmenu:client:open', source)
end)

lib.callback.register('dps-carmenu:server:spawn', function(source, model)
    -- The command is admin-gated, but callbacks are player-triggerable:
    -- re-check the ace so a modified client cannot spawn through us.
    if not IsPlayerAceAllowed(source, 'command') then return false end
    if type(model) ~= 'string' or #model > 40 then return false end

    local ped = GetPlayerPed(source)
    local ok, netId = pcall(function()
        local _, veh = qbx.spawnVehicle({
            model = model,
            spawnSource = ped,
            warp = true,
        })
        return NetworkGetNetworkIdFromEntity(veh)
    end)
    if not ok or not netId then return false end

    local veh = NetworkGetEntityFromNetworkId(netId)
    return true, qbx.getVehiclePlate(veh)
end)
