local isServer = IsDuplicityVersion()
if not isServer then
    lib.print.error('cannot use the logger on the client')
    return
end

local logQueue, isProcessingQueue, logCount = {}, false, 0
local lastRequestTime, requestDelay = 0, 0

---@enum Colors
local Colors = { -- https://www.spycolor.com/
    default = 14423100,
    blue = 255,
    red = 16711680,
    green = 65280,
    white = 16777215,
    black = 0,
    orange = 16744192,
    yellow = 16776960,
    pink = 16761035,
    lightgreen = 65309,
}

---Log Queue
local function applyRequestDelay()
    local currentTime = GetGameTimer()
    local timeDiff = currentTime - lastRequestTime
    if timeDiff < requestDelay then
        local remainingDelay = requestDelay - timeDiff

        Wait(remainingDelay)
    end

    lastRequestTime = GetGameTimer()
end

local allowedErr = {
    [200] = true,
    [201] = true,
    [204] = true,
    [304] = true
}

---@class DiscordLog
---@field webhook string url of the webhook this log should send to
---@field tags? string[] tags in discord. Example: {'<@%roleid>', '@everyone'}
---@field embed table formatted embed table for discord webhook

---Log Queue
---@param payload DiscordLog Queue
local function logPayload(payload)
    local tags
    local username = 'QBX Logs'
    local avatarUrl = 'https://qbox-project.github.io/qbox-duck.png'

    if payload.tags then
        for i = 1, #payload.tags do
            if not tags then tags = '' end
            tags = tags .. payload.tags[i]
        end
    end

    PerformHttpRequest(payload.webhook, function(err, _, headers)
        if err and not allowedErr[err] then
            lib.print.error('can\'t send log to discord', err)
            return
        end

        local remainingRequests = tonumber(headers['X-RateLimit-Remaining'])
        local resetTime = tonumber(headers['X-RateLimit-Reset'])
        if remainingRequests and resetTime and remainingRequests == 0 then
            local currentTime = os.time()
            local resetDelay = resetTime - currentTime
            if resetDelay > 0 then
                requestDelay = resetDelay * 1000 / 10
            end
        end
    end, 'POST', json.encode({username = username, avatar_url = avatarUrl, content = tags, embeds = payload.embed}), { ['Content-Type'] = 'application/json' })
end

---Log Queue
local function processLogQueue()
    if #logQueue > 0 then
        local payload = table.remove(logQueue, 1)

        logPayload(payload)

        logCount += 1

        if logCount % 5 == 0 then
            Wait(60000)
        else
            applyRequestDelay()
        end

        processLogQueue()
    else
        isProcessingQueue = false
    end
end

---Creates a discord log
---@param log Log
local function discordLog(log)
    local embedData = {
        {
            title = log.event,
            color = Colors[log.color] or Colors.default,
            footer = {
                text = os.date('%H:%M:%S %m-%d-%Y'),
            },
            description = log.message,
            author = {
                name = log.source,
            },
        }
    }

    logQueue[#logQueue + 1] = {
        webhook = log.webhook,
        tags = log.tags,
        embed = embedData
    }

    if not isProcessingQueue then
        isProcessingQueue = true
        CreateThread(processLogQueue)
    end
end

---@class Log
---@field source string source of the log. Usually a playerId or name of a resource.
---@field event string the action or 'event' being logged. Usually a verb describing what the name is doing. Example: SpawnVehicle
---@field message string the message attached to the log
---@field webhook? string Discord logs only. url of the webhook this log should send to
---@field color? string Discord logs only. what color the message should be
---@field tags? string[] Discord logs only. tags in discord. Example: {'<@%roleid>', '@everyone'}
---@field oxLibTags? string -- Tags for ox_lib logger

---Logs using ox_lib, if ox_lib logging is configured. Additionally logs to discord if a web hook is passed.
---@param log Log
local function createLog(log)
    if log.webhook then
        ---@diagnostic disable-next-line: param-type-mismatch
        discordLog(log)
    end

    lib.logger(log.source, log.event, log.message, log.oxLibTags) -- support for ox_lib: datadog, grafana loki logging, fivemanage
end

return {
    log = createLog
}
