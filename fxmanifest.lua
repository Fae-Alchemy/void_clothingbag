fx_version 'cerulean'
games { 'gta5' }

author 'Antigravity'
description 'Modular Clothing Bag system: use physical bag items to open pre-saved outfit wardrobes.'
version '1.0.0'

lua54 'yes'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client/cl_main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/sv_main.lua'
}

dependencies {
    'ox_lib',
    'void_bridge'
}
