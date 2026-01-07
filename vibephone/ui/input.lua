local p = require("ui.primitives")
local frame = require("ui.frame")
local M = {}

function M.textEntry(theme, title, initial, maxLen, hint)
  local value = initial or ""
  maxLen = maxLen or 18

  while true do
    term.setBackgroundColor(theme.bg)
    term.setTextColor(theme.text)
    term.clear()

    frame.statusBar(theme, title or "Input", "Q=Cancel")
    frame.header(theme, title or "Input", nil)

    local w,h = term.getSize()
    p.writeAt(2,6, hint or "Type then Enter", theme.muted, theme.bg)
    p.writeAt(2,8, "[" .. value .. "]", theme.text, theme.bg)
    p.writeAt(2,h-4, "Enter=OK  Backspace=Del", theme.muted, theme.bg)

    local e,a = os.pullEvent()
    if e == "char" then
      if #value < maxLen then value = value .. a end
    elseif e == "key" then
      if a == keys.backspace then value = value:sub(1,-2)
      elseif a == keys.enter then return value
      elseif a == keys.q then return nil end
    end
  end
end

function M.pinPad(theme, title, hint)
  local pin = ""

  local function draw()
    term.setBackgroundColor(theme.bg)
    term.setTextColor(theme.text)
    term.clear()

    frame.statusBar(theme, title or "VibePhone", "Q=Reset")
    frame.header(theme, hint or "Unlock", nil)

    p.center(7, string.rep("*", #pin), theme.text, theme.bg)
    p.center(9, "Tap digits or type", theme.muted, theme.bg)

local grid = {
  {"1","2","3"},
  {"4","5","6"},
  {"7","8","9"},
  {"DEL","0","SUB"},
}

    local w,_ = term.getSize()
    local bw,gap = 8,2
    local startX = math.max(2, math.floor((w-(bw*3+gap*2))/2)+1)
    local startY = 11

    local buttons = {}
    for r=1,4 do
      for c=1,3 do
        local label = grid[r][c]
        local x = startX + (c-1)*(bw+gap)
        local y = startY + (r-1)*3

        local bg = theme.surface
        local fg = theme.text
        if label == "SUB" then bg = theme.accent; fg = colors.black end
        if label == "DEL" then bg = theme.line end

        p.fillRect(x,y,bw,2,bg)
        local lx = x + math.max(0, math.floor((bw-#label)/2))
        p.writeAt(lx,y,label,fg,bg)

        buttons[#buttons+1] = {id=label, x=x, y=y, w=bw, h=2}
      end
    end

    return buttons
  end

  while true do
    local buttons = draw()
    local e,a,b,c = os.pullEvent()

    if e == "char" then
      if #pin < 12 then pin = pin .. a end
    elseif e == "key" then
      if a == keys.backspace then pin = pin:sub(1,-2)
      elseif a == keys.enter then return pin, false
      elseif a == keys.q then return nil, true end
    elseif e == "mouse_click" then
      local mx,my = b,c
      for _,bt in ipairs(buttons) do
        if p.hit(mx,my, bt.x,bt.y,bt.w,bt.h) then
if bt.id == "SUB" then return pin, false end
if bt.id == "DEL" then pin = pin:sub(1,-2) end
if bt.id ~= "SUB" and bt.id ~= "DEL" then
            if #pin < 12 then pin = pin .. bt.id end
          end
        end
      end
    end
  end
end

return M
