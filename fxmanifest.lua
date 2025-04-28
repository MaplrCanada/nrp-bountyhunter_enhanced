fx_version 'cerulean'
game 'gta5'

description 'SyntaxScripts - Bounty Hunter'
author 'SyntaxScripts'
version '1.0.0'

ui_page 'html/index.html'

shared_scripts {
    '@qb-core/shared/locale.lua',
    'config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    'server/main.lua'
}

files {
    'html/index.html',
    'html/app.js',
    'html/style.css'
}

lua54 'yes'