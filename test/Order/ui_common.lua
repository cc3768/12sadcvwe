local M = {}

-- ===== basic drawing =====

local function rep(n) return (" "):rep(math.max(0, n or 0)) end

function M.panel(t, x, y, w, h, bg)
  t.setBackgroundColor(bg or colors.black)
  for i = 0, (h or 1) - 1 do
    t.setCursorPos(x, y + i)
    t.write(rep(w))
  end
end

function M.label(t, x, y, text, fg, bg)
  if bg then t.setBackgroundColor(bg) end
  t.setTextColor(fg or colors.white)
  t.setCursorPos(x, y)
  t.write(tostring(text or ""))
end

function M.center(t, y, text, fg, bg)
  local w = ({t.getSize()})[1]
  local s = tostring(text or "")
  local x = math.max(1, math.floor((w - #s)/2) + 1)
  M.label(t, x, y, s, fg, bg)
end

function M.trunc(s, max)
  s = tostring(s or "")
  max = max or #s
  if #s <= max then return s end
  if max <= 1 then return s:sub(1, max) end
  return s:sub(1, max-1) .. "…"
end

function M.wrap(s, max)
  s = tostring(s or "")
  max = max or 20
  local out = {}
  for line in s:gmatch("([^\n]*)\n?") do
    if line == "" and #out > 0 then break end
    local cur = line
    while #cur > max do
      table.insert(out, cur:sub(1, max))
      cur = cur:sub(max+1)
    end
    table.insert(out, cur)
  end
  return out
end

-- ===== buttons / hit tests =====

function M.button(t, x, y, w, h, label, bg, fg)
  M.panel(t, x, y, w, h, bg or colors.gray)
  local s = tostring(label or "")
  local tx = x + math.max(0, math.floor((w - #s)/2))
  local ty = y + math.floor((h-1)/2)
  M.label(t, tx, ty, M.trunc(s, w), fg or colors.white, bg or colors.gray)
end

function M.hit(x, y, b)
  return x>=b.x and x<=b.x+b.w-1 and y>=b.y and y<=b.y+b.h-1
end

function M.hitRect(x, y, r)
  return x >= r.x1 and x <= r.x2 and y >= r.y1 and y <= r.y2
end

-- ===== modern bits =====

function M.badge(t, x, y, text, bg, fg)
  local s = " " .. tostring(text or "") .. " "
  M.panel(t, x, y, #s, 1, bg or colors.gray)
  M.label(t, x, y, s, fg or colors.white, bg or colors.gray)
  return #s
end

function M.hline(t, y, bg)
  local w = ({t.getSize()})[1]
  M.panel(t, 1, y, w, 1, bg or colors.black)
end

return M
