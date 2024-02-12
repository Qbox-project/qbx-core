local jobs = require 'shared.jobs'
local gangs = require 'shared.gangs'

---Adds or overwrites jobs in shared/jobs.lua
---@param newJobs table<string, Job>
function CreateJobs(newJobs)
    for jobName, job in pairs(newJobs) do
        jobs[jobName] = job
        TriggerEvent('qbx_core:server:onJobUpdate', jobName, job)
        TriggerClientEvent('qbx_core:client:onJobUpdate', -1, jobName, job)
    end
end

exports('CreateJobs', CreateJobs)

-- Single Remove Job
---@param jobName string
---@return boolean success
---@return string message
function RemoveJob(jobName)
    if type(jobName) ~= "string" then
        return false, "invalid_job_name"
    end

    if not jobs[jobName] then
        return false, "job_not_exists"
    end

    jobs[jobName] = nil
    TriggerEvent('qbx_core:server:onJobUpdate', jobName, nil)
    TriggerClientEvent('qbx_core:client:onJobUpdate', -1, jobName, nil)
    return true, "success"
end

exports('RemoveJob', RemoveJob)

---Adds or overwrites gangs in shared/gangs.lua
---@param newGangs table<string, Gang>
function CreateGangs(newGangs)
    for gangName, gang in pairs(newGangs) do
        gangs[gangName] = gang
        TriggerEvent('qbx_core:server:onGangUpdate', gangName, gang)
        TriggerClientEvent('qbx_core:client:onGangUpdate', -1, gangName, gang)
    end
end

exports('CreateGangs', CreateGangs)

-- Single Remove Gang
---@param gangName string
---@return boolean success
---@return string message
function RemoveGang(gangName)
    if type(gangName) ~= "string" then
        return false, "invalid_gang_name"
    end

    if not gangs[gangName] then
        return false, "gang_not_exists"
    end

    gangs[gangName] = nil

    TriggerEvent('qbx_core:server:onGangUpdate', gangName, nil)
    TriggerClientEvent('qbx_core:client:onGangUpdate', -1, gangName, nil)
    return true, "success"
end

exports('RemoveGang', RemoveGang)

---@return table<string, Job>
function GetJobs()
    return jobs
end

exports('GetJobs', GetJobs)

---@return table<string, Gang>
function GetGangs()
    return gangs
end

exports('GetGangs', GetGangs)

---@param name string
---@return Job?
function GetJob(name)
    return jobs[name]
end

---@param name string
---@return Gang?
function GetGang(name)
    return gangs[name]
end

lib.callback.register('qbx_core:server:getJobs', function()
    return jobs
end)

lib.callback.register('qbx_core:server:getGangs', function()
    return gangs
end)