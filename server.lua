--[[
    dps-carmenu server
    Access is the ace `dps.carmenu` (server.cfg grants it to group.admin and group.tester).
    Spawns run through qbx.spawnVehicle, the same path /car uses. Replace mode removes the
    vehicle the player sits in first (Damon 2026-09-27: "remove anything" on this box).
]]

local STATE_FILE = '/opt/fivem/tools/state/vehicles_found.json'
local PACKS, CLASSES = {}, {}

-- Read the fleet state file the registry builder writes each boot: model -> streaming resource, game class.
CreateThread(function()
    local fh = io.open(STATE_FILE, 'r')
    if not fh then
        print(('[dps-carmenu] no fleet state file at %s; packs show as vanilla'):format(STATE_FILE))
        return
    end
    local raw = fh:read('*a'); fh:close()
    local ok, data = pcall(json.decode, raw)
    if not ok or type(data) ~= 'table' then
        print('[dps-carmenu] fleet state file unreadable; packs show as vanilla')
        return
    end
    local n = 0
    for model, v in pairs(data) do
        if type(v) == 'table' then
            PACKS[model:lower()] = v.res or 'vanilla'
            if v.class then CLASSES[model:lower()] = tostring(v.class):gsub('^%l', string.upper) end
            n = n + 1
        end
    end
    print(('[dps-carmenu] fleet state loaded: %d models with pack info'):format(n))
end)

local function allowed(src)
    return IsPlayerAceAllowed(src, 'dps.carmenu')
end

lib.callback.register('dps-carmenu:server:open', function(source, alreadyHasData)
    if not allowed(source) then return false end
    if alreadyHasData then return true end
    return true, { packs = PACKS, classes = CLASSES }
end)

local function registryHas(model)
    local reg = exports.qbx_core:GetVehiclesByName()
    return reg and reg[model] ~= nil
end

local function removeVehicle(veh)
    if veh == 0 or not DoesEntityExist(veh) then return end
    DeleteEntity(veh)
end

lib.callback.register('dps-carmenu:server:spawn', function(source, model, mode, beside)
    if not allowed(source) then return false, 'no access' end
    if type(model) ~= 'string' or #model > 40 or not registryHas(model) then return false, 'unknown model' end

    local ped = GetPlayerPed(source)
    local started = GetGameTimer()
    local spawnSource, warp = ped, true
    if mode == 'beside' and type(beside) == 'table' and type(beside.x) == 'number' then
        spawnSource = vector4(beside.x + 0.0, beside.y + 0.0, beside.z + 0.0, (beside.w or 0.0) + 0.0)
        warp = false
    else
        local current = GetVehiclePedIsIn(ped, false)
        if current ~= 0 then
            -- remember where the old one stood so the new one takes the exact spot
            local c, h = GetEntityCoords(current), GetEntityHeading(current)
            removeVehicle(current)
            spawnSource = vector4(c.x, c.y, c.z, h)
            warp = ped -- qbx.spawnVehicle warps this ped when spawnSource is a coordinate
        end
    end

    local ok, netId = pcall(function()
        local _, veh = qbx.spawnVehicle({ model = model, spawnSource = spawnSource, warp = warp })
        return NetworkGetNetworkIdFromEntity(veh)
    end)
    if not ok or not netId then
        print(('[dps-carmenu] spawn FAILED for %s (src %s, %s) after %d ms: %s'):format(model, source, mode, GetGameTimer() - started, tostring(netId)))
        return false, 'spawn failed'
    end
    local veh = NetworkGetEntityFromNetworkId(netId)
    local plate = qbx.getVehiclePlate(veh)
    print(('[dps-carmenu] spawned %s plate %s for src %s (%s) in %d ms'):format(model, tostring(plate), source, mode, GetGameTimer() - started))
    return true, plate, netId
end)

lib.callback.register('dps-carmenu:server:delete', function(source, netId)
    if not allowed(source) then return false end
    if type(netId) ~= 'number' then return false end
    local veh = NetworkGetEntityFromNetworkId(netId)
    if veh == 0 or not DoesEntityExist(veh) then return false end
    removeVehicle(veh)
    return true
end)
