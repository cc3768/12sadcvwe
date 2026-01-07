-- /vibephone/screens/settings.lua
local ui = require("ui")
local store = require("data_store")

local M = {}

local function safeSave(cfg, data)
  store.save(cfg.dataFile, data)
end

local function drawHeader(theme, data, blinkOn)
  local w,_ = term.getSize()
  ui.fillRect(1, 1, w, 1, theme.surface)

  local connected = (data.serverId ~= nil)
  local dot = blinkOn and "●" or "○"
  local dotColor = connected and theme.accent or theme.muted

  ui.writeAt(2, 1, dot, dotColor, theme.surface)
  ui.writeAt(4, 1, "Settings", theme.text, theme.surface)

  local title = (data.profile and data.profile.name) or "VibePhone"
  local tx = math.floor((w - #title) / 2) + 1
  ui.writeAt(tx, 1, title, theme.text, theme.surface)

  local num = data.number and ("#" .. tostring(data.number)) or "#----"
  ui.writeAt(w - #num - 1, 1, num, theme.muted, theme.surface)
end

local function drawTabs(theme, tabIndex)
  local w,_ = term.getSize()
  ui.fillRect(1, 2, w, 2, theme.bg)

  local tabs = {"PROFILE","LOOK","SECURITY"}
  local cellW = math.floor(w / #tabs)
  local btns = {}

  for i,name in ipairs(tabs) do
    local x = (i-1)*cellW + 1
    local ww = (i == #tabs) and (w - x + 1) or cellW
    local active = (i == tabIndex)

    local fg = active and theme.text or theme.muted

    local tx = x + math.floor((ww - #name) / 2)
    ui.writeAt(tx, 2, name, fg, theme.bg)

    if active then
      ui.fillRect(x, 3, ww, 1, theme.accent)
    end

    btns[#btns+1] = {id=i, x=x, y=2, w=ww, h=2}
  end

  return btns
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

local function drawCard(theme, x, y, w, h)
  ui.fillRect(x, y, w, h, theme.line)
  ui.fillRect(x+1, y+1, w-2, h-2, theme.surface)
end

local function drawRow(theme, x, y, w, title, value, focused, arrow)
  local bg = focused and theme.inner or theme.surface
  ui.fillRect(x, y, w, 2, bg)

  local t = tostring(title or "")
  if #t > w-3 then t = t:sub(1, w-3) end
  ui.writeAt(x+1, y, t, theme.text, bg)

  local v = tostring(value or "")
  if #v > w-3 then v = v:sub(1, w-3) end
  ui.writeAt(x+1, y+1, v, theme.muted, bg)

  if arrow then
    ui.writeAt(x+w-1, y, "›", focused and theme.accent or theme.muted, bg)
  end
end

local function drawToggle(theme, x, y, w, title, enabled, focused)
  local bg = focused and theme.inner or theme.surface
  ui.fillRect(x, y, w, 2, bg)

  local t = tostring(title or "")
  if #t > w-10 then t = t:sub(1, w-10) end
  ui.writeAt(x+1, y, t, theme.text, bg)

  local pill = enabled and "[ON]" or "[OFF]"
  local pillColor = enabled and theme.accent or theme.muted
  ui.writeAt(x+w-#pill-1, y, pill, pillColor, bg)

  ui.writeAt(x+1, y+1, enabled and "Enabled" or "Disabled", theme.muted, bg)
end

local function inputModal(theme, title, label, initial, maxLen)
  local w,h = term.getSize()
  local boxW = math.min(w-4, 26)
  local boxH = 7
  local x = math.floor((w - boxW) / 2) + 1
  local y = math.floor((h - boxH) / 2)

  local text = tostring(initial or "")
  maxLen = maxLen or 24

  while true do
    ui.fillRect(1, 1, w, h, theme.bg)

    ui.fillRect(x, y, boxW, boxH, theme.line)
    ui.fillRect(x+1, y+1, boxW-2, boxH-2, theme.surface)

    ui.writeAt(x+2, y+1, title, theme.text, theme.surface)
    ui.writeAt(x+2, y+2, label, theme.muted, theme.surface)

    local shown = text
    if #shown > boxW-4 then shown = shown:sub(#shown-(boxW-5)) end
    ui.writeAt(x+2, y+4, shown .. "_", theme.text, theme.surface)

    ui.writeAt(x+2, y+5, "Enter=OK  Esc=Cancel", theme.muted, theme.surface)

    local e,a = os.pullEvent()
    if e == "char" then
      if #text < maxLen then text = text .. a end
    elseif e == "key" then
      if a == keys.backspace then
        text = text:sub(1, -2)
      elseif a == keys.enter then
        return text
      elseif a == keys.escape then
        return nil
      end
    end
  end
end

local function pinModal(theme)
  local w,h = term.getSize()
  local boxW = math.min(w-4, 28)
  local boxH = 9
  local x = math.floor((w - boxW) / 2) + 1
  local y = math.floor((h - boxH) / 2)

  local stage = 1
  local pin = ""
  local confirm = ""
  local err = nil

  while true do
    ui.fillRect(1, 1, w, h, theme.bg)

    ui.fillRect(x, y, boxW, boxH, theme.line)
    ui.fillRect(x+1, y+1, boxW-2, boxH-2, theme.surface)

    ui.writeAt(x+2, y+1, "Change PIN", theme.text, theme.surface)

    local label = (stage == 1) and "Enter new PIN" or "Confirm PIN"
    ui.writeAt(x+2, y+2, label, theme.muted, theme.surface)

    local shown = (stage == 1) and pin or confirm
    local masked = (#shown > 0) and string.rep("*", #shown) or " "
    ui.writeAt(x+2, y+4, masked .. "_", theme.text, theme.surface)

    if err then ui.writeAt(x+2, y+5, err, theme.bad, theme.surface) end

    ui.writeAt(x+2, y+7, "Digits • Enter=OK • Esc=Cancel", theme.muted, theme.surface)

    local e,a = os.pullEvent()
    if e == "char" and a:match("%d") then
      if stage == 1 then
        if #pin < 12 then pin = pin .. a end
      else
        if #confirm < 12 then confirm = confirm .. a end
      end
      err = nil
    elseif e == "key" then
      if a == keys.backspace then
        if stage == 1 then pin = pin:sub(1, -2) else confirm = confirm:sub(1, -2) end
      elseif a == keys.enter then
        if stage == 1 then
          if #pin < 4 then
            err = "PIN must be 4+ digits"
          else
            stage = 2
            confirm = ""
          end
        else
          if confirm ~= pin then
            err = "PIN does not match"
            stage = 1
            pin = ""
            confirm = ""
          else
            return tostring(ui.djb2(pin))
          end
        end
      elseif a == keys.escape then
        return nil
      end
    end
  end
end

function M.run(cfg, data)
  data.profile = data.profile or { name = "VibePhone" }
  data.ui = data.ui or { theme="neon", accent=colors.cyan, wallpaper="border" }
  data.lock = data.lock or { requirePinForStore=false }

  local tab = 1
  local focus = 1
  local scroll = 0

  local blinkOn = true
  local tick = 0
  local timerId = os.startTimer(0.25)

  while true do
    local theme = ui.getTheme(data)
    local w,h = term.getSize()

    ui.drawWallpaper(theme, data.ui.wallpaper or "border")
    drawHeader(theme, data, blinkOn)
    local tabBtns = drawTabs(theme, tab)

    local cardX, cardY = 2, 5
    local cardW, cardH = w-2, (h - 5 - 2)
    if cardH < 8 then cardH = 8 end
    drawCard(theme, cardX, cardY, cardW-1, cardH)

    local rows = {}
    if tab == 1 then
      rows = {
        { kind="row", title="Device Name", value=data.profile.name or "VibePhone", action="edit_name" },
        { kind="row", title="Phone Number", value=(data.number and ("#" .. tostring(data.number))) or "#----", action=nil },
        { kind="row", title="Server", value=(data.serverName or "Unknown"), action=nil },
      }
    elseif tab == 2 then
      rows = {
        { kind="row", title="Theme", value=(data.ui.theme or "neon"), action="cycle_theme" },
        { kind="row", title="Accent", value=tostring(data.ui.accent or colors.cyan) .. " (tap)", action="cycle_accent" },
        { kind="row", title="Wallpaper", value=(data.ui.wallpaper or "border") .. " (tap)", action="cycle_wallpaper" },
      }
    else
      rows = {
        { kind="row", title="Change PIN", value="Tap to set a new PIN", action="change_pin" },
        { kind="toggle", title="Require PIN for Store", action="toggle_store_pin", state=not not data.lock.requirePinForStore },
        { kind="row", title="Reset Phone", value="Clears number + PIN + setup", action="reset_phone" },
      }
    end

    local listX = cardX + 1
    local listY = cardY + 1
    local listW = cardW - 3
    local visibleRows = math.floor((cardH - 2) / 2)
    if visibleRows < 1 then visibleRows = 1 end
    scroll = math.max(0, math.min(scroll, math.max(0, #rows - visibleRows)))

    local hitTargets = {}
    for i=1, visibleRows do
      local idx = i + scroll
      local r = rows[idx]
      if not r then break end
      local y = listY + (i-1)*2
      local focused = (idx == focus)

      if r.kind == "toggle" then
        drawToggle(theme, listX, y, listW, r.title, r.state, focused)
        hitTargets[#hitTargets+1] = {idx=idx, x=listX, y=y, w=listW, h=2, action="toggle_store_pin"}
      else
        drawRow(theme, listX, y, listW, r.title, r.value, focused, r.action ~= nil)
        hitTargets[#hitTargets+1] = {idx=idx, x=listX, y=y, w=listW, h=2, action=r.action}
      end
    end

    ui.fillRect(1, h-2, w, 1, theme.bg)
    ui.center(h-2, "Tap • Left/Right tabs • Q=Back", theme.muted, theme.bg)
    local dock = drawDock(theme, "settings")

    local function doAction(action)
      if not action then return end

      if action == "edit_name" then
        local v = inputModal(theme, "Profile", "Device name:", data.profile.name or "VibePhone", 24)
        if v and v ~= "" then data.profile.name = v; safeSave(cfg, data) end

      elseif action == "cycle_theme" then
        local order = {"neon","dark","mono"}
        local cur = data.ui.theme or "neon"
        local k = 1
        for i,n in ipairs(order) do if n == cur then k = i break end end
        k = (k % #order) + 1
        data.ui.theme = order[k]
        safeSave(cfg, data)

      elseif action == "cycle_accent" then
        local accents = {colors.cyan, colors.lightBlue, colors.lime, colors.orange, colors.pink, colors.purple, colors.yellow, colors.white}
        local cur = data.ui.accent or colors.cyan
        local k = 1
        for i,v in ipairs(accents) do if v == cur then k = i break end end
        k = (k % #accents) + 1
        data.ui.accent = accents[k]
        safeSave(cfg, data)

      elseif action == "cycle_wallpaper" then
        local walls = {"border","grid","stripes","none"}
        local cur = data.ui.wallpaper or "border"
        local k = 1
        for i,v in ipairs(walls) do if v == cur then k = i break end end
        k = (k % #walls) + 1
        data.ui.wallpaper = walls[k]
        safeSave(cfg, data)

      elseif action == "change_pin" then
        local newHash = pinModal(theme)
        if newHash then
          data.pinHash = newHash
          data.setupComplete = true
          safeSave(cfg, data)
        end

      elseif action == "toggle_store_pin" then
        data.lock.requirePinForStore = not data.lock.requirePinForStore
        safeSave(cfg, data)

      elseif action == "reset_phone" then
        store.reset(data)
        safeSave(cfg, data)
        return "setup"
      end
    end

    local e,a,b,c = os.pullEvent()

    if e == "timer" and a == timerId then
      tick = tick + 1
      blinkOn = (tick % 2 == 0)
      timerId = os.startTimer(0.25)

    elseif e == "key" then
      if a == keys.q or a == keys.escape then
        return "home"
      elseif a == keys.left then
        tab = math.max(1, tab - 1); focus, scroll = 1, 0
      elseif a == keys.right then
        tab = math.min(3, tab + 1); focus, scroll = 1, 0
      elseif a == keys.up then
        focus = math.max(1, focus - 1)
        if focus <= scroll then scroll = math.max(0, scroll - 1) end
      elseif a == keys.down then
        focus = math.min(#rows, focus + 1)
        if focus > scroll + visibleRows then scroll = scroll + 1 end
      elseif a == keys.enter then
        local r = rows[focus]
        if r and r.action then
          local goto = doAction(r.action)
          if goto then return goto end
        end
      end

    elseif e == "mouse_click" then
      local mx,my = b,c

      for _,bt in ipairs(dock) do
        if ui.hit(mx,my, bt.x,bt.y,bt.w,bt.h) then
          if bt.id ~= "settings" then return bt.id end
        end
      end

      for _,t in ipairs(tabBtns) do
        if ui.hit(mx,my, t.x,t.y,t.w,t.h) then
          tab = t.id; focus, scroll = 1, 0
        end
      end

      for _,ht in ipairs(hitTargets) do
        if ui.hit(mx,my, ht.x,ht.y,ht.w,ht.h) then
          focus = ht.idx
          local goto = doAction(ht.action)
          if goto then return goto end
        end
      end
    end
  end
end

return M
