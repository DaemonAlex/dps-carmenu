fx_version 'cerulean'
game 'gta5'

description 'dps-carmenu - admin vehicle browser/spawner over the live registry'
author 'DPS'

shared_scripts {
    '@ox_lib/init.lua',
    '@qbx_core/modules/lib.lua',
}
client_script 'client.lua'
server_script 'server.lua'

dependencies { 'ox_lib', 'qbx_core' }
