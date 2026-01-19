-- /vibephone/apps/vibechat/main.lua
local entry = (...) or (shell and shell.getRunningProgram and shell.getRunningProgram()) or "/vibephone/apps/vibechat/main.lua"
_G.__VC_ENTRY = entry
dofile(fs.combine(fs.getDir(entry), "require_shim.lua"))

local config = require("config")
local S = require("state")
local state = S.state
local net = require("net")
local ui = require("ui")

local function redraw()
  ui.redraw()
end

local function clampScroll()
  local info = ui.getScrollInfo()
  state.scroll = math.max(0, math.min(state.scroll or 0, info.maxScroll or 0))
end

local function setTab(t)
  state.tab = t
  state.scroll = 0
  state.status = "Tab: " .. t
  redraw()
end

local function setActivePeer(call)
  state.activePeer = call
  state.scroll = 0
  state.status = "DM with #"..tostring(call)
  net.setLastPeer(call)
  redraw()
end

local function promptText(title)
  state.status = title
  state.input = ""
  redraw()

  while true do
    local e,a,b,c = os.pullEvent()
    if e == "char" then
      state.input = state.input .. a
      redraw()
    elseif e == "key" then
      if a == keys.backspace then
        state.input = state.input:sub(1, math.max(#state.input-1, 0))
        redraw()
      elseif a == keys.enter then
        local out = state.input
        state.input = ""
        redraw()
        return out
      elseif a == keys.escape then
        state.input = ""
        redraw()
        return nil
      end
    end
  end
end

local function joinRoom(room)
  if not room:match("^#") then room = "#" .. room end
  net.wsSend({ t="join", room=room })
  state.room = room
  state.scroll = 0
  state.status = "Joining " .. room
  redraw()
end

local function sendCurrentInput()
  local text = tostring(state.input or ""):gsub("^%s+",""):gsub("%s+$","")
  state.input = ""
  if text == "" then redraw(); return end
  if #text > config.MAX_TEXT then text = text:sub(1, config.MAX_TEXT) end

  if state.tab == "chat" then
    net.wsSend({ t="chat", room=state.room, text=text })
  elseif state.tab == "dm" then
    if state.activePeer then
      net.wsSend({ t="dm", to=state.activePeer, text=text })
    else
      state.status = "Pick a DM target first."
    end
  else
    state.status = "Type in Chat or DM tab."
  end
  redraw()
end

local function uiTap(x,y)
  local id = ui.hit(x,y)

  if not id then
    -- tap-to-DM in Contacts list
    if state.tab == "contacts" then
      local w,h = term.getSize()
      local top, bottom = 4, math.max(4, h-2)
      if y >= top+1 and y <= bottom then
        local idx = (y - (top+1)) + 1
        local u = (state.directory or {})[idx]
        if u and state.call and u.call ~= state.call then
          setTab("dm")
          setActivePeer(u.call)
        end
      end
    end
    return
  end

  if id == "tab_chat" then return setTab("chat") end
  if id == "tab_dm" then return setTab("dm") end
  if id == "tab_contacts" then return setTab("contacts") end
  if id == "tab_settings" then return setTab("settings") end

  if id:match("^room_") then
    local room = id:sub(6)
    return joinRoom(room)
  end

  if id == "dm_pick" then
    local s = promptText("Enter call # (ESC cancel)")
    if not s then state.status="Cancelled"; redraw(); return end
    local n = tonumber(s)
    if n then setActivePeer(n) else state.status="Not a number."; redraw() end
    return
  end

  if id == "dm_clear" then
    if state.activePeer then
      state.dmLogByPeer[tostring(state.activePeer)] = {}
      state.scroll = 0
      state.status = "DM cleared."
      redraw()
    end
    return
  end

  if id == "contacts_refresh" then
    net.wsSend({ t="directory" })
    state.status = "Refreshing users..."
    redraw()
    return
  end

  if id == "set_name" then
    local s = promptText("Set name (ESC cancel)")
    if not s then state.status="Cancelled"; redraw(); return end
    s = s:gsub("^%s+",""):gsub("%s+$","")
    net.wsSend({ t="set_name", name=s })
    net.setSavedName(s)
    state.name = s
    state.status = "Setting name..."
    redraw()
    return
  end

  if id == "reconnect" then
    net.connect(redraw)
    return
  end
end

local function scrollBy(delta)
  state.scroll = (state.scroll or 0) + delta
  clampScroll()
  redraw()
end

local function uiLoop()
  redraw()
  while true do
    local e,a,b,c = os.pullEvent()

    if e == "term_resize" then
      clampScroll()
      redraw()

    elseif e == "mouse_click" then
      uiTap(b,c)

    elseif e == "mouse_scroll" then
      -- a == 1 scroll down (older), a == -1 scroll up (newer)
      if a == 1 then scrollBy(3) else scrollBy(-3) end

    elseif e == "char" then
      state.input = (state.input or "") .. a
      redraw()

    elseif e == "key" then
      if a == keys.backspace then
        state.input = tostring(state.input or ""):sub(1, math.max(#tostring(state.input or "")-1, 0))
        redraw()

      elseif a == keys.enter then
        sendCurrentInput()
        clampScroll()

      elseif a == keys.pageUp then
        scrollBy(6)

      elseif a == keys.pageDown then
        scrollBy(-6)

      elseif a == keys.escape then
        state.input = ""
        state.status = "Cleared input."
        redraw()
      end
    end
  end
end

term.setBackgroundColor(colors.black)
term.setTextColor(colors.white)
term.clear()

net.connect(redraw)
parallel.waitForAny(function() net.netLoop(redraw) end, uiLoop)
