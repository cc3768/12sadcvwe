local config = {}

config.URL = "ws://15.204.199.112:8080" -- change as needed
config.DEFAULT_ROOM = "#lobby"

config.LOG_LIMIT = 200
config.MAX_TEXT = 240

config.QUICK_ROOMS = { "#lobby", "#general", "#trade" }

config.SETTINGS_PATH = "/vcchat/settings.json"

return config
