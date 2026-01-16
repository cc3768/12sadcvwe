local config = {}

config.STATE_PATH = "/vibephone/phone_state.json"

-- Home grid
config.GRID_COLS = 3
config.ICON_W = 9
config.ICON_H = 5
config.GRID_TOP = 4

-- Lock
config.PIN_LENGTH = 4

-- Animation
config.ANIM_ENABLED = true
config.ANIM_FPS = 12
config.ANIM_SECONDS = 1.8

-- AppStore (same server as chat)
config.APPSTORE_WS_URL = "ws://192.168.5.2:8080"

-- Theme colors
config.C_BG = colors.black
config.C_SURFACE = colors.gray
config.C_SURFACE_2 = colors.lightGray
config.C_TEXT = colors.white
config.C_MUTED = colors.lightGray
config.C_ACCENT = colors.cyan
config.C_OK = colors.lime
config.C_BAD = colors.red

return config
