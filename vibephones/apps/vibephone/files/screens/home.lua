dofile("/vibephone/require_shim.lua")
local config = require("config")
local ui = require("ui")
local apps = require("apps")

local home = {}

local function orderedAppIds(state)
  local out, seen = {}, {}
  for _,id in ipairs(state.apps.order or {}) do
    if apps[id] then out[#out+1]=id; seen[id]=true end
  end
  for id,_ in pairs(apps) do
    if not seen[id] then out[#out+1]=id end
  end
  table.sort(out)
  return out
end

function home.draw(state)
  ui.clearButtons()
  local w,h = term.getSize()
  ui.fill(config.C_BG)

  ui.statusBar(state.settings.deviceName or "VibePhone", os.date("%H:%M"))

  ui.text(2,2,"Home",config.C_MUTED,config.C_BG)
  local sTxt = "Settings"
  ui.text(w-#sTxt-1,2,sTxt,config.C_ACCENT,config.C_BG)
  ui.addButton("open_settings", w-#sTxt-1,2,#sTxt,1)

  ui.divider(3, config.C_MUTED, config.C_BG)

  local ids = orderedAppIds(state)
  local cols = config.GRID_COLS
  local iconW, iconH = config.ICON_W, config.ICON_H
  local gapX, gapY = 2, 1

  local totalW = cols*iconW + (cols-1)*gapX
  local startX = math.max(1, math.floor((w-totalW)/2) + 1)
  local startY = config.GRID_TOP

  for i,id in ipairs(ids) do
    local col = ((i-1) % cols)
    local row = math.floor((i-1) / cols)
    local x = startX + col*(iconW+gapX)
    local y = startY + row*(iconH+gapY)
    if y + iconH <= h-3 then
      local a = apps[id].accent or config.C_ACCENT
      ui.iconTile("app_"..id, x, y, iconW, iconH, apps[id].name, apps[id].glyph, a)
    end
  end

  ui.dock(h-1)
  local status = tostring(state.status or "Ready.")
  if #status > w-2 then status = status:sub(1, w-2) end
  ui.text(2,h-1,status,colors.black,config.C_SURFACE_2)
end

function home.handleTap(state, id)
  if id == "open_settings" then return { action="settings" } end
  if id and id:match("^app_") then
    local appId = id:sub(5)
    if apps[appId] then return { action="launch", appId=appId } end
  end
  return nil
end

return home
