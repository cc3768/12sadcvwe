local p = require("ui.primitives")
local M = {}

function M.card(x,y,w,h, theme, title, subtitle, accent)
  accent = accent or theme.accent
  p.fillRect(x,y,w,h, theme.surface)
  if w>2 and h>2 then p.fillRect(x+1,y+1,w-2,h-2, theme.inner) end
  p.fillRect(x,y,w,1, accent)

  if title then
    p.writeAt(x+2,y+1,title, theme.text, theme.inner)
  end
  if subtitle then
    p.writeAt(x+2,y+2,subtitle, theme.muted, theme.inner)
  end
end

-- Old boxed button style
function M.appButton(btn, theme, active)
  local border = active and theme.accent or theme.bg2
  local fill   = theme.inner

  p.fillRect(btn.x, btn.y, btn.w, btn.h, border)
  if btn.w>2 and btn.h>2 then
    p.fillRect(btn.x+1, btn.y+1, btn.w-2, btn.h-2, fill)
  end

  local label = btn.label or ""
  if #label > btn.w-4 then label = label:sub(1, btn.w-7) .. "..." end
  local lx = btn.x + math.max(2, math.floor((btn.w-#label)/2))
  local ly = btn.y + math.floor(btn.h/2)
  p.writeAt(lx, ly, label, theme.text, fill)
end

-- New flat tile style
function M.tile(btn, theme, pressed)
  local bg = pressed and theme.accent or theme.surface
  local fg = pressed and colors.black or theme.text

  p.fillRect(btn.x,btn.y,btn.w,btn.h, bg)
  if btn.w>2 and btn.h>2 then
    p.fillRect(btn.x+1,btn.y+1,btn.w-2,btn.h-2, theme.inner)
  end

  local label = btn.label or ""
  if #label > btn.w-4 then label = label:sub(1, btn.w-7) .. "..." end
  local lx = btn.x + math.max(2, math.floor((btn.w-#label)/2))
  local ly = btn.y + math.floor(btn.h/2)
  p.writeAt(lx, ly, label, fg, theme.inner)
end

function M.pageDots(theme, y, total, index)
  if total <= 1 then return end
  local s = ""
  for i=1,total do
    s = s .. ((i==index) and "o" or ".") .. " "
  end
  p.center(y, s:sub(1,-2), theme.muted, theme.bg)
end

function M.navBar(theme, activeId)
  local w,h = term.getSize()
  local y = h-2

  p.fillRect(1,y,w,3, theme.bg)
  p.fillRect(1,y,w,1, theme.line)

  local items = {
    {id="home", label="HOME"},
    {id="messages", label="MSG"},
    {id="store", label="STORE"},
    {id="settings", label="SET"},
  }

  local bw = math.floor(w/#items)
  local buttons = {}

  for i,it in ipairs(items) do
    local x = (i-1)*bw + 1
    local ww = (i==#items) and (w-x+1) or bw
    local fg = (it.id==activeId) and theme.accent or theme.muted

    local lx = x + math.max(0, math.floor((ww-#it.label)/2))
    p.writeAt(lx, y+2, it.label, fg, theme.bg)

    buttons[#buttons+1] = {id=it.id, x=x, y=y, w=ww, h=3}
  end

  return buttons
end

return M
