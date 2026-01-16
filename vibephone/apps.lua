dofile("/vibephone/require_shim.lua")
-- App registry. Add apps here.
local apps = {
  vibechat = {
    id = "vibechat",
    name = "VibeChat",
    entry = "/vibephone/apps/vibechat/main.lua",
    accent = colors.cyan,
    glyph = "💬",
    multishell = true
  },
  appstore = {
    id = "appstore",
    name = "App Store",
    entry = "/vibephone/apps/appstore/app.lua",
    accent = colors.purple,
    glyph = "⬇",
    multishell = true
  },
  calculator = {
    id = "calculator",
    name = "Calc",
    entry = "/vibephone/apps/calculator/app.lua",
    accent = colors.orange,
    glyph = "∑",
    multishell = true
  },
  controller = {
    id = "controller",
    name = "Ctrl",
    entry = "/vibephone/apps/controller/app.lua",
    accent = colors.lime,
    glyph = "⚙",
    multishell = true
  }
}

return apps
