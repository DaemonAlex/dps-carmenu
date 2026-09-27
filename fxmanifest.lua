fx_version 'cerulean'
game 'gta5'
lua54 'yes'

description 'dps-carmenu - DPS fleet browser: search, info, spawn and copy cards over the live registry'
author 'DPS'
version '3.0.0'

shared_scripts {
    '@ox_lib/init.lua',
    '@qbx_core/modules/lib.lua',
    'shared/fields.lua',
    'shared/groups.lua',
    'shared/search.lua',
}
client_script 'client.lua'
server_script 'server.lua'

ui_page 'html/index.html'
files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
}

dependencies { 'ox_lib', 'qbx_core' }
