---@return table<string, Job>
function GetJobs()
    return lib.callback.await('qbx_core:server:getJobs')
end

exports('GetJobs', GetJobs)

---@return table<string, Gang>
function GetGangs()
    return lib.callback.await('qbx_core:server:getGangs')
end

exports('GetGangs', GetGangs)

---@param name string
---@return Job?
function GetJob(name)
    local jobs = lib.callback.await('qbx_core:server:getJobs')
    return jobs[name]
end

exports('GetJob', GetJob)

---@param name string
---@return Gang?
function GetGang(name)
    local gangs = lib.callback.await('qbx_core:server:getGangs')
    return gangs[name]
end

exports('GetGang', GetGang)
