local M = {}

function M.fillRect(x,y,w,h,bg)
  term.setBackgroundColor(bg)
  for yy=y, y+h-1 do
    term.setCursorPos(x,yy)
    term.write(string.rep(" ", w))
  end
end

function M.writeAt(x,y,txt,fg,bg)
  if bg then term.setBackgroundColor(bg) end
  if fg then term.setTextColor(fg) end
  term.setCursorPos(x,y)
  term.write(txt)
end

function M.center(y, txt, fg, bg)
  local w,_ = term.getSize()
  local x = math.max(1, math.floor((w-#txt)/2)+1)
  M.writeAt(x,y,txt,fg,bg)
end

function M.hit(mx,my,x,y,w,h)
  return mx>=x and mx<x+w and my>=y and my<y+h
end

function M.djb2(s)
  local h = 5381
  for i=1,#s do
    h = ((h*33) + string.byte(s,i)) % 2147483647
  end
  return tostring(h)
end

return M
