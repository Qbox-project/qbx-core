-- Player load and unload handling
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    ShutdownLoadingScreenNui()
    QBX.IsLoggedIn = true

    if GlobalState.PVPEnabled then
        SetCanAttackFriendly(cache.ped, true, false)
        NetworkSetFriendlyFireOption(true)
    end

    NetworkEndTutorialSession()

    while NetworkIsInTutorialSession() do
        Wait(0)
    end

    local motd = GetConvar('qbx:motd', '')
    if motd ~= '' then
        exports.chat:addMessage({ template = motd })
    end
end)

---@param val PlayerData
RegisterNetEvent('QBCore:Player:SetPlayerData', function(val)
    local invokingResource = GetInvokingResource()
    if invokingResource and invokingResource ~= cache.resource then return end

    QBX.PlayerData = val
end)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    QBX.IsLoggedIn = false
end)

---@param value boolean
---@diagnostic disable-next-line: param-type-mismatch
AddStateBagChangeHandler('PVPEnabled', nil, function(bagName, _, value)
    if bagName ~= 'global' then return end

    SetCanAttackFriendly(cache.ped, value, false)
    NetworkSetFriendlyFireOption(value)
end)

-- Teleport Commands

---@param coords vector3
RegisterNetEvent('QBCore:Command:TeleportToPlayer', function(coords)
    SetPedCoordsKeepVehicle(cache.ped, coords.x, coords.y, coords.z)
end)

---@param x number
---@param y number
---@param z number
---@param h number
RegisterNetEvent('QBCore:Command:TeleportToCoords', function(x, y, z, h)
    SetPedCoordsKeepVehicle(cache.ped, x, y, z)
    SetEntityHeading(cache.ped, h or GetEntityHeading(cache.ped))
end)

RegisterNetEvent('QBCore:Command:GoToMarker', function()
    local blipMarker <const> = GetFirstBlipInfoId(8)
    if not DoesBlipExist(blipMarker) then
        Notify(locale('error.no_waypoint'), 'error')
        return
    end

    -- Fade screen to hide how clients get teleported.
    DoScreenFadeOut(650)
    while not IsScreenFadedOut() do
        Wait(0)
    end

    local ped, coords <const> = cache.ped, GetBlipInfoIdCoord(blipMarker)
    local vehicle = GetVehiclePedIsIn(ped, false)
    local oldCoords <const> = GetEntityCoords(ped)

    -- Unpack coords instead of having to unpack them while iterating.
    -- 825.0 seems to be the max a player can reach while 0.0 being the lowest.
    local x, y, groundZ, Z_START = coords.x, coords.y, 850.0, 950.0
    local found = false
    if vehicle > 0 then
        FreezeEntityPosition(vehicle, true)
    else
        FreezeEntityPosition(ped, true)
    end

    for i = Z_START, 0, -25.0 do
        local z = i
        if (i % 2) ~= 0 then
            z = Z_START - i
        end

        NewLoadSceneStart(x, y, z, x, y, z, 50.0, 0)
        local curTime = GetGameTimer()
        while IsNetworkLoadingScene() do
            if GetGameTimer() - curTime > 1000 then
                break
            end

            Wait(0)
        end

        NewLoadSceneStop()
        SetPedCoordsKeepVehicle(ped, x, y, z)

        while not HasCollisionLoadedAroundEntity(ped) do
            RequestCollisionAtCoord(x, y, z)
            if GetGameTimer() - curTime > 1000 then
                break
            end
            Wait(0)
        end

        -- Get ground coord. As mentioned in the natives, this only works if the client is in render distance.
        found, groundZ = GetGroundZFor_3dCoord(x, y, z, false);
        if found then
            Wait(0)
            SetPedCoordsKeepVehicle(ped, x, y, groundZ)
            break
        end

        Wait(0)
    end

    -- Remove black screen once the loop has ended.
    DoScreenFadeIn(650)
    if vehicle > 0 then
        FreezeEntityPosition(vehicle, false)
    else
        FreezeEntityPosition(ped, false)
    end

    if not found then
        -- If we can't find the coords, set the coords to the old ones.
        -- We don't unpack them before since they aren't in a loop and only called once.
        SetPedCoordsKeepVehicle(ped, oldCoords.x, oldCoords.y, oldCoords.z - 1.0)
        Notify(locale('error.tp_error'), 'error')
    end

    -- If Z coord was found, set coords in found coords.
    SetPedCoordsKeepVehicle(ped, x, y, groundZ)
    Notify(locale('success.teleported_waypoint'), 'success')
end)

-- Vehicle Commands

lib.callback.register('qbx_core:client:getVehiclesInRadius', function(radius)
    local vehicles = lib.getNearbyVehicles(GetEntityCoords(cache.ped), radius or 5, true)

    for i = 1, #vehicles do
        vehicles[i] = VehToNet(vehicles[i].vehicle)
    end

    return vehicles
end)

-- Other stuff

---@see client/functions.lua:QBCore.Functions.Notify
RegisterNetEvent('QBCore:Notify', function(text, notifyType, duration, subTitle, notifyPosition, notifyStyle, notifyIcon, notifyIconColor)
    Notify(text, notifyType, duration, subTitle, notifyPosition, notifyStyle, notifyIcon, notifyIconColor)
end)

-- Me command

---@param bagName string
---@param value string
---@diagnostic disable-next-line: param-type-mismatch
AddStateBagChangeHandler('me', nil, function(bagName, _, value)
    if not value then return end

    local playerId = GetPlayerFromStateBagName(bagName)

    if not playerId or not NetworkIsPlayerActive(playerId) then return end

    local isLocalPlayer = playerId == cache.playerId
    local playerPed = isLocalPlayer and cache.ped or GetPlayerPed(playerId)

    -- Here we do a entity check to see if the player exsist within each clients scope --
    if not DoesEntityExist(playerPed) then return end

    -- Distance check to make sure that players do not see others me from 100s of meters away --
    if not isLocalPlayer and #(GetEntityCoords(playerPed) - GetEntityCoords(cache.ped)) > 25 then return end

    CreateThread(function()
        local displayTime = 5000 + GetGameTimer()
        while displayTime > GetGameTimer() do
            playerPed = isLocalPlayer and cache.ped or GetPlayerPed(playerId)
            qbx.drawText3d({text = value, coords = GetEntityCoords(playerPed)})
            Wait(0)
        end
    end)
end)

-- Listen to Shared being updated
---@param tableName string
---@param key any
---@param value any
RegisterNetEvent('QBCore:Client:OnSharedUpdate', function(tableName, key, value)
    QBX.Shared[tableName][key] = value
    TriggerEvent('QBCore:Client:UpdateObject')
end)

---@param tableName string
---@param values table<any, any>
RegisterNetEvent('QBCore:Client:OnSharedUpdateMultiple', function(tableName, values)
    for key, value in pairs(values) do
        QBX.Shared[tableName][key] = value
    end

    TriggerEvent('QBCore:Client:UpdateObject')
end)

-- Set vehicle props
---@param netId number
---@param props table<any, any>
RegisterNetEvent('qbx_core:client:setVehicleProperties', function(netId, props)
    if not props then return end

    local timeOut = GetGameTimer() + 1000
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    while true do
        if NetworkGetEntityOwner(vehicle) == cache.playerId then
            if lib.setVehicleProperties(vehicle, props) then
                return
            end
        end

        if GetGameTimer() > timeOut then
            return
        end

        Wait(50)
    end
end)

-- Clear vehicle peds
---@param vehicle number
---@param init boolean
qbx.entityStateHandler('initVehicle', function(vehicle, _, init)
    if not init then return end

    for i = -1, 0 do
        local ped = GetPedInVehicleSeat(vehicle, i)
        if ped ~= cache.ped and ped > 0 and NetworkGetEntityOwner(ped) == cache.playerId then
            DeleteEntity(ped)
        end
    end

    lib.waitFor(function()
        return not IsEntityWaitingForWorldCollision(vehicle)
    end)

    if NetworkGetEntityOwner(vehicle) ~= cache.playerId then return end

    local state = Entity(vehicle).state

    SetVehicleOnGroundProperly(vehicle);

    SetTimeout(0, function()
        state:set('initVehicle', nil, true)
    end)
end)
