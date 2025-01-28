QBX = {}

---@diagnostic disable-next-line: missing-fields
QBX.PlayerData = {}
QBX.Shared = require 'shared.main'
QBX.IsLoggedIn = false

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

AddStateBagChangeHandler('isLoggedIn', ('player:%s'):format(cache.serverId), function(_, _, value)
    QBX.IsLoggedIn = value
end)

lib.callback.register('qbx_core:client:setHealth', function(health)
    SetEntityHealth(cache.ped, health)
end)

local mapText = require 'config.client'.pauseMapText
if mapText == '' or type(mapText) ~= 'string' then mapText = 'FiveM' end

AddTextEntry('FE_THDR_GTAO', mapText)

CreateThread(function()
    for _, v in pairs(GetVehiclesByName()) do
        if v.model and v.name then
            local gameName = GetDisplayNameFromVehicleModel(v.model)
            if gameName and gameName ~= 'CARNOTFOUND' then
                AddTextEntryByHash(joaat(gameName), v.name)
            else
                lib.print.warn('Could not find gameName value in vehicles.meta for vehicle model %s', v.model)
            end
        end
    end
end)

lib.callback.register('qbx_core:client:getVehicleClasses', function()
    local models = GetAllVehicleModels()
    local classes = {}
    for i = 1, #models do
        local model = models[i]
        local class = GetVehicleClassFromName(model)
        classes[joaat(model)] = class
    end

    return classes
end)