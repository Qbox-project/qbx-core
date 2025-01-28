local defaultSpawn = require 'config.shared'.defaultSpawn
local characterDataTables = require 'config.server'.characterDataTables
local playerDataUpdateQueue = {}
local collectedPlayerData = {}
local isUpdating = false
local isPlayerUpdating = false

local otherNamedPlayerFields = {
    ['items'] = 'inventory',
    ['lastLoggedOut'] = 'last_logged_out'
}

local jsonPlayerFields = {
    ['id'] = false,
    ['userId'] = false,
    ['citizenid'] = false,
    ['cid'] = false,
    ['license'] = false,
    ['name'] = false,
    ['money'] = true,
    ['charinfo'] = true,
    ['job'] = true,
    ['gang'] = true,
    ['position'] = true,
    ['metadata'] = true,
    ['inventory'] = true,
    ['phone_number'] = false,
    ['last_updated'] = false,
    ['last_logged_out'] = false
}

local function createUsersTable()
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS `users` (
            `userId` int UNSIGNED NOT NULL AUTO_INCREMENT,
            `username` varchar(255) DEFAULT NULL,
            `license` varchar(50) DEFAULT NULL,
            `license2` varchar(50) DEFAULT NULL,
            `fivem` varchar(20) DEFAULT NULL,
            `discord` varchar(30) DEFAULT NULL,
            PRIMARY KEY (`userId`)
        ) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]])
end

---@param identifiers table<PlayerIdentifier, string>
---@return number?
local function createUser(identifiers)
    return MySQL.insert.await('INSERT INTO users (username, license, license2, fivem, discord) VALUES (?, ?, ?, ?, ?)', {
        identifiers.username,
        identifiers.license,
        identifiers.license2,
        identifiers.fivem,
        identifiers.discord,
    })
end

---@param identifier string
---@return integer?
local function fetchUserByIdentifier(identifier)
    local idType = identifier:match('([^:]+)')
    local select = ('SELECT `userId` FROM `users` WHERE `%s` = ? LIMIT 1'):format(idType)

    return MySQL.scalar.await(select, { identifier })
end

---@param request InsertBanRequest
---@return boolean success
---@return ErrorResult? errorResult
local function insertBan(request)
    if not request.discordId and not request.ip and not request.license then
        return false, {
            code = 'no_identifier',
            message = 'discordId, ip, or license required in the ban request'
        }
    end

    MySQL.insert.await('INSERT INTO bans (name, license, discord, ip, reason, expire, bannedby) VALUES (?, ?, ?, ?, ?, ?, ?)', {
        request.name,
        request.license,
        request.discordId,
        request.ip,
        request.reason,
        request.expiration,
        request.bannedBy,
    })
    return true
end

---@param request GetBanRequest
---@return string column in storage
---@return string value of the id
local function getBanId(request)
    if request.license then
        return 'license', request.license
    elseif request.discordId then
        return 'discord', request.discordId
    elseif request.ip then
        return 'ip', request.ip
    else
        error('no identifier provided', 2)
    end
end

---@param request GetBanRequest
---@return BanEntity?
local function fetchBan(request)
    local column, value = getBanId(request)
    local result = MySQL.single.await('SELECT expire, reason FROM bans WHERE ' .. column .. ' = ?', { value })
    return result and {
        expire = result.expire,
        reason = result.reason,
    } or nil
end

---@param request GetBanRequest
local function deleteBan(request)
    local column, value = getBanId(request)
    MySQL.query.await('DELETE FROM bans WHERE ' .. column .. ' = ?', { value })
end

---@param request UpsertPlayerRequest
local function upsertPlayerEntity(request)
    MySQL.insert.await('INSERT INTO players (userId, citizenid, cid, license, name, money, charinfo, job, gang, position, metadata, last_logged_out) VALUES (:userId, :citizenid, :cid, :license, :name, :money, :charinfo, :job, :gang, :position, :metadata, :last_logged_out) ON DUPLICATE KEY UPDATE userId = :userId, name = :name, money = :money, charinfo = :charinfo, job = :job, gang = :gang, position = :position, metadata = :metadata, last_logged_out = :last_logged_out', {
        userId = request.playerEntity.userId,
        citizenid = request.playerEntity.citizenid,
        cid = request.playerEntity.charinfo.cid,
        license = request.playerEntity.license,
        name = request.playerEntity.name,
        money = json.encode(request.playerEntity.money),
        charinfo = json.encode(request.playerEntity.charinfo),
        job = json.encode(request.playerEntity.job),
        gang = json.encode(request.playerEntity.gang),
        position = json.encode(request.position),
        metadata = json.encode(request.playerEntity.metadata),
        last_logged_out = os.date('%Y-%m-%d %H:%M:%S', request.playerEntity.lastLoggedOut)
    })
end

---@param citizenId string
---@return PlayerSkin?
local function fetchPlayerSkin(citizenId)
    return MySQL.single.await('SELECT * FROM playerskins WHERE citizenid = ? AND active = 1', {citizenId})
end

local function convertPosition(position)
    local pos = json.decode(position)
    local actualPos = (not pos.x or not pos.y or not pos.z) and defaultSpawn or pos
    return vec4(actualPos.x, actualPos.y, actualPos.z, actualPos.w or defaultSpawn.w)
end

---@param license2 string
---@param license? string
---@return PlayerEntity[]
local function fetchAllPlayerEntities(license2, license)
    ---@type PlayerEntity[]
    local chars = {}
    ---@type PlayerEntityDatabase[]
    local result = MySQL.query.await('SELECT citizenid, charinfo, money, job, gang, position, metadata, UNIX_TIMESTAMP(last_logged_out) AS lastLoggedOutUnix FROM players WHERE license = ? OR license = ? ORDER BY cid', {license, license2})
    for i = 1, #result do
        chars[i] = result[i]
        chars[i].charinfo = json.decode(result[i].charinfo)
        chars[i].money = json.decode(result[i].money)
        chars[i].job = result[i].job and json.decode(result[i].job)
        chars[i].gang = result[i].gang and json.decode(result[i].gang)
        chars[i].position = convertPosition(result[i].position)
        chars[i].metadata = json.decode(result[i].metadata)
        chars[i].lastLoggedOut = result[i].lastLoggedOutUnix
    end

    return chars
end

---@param citizenId string
---@return PlayerEntity?
local function fetchPlayerEntity(citizenId)
    ---@type PlayerEntityDatabase
    local player = MySQL.single.await('SELECT userId, citizenid, license, name, charinfo, money, job, gang, position, metadata, UNIX_TIMESTAMP(last_logged_out) AS lastLoggedOutUnix FROM players WHERE citizenid = ?', { citizenId })
    local charinfo = player and json.decode(player.charinfo)
    return player and {
        userId = player.userId,
        citizenid = player.citizenid,
        license = player.license,
        name = player.name,
        money = json.decode(player.money),
        charinfo = charinfo,
        cid = charinfo.cid,
        job = player.job and json.decode(player.job),
        gang = player.gang and json.decode(player.gang),
        position = convertPosition(player.position),
        metadata = json.decode(player.metadata),
        lastLoggedOut = player.lastLoggedOutUnix
    } or nil
end

---@param filters table<string, any>
---@return string, any[]
local function handleSearchFilters(filters)
    if not filters then return '', {} end

    local holders = {}
    local clauses = {}

    if filters.license then
        clauses[#clauses + 1] = 'license = ?'
        holders[#holders + 1] = filters.license
    end

    if filters.job then
        clauses[#clauses + 1] = 'JSON_EXTRACT(job, "$.name") = ?'
        holders[#holders + 1] = filters.job
    end

    if filters.gang then
        clauses[#clauses + 1] = 'JSON_EXTRACT(gang, "$.name") = ?'
        holders[#holders + 1] = filters.gang
    end

    if filters.metadata then
        local strict = filters.metadata.strict
        for key, value in pairs(filters.metadata) do
            if key ~= "strict" then
                if type(value) == "number" then
                    if strict then
                        clauses[#clauses + 1] = 'JSON_EXTRACT(metadata, "$.' .. key .. '") = ?'
                    else
                        clauses[#clauses + 1] = 'JSON_EXTRACT(metadata, "$.' .. key .. '") >= ?'
                    end

                    holders[#holders + 1] = value
                elseif type(value) == "boolean" then
                    clauses[#clauses + 1] = 'JSON_EXTRACT(metadata, "$.' .. key .. '") = ?'
                    holders[#holders + 1] = tostring(value)
                elseif type(value) == "string" then
                    clauses[#clauses + 1] = 'JSON_UNQUOTE(JSON_EXTRACT(metadata, "$.' .. key .. '")) = ?'
                    holders[#holders + 1] = value
                end
            end
        end
    end

    return (' WHERE %s'):format(table.concat(clauses, ' AND ')), holders
end

---@param filters table <string, any>
---@return PlayerEntityDatabase[]
local function searchPlayerEntities(filters)
    local query = "SELECT citizenid FROM players"
    local where, holders = handleSearchFilters(filters)
    lib.print.debug(query .. where)
    ---@type PlayerEntityDatabase[]
    local response = MySQL.query.await(query .. where, holders)
    return response
end

---Checks if a table exists in the database
---@param tableName string
---@return boolean
local function doesTableExist(tableName)
    local tbl = MySQL.single.await(('SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_NAME = \'%s\' AND TABLE_SCHEMA in (SELECT DATABASE())'):format(tableName))
    return tbl['COUNT(*)'] > 0
end

---deletes character data using the characterDataTables object in the config file
---@param citizenId string
---@return boolean success if operation is successful.
local function deletePlayer(citizenId)
    local query = 'DELETE FROM %s WHERE %s = ?'
    local queries = {}

    for i = 1, #characterDataTables do
        local data = characterDataTables[i]
        local tableName = data[1]
        local columnName = data[2]
        if doesTableExist(tableName) then
            queries[#queries + 1] = {
                query = query:format(tableName, columnName),
                values = {
                    citizenId,
                }
            }
        else
            warn(('Table %s does not exist in database, please remove it from qbx_core/config/server.lua or create the table'):format(tableName))
        end
    end

    local success = MySQL.transaction.await(queries)
    return not not success
end

---checks the storage for uniqueness of the given value
---@param type UniqueIdType
---@param value string|number
---@return boolean isUnique if the value does not already exist in storage for the given type
local function fetchIsUnique(type, value)
    local typeToColumn = {
        citizenid = 'citizenid',
        AccountNumber = "JSON_VALUE(charinfo, '$.account')",
        PhoneNumber = "JSON_VALUE(charinfo, '$.phone')",
        FingerId = "JSON_VALUE(metadata, '$.fingerprint')",
        WalletId = "JSON_VALUE(metadata, '$.walletid')",
        SerialNumber = "JSON_VALUE(metadata, '$.phonedata.SerialNumber')",
    }

    local result = MySQL.single.await('SELECT COUNT(*) as count FROM players WHERE ' .. typeToColumn[type] .. ' = ?', { value })
    return result.count == 0
end

---@param citizenid string
---@param type GroupType type
---@param group string
---@param grade integer
local function addToGroup(citizenid, type, group, grade)
    MySQL.insert('INSERT INTO player_groups (citizenid, type, `group`, grade) VALUES (:citizenid, :type, :group, :grade) ON DUPLICATE KEY UPDATE grade = :grade', {
        citizenid = citizenid,
        type = type,
        group = group,
        grade = grade,
    })
end

---@param citizenid string
---@param group string
---@param grade integer
local function addPlayerToJob(citizenid, group, grade)
    addToGroup(citizenid, GroupType.JOB, group, grade)
end

---@param citizenid string
---@param group string
---@param grade integer
local function addPlayerToGang(citizenid, group, grade)
    addToGroup(citizenid, GroupType.GANG, group, grade)
end

---@param citizenid string
---@return table<string, integer> jobs
---@return table<string, integer> gangs
local function fetchPlayerGroups(citizenid)
    local groups = MySQL.query.await('SELECT `group`, type, grade FROM player_groups WHERE citizenid = ?', {citizenid})
    local jobs = {}
    local gangs = {}
    for i = 1, #groups do
        local group = groups[i]
        local validGroup = group.type == GroupType.JOB and GetJob(group.group) or GetGang(group.group)
        if not validGroup then
            lib.print.warn(('Invalid group %s found in player_groups table, Does it exist in shared/%ss.lua?'):format(group.group, group.type))
        elseif not validGroup.grades?[group.grade] then
            lib.print.warn(('Invalid grade %s found in player_groups table for %s %s, Does it exist in shared/%ss.lua?'):format(group.grade, group.type, group.group, group.type))
        elseif group.type == GroupType.JOB then
            jobs[group.group] = group.grade
        elseif group.type == GroupType.GANG then
            gangs[group.group] = group.grade
        end
    end

    return jobs, gangs
end

---@param group string
---@param type GroupType
---@return table<string, integer> players
local function fetchGroupMembers(group, type)
    return MySQL.query.await("SELECT citizenid, grade FROM player_groups WHERE `group` = ? AND `type` = ?", {group, type})
end

---@param citizenid string
---@param type GroupType
---@param group string
local function removeFromGroup(citizenid, type, group)
    MySQL.query.await('DELETE FROM player_groups WHERE citizenid = ? AND type = ? AND `group` = ?', {citizenid, type, group})
end

---@param citizenid string
---@param group string
local function removePlayerFromJob(citizenid, group)
    removeFromGroup(citizenid, GroupType.JOB, group)
end

---@param citizenid string
---@param group string
local function removePlayerFromGang(citizenid, group)
    removeFromGroup(citizenid, GroupType.GANG, group)
end

---Copies player's primary job/gang to the player_groups table. Works for online/offline players.
---Idempotent
RegisterCommand('convertjobs', function(source)
    if source ~= 0 then return warn('This command can only be executed using the server console.') end

    local players = MySQL.query.await('SELECT citizenid, JSON_VALUE(job, \'$.name\') AS jobName, JSON_VALUE(job, \'$.grade.level\') AS jobGrade, JSON_VALUE(gang, \'$.name\') AS gangName, JSON_VALUE(gang, \'$.grade.level\') AS gangGrade FROM players')
    for i = 1, #players do
        local player = players[i]
        local success, err = pcall(AddPlayerToJob, player.citizenid, player.jobName, tonumber(player.jobGrade))
        if not success then lib.print.error(err) end
        success, err = pcall(AddPlayerToGang, player.citizenid, player.gangName, tonumber(player.gangGrade))
        if not success then lib.print.error(err) end
    end

    lib.print.info('Converted jobs and gangs successfully')
    TriggerEvent('qbx_core:server:jobsconverted')
end, true)

---Removes invalid groups from the player_groups table.
local function cleanPlayerGroups()
    local groups = MySQL.query.await('SELECT DISTINCT `group`, type, grade FROM player_groups')
    for i = 1, #groups do
        local group = groups[i]
        local validGroup = group.type == GroupType.JOB and GetJob(group.group) or GetGang(group.group)
        if not validGroup then
            MySQL.query.await('DELETE FROM player_groups WHERE `group` = ? AND type = ?', {group.group, group.type})
            lib.print.info(('Remove invalid %s %s from player_groups table'):format(group.type, group.group))
        elseif not validGroup.grades?[group.grade] then
            MySQL.query.await('DELETE FROM player_groups WHERE `group` = ? AND type = ? AND grade = ?', {group.group, group.type, group.grade})
            lib.print.info(('Remove invalid %s %s grade %s from player_groups table'):format(group.type, group.group, group.grade))
        end
    end

    lib.print.info('Removed invalid groups from player_groups table')
end

---@param citizenid string
---@param key string | string[]
---@param value any
local function addPlayerDataUpdate(citizenid, key, value)
    local hasSubKeys = type(key) == 'table'

    if hasSubKeys then
        key[1] = otherNamedPlayerFields[key[1]] or key[1]
    else
        key = otherNamedPlayerFields[key] or key
    end

    if jsonPlayerFields[hasSubKeys and key[1] or key] == nil then
        lib.print.error(('Tried to update player data field %s when it doesn\'t exist. Value: %s'):format(hasSubKeys and key[1] or key, value))
        return
    end

    if hasSubKeys and not jsonPlayerFields[key[1]] then
        lib.print.error(('Tried to update player data field %s as a json object when it isn\'t one'):format(key[1]))
        return
    end

    value = type(value) == 'table' and json.encode(value) or value

    local currentTable = isUpdating and playerDataUpdateQueue or collectedPlayerData
    if not currentTable[citizenid] then
        currentTable[citizenid] = {}
    end

    currentTable[citizenid][hasSubKeys and key[1] or key] = hasSubKeys and {} or value

    if hasSubKeys then
        local current = currentTable[citizenid][key[1]]
        if #key > 2 then
            -- We don't check the last one because otherwise we lose the table reference
            for i = 2, #key - 1 do
                if not current[key[i]] then
                    current[key[i]] = {}
                end

                current = current[key[i]]
            end
        end

        current[key[#key]] = value
    end
end

---@param key string
---@param nestedTable table<string, any>
---@param path string?
---@param citizenid string
local function updateNestedPlayerData(key, nestedTable, citizenid, path)
    for k, v in pairs(nestedTable) do
        local currentPath = path and ('%s.%s'):format(path, k) or k
        if type(v) == 'table' then
            updateNestedPlayerData(key, v, citizenid, currentPath)
        else
            local query = ('UPDATE players SET %s = JSON_SET(%s, "$.%s", ?) WHERE citizenid = ?'):format(key, key, currentPath)
            MySQL.prepare.await(query, { v, citizenid })
        end
    end
end

local function sendPlayerDataUpdates()
    if isUpdating then return end

    -- We wait on a single player to be updated to not mess with the collectedPlayerData table whilst it's updating
    while isPlayerUpdating do
        Wait(10)
    end

    -- We implement this to ensure when updating no values are added to our updating sequence to prevent data loss by accidentally skipping over it
    isUpdating = true

    for citizenid, playerData in pairs(collectedPlayerData) do
        for key, data in pairs(playerData) do
            if type(data) == 'table' then
                updateNestedPlayerData(key, data, citizenid)
            else
                local query = ('UPDATE players SET %s = ? WHERE citizenid = ?'):format(key)
                MySQL.prepare.await(query, { data, citizenid })
            end
        end
    end

    collectedPlayerData = playerDataUpdateQueue
    playerDataUpdateQueue = {}
    isUpdating = false
end

---@param citizenid string
local function forcePlayerDataUpdate(citizenid)
    -- We don't need to update a single player when everyone is already getting an update
    if isUpdating then return end

    -- We wait on a single player to be updated to not mess with the collectedPlayerData table whilst it's updating
    while isPlayerUpdating do
        Wait(10)
    end

    isPlayerUpdating = true

    local playerData = collectedPlayerData[citizenid]
    for key, data in pairs(playerData) do
        if type(data) == 'table' then
            updateNestedPlayerData(key, data, citizenid)
        else
            local query = ('UPDATE players SET %s = ? WHERE citizenid = ?'):format(key)
            MySQL.prepare.await(query, { data, citizenid })
        end
    end

    collectedPlayerData[citizenid] = playerDataUpdateQueue[citizenid]
    playerDataUpdateQueue[citizenid] = nil
    isPlayerUpdating = false
end

RegisterCommand('cleanplayergroups', function(source)
    if source ~= 0 then return warn('This command can only be executed using the server console.') end

    cleanPlayerGroups()
end, true)

CreateThread(function()
    for _, data in pairs(characterDataTables) do
        local tableName = data[1]
        if not doesTableExist(tableName) then
            warn(('Table \'%s\' does not exist in database, please remove it from qbx_core/config/server.lua or create the table'):format(tableName))
        end
    end

    if GetConvar('qbx:cleanPlayerGroups', 'false') == 'true' then
        cleanPlayerGroups()
    end
end)

return {
    createUsersTable = createUsersTable,
    createUser = createUser,
    fetchUserByIdentifier = fetchUserByIdentifier,
    insertBan = insertBan,
    fetchBan = fetchBan,
    deleteBan = deleteBan,
    upsertPlayerEntity = upsertPlayerEntity,
    fetchPlayerSkin = fetchPlayerSkin,
    fetchPlayerEntity = fetchPlayerEntity,
    fetchAllPlayerEntities = fetchAllPlayerEntities,
    deletePlayer = deletePlayer,
    fetchIsUnique = fetchIsUnique,
    addPlayerToJob = addPlayerToJob,
    addPlayerToGang = addPlayerToGang,
    fetchPlayerGroups = fetchPlayerGroups,
    fetchGroupMembers = fetchGroupMembers,
    removePlayerFromJob = removePlayerFromJob,
    removePlayerFromGang = removePlayerFromGang,
    searchPlayerEntities = searchPlayerEntities,
    sendPlayerDataUpdates = sendPlayerDataUpdates,
    forcePlayerDataUpdate = forcePlayerDataUpdate,
    addPlayerDataUpdate = addPlayerDataUpdate
}
