local ui = {}

local theme      = require("ui.theme")
local primitives = require("ui.primitives")
local wallpaper  = require("ui.wallpaper")
local frame      = require("ui.frame")
local widgets    = require("ui.widgets")
local input      = require("ui.input")

-- Merge modules onto ui table
for k,v in pairs(theme)      do ui[k]=v end
for k,v in pairs(primitives) do ui[k]=v end
for k,v in pairs(wallpaper)  do ui[k]=v end
for k,v in pairs(frame)      do ui[k]=v end
for k,v in pairs(widgets)    do ui[k]=v end
for k,v in pairs(input)      do ui[k]=v end

-- Backwards-compat aliases (old screens)
ui.fill     = ui.fillRect
ui.at       = ui.writeAt
ui.status   = ui.statusBar
ui.nav      = ui.navBar
ui.dots     = ui.pageDots

-- Extra compatibility shims
ui.drawBackground = function(theme)
  -- old/new screens may call this; just clear with wallpaper border or none
  ui.drawWallpaper(theme, "none")
end

ui.clear = function(theme)
  ui.drawWallpaper(theme, "none")
end

-- Layout helper (used by some screens)
ui.layout = function()
  local w,h = term.getSize()
  return {
    w = w,
    h = h,
    top = 5,     -- after status+header
    bottom = 3,  -- nav bar height
    pad = 2,
  }
end

return ui
