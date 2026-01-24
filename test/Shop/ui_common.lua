local M = {}



function M.button(m,x,y,w,h,label,bg,fg)

  m.setBackgroundColor(bg)

  m.setTextColor(fg)

  for i=0,h-1 do

    m.setCursorPos(x,y+i)

    m.write((" "):rep(w))

  end

  m.setCursorPos(x+1,y+math.floor(h/2))

  m.write(label)

end



function M.hit(x,y,b)

  return x>=b.x and x<=b.x+b.w-1 and y>=b.y and y<=b.y+b.h-1

end





-- Added for compatibility: fill a rectangle background

function M.panel(t, x, y, w, h, bg)

  t.setBackgroundColor(bg)

  for i = 0, h - 1 do

    t.setCursorPos(x, y + i)

    t.write((" "):rep(w))

  end

end

-- Draw text at position

function M.label(t, x, y, text, fg, bg)

  if bg then t.setBackgroundColor(bg) end

  t.setTextColor(fg or colors.white)

  t.setCursorPos(x, y)

  t.write(text)

end



-- Hit test using x1/x2/y1/y2

function M.hitRect(x, y, r)

  return x >= r.x1 and x <= r.x2 and y >= r.y1 and y <= r.y2

end



return M

