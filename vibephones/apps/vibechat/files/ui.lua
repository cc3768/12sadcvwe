-- /vibephone/apps/vibechat/ui.lua
-- Pocket-friendly UI (fits Advanced Pocket Computer screens) + text wrap in log window
local config = require("config")
local S = require("state")
local state, ensureRoom, ensurePeer = S.state, S.ensureRoom, S.ensurePeer

local ui = {}

local buttons = {}

local function clamp(n,a,b) if n<a then return a elseif n>b then return b else return n end end
local function padRight(s,w)
  s = tostring(s or "")
  if #s >= w then return s:sub(1,w) end
  return s .. string.rep(" ", w-#s)
end

local function size() return term.getSize() end

local function drawBox(x,y,w,h,bg)
  local tw, th = size()
  if w <= 0 or h <= 0 then return end
  if x > tw or y > th then return end
  if x < 1 then w = w - (1-x); x = 1 end
  if y < 1 then h = h - (1-y); y = 1 end
  w = math.min(w, tw - x + 1)
  h = math.min(h, th - y + 1)
  if w <= 0 or h <= 0 then return end

  term.setBackgroundColor(bg or colors.black)
  for yy=y, y+h-1 do
    term.setCursorPos(x,yy)
    term.write(string.rep(" ", w))
  end
end

local function writeAt(x,y,s,fg,bg)
  local tw, th = size()
  if y < 1 or y > th then return end
  if x < 1 then
    s = tostring(s or "")
    local cut = 1-x
    if cut >= #s then return end
    s = s:sub(cut+1)
    x = 1
  end
  if x > tw then return end

  s = tostring(s or "")
  if #s > (tw - x + 1) then s = s:sub(1, tw - x + 1) end
  if fg then term.setTextColor(fg) end
  if bg then term.setBackgroundColor(bg) end
  term.setCursorPos(x,y)
  term.write(s)
end

local function hLine(y, fg, bg)
  local w = select(1, size())
  drawBox(1,y,w,1,bg or colors.black)
  writeAt(1,y,string.rep("-", w), fg or colors.gray, bg or colors.black)
end

local function button(x,y,w,label,id,isActive)
  w = math.max(1, w)
  local bg = isActive and colors.cyan or colors.gray
  local fg = isActive and colors.black or colors.white
  drawBox(x,y,w,1,bg)
  local txt = tostring(label or "")
  if #txt > w then txt = txt:sub(1,w) end
  local px = x + math.floor((w-#txt)/2)
  writeAt(px,y,txt,fg,bg)
  return { id=id, x=x, y=y, w=w, h=1 }
end

local function setButtons(list) buttons = list end

function ui.hit(px,py)
  for _,b in ipairs(buttons) do
    if px>=b.x and px<b.x+b.w and py>=b.y and py<b.y+b.h then return b.id end
  end
  return nil
end

local function getLogWindow()
  local w,h = size()
  -- 1: title, 2: tabs, 3: context buttons, 4..(h-2): log, h-1 input, h status
  local top = 4
  local bottom = math.max(top, h-2)
  local avail = bottom - top + 1
  return w,h,top,bottom,avail
end

-- Simple hard wrap (keeps timestamps intact; wraps by width)
local function wrapHard(s, w)
  s = tostring(s or "")
  if w <= 1 then return { s:sub(1,1) } end
  if #s <= w then return { s } end

  local out = {}
  local i = 1
  while i <= #s do
    out[#out+1] = s:sub(i, i+w-1)
    i = i + w
  end
  return out
end

-- Build wrapped visual lines for current view (chat/dm)
local function buildVisualLogLines(w)
  local visual = {}

  if state.tab == "chat" then
    ensureRoom(state.room)
    local log = state.chatLogByRoom[state.room] or {}
    for i=1, #log do
      local segs = wrapHard(log[i], w)
      for j=1, #segs do visual[#visual+1] = segs[j] end
    end
  elseif state.tab == "dm" then
    if not state.activePeer then return visual end
    ensurePeer(state.activePeer)
    local log = state.dmLogByPeer[tostring(state.activePeer)] or {}
    for i=1, #log do
      local segs = wrapHard(log[i], w)
      for j=1, #segs do visual[#visual+1] = segs[j] end
    end
  end

  return visual
end

-- Exposed helpers so main.lua can clamp scroll based on wrapped lines
function ui.getScrollInfo()
  local w,_,_,_,viewLines = getLogWindow()
  if state.tab ~= "chat" and state.tab ~= "dm" then
    return { total = 0, view = viewLines, maxScroll = 0 }
  end
  local visual = buildVisualLogLines(w)
  local total = #visual
  local maxScroll = math.max(0, total - viewLines)
  return { total = total, view = viewLines, maxScroll = maxScroll }
end

function ui.redraw()
  local w,h = size()
  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.white)
  term.clear()

  local btns = {}

  -- Row 1: title + status
  drawBox(1,1,w,1,colors.lightGray)
  writeAt(2,1,"VC",colors.black,colors.lightGray)
  local right = state.connected and ("#"..tostring(state.call or "?")) or "OFF"
  writeAt(w-#right,1,right,state.connected and colors.green or colors.red,colors.lightGray)

  -- Row 2: tabs (short labels for pocket)
  drawBox(1,2,w,1,colors.black)
  local tabW = math.max(4, math.floor(w/4))
  local x = 1
  btns[#btns+1] = button(x,2,tabW,"C","tab_chat",state.tab=="chat"); x = x + tabW
  btns[#btns+1] = button(x,2,tabW,"D","tab_dm",state.tab=="dm"); x = x + tabW
  btns[#btns+1] = button(x,2,tabW,"U","tab_contacts",state.tab=="contacts"); x = x + tabW
  btns[#btns+1] = button(x,2,w-x+1,"S","tab_settings",state.tab=="settings")

  hLine(3, colors.gray, colors.black)

  -- Row 3: context buttons
  if state.tab == "chat" then
    local count = #(config.QUICK_ROOMS or {})
    if count > 0 then
      local bw = math.max(6, math.floor(w / count))
      local cx = 1
      for i, room in ipairs(config.QUICK_ROOMS) do
        local label = room:gsub("^#","")
        label = (#label > 3) and label:sub(1,3) or label
        local ww = (i == count) and (w - cx + 1) or bw
        btns[#btns+1] = button(cx,3,ww,label:upper(),"room_"..room,state.room==room)
        cx = cx + ww
        if cx > w then break end
      end
    end
  elseif state.tab == "dm" then
    local half = math.floor(w/2)
    btns[#btns+1] = button(1,3,half,"PICK","dm_pick",false)
    btns[#btns+1] = button(1+half,3,w-half,"CLR","dm_clear",false)
  elseif state.tab == "contacts" then
    btns[#btns+1] = button(1,3,w,"REF","contacts_refresh",false)
  elseif state.tab == "settings" then
    local half = math.floor(w/2)
    btns[#btns+1] = button(1,3,half,"NAME","set_name",false)
    btns[#btns+1] = button(1+half,3,w-half,"RECON","reconnect",false)
  end

  -- Log window
  local _,_,top,bottom,viewLines = getLogWindow()
  drawBox(1,top,w,bottom-top+1,colors.black)

  if state.tab == "chat" or state.tab == "dm" then
    local visual = buildVisualLogLines(w)
    local total = #visual
    local scroll = clamp(state.scroll or 0, 0, math.max(0, total - viewLines))
    state.scroll = scroll

    local start = math.max(1, total - viewLines - scroll + 1)
    local stop  = math.min(total, start + viewLines - 1)

    local y = top
    for i=start, stop do
      writeAt(1,y,padRight(visual[i] or "", w),colors.white,colors.black)
      y = y + 1
    end

  elseif state.tab == "contacts" then
    writeAt(1,top,padRight("Users (tap)",w),colors.black,colors.lightGray)
    local y = top + 1
    for _,u in ipairs(state.directory or {}) do
      if y > bottom then break end
      local label = string.format("#%d %s", u.call, u.name or ("U-"..u.call))
      writeAt(1,y,padRight(label,w),colors.white,colors.black)
      y = y + 1
    end

  elseif state.tab == "settings" then
    writeAt(1,top,padRight("Settings",w),colors.black,colors.lightGray)
    writeAt(1,top+1,padRight("ESC clr | PgUp/Dn scr",w),colors.gray,colors.black)
    writeAt(1,top+2,padRight("Name: "..tostring(state.name or ("U-"..tostring(state.call or "?"))),w),colors.white,colors.black)
    writeAt(1,top+3,padRight("Conn: "..tostring(state.connected),w),colors.white,colors.black)
  end

  -- Input row (h-1)
  drawBox(1,h-1,w,1,colors.black)
  local prompt = ">"
  local suffix = ""
  if state.tab == "chat" then suffix = tostring(state.room or "#?")
  elseif state.tab == "dm" then suffix = "DM:"..tostring(state.activePeer or "?")
  end
  if #suffix > 0 then suffix = " " .. suffix end

  local show = prompt .. tostring(state.input or "")
  local maxLeft = math.max(1, w - #suffix)
  if #show > maxLeft then show = show:sub(#show-maxLeft+1) end
  writeAt(1,h-1,padRight(show,maxLeft),colors.white,colors.black)
  if #suffix > 0 then writeAt(w-#suffix+1,h-1,suffix,colors.cyan,colors.black) end

  -- Status row (h)
  drawBox(1,h,w,1,colors.black)
  writeAt(1,h,padRight(tostring(state.status or ""),w),colors.lightGray,colors.black)

  setButtons(btns)
end

return ui
