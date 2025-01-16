lib.versionCheck('Qbox-project/qbx_core')
local startupErrors, errorMessage
if not lib.checkDependency('ox_lib', '3.20.0', true) then
    startupErrors, errorMessage = true, 'ox_lib version 3.20.0 or higher is required'
elseif not lib.checkDependency('ox_inventory', '2.42.1', true) then
    startupErrors, errorMessage = true, 'ox_inventory version 2.42.1 or higher is required'
elseif GetConvar('inventory:framework', '') ~= 'qbx' then
    startupErrors, errorMessage = true, 'inventory:framework must be set to "qbx" in order to use qbx_core'
elseif GetConvarInt('onesync_enableInfinity', 0) ~= 1 then
    startupErrors, errorMessage = true, 'OneSync Infinity is not enabled. You can do so in txAdmin settings or add +set onesync on to your server startup command line'
end

if startupErrors then
    lib.print.error('Startup errors detected, shutting down server...')
    ExecuteCommand('quit immediately')

    for _ = 1, 100 do
        lib.print.error(errorMessage)
    end

    error(errorMessage)
end

---@type 'strict' | 'relaxed' | 'inactive'
local bucketLockDownMode = GetConvar('qbx:bucketlockdownmode', 'inactive')
SetRoutingBucketEntityLockdownMode(0, bucketLockDownMode)

QBX = {}
QBX.Shared = require 'shared.main'

---@type table<Source, Player>
QBX.Players = {}
GlobalState.PlayerCount = 0
GlobalState.MaxPlayers = GetConvarInt('sv_maxclients', 48)

QBX.Player_Buckets = {}
QBX.Entity_Buckets = {}
QBX.UsableItems = {}

---@alias Model number
---@alias VehicleClass integer see https://docs.fivem.net/natives/?_0x29439776AAA00A62
---@type table<Model, VehicleClass>
local vehicleClasses
local vehicleClassesPromise

local currentSessionId = 0

---Sets a unique sessionId statebag on the entity.
---If the entity already has a sessionId, this will return it rather than overwrite.
---@param entity number
---@return integer sessionId
local function createSessionId(entity)
    local existingSessionId = Entity(entity).state.sessionId
    if existingSessionId then
        return existingSessionId
    end

    currentSessionId += 1
    local sessionId = currentSessionId
    Entity(entity).state:set('sessionId', sessionId, true)
    return sessionId
end

exports('CreateSessionId', createSessionId)

---Caches the vehicle classes the first time this is called by getting the data from a random client.
---Throws an error if there is no cache and no client is connected to get the data from.
---@param model number
---@return VehicleClass
function GetVehicleClass(model)
    if not vehicleClasses then
        if vehicleClassesPromise then
            Citizen.Await(vehicleClassesPromise)
        else
            -- lib.callback.await is async, so let additional callers wait along instead of awaiting new callbacks
            vehicleClassesPromise = promise:new()

            -- keep asking different players until we get an answer or until there are no players
            repeat
                local players = GetPlayers()
                if #players == 0 then break end

                local playerId = players[math.random(#players)]
                -- this *may* fail, but we still need to resolve our promise
                pcall(function()
                    vehicleClasses = lib.callback.await('qbx_core:client:getVehicleClasses', playerId)
                end)
            until vehicleClasses

            if not vehicleClasses then
                local message = 'no clients online'
                vehicleClassesPromise:reject(message)
                vehicleClassesPromise = nil
                error(message)
            end

            vehicleClassesPromise:resolve()
        end
    end

    return vehicleClasses[model]
end

exports('GetVehicleClass', GetVehicleClass)

---@return table<string, Vehicle>
---@overload fun(key: string): Vehicle
function GetVehiclesByName(key)
    local vehicles = QBX.Shared.Vehicles
    return vehicles[key] or vehicles
end

exports('GetVehiclesByName', GetVehiclesByName)

---@return table<number, Vehicle>
---@overload fun(key: number): Vehicle
function GetVehiclesByHash(key)
    local vehicles = QBX.Shared.VehicleHashes
    return vehicles[key] or vehicles
end

exports('GetVehiclesByHash', GetVehiclesByHash)

---@return table<string, Vehicle[]>
function GetVehiclesByCategory()
    return qbx.table.mapBySubfield(QBX.Shared.Vehicles, 'category')
end

exports('GetVehiclesByCategory', GetVehiclesByCategory)

---@return table<number, Weapon>
---@overload fun(key: number): Weapon
function GetWeapons(key)
    local weapons = QBX.Shared.Weapons
    return weapons[key] or weapons
end

exports('GetWeapons', GetWeapons)

---@deprecated
---@return table<string, vector4>
function GetLocations()
    return QBX.Shared.Locations
end

---@diagnostic disable-next-line: deprecated
exports('GetLocations', GetLocations)