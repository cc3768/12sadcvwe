-- /vibephone/screens/appstore.lua
-- UI-first placeholder that fits pocket screens.
-- Pulls available apps if server supports vp_store_list, otherwise shows local list.

local ui = require("ui")
local store = require("data_store")
local net = require("net")

local M = {}

local function ensureApps(data)
  data.apps = data.apps or {}
  data.apps.installed = data.apps.installed or {} -- { {id="messages", name="Messages"} ... }
  data.apps.available = data.apps.available or {} -- from server
end

local function save(cfg, data)
  store.save(cfg.dataFile, data)
end

local function drawHeader(theme, data, blinkOn)
  local w,_ = term.getSize()
  ui.fillRect(1, 1, w, 1, theme.surface)

  local connected = (data.serverId ~= nil)
  local dot = blinkOn and "●" or "○"
  local dotColor = connected and theme.accent or theme.muted

  ui.writeAt(2, 1, dot, dotColor, theme.surface)
  ui.writeAt(4, 1, "Store", theme.text, theme.surface)

  local title = (data.profile and data.profile.name) or "VibePhone"
  local tx = math.floor((w - #title) / 2) + 1
  ui.writeAt(tx, 1, title, theme.text, theme.surface)

  local num = data.number and ("#" .. tostring(data.number)) or "#----"
  ui.writeAt(w - #num - 1, 1, num, theme.muted, theme.surface)
end

local function drawDock(theme, active)
  local w,h = term.getSize()
  local y = h - 1

  ui.fillRect(1, y, w, 1, theme.surface)

  local items = {
    {id="home",     label="HOME"},
    {id="messages", label="MSG"},
    {id="appstore", label="STORE"},
    {id="settings", label="SET"},
  }

  local cellW = math.floor(w / #items)
  local btns = {}

  for i,it in ipairs(items) do
    local x = (i-1)*cellW + 1
    local ww = (i == #items) and (w - x + 1) or cellW

    local isActive = (active == it.id)
    local fg = isActive and theme.accent or theme.muted

    local tx = x + math.floor((ww - #it.label) / 2)
    ui.writeAt(tx, y, it.label, fg, theme.surface)

    btns[#btns+1] = {id=it.id, x=x, y=y, w=ww, h=1}
  end

  return btns
end

local function drawTabs(theme, tabIndex)
  local w,_ = term.getSize()
  ui.fillRect(1, 2, w, 2, theme.bg)

  local tabs = {"AVAILABLE","INSTALLED"}
  local cellW = math.floor(w / #tabs)
  local btns = {}

  for i,name in ipairs(tabs) do
    local x = (i-1)*cellW + 1
    local ww = (i == #tabs) and (w - x + 1) or cellW
    local active = (i == tabIndex)
    local fg = active and theme.text or theme.muted

    local tx = x + math.floor((ww - #name) / 2)
    ui.writeAt(tx, 2, name, fg, theme.bg)

    if active then ui.fillRect(x, 3, ww, 1, theme.accent) end
    btns[#btns+1] = {id=i, x=x, y=2, w=ww, h=2}
  end

  return btns
end

local function drawCard(theme, x, y, w, h)
  ui.fillRect(x, y, w, h, theme.line)
  ui.fillRect(x+1, y+1, w-2, h-2, theme.surface)
end

local function drawRow(theme, x, y, w, name, sub, focused)
  local bg = focused and theme.inner or theme.surface
  ui.fillRect(x, y, w, 2, bg)
  local t = tostring(name or "")
  if #t > w-3 then t = t:sub(1, w-3) end
  ui.writeAt(x+1, y, t, theme.text, bg)
  local s = tostring(sub or "")
  if #s > w-3 then s = s:sub(1, w-3) end
  ui.writeAt(x+1, y+1, s, theme.muted, bg)
  ui.writeAt(x+w-1, y, "›", focused and theme.accent or theme.muted, bg)
end

local function tryFetchStore(cfg, data)
  if not data.serverId then return false end
  local ok, resp = net.request(data, { type="vp_store_list", token=data.token }, 3.0)
  if not ok or type(resp) ~= "table" then return false end
  if resp.type ~= "vp_store_list_ok" or type(resp.apps) ~= "table" then return false end
  data.apps.available = resp.apps
  save(cfg, data)
  return true
end

function M.run(cfg, data)
  ensureApps(data)
  net.init(cfg)

  local tab = 1
  local focus = 1
  local scroll = 0

  local blinkOn = true
  local tick = 0
  local timerId = os.startTimer(0.25)

  while true do
    local theme = ui.getTheme(data)
    local w,h = term.getSize()

    ui.drawWallpaper(theme, (data.ui and data.ui.wallpaper) or "border")
    drawHeader(theme, data, blinkOn)
    local tabBtns = drawTabs(theme, tab)

    local cardX, cardY = 2, 5
    local cardW, cardH = w-2, (h - 5 - 2)
    if cardH < 8 then cardH = 8 end
    drawCard(theme, cardX, cardY, cardW-1, cardH)

    local list = {}
    if tab == 1 then
      for _,a in ipairs(data.apps.available or {}) do
        list[#list+1] = { name = a.name or a.id or "App", sub = (a.desc or "Tap to install"), id = a.id }
      end
      if #list == 0 then
        list[1] = { name = "No apps yet", sub = "Press R to refresh", id = nil }
      end
    else
      for _,a in ipairs(data.apps.installed or {}) do
        list[#list+1] = { name = a.name or a.id or "App", sub = "Installed", id = a.id }
      end
      if #list == 0 then
        list[1] = { name = "Nothing installed", sub = "Use Available tab", id = nil }
      end
    end

    local listX, listY, listW = cardX+1, cardY+1, cardW-3
    local visible = math.floor((cardH - 2) / 2)
    if visible < 1 then visible = 1 end

    scroll = math.max(0, math.min(scroll, math.max(0, #list - visible)))
    if focus < 1 then focus = 1 end
    if focus > #list then focus = #list end
    if focus <= scroll then scroll = math.max(0, scroll - 1) end
    if focus > scroll + visible then scroll = scroll + 1 end

    local hit = {}
    for i=1, visible do
      local idx = i + scroll
      local row = list[idx]
      if not row then break end
      local y = listY + (i-1)*2
      drawRow(theme, listX, y, listW, row.name, row.sub, idx == focus)
      hit[#hit+1] = { idx=idx, x=listX, y=y, w=listW, h=2 }
    end

    ui.fillRect(1, h-2, w, 1, theme.bg)
    ui.center(h-2, "R=Refresh  Enter=Select  Q=Back", theme.muted, theme.bg)
    local dock = drawDock(theme, "appstore")

    local e,a,b,c = os.pullEvent()

    if e == "timer" and a == timerId then
      tick = tick + 1
      blinkOn = (tick % 2 == 0)
      timerId = os.startTimer(0.25)

    elseif e == "key" then
      if a == keys.q or a == keys.escape then return "home" end
      if a == keys.left then tab = math.max(1, tab-1); focus, scroll = 1, 0 end
      if a == keys.right then tab = math.min(2, tab+1); focus, scroll = 1, 0 end
      if a == keys.up then focus = math.max(1, focus-1) end
      if a == keys.down then focus = math.min(#list, focus+1) end
      if a == keys.r then tryFetchStore(cfg, data) end
      if a == keys.enter then
        local row = list[focus]
        if tab == 1 and row and row.id then
          -- install request (optional)
          pcall(function()
            net.request(data, { type="vp_store_install", token=data.token, id=row.id }, 4.0)
          end)
          -- add to local installed list
          table.insert(data.apps.installed, { id=row.id, name=row.name })
          save(cfg, data)
          tab = 2; focus, scroll = 1, 0
        end
      end

    elseif e == "mouse_click" then
      local mx,my = b,c

      for _,bt in ipairs(dock) do
        if ui.hit(mx,my, bt.x,bt.y,bt.w,bt.h) then
          if bt.id ~= "appstore" then return bt.id end
        end
      end

      for _,t in ipairs(tabBtns) do
        if ui.hit(mx,my, t.x,t.y,t.w,t.h) then
          tab = t.id; focus, scroll = 1, 0
        end
      end

      for _,ht in ipairs(hit) do
        if ui.hit(mx,my, ht.x,ht.y,ht.w,ht.h) then
          focus = ht.idx
        end
      end
    end
  end
end

return M
