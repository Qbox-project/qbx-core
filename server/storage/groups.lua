local function createGroupsTable()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `groups` (
            `name` varchar(255) NOT NULL UNIQUE,
            `type` varchar(10) NOT NULL,
            `label` varchar(255) NOT NULL,
            `defaultDuty` tinyint(1) DEFAULT 1,
            `offDutyPay` tinyint(1) DEFAULT 0,
            `grades` LONGTEXT DEFAULT NULL,
            PRIMARY KEY (`name`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]])
end

---Update / insert group data
---@param name string
---@param groupType GroupType
---@param data Job|Gang
local function updateGroup(name, groupType, data)
    if data.grades and table.type(data.grades) == 'hash' then
        local _grades = {}
        for k, v in pairs(data.grades) do
            if not tonumber(k) then goto skip end
            _grades[tonumber(k)] = v
            ::skip::
        end
        data.grades = _grades
    end
    MySQL.query([[
        INSERT INTO `groups` (name, type, label, defaultDuty, offDutyPay, grades)
            VALUES (@name, @type, @label, @defaultDuty, @offDutyPay, @grades)
        ON DUPLICATE KEY UPDATE
            `type` = @type, `label` = @label, `defaultDuty` = @defaultDuty, `offDutyPay` = @offDutyPay, `grades` = @grades
    ]], {
        name = name,
        type = groupType,
        label = data.label,
        defaultDuty = data.defaultDuty,
        offDutyPay = data.offDutyPay,
        grades = data.grades and json.encode(data.grades),
    })
end

local function convertGrades(gangJson)
    local _grades = json.decode(gangJson)
    local grades = {}
    for k, v in pairs(_grades) do
        grades[tonumber(("%d"):format(k))] = v
    end
    return grades
end

---Fetch job data
---@return table<string, Job>
local function fetchJobs()
    local results = MySQL.query.await("SELECT * FROM `groups` WHERE `type` = 'job'")
    local jobData = {}

    for i = 1, #results do
        jobData[results[i].name] = {
            label = results[i].label,
            type = results[i].type,
            defaultDuty = results[i].defaultDuty == 1,
            offDutyPay = results[i].offDutyPay == 1,
            grades = results[i].grades and convertGrades(results[i].grades) or {},
        }
    end

    return jobData
end

---Fetch gang data
---@return table<string, Gang>
local function fetchGangs()
    local results = MySQL.query.await("SELECT * FROM `groups` WHERE `type` = 'gang'")
    local gangData = {}

    for i = 1, #results do
        gangData[results[i].name] = {
            label = results[i].label,
            grades = results[i].grades and convertGrades(results[i].grades) or {},
        }
    end

    return gangData
end

return {
    createGroupsTable = createGroupsTable,
    updateGroup = updateGroup,
    fetchJobs = fetchJobs,
    fetchGangs = fetchGangs,
}
