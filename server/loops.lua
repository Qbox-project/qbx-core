local config = require 'config.server'
local storage = require 'server.storage.main'

local function removeHungerAndThirst(src, player)
    local playerState = Player(src).state
    if not playerState.isLoggedIn then return end

    local newHunger = playerState.hunger - config.player.hungerRate
    local newThirst = playerState.thirst - config.player.thirstRate

    player.Functions.SetMetaData('thirst', math.max(0, newThirst))
    player.Functions.SetMetaData('hunger', math.max(0, newHunger))
end

local function pay(player)
    local job = player.PlayerData.job
    local payment = GetJob(job.name).grades[job.grade.level].payment or job.payment
    if payment <= 0 then return end

    if not GetJob(job.name).offDutyPay and not job.onduty then return end

    if not config.money.paycheckSociety then
        config.sendPaycheck(player, payment)
        return
    end

    local account = config.getSocietyAccount(job.name)
    if not account then -- Checks if player is employed by a society
        config.sendPaycheck(player, payment)
        return
    end

    if account < payment then -- Checks if company has enough money to pay society
        Notify(player.PlayerData.source, locale('error.company_too_poor'), 'error')
        return
    end

    config.removeSocietyMoney(job.name, payment)
    config.sendPaycheck(player, payment)
end

CreateThread(function()
    local interval = 60000 * config.updateInterval
    while true do
        Wait(interval)
        for src, player in pairs(QBX.Players) do
            removeHungerAndThirst(src, player)
        end
    end
end)

CreateThread(function()
    local interval = 1000 * config.dbUpdateInterval
    while true do
        Wait(interval)
        storage.sendPlayerDataUpdates()
    end
end)

CreateThread(function()
    local interval = 60000 * config.money.paycheckTimeout
    while true do
        Wait(interval)
        for _, player in pairs(QBX.Players) do
            pay(player)
        end
    end
end)
