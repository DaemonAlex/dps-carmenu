--[[
    dps-carmenu client
    The fleet panel: F7 or /carmenu opens an NUI browser over the live qbx_core
    registry. Search, sort and card text are built here in Lua (shared/search.lua)
    so the panel is a view and the logic stays testable.
]]

local open = false
local ALL = {}            -- rows: model, name, brand, category, type, price, pack, cls, make, speed, ...
local BY_MODEL = {}
local INFO = {}           -- model -> model-native info (speed, accel, seats, dims ...) read once per session
local HANDLING = {}       -- model -> last handling record read from a live vehicle
local lastSpawned = nil   -- { netId, model }
local serverData = nil    -- packs/classes from the server, fetched once per session

local KVP_RECENT, KVP_FAV = 'dps_carmenu_recent', 'dps_carmenu_fav'
local RECENT_MAX = 15

local function loadList(key)
    local raw = GetResourceKvpString(key)
    if not raw then return {} end
    local ok, t = pcall(json.decode, raw)
    return ok and type(t) == 'table' and t or {}
end
local function saveList(key, t) SetResourceKvp(key, json.encode(t)) end

local function pushRecent(model)
    local list = loadList(KVP_RECENT)
    for i = #list, 1, -1 do if list[i] == model then table.remove(list, i) end end
    table.insert(list, 1, model)
    while #list > RECENT_MAX do table.remove(list) end
    saveList(KVP_RECENT, list)
    return list
end

local function favSet()
    local set = {}
    for _, m in ipairs(loadList(KVP_FAV)) do set[m] = true end
    return set
end

local function classLabel(hash)
    local names = { [0] = 'Compacts', 'Sedans', 'SUVs', 'Coupes', 'Muscle', 'Sports Classics', 'Sports', 'Super', 'Motorcycles', 'Off-road',
        'Industrial', 'Utility', 'Vans', 'Cycles', 'Boats', 'Helicopters', 'Planes', 'Service', 'Emergency', 'Military', 'Commercial', 'Trains', 'Open Wheel' }
    return names[GetVehicleClassFromName(hash)] or '-'
end

---Model-level facts. Needs the model streamed, so it takes a moment the first time.
local function readModelInfo(model)
    if INFO[model] then return INFO[model] end
    local hash = joaat(model)
    if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then
        INFO[model] = { missing = true }
        return INFO[model]
    end
    local loaded = pcall(lib.requestModel, hash, 4000)
    local min, max = GetModelDimensions(hash)
    local info = {
        speed = math.floor(GetVehicleModelMaxSpeed(hash) * 3.6 + 0.5),
        accel = GetVehicleModelAcceleration(hash),
        brake = GetVehicleModelMaxBraking(hash),
        traction = GetVehicleModelMaxTraction(hash),
        seats = GetVehicleModelNumberOfSeats(hash),
        cls = classLabel(hash),
        make = GetMakeNameFromVehicleModel(hash),
        display = GetDisplayNameFromVehicleModel(hash),
        dims = { l = max.y - min.y, w = max.x - min.x, h = max.z - min.z },
        loaded = loaded,
    }
    if loaded then SetModelAsNoLongerNeeded(hash) end
    INFO[model] = info
    local row = BY_MODEL[model]
    if row then row.speed = info.speed; row.seats = info.seats; if info.cls ~= '-' then row.cls = info.cls end end
    return info
end

---A live vehicle of this model: the one we sit in, else the last one we spawned.
local function liveVehicle(model)
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 and GetEntityModel(veh) == joaat(model) then return veh end
    if lastSpawned and lastSpawned.model == model and NetworkDoesNetworkIdExist(lastSpawned.netId) then
        local e = NetworkGetEntityFromNetworkId(lastSpawned.netId)
        if e ~= 0 and DoesEntityExist(e) then return e end
    end
    return nil
end

local function readHandling(model)
    local veh = liveVehicle(model)
    if not veh then return nil end
    local rec = {}
    for _, f in ipairs(HandlingFields.floats) do rec[f] = GetVehicleHandlingFloat(veh, 'CHandlingData', f) end
    for _, f in ipairs(HandlingFields.ints) do rec[f] = GetVehicleHandlingInt(veh, 'CHandlingData', f) end
    for _, f in ipairs(HandlingFields.vectors) do
        local v = GetVehicleHandlingVector(veh, 'CHandlingData', f)
        rec[f] = { x = v.x, y = v.y, z = v.z }
    end
    HANDLING[model] = rec
    return rec
end

local function cardInfo(model)
    local row = BY_MODEL[model]
    if not row then return nil end
    local info = readModelInfo(model)
    local out = {}
    for k, v in pairs(row) do out[k] = v end
    for k, v in pairs(info) do out[k] = v end
    out.handling = readHandling(model) or HANDLING[model]
    return out
end

local function buildRows(data)
    ALL, BY_MODEL = {}, {}
    local packs, classes = data.packs or {}, data.classes or {}
    for model, v in pairs(exports.qbx_core:GetVehiclesByName() or {}) do
        local row = {
            model = model, name = v.name or model, brand = v.brand or '', category = v.category or 'other',
            type = v.type or '-', price = tonumber(v.price) or 0, pack = packs[model] or 'vanilla', cls = classes[model] or '-', make = '',
        }
        ALL[#ALL + 1] = row
        BY_MODEL[model] = row
    end
end

local function closePanel()
    if not open then return end
    open = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

local function openPanel()
    if open then return end
    -- The pack table is static for a server run: fetch it once per session, then only re-check access.
    local ok, data = lib.callback.await('dps-carmenu:server:open', false, serverData ~= nil)
    if not ok then
        lib.notify({ title = 'DPS Fleet', description = 'You do not have access to the fleet browser.', type = 'error' })
        return
    end
    if data then serverData = data end
    buildRows(serverData or {})
    open = true
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'open',
        vehicles = ALL,
        counts = Search.counts(ALL),
        recent = loadList(KVP_RECENT),
        favorites = loadList(KVP_FAV),
    })
end

RegisterCommand('carmenu', function() if open then closePanel() else openPanel() end end, false)
RegisterKeyMapping('carmenu', 'DPS Fleet: open the vehicle browser', 'keyboard', 'F7')
TriggerEvent('chat:addSuggestion', '/carmenu', 'Open the DPS fleet browser (admins and testers)')

-- ── NUI callbacks ──────────────────────────────────────────────────────────────

RegisterNUICallback('close', function(_, cb) closePanel(); cb(1) end)

RegisterNUICallback('search', function(req, cb)
    local only
    if req.view == 'recent' then
        only = {}; for _, m in ipairs(loadList(KVP_RECENT)) do only[m] = true end
    elseif req.view == 'fav' then
        only = favSet()
    end
    local rows = Search.run(ALL, req.q, { category = req.category, only = only, sort = req.sort, desc = req.desc })
    local models = {}
    for i, v in ipairs(rows) do models[i] = v.model end
    -- recent keeps its own order
    if req.view == 'recent' and (not req.q or req.q == '') then
        models = {}
        for _, m in ipairs(loadList(KVP_RECENT)) do if BY_MODEL[m] then models[#models + 1] = m end end
    end
    cb({ models = models, total = #ALL })
end)

RegisterNUICallback('info', function(req, cb)
    local model = req.model
    if not BY_MODEL[model] then cb({}) return end
    local info = readModelInfo(model)
    local h = readHandling(model) or HANDLING[model]
    cb({ info = info, handling = h, row = BY_MODEL[model], favorite = favSet()[model] == true })
end)

RegisterNUICallback('spawn', function(req, cb)
    local model, mode = req.model, req.mode or 'replace'
    if not BY_MODEL[model] then cb({ ok = false, reason = 'unknown model' }) return end
    local ped = PlayerPedId()
    local beside
    if mode == 'beside' then
        local base = GetVehiclePedIsIn(ped, false)
        local len = 5.0
        if base ~= 0 then
            local min, max = GetModelDimensions(GetEntityModel(base))
            len = (max.x - min.x) + 3.0
        end
        local p = GetOffsetFromEntityInWorldCoords(base ~= 0 and base or ped, len, 0.0, 0.0)
        beside = { x = p.x, y = p.y, z = p.z, w = GetEntityHeading(base ~= 0 and base or ped) }
    end
    local ok, plate, netId = lib.callback.await('dps-carmenu:server:spawn', false, model, mode, beside)
    if not ok then
        cb({ ok = false, reason = plate or 'spawn failed' })
        return
    end
    lastSpawned = { netId = netId, model = model }
    if plate and GetResourceState('wasabi_carlock') == 'started' then
        pcall(function() exports.wasabi_carlock:GiveKey(plate) end)
    end
    local recent = pushRecent(model)
    -- handling is readable now that the vehicle exists
    CreateThread(function() Wait(250); readHandling(model) end)
    cb({ ok = true, plate = plate, recent = recent })
end)

RegisterNUICallback('favorite', function(req, cb)
    local list = loadList(KVP_FAV)
    local found
    for i, m in ipairs(list) do if m == req.model then found = i end end
    if found then table.remove(list, found) elseif BY_MODEL[req.model] then table.insert(list, 1, req.model) end
    saveList(KVP_FAV, list)
    cb({ favorites = list })
end)

RegisterNUICallback('card', function(req, cb)
    local info = cardInfo(req.model)
    cb({ text = info and Card.format(info) or '' })
end)

RegisterNUICallback('handlingText', function(req, cb)
    local rec = readHandling(req.model) or HANDLING[req.model]
    if not rec then cb({ text = '', reason = 'Spawn it or sit in it first.' }) return end
    cb({ text = Card.handling(rec, HandlingFields, req.model) })
end)

RegisterNUICallback('delete', function(_, cb)
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 and lastSpawned and NetworkDoesNetworkIdExist(lastSpawned.netId) then
        veh = NetworkGetEntityFromNetworkId(lastSpawned.netId)
    end
    if veh == 0 or not DoesEntityExist(veh) then cb({ ok = false, reason = 'Nothing to remove.' }) return end
    local ok = lib.callback.await('dps-carmenu:server:delete', false, NetworkGetNetworkIdFromEntity(veh))
    cb({ ok = ok })
end)

-- Workshop: hand the selected vehicle (the one we sit in, else the last spawned) to dps-EVM.
RegisterNUICallback('workshop', function(req, cb)
    local veh = liveVehicle(req.model or '')
    if not veh then cb({ ok = false, reason = 'Spawn it or sit in it first.' }) return end
    if GetResourceState('dps-EVM') ~= 'started' then cb({ ok = false, reason = 'Workshop (dps-EVM) is not running.' }) return end
    closePanel()
    TriggerEvent('vehiclemods:client:openVehicleModMenu', veh)
    cb({ ok = true })
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then SetNuiFocus(false, false) end
end)
