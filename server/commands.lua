local config = require 'config.server'
local logger = require 'modules.logger'

GlobalState.PVPEnabled = config.server.pvp

lib.addCommand('tp', {
    help = locale('command.tp.help'),
    params = {
        { name = locale('command.tp.params.x.name'), help = locale('command.tp.params.x.help'), optional = false },
        { name = locale('command.tp.params.y.name'), help = locale('command.tp.params.y.help'), optional = true },
        { name = locale('command.tp.params.z.name'), help = locale('command.tp.params.z.help'), optional = true }
    },
    restricted = 'group.admin'
}, function(source, args)
    if args[locale('command.tp.params.x.name')] and not args[locale('command.tp.params.y.name')] and not args[locale('command.tp.params.z.name')] then
        local target = GetPlayerPed(tonumber(args[locale('command.tp.params.x.name')]) --[[@as number]])
        if target ~= 0 then
            local coords = GetEntityCoords(target)
            TriggerClientEvent('QBCore:Command:TeleportToPlayer', source, coords)
        else
            Notify(source, locale('error.not_online'), 'error')
        end
    else
        if args[locale('command.tp.params.x.name')] and args[locale('command.tp.params.y.name')] and args[locale('command.tp.params.z.name')] then
            local x = tonumber((args[locale('command.tp.params.x.name')]:gsub(',',''))) + .0
            local y = tonumber((args[locale('command.tp.params.y.name')]:gsub(',',''))) + .0
            local z = tonumber((args[locale('command.tp.params.z.name')]:gsub(',',''))) + .0
            if x ~= 0 and y ~= 0 and z ~= 0 then
                TriggerClientEvent('QBCore:Command:TeleportToCoords', source, x, y, z)
            else
                Notify(source, locale('error.wrong_format'), 'error')
            end
        else
            Notify(source, locale('error.missing_args'), 'error')
        end
    end
end)

lib.addCommand('tpm', {
    help = locale('command.tpm.help'),
    restricted = 'group.admin'
}, function(source)
    TriggerClientEvent('QBCore:Command:GoToMarker', source)
end)

lib.addCommand('togglepvp', {
    help = locale('command.togglepvp.help'),
    restricted = 'group.admin'
}, function()
    config.server.pvp = not config.server.pvp
    GlobalState.PVPEnabled = config.server.pvp
end)

lib.addCommand('addpermission', {
    help = locale('command.addpermission.help'),
    params = {
        { name = locale('command.addpermission.params.id.name'), help = locale('command.addpermission.params.id.help'), type = 'playerId' },
        { name = locale('command.addpermission.params.permission.name'), help = locale('command.addpermission.params.permission.help'), type = 'string' }
    },
    restricted = 'group.admin'
}, function(source, args)
    local player = GetPlayer(args[locale('command.addpermission.params.id.name')])
    local permission = args[locale('command.addpermission.params.permission.name')]
    if not player then
        Notify(source, locale('error.not_online'), 'error')
        return
    end

    ---@diagnostic disable-next-line: deprecated
    AddPermission(player.PlayerData.source, permission)
end)

lib.addCommand('removepermission', {
    help = locale('command.removepermission.help'),
    params = {
        { name = locale('command.removepermission.params.id.name'), help = locale('command.removepermission.params.id.help'), type = 'playerId' },
        { name = locale('command.removepermission.params.permission.name'), help = locale('command.removepermission.params.permission.help'), type = 'string' }
    },
    restricted = 'group.admin'
}, function(source, args)
    local player = GetPlayer(args[locale('command.removepermission.params.id.name')])
    local permission = args[locale('command.removepermission.params.permission.name')]
    if not player then
        Notify(source, locale('error.not_online'), 'error')
        return
    end

    ---@diagnostic disable-next-line: deprecated
    RemovePermission(player.PlayerData.source, permission)
end)

lib.addCommand('openserver', {
    help = locale('command.openserver.help'),
    restricted = 'group.admin'
}, function(source)
    if not config.server.closed then
        Notify(source, locale('error.server_already_open'), 'error')
        return
    end

    if IsPlayerAceAllowed(source, 'admin') then
        config.server.closed = false
        Notify(source, locale('success.server_opened'), 'success')
    else
        DropPlayer(source, locale('error.no_permission'))
    end
end)

lib.addCommand('closeserver', {
    help = locale('command.openserver.help'),
    params = {
        { name = locale('command.closeserver.params.reason.name'), help = locale('command.closeserver.params.reason.help'), type = 'string' }
    },
    restricted = 'group.admin'
}, function(source, args)
    if config.server.closed then
        Notify(source, locale('error.server_already_closed'), 'error')
        return
    end

    if IsPlayerAceAllowed(source, 'admin') then
        local reason = args[locale('command.closeserver.params.reason.name')] or 'No reason specified'
        config.server.closed = true
        config.server.closedReason = reason
        for k in pairs(QBX.Players) do
            if not IsPlayerAceAllowed(k --[[@as string]], config.server.whitelistPermission) then
                DropPlayer(k --[[@as string]], reason)
            end
        end

        Notify(source, locale('success.server_closed'), 'success')
    else
        DropPlayer(source, locale('error.no_permission'))
    end
end)

lib.addCommand('car', {
    help = locale('command.car.help'),
    params = {
        { name = locale('command.car.params.model.name'), help = locale('command.car.params.model.help') },
        { name = locale('command.car.params.keepCurrentVehicle.name'), help = locale('command.car.params.keepCurrentVehicle.help'), optional = true },
    },
    restricted = 'group.admin'
}, function(source, args)
    if not args then return end

    local ped = GetPlayerPed(source)
    local keepCurrentVehicle = args[locale('command.car.params.keepCurrentVehicle.name')]
    local currentVehicle = not keepCurrentVehicle and GetVehiclePedIsIn(ped, false)
    if currentVehicle and currentVehicle ~= 0 then
        DeleteVehicle(currentVehicle)
    end

    local _, vehicle = qbx.spawnVehicle({
        model = args[locale('command.car.params.model.name')],
        spawnSource = ped,
        warp = true,
    })

    local plate = qbx.getVehiclePlate(vehicle)
    config.giveVehicleKeys(source, plate, vehicle)
end)

lib.addCommand('dv', {
    help = locale('command.dv.help'),
    params = {
        { name = locale('command.dv.params.radius.name'), help = locale('command.dv.params.radius.help'), type = 'number', optional = true }
    },
    restricted = 'group.admin'
}, function(source, args)
    local ped = GetPlayerPed(source)
    local pedCars = {GetVehiclePedIsIn(ped, false)}
    local radius = args[locale('command.dv.params.radius.name')]
    if pedCars[1] == 0 or radius then -- Only execute when player is not in a vehicle or radius is explicitly defined
        pedCars = lib.callback.await('qbx_core:client:getVehiclesInRadius', source, radius)
    else
        pedCars[1] = NetworkGetNetworkIdFromEntity(pedCars[1])
    end

    if #pedCars ~= 0 then
        for i = 1, #pedCars do
            local pedCar = NetworkGetEntityFromNetworkId(pedCars[i])
            if pedCar and DoesEntityExist(pedCar) then
                DeleteVehicle(pedCar)
            end
        end
    end
end)

lib.addCommand('givemoney', {
    help = locale('command.givemoney.help'),
    params = {
        { name = locale('command.givemoney.params.id.name'), help = locale('command.givemoney.params.id.help'), type = 'playerId' },
        { name = locale('command.givemoney.params.moneytype.name'), help = locale('command.givemoney.params.moneytype.help'), type = 'string' },
        { name = locale('command.givemoney.params.amount.name'), help = locale('command.givemoney.params.amount.help'), type = 'number' }
    },
    restricted = 'group.admin'
}, function(source, args)
    local player = GetPlayer(args[locale('command.givemoney.params.id.name')])
    if not player then
        Notify(source, locale('error.not_online'), 'error')
        return
    end

    player.Functions.AddMoney(args[locale('command.givemoney.params.moneytype.name')], args[locale('command.givemoney.params.amount.name')])
end)

lib.addCommand('setmoney', {
    help = locale('command.setmoney.help'),
    params = {
        { name = locale('command.setmoney.params.id.name'), help = locale('command.setmoney.params.id.help'), type = 'playerId' },
        { name = locale('command.setmoney.params.moneytype.name'), help = locale('command.setmoney.params.moneytype.help'), type = 'string' },
        { name = locale('command.setmoney.params.amount.name'), help = locale('command.setmoney.params.amount.help'), type = 'number' }
    },
    restricted = 'group.admin'
}, function(source, args)
    local player = GetPlayer(args[locale('command.setmoney.params.id.name')])
    if not player then
        Notify(source, locale('error.not_online'), 'error')
        return
    end

    player.Functions.SetMoney(args[locale('command.setmoney.params.moneytype.name')], args[locale('command.setmoney.params.amount.name')])
end)

lib.addCommand('job', {
    help = locale('command.job.help')
}, function(source)
    local PlayerJob = GetPlayer(source).PlayerData.job
    Notify(source, locale('info.job_info', PlayerJob?.label, PlayerJob?.grade.name, PlayerJob?.onduty))
end)

lib.addCommand('setjob', {
    help = locale('command.setjob.help'),
    params = {
        { name = locale('command.setjob.params.id.name'), help = locale('command.setjob.params.id.help'), type = 'playerId' },
        { name = locale('command.setjob.params.job.name'), help = locale('command.setjob.params.job.help'), type = 'string' },
        { name = locale('command.setjob.params.grade.name'), help = locale('command.setjob.params.grade.help'), type = 'number', optional = true }
    },
    restricted = 'group.admin'
}, function(source, args)
    local player = GetPlayer(args[locale('command.setjob.params.id.name')])
    if not player then
        Notify(source, locale('error.not_online'), 'error')
        return
    end

    local success, errorResult = player.Functions.SetJob(args[locale('command.setjob.params.job.name')], args[locale('command.setjob.params.grade.name')] or 0)
    assert(success, json.encode(errorResult))
end)

lib.addCommand('changejob', {
    help = locale('command.changejob.help'),
    params = {
        { name = locale('command.changejob.params.id.name'), help = locale('command.changejob.params.id.help'), type = 'playerId' },
        { name = locale('command.changejob.params.job.name'), help = locale('command.changejob.params.job.help'), type = 'string' },
    },
    restricted = 'group.admin'
}, function(source, args)
    local player = GetPlayer(args[locale('command.changejob.params.id.name')])
    if not player then
        Notify(source, locale('error.not_online'), 'error')
        return
    end

    local success, errorResult = SetPlayerPrimaryJob(player.PlayerData.citizenid, args[locale('command.changejob.params.job.name')])
    assert(success, json.encode(errorResult))
end)

lib.addCommand('addjob', {
    help = locale('command.addjob.help'),
    params = {
        { name = locale('command.addjob.params.id.name'), help = locale('command.addjob.params.id.help'), type = 'playerId' },
        { name = locale('command.addjob.params.job.name'), help = locale('command.addjob.params.job.help'), type = 'string' },
        { name = locale('command.addjob.params.grade.name'), help = locale('command.addjob.params.grade.help'), type = 'number', optional = true}
    },
    restricted = 'group.admin'
}, function(source, args)
    local player = GetPlayer(args[locale('command.addjob.params.id.name')])
    if not player then
        Notify(source, locale('error.not_online'), 'error')
        return
    end

    local success, errorResult = AddPlayerToJob(player.PlayerData.citizenid, args[locale('command.addjob.params.job.name')], args[locale('command.addjob.params.grade.name')] or 0)
    assert(success, json.encode(errorResult))
end)

lib.addCommand('removejob', {
    help = locale('command.removejob.help'),
    params = {
        { name = locale('command.removejob.params.id.name'), help = locale('command.removejob.params.id.help'), type = 'playerId' },
        { name = locale('command.removejob.params.job.name'), help = locale('command.removejob.params.job.help'), type = 'string' }
    },
    restricted = 'group.admin'
}, function(source, args)
    local player = GetPlayer(args[locale('command.removejob.params.id.name')])
    if not player then
        Notify(source, locale('error.not_online'), 'error')
        return
    end

    local success, errorResult = RemovePlayerFromJob(player.PlayerData.citizenid, args[locale('command.removejob.params.job.name')])
    assert(success, json.encode(errorResult))
end)

lib.addCommand('gang', {
    help = locale('command.gang.help')
}, function(source)
    local PlayerGang = GetPlayer(source).PlayerData.gang
    Notify(source, locale('info.gang_info', PlayerGang?.label, PlayerGang?.grade.name))
end)

lib.addCommand('setgang', {
    help = locale('command.setgang.help'),
    params = {
        { name = locale('command.setgang.params.id.name'), help = locale('command.setgang.params.id.help'), type = 'playerId' },
        { name = locale('command.setgang.params.gang.name'), help = locale('command.setgang.params.gang.help'), type = 'string' },
        { name = locale('command.setgang.params.grade.name'), help = locale('command.setgang.params.grade.help'), type = 'number', optional = true }
    },
    restricted = 'group.admin'
}, function(source, args)
    local player = GetPlayer(args[locale('command.setgang.params.id.name')])
    if not player then
        Notify(source, locale('error.not_online'), 'error')
        return
    end

    local success, errorResult = player.Functions.SetGang(args[locale('command.setgang.params.gang.name')], args[locale('command.setgang.params.grade.name')] or 0)
    assert(success, json.encode(errorResult))
end)

lib.addCommand('ooc', {
    help = locale('command.ooc.help')
}, function(source, args)
    local message = table.concat(args, ' ')
    local players = GetPlayers()
    local player = GetPlayer(source)
    if not player then return end

    local playerCoords = GetEntityCoords(GetPlayerPed(source))
    for _, v in pairs(players) do
        if v == source then
            exports.chat:addMessage(v --[[@as Source]], {
                color = { 0, 0, 255},
                multiline = true,
                args = {('OOC | %s'):format(GetPlayerName(source)), message}
            })
        elseif #(playerCoords - GetEntityCoords(GetPlayerPed(v))) < 20.0 then
            exports.chat:addMessage(v --[[@as Source]], {
                color = { 0, 0, 255},
                multiline = true,
                args = {('OOC | %s'):format(GetPlayerName(source)), message}
            })
        elseif IsPlayerAceAllowed(v --[[@as string]], 'admin') then
            if IsOptin(v --[[@as Source]]) then
                exports.chat:addMessage(v--[[@as Source]], {
                    color = { 0, 0, 255},
                    multiline = true,
                    args = {('Proximity OOC | %s'):format(GetPlayerName(source)), message}
                })
                logger.log({
                    source = 'qbx_core',
                    webhook  = 'ooc',
                    event = 'OOC',
                    color = 'white',
                    tags = config.logging.role,
                    message = ('**%s** (CitizenID: %s | ID: %s) **Message:** %s'):format(GetPlayerName(source), player.PlayerData.citizenid, source, message)
                })
            end
        end
    end
end)

lib.addCommand('me', {
    help = locale('command.me.help'),
    params = {
        { name = locale('command.me.params.message.name'), help = locale('command.me.params.message.help'), type = 'string' }
    }
}, function(source, args)
    args[1] = args[locale('command.me.params.message.name')]
    args[locale('command.me.params.message.name')] = nil
    if #args < 1 then Notify(source, locale('error.missing_args2'), 'error') return end

    local msg = table.concat(args, ' '):gsub('[~<].-[>~]', '')
    local playerState = Player(source).state
    playerState:set('me', msg, true)

    -- We have to reset the playerState since the state does not get replicated on StateBagHandler if the value is the same as the previous one --
    playerState:set('me', nil, true)
end)

lib.addCommand('id', {help = locale('info.check_id')}, function(source)
    Notify(source, 'ID: ' .. source)
end)

lib.addCommand('logout', {
    help = locale('info.logout_command_help'),
    restricted = 'group.admin',
}, Logout)

lib.addCommand('deletechar', {
    help = locale('info.deletechar_command_help'),
    restricted = 'group.admin',
    params = {
        { name = 'id', help = locale('info.deletechar_command_arg_player_id'), type = 'number' },
    }
}, function(source, args)
    local player = GetPlayer(args.id)
    if not player then return end

    local citizenId = player.PlayerData.citizenid
    ForceDeleteCharacter(citizenId)
    Notify(source, locale('success.character_deleted_citizenid', citizenId))
end)