fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pxd_voice'
description 'Próxima RP — voz: N habla, doble N grita, J susurra (sobre pma-voice)'
version '0.1.0'

dependency 'pma-voice'

shared_scripts {
    'config.lua',
    'shared/voice.lua',
}
client_script 'client/main.lua'
