local qbCoreCompat = {}
qbCoreCompat.PlayerData = QBX.PlayerData
qbCoreCompat.Config = lib.table.merge(require 'config.client', require 'config.shared')
qbCoreCompat.Shared = require 'bridge.qb.shared.main'
qbCoreCompat.Functions = require 'bridge.qb.client.functions'

---@deprecated use https://overextended.github.io/docs/ox_lib/Callback/Lua/Client/ instead
qbCoreCompat.ClientCallbacks = {}

---@deprecated use https://overextended.github.io/docs/ox_lib/Callback/Lua/Client/ instead
qbCoreCompat.ServerCallbacks = {}

-- Callback Events --

-- Client Callback
---@deprecated call a function instead
RegisterNetEvent('QBCore:Client:TriggerClientCallback', function(name, ...)
    qbCoreCompat.Functions.TriggerClientCallback(name, function(...)
        TriggerServerEvent('QBCore:Server:TriggerClientCallback', name, ...)
    end, ...)
end)

-- Server Callback
---@deprecated use https://overextended.github.io/docs/ox_lib/Callback/Lua/Client/ instead
RegisterNetEvent('QBCore:Client:TriggerCallback', function(name, ...)
    if qbCoreCompat.ServerCallbacks[name] then
        qbCoreCompat.ServerCallbacks[name](...)
        qbCoreCompat.ServerCallbacks[name] = nil
    end
end)

-- Callback Functions --

-- Client Callback
---@deprecated use https://overextended.github.io/docs/ox_lib/Callback/Lua/Client/ instead
function qbCoreCompat.Functions.CreateClientCallback(name, cb)
    qbCoreCompat.ClientCallbacks[name] = cb
end

---@deprecated call a function instead
function qbCoreCompat.Functions.TriggerClientCallback(name, cb, ...)
    if not qbCoreCompat.ClientCallbacks[name] then return end
    qbCoreCompat.ClientCallbacks[name](cb, ...)
end

-- Server Callback
---@deprecated use https://overextended.github.io/docs/ox_lib/Callback/Lua/Client/ instead
function qbCoreCompat.Functions.TriggerCallback(name, cb, ...)
    qbCoreCompat.ServerCallbacks[name] = cb
    TriggerServerEvent('QBCore:Server:TriggerCallback', name, ...)
end

---@deprecated Use lib.print.debug()
---@param obj any
function qbCoreCompat.Debug(_, obj)
    lib.print.debug(obj)
end

function CreateQbExport(name, cb)
    AddEventHandler(string.format('__cfx_export_qb-core_%s', name), function(setCB)
        setCB(cb)
    end)
end

CreateQbExport('GetCoreObject', function()
    return qbCoreCompat
end)
