fx_version 'cerulean'
game 'gta5'

name "lone_radio"
description "radio script by lone"
author "Lone"
version "1.0.0"

shared_scripts {
	'shared/*.lua'
}

client_scripts {
	'client/*.lua'
}

server_scripts {
	'server/*.lua'
}

ui_page 'html/ui.html'

files {
	'html/*',
	'html/imgs/*'
}


dependencies {
	'xsound'
  }
