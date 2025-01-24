if IsDuplicityVersion() then return end

QBX = {} -- luacheck: ignore
QBX.PlayerData = exports.qbx_core:GetPlayerData() or {}

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    ---@diagnostic disable-next-line: missing-fields
    QBX.PlayerData = {}
end)

RegisterNetEvent('QBCore:Player:SetPlayerData', function(value)
    local invokingResource = GetInvokingResource()
    if invokingResource and invokingResource ~= 'qbx_core' then return end
    QBX.PlayerData = value
end)
