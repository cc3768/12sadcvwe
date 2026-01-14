local cfg = require("config")
local builder = require("ui_builder")
local shellUI = require("ui_shell")
local outbox = require("outbox_db")
local helper = require("net_helper")

outbox.load()

local ok, err = helper.openModem()
if not ok then error(err) end

local PROTOCOL = cfg.rednet.protocol
local HEARTBEAT = cfg.rednet.heartbeat_interval or 3

local mon = helper.getMonitor(cfg.monitors.builder) or error("No builder monitor found")
mon.setTextScale(0.5)

-- Advanced Peripherals: Player Detector
local playerDetector = peripheral.find("playerDetector")
local detectorName = playerDetector and peripheral.getName(playerDetector) or nil
local lastTouchUser = nil

local function asArray(t)
  if type(t) ~= "table" then return {} end
  -- Most AP returns { "name1", "name2" } (array)
  if #t > 0 then return t end
  -- Fallback if it ever returns map-ish tables
  local out = {}
  for k,v in pairs(t) do
    if type(k) == "string" then out[#out+1] = k end
    if type(v) == "string" then out[#out+1] = v end
  end
  return out
end

local function getClosestOrAnyPlayer()
  if not playerDetector then return nil end

  -- 1) Best: players near the detector block
  if playerDetector.getPlayersInRange then
    local near = asArray(playerDetector.getPlayersInRange(16) or {})
    if #near > 0 then
      return near[1] -- usually only 1 person ordering; simplest + reliable
    end
  end

  -- 2) Fallback: if only 1 person online, use them
  if playerDetector.getOnlinePlayers then
    local online = asArray(playerDetector.getOnlinePlayers() or {})
    if #online == 1 then return online[1] end
  end

  return nil
end

local queueOnline = false
local lastPing = 0
local dirty = true

local function deepCopyParts(parts)
  local out = {}
  for k,v in pairs(parts or {}) do out[k]=v end
  return out
end

local function sendOrder(order)
  rednet.broadcast({type="new_order", order=order}, PROTOCOL)
end

local function flushOutbox()
  if #outbox.orders == 0 then return end
  for _,o in ipairs(outbox.orders) do
    sendOrder(o)
  end
  outbox.clear()
end

while true do
  if dirty then
    builder.draw(mon)
    dirty = false
  end

  local event, p1, p2, p3 = os.pullEvent()

  -- heartbeat
  if os.clock() - lastPing >= HEARTBEAT then
    rednet.broadcast({type="heartbeat"}, PROTOCOL)
    lastPing = os.clock()
  end

  -- OPTIONAL but very useful: if someone clicks the detector block, we get the exact username
  -- event: playerClick, username, deviceName
  if event == "playerClick" then
    local username, device = p1, p2
    if not detectorName or device == detectorName then
      lastTouchUser = username
    end

  elseif event == "rednet_message" then
    local sender, msg, proto = p1, p2, p3
    if proto == PROTOCOL and type(msg) == "table" then
      if msg.type == "heartbeat_ack" then
        if not queueOnline then
          queueOnline = true
          flushOutbox()
        end
      end
    end

  elseif event == "monitor_touch" then
    -- best-effort: grab nearest player to detector at touch time
    local nearest = getClosestOrAnyPlayer()
    if nearest then lastTouchUser = nearest end

    builder.touch(p2, p3)
    dirty = true

    -- IMPORTANT: do not inject a name; use UI name if it provides one
    local raw = builder.getOrder(nil)

    if raw and raw._submit and raw.tool then
      -- Try again right at submit moment (more accurate)
      if not lastTouchUser then
        local n2 = getClosestOrAnyPlayer()
        if n2 then lastTouchUser = n2 end
      end

      local user = raw.user
      if not user or user == "" then
        user = lastTouchUser or os.getComputerLabel() or "Customer"
      end

      local order = {
        id = raw.id or os.epoch("utc"),
        user = user,
        tool = raw.tool,
        parts = deepCopyParts(raw.parts),
        status = "pending",
        total = raw.total,
        time = os.time(),
      }

      if queueOnline then
        sendOrder(order)
      else
        table.insert(outbox.orders, order)
        outbox.save()
      end
    end

  elseif event == "char" then
    if p1 == "c" or p1 == "C" then
      shellUI.start()
      dirty = true
    end

  elseif event == "key" then
    if p1 == keys.c then
      shellUI.start()
      dirty = true
    end
  end
end
