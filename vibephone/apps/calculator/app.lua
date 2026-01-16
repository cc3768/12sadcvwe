-- /vibephone/apps/calculator/app.lua
-- Standalone calculator (does NOT use /vibephone/ui.lua)

local C_BG      = colors.black
local C_PANEL   = colors.gray
local C_PANEL2  = colors.lightGray
local C_TEXT    = colors.white
local C_ACCENT  = colors.cyan
local C_DANGER  = colors.red

local S = { expr="", result="", status="Tap buttons. Enter = =", scroll=0 }
local buttons = {}

local function setBG(c) term.setBackgroundColor(c or C_BG) end
local function setFG(c) term.setTextColor(c or C_TEXT) end

local function clear(bg)
  setBG(bg); setFG(C_TEXT)
  term.clear()
end

local function box(x,y,w,h,bg)
  setBG(bg)
  for yy=y, y+h-1 do
    term.setCursorPos(x,yy)
    term.write(string.rep(" ", w))
  end
end

local function text(x,y,s,fg,bg)
  if bg then setBG(bg) end
  if fg then setFG(fg) end
  term.setCursorPos(x,y)
  term.write(s)
end

local function center(x,y,w,h,s,fg,bg)
  local tx = x + math.max(0, math.floor((w-#s)/2))
  local ty = y + math.floor(h/2)
  text(tx, ty, s, fg, bg)
end

local function addBtn(id,x,y,w,h)
  buttons[#buttons+1] = {id=id,x=x,y=y,w=w,h=h}
end

local function hit(px,py)
  for i=#buttons,1,-1 do
    local b = buttons[i]
    if px>=b.x and px<b.x+b.w and py>=b.y and py<b.y+b.h then
      return b.id
    end
  end
  return nil
end

local function trim(s) return (tostring(s or ""):gsub("^%s+",""):gsub("%s+$","")) end

local function safeEval(expr)
  expr = trim(expr)
  if expr == "" then return nil, "Empty" end
  if expr:match("[^0-9%+%-%*/%%%^%(%)%.%s]") then return nil, "Invalid char" end
  expr = expr:gsub("(%d+)%s*%%", "(%1/100)")

  local fn = load("return ("..expr..")", "calc", "t", {})
  if not fn then return nil, "Parse" end
  local ok, val = pcall(fn)
  if not ok then return nil, "Math err" end
  if type(val) ~= "number" or val ~= val or val == math.huge or val == -math.huge then
    return nil, "NaN/Inf"
  end
  return val, nil
end

local function fmt(n)
  if n == nil then return "" end
  local s = tostring(n)
  if s:find("%.") then s = s:gsub("0+$",""):gsub("%.$","") end
  return s
end

local function draw()
  buttons = {}
  local w,h = term.getSize()
  clear(C_BG)

  -- header
  box(1,1,w,1,C_PANEL2)
  text(2,1,"Calculator",colors.black,C_PANEL2)
  text(w-5,1,"Exit",colors.blue,C_PANEL2)
  addBtn("exit", w-5,1,4,1)

  -- display
  local top = 3
  box(2,top,w-2,4,C_PANEL)
  local e = S.expr
  if #e > w-6 then e = "…" .. e:sub(#e-(w-7)) end
  text(3,top+1,e,C_TEXT,C_PANEL)

  local r = S.result
  if #r > w-6 then r = "…" .. r:sub(#r-(w-7)) end
  text(3,top+2,r,C_ACCENT,C_PANEL)

  -- status
  box(1,h,w,1,C_PANEL2)
  local st = tostring(S.status or "")
  if #st > w-2 then st = st:sub(1,w-2) end
  text(2,h,st,colors.black,C_PANEL2)

  -- keypad
  local gridTop = top + 5
  local rows = {
    {"C","(",")","⌫"},
    {"7","8","9","/"},
    {"4","5","6","*"},
    {"1","2","3","-"},
    {"0",".","=","+"},
  }
  local cols = 4
  local btnW = math.floor((w-2)/cols)
  local btnH = 2

  for yi=1,#rows do
    for xi=1,cols do
      local label = rows[yi][xi]
      local x = 2 + (xi-1)*btnW
      local y = gridTop + (yi-1)*btnH

      local bg = C_PANEL
      local fg = C_TEXT
      if label == "=" then bg = C_ACCENT; fg = colors.black end
      if label == "C" then bg = C_DANGER; fg = colors.white end

      box(x,y,btnW,btnH,bg)
      center(x,y,btnW,btnH,label,fg,bg)
      addBtn("k_"..label,x,y,btnW,btnH)
    end
  end
end

local function applyKey(label)
  if label == "C" then
    S.expr, S.result, S.status = "", "", "Cleared"
    return
  end
  if label == "⌫" then
    S.expr = S.expr:sub(1, math.max(#S.expr-1,0))
    S.status = "Backspace"
    return
  end
  if label == "=" then
    local val, err = safeEval(S.expr)
    if err then
      S.result = "Error: "..err
      S.status = "Fix expression"
    else
      S.result = fmt(val)
      S.expr = fmt(val)
      S.status = "OK"
    end
    return
  end

  local op = label:match("^[%+%-%*/%^]$")
  if op then
    local last = S.expr:sub(-1)
    if last:match("[%+%-%*/%^]") then
      S.expr = S.expr:sub(1,#S.expr-1) .. op
      return
    end
  end

  S.expr = S.expr .. label
  S.status = "Typing..."
end

-- main loop
term.setCursorBlink(false)
draw()

while true do
  local e,a,b,c = os.pullEvent()
  if e == "term_resize" then
    draw()

  elseif e == "mouse_click" then
    local id = hit(b,c)
    if id == "exit" then return end
    if id and id:sub(1,2) == "k_" then
      applyKey(id:sub(3))
      draw()
    end

  elseif e == "char" then
    local ch = a
    if ch:match("[0-9%.%(%)%+%-%*/%^]") then
      S.expr = S.expr .. ch
      S.status = "Typing..."
      draw()
    end

  elseif e == "key" then
    if a == keys.backspace then applyKey("⌫"); draw()
    elseif a == keys.enter then applyKey("="); draw()
    elseif a == keys.delete then applyKey("C"); draw()
    elseif a == keys.escape then return end
  end
end
