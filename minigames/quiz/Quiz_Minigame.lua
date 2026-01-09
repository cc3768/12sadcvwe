-- Quiz_MiniGame.lua
-- Quiz minigame for CC:Tweaked (Advanced Computer + Advanced Monitor 3x2)
-- Entry function: Quiz_mainingame() Yes i really did write this stuff, Why because there is no shadey code in my work!. cc3768
-- Ends with: GameOverWin() or GameOverLose()
-- Main expects: Play() -> returns true/false, and GameWon()/GameLost().

local config = dofile("Quiz_Minigame_config.lua")

local M = {}

-- =========================
-- Utilities
-- =========================
local function clamp(n, a, b)
  if n < a then return a end
  if n > b then return b end
  return n
end

local function shuffle(t)
  for i = #t, 2, -1 do
    local j = math.random(1, i)
    t[i], t[j] = t[j], t[i]
  end
  return t
end

local function wrapText(text, width)
  width = math.max(1, width)
  local words = {}
  for w in tostring(text):gmatch("%S+") do table.insert(words, w) end

  local lines = {}
  local line = ""

  for _, w in ipairs(words) do
    if #line == 0 then
      line = w
    elseif (#line + 1 + #w) <= width then
      line = line .. " " .. w
    else
      table.insert(lines, line)
      line = w
    end
  end
  if #line > 0 then table.insert(lines, line) end
  if #lines == 0 then lines = {""} end
  return lines
end

local function centerWrite(termObj, y, text, fg, bg)
  local w, _ = termObj.getSize()
  local s = tostring(text)
  local x = math.floor((w - #s) / 2) + 1
  x = clamp(x, 1, w)
  if bg then termObj.setBackgroundColor(bg) end
  if fg then termObj.setTextColor(fg) end
  termObj.setCursorPos(x, y)
  termObj.write(s:sub(1, w))
end

local function fill(termObj, bg)
  local w, h = termObj.getSize()
  termObj.setBackgroundColor(bg)
  termObj.clear()
  termObj.setCursorPos(1, 1)
end

-- Button object: {id,x1,y1,x2,y2,label}
local function drawButton(termObj, btn, style)
  style = style or {}
  local bg = style.bg or colors.gray
  local fg = style.fg or colors.white
  local border = style.border or colors.lightGray

  local x1, y1, x2, y2 = btn.x1, btn.y1, btn.x2, btn.y2
  local w = x2 - x1 + 1
  local h = y2 - y1 + 1

  -- border
  termObj.setBackgroundColor(border)
  termObj.setTextColor(border)
  for y = y1, y2 do
    termObj.setCursorPos(x1, y)
    termObj.write((" "):rep(w))
  end

  -- inner
  termObj.setBackgroundColor(bg)
  termObj.setTextColor(fg)
  for y = y1 + 1, y2 - 1 do
    if y >= y1 and y <= y2 then
      termObj.setCursorPos(x1 + 1, y)
      termObj.write((" "):rep(math.max(0, w - 2)))
    end
  end

  -- label centered
  local label = tostring(btn.label)
  local ly = y1 + math.floor(h / 2)
  local lx = x1 + math.floor((w - #label) / 2)
  lx = clamp(lx, x1 + 1, x2 - 1)
  ly = clamp(ly, y1, y2)
  termObj.setCursorPos(lx, ly)
  termObj.write(label:sub(1, math.max(0, w - 2)))
end

local function pointInButton(x, y, btn)
  return x >= btn.x1 and x <= btn.x2 and y >= btn.y1 and y <= btn.y2
end

local function findMonitor()
  local mon = peripheral.find("monitor")
  if not mon then
    error("No monitor found. Please attach an Advanced Monitor (3x2) and try again.")
  end
  return mon
end

-- =========================
-- End screens (main calls GameWon/GameLost)
-- =========================
function M.GameOverWin(mon)
  mon = mon or findMonitor()
  pcall(function()
    mon.setTextScale(config.textScale or 0.5)
  end)
  fill(mon, colors.black)
  local _, h = mon.getSize()
  centerWrite(mon, math.floor(h / 2) - 1, "YOU WIN!", colors.lime, colors.black)
  centerWrite(mon, math.floor(h / 2) + 1, "Nice work.", colors.white, colors.black)
end

function M.GameOverLose(mon)
  mon = mon or findMonitor()
  pcall(function()
    mon.setTextScale(config.textScale or 0.5)
  end)
  fill(mon, colors.black)
  local _, h = mon.getSize()
  centerWrite(mon, math.floor(h / 2) - 1, "YOU LOSE!", colors.red, colors.black)
  centerWrite(mon, math.floor(h / 2) + 1, "Try again.", colors.white, colors.black)
end

function M.GameWon(...) return M.GameOverWin(...) end
function M.GameLost(...) return M.GameOverLose(...) end

-- =========================
-- Core quiz
-- =========================
local function pickQuestionIndices(total, count)
  local idx = {}
  for i = 1, total do idx[i] = i end
  shuffle(idx)
  local out = {}
  for i = 1, math.min(count, total) do
    out[i] = idx[i]
  end
  return out
end

local function validateConfig(cfg)
  if type(cfg) ~= "table" then error("Config must return a table.") end
  if type(cfg.questions) ~= "table" or #cfg.questions < 1 then
    error("Config needs questions = { ... } with at least 1 question.")
  end
  for i, q in ipairs(cfg.questions) do
    if type(q.question) ~= "string" then error(("Question %d missing 'question' string."):format(i)) end
    if type(q.answers) ~= "table" or #q.answers < 2 then error(("Question %d needs answers table (>=2)."):format(i)) end
    if type(q.correct) ~= "number" then error(("Question %d needs numeric 'correct' index."):format(i)) end
    if q.correct < 1 or q.correct > #q.answers then
      error(("Question %d 'correct' index out of range."):format(i))
    end
  end
end

local function renderQuestion(mon, q, timeLeftSec)
  local w, h = mon.getSize()
  fill(mon, config.colors.bg)

  -- Header
  mon.setBackgroundColor(config.colors.bg)
  mon.setTextColor(config.colors.header)
  mon.setCursorPos(1, 1)
  mon.write((" "):rep(w))
  centerWrite(mon, 1, config.title or "QUIZ", config.colors.header, config.colors.bg)

  -- Timer (top right)
  local timerText = ("Time: %ds"):format(math.max(0, math.floor(timeLeftSec)))
  mon.setCursorPos(math.max(1, w - #timerText + 1), 1)
  mon.setTextColor(config.colors.timer)
  mon.write(timerText)

  -- Question area
  local qTop = 3
  local qWidth = w - 2
  local lines = wrapText(q.question, qWidth)
  local maxLines = math.max(1, math.min(#lines, math.max(1, h - 10)))
  mon.setTextColor(config.colors.question)
  for i = 1, maxLines do
    mon.setCursorPos(2, qTop + i - 1)
    mon.write(lines[i]:sub(1, qWidth))
  end

  -- Answers buttons layout: 2 columns x 2 rows (supports up to 4 answers cleanly)
  local btns = {}
  local answers = q.answers

  local btnAreaTop = math.max(qTop + maxLines + 1, math.floor(h * 0.55))
  local btnAreaBottom = h
  local btnAreaHeight = btnAreaBottom - btnAreaTop + 1

  local rows = 2
  local cols = 2
  local gapX = 2
  local gapY = 1

  local innerW = w - (gapX * (cols + 1))
  local innerH = btnAreaHeight - (gapY * (rows + 1))

  local btnW = math.floor(innerW / cols)
  local btnH = math.max(3, math.floor(innerH / rows))

  local id = 1
  for r = 1, rows do
    for c = 1, cols do
      if id > #answers then break end
      if id > 4 then break end -- keep UI tidy
      local x1 = gapX * c + btnW * (c - 1) + 1
      local y1 = btnAreaTop + gapY * r + btnH * (r - 1)
      local x2 = x1 + btnW - 1
      local y2 = y1 + btnH - 1

      local label = tostring(answers[id])
      btns[#btns + 1] = { id = id, x1 = x1, y1 = y1, x2 = x2, y2 = y2, label = label }
      id = id + 1
    end
  end

  for _, b in ipairs(btns) do
    drawButton(mon, b, { bg = config.colors.btnBg, fg = config.colors.btnText, border = config.colors.btnBorder })
  end

  return btns
end

local function flashMessage(mon, msg, fg, bg, seconds)
  local w, h = mon.getSize()
  seconds = seconds or 0.6
  mon.setBackgroundColor(bg or colors.black)
  mon.setTextColor(fg or colors.white)
  local y = math.max(1, math.floor(h / 2))
  mon.setCursorPos(1, y)
  mon.write((" "):rep(w))
  centerWrite(mon, y, msg, fg or colors.white, bg or colors.black)
  sleep(seconds)
end

-- =========================
-- Public entrypoints
-- =========================
function M.Quiz_mainingame()
  validateConfig(config)

  math.randomseed(os.epoch("utc") % 2147483647)

  local mon = findMonitor()
  pcall(function()
    mon.setTextScale(config.textScale or 0.5)
  end)

  local totalQuestions = #config.questions
  local minQ = clamp(tonumber(config.minQuestions or 1) or 1, 1, totalQuestions)
  local maxQ = clamp(tonumber(config.maxQuestions or minQ) or minQ, minQ, totalQuestions)
  local count = math.random(minQ, maxQ)

  local timeLimit = tonumber(config.timeLimitSeconds or 12) or 12
  local failOnWrong = (config.failOnWrong ~= false)

  local order = pickQuestionIndices(totalQuestions, count)

  -- Intro
  fill(mon, config.colors.bg)
  local _, h = mon.getSize()
  centerWrite(mon, math.floor(h/2) - 1, config.title or "QUIZ", config.colors.header, config.colors.bg)
  centerWrite(mon, math.floor(h/2) + 1, ("Answer %d question(s)"):format(count), config.colors.question, config.colors.bg)
  sleep(1.0)

  for i = 1, #order do
    local q = config.questions[order[i]]

    local deadline = os.epoch("utc") + (timeLimit * 1000)
    local btns = renderQuestion(mon, q, timeLimit)

    -- Event loop for this question
    local refreshTimer = os.startTimer(0.2)

    while true do
      local now = os.epoch("utc")
      local timeLeft = (deadline - now) / 1000

      if timeLeft <= 0 then
        -- Time out => lose
        flashMessage(mon, "Time's up!", colors.red, colors.black, 0.7)
        M.GameOverLose(mon)
        return false
      end

      local ev, a, b, c = os.pullEvent()
      if ev == "timer" then
        if a == refreshTimer then
          -- update timer display (just re-render top bar quickly)
          local w, _h = mon.getSize()
          mon.setCursorPos(1, 1)
          mon.setBackgroundColor(config.colors.bg)
          mon.setTextColor(config.colors.header)
          mon.write((" "):rep(w))
          centerWrite(mon, 1, config.title or "QUIZ", config.colors.header, config.colors.bg)

          local timerText = ("Time: %ds"):format(math.max(0, math.floor(timeLeft)))
          mon.setCursorPos(math.max(1, w - #timerText + 1), 1)
          mon.setTextColor(config.colors.timer)
          mon.write(timerText)

          refreshTimer = os.startTimer(0.2)
        end

      elseif ev == "monitor_touch" then
        local _side = a
        local x, y = b, c

        for _, btn in ipairs(btns) do
          if pointInButton(x, y, btn) then
            if btn.id == q.correct then
              flashMessage(mon, "Correct!", colors.lime, colors.black, 0.35)
              break
            else
              flashMessage(mon, "Wrong!", colors.red, colors.black, 0.6)
              if failOnWrong then
                M.GameOverLose(mon)
                return false
              end
              -- if not failing on wrong, you could continue; but default is fail
              break
            end
          end
        end

        -- If correct, advance to next question
        -- We detect "correct" by checking last message? simplest: re-check selection quickly:
        -- If user touched correct button, move on; otherwise if failOnWrong triggers we already returned.
        local wasCorrect = false
        for _, btn in ipairs(btns) do
          if pointInButton(x, y, btn) and btn.id == q.correct then
            wasCorrect = true
            break
          end
        end
        if wasCorrect then
          break
        end
      end
    end
  end

  M.GameOverWin(mon)
  return true
end

function M.Play()
  return M.Quiz_mainingame()
end

return M
