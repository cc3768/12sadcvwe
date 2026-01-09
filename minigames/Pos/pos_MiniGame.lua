-- name_Minigame.lua
-- Returns: true (win) / false (lose)
-- Use from main: local play = dofile("name_Minigame.lua"); local won = play()

local cfg = dofile("pos_MiniGame_config.lua")

local function clamp(v, a, b)
  if v < a then return a end
  if v > b then return b end
  return v
end
--made by cc3768
local function nowMs()
  return os.epoch("utc")
end

local function findMonitor()
  if cfg.monitorSide then
    local m = peripheral.wrap(cfg.monitorSide)
    if m and peripheral.getType(cfg.monitorSide) == "monitor" then return m end
  end
  return peripheral.find("monitor")
end
--made by cc3768
local function clear(termObj)
  termObj.setBackgroundColor(colors.black)
  termObj.setTextColor(colors.white)
  termObj.clear()
  termObj.setCursorPos(1, 1)
end

local function centerText(termObj, y, text, textColor)
  local w, _ = termObj.getSize()
  termObj.setTextColor(textColor or colors.white)
  termObj.setCursorPos(math.floor((w - #text) / 2) + 1, y)
  termObj.write(text)
end

local function GameLost()
  local mon = findMonitor()
  if not mon then return end
  mon.setTextScale(cfg.textScale or 0.5)
  clear(mon)

  local _, h = mon.getSize()
  centerText(mon, math.floor(h/2), "YOU LOSE", colors.red)
end

local function GameWon()
  local mon = findMonitor()
  if not mon then return end
  mon.setTextScale(cfg.textScale or 0.5)
  clear(mon)

  local _, h = mon.getSize()
  centerText(mon, math.floor(h/2), "YOU WIN!", colors.lime)
end

local function drawText(termObj, x, y, text, textColor, bgColor)
  if bgColor then termObj.setBackgroundColor(bgColor) end
  if textColor then termObj.setTextColor(textColor) end
  termObj.setCursorPos(x, y)
  termObj.write(text)
end

local function drawRect(termObj, x, y, w, h, bgColor)
  termObj.setBackgroundColor(bgColor or colors.black)
  for yy = y, y + h - 1 do
    termObj.setCursorPos(x, yy)
    termObj.write(string.rep(" ", w))
  end
end
--made by cc3768
local function computePlayArea(termObj)
  local w, h = termObj.getSize()
  local top = clamp((cfg.uiRows or 0) + 1, 1, h)
  local bottom = h
  return w, h, top, bottom
end

local function randomDotPos(termObj, dotSize)
  local w, _, top, bottom = computePlayArea(termObj)
  local maxX = math.max(1, w - dotSize + 1)
  local maxY = math.max(top, bottom - dotSize + 1)
  return math.random(1, maxX), math.random(top, maxY)
end

local function randomDir()
  while true do
    local dx = math.random(-1, 1)
    local dy = math.random(-1, 1)
    if not (dx == 0 and dy == 0) then
      return dx, dy
    end
  end
end
--made by cc3768
local FADE_COLORS = {
  colors.lime,
  colors.green,
  colors.yellow,
  colors.orange,
  colors.red
}
--made by cc3768
local function Play()
  math.randomseed(nowMs() + os.getComputerID() * 1337)

  local mon = findMonitor()
  if not mon then error("No monitor found. Attach one or set cfg.monitorSide.") end

  mon.setTextScale(cfg.textScale or 0.5)
  clear(mon)
--made by cc3768
  local targetRounds = math.random(cfg.minRounds or 5, cfg.maxRounds or 10)
  local roundsDone = 0

  local w, h = mon.getSize()
  if w < 6 or h < 4 then
    clear(mon)
    drawText(mon, 1, 1, "Monitor too small", colors.red, colors.black)
    return false
  end
--made by cc3768
  local function drawUI()
    drawRect(mon, 1, 1, w, cfg.uiRows or 2, colors.black)
    drawText(mon, 1, 1, "Tap the dot!", colors.cyan, colors.black)
    drawText(mon, 1, 2, string.format("Progress: %d/%d", roundsDone, targetRounds), colors.white, colors.black)
  end
--made by cc3768
  local function shouldMoveDot()
    return roundsDone >= (cfg.moveAfter or 5)
  end
--made by cc3768
  local function calcTimeAllowedSeconds()
    local base = cfg.baseTimeSeconds or 1.6
    local decay = cfg.timeDecayPerRound or 0.04
    local minT = cfg.minTimeSeconds or 0.55
    local t = math.max(minT, base - decay * roundsDone)

    if roundsDone >= (cfg.fastAfter or 10) then
      t = math.max(minT, t * 0.75)
    end
    return t
  end
--made by cc3768
  local function calcMoveIntervalSeconds()
    if roundsDone >= (cfg.fastAfter or 10) then
      return cfg.fastMoveInterval or 0.45
    end
    return cfg.moveInterval or 0.65
  end

  local dotSize = cfg.dotSize or 2
  local dot = { x=1, y=1, dx=0, dy=0, step=1, alive=true, lastX=nil, lastY=nil }

  local function eraseDot()
    if dot.lastX and dot.lastY then
      drawRect(mon, dot.lastX, dot.lastY, dotSize, dotSize, colors.black)
    end
  end
--made by cc3768
  local function drawDot(color)
    eraseDot()
    drawRect(mon, dot.x, dot.y, dotSize, dotSize, color)
    dot.lastX, dot.lastY = dot.x, dot.y
  end

  local function slideDotOneStep()
    local mw, _, top, bottom = computePlayArea(mon)
    local minX, maxX = 1, math.max(1, mw - dotSize + 1)
    local minY, maxY = top, math.max(top, bottom - dotSize + 1)

    local nx = dot.x + dot.dx
    local ny = dot.y + dot.dy

    if nx < minX or nx > maxX then
      dot.dx = -dot.dx
      nx = clamp(dot.x + dot.dx, minX, maxX)
    end
    if ny < minY or ny > maxY then
      dot.dy = -dot.dy
      ny = clamp(dot.y + dot.dy, minY, maxY)
    end

    dot.x, dot.y = nx, ny
  end
--made by cc3768
  local function spawnNewDot()
    drawUI()
    dot.step = 1
    dot.alive = true
    dot.x, dot.y = randomDotPos(mon, dotSize)

    if shouldMoveDot() then
      dot.dx, dot.dy = randomDir()
    else
      dot.dx, dot.dy = 0, 0
    end

    drawDot(FADE_COLORS[dot.step])
  end

  spawnNewDot()

  local timeAllowed = calcTimeAllowedSeconds()
  local fadeInterval = timeAllowed / #FADE_COLORS
  local fadeTimer = os.startTimer(fadeInterval)
  local deadline = nowMs() + math.floor(timeAllowed * 1000)

  local moveTimer = nil
  if shouldMoveDot() then
    moveTimer = os.startTimer(calcMoveIntervalSeconds())
  end

  while true do
    local e, a, b, c = os.pullEvent()

    if e == "terminate" then
      clear(mon)
      return false
    end
--made by cc3768
    -- Fade
    if e == "timer" and a == fadeTimer and dot.alive then
      if nowMs() >= deadline then
        return false
      end

      dot.step = dot.step + 1
      if dot.step > #FADE_COLORS then
        return false
      end

      drawDot(FADE_COLORS[dot.step])
      fadeTimer = os.startTimer(fadeInterval)
    end

    -- Slide movement (no jumping)
    if e == "timer" and moveTimer and a == moveTimer and dot.alive and shouldMoveDot() then
      slideDotOneStep()
      drawDot(FADE_COLORS[dot.step])
      moveTimer = os.startTimer(calcMoveIntervalSeconds())
    end

    -- Touch
    if e == "monitor_touch" and dot.alive then
      local tx, ty = b, c
      local inside =
        tx >= dot.x and tx <= (dot.x + dotSize - 1) and
        ty >= dot.y and ty <= (dot.y + dotSize - 1)

      if inside then
        roundsDone = roundsDone + 1

        if roundsDone >= targetRounds then
          return true
        end

        timeAllowed = calcTimeAllowedSeconds()
        fadeInterval = timeAllowed / #FADE_COLORS
        deadline = nowMs() + math.floor(timeAllowed * 1000)

        spawnNewDot()
        fadeTimer = os.startTimer(fadeInterval)
--made by cc3768
        if shouldMoveDot() then
          moveTimer = os.startTimer(calcMoveIntervalSeconds())
        else
          moveTimer = nil
        end
      end
    end
  end
end

-- Export the function so main.lua can call it
return {
  Play = Play,
  GameWon = GameWon,
  GameLost = GameLost,
}