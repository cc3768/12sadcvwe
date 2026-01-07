-- /vibephone/screens/home.lua
local ui = require("ui")

local M = {}

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function drawTile(theme, x, y, w, h, title, subtitle, focused, pressed, pulseOn)
  local border = theme.line
  local bg = theme.surface
  local fg = theme.text
  local sub = theme.muted

  if focused and pulseOn then border = theme.accent end
  if pressed then
    border = theme.accent
    bg = theme.inner
    fg = theme.text
  end

  ui.fillRect(x, y, w, h, border)
  ui.fillRect(x+1, y+1, w-2, h-2, bg)

  local t = title or ""
  if #t > w-2 then t = t:sub(1, w-2) end
  local tx = x + 1 + math.floor(((w-2) - #t) / 2)
  ui.writeAt(tx, y+1, t, fg, bg)

  if subtitle and subtitle ~= "" and h >= 4 then
    local s = subtitle
    if #s > w-2 then s = s:sub(1, w-2) end
    local sx = x + 1 + math.floor(((w-2) - #s) / 2)
    ui.writeAt(sx, y+2, s, sub, bg)
  end
end

local function drawHeader(theme, data, blinkOn)
  local w,_ = term.getSize()

  -- single merged header row
  local y = 1
  ui.fillRect(1, y, w, 1, theme.surface)

  local connected = (data.serverId ~= nil)
  local dot = blinkOn and "●" or "○"
  local dotColor = connected and theme.accent or theme.muted

  -- left status
  ui.writeAt(2, y, dot, dotColor, theme.surface)
  ui.writeAt(4, y, connected and "Connected" or "Offline", theme.text, theme.surface)

  -- center title
  local title = (data.profile and data.profile.name) or "VibePhone"
  local tx = math.floor((w - #title) / 2) + 1
  ui.writeAt(tx, y, title, theme.text, theme.surface)

  -- right number
  local num = data.number and ("#" .. tostring(data.number)) or "#----"
  ui.writeAt(w - #num - 1, y, num, theme.muted, theme.surface)
end


local function drawDock(theme, active)
  local w,h = term.getSize()
  local y = h - 1

  ui.fillRect(1, y, w, 1, theme.surface)

  local items = {
    {id="home",     label="HOME"},
    {id="messages", label="MSG"},
    {id="appstore", label="STORE"},
    {id="settings", label="SET"},
  }

  local cellW = math.floor(w / #items)
  local btns = {}

  for i,it in ipairs(items) do
    local x = (i-1)*cellW + 1
    local ww = (i == #items) and (w - x + 1) or cellW

    local isActive = (active == it.id) or (active == "home" and it.id == "home")
    local fg = isActive and theme.accent or theme.muted

    local tx = x + math.floor((ww - #it.label) / 2)
    ui.writeAt(tx, y, it.label, fg, theme.surface)

    btns[#btns+1] = {id=it.id, x=x, y=y, w=ww, h=1}
  end

  return btns
end

-- 3-column grid for smaller tiles + growth
local function layoutApps(tiles)
  local w,h = term.getSize()

  -- header uses lines 1
  local top = 3

  -- reserve:
  -- line h-2 hint
  -- line h-1 dock
  local bottom = h - 3
  local contentH = bottom - top + 1
  if contentH < 6 then contentH = 6 end

  local cols = (w <= 26) and 3 or 4
  if cols > 4 then cols = 4 end

  local gapX = (w <= 26) and 1 or 2
  local gapY = 1

  local tileW = math.floor((w - 2 - gapX*(cols-1)) / cols)
  tileW = clamp(tileW, 7, 12)

  local tileH = 4 -- compact
  if h >= 20 then tileH = 5 end

  local rows = math.max(1, math.floor((contentH + gapY) / (tileH + gapY)))
  local maxTiles = rows * cols

  -- Center grid block
  local usedTiles = math.min(#tiles, maxTiles)
  local usedRows = math.max(1, math.ceil(usedTiles / cols))
  local gridW = tileW*cols + gapX*(cols-1)
  local gridH = tileH*usedRows + gapY*(usedRows-1)

  local startX = math.floor((w - gridW) / 2) + 1
  local startY = top + math.floor((contentH - gridH) / 2)
  if startY < top then startY = top end

  local out = {}
  for i=1, usedTiles do
    local r = math.floor((i-1)/cols)
    local c = (i-1) % cols
    out[i] = {
      id = tiles[i].id,
      label = tiles[i].label,
      sub = tiles[i].sub,
      x = startX + c*(tileW + gapX),
      y = startY + r*(tileH + gapY),
      w = tileW,
      h = tileH,
    }
  end

  return out
end

local function drawHome(theme, data, focusId, pressedId, pulseOn, blinkOn)
  ui.drawWallpaper(theme, (data.ui and data.ui.wallpaper) or "border")

  drawHeader(theme, data, blinkOn)

  local w,h = term.getSize()

  -- Tiles list (later: populate from installed apps)
  local tiles = {
    { id="messages", label="Messages", sub="Inbox" },
    { id="appstore", label="Store",    sub="Apps"  },
    { id="settings", label="Settings", sub="Theme" },
    { id="lock",     label="Lock",     sub="PIN"   },
  }

  local slots = layoutApps(tiles)

  for _,s in ipairs(slots) do
    drawTile(theme, s.x, s.y, s.w, s.h, s.label, s.sub, s.id==focusId, s.id==pressedId, pulseOn)
  end

  -- Hint line
  ui.fillRect(1, h-2, w, 1, theme.bg)
  ui.center(h-2, "Tap • Arrows • Enter", theme.muted, theme.bg)

  local dock = drawDock(theme, "home")
  return slots, dock, tiles
end

local function nextFocusId(tiles, current, dir)
  local idx = 1
  for i,t in ipairs(tiles) do
    if t.id == current then idx = i break end
  end

  if dir == "next" then
    idx = idx + 1
    if idx > #tiles then idx = 1 end
  else
    idx = idx - 1
    if idx < 1 then idx = #tiles end
  end
  return tiles[idx].id
end

function M.run(cfg, data)
  local focusId = "messages"
  local pressedId = nil
  local pressedUntil = 0

  local pulseOn = false
  local blinkOn = true
  local tick = 0
  local timerId = os.startTimer(0.18)

  while true do
    local theme = ui.getTheme(data)
    local slots, dock, tiles = drawHome(theme, data, focusId, pressedId, pulseOn, blinkOn)

    local e,a,b,c = os.pullEvent()

    if e == "timer" and a == timerId then
      tick = tick + 1
      pulseOn = (tick % 2 == 0)
      blinkOn = (tick % 3 ~= 0)

      if pressedId and os.clock() > pressedUntil then
        pressedId = nil
      end

      timerId = os.startTimer(0.18)

    elseif e == "mouse_click" then
      local mx,my = b,c

      -- dock taps
      for _,bt in ipairs(dock) do
        if ui.hit(mx,my, bt.x,bt.y,bt.w,bt.h) then
          if bt.id ~= "home" then return bt.id end
        end
      end

      -- tile taps
      for _,s in ipairs(slots) do
        if ui.hit(mx,my, s.x,s.y,s.w,s.h) then
          focusId = s.id
          pressedId = s.id
          pressedUntil = os.clock() + 0.12
          return s.id
        end
      end

    elseif e == "key" then
      if a == keys.left or a == keys.up then
        focusId = nextFocusId(tiles, focusId, "prev")
      elseif a == keys.right or a == keys.down then
        focusId = nextFocusId(tiles, focusId, "next")
      elseif a == keys.enter then
        pressedId = focusId
        pressedUntil = os.clock() + 0.12
        return focusId
      end
    end
  end
end

return M
