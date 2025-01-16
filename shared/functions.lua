--- HasPlayerGotGroup function borrowed from ox_target: https://github.com/overextended/ox_target/blob/aefc464d01da9b7aa3565e79161dd0a489945b90/client/framework/qb.lua#L41

-- MIT License

-- Copyright (c) 2022 Overextended

-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:

-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.

-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.

---@param filter string | string[] | table<string, number>
---@param playerData table
---@param primary? boolean Check only for primary job/gang
---@return boolean
function HasPlayerGotGroup(filter, playerData, primary)
    local groups = not primary and GetPlayerGroups(playerData)
    if not filter then return false end

    local _type = type(filter)
    if _type == 'string' then
        local job = playerData.job.name == filter
        local gang = playerData.gang.name == filter
        local group = groups and groups[filter]
        local citizenId = playerData.citizenid == filter
        if job or gang or group or citizenId then
            return true
        end
    elseif _type == 'table' then
        local tabletype = table.type(filter)
        if tabletype == 'hash' then
            for name, grade in pairs(filter) do
                local job = playerData.job.name == name
                local gang = playerData.gang.name == name
                local group = groups and groups[name]
                local citizenId = playerData.citizenid == name
                if job and grade <= playerData.job.grade.level or gang and grade <= playerData.gang.grade.level or group and grade <= group or citizenId then
                    return true
                end
            end
        elseif tabletype == 'array' then
            for i = 1, #filter do
                local name = filter[i]
                local job = playerData.job.name == name
                local gang = playerData.gang.name == name
                local group = groups and groups[name]
                local citizenId = playerData.citizenid == name
                if job or gang or group or citizenId then
                    return true
                end
            end
        end
    end

    return false
end

---@param playerData PlayerData
---@return table<string, integer> playerGroups
function GetPlayerGroups(playerData)
    local groups = {}
    for job, data in pairs(playerData.jobs) do
        if not groups[job] then
            groups[job] = data
        end
    end

    for gang, data in pairs(playerData.gangs) do
        if not groups[gang] then
            groups[gang] = data
        else
            lib.print.warn(('Duplicate group name %s found in player_groups table, check job and gang shared lua.'):format(gang))
        end
    end

    return groups
end