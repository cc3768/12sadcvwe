-- /vibephone/screens/messages.lua
local ui = require("ui")
local store = require("data_store")
local net = require("net")

local M = {}

-- ------------------------------------------------------------
-- Data helpers (local SMS storage)
-- ------------------------------------------------------------
local function ensureSms(data)
  data.sms = data.sms or {}
  data.sms.threads = data.sms.threads or {} -- key = otherNumber string
  data.sms.lastSeenTs = data.sms.lastSeenTs or 0
end

local function nowTs()
  if os.epoch then return os.epoch("utc") end
  return os.time()
end

local function save(cfg, data)
  store.save(cfg.dataFile, data)
end

local function addMsg(data, other, msg)
  ensureSms(data)
  other = tostring(other)
  data.sms.threads[other] = data.sms.threads[other] or {}
  table.insert(data.sms.threads[other], msg)

  if msg.ts and msg.ts > (data.sms.lastSeenTs or 0) then
    data.sms.lastSeenTs = msg.ts
  end
end

local function lastMsgForThread(thread)
  if not thread or #thread == 0 then return nil end
  return thread[#thread]
end

local function buildConvoList(data)
  ensureSms(data)
  local list = {}
  for other, thread in pairs(data.sms.threads) do
    local last = lastMsgForThread(thread)
    local preview = ""
    local ts = 0
    if last then
      preview = tostring(last.body or "")
      ts = tonumber(last.ts or 0) or 0
    end
    list[#list+1] = { other = other, preview = preview, ts = ts }
  end
  table.sort(list, function(a,b) return (a.ts or 0) > (b.ts or 0) end)
  return list
end

-- ------------------------------------------------------------
-- Text wrap
-- ------------------------------------------------------------
local function wrapLines(text, width)
  text = tostring(text or "")
  if width <= 1 then return { text } end

  local out = {}
  for raw in text:gmatch("([^\n]*)\n?") do
    if raw == "" and #out > 0 then
      -- allow blank line if user typed newline
    end
    local line = raw
    while #line > width do
      local chunk = line:sub(1, width)
      table.insert(out, chunk)
      line = line:sub(width + 1)
    end
    table.insert(out, line)
    if raw == "" then break end
  end

  if #out == 0 then out[1] = "" end
  return out
end

-- ------------------------------------------------------------
-- UI building blocks (matches Settings style)
-- ------------------------------------------------------------
local function drawHeader(theme, data, blinkOn)
  local w,_ = term.getSize()
  ui.fillRect(1, 1, w, 1, theme.surface)

  local connected = (data.serverId ~= nil)
  local dot = blinkOn and "●" or "○"
  local dotColor = connected and theme.accent or theme.muted

  ui.writeAt(2, 1, dot, dotColor, theme.surface)
  ui.writeAt(4, 1, "Messages", theme.text, theme.surface)

  local title = (data.profile and data.profile.name) or "VibePhone"
  local tx = math.floor((w - #title) / 2) + 1
  ui.writeAt(tx, 1, title, theme.text, theme.surface)

  local num = data.number and ("#" .. tostring(data.number)) or "#----"
  ui.writeAt(w - #num - 1, 1, num, theme.muted, theme.surface)
end

local function drawToolbar(theme, leftLabel, rightLabel)
  local w,_ = term.getSize()
  ui.fillRect(1, 2, w, 1, theme.bg)

  -- left button
  local ltxt = leftLabel or "NEW"
  local lx = 2
  local lw = #ltxt + 2
  ui.fillRect(lx, 2, lw, 1, theme.surface)
  ui.writeAt(lx+1, 2, ltxt, theme.text, theme.surface)

  -- right button
  local rtxt = rightLabel or "REFRESH"
  local rw = #rtxt + 2
  local rx = w - rw - 1
  ui.fillRect(rx, 2, rw, 1, theme.surface)
  ui.writeAt(rx+1, 2, rtxt, theme.text, theme.surface)

  return {
    { id="new", x=lx, y=2, w=lw, h=1 },
    { id="refresh", x=rx, y=2, w=rw, h=1 },
  }
end

local function drawCard(theme, x, y, w, h)
  ui.fillRect(x, y, w, h, theme.line)
  ui.fillRect(x+1, y+1, w-2, h-2, theme.surface)
end

local function drawRow(theme, x, y, w, title, subtitle, focused)
  local bg = focused and theme.inner or theme.surface
  ui.fillRect(x, y, w, 2, bg)

  local t = tostring(title or "")
  if #t > w-3 then t = t:sub(1, w-3) end
  ui.writeAt(x+1, y, t, theme.text, bg)

  local s = tostring(subtitle or "")
  s = s:gsub("\n", " ")
  if #s > w-3 then s = s:sub(1, w-3) end
  ui.writeAt(x+1, y+1, s, theme.muted, bg)

  ui.writeAt(x+w-1, y, "›", focused and theme.accent or theme.muted, bg)
end

-- message bubbles
local function drawBubble(theme, x, y, w, lines, mine)
  local border = mine and theme.accent or theme.line
  local bg = mine and theme.inner or theme.surface
  local fg = theme.text
  local ww = w

  ui.fillRect(x, y, ww, #lines + 2, border)
  ui.fillRect(x+1, y+1, ww-2, #lines, bg)

  for i=1, #lines do
    local line = lines[i]
    if #line > ww-2 then line = line:sub(1, ww-2) end
    ui.writeAt(x+2, y+i, line, fg, bg)
  end
end

-- ------------------------------------------------------------
-- Server SMS (optional)
-- ------------------------------------------------------------
local function trySync(cfg, data)
  if not data.serverId then return false end
  if not net or not net.request then return false end

  local ok, resp = net.request(data, {
    type = "vp_sms_sync",
    token = data.token,
    since = data.sms and data.sms.lastSeenTs or 0,
  }, 2.5)

  if not ok or type(resp) ~= "table" then return false end
  if resp.type ~= "vp_sms_sync_ok" or type(resp.messages) ~= "table" then
    return false
  end

  for _,m in ipairs(resp.messages) do
    local other = tostring(m.other or m.from or "unknown")
    addMsg(data, other, {
      from = tostring(m.from or other),
      to   = tostring(m.to or (data.number or "")),
      body = tostring(m.body or ""),
      ts   = tonumber(m.ts or nowTs()) or nowTs(),
    })
  end

  save(cfg, data)
  return true
end

local function trySend(cfg, data, toNumber, body)
  if not data.serverId then
    -- offline: store local as outgoing
    addMsg(data, toNumber, {
      from = tostring(data.number or ""),
      to   = tostring(toNumber),
      body = tostring(body),
      ts   = nowTs(),
    })
    save(cfg, data)
    return true, "offline_saved"
  end

  local ok, resp = net.request(data, {
    type = "vp_sms_send",
    token = data.token,
    to = tostring(toNumber),
    body = tostring(body),
  }, 3.5)

  -- regardless of server response, store local outgoing
  addMsg(data, toNumber, {
    from = tostring(data.number or ""),
    to   = tostring(toNumber),
    body = tostring(body),
    ts   = nowTs(),
  })
  save(cfg, data)

  if ok and type(resp) == "table" and (resp.type == "vp_sms_send_ok" or resp.ok == true) then
    return true
  end
  return true, "sent_local"
end

-- ------------------------------------------------------------
-- Compose modal
-- ------------------------------------------------------------
local function inputModal(theme, title, label, initial, maxLen)
  local w,h = term.getSize()
  local boxW = math.min(w-4, 30)
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

local function composeModal(theme, data)
  local to = inputModal(theme, "New Message", "Send to number:", "", 12)
  if not to or to == "" then return nil end
  to = to:gsub("%s","")

  local w,h = term.getSize()
  local boxW = math.min(w-4, 32)
  local boxH = math.min(h-4, 12)
  local x = math.floor((w - boxW) / 2) + 1
  local y = math.floor((h - boxH) / 2)

  local text = ""

  while true do
    ui.fillRect(1, 1, w, h, theme.bg)

    ui.fillRect(x, y, boxW, boxH, theme.line)
    ui.fillRect(x+1, y+1, boxW-2, boxH-2, theme.surface)

    ui.writeAt(x+2, y+1, "To: " .. tostring(to), theme.text, theme.surface)
    ui.writeAt(x+2, y+2, "Type message:", theme.muted, theme.surface)

    local areaY = y+4
    local areaH = boxH-6
    local areaW = boxW-4

    local lines = wrapLines(text, areaW)
    local start = math.max(1, #lines - areaH + 1)

    for i=0, areaH-1 do
      local idx = start + i
      local line = lines[idx]
      ui.fillRect(x+2, areaY+i, areaW, 1, theme.inner)
      if line then
        ui.writeAt(x+2, areaY+i, line, theme.text, theme.inner)
      end
    end

    ui.writeAt(x+2, y+boxH-2, "Enter=Send  Esc=Cancel  Backspace=Del", theme.muted, theme.surface)

    local e,a = os.pullEvent()
    if e == "char" then
      if #text < 240 then text = text .. a end
    elseif e == "key" then
      if a == keys.backspace then
        text = text:sub(1, -2)
      elseif a == keys.enter then
        if text:gsub("%s","") == "" then
          -- ignore empty
        else
          return to, text
        end
      elseif a == keys.escape then
        return nil
      end
    end
  end
end

-- ------------------------------------------------------------
-- Main screen
-- ------------------------------------------------------------
function M.run(cfg, data)
  ensureSms(data)
  net.init(cfg)

  local mode = "list"   -- list | thread
  local focus = 1
  local scroll = 0

  local threadOther = nil
  local threadScroll = 0
  local replyDraft = ""

  local pressed = nil
  local pressedUntil = 0

  local blinkOn = true
  local tick = 0
  local timerId = os.startTimer(0.25)

  while true do
    local theme = ui.getTheme(data)
    local w,h = term.getSize()

    ui.drawWallpaper(theme, (data.ui and data.ui.wallpaper) or "border")
    drawHeader(theme, data, blinkOn)
    local toolbarBtns = drawToolbar(theme, "NEW", "REFRESH")

    -- content card area
    local cardX, cardY = 2, 4
    local cardW, cardH = w-2, (h - 4 - 2) -- leaves hint row + dock
    if cardH < 8 then cardH = 8 end
    drawCard(theme, cardX, cardY, cardW-1, cardH)

    local dock = ui.navBar(theme, "messages")

    local hit = {}
    local hint = ""

    if mode == "list" then
      local convos = buildConvoList(data)
      if focus < 1 then focus = 1 end
      if focus > math.max(1, #convos) then focus = math.max(1, #convos) end

      local listX = cardX + 1
      local listY = cardY + 1
      local listW = cardW - 3
      local visible = math.floor((cardH - 2) / 2)
      if visible < 1 then visible = 1 end

      scroll = math.max(0, math.min(scroll, math.max(0, #convos - visible)))
      if focus <= scroll then scroll = math.max(0, scroll - 1) end
      if focus > scroll + visible then scroll = scroll + 1 end

      for i=1, visible do
        local idx = i + scroll
        local c = convos[idx]
        if not c then break end

        local y = listY + (i-1)*2
        local title = "#" .. c.other
        local sub = c.preview or ""
        drawRow(theme, listX, y, listW, title, sub, idx == focus)
        hit[#hit+1] = { idx=idx, other=c.other, x=listX, y=y, w=listW, h=2 }
      end

      hint = "N=New  Enter=Open  Q=Back"

    else
      -- THREAD VIEW
      local other = tostring(threadOther or "")
      ui.writeAt(cardX+2, cardY+1, "Chat with #" .. other, theme.text, theme.surface)

      local thread = (data.sms.threads and data.sms.threads[other]) or {}
      local areaX = cardX + 2
      local areaY = cardY + 3
      local areaW = cardW - 5
      local areaH = cardH - 7

      if areaH < 3 then areaH = 3 end

      -- build render lines per message, store mapping
      local rendered = {}
      for _,m in ipairs(thread) do
        local mine = tostring(m.from or "") == tostring(data.number or "")
        local prefix = mine and "You: " or ("#" .. other .. ": ")
        local lines = wrapLines(prefix .. tostring(m.body or ""), areaW - 4)
        rendered[#rendered+1] = { mine=mine, lines=lines }
      end

      -- total height in lines
      local totalLines = 0
      for _,r in ipairs(rendered) do totalLines = totalLines + (#r.lines + 2) + 1 end

      local maxScroll = math.max(0, totalLines - areaH)
      threadScroll = math.max(0, math.min(threadScroll, maxScroll))

      -- draw messages (from top with scroll)
      ui.fillRect(areaX, areaY, areaW, areaH, theme.bg)

      local cursorY = areaY - threadScroll
      for _,r in ipairs(rendered) do
        local bubbleH = #r.lines + 2
        local bw = math.min(areaW, math.max(10, (#r.lines[1] or "") + 6))

        local bx
        if r.mine then
          bx = areaX + (areaW - bw)
        else
          bx = areaX
        end

        if cursorY + bubbleH >= areaY and cursorY <= areaY + areaH - 1 then
          drawBubble(theme, bx, cursorY, bw, r.lines, r.mine)
        end
        cursorY = cursorY + bubbleH + 1
      end

      -- reply bar
      local inputY = cardY + cardH - 2
      ui.fillRect(cardX+1, inputY, cardW-3, 2, theme.inner)
      local label = "Reply: "
      local maxLen = (cardW-3) - #label - 2
      local shown = replyDraft
      if #shown > maxLen then shown = shown:sub(#shown-maxLen+1) end
      ui.writeAt(cardX+2, inputY, label .. shown .. "_", theme.text, theme.inner)
      ui.writeAt(cardX+2, inputY+1, "Enter=Send  Esc/Q=Back  N=New", theme.muted, theme.inner)

      hint = "Type to reply"

      -- clicking inside thread doesn’t select rows, but we keep hit for future
    end

    -- hint line + dock already drawn by ui.navBar
    ui.fillRect(1, h-2, w, 1, theme.bg)
    ui.center(h-2, hint, theme.muted, theme.bg)

    -- --------------------------------------------------------
    -- Events
    -- --------------------------------------------------------
    local e,a,b,c = os.pullEvent()

    if e == "timer" and a == timerId then
      tick = tick + 1
      blinkOn = (tick % 2 == 0)
      timerId = os.startTimer(0.25)

      if pressed and os.clock() > pressedUntil then pressed = nil end

      -- background sync attempt (silent)
      pcall(function() trySync(cfg, data) end)

    elseif e == "mouse_click" then
      local mx,my = b,c

      -- dock taps
      for _,bt in ipairs(dock or {}) do
        if ui.hit(mx,my, bt.x,bt.y,bt.w,bt.h) then
          if bt.id ~= "messages" then return bt.id end
        end
      end

      -- toolbar taps
      for _,tb in ipairs(toolbarBtns or {}) do
        if ui.hit(mx,my, tb.x,tb.y,tb.w,tb.h) then
          if tb.id == "new" then
            local to, body = composeModal(theme, data)
            if to and body then
              trySend(cfg, data, to, body)
              mode = "thread"
              threadOther = tostring(to)
              replyDraft = ""
              threadScroll = 999999 -- jump bottom next draw
            end
          elseif tb.id == "refresh" then
            trySync(cfg, data)
          end
        end
      end

      if mode == "list" then
        for _,ht in ipairs(hit) do
          if ui.hit(mx,my, ht.x,ht.y,ht.w,ht.h) then
            focus = ht.idx
            mode = "thread"
            threadOther = tostring(ht.other)
            replyDraft = ""
            threadScroll = 999999
            break
          end
        end
      end

    elseif e == "key" then
      if mode == "list" then
        if a == keys.q or a == keys.escape then
          return "home"
        elseif a == keys.n then
          local to, body = composeModal(theme, data)
          if to and body then
            trySend(cfg, data, to, body)
            mode = "thread"
            threadOther = tostring(to)
            replyDraft = ""
            threadScroll = 999999
          end
        elseif a == keys.up then
          focus = math.max(1, focus - 1)
        elseif a == keys.down then
          local convos = buildConvoList(data)
          focus = math.min(math.max(1, #convos), focus + 1)
        elseif a == keys.enter then
          local convos = buildConvoList(data)
          local c = convos[focus]
          if c then
            mode = "thread"
            threadOther = tostring(c.other)
            replyDraft = ""
            threadScroll = 999999
          end
        end
      else
        -- thread view
        if a == keys.q or a == keys.escape then
          mode = "list"
          threadOther = nil
          replyDraft = ""
          threadScroll = 0
        elseif a == keys.up then
          threadScroll = math.max(0, threadScroll - 2)
        elseif a == keys.down then
          threadScroll = threadScroll + 2
        elseif a == keys.enter then
          local body = replyDraft
          if body and body:gsub("%s","") ~= "" and threadOther then
            trySend(cfg, data, threadOther, body)
            replyDraft = ""
            threadScroll = 999999
          end
        elseif a == keys.backspace then
          replyDraft = replyDraft:sub(1, -2)
        elseif a == keys.n then
          local to, body = composeModal(theme, data)
          if to and body then
            trySend(cfg, data, to, body)
            mode = "thread"
            threadOther = tostring(to)
            replyDraft = ""
            threadScroll = 999999
          end
        end
      end

    elseif e == "char" then
      if mode == "thread" then
        if #replyDraft < 160 then
          replyDraft = replyDraft .. a
        end
      else
        -- list: allow quick shortcut
        if a == "n" then
          local to, body = composeModal(theme, data)
          if to and body then
            trySend(cfg, data, to, body)
            mode = "thread"
            threadOther = tostring(to)
            replyDraft = ""
            threadScroll = 999999
          end
        end
      end
    end
  end
end

return M
