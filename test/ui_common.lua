local M = {}

-- =========================
-- PRIMITIVES
-- =========================

function M.panel(t, x, y, w, h, bg)
  t.setBackgroundColor(bg)
  for i = 0, h - 1 do
    t.setCursorPos(x, y + i)
    t.write((" "):rep(w))
  end
end

function M.label(t, x, y, text, fg, bg)
  if bg then t.setBackgroundColor(bg) end
  t.setTextColor(fg or colors.white)
  t.setCursorPos(x, y)
  t.write(text or "")
end

function M.hitRect(x, y, r)
  return x >= r.x1 and x <= r.x2 and y >= r.y1 and y <= r.y2
end

function M.truncate(s, max)
  s = tostring(s or "")
  if #s <= max then return s end
  if max <= 3 then return s:sub(1, max) end
  return s:sub(1, max - 3) .. "..."
end

function M.rightText(t, x2, y, text, fg, bg)
  text = tostring(text or "")
  local x = x2 - #text + 1
  if x < 1 then x = 1 end
  M.label(t, x, y, text, fg, bg)
end

function M.centerText(t, x1, x2, y, text, fg, bg)
  text = tostring(text or "")
  local w = (x2 - x1 + 1)
  local x = x1 + math.floor((w - #text) / 2)
  if x < x1 then x = x1 end
  M.label(t, x, y, text, fg, bg)
end

function M.box(t, x, y, w, h, bg, border, title, titleFg)
  border = border or bg
  M.panel(t, x, y, w, h, bg)
  -- border
  t.setBackgroundColor(border)
  for i = 0, w - 1 do
    t.setCursorPos(x + i, y)
    t.write(" ")
    t.setCursorPos(x + i, y + h - 1)
    t.write(" ")
  end
  for i = 0, h - 1 do
    t.setCursorPos(x, y + i)
    t.write(" ")
    t.setCursorPos(x + w - 1, y + i)
    t.write(" ")
  end

  if title and title ~= "" and h >= 3 and w >= 6 then
    M.label(t, x + 2, y, " " .. title .. " ", titleFg or colors.white, border)
  end
end

function M.button(t, x, y, w, h, label, bg, fg)
  M.panel(t, x, y, w, h, bg)
  M.centerText(t, x, x + w - 1, y + math.floor(h / 2), label, fg or colors.white, bg)
end

function M.badge(t, x, y, text, bg, fg)
  text = tostring(text or "")
  local w = #text + 2
  M.panel(t, x, y, w, 1, bg)
  M.label(t, x + 1, y, text, fg or colors.white, bg)
  return w
end

return M
