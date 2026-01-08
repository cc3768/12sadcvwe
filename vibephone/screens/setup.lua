-- /vibephone/screens/setup.lua
local ui = require("ui")
local store = require("data_store")
local net = require("net")

local M = {}

-- Always save/load the same file as main: "data.json" in the program folder.
-- data_store.lua normalizes relative paths to the running program's folder (with the updated version I gave you).
local SAVE_PATH = "data.json"

local function saveData(cfg, data)
  -- Do NOT use cfg.dataFile here (it is what caused the mismatch).
  store.save(SAVE_PATH, data)
end

local function drawHeader(theme, data, blinkOn, leftLabel)
  local w,_ = term.getSize()
  local y = 1

  ui.fillRect(1, y, w, 1, theme.surface)

  local dot = blinkOn and "●" or "○"
  ui.writeAt(2, y, dot, theme.accent, theme.surface)
  ui.writeAt(4, y, leftLabel or "Setup", theme.text, theme.surface)

  local title = (data.profile and data.profile.name) or "VibePhone"
  local tx = math.floor((w - #title) / 2) + 1
  ui.writeAt(tx, y, title, theme.text, theme.surface)

  local num = data.number and ("#" .. tostring(data.number)) or "#----"
  ui.writeAt(w - #num - 1, y, num, theme.muted, theme.surface)
end

local function drawBox(theme, topTitle, bodyLines, footer)
  local w,h = term.getSize()

  ui.fillRect(1, 2, w, 1, theme.bg)

  local top = 3
  ui.writeAt(2, top, topTitle or "", theme.text, theme.bg)

  local boxY = top + 2
  local boxH = h - boxY - 2
  if boxH < 6 then boxH = 6 end

  ui.fillRect(2, boxY, w-2, boxH, theme.line)
  ui.fillRect(3, boxY+1, w-4, boxH-2, theme.surface)

  local ty = boxY + 2
  for i=1, math.min(#bodyLines, boxH-4) do
    ui.writeAt(4, ty+i-1, bodyLines[i], theme.text, theme.surface)
  end

  ui.fillRect(1, h-1, w, 1, theme.bg)
  ui.center(h-1, footer or "Enter=Continue | 1=Reset", theme.muted, theme.bg)
end

local function keypadLayout()
  local w,h = term.getSize()

  local keyH = 2
  local rowGap = 1
  local colGap = (w <= 26) and 1 or 2

  local bw = math.floor((w - 2 - colGap * 2) / 3)
  if bw < 6 then bw = 6 end
  if bw > 10 then bw = 10 end

  local keypadW = bw*3 + colGap*2
  local keypadH = keyH*4 + rowGap*3
  local keypadX = math.floor((w - keypadW)/2) + 1

  local footerY = h - 1
  local keypadY = footerY - keypadH - 1
  if keypadY < 8 then keypadY = 8 end

  return bw, keyH, colGap, rowGap, keypadX, keypadY, footerY
end

local function drawKey(theme, x, y, w, h, label, kind, pressed)
  local bg = theme.surface
  local fg = theme.text

  if kind == "ok" then
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
  if #label > w then label = label:sub(1,w) end
  local tx = x + math.floor((w-#label)/2)
  local ty = y + math.floor((h-1)/2)
  ui.writeAt(tx, ty, label, fg, bg)
end

local function runCreatePin(cfg, data)
  local pin = ""
  local confirm = ""
  local stage = 1 -- 1=enter, 2=confirm
  local errMsg = nil
  local pressedId = nil

  local tick = 0
  local blinkOn = true
  local timerId = os.startTimer(0.25)

  while true do
    local theme = ui.getTheme(data)
    ui.drawWallpaper(theme, (data.ui and data.ui.wallpaper) or "border")
    drawHeader(theme, data, blinkOn, "Setup")

    local w,h = term.getSize()
    ui.fillRect(1, 2, w, 1, theme.bg)

    local title = (stage == 1) and "Create a PIN" or "Confirm PIN"
    ui.center(3, title, theme.text, theme.bg)
    ui.center(4, "Tap digits or type", theme.muted, theme.bg)

    local shown = (stage == 1) and pin or confirm
    local masked = (#shown > 0) and string.rep("*", #shown) or " "
    ui.center(6, masked, theme.text, theme.bg)

    if errMsg then ui.center(7, errMsg, theme.bad, theme.bg) end

    local bw, keyH, colGap, rowGap, x0, y0, footerY = keypadLayout()

    local grid = {
      {"1","2","3"},
      {"4","5","6"},
      {"7","8","9"},
      {"DEL","0","OK"},
    }

    local buttons = {}
    for r=1,4 do
      for c=1,3 do
        local label = grid[r][c]
        local x = x0 + (c-1)*(bw+colGap)
        local y = y0 + (r-1)*(keyH+rowGap)

        local kind = "num"
        if label == "DEL" then kind = "del" end
        if label == "OK" then kind = "ok" end

        drawKey(theme, x, y, bw, keyH, label, kind, pressedId == label)
        buttons[#buttons+1] = {id=label, x=x, y=y, w=bw, h=keyH}
      end
    end
    pressedId = nil

    ui.fillRect(1, footerY, w, 1, theme.bg)
    ui.center(footerY, "OK=Next | Backspace=Del | 1=Reset", theme.muted, theme.bg)

    local e,a,b,c = os.pullEvent()

    if e == "timer" and a == timerId then
      tick = tick + 1
      blinkOn = (tick % 2 == 0)
      timerId = os.startTimer(0.25)

    elseif e == "char" then
      if a == "1" then
        store.reset(data)
        saveData(cfg, data)
        return false, "reset"
      end
      if a:match("%d") then
        if stage == 1 then
          if #pin < 12 then pin = pin .. a end
        else
          if #confirm < 12 then confirm = confirm .. a end
        end
        errMsg = nil
      end

    elseif e == "key" then
      if a == keys.one then
        store.reset(data)
        saveData(cfg, data)
        return false, "reset"
      end

      if a == keys.backspace then
        if stage == 1 then pin = pin:sub(1,-2) else confirm = confirm:sub(1,-2) end
        errMsg = nil
      elseif a == keys.enter then
        if stage == 1 then
          if #pin < 4 then
            errMsg = "PIN must be 4+ digits"
          else
            stage = 2
            confirm = ""
            errMsg = nil
          end
        else
          if confirm ~= pin then
            errMsg = "PIN does not match"
            stage = 1
            pin = ""
            confirm = ""
          else
            -- ✅ Persist pinHash using the same key main checks for
            data.pinHash = tostring(ui.djb2(pin))
            data.setupComplete = true
            saveData(cfg, data)
            return true
          end
        end
      end

    elseif e == "mouse_click" then
      local mx,my = b,c
      for _,bt in ipairs(buttons) do
        if ui.hit(mx,my, bt.x,bt.y,bt.w,bt.h) then
          pressedId = bt.id
          if bt.id == "DEL" then
            if stage == 1 then pin = pin:sub(1,-2) else confirm = confirm:sub(1,-2) end
            errMsg = nil
          elseif bt.id == "OK" then
            if stage == 1 then
              if #pin < 4 then
                errMsg = "PIN must be 4+ digits"
              else
                stage = 2
                confirm = ""
                errMsg = nil
              end
            else
              if confirm ~= pin then
                errMsg = "PIN does not match"
                stage = 1
                pin = ""
                confirm = ""
              else
                data.pinHash = tostring(ui.djb2(pin))
                data.setupComplete = true
                saveData(cfg, data)
                return true
              end
            end
          else
            if stage == 1 then
              if #pin < 12 then pin = pin .. bt.id end
            else
              if #confirm < 12 then confirm = confirm .. bt.id end
            end
            errMsg = nil
          end
          break
        end
      end
    end
  end
end

function M.run(cfg, data)
  local blinkOn = true
  local tick = 0
  local timerId = os.startTimer(0.25)

  -- Net may already be init'd by main; net.init should be idempotent.
  net.init(cfg)

  -- ✅ Return boolean so main's ensureSetup() loop works correctly
  if data.setupComplete and data.number and data.pinHash then
    return true
  end

  -- Find server
  while true do
    local theme = ui.getTheme(data)
    ui.drawWallpaper(theme, (data.ui and data.ui.wallpaper) or "border")
    drawHeader(theme, data, blinkOn, "Setup")
    drawBox(theme, "Finding Server", {
      "Searching for VibePhone Server...",
      "",
      "Make sure the server is running",
      "and both have Ender Modems.",
    }, "Enter=Retry | 1=Reset")

    local okFind = net.discoverServer(data, 3.0)
    if okFind then break end

    local e,a = os.pullEvent()
    if e == "key" and a == keys.enter then
      -- retry
    elseif (e == "char" and a == "1") or (e == "key" and a == keys.one) then
      store.reset(data)
      saveData(cfg, data)
      return false
    elseif e == "timer" and a == timerId then
      tick = tick + 1
      blinkOn = (tick % 2 == 0)
      timerId = os.startTimer(0.25)
    end
  end

  -- Register
  do
    local theme = ui.getTheme(data)
    ui.drawWallpaper(theme, (data.ui and data.ui.wallpaper) or "border")
    drawHeader(theme, data, blinkOn, "Setup")
    drawBox(theme, "Registering", {
      "Requesting phone number...",
      "",
      "Please wait...",
    }, "Please wait...")

    local deviceKey = tostring(os.getComputerID()) .. ":" .. tostring(os.getComputerLabel() or "phone")
    local ok, resp = net.request(data, { type="vp_register", deviceKey=deviceKey }, 4.0)
    if not ok or type(resp) ~= "table" then
      return false
    end

    data.number = resp.number or data.number
    data.token = resp.token or data.token
    data.serverName = resp.serverName or data.serverName
    saveData(cfg, data)
  end

  local okPin = runCreatePin(cfg, data)
  if not okPin then
    return false
  end

  -- ✅ Final guarantee
  data.setupComplete = true
  saveData(cfg, data)

  return true
end

return M
