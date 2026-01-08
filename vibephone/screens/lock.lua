-- /vibephone/screens/lock.lua
local ui = require("ui")
local store = require("data_store")

local M = {}

local function nowMs()
  if os.epoch then return os.epoch("utc") end
  return math.floor(os.time() * 1000)
end

local function drawHeader(theme, data, blinkOn)
  local w,_ = term.getSize()
  local y = 1

  ui.fillRect(1, y, w, 1, theme.surface)

  local dot = blinkOn and "●" or "○"
  ui.writeAt(2, y, dot, theme.muted, theme.surface)
  ui.writeAt(4, y, "Locked", theme.text, theme.surface)

  local title = (data.profile and data.profile.name) or "VibePhone"
  local tx = math.floor((w - #title) / 2) + 1
  ui.writeAt(tx, y, title, theme.text, theme.surface)

  local num = data.number and ("#" .. tostring(data.number)) or "#----"
  ui.writeAt(w - #num - 1, y, num, theme.muted, theme.surface)
end

local function drawKey(theme, x, y, w, h, label, kind, pressed)
  local bg = theme.surface
  local fg = theme.text

  if kind == "sub" then
    bg = theme.accent
    fg = colors.black
  elseif kind == "del" then
    bg = theme.line
    fg = theme.text
  end

  if pressed then
    bg = theme.inner
    fg = theme.accent
  end

  ui.fillRect(x, y, w, h, bg)

  if #label > w then label = label:sub(1, w) end
  local tx = x + math.max(0, math.floor((w - #label) / 2))
  local ty = y + math.floor((h - 1) / 2)
  ui.writeAt(tx, ty, label, fg, bg)
end

local function drawLock(theme, data, pin, errMsg, pressedId, blinkOn)
  ui.drawWallpaper(theme, (data.ui and data.ui.wallpaper) or "border")

  local w,h = term.getSize()

  drawHeader(theme, data, blinkOn)

  ui.fillRect(1, 2, w, 1, theme.bg)

  local textTop = 3
  ui.center(textTop,     "Enter PIN", theme.text, theme.bg)
  ui.center(textTop + 1, "Tap digits or type", theme.muted, theme.bg)

  local masked = (#pin > 0) and string.rep("*", #pin) or " "
  ui.center(textTop + 3, masked, theme.text, theme.bg)

  if errMsg then
    ui.center(textTop + 4, errMsg, theme.bad, theme.bg)
  end

  local keyH = 2
  local rowGap = 1
  local colGap = (w <= 26) and 1 or 2

  local bw = math.floor((w - 2 - colGap * 2) / 3)
  if bw < 6 then bw = 6 end
  if bw > 10 then bw = 10 end

  local keypadW = bw * 3 + colGap * 2
  local keypadH = keyH * 4 + rowGap * 3

  local footerY = h - 1
  local keypadY = footerY - keypadH - 1
  local minKeypadY = textTop + 6
  if keypadY < minKeypadY then keypadY = minKeypadY end

  local keypadX = math.floor((w - keypadW) / 2) + 1

  local grid = {
    {"1","2","3"},
    {"4","5","6"},
    {"7","8","9"},
    {"DEL","0","SUB"},
  }

  local buttons = {}
  for r = 1, 4 do
    for c = 1, 3 do
      local label = grid[r][c]
      local x = keypadX + (c - 1) * (bw + colGap)
      local y = keypadY + (r - 1) * (keyH + rowGap)

      local kind = "num"
      if label == "DEL" then kind = "del" end
      if label == "SUB" then kind = "sub" end

      drawKey(theme, x, y, bw, keyH, label, kind, pressedId == label)
      buttons[#buttons + 1] = { id = label, x = x, y = y, w = bw, h = keyH }
    end
  end

  ui.fillRect(1, footerY, w, 1, theme.bg)
  ui.center(footerY, "SUB unlock | Backspace delete", theme.muted, theme.bg)

  return buttons
end

function M.run(cfg, data)
  if not data.pinHash then
    return "setup"
  end

  data.lock = data.lock or {}
  data.lock.failedAttempts = data.lock.failedAttempts or 0
  data.lock.lockedUntil = data.lock.lockedUntil or 0

  local pin = ""
  local errMsg = nil
  local pressedId = nil

  local tick = 0
  local blinkOn = true
  local timerId = os.startTimer(0.25)

  while true do
    local theme = ui.getTheme(data)

    local ms = nowMs()
    if data.lock.lockedUntil and ms < data.lock.lockedUntil then
      drawLock(theme, data, "", "Too many tries. Wait...", nil, blinkOn)
      os.sleep(1)
    end

    local buttons = drawLock(theme, data, pin, errMsg, pressedId, blinkOn)
    pressedId = nil

    local e,a,b,c = os.pullEvent()

    if e == "timer" and a == timerId then
      tick = tick + 1
      blinkOn = (tick % 2 == 0)
      timerId = os.startTimer(0.25)

    elseif e == "char" then

      if a:match("%d") then
        if #pin < 12 then pin = pin .. a end
        errMsg = nil
      end

    elseif e == "key" then

      if a == keys.backspace then
        pin = pin:sub(1, -2)
        errMsg = nil

      elseif a == keys.enter then
        local hash = ui.djb2(pin)
        if hash == tostring(data.pinHash) then
          data.lock.failedAttempts = 0
          store.save(cfg.dataFile, data)
          return "home"
        else
          data.lock.failedAttempts = (data.lock.failedAttempts or 0) + 1
          errMsg = "Wrong PIN"
          if data.lock.failedAttempts >= 5 then
            data.lock.lockedUntil = nowMs() + 10000
            data.lock.failedAttempts = 0
          end
          store.save(cfg.dataFile, data)
          pin = ""
        end
      end

    elseif e == "mouse_click" then
      local mx,my = b,c
      for _,bt in ipairs(buttons) do
        if ui.hit(mx,my, bt.x,bt.y,bt.w,bt.h) then
          pressedId = bt.id

          if bt.id == "DEL" then
            pin = pin:sub(1, -2)
            errMsg = nil

          elseif bt.id == "SUB" then
            local hash = ui.djb2(pin)
            if hash == tostring(data.pinHash) then
              data.lock.failedAttempts = 0
              store.save(cfg.dataFile, data)
              return "home"
            else
              data.lock.failedAttempts = (data.lock.failedAttempts or 0) + 1
              errMsg = "Wrong PIN"
              if data.lock.failedAttempts >= 5 then
                data.lock.lockedUntil = nowMs() + 10000
                data.lock.failedAttempts = 0
              end
              store.save(cfg.dataFile, data)
              pin = ""
            end

          else
            if #pin < 12 then pin = pin .. bt.id end
            errMsg = nil
          end
          break
        end
      end
    end
  end
end

return M
