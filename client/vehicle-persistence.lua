if GetConvar('qbx:enableVehiclePersistence', 'false') == 'false' then return end

local cachedProps
local netId
local vehicle
local seat

local watchedKeys = {
    'bodyHealth',
    'engineHealth',
    'tankHealth',
    'fuelLevel',
    'oilLevel',
    'dirtLevel',
    'windows',
    'doors',
    'tyres',
}

---Calculates the difference in values of two tables for the watched keys.
---If the second table does not have a value that the first table has, it will be marked 'deleted'.
---@param tbl1 table
---@param tbl2 table
---@return table diff
---@return boolean hasChanged if diff table is not empty
local function calculateDiff(tbl1, tbl2)
    local diff = {}
    local hasChanged = false

    for i = 1, #watchedKeys do
        local key = watchedKeys[i]
        local val1 = tbl1[key]
        local val2 = tbl2[key]

        if val1 ~= val2 then
            diff[key] = val2 == nil and 'deleted' or val2
            hasChanged = true
        end
    end

    return diff, hasChanged
end

local function sendPropsDiff()
    if not Entity(vehicle).state.persisted then return end

    local newProps = lib.getVehicleProperties(vehicle)
    if not cachedProps then
        cachedProps = newProps
        return
    end

    local diff, hasChanged = calculateDiff(cachedProps, newProps)
    cachedProps = newProps
    if not hasChanged then return end

    TriggerServerEvent('qbx_core:server:vehiclePropsChanged', netId, diff)
end

lib.onCache('seat', function(newSeat)
    if newSeat == -1 then
        seat = -1
        vehicle = cache.vehicle
        netId = NetworkGetNetworkIdFromEntity(vehicle)
        CreateThread(function()
            while seat == -1 do
                sendPropsDiff()
                Wait(10000)
            end
        end)
    elseif seat == -1 then
        seat = nil
        sendPropsDiff()
        vehicle = nil
        netId = nil
    end
end)