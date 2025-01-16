local serverConfig = require 'config.server'.server
local positionConfig = require 'config.shared'.notifyPosition
local logger = require 'modules.logger'
local loggingConfig = require 'config.server'.logging
local storage = require 'server.storage.main'

-- Getters
-- Get your player first and then trigger a function on them
-- ex: local player = GetPlayer(source)
-- ex: local example = player.functionname(parameter)

---@param identifier string
---@return integer source of the player with the matching identifier or 0 if no player found
function GetSource(identifier)
    for src in pairs(QBX.Players) do
        local idens = GetPlayerIdentifiers(src)
        for i = 1, #idens do
            if identifier == idens[i] then
                return src
            end
        end
    end

    return 0
end

exports('GetSource', GetSource)

---@param identifier string
---@return integer source of the player with the matching identifier or 0 if no player found
function GetUserId(identifier)
    for src in pairs(QBX.Players) do
        local idens = GetPlayerIdentifiers(src)
        for i = 1, #idens do
            if identifier == idens[i] then
                return QBX.Players[src].PlayerData.userId
            end
        end
    end

    return 0
end

exports('GetUserId', GetUserId)

---@param source Source | string source or identifier of the player
---@return Player
function GetPlayer(source)
    local numberSource = tonumber(source)
    if numberSource then
        return QBX.Players[numberSource]
    else
        return QBX.Players[GetSource(source --[[@as string]])]
    end
end

exports('GetPlayer', GetPlayer)

---@param citizenid string
---@return Player?
function GetPlayerByCitizenId(citizenid)
    for src in pairs(QBX.Players) do
        if QBX.Players[src].PlayerData.citizenid == citizenid then
            return QBX.Players[src]
        end
    end
end

exports('GetPlayerByCitizenId', GetPlayerByCitizenId)

---@param userId string
---@return Player?
function GetPlayerByUserId(userId)
    for src in pairs(QBX.Players) do
        if QBX.Players[src].PlayerData.userId == userId then
            return QBX.Players[src]
        end
    end
end

exports('GetPlayerByUserId', GetPlayerByUserId)

---@param number string
---@return Player?
function GetPlayerByPhone(number)
    for src in pairs(QBX.Players) do
        if QBX.Players[src].PlayerData.charinfo.phone == number then
            return QBX.Players[src]
        end
    end
end

exports('GetPlayerByPhone', GetPlayerByPhone)

---Will return an array of QB Player class instances
---unlike the GetPlayers() wrapper which only returns IDs
---@return table<Source, Player>
function GetQBPlayers()
    return QBX.Players
end

exports('GetQBPlayers', GetQBPlayers)

---Gets a list of all on duty players of a specified job and the number
---@param job string name
---@return integer
---@return Source[]
function GetDutyCountJob(job)
    local players = {}
    local count = 0
    for src, player in pairs(QBX.Players) do
        if player.PlayerData.job.name == job and player.PlayerData.job.onduty then
            players[#players + 1] = src
            count += 1
        end
    end

    return count, players
end

exports('GetDutyCountJob', GetDutyCountJob)

---Gets a list of all on duty players of a specified job type and the number
---@param type string
---@return integer
---@return Source[]
function GetDutyCountType(type)
    local players = {}
    local count = 0
    for src, player in pairs(QBX.Players) do
        if player.PlayerData.job.type == type and player.PlayerData.job.onduty then
            players[#players + 1] = src
            count += 1
        end
    end

    return count, players
end

exports('GetDutyCountType', GetDutyCountType)

-- Routing buckets (Only touch if you know what you are doing)

-- Returns the objects related to buckets, first returned value is the player buckets, second one is entity buckets
---@return table
---@return table
function GetBucketObjects()
    return QBX.Player_Buckets, QBX.Entity_Buckets
end

exports('GetBucketObjects', GetBucketObjects)

-- Will set the provided player id / source into the provided bucket id
---@param source Source
---@param bucket integer
---@return boolean
function SetPlayerBucket(source, bucket)
    if not source or not bucket then return false end

    Player(source).state:set('instance', bucket, true)
    SetPlayerRoutingBucket(source --[[@as string]], bucket)
    QBX.Player_Buckets[source] = bucket

    return true
end

exports('SetPlayerBucket', SetPlayerBucket)

-- Will set any entity into the provided bucket, for example peds / vehicles / props / etc.
---@param entity integer
---@param bucket integer
---@return boolean
function SetEntityBucket(entity, bucket)
    if not entity or not bucket then return false end

    SetEntityRoutingBucket(entity, bucket)
    QBX.Entity_Buckets[entity] = bucket

    return true
end

exports('SetEntityBucket', SetEntityBucket)

-- Will return an array of all the player ids inside the current bucket
---@param bucket integer
---@return Source[]|boolean
function GetPlayersInBucket(bucket)
    local curr_bucket_pool = {}
    if not QBX.Player_Buckets or table.type(QBX.Player_Buckets) == 'empty' then
        return false
    end

    for k, v in pairs(QBX.Player_Buckets) do
        if v == bucket then
            curr_bucket_pool[#curr_bucket_pool + 1] = k
        end
    end

    return curr_bucket_pool
end

exports('GetPlayersInBucket', GetPlayersInBucket)

-- Will return an array of all the entities inside the current bucket (not for player entities, use GetPlayersInBucket for that)
---@param bucket integer
---@return boolean | integer[]
function GetEntitiesInBucket(bucket)
    local curr_bucket_pool = {}
    if not QBX.Entity_Buckets or table.type(QBX.Entity_Buckets) == 'empty' then
        return false
    end

    for k, v in pairs(QBX.Entity_Buckets) do
        if v == bucket then
            curr_bucket_pool[#curr_bucket_pool + 1] = k
        end
    end

    return curr_bucket_pool
end

exports('GetEntitiesInBucket', GetEntitiesInBucket)

-- Items
---@param item string name
---@param data fun(source: Source, item: unknown)
function CreateUseableItem(item, data)
    QBX.UsableItems[item] = data
end

exports('CreateUseableItem', CreateUseableItem)

---@param item string name
---@return unknown
function CanUseItem(item)
    return QBX.UsableItems[item]
end

exports('CanUseItem', CanUseItem)

-- Check if player is whitelisted, kept like this for backwards compatibility or future plans
---@param source Source
---@return boolean
function IsWhitelisted(source)
    return not serverConfig.whitelist or IsPlayerAceAllowed(source --[[@as string]], serverConfig.whitelistPermission)
end

exports('IsWhitelisted', IsWhitelisted)

-- Setting & Removing Permissions

---@deprecated use cfg ACEs instead
---@param source Source
---@param permission string
function AddPermission(source, permission)
    if IsPlayerAceAllowed(source --[[@as string]], permission) then return end

    lib.addPrincipal('player.' .. source, 'group.' .. permission)
    lib.addAce('player.' .. source, 'group.' .. permission)
    TriggerClientEvent('QBCore:Client:OnPermissionUpdate', source)
    TriggerEvent('QBCore:Server:OnPermissionUpdate', source)
end

---@deprecated use cfg ACEs instead
---@diagnostic disable-next-line: deprecated
exports('AddPermission', AddPermission)

---@deprecated use cfg ACEs instead
---@param source Source
---@param permission string
function RemovePermission(source, permission)
    if permission then
        if IsPlayerAceAllowed(source --[[@as string]], permission) then
            lib.removePrincipal('player.' .. source, 'group.' .. permission)
            lib.removeAce('player.' .. source, 'group.' .. permission)
            TriggerClientEvent('QBCore:Client:OnPermissionUpdate', source)
            TriggerEvent('QBCore:Server:OnPermissionUpdate', source)
        end
    else
        local hasUpdated = false

        ---@diagnostic disable-next-line: deprecated
        for _, v in pairs(serverConfig.permissions) do
            if IsPlayerAceAllowed(source --[[@as string]], v) then
                lib.removePrincipal('player.' .. source, 'group.' .. v)
                lib.removeAce('player.' .. source, 'group.' .. v)
                hasUpdated = true
            end
        end
        if hasUpdated then
            TriggerClientEvent('QBCore:Client:OnPermissionUpdate', source)
            TriggerEvent('QBCore:Server:OnPermissionUpdate', source)
        end
    end
end

---@deprecated use cfg ACEs instead
---@diagnostic disable-next-line: deprecated
exports('RemovePermission', RemovePermission)

-- Checking for Permission Level
---@deprecated use IsPlayerAceAllowed
---@param source Source
---@param permission string|string[]
---@return boolean
function HasPermission(source, permission)
    if type(permission) == 'string' then
        if IsPlayerAceAllowed(source --[[@as string]], permission) then return true end
    elseif type(permission) == 'table' then
        for _, permLevel in pairs(permission) do
            if IsPlayerAceAllowed(source --[[@as string]], permLevel) then return true end
        end
    end

    return false
end

---@deprecated use IsPlayerAceAllowed
---@diagnostic disable-next-line: deprecated
exports('HasPermission', HasPermission)

---@deprecated use cfg ACEs instead
---@param source Source
---@return table<string, boolean>
function GetPermission(source)
    local perms = {}

    ---@diagnostic disable-next-line: deprecated
    for _, v in pairs (serverConfig.permissions) do
        if IsPlayerAceAllowed(source --[[@as string]], v) then
            perms[v] = true
        end
    end

    return perms
end

---@deprecated use cfg ACEs instead
---@diagnostic disable-next-line: deprecated
exports('GetPermission', GetPermission)

-- Opt in or out of admin reports
---@param source Source
---@return boolean
function IsOptin(source)
    local license = GetPlayerIdentifierByType(source --[[@as string]], 'license2') or GetPlayerIdentifierByType(source --[[@as string]], 'license')
    if not license or not IsPlayerAceAllowed(source --[[@as string]], 'admin') then return false end

    local player = GetPlayer(source)

    return player.PlayerData.optin
end

exports('IsOptin', IsOptin)

---Opt in or out of admin reports
---@param source Source
function ToggleOptin(source)
    local license = GetPlayerIdentifierByType(source --[[@as string]], 'license2') or GetPlayerIdentifierByType(source --[[@as string]], 'license')
    if not license or not IsPlayerAceAllowed(source --[[@as string]], 'admin') then return end

    local player = GetPlayer(source)
    player.PlayerData.optin = not player.PlayerData.optin
    SetPlayerData(player.PlayerData.source, 'optin', player.PlayerData.optin, nil, true)
end

exports('ToggleOptin', ToggleOptin)

-- Check if player is banned
---@param source Source
---@return boolean
---@return string? playerMessage
function IsPlayerBanned(source)
    local license = GetPlayerIdentifierByType(source --[[@as string]], 'license')
    local license2 = GetPlayerIdentifierByType(source --[[@as string]], 'license2')
    local result = license2 and storage.fetchBan({ license = license2 })

    if not result then
        result = storage.fetchBan({ license = license })
    end

    if not result then return false end

    if os.time() < result.expire then
        local timeTable = os.date('*t', tonumber(result.expire))

        return true, ('You have been banned from the server:\n%s\nYour ban expires in %s/%s/%s %s:%s\n'):format(result.reason, timeTable.day, timeTable.month, timeTable.year, timeTable.hour, timeTable.min)
    else
        CreateThread(function()
            if license2 then
                storage.deleteBan({ license = license2 })
            end

            storage.deleteBan({ license = license })
        end)
    end

    return false
end

exports('IsPlayerBanned', IsPlayerBanned)

---@see client/lua:Notify
function Notify(source, text, notifyType, duration, subTitle, notifyPosition, notifyStyle, notifyIcon, notifyIconColor)
    local title, description
    if type(text) == 'table' then
        title = text.text or 'Placeholder'
        description = text.caption or nil
    elseif subTitle then
        title = text
        description = subTitle
    else
        description = text
    end
    local position = notifyPosition or positionConfig

    TriggerClientEvent('ox_lib:notify', source, {
        id = title,
        title = title,
        description = description,
        duration = duration,
        type = notifyType,
        position = position,
        style = notifyStyle,
        icon = notifyIcon,
        iconColor = notifyIconColor
    })
end

exports('Notify', Notify)

---@param InvokingResource string
---@return string version
local function GetCoreVersion(InvokingResource)
    ---@diagnostic disable-next-line: missing-parameter
    local resourceVersion = GetResourceMetadata(cache.resource, 'version')
    if InvokingResource and InvokingResource ~= '' then
        lib.print.debug(('%s called qbcore version check: %s'):format(InvokingResource or 'Unknown Resource', resourceVersion))
    end
    return resourceVersion
end

exports('GetCoreVersion', GetCoreVersion)

---@param playerId Source server id
---@param origin string reason
local function ExploitBan(playerId, origin)
    local name = GetPlayerName(playerId)
    local success, errorResult = storage.insertBan({
        name = name,
        license = GetPlayerIdentifierByType(playerId --[[@as string]], 'license2') or GetPlayerIdentifierByType(playerId --[[@as string]], 'license'),
        discordId = GetPlayerIdentifierByType(playerId --[[@as string]], 'discord'),
        ip = GetPlayerIdentifierByType(playerId --[[@as string]], 'ip'),
        reason = origin,
        expiration = 2147483647,
        bannedBy = 'Anti Cheat'
    })
    if not success then lib.print.error(errorResult) end
    DropPlayer(playerId --[[@as string]], locale('info.exploit_banned', serverConfig.discord))
    logger.log({
        source = 'qbx_core',
        webhook = loggingConfig.webhook.anticheat,
        event = 'Anti-Cheat',
        color = 'red',
        tags = loggingConfig.role,
        message = success and ('%s has been kicked and banned for exploiting %s'):format(name, origin) or ('%s has been kicked for exploiting %s, ban insert failed'):format(name, origin)
    })
end

exports('ExploitBan', ExploitBan)

---@param source Source
---@param filter string | string[] | table<string, number>
---@return boolean
function HasPrimaryGroup(source, filter)
    local playerData = QBX.Players[source].PlayerData
    return HasPlayerGotGroup(filter, playerData, true)
end

exports('HasPrimaryGroup', HasPrimaryGroup)

---@param source Source
---@param filter string | string[] | table<string, number>
---@return boolean
function HasGroup(source, filter)
    local playerData = QBX.Players[source].PlayerData
    return HasPlayerGotGroup(filter, playerData)
end

exports('HasGroup', HasGroup)

---@param source Source
---@return table<string, integer>
function GetGroups(source)
    local playerData = QBX.Players[source].PlayerData
    return GetPlayerGroups(playerData)
end

exports('GetGroups', GetGroups)

---@return PlayerData[]
local function getPlayersData()
    local playersData = {}
    for _, player in pairs(QBX.Players) do
        playersData[#playersData + 1] = player.PlayerData
    end
    return playersData
end

exports('GetPlayersData', getPlayersData)

---@param filters table <string, any>
---@return Player[]
local function searchPlayerEntities(filters)
    local result = {}
    local response = storage.searchPlayerEntities(filters)
    for i = 1, #response do
        local citizenid = response[i].citizenid
        local player = GetPlayerByCitizenId(citizenid)
        if player then
            result[#result+1] = player
        else
            local offlinePlayer = GetOfflinePlayer(citizenid)
            if offlinePlayer then
                result[#result+1] = offlinePlayer
            end
        end
    end
    return result
end

exports("SearchPlayers", searchPlayerEntities)

local function isGradeBoss(group, grade)
    local groupData = GetJob(group) or GetGang(group)
    if not groupData then return end
    return groupData[grade].IsBoss
end

exports('IsGradeBoss', isGradeBoss)

local function getGroupMembers(group, type)
    return storage.fetchGroupMembers(group, type)
end

exports('GetGroupMembers', getGroupMembers)

---Disables persistence before deleting a vehicle, then deletes it.
---@param vehicle number
function DeleteVehicle(vehicle)
    DisablePersistence(vehicle)
    if DoesEntityExist(vehicle) then
        DeleteEntity(vehicle)
    end
end

exports('DeleteVehicle', DeleteVehicle)