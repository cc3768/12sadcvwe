dofile("/vibephone/require_shim.lua")
local config = require("/vibephone/config")
local ui = require("/vibephone/ui")
local storage = require("/vibephone/storage")

local state = storage.load()

local S = {
  ws = nil,
  connected = false,
  status = "Connecting...",
  apps = {},
  selected = 1,
  detail = false
}

local function jencode(t) return textutils.serializeJSON(t) end
local function jdecode(s) return textutils.unserializeJSON(s) end

local function wsSend(obj)
  if not S.ws or not S.connected then return false end
  local ok = pcall(function() S.ws.send(jencode(obj)) end)
  return ok
end

local function connect()
  S.status = "Connecting..."
  S.connected = false
  if S.ws then pcall(function() S.ws.close() end) end
  S.ws = nil

  local ws, err
  local ok = pcall(function() ws = http.websocket(config.APPSTORE_WS_URL) end)
  if not ok or not ws then
    S.status = "Connect failed: "..tostring(err)
    return false
  end
  S.ws = ws
  S.connected = true
  S.status = "Connected."
  return true
end

local function ensureDir(path)
  if not fs.exists(path) then fs.makeDir(path) end
end

local function writeFile(path, content)
  fs.makeDir(fs.getDir(path))
  local f = fs.open(path, "w"); assert(f, "write failed: "..path)
  f.write(content); f.close()
end

local function installBundle(bundle)
  local base = tostring(bundle.installBase or "")
  if base == "" then
    S.status = "Bundle missing installBase."
    return false
  end

  ensureDir(base)

  for _,file in ipairs(bundle.files or {}) do
    local rel = tostring(file.path or "")
    local b64 = tostring(file.b64 or "")
    if rel ~= "" and b64 ~= "" then
      local decoded = textutils.decodeBase64(b64)
      local outPath = fs.combine(base, rel)
      writeFile(outPath, decoded)
    end
  end

  -- ensure app appears on home
  local id = tostring(bundle.id or "")
  if id ~= "" then
    local found = false
    for _,v in ipairs(state.apps.order or {}) do if v == id then found = true end end
    if not found then
      state.apps.order[#state.apps.order+1] = id
      storage.save(state)
    end
  end

  return true
end

local function requestList()
  wsSend({ t="apps_list" })
  S.status = "Requesting app list..."
end

local function requestApp(id)
  wsSend({ t="app_fetch", id=id })
  S.status = "Fetching "..id.."..."
end

local function draw()
  ui.clearButtons()
  local w,h = term.getSize()
  ui.fill(config.C_BG)
  ui.statusBar("App Store", S.connected and "ONLINE" or "OFFLINE")

  local top = 3
  ui.divider(top, config.C_MUTED, config.C_BG)

  local listTop = top + 1
  local listBottom = h - 3
  local listH = listBottom - listTop + 1

  -- header row
  ui.text(2,listTop,"Apps",config.C_MUTED,config.C_BG)
  local refresh = "Refresh"
  ui.text(w-#refresh-1, listTop, refresh, config.C_ACCENT, config.C_BG)
  ui.addButton("refresh", w-#refresh-1, listTop, #refresh, 1)

  local y = listTop + 1
  for i=1,math.min(#S.apps, listH-2) do
    local app = S.apps[i]
    local sel = (i == S.selected)
    local bg = sel and config.C_SURFACE_2 or config.C_BG
    local fg = sel and colors.black or config.C_TEXT

    ui.box(1,y,w,1,bg)
    local line = string.format("%s  v%s", app.name or app.id, app.version or "?")
    if #line > w-2 then line = line:sub(1,w-2) end
    ui.text(2,y,line,fg,bg)
    ui.addButton("sel_"..tostring(i), 1,y,w,1)
    y = y + 1
  end

  -- bottom actions
  ui.box(1,h-1,w,2,config.C_SURFACE_2)
  local actY = h-1
  local bW = math.max(8, math.floor(w/3)-1)

  local b1x = 2
  local b2x = b1x + bW + 1
  local b3x = b2x + bW + 1

  ui.box(b1x,actY,bW,1,config.C_ACCENT); ui.text(b1x+2,actY,"Install/Update",colors.black,config.C_ACCENT)
  ui.addButton("install", b1x,actY,bW,1)

  ui.box(b2x,actY,bW,1,config.C_SURFACE); ui.text(b2x+2,actY,"Details",config.C_TEXT,config.C_SURFACE)
  ui.addButton("details", b2x,actY,bW,1)

  ui.box(b3x,actY,bW,1,config.C_SURFACE); ui.text(b3x+2,actY,"Exit",config.C_TEXT,config.C_SURFACE)
  ui.addButton("exit", b3x,actY,bW,1)

  -- status line
  local s = tostring(S.status or "")
  if #s > w-2 then s = s:sub(1,w-2) end
  ui.text(2,h,s,colors.black,config.C_SURFACE_2)

  if S.detail and S.apps[S.selected] then
    local a = S.apps[S.selected]
    local bx, by, bw, bh = 3, math.floor(h*0.25), w-4, math.floor(h*0.5)
    ui.box(bx,by,bw,bh,config.C_SURFACE)
    ui.box(bx,by,bw,1,config.C_ACCENT)
    ui.text(bx+2,by,"Details",colors.black,config.C_ACCENT)

    local lines = {
      "ID: "..tostring(a.id),
      "Name: "..tostring(a.name),
      "Version: "..tostring(a.version),
      "",
      tostring(a.description or "")
    }
    local yy = by + 2
    for _,ln in ipairs(lines) do
      if yy > by+bh-2 then break end
      local s2 = tostring(ln)
      if #s2 > bw-2 then s2 = s2:sub(1,bw-2) end
      ui.text(bx+1,yy,s2,config.C_TEXT,config.C_SURFACE)
      yy = yy + 1
    end
    ui.text(bx+2,by+bh-1,"(tap anywhere to close)",config.C_MUTED,config.C_SURFACE)
    ui.addButton("close_detail", bx,by,bw,bh)
  end
end

local function handleServer(msg)
  if msg.t == "apps_list" then
    S.apps = msg.apps or {}
    table.sort(S.apps, function(a,b) return tostring(a.name or a.id) < tostring(b.name or b.id) end)
    if S.selected > #S.apps then S.selected = math.max(1, #S.apps) end
    S.status = "Loaded "..tostring(#S.apps).." apps."
    return
  end

  if msg.t == "app_bundle" then
    local ok = installBundle(msg)
    if ok then
      S.status = "Installed: "..tostring(msg.id).." v"..tostring(msg.version)
    else
      S.status = "Install failed for "..tostring(msg.id)
    end
    return
  end

  if msg.t == "app_error" then
    S.status = "Error: "..tostring(msg.error)
  end
end

-- Run
math.randomseed(os.epoch("utc") or os.time())

connect()
requestList()

while true do
  draw()
  local e,a,b,c = os.pullEvent()
  if e == "mouse_click" then
    local id = ui.hit(b,c)
    if not id then
      if S.detail then S.detail = false end
    elseif id == "exit" then
      if S.ws then pcall(function() S.ws.close() end) end
      return
    elseif id == "refresh" then
      if not S.connected then connect() end
      requestList()
    elseif id == "details" then
      S.detail = true
    elseif id == "close_detail" then
      S.detail = false
    elseif id == "install" then
      local app = S.apps[S.selected]
      if app then
        if not S.connected then connect() end
        requestApp(app.id)
      end
    elseif id:match("^sel_") then
      local n = tonumber(id:sub(5))
      if n then S.selected = n end
    end
  elseif e == "key" then
    if a == keys.up then S.selected = math.max(1, S.selected-1)
    elseif a == keys.down then S.selected = math.min(#S.apps, S.selected+1)
    elseif a == keys.enter then
      local app = S.apps[S.selected]
      if app then requestApp(app.id) end
    elseif a == keys.escape then
      if S.detail then S.detail = false else
        if S.ws then pcall(function() S.ws.close() end) end
        return
      end
    end
  elseif e == "websocket_message" then
    local url, message = a, b
    if S.ws and url == config.APPSTORE_WS_URL then
      local decoded = jdecode(message)
      if decoded then handleServer(decoded) end
    end
  elseif e == "websocket_closed" then
    S.connected = false
    S.status = "Disconnected."
  end
end
