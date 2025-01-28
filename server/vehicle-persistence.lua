---A persisted vehicle will respawn when deleted. Only works for player owned vehicles.
---Vehicles spawned using lib are automatically persisted
---@param vehicle number
local function enablePersistence(vehicle)
    Entity(vehicle).state:set('persisted', true, true)
end

exports('EnablePersistence', enablePersistence)

---A vehicle without persistence will not respawn when deleted.
---@param vehicle number
function DisablePersistence(vehicle)
    Entity(vehicle).state:set('persisted', nil, true)
end

exports('DisablePersistence', DisablePersistence)

if GetConvar('qbx:enableVehiclePersistence', 'false') == 'false' then return end

assert(lib.checkDependency('qbx_vehicles', '1.4.1', true))

local function getVehicleId(vehicle)
    return Entity(vehicle).state.vehicleid or exports.qbx_vehicles:GetVehicleIdByPlate(GetVehicleNumberPlateText(vehicle))
end

RegisterNetEvent('qbx_core:server:vehiclePropsChanged', function(netId, diff)
    local vehicle = NetworkGetEntityFromNetworkId(netId)

    local vehicleId = getVehicleId(vehicle)
    if not vehicleId then return end

    local props = exports.qbx_vehicles:GetPlayerVehicle(vehicleId)?.props
    if not props then return end

    if diff.bodyHealth then
        props.bodyHealth = GetVehicleBodyHealth(vehicle)
    end

    if diff.engineHealth then
        props.engineHealth = GetVehicleEngineHealth(vehicle)
    end

    if diff.tankHealth then
        props.tankHealth = GetVehiclePetrolTankHealth(vehicle)
    end

    if diff.fuelLevel then
        props.fuelLevel = diff.fuelLevel ~= 'deleted' and diff.fuelLevel or nil
    end

    if diff.oilLevel then
        props.oilLevel = diff.oilLevel ~= 'deleted' and diff.oilLevel or nil
    end

    if diff.dirtLevel then
        props.dirtLevel = GetVehicleDirtLevel(vehicle)
    end

    if diff.windows then
        props.windows = diff.windows ~= 'deleted' and diff.windows or nil
    end

    if diff.doors then
        props.doors = diff.doors ~= 'deleted' and diff.doors or nil
    end

    if diff.tyres then
        props.tyres = diff.tyres ~= 'deleted' and diff.tyres or nil
    end

    exports.qbx_vehicles:SaveVehicle(vehicle, {
        props = props,
    })
end)

local function getPedsInVehicleSeats(vehicle)
    local occupants = {}
    local occupantsI = 1
    for i = -1, 7 do
        local ped = GetPedInVehicleSeat(vehicle, i)
        if ped ~= 0 then
            occupants[occupantsI] = {
                ped = ped,
                seat = i,
            }

            occupantsI += 1
        end
    end

    return occupants
end

AddEventHandler('entityRemoved', function(entity)
    if not Entity(entity).state.persisted then return end

    local sessionId = Entity(entity).state.sessionId
    local coords = GetEntityCoords(entity)
    local heading = GetEntityHeading(entity)
    local bucket = GetEntityRoutingBucket(entity)
    local passengers = getPedsInVehicleSeats(entity)

    local vehicleId = getVehicleId(entity)
    if not vehicleId then return end

    local playerVehicle = exports.qbx_vehicles:GetPlayerVehicle(vehicleId)

    if DoesEntityExist(entity) then
        Entity(entity).state:set('persisted', nil, true)
        DeleteVehicle(entity)
    end

    local _, veh = qbx.spawnVehicle({
        model = playerVehicle.props.model,
        spawnSource = vec4(coords.x, coords.y, coords.z, heading),
        bucket = bucket,
        props = playerVehicle.props
    })

    Entity(veh).state:set('sessionId', sessionId, true)
    Entity(veh).state:set('vehicleid', vehicleId, false)

    for i = 1, #passengers do
        local passenger = passengers[i]
        SetPedIntoVehicle(passenger.ped, veh, passenger.seat)
    end
end)