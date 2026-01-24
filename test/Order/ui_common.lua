local M = {}

-- =========================================================
-- Core primitives (backwards compatible)
-- =========================================================

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
  t.write(tostring(text or ""))
end

function M.button(t, x, y, w, h, label, bg, fg)
  M.panel(t, x, y, w, h, bg)
  t.setTextColor(fg or colors.white)
  local ly = y + math.floor(h / 2)
  local s = tostring(label or "")
  if #s > w - 2 then s = s:sub(1, w - 2) end
  t.setCursorPos(x + 1, ly)
  t.write(s)
end

-- Hit test old format {x,y,w,h}
function M.hit(x, y, b)
  return x >= b.x and x <= b.x + b.w - 1 and y >= b.y and y <= b.y + b.h - 1
end

-- Hit test rect format {x1,x2,y1,y2}
function M.hitRect(x, y, r)
  return x >= r.x1 and x <= r.x2 and y >= r.y1 and y <= r.y2
end

-- =========================================================
-- Helpers (new)
-- =========================================================

function M.clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

function M.trunc(s, maxLen)
  s = tostring(s or "")
  if #s <= maxLen then return s end
  if maxLen <= 1 then return s:sub(1, maxLen) end
  return s:sub(1, maxLen - 1) .. "…"
end

function M.center(t, y, text, fg, bg)
  local w = ({t.getSize()})[1]
  local s = tostring(text or "")
  local x = math.max(1, math.floor((w - #s) / 2) + 1)
  M.label(t, x, y, s, fg, bg)
end

function M.box(t, x, y, w, h, border, fill)
  if fill then M.panel(t, x, y, w, h, fill) end
  t.setBackgroundColor(border or colors.gray)
  for i = 0, h - 1 do
    t.setCursorPos(x, y + i)
    if i == 0 or i == h - 1 then
      t.write((" "):rep(w))
    else
      t.write(" ")
      t.setCursorPos(x + w - 1, y + i)
      t.write(" ")
    end
  end
end

function M.wrapLines(text, width, maxLines)
  text = tostring(text or "")
  width = math.max(1, width or 1)
  local words = {}
  for w in text:gmatch("%S+") do words[#words+1] = w end

  local lines, line = {}, ""
  local function push()
    lines[#lines+1] = line
    line = ""
  end

  for i = 1, #words do
    local w = words[i]
    if #w > width then
      -- hard split long token
      local j = 1
      while j <= #w do
        local chunk = w:sub(j, j + width - 1)
        if line ~= "" then push() end
        line = chunk
        push()
        j = j + width
        if maxLines and #lines >= maxLines then return lines end
      end
    else
      if line == "" then
        line = w
      elseif #line + 1 + #w <= width then
        line = line .. " " .. w
      else
        push()
        line = w
      end
    end

    if maxLines and #lines >= maxLines then return lines end
  end

  if line ~= "" and (not maxLines or #lines < maxLines) then
    push()
  end

  return lines
end

return M
