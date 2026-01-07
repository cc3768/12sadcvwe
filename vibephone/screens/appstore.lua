local ui = require("ui")

local M = {}

local function requirePinIfEnabled(theme, data)
  if not (data.lock and data.lock.requirePinForStore) then return true end

  local pin, reset = ui.pinPad(theme, "App Store", "PIN required")
  if reset then return false end
  return ui.djb2(pin or "") == data.pinHash
end

function M.run(cfg, data, net)
  local theme = ui.getTheme(data)

  if not requirePinIfEnabled(theme, data) then
    ui.drawWallpaper(theme, data.ui.wallpaper or "dots")
    ui.statusBar(theme, "App Store", textutils.formatTime(os.time(), true))
    ui.center(10, "Wrong PIN", theme.bad)
    sleep(0.8)
    return
  end

  local ok, res = net.request(data, { type="apps_list" }, 3.0)
  if not ok or type(res) ~= "table" or res.type ~= "apps_list_ok" then
    ui.drawWallpaper(theme, data.ui.wallpaper or "dots")
    ui.statusBar(theme, "App Store", "Q=Back")
    ui.center(8, "Failed to load apps", theme.bad)
    ui.center(10, tostring(type(res)=="table" and (res.message or "Unknown") or res), theme.muted)
    os.pullEvent("key")
    return
  end

  local apps = res.apps or {}
  local idx = 1

  while true do
    theme = ui.getTheme(data)
    ui.drawWallpaper(theme, data.ui.wallpaper or "dots")
    ui.statusBar(theme, "App Store", "Q=Back")

    ui.center(3, "Tap Up/Down • Enter = (next step installs)", theme.muted)

    local y = 5
    for i,a in ipairs(apps) do
      local isSel = (i == idx)
      local accent = isSel and theme.accent or theme.bg2
      ui.card(2,y, (select(1,term.getSize())-2), 4, theme, a.name .. "  ("..a.version..")", a.desc, accent)
      y = y + 5
      if y > (select(2,term.getSize())-3) then break end
    end

    local e,k = os.pullEvent("key")
    if k == keys.q then return end
    if k == keys.up then idx = math.max(1, idx-1) end
    if k == keys.down then idx = math.min(#apps, idx+1) end
  end
end

return M
