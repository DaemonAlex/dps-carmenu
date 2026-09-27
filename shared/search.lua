--[[
    dps-carmenu shared/search.lua
    Pure Lua (no natives) so tests/run.lua can drive it under lua5.4.

    Search.parse(q)            -> query table
    Search.run(list, q, opts)  -> filtered + sorted copy of list
    Card.format(info)          -> plain-text DPS VEHICLE CARD
    Card.handling(rec, fields) -> plain-text handling block in handling.meta order

    A vehicle row looks like:
      { model, name, brand, category, type, price, pack, cls, make, speed }
    speed (km/h) is optional and only present once the client has read the model.
]]

Search = {}
Card = {}

local FILTER_KEYS = { cat = 'category', category = 'category', pack = 'pack', type = 'type', brand = 'brand', class = 'cls', make = 'make' }
local RANGE_KEYS = { price = 'price', speed = 'speed', seats = 'seats' }
local SORT_KEYS = { name = true, price = true, speed = true, category = true, model = true }

local function lower(s) return (tostring(s or '')):lower() end

---Parse a query string into words, filters, ranges and a sort key.
---@param q string|nil
---@return table
function Search.parse(q)
    local out = { words = {}, filters = {}, ranges = {}, sort = nil, desc = false }
    for token in lower(q):gmatch('%S+') do
        local key, val = token:match('^(%a+):(.+)$')
        if key and FILTER_KEYS[key] then
            out.filters[FILTER_KEYS[key]] = val
        elseif key and RANGE_KEYS[key] then
            local op, num = val:match('^([<>]=?)(%d+%.?%d*)$')
            if not op then op, num = '=', val:match('^(%d+%.?%d*)$') end
            if num then out.ranges[RANGE_KEYS[key]] = { op = op, value = tonumber(num) } end
        elseif key == 'sort' then
            local field, dir = val:match('^(%a+)%-?(%a*)$')
            if field and SORT_KEYS[field] then
                out.sort = field
                out.desc = (dir == 'desc')
            end
        else
            out.words[#out.words + 1] = token
        end
    end
    return out
end

local function cmpRange(v, r)
    if v == nil then return false end
    if r.op == '<' then return v < r.value end
    if r.op == '<=' then return v <= r.value end
    if r.op == '>' then return v > r.value end
    if r.op == '>=' then return v >= r.value end
    return v == r.value
end

---Does one row satisfy a parsed query?
---@param v table
---@param p table parsed query
---@return boolean
function Search.match(v, p)
    for field, want in pairs(p.filters) do
        if not lower(v[field]):find(want, 1, true) then return false end
    end
    for field, r in pairs(p.ranges) do
        if not cmpRange(tonumber(v[field]), r) then return false end
    end
    if #p.words > 0 then
        local hay = table.concat({ lower(v.name), lower(v.brand), lower(v.model), lower(v.category), lower(v.pack), lower(v.make) }, ' ')
        for _, w in ipairs(p.words) do
            if not hay:find(w, 1, true) then return false end
        end
    end
    return true
end

local function displayName(v)
    if v.brand and v.brand ~= '' then return v.brand .. ' ' .. (v.name or v.model) end
    return v.name or v.model or ''
end

local function sorter(field, desc)
    return function(a, b)
        local x, y
        if field == 'price' or field == 'speed' then
            x, y = tonumber(a[field]) or -1, tonumber(b[field]) or -1
        elseif field == 'model' then
            x, y = lower(a.model), lower(b.model)
        elseif field == 'category' then
            x, y = lower(a.category) .. lower(displayName(a)), lower(b.category) .. lower(displayName(b))
        else
            x, y = lower(displayName(a)), lower(displayName(b))
        end
        if x == y then return lower(a.model) < lower(b.model) end
        if desc then return x > y end
        return x < y
    end
end

---Filter and sort a list of rows. Never mutates the input.
---@param list table[]
---@param q string|nil
---@param opts table|nil { category = string, only = table<string,boolean>, sort = string, desc = boolean }
---@return table[]
function Search.run(list, q, opts)
    opts = opts or {}
    local p = Search.parse(q)
    local out = {}
    for _, v in ipairs(list or {}) do
        local ok = Search.match(v, p)
        if ok and opts.category and opts.category ~= 'all' and lower(v.category) ~= lower(opts.category) then ok = false end
        if ok and opts.only and not opts.only[v.model] then ok = false end
        if ok then out[#out + 1] = v end
    end
    local field = p.sort or opts.sort or 'name'
    local desc = p.sort and p.desc or (opts.desc == true)
    table.sort(out, sorter(field, desc))
    return out
end

---Count rows per category (for the rail).
---@param list table[]
---@return table<string, integer>
function Search.counts(list)
    local counts = {}
    for _, v in ipairs(list or {}) do
        local c = v.category or 'other'
        counts[c] = (counts[c] or 0) + 1
    end
    return counts
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Cards

local function money(n)
    n = tonumber(n)
    if not n then return '-' end
    local s = tostring(math.floor(n))
    local formatted = s:reverse():gsub('(%d%d%d)', '%1,'):reverse():gsub('^,', '')
    return '$' .. formatted
end

local function num(v, digits)
    if v == nil then return '-' end
    if digits then return string.format('%.' .. digits .. 'f', v) end
    return tostring(v)
end

---Plain-text card for pasting into an LLM.
---@param info table
---@return string
function Card.format(info)
    info = info or {}
    local lines = {}
    lines[#lines + 1] = 'DPS VEHICLE CARD'
    lines[#lines + 1] = ('model: %s   name: %s   category: %s   type: %s'):format(info.model or '-', displayName(info), info.category or '-', info.type or '-')
    lines[#lines + 1] = ('price: %s   pack: %s   game class: %s   maker: %s'):format(money(info.price), info.pack or '-', info.cls or '-', info.make or '-')
    if info.speed or info.accel or info.seats then
        local dims = info.dims and ('%.1f x %.1f x %.1f m'):format(info.dims.l or 0, info.dims.w or 0, info.dims.h or 0) or '-'
        lines[#lines + 1] = ('model: top speed %s km/h · accel %s · braking %s · traction %s · seats %s · %s'):format(
            num(info.speed), num(info.accel, 2), num(info.brake, 2), num(info.traction, 2), num(info.seats), dims)
    end
    local h = info.handling
    if h then
        local bias = tonumber(h.fDriveBiasFront)
        local biasWord = bias and (bias >= 0.99 and 'front' or bias <= 0.01 and 'rear' or 'awd') or '-'
        lines[#lines + 1] = ('handling: mass %s · drive force %s · drive bias %s (%s) · gears %s · flat vel %s'):format(
            num(h.fMass), num(h.fInitialDriveForce, 2), num(bias, 2), biasWord, num(h.nInitialDriveGears), num(h.fInitialDriveMaxFlatVel))
        lines[#lines + 1] = ('          brake force %s bias %s · traction max %s min %s lat %s · susp force %s · fuel %s'):format(
            num(h.fBrakeForce, 2), num(h.fBrakeBiasFront, 2), num(h.fTractionCurveMax, 2), num(h.fTractionCurveMin, 2),
            num(h.fTractionCurveLateral, 1), num(h.fSuspensionForce, 2), num(h.fPetrolTankVolume))
    else
        lines[#lines + 1] = 'handling: (spawn it or sit in it, then Copy card again for the handling line)'
    end
    lines[#lines + 1] = 'notes: DPS class envelope ±5% per category; race cars never on stock sound or tune; LVC only'
    return table.concat(lines, '\n')
end

---handling.meta-ordered block of every field we read.
---@param rec table field -> value (vectors as {x,y,z})
---@param fields table { floats = {...}, ints = {...}, vectors = {...} }
---@param model string|nil
---@return string
function Card.handling(rec, fields, model)
    local lines = { ('handling for %s (live values)'):format(model or '?') }
    for _, f in ipairs(fields.floats or {}) do
        lines[#lines + 1] = ('  <%s value="%s" />'):format(f, num(rec[f], 6))
    end
    for _, f in ipairs(fields.ints or {}) do
        lines[#lines + 1] = ('  <%s value="%s" />'):format(f, num(rec[f]))
    end
    for _, f in ipairs(fields.vectors or {}) do
        local v = rec[f]
        if v then
            lines[#lines + 1] = ('  <%s x="%.6f" y="%.6f" z="%.6f" />'):format(f, v.x or 0, v.y or 0, v.z or 0)
        end
    end
    return table.concat(lines, '\n')
end

return { Search = Search, Card = Card }
