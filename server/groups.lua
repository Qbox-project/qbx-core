---@enum GroupType
GroupType = {
    JOB = 'job',
    GANG = 'gang'
}

---@type table<string, Job>
local jobs = require 'shared.jobs'

---@type table<string, Gang>
local gangs = require 'shared.gangs'

for name in pairs(jobs) do
    if name ~= name:lower() then
        lib.print.error(('jobs.lua contains a job name with capital letters: %s'):format(name))
    end
end

for name in pairs(gangs) do
    if name ~= name:lower() then
        lib.print.error(('gangs.lua contains a gang name with capital letters: %s'):format(name))
    end
end

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
    if type(jobName) ~= 'string' then
        return false, 'invalid_job_name'
    end

    if not jobs[jobName] then
        return false, 'job_not_exists'
    end

    jobs[jobName] = nil
    TriggerEvent('qbx_core:server:onJobUpdate', jobName, nil)
    TriggerClientEvent('qbx_core:client:onJobUpdate', -1, jobName, nil)

    return true, 'success'
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
    if type(gangName) ~= 'string' then
        return false, 'invalid_gang_name'
    end

    if not gangs[gangName] then
        return false, 'gang_not_exists'
    end

    gangs[gangName] = nil

    TriggerEvent('qbx_core:server:onGangUpdate', gangName, nil)
    TriggerClientEvent('qbx_core:client:onGangUpdate', -1, gangName, nil)

    return true, 'success'
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

exports('GetJob', GetJob)

---@param name string
---@return Gang?
function GetGang(name)
    return gangs[name]
end

exports('GetGang', GetGang)

---@param name string
---@param data JobData
local function upsertJobData(name, data)
    if jobs[name] then
        jobs[name].defaultDuty = data.defaultDuty
        jobs[name].label = data.label
        jobs[name].offDutyPay = data.offDutyPay
        jobs[name].type = data.type
    else
        jobs[name] = {
            defaultDuty = data.defaultDuty,
            label = data.label,
            offDutyPay = data.offDutyPay,
            type = data.type,
            grades = {},
        }
    end

    TriggerEvent('qbx_core:server:onJobUpdate', name, jobs[name])
    TriggerClientEvent('qbx_core:client:onJobUpdate', -1, name, jobs[name])
end

exports('UpsertJobData', upsertJobData)

---@param name string
---@param data GangData
local function upsertGangData(name, data)
    if gangs[name] then
        gangs[name].label = data.label
    else
        gangs[name] = {
            label = data.label,
            grades = {},
        }
    end

    TriggerEvent('qbx_core:server:onGangUpdate', name, gangs[name])
    TriggerClientEvent('qbx_core:client:onGangUpdate', -1, name, gangs[name])
end

exports('UpsertGangData', upsertGangData)

---@param name string
---@param grade integer
---@param data JobGradeData
local function upsertJobGrade(name, grade, data)
    if not jobs[name] then
        lib.print.error('Job must exist to edit grades. Not found:', name)
        return
    end

    jobs[name].grades[grade] = data
    TriggerEvent('qbx_core:server:onJobUpdate', name, jobs[name])
    TriggerClientEvent('qbx_core:client:onJobUpdate', -1, name, jobs[name])
end

exports('UpsertJobGrade', upsertJobGrade)

---@param name string
---@param grade integer
---@param data GangGradeData
local function upsertGangGrade(name, grade, data)
    if not gangs[name] then
        lib.print.error('Gang must exist to edit grades. Not found:', name)
        return
    end

    gangs[name].grades[grade] = data
    TriggerEvent('qbx_core:server:onGangUpdate', name, gangs[name])
    TriggerClientEvent('qbx_core:client:onGangUpdate', -1, name, gangs[name])
end

exports('UpsertGangGrade', upsertGangGrade)

---@param name string
---@param grade integer
local function removeJobGrade(name, grade)
    if not jobs[name] then
        lib.print.error('Job must exist to edit grades. Not found:', name)
        return
    end

    jobs[name].grades[grade] = nil
    TriggerEvent('qbx_core:server:onJobUpdate', name, jobs[name])
    TriggerClientEvent('qbx_core:client:onJobUpdate', -1, name, jobs[name])
end

exports('RemoveJobGrade', removeJobGrade)

---@param name string
---@param grade integer
local function removeGangGrade(name, grade)
    if not gangs[name] then
        lib.print.error('Gang must exist to edit grades. Not found:', name)
        return
    end

    gangs[name].grades[grade] = nil
    TriggerEvent('qbx_core:server:onGangUpdate', name, gangs[name])
    TriggerClientEvent('qbx_core:client:onGangUpdate', -1, name, gangs[name])
end

exports('RemoveGangGrade', removeGangGrade)
