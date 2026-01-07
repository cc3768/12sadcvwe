-- /vibephone/config.lua
-- VibePhone (Pocket) configuration

local cfg = {}

-- ===== Storage (IMPORTANT) =====
-- Absolute path so your data persists no matter where you launch from.
cfg.dataFile = "/vibephone/data.json"
dataFile = "/vibephone/data.json"
-- Optional: unique device id. If nil, main.lua can generate one.
cfg.deviceId = nil

-- ===== Network =====
-- Pocket modem is on the BACK of the pocket computer.
cfg.modemSide = "back"

-- Rednet protocol names (keep these stable)
cfg.rednet = {
  protocol = "vibephone",
  serverProtocol = "vibephone_srv",
  heartbeat_interval = 3,
  request_timeout = 2.5,
}

-- Server discovery:
-- Your "middleman" advanced computer should have an Ender Modem attached.
-- We will find it with peripheral.find on the phone side (or use rednet lookup).
cfg.server = {
  -- Optional fixed ID (if you want). If nil, we'll discover.
  id = nil,

  -- Optional label to match (if you label the server computer).
  label = "VibePhone Server",

  -- Discovery behavior
  discover_timeout = 2.0,   -- seconds to wait for server response during discovery
  retry_interval = 3.0,     -- seconds between reconnect attempts
}

-- ===== UI Defaults =====
cfg.ui = {
  -- Default theme key (must exist in themes.lua)
  theme = "neon",

  -- Default wallpaper style: border | none | dots | stripes | grid
  wallpaper = "border",

  -- Default accent color (can be overridden by saved data)
  accent = colors.lime,
}

-- ===== Security Defaults =====
cfg.security = {
  -- If true, App Store requires PIN even when phone is unlocked.
  requirePinForStore = true,

  -- Max PIN length accepted
  pinMaxLen = 12,
}

-- ===== SMS Defaults =====
cfg.sms = {
  poll_interval = 2.5,   -- seconds between inbox fetches
  max_body_len = 120,
  max_threads = 200,
  max_messages_per_thread = 200,
}

return cfg
