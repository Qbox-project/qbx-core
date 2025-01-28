local serverConfig = require 'config.server'.server
local loggingConfig = require 'config.server'.logging
local serverName = require 'config.shared'.serverName
local storage = require 'server.storage.main'
local logger = require 'modules.logger'
local queue = require 'server.queue'

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
    local src = source --[[@as string]]
    local license = GetPlayerIdentifierByType(src, 'license2') or GetPlayerIdentifierByType(src, 'license')
    if not license then return end

    if queue then
        queue.removePlayerJoining(license)
    end

    if not serverConfig.checkDuplicateLicense then return end

    if usedLicenses[license] then
        Wait(0) -- mandatory wait for the drop reason to show up
        DropPlayer(src, locale('error.duplicate_license'))
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

    GlobalState.PlayerCount = GetNumPlayerIndices()

    local player = QBX.Players[src]
    player.PlayerData.lastLoggedOut = os.time()
    Save(player.PlayerData.source)

    logger.log({
        source = 'qbx_core',
        webhook = loggingConfig.webhook.joinleave,
        event = 'Dropped',
        color = 'red',
        message = ('**%s** (%s) left...\n **Reason:** %s'):format(GetPlayerName(src), player.PlayerData.license, reason),
    })

    QBX.Player_Buckets[player.PlayerData.license] = nil
    QBX.Players[src] = nil
end)

---@param source Source | string
---@return table<string, string>
local function getIdentifiers(source)
    local identifiers = {}
    for i = 0, GetNumPlayerIdentifiers(source --[[@as string]]) - 1 do
        local identifier = GetPlayerIdentifier(source --[[@as string]], i)
        local prefix = identifier:match('([^:]+)')
        if prefix ~= 'ip' then
            identifiers[prefix] = identifier
        end
    end

    return identifiers
end

-- Player Connecting
---@param name string
---@param _ any
---@param deferrals Deferrals
local function onPlayerConnecting(name, _, deferrals)
    local src = source --[[@as string]]
    local license = GetPlayerIdentifierByType(src, 'license2') or GetPlayerIdentifierByType(src, 'license')
    local userId = storage.fetchUserByIdentifier(license)
    deferrals.defer()

    -- Mandatory wait
    Wait(0)

    if serverConfig.closed then
        if not IsPlayerAceAllowed(src, 'qbadmin.join') then
            deferrals.done(serverConfig.closedReason)
        end
    end

    if not license then
        deferrals.done(locale('error.no_valid_license'))
    elseif serverConfig.checkDuplicateLicense and usedLicenses[license] then
        deferrals.done(locale('error.duplicate_license'))
    end

    if not userId then
        local identifiers = getIdentifiers(src)
        identifiers.username = name
        storage.createUser(identifiers)
    end

    local databaseTime = os.clock()
    local databasePromise = promise.new()

    -- conduct database-dependant checks
    CreateThread(function()
        deferrals.update(locale('info.checking_ban', name))
        local success, err = pcall(function()
            local isBanned, Reason = IsPlayerBanned(src --[[@as Source]])
            if isBanned then
                Wait(0) -- Mandatory wait
                deferrals.done(Reason)
            end
        end)

        if serverConfig.whitelist and success then
            deferrals.update(locale('info.checking_whitelisted', name))
            success, err = pcall(function()
                if not IsWhitelisted(src --[[@as Source]]) then
                    Wait(0) -- Mandatory wait
                    deferrals.done(locale('error.not_whitelisted'))
                end
            end)
        end

        if not success then
            databasePromise:reject(err)
        end

        databasePromise:resolve()
    end)

    local onError = function(err)
        deferrals.done(locale('error.connecting_error'))
        lib.print.error(err)
    end

    -- wait for database to finish
    databasePromise:next(function()
        deferrals.update(locale('info.join_server', name, serverName))

        -- Mandatory wait
        Wait(0)

        if queue then
            queue.awaitPlayerQueue(src --[[@as Source]], license, deferrals)
        else
            deferrals.done()
        end
    end, onError):next(function() end, onError)

    -- if conducting db checks for too long then raise error
    while databasePromise.state == 0 do
        if os.clock() - databaseTime > 30 then
            deferrals.done(locale('error.connecting_database_timeout'))
            error(locale('error.connecting_database_timeout'))
            break
        end
        Wait(1000)
    end

    -- Add any additional defferals you may need!
end

AddEventHandler('playerConnecting', onPlayerConnecting)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= cache.resource then return end

    storage.createUsersTable()

    MySQL.query([[
        ALTER TABLE `players`
        ADD COLUMN IF NOT EXISTS `userId` INT UNSIGNED DEFAULT NULL AFTER `id`;
    ]])
end)

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
    if IsPlayerAceAllowed(src --[[@as string]], 'admin') then
        reason = reason or 'No reason specified'
        serverConfig.closed = true
        serverConfig.closedReason = reason
        for k in pairs(QBX.Players) do
            if not IsPlayerAceAllowed(k --[[@as string]], serverConfig.whitelistPermission) then
                DropPlayer(k --[[@as string]], reason)
            end
        end
    else
        DropPlayer(src --[[@as string]], locale('error.no_permission'))
    end
end)

RegisterNetEvent('QBCore:Server:OpenServer', function()
    local src = source --[[@as Source]]
    if IsPlayerAceAllowed(src --[[@as string]], 'admin') then
        serverConfig.closed = false
    else
        DropPlayer(src --[[@as string]], locale('error.no_permission'))
    end
end)

-- Player

RegisterNetEvent('QBCore:ToggleDuty', function()
    local src = source --[[@as Source]]
    local player = GetPlayer(src)
    if not player then return end

    if player.PlayerData.job.onduty then
        player.Functions.SetJobDuty(false)
        Notify(src, locale('info.off_duty'))
    else
        player.Functions.SetJobDuty(true)
        Notify(src, locale('info.on_duty'))
    end
end)

---Syncs the player's hunger, thirst, and stress levels with the statebags
---@param bagName string
---@param meta 'hunger' | 'thirst' | 'stress'
---@param value number
local function playerStateBagCheck(bagName, meta, value)
    if not value then return end

    local plySrc = GetPlayerFromStateBagName(bagName)
    if not plySrc then return end

    local player = QBX.Players[plySrc]
    if not player or player.PlayerData.metadata[meta] == value then return end

    player.Functions.SetMetaData(meta, value)
end

---@diagnostic disable-next-line: param-type-mismatch
AddStateBagChangeHandler('hunger', nil, function(bagName, _, value)
    playerStateBagCheck(bagName, 'hunger', value)
end)

---@diagnostic disable-next-line: param-type-mismatch
AddStateBagChangeHandler('thirst', nil, function(bagName, _, value)
    playerStateBagCheck(bagName, 'thirst', value)
end)

---@diagnostic disable-next-line: param-type-mismatch
AddStateBagChangeHandler('stress', nil, function(bagName, _, value)
    playerStateBagCheck(bagName, 'stress', value)
end)
