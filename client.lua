--[[
    dps-carmenu client
    Category browser -> vehicle list -> spawn (keys included).
    Registry comes live from qbx_core, so curation edits show up
    on the next restart with no changes here.
]]

local CATEGORY_ORDER = {
    'race', 'super', 'sports', 'sportsclassics', 'muscle', 'sedans', 'coupes',
    'compacts', 'suvs', 'pickups', 'offroad', 'motorcycles', 'vans', 'trailers', 'boats',
    'helicopters', 'planes', 'openwheel', 'emergency', 'military', 'service',
    'commercial', 'industrial', 'utility', 'rc', 'trains', 'cycles',
}

local function spawnVehicle(model, label)
    local ok, plate = lib.callback.await('dps-carmenu:server:spawn', false, model)
    if not ok then
        lib.notify({ title = 'Car Menu', description = ('Failed to spawn %s'):format(model), type = 'error' })
        return
    end
    if plate and GetResourceState('wasabi_carlock') == 'started' then
        exports.wasabi_carlock:GiveKey(plate)
    end
    lib.notify({ title = 'Car Menu', description = ('%s spawned'):format(label or model), type = 'success' })
end

local function openCategory(cat, vehicles)
    table.sort(vehicles, function(a, b) return (a.brand .. a.name) < (b.brand .. b.name) end)
    local options = {}
    for _, v in ipairs(vehicles) do
        options[#options + 1] = {
            title = (v.brand and v.brand ~= '' and (v.brand .. ' ') or '') .. v.name,
            description = v.model,
            arrow = false,
            onSelect = function() spawnVehicle(v.model, v.name) end,
        }
    end
    lib.registerContext({
        id = 'dps_carmenu_' .. cat,
        title = ('%s (%d)'):format(cat:upper(), #vehicles),
        menu = 'dps_carmenu_main',
        options = options,
    })
    lib.showContext('dps_carmenu_' .. cat)
end

RegisterNetEvent('dps-carmenu:client:open', function()
    local byCat = {}
    for model, v in pairs(exports.qbx_core:GetVehiclesByName() or {}) do
        local cat = v.category or 'sports'
        byCat[cat] = byCat[cat] or {}
        byCat[cat][#byCat[cat] + 1] = {
            model = model, name = v.name or model, brand = v.brand or '',
        }
    end

    local options = {}
    for _, cat in ipairs(CATEGORY_ORDER) do
        local list = byCat[cat]
        if list and #list > 0 then
            options[#options + 1] = {
                title = ('%s (%d)'):format(cat:upper(), #list),
                onSelect = function() openCategory(cat, list) end,
            }
        end
    end
    -- anything in a category not in the fixed order still shows up
    for cat, list in pairs(byCat) do
        local known = false
        for _, c in ipairs(CATEGORY_ORDER) do if c == cat then known = true break end end
        if not known and #list > 0 then
            options[#options + 1] = {
                title = ('%s (%d)'):format(cat:upper(), #list),
                onSelect = function() openCategory(cat, list) end,
            }
        end
    end

    lib.registerContext({
        id = 'dps_carmenu_main',
        title = 'Vehicle Browser',
        options = options,
    })
    lib.showContext('dps_carmenu_main')
end)
