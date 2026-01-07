local M = {}

-- styles: border | none | dots | stripes | grid
function M.drawWallpaper(theme, style)
  style = style or "border"
  local w,h = term.getSize()

  -- base fill
  term.setBackgroundColor(theme.bg)
  term.setTextColor(theme.text)
  term.clear()

  if style == "none" then return end

  if style == "border" then
    -- outer border frame using bg2
    term.setBackgroundColor(theme.bg2)
    term.setCursorPos(1,1); term.write(string.rep(" ", w))
    term.setCursorPos(1,h); term.write(string.rep(" ", w))
    for y=2,h-1 do
      term.setCursorPos(1,y); term.write(" ")
      term.setCursorPos(w,y); term.write(" ")
    end
    -- inner reset
    term.setBackgroundColor(theme.bg)
    return
  end

  if style == "dots" then
    for y=1,h do
      for x=1,w do
        if (x+y) % 7 == 0 then
          term.setCursorPos(x,y)
          term.setBackgroundColor(theme.bg2)
          term.write(" ")
        end
      end
    end
  elseif style == "stripes" then
    for y=1,h do
      if y % 3 == 0 then
        term.setCursorPos(1,y)
        term.setBackgroundColor(theme.bg2)
        term.write(string.rep(" ", w))
      end
    end
  elseif style == "grid" then
    for y=1,h do
      for x=1,w do
        if x % 6 == 0 or y % 4 == 0 then
          term.setCursorPos(x,y)
          term.setBackgroundColor(theme.bg2)
          term.write(" ")
        end
      end
    end
  end

  term.setBackgroundColor(theme.bg)
  term.setTextColor(theme.text)
end

return M
