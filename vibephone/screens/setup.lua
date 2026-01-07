-- /vibephone/screens/setup.lua
local ui = require("ui")
local store = require("data_store")
local net = require("net")

local M = {}

local function drawHeader(theme, data, blinkOn)
  local w,_ = term.getSize()
  local y = 1

  ui.fillRect(1, y, w, 1, theme.surface)

  local dot = blinkOn and "●" or "○"
  ui.writeAt(2, y, dot, theme.accent, theme.surface)
  ui.writeAt(4, y, "Setup", theme.text, theme.surface)

  local title = (data.profile and data.profile.name) or "VibePhone"
  local tx = math.floor((w - #title) / 2) + 1
  ui.writeAt(tx, y, title, theme.text, theme.surface)

  local num = data.number and ("#" .. tostring(data.number)) or "#----"
  ui.writeAt(w - #num - 1, y, num, theme.muted, theme.surface)
end

local function drawSetup(theme, data, stepTitle, stepBody, blinkOn)
  ui.drawWallpaper(theme, (data.ui and data.ui.wallpaper) or "border")

  local w,h = term.getSize()
  drawHeader(theme, data, blinkOn)

  local top = 3
  ui.writeAt(2, top, stepTitle or "Setup", theme.text, theme.bg)

  -- body box
  local boxY = top + 2
  local boxH = h - boxY - 3
  if boxH < 6 then boxH = 6 end

  ui.fillRect(2, boxY, w-2, boxH, theme.surface)
  ui.fillRect(3, boxY+1, w-4, boxH-2, theme.inner)

  local lines = {}
  for line in tostring(stepBody or ""):gmatch("[^\n]+") do
    lines[#lines+1] = line
  end

  local ty = boxY + 2
  for i=1, math.min(#lines, boxH-4) do
    ui.writeAt(4, ty+i-1, lines[i], theme.text, theme.inner)
  end

  ui.fillRect(1, h-1, w, 1, theme.bg)
  ui.center(h-1, "Enter=Continue  |  1=Reset", theme.muted, theme.bg)
end

function M.run(cfg, data)
  local tick = 0
  local blinkOn = true
  local timerId = os.startTimer(0.25)

  -- ensure modem open
  net.init(cfg)

  -- If already set up, skip
  if data.setupComplete and data.pinHash and data.number then
    return "lock"
  end

  -- Step 1: find server
  drawSetup(ui.getTheme(data), data, "Finding Server", "Searching for VibePhone Server...", blinkOn)
  local okFind, errFind = net.discoverServer(data, 3.0)
  if not okFind then
    drawSetup(ui.getTheme(data), data, "No Server", "Could not find server.\n\nCheck:\n- Server is running\n- Ender modem attached\n- Same protocol\n\nPress Enter to retry.", blinkOn)
    while true do
      local e,a = os.pullEvent()
      if e == "key" and a == keys.enter then return "setup" end
      if e == "char" and a == "1" then
        store.reset(data); store.save(cfg.dataFile, data)
        return "setup"
      end
    end
  end

  -- Step 2: register / get number
  local theme = ui.getTheme(data)
  drawSetup(theme, data, "Registering", "Requesting phone number from server...", blinkOn)

  -- deviceKey can be computer id + label; stable enough
  local deviceKey = tostring(os.getComputerID()) .. ":" .. tostring(os.getComputerLabel() or "phone")

  local ok, resp = net.request(data, {
    type = "vp_register",
    deviceKey = deviceKey,
  }, 4.0)

  if not ok or type(resp) ~= "table" or (resp.type ~= "vp_register_ok" and resp.type ~= "register_ok") then
    drawSetup(ui.getTheme(data), data, "Failed to Register",
      "Server did not accept registration.\n\nPress Enter to retry.\n(Or press 1 to reset.)", blinkOn)
    while true do
      local e,a = os.pullEvent()
      if e == "key" and a == keys.enter then return "setup" end
      if e == "char" and a == "1" then
        store.reset(data); store.save(cfg.dataFile, data)
        return "setup"
      end
    end
  end

  data.number = resp.number or data.number
  data.token = resp.token or data.token
  data.serverName = resp.serverName or data.serverName
  data.setupComplete = true
  store.save(cfg.dataFile, data)

  drawSetup(ui.getTheme(data), data, "Setup Complete!",
    "Your number: #" .. tostring(data.number) .. "\n\nNext:\nSet a PIN to secure your phone.\n\nPress Enter.", blinkOn)

  while true do
    local e,a = os.pullEvent()
    if e == "key" and a == keys.enter then
      return "settings" -- or "lock" if you set pin in setup; depends on your flow
    end
    if e == "char" and a == "1" then
      store.reset(data); store.save(cfg.dataFile, data)
      return "setup"
    end
    if e == "timer" and a == timerId then
      tick = tick + 1
      blinkOn = (tick % 2 == 0)
      timerId = os.startTimer(0.25)
      drawSetup(ui.getTheme(data), data, "Setup Complete!",
        "Your number: #" .. tostring(data.number) .. "\n\nNext:\nSet a PIN to secure your phone.\n\nPress Enter.", blinkOn)
    end
  end
end

return M
