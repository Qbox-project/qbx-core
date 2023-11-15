local ServerConfig = require 'config.server'.Server

-- Event Handler

local usedLicenses = {}

---@param message string
AddEventHandler('chatMessage', function(_, _, message)
    if string.sub(message, 1, 1) == '/' then
        CancelEvent()
        return
    end
end)

AddEventHandler('playerJoining', function()
    if not ServerConfig.CheckDuplicateLicense then return end
    local src = source --[[@as string]]
    local license = GetPlayerIdentifierByType(src, 'license2') or GetPlayerIdentifierByType(src, 'license')
    if not license then return end
    if usedLicenses[license] then
        Wait(0) -- mandatory wait for the drop reason to show up
        DropPlayer(src, Lang:t('error.duplicate_license'))
    else
        usedLicenses[license] = true
    end
end)

---@param reason string
AddEventHandler('playerDropped', function(reason)
    local src = source --[[@as string]]
    local license = GetPlayerIdentifierByType(src, 'license2') or GetPlayerIdentifierByType(src, 'license')
    if license then usedLicenses[license] = nil end
    if not QBX.Players[src] then return end
    GlobalState.PlayerCount -= 1
    local player = QBX.Players[src]
    TriggerEvent('qb-log:server:CreateLog', 'joinleave', 'Dropped', 'red', '**' .. GetPlayerName(src) .. '** (' .. player.PlayerData.license .. ') left..' ..'\n **Reason:** ' .. reason)
    player.Functions.Save()
    QBX.Player_Buckets[player.PlayerData.license] = nil
    QBX.Players[src] = nil
end)

---@class Deferrals https://docs.fivem.net/docs/scripting-reference/events/list/playerConnecting/#deferring-connections
---@field defer fun() initialize deferrals for the current resource. Required to wait at least 1 tick before calling other deferrals methods.
---@field update fun(message: string) sends a progress message to the connecting client
---@field presentCard fun(card: unknown|string, cb?: fun(data: unknown, rawData: string)) send an adaptive card to the client https://learn.microsoft.com/en-us/adaptive-cards/authoring-cards/getting-started and capture user input via callback.
---@field done fun(failureReason?: string) finalizes deferrals. If failureReason is present, user will be refused connection and shown reason. Need to wait 1 tick after calling other deferral methods before calling done.

-- Player Connecting
---@param name any
---@param _ any
---@param deferrals Deferrals
local function onPlayerConnecting(name, _, deferrals)
    local src = source --[[@as string]]
    local license
    local identifiers = GetPlayerIdentifiers(src)
    deferrals.defer()

    -- Mandatory wait
    Wait(0)

    if ServerConfig.Closed then
        if not IsPlayerAceAllowed(src, 'qbadmin.join') then
            deferrals.done(ServerConfig.ClosedReason)
        end
    end

    for _, v in pairs(identifiers) do
        if string.find(v, 'license2') or string.find(v, 'license') then
            license = v
            break
        end
    end

    if not license then
        deferrals.done(Lang:t('error.no_valid_license'))
    elseif ServerConfig.CheckDuplicateLicense and IsLicenseInUse(license) then
        deferrals.done(Lang:t('error.duplicate_license'))
    end

    local databaseTime = os.clock()
    local databasePromise = promise.new()

    -- conduct database-dependant checks
    CreateThread(function()
        deferrals.update(string.format(Lang:t('info.checking_ban'), name))
        local success, err = pcall(function()
            local isBanned, Reason = IsPlayerBanned(src --[[@as Source]])
            if isBanned then
                deferrals.done(Reason)
            end
        end)

        if ServerConfig.Whitelist and success then
            deferrals.update(string.format(Lang:t('info.checking_whitelisted'), name))
            success, err = pcall(function()
                if not IsWhitelisted(src --[[@as Source]]) then
                    deferrals.done(Lang:t('error.not_whitelisted'))
                end
            end)
        end

        if not success then
            databasePromise:reject(err)
        end
        databasePromise:resolve()
    end)

    -- wait for database to finish
    databasePromise:next(function()
        deferrals.update(string.format(Lang:t('info.join_server'), name))
        deferrals.done()
    end, function(err)
        deferrals.done(Lang:t('error.connecting_error'))
        lib.print.error(err)
    end)

    -- if conducting db checks for too long then raise error
    while databasePromise.state == 0 do
        if os.clock() - databaseTime > 30 then
            deferrals.done(Lang:t('error.connecting_database_timeout'))
            error(Lang:t('error.connecting_database_timeout'))
            break
        end
        Wait(1000)
    end

    -- Add any additional defferals you may need!
end

AddEventHandler('playerConnecting', onPlayerConnecting)

-- New method for checking if logged in across all scripts (optional)
-- `if LocalPlayer.state.isLoggedIn then` for the client side
-- `if Player(source).state.isLoggedIn then` for the server side
RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
    Player(source --[[@as Source]]).state:set('isLoggedIn', true, true)
end)

---@param source Source
AddEventHandler('QBCore:Server:OnPlayerUnload', function(source)
    Player(source).state:set('isLoggedIn', false, true)
end)

-- Open & Close Server (prevents players from joining)

---@param reason string
RegisterNetEvent('QBCore:Server:CloseServer', function(reason)
    local src = source --[[@as Source]]
    if HasPermission(src, 'admin') then
        reason = reason or 'No reason specified'
        ServerConfig.Closed = true
        ServerConfig.ClosedReason = reason
        for k in pairs(QBX.Players) do
            if not HasPermission(k, ServerConfig.WhitelistPermission) then
                KickWithReason(k, reason, nil, nil)
            end
        end
    else
        KickWithReason(src, Lang:t("error.no_permission"), nil, nil)
    end
end)

RegisterNetEvent('QBCore:Server:OpenServer', function()
    local src = source --[[@as Source]]
    if HasPermission(src, 'admin') then
        ServerConfig.Closed = false
    else
        KickWithReason(src, Lang:t("error.no_permission"), nil, nil)
    end
end)

-- Player

RegisterNetEvent('QBCore:ToggleDuty', function()
    local src = source --[[@as Source]]
    local player = GetPlayer(src)
    if not player then return end
    if player.PlayerData.job.onduty then
        player.Functions.SetJobDuty(false)
        Notify(src, Lang:t('info.off_duty'))
    else
        player.Functions.SetJobDuty(true)
        Notify(src, Lang:t('info.on_duty'))
    end
    TriggerClientEvent('QBCore:Client:SetDuty', src, player.PlayerData.job.onduty)
end)
