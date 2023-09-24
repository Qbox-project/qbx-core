fx_version 'cerulean'
game 'gta5'

description 'QBX-Core'
version '1.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/locale.lua',
    'locale/en.lua',
    'locale/*.lua',
    'import.lua'
}

client_scripts {
    'client/main.lua',
    'client/loops.lua',
    'client/events.lua',
    'client/character.lua',
    'bridge/qb/client/drawtext.lua',
    'bridge/qb/client/events.lua',
    'bridge/qb/client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/events.lua',
    'server/commands.lua',
    'server/loops.lua',
    'server/storage.lua',
    'server/character.lua',
    'bridge/qb/server/commands.lua',
    'bridge/qb/server/debug.lua',
    'bridge/qb/server/main.lua',
}

modules {
    'utils'
}

files {
    'modules/*.lua',
    'config.lua',
    'shared/gangs.lua',
    'shared/items.lua',
    'shared/jobs.lua',
    'shared/locations.lua',
    'shared/main.lua',
    'shared/vehicles.lua',
    'shared/weapons.lua',
    'server/functions.lua',
    'server/player.lua',
    'client/functions.lua',
    'bridge/qb/client/functions.lua',
    'bridge/qb/shared/main.lua',
    'bridge/qb/server/functions.lua',
    'bridge/qb/server/main.lua',
    'bridge/qb/server/player.lua',
}

dependency 'oxmysql'
provide 'qb-core'
lua54 'yes'
use_experimental_fxv2_oal 'yes'
