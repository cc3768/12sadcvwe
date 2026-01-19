-- VibePhone AppStore (HTTP-based)
-- Fix: installs actually copy files AND adds installed apps to the Home screen automatically
dofile("/vibephone/require_shim.lua")

local config = require("/vibephone/config")
local ui = require("/vibephone/ui")
local storage = require("/vibephone/storage")

local phoneState = storage.load()

local S = {
  status = "Starting...",
  apps = {},
  selected = 1,
  detail = false,
  online = false,
}

local REGISTRY_PATH = "/vibephone/apps_registry.json" -- persisted app metadata for Home screen

local function jdecode(s) return textutils.unserializeJSON(s) end
local function jencode(t) return textutils.serializeJSON(t) end

local function trimSlash(s)
  s = tostring(s or "")
  s = s:gsub("%s+$","")
  while s:sub(-1) == "/" do s = s:sub(1, -2) end
  return s
end

-- Prefer explicit HTTP base; otherwise derive from ws://... by swapping scheme.
local function getHttpBase()
  if config.APPSTORE_HTTP_BASE and tostring(config.APPSTORE_HTTP_BASE) ~= "" then
    return trimSlash(config.APPSTORE_HTTP_BASE)
  end

  local ws = tostring(config.APPSTORE_WS_URL or "")
  if ws ~= "" then
    ws = ws:gsub("^wss://", "https://"):gsub("^ws://", "http://")
    -- IMPORTANT: websocket path is /ws, but HTTP API is at the site root
    ws = ws:gsub("/ws$", "")
    return trimSlash(ws)
  end

  return ""
end

local function httpGet(url)
  local h = http.get(url, { ["User-Agent"] = "VibePhone-AppStore" })
  if not h then return nil, "http.get failed" end
  local body = h.readAll()
  h.close()
  return body
end

local function ensureDir(path)
  if not fs.exists(path) then fs.makeDir(path) end
end

local function writeFile(path, content)
  fs.makeDir(fs.getDir(path))
  local f = fs.open(path, "w"); assert(f, "write failed: "..path)
  f.write(content or ""); f.close()
end

local function readFile(path)
  if not fs.exists(path) then return nil end
  local f = fs.open(path, "r"); if not f then return nil end
  local s = f.readAll(); f.close(); return s
end

local function loadRegistry()
  local raw = readFile(REGISTRY_PATH)
  if not raw then return {} end
  local ok, obj = pcall(function() return textutils.unserializeJSON(raw) end)
  if ok and type(obj) == "table" then return obj end
  return {}
end

local function saveRegistry(reg)
  writeFile(REGISTRY_PATH, jencode(reg or {}))
end

local function chooseAccent(id)
  -- stable “hash” into a small palette (keeps Home screen looking consistent)
  local palette = { colors.cyan, colors.purple, colors.orange, colors.lime, colors.lightBlue, colors.pink, colors.yellow }
  local s = tostring(id or "")
  local sum = 0
  for i=1,#s do sum = sum + s:byte(i) end
  return palette[(sum % #palette) + 1]
end

local function chooseGlyph(name, id)
  local s = tostring(name or "")
  s = s:gsub("^%s+",""):gsub("%s+$","")
  if #s > 0 then
    local c = s:sub(1,1):upper()
    if c:match("[%w]") then return c end
  end
  return "□"
end

local function upsertRegistryFromManifest(m)
  local reg = loadRegistry()

  local id = tostring(m.id or "")
  local name = tostring(m.name or id)
  local entryRel = tostring(m.entry or "main.lua")
  local installBase = tostring(m.installBase or "")
  if id == "" or installBase == "" then return end

  reg[id] = reg[id] or {}

  reg[id].id = id
  reg[id].name = name
  reg[id].entry = fs.combine(installBase, entryRel) -- absolute-ish path for launcher
  reg[id].multishell = true

  -- Preserve existing styling if already set; otherwise choose defaults
  reg[id].accent = reg[id].accent or chooseAccent(id)
  reg[id].glyph = reg[id].glyph or chooseGlyph(name, id)

  saveRegistry(reg)
end

local function upsertInstalledApp(id)
  id = tostring(id or "")
  if id == "" then return end
  phoneState.apps = phoneState.apps or { order = {} }
  phoneState.apps.order = phoneState.apps.order or {}

  for _,v in ipairs(phoneState.apps.order) do
    if v == id then return end
  end

  table.insert(phoneState.apps.order, id)
  storage.save(phoneState)
end

local function fetchApps()
  local base = getHttpBase()
  if base == "" then
    S.online = false
    S.status = "Missing APPSTORE base URL."
    return false
  end

  S.status = "Loading app list..."
  local raw = httpGet(base .. "/api/apps")
  if not raw then
    S.online = false
    S.status = "Network error (apps list)."
    return false
  end

  local obj = jdecode(raw)
  if not obj or obj.ok ~= true then
    S.online = false
    S.status = "Bad response (apps list)."
    return false
  end

  S.apps = obj.apps or {}
  table.sort(S.apps, function(a,b)
    return tostring(a.name or a.id) < tostring(b.name or b.id)
  end)

  if S.selected > #S.apps then S.selected = math.max(1, #S.apps) end
  S.online = true
  S.status = "Loaded "..tostring(#S.apps).." apps."
  return true
end

local function fetchManifest(appId)
  local base = getHttpBase()
  local raw = httpGet(base .. "/api/apps/" .. textutils.urlEncode(appId) .. "/manifest")
  if not raw then return nil, "network" end
  local obj = jdecode(raw)
  if not obj or obj.ok ~= true or type(obj.manifest) ~= "table" then
    return nil, "bad_manifest"
  end
  return obj.manifest
end

local function fetchFile(appId, relPath)
  local base = getHttpBase()
  local url = base .. "/api/apps/" .. textutils.urlEncode(appId) .. "/file/" .. textutils.urlEncode(relPath)
  return httpGet(url)
end

local function installFromManifest(m)
  local id = tostring(m.id or "")
  local basePath = tostring(m.installBase or "")
  local files = m.files

  if id == "" or basePath == "" or type(files) ~= "table" then
    S.status = "Manifest missing fields."
    return false
  end

  ensureDir(basePath)

  local total = #files
  if total == 0 then
    S.status = "No files in manifest."
    return false
  end

  for i=1,total do
    local rel = tostring(files[i] or "")
    if rel ~= "" then
      S.status = ("Fetching %s (%d/%d)..."):format(rel, i, total)

      local body = fetchFile(id, rel)
      if not body then
        S.status = "Fetch failed: "..rel
        return false
      end

      local outPath = fs.combine(basePath, rel)
      writeFile(outPath, body)
    end
  end

  -- ✅ Make it appear on the Home screen
  upsertRegistryFromManifest(m)
  upsertInstalledApp(id)

  S.status = "Installed: "..id.." v"..tostring(m.version or "?")
  return true
end

local function draw()
  ui.clearButtons()
  local w,h = term.getSize()
  ui.fill(config.C_BG)
  ui.statusBar("App Store", S.online and "ONLINE" or "OFFLINE")
  ui.divider(3, config.C_MUTED, config.C_BG)

  local listTop = 4
  local listBottom = h - 3
  local listH = listBottom - listTop + 1

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
      tostring(a.description or ""),
      "",
      "Install: "..tostring(a.installBase or "")
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

math.randomseed(os.epoch("utc") or os.time())
fetchApps()

while true do
  draw()
  local e,a,b,c = os.pullEvent()
  if e == "mouse_click" then
    local id = ui.hit(b,c)
    if not id then
      if S.detail then S.detail = false end
    elseif id == "exit" then
      return
    elseif id == "refresh" then
      fetchApps()
    elseif id == "details" then
      S.detail = true
    elseif id == "close_detail" then
      S.detail = false
    elseif id == "install" then
      local app = S.apps[S.selected]
      if app and app.id then
        S.detail = false
        S.status = "Fetching manifest..."
        local m, err = fetchManifest(app.id)
        if not m then
          S.online = false
          S.status = "Manifest error: "..tostring(err)
        else
          S.online = true
          installFromManifest(m)
        end
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
      if app and app.id then
        S.status = "Fetching manifest..."
        local m, err = fetchManifest(app.id)
        if not m then
          S.online = false
          S.status = "Manifest error: "..tostring(err)
        else
          S.online = true
          installFromManifest(m)
        end
      end
    elseif a == keys.escape then
      if S.detail then S.detail = false else return end
    end
  end
end
