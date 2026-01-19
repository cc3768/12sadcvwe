dofile("/vibephone/require_shim.lua")
local config = require("config")

local ui = {}
ui.buttons = {}

function ui.clearButtons() ui.buttons = {} end

function ui.addButton(id, x,y,w,h)
  ui.buttons[#ui.buttons+1] = { id=id, x=x, y=y, w=w, h=h }
end

function ui.hit(px,py)
  for _,b in ipairs(ui.buttons) do
    if px>=b.x and px<b.x+b.w and py>=b.y and py<b.y+b.h then return b.id end
  end
  return nil
end

function ui.fill(bg)
  term.setBackgroundColor(bg or config.C_BG)
  term.setTextColor(config.C_TEXT)
  term.clear()
end

function ui.box(x,y,w,h,bg)
  term.setBackgroundColor(bg or config.C_BG)
  for yy=y,y+h-1 do
    term.setCursorPos(x,yy)
    term.write(string.rep(" ", w))
  end
end

function ui.text(x,y,s,fg,bg)
  if bg then term.setBackgroundColor(bg) end
  if fg then term.setTextColor(fg) end
  term.setCursorPos(x,y)
  term.write(s)
end

function ui.centerText(y, s, fg, bg)
  local w = term.getSize()
  local x = math.max(1, math.floor((w-#s)/2) + 1)
  ui.text(x,y,s,fg,bg)
end

function ui.statusBar(title, rightText)
  local w = term.getSize()
  ui.box(1,1,w,1,config.C_SURFACE_2)
  ui.text(2,1,title or "", colors.black, config.C_SURFACE_2)
  local r = rightText or os.date("%H:%M")
  ui.text(w-#r,1,r, colors.black, config.C_SURFACE_2)
end

function ui.divider(y, fg, bg)
  local w = term.getSize()
  ui.box(1,y,w,1,bg or config.C_BG)
  ui.text(1,y,string.rep("-", w), fg or config.C_MUTED, bg or config.C_BG)
end

function ui.card(x,y,w,h,accent)
  ui.box(x,y,w,h,config.C_SURFACE)
  ui.box(x,y,w,1,accent or config.C_ACCENT)
end

function ui.iconTile(id, x,y,w,h, label, glyph, accent)
  local a = accent or config.C_ACCENT
  ui.card(x,y,w,h,a)
  if glyph and #glyph > 0 then
    ui.centerText(y+2, glyph, a, config.C_SURFACE)
  else
    ui.centerText(y+2, "■", a, config.C_SURFACE)
  end
  local l = label or ""
  if #l > w-2 then l = l:sub(1,w-2) end
  ui.text(x+1, y+h-1, l, colors.black, config.C_SURFACE)
  ui.addButton(id, x,y,w,h)
end

function ui.dock(y)
  local w = term.getSize()
  ui.box(1,y,w,2,config.C_SURFACE_2)
end

return ui
