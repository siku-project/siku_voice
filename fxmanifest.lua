fx_version 'cerulean'
game 'gta5'

author 'Siku Studio'
description 'A modern, high-performance voice system for the SIKU ecosystem — providing proximity voice, communication channels, calls, radio integration, audio effects, and a clean API for immersive FiveM roleplay experiences. Built for reliability, extensibility, and seamless integration across SIKU resources.'
version '1.1.0'

name 'siku_voice'

lua54 'yes'

shared_scripts {
  '@siku_core/init.lua',
  'config/translation.lua',
  'config/voice.lua',
  'shared/modules/modes.lua',
}

server_scripts {
  'server/init.lua',
  'server/modules/channels.lua',
  'server/modules/audio.lua',
  'server/modules/endpoint.lua',
  'server/modules/mute.lua',
  'server/modules/grants.lua',
  'server/modules/lifecycle.lua',
  'server/modules/api.lua',
}

client_scripts {
  'client/modules/support.lua',
  'client/modules/mumble.lua',
  'client/modules/endpoint.lua',
  'client/modules/effects.lua',
  'client/modules/rendering.lua',
  'client/modules/routing.lua',
  'client/modules/restrictions.lua',
  'client/modules/proximity.lua',
  'client/modules/listening.lua',
  'client/modules/scan.lua',
  'client/modules/indicator.lua',
  'client/modules/session.lua',
  'client/modules/talk.lua',
  'client/modules/keybinds.lua',
  'client/modules/api.lua',
}

files {
  'translations/*.lua',
}

dependencies {
  '/onesync',
  'siku_core',
}
