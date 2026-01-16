local config = require("config")
local S = require("state")
local state, ensureRoom, ensurePeer = S.state, S.ensureRoom, S.ensurePeer

local ui = {}

local buttons = {}

local function clamp(n,a,b) if n<a then return a elseif n>b then return b else return n end end
local function padRight(s,w) s=tostring(s or ""); if #s>=w then return s:sub(1,w) end; return s..string.rep(" ", w-#s) end
local function size() return term.getSize() end

local function drawBox(x,y,w,h,bg)
  term.setBackgroundColor(bg or colors.black)
  for yy=y,y+h-1 do
    term.setCursorPos(x,yy)
    term.write(string.rep(" ", w))
  end
end

local function writeAt(x,y,s,fg,bg)
  if fg then term.setTextColor(fg) end
  if bg then term.setBackgroundColor(bg) end
  term.setCursorPos(x,y)
  term.write(s)
end

local function hLine(y, fg, bg)
  local w = select(1, size())
  drawBox(1,y,w,1,bg or colors.black)
  writeAt(1,y,string.rep("c", w), fg or colors.gray, bg or colors.black)
end

local function button(x,y,w,label,id,isActive)
  local bg = isActive and colors.cyan or colors.gray
  local fg = isActive and colors.black or colors.white
  drawBox(x,y,w,1,bg)
  local txt = label
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

local function getLogLines()
  local w,h = size()
  local top, bottom = 5, h-2
  local avail = bottom-top+1

  if state.tab == "chat" then
    ensureRoom(state.room)
    local log = state.chatLogByRoom[state.room]
    local total = #log
    local start = clamp(total - avail - state.scroll + 1, 1, math.max(total,1))
    local stop = clamp(start + avail - 1, 1, total)
    return log, start, stop, top, bottom
  elseif state.tab == "dm" then
    if not state.activePeer then return {},1,0,top,bottom end
    ensurePeer(state.activePeer)
    local log = state.dmLogByPeer[tostring(state.activePeer)]
    local total = #log
    local start = clamp(total - avail - state.scroll + 1, 1, math.max(total,1))
    local stop = clamp(start + avail - 1, 1, total)
    return log, start, stop, top, bottom
  end

  return {},1,0,top,bottom
end

function ui.redraw()
  local w,h = size()
  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.white)
  term.clear()

  local btns = {}

  drawBox(1,1,w,1,colors.lightGray)
  writeAt(2,1,"VibeChat",colors.black,colors.lightGray)
  local right = state.connected and ("#"..tostring(state.call or "?")) or "OFFLINE"
  writeAt(w-#right,1,right,state.connected and colors.green or colors.red,colors.lightGray)

  drawBox(1,2,w,1,colors.black)
  local tabW = math.floor(w/4)
  btns[#btns+1] = button(1,2,tabW,"CHAT","tab_chat",state.tab=="chat")
  btns[#btns+1] = button(1+tabW,2,tabW,"DM","tab_dm",state.tab=="dm")
  btns[#btns+1] = button(1+tabW*2,2,tabW,"CONTACTS","tab_contacts",state.tab=="contacts")
  btns[#btns+1] = button(1+tabW*3,2,w-(tabW*3),"SETTINGS","tab_settings",state.tab=="settings")

  hLine(3, colors.gray, colors.black)

  if state.tab == "chat" then
    local x = 1
    local btnW = math.max(8, math.floor(w/3))
    for i, room in ipairs(config.QUICK_ROOMS) do
      local ww = (i == #config.QUICK_ROOMS) and (w-x+1) or btnW
      btns[#btns+1] = button(x,4,ww,room:sub(2):upper(),"room_"..room,state.room==room)
      x = x + ww
      if x > w then break end
    end
  elseif state.tab == "dm" then
    local half = math.floor(w/2)
    btns[#btns+1] = button(1,4,half,"PICK DM","dm_pick",false)
    btns[#btns+1] = button(1+half,4,w-half,"CLEAR","dm_clear",false)
  elseif state.tab == "contacts" then
    btns[#btns+1] = button(1,4,w,"REFRESH","contacts_refresh",false)
  elseif state.tab == "settings" then
    local half = math.floor(w/2)
    btns[#btns+1] = button(1,4,half,"SET NAME","set_name",false)
    btns[#btns+1] = button(1+half,4,w-half,"RECONNECT","reconnect",false)
  end

  local top, bottom = 5, h-2
  drawBox(1,top,w,bottom-top+1,colors.black)

  if state.tab == "chat" or state.tab == "dm" then
    local log, start, stop = getLogLines()
    local y = top
    for i=start, stop do
      local line = tostring(log[i] or "")
      if #line > w then line = line:sub(1,w) end
      writeAt(1,y,padRight(line,w),colors.white,colors.black)
      y = y + 1
    end
  elseif state.tab == "contacts" then
    writeAt(1,top,padRight(" Online users (tap to DM) ",w),colors.black,colors.lightGray)
    local y = top + 1
    for _,u in ipairs(state.directory) do
      if y > bottom then break end
      local label = string.format(" #%d  %s", u.call, u.name or ("User-"..u.call))
      writeAt(1,y,padRight(label,w),colors.white,colors.black)
      y = y + 1
    end
  elseif state.tab == "settings" then
    writeAt(1,top,padRight(" Settings ",w),colors.black,colors.lightGray)
    writeAt(1,top+1,padRight("ESC clears input. PgUp/PgDn scroll.",w),colors.gray,colors.black)
    writeAt(1,top+3,padRight("Name: "..tostring(state.name or ("User-"..tostring(state.call or "?"))),w),colors.white,colors.black)
    writeAt(1,top+4,padRight("Connected: "..tostring(state.connected),w),colors.white,colors.black)
  end

  drawBox(1,h-1,w,1,colors.black)
  local prompt = "> "
  local roomInfo = ""
  if state.tab == "chat" then roomInfo = " "..tostring(state.room or "#?") end
  if state.tab == "dm" then roomInfo = " DM:"..tostring(state.activePeer or "?") end

  local show = prompt .. tostring(state.input or "")
  if #show > w-#roomInfo then show = show:sub(#show-(w-#roomInfo)+1) end
  writeAt(1,h-1,padRight(show,w-#roomInfo),colors.white,colors.black)
  if #roomInfo > 0 then writeAt(w-#roomInfo+1,h-1,roomInfo,colors.cyan,colors.black) end

  drawBox(1,h,w,1,colors.black)
  writeAt(1,h,padRight(tostring(state.status or ""),w),colors.lightGray,colors.black)

  setButtons(btns)
end

return ui
