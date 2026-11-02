fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pxd_jobs'
description 'Próxima RP — trabajos legales propios (minero, leñador, pescador, repartidor)'
version '0.1.0'

shared_scripts {
    'config.lua',
    'shared/jobs.lua',
}

server_script 'server/main.lua'
client_script 'client/main.lua'
