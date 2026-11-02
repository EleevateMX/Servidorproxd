fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pxd_chat'
description 'Próxima RP — chat de rol por proximidad y tema propio del chat del sistema'
version '0.1.0'

-- Usa el chat del sistema de FiveM (recurso «chat»): su tema y su registerMessageHook.
dependency 'chat'

shared_scripts {
    'config.lua',
    'shared/chat.lua',
}
server_script 'server/main.lua'
client_script 'client/main.lua'

files {
    'html/ui/*.css',
    'html/chat.css',
}

-- Tema del chat (mismo mecanismo que cfx-server-data/resources/[gameplay]/chat-theme-example).
-- Los argumentos {0} y {1} los escapa el chat antes de insertarlos.
chat_theme 'proxima' {
    styleSheet = 'html/chat.css',
    msgTemplates = {
        default = '<div class="pm"><b class="pm__who">{0}</b><span class="pm__text">{1}</span></div>',
        defaultAlt = '<div class="pm pm--system"><span class="pm__text">{0}</span></div>',
        pxd_say = '<div class="pm pm--say"><b class="pm__who">{0}</b><span class="pm__text">{1}</span></div>',
        pxd_whisper = '<div class="pm pm--whisper"><b class="pm__who">{0} susurra</b><span class="pm__text">{1}</span></div>',
        pxd_shout = '<div class="pm pm--shout"><b class="pm__who">{0} grita</b><span class="pm__text">{1}</span></div>',
        pxd_me = '<div class="pm pm--me"><span class="pm__text"><b>{0}</b> {1}</span></div>',
        pxd_do = '<div class="pm pm--do"><span class="pm__text">{1}</span><b class="pm__who">{0}</b></div>',
        pxd_ooc = '<div class="pm pm--ooc"><b class="pm__who">OOC · {0}</b><span class="pm__text">{1}</span></div>',
        pxd_announce = '<div class="pm pm--announce"><b class="pm__who">{0}</b><span class="pm__text">{1}</span></div>',
        pxd_system = '<div class="pm pm--system"><span class="pm__text">{0}</span></div>',
    }
}
