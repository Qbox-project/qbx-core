local acknowledged = GetConvar('qbx:acknowledge', 'false') == 'true'
local messagesUrl = GetConvar('qbx:serviceMessagesUrl', 'https://raw.githubusercontent.com/Qbox-project/txAdminRecipe/refs/heads/main/service-messages.json')
local resourceVersion = GetResourceMetadata(cache.resource, 'version', 0)

---@param str string
---@param prefix string
---@return boolean
local function startsWith(str, prefix)
    return str:sub(1, prefix:len()) == prefix
end

---Returns whether the given version prefix or exact version matches the resource's version.
---@return boolean
local function isResourceVersion(version)
    if type(version) == 'string' then
        -- if we don't have a dot at the end, check for an exact version match
        if version:sub(-1) ~= '.' then
            return resourceVersion == version
        end

        -- otherwise treat `version` as a prefix
        return startsWith(resourceVersion, version)
    end

    if type(version) == 'table' then
        for i = 1, #version do
            local currentVersion = version[i]
            if isResourceVersion(currentVersion) then
                return true
            end
        end

        return false
    end

    return not version
end

---Returns the given content stringified, or concatenated with a newline separator if given a table.
---@return string
local function validateContent(content)
    if type(content) == 'table' then
        local concat = ''

        for i = 1, #content do
            concat = concat .. (i == 1 and '' or '\n') .. tostring(content[i])
        end

        return concat
    end

    return tostring(content)
end

CreateThread(function()
    Wait(500) -- wait until after the Nucleus message
    local messages = {}

    if not acknowledged then
        messages[#messages + 1] = [[^7
^4Welcome to ^3Qbox^4!
To learn more, please check out the documentation at ^5https://docs.qbox.re/^4.
To turn this message off, set the ^3qbx:acknowledge^4 convar to true in your server.cfg file.^7]]
    end

    local requestPromise = promise:new()
    PerformHttpRequest(messagesUrl, function(_, body)
        requestPromise:resolve(body)
    end, 'GET')

    local serviceMessages = json.decode(Citizen.Await(requestPromise))
    if type(serviceMessages) == 'table' then
        local hasServiceMessage = false
        for i = 1, #serviceMessages do
            local message = serviceMessages[i]
            if type(message) == 'table' and message.content and isResourceVersion(message.version) then
                if not hasServiceMessage then
                    hasServiceMessage = true
                    messages[#messages + 1] = '\n^5Qbox service messages:^7'
                end

                local content = validateContent(message.content)
                if content then
                    messages[#messages + 1] = '    ' .. content
                end
            end
        end
    end

    if #messages == 0 then return end
    messages[#messages + 1] = '^7'

    print(table.concat(messages, '\n'))
end)
