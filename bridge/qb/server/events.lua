-- Vehicles
RegisterServerEvent('baseevents:enteringVehicle', function(veh, seat, modelName, netId)
    local src = source
    local data = {
        vehicle = veh,
        seat = seat,
        name = modelName,
        netId = netId,
        event = 'Entering'
    }

    TriggerClientEvent('QBCore:Client:VehicleInfo', src, data)
end)

RegisterServerEvent('baseevents:enteredVehicle', function(veh, seat, modelName, netId)
    local src = source
    local data = {
        vehicle = veh,
        seat = seat,
        name = modelName,
        netId = netId,
        event = 'Entered'
    }

    TriggerClientEvent('QBCore:Client:VehicleInfo', src, data)
end)

RegisterServerEvent('baseevents:enteringAborted', function()
    local src = source
    TriggerClientEvent('QBCore:Client:AbortVehicleEntering', src)
end)

RegisterServerEvent('baseevents:leftVehicle', function(veh, seat, modelName, netId)
    local src = source
    local data = {
        vehicle = veh,
        seat = seat,
        name = modelName,
        netId = netId,
        event = 'Left'
    }

    TriggerClientEvent('QBCore:Client:VehicleInfo', src, data)
end)