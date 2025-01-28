local persistence = GetConvar('qbx:enableVehiclePersistence', 'false')

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

if persistence == 'false' then return end

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
        props = props
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

if persistence == 'full' then return end

local cachedVehicles = {}
local config = require 'config.server'

---@param plate string
---@return boolean
local function isVehicleSpawned(plate)
    local vehicles = GetGamePool('CVehicle')

    for i = 1, #vehicles do
        local vehicle = vehicles[i]
        if qbx.getVehiclePlate(vehicle) == plate then
            return true
        end
    end

    return false
end

--- Save the vehicle position to the database
---@param vehicle number
---@param coords vector3
---@param heading number
local function saveVehiclePosition(vehicle, coords, heading)
    local type = GetVehicleType(vehicle)
    if type == 'heli' or type == 'plane' then
        coords = vec3(coords.x, coords.y, coords.z + 1.0)
    end

    exports.qbx_vehicles:SaveVehicle(vehicle, {
        coords = vec4(coords.x, coords.y, coords.z, heading)
    })
end

--- Save all vehicle positions to the database
local function saveAllVehiclePosition()
    local vehicles = GetGamePool('CVehicle')
    for i = 1, #vehicles do
        local vehicle = vehicles[i]
        if DoesEntityExist(vehicle) and Entity(vehicle).state.persisted then
            saveVehiclePosition(vehicle, GetEntityCoords(vehicle), GetEntityHeading(vehicle))
        end
    end
end

---@param coords vector4
---@param id number
---@param model string
---@param props table
local function spawnVehicle(coords, id, model, props)
    if not coords or not id or not model or not props then return end

    local _, veh = qbx.spawnVehicle({
        spawnSource = vec4(coords.x, coords.y, coords.z, coords.w),
        model = model,
        props = props
    })

    cachedVehicles[id] = nil
    Entity(veh).state:set('vehicleid', id, false)
    TriggerClientEvent('qbx_core:client:removeVehZone', -1, id)
    config.setVehicleLock(veh, config.persistence.lockState)
end

lib.callback.register('qbx_core:server:getVehiclesToSpawn', function()
    return cachedVehicles
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= 'qbx_vehicles' then return end

    local vehicles = exports.qbx_vehicles:GetPlayerVehicles({ states = 0 })
    if not vehicles then return end

    for i = 1, #vehicles do
        local vehicle = vehicles[i]
        if vehicle.coords and vehicle.props and vehicle.props.plate and not isVehicleSpawned(vehicle.props.plate) then
            cachedVehicles[vehicle.id] = vehicle.coords
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= cache.resource then return end

    saveAllVehiclePosition()
end)

AddEventHandler('txAdmin:events:scheduledRestart', function(eventData)
    if eventData.secondsRemaining ~= 60 then return end

    saveAllVehiclePosition()
end)

RegisterNetEvent('qbx_core:server:spawnVehicle', function(id, coords)
    if not id or not coords then return end

    local cachedCoords = cachedVehicles[id]
    if not cachedCoords or
        cachedCoords.x ~= coords.x or
        cachedCoords.y ~= coords.y or
        cachedCoords.z ~= coords.z or
        cachedCoords.w ~= coords.w then
        return
    end

    local vehicle = exports.qbx_vehicles:GetPlayerVehicle(id)
    if not vehicle or not vehicle.modelName or not vehicle.props then return end

    spawnVehicle(coords, id, vehicle.modelName, vehicle.props)
end)

RegisterNetEvent('qbx_core:server:vehiclePositionChanged', function(netId)
    local src = source

    local ped = GetPlayerPed(src)
    local vehicle = NetworkGetEntityFromNetworkId(netId)

    local vehicleId = getVehicleId(vehicle)
    if not vehicleId then return end

    local pedCoords = GetEntityCoords(ped)
    local vehicleCoords = GetEntityCoords(vehicle)
    local vehicleHeading = GetEntityHeading(vehicle)

    if #(pedCoords - vehicleCoords) > 10.0 then
        return
    end

    saveVehiclePosition(vehicle, vehicleCoords, vehicleHeading)
end)
