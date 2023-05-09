QBCore = {}
QBCore.PlayerData = {}
QBCore.Config = QBConfig
QBCore.Shared = QBShared

---@deprecated use https://overextended.github.io/docs/ox_lib/Callback/Lua/Client/ instead
QBCore.ClientCallbacks = {}

---@deprecated use https://overextended.github.io/docs/ox_lib/Callback/Lua/Client/ instead
QBCore.ServerCallbacks = {}

IsLoggedIn = false

exports('GetCoreObject', function()
    return QBCore
end)

-- To use this export in a script instead of manifest method
-- Just put this line of code below at the very top of the script
-- local QBCore = exports['qbx-core']:GetCoreObject()

AddEventHandler('__cfx_export_qb-core_GetCoreObject', function(setCB)
    setCB(function()
        return QBCore
    end)
end)
