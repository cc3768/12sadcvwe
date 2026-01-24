local cfg = require("config")
local ui  = require("ui_queue")
local db  = require("order_db")
local helper = require("net_helper")
local shellUI = require("ui_shell") -- optional; press C on terminal/keyboard

db.load()

local ok, err = helper.openModem()
if not ok then error(err) end

local PROTOCOL  = (cfg.rednet and cfg.rednet.protocol) or "shop_queue_v1"
local HEARTBEAT = (cfg.rednet and cfg.rednet.heartbeat_interval) or 3

local mon = helper.getMonitor((cfg.monitors and cfg.monitors.queue) or nil) or error("No queue monitor found")
-- Prefer smaller text for dense lists; safe-guard for tiny monitors
pcall(function() mon.setTextScale(0.5) end)

local lastAck = 0
local dirty = true

local function normalizeOrder(o)
  if type(o) ~= "table" then return nil end
  o.status = o.status or "pending"
  -- ensure id
  if not o.id then
    o.id = os.epoch("utc")
  end
  -- normalize grades payloads (optional)
  o.grades = o.grades or {}
  o.parts_detail = o.parts_detail or {}
  return o
end

local function upsertOrder(o)
  o = normalizeOrder(o)
  if not o then return end

  local id = o.id
  for i=1,#db.orders do
    if db.orders[i] and db.orders[i].id == id then
      db.orders[i] = o
      db.save()
      return
    end
  end
  table.insert(db.orders, 1, o) -- newest on top
  db.save()
end

local function setStatus(id, status)
  for i=1,#db.orders do
    local o = db.orders[i]
    if o and o.id == id then
      o.status = status
      if status == "complete" then
        o.completed_time = os.time()
      end
      db.save()
      return o
    end
  end
  return nil
end

local function deleteOrder(id)
  for i=1,#db.orders do
    if db.orders[i] and db.orders[i].id == id then
      table.remove(db.orders, i)
      db.save()
      return true
    end
  end
  return false
end

local function ackHeartbeat(sender)
  -- broadcast ack so shop can detect queue is online
  rednet.broadcast({ type="heartbeat_ack", t=os.time() }, PROTOCOL)
  lastAck = os.clock()
end

local function handleAction(act)
  if not act or type(act) ~= "table" then return end

  if act.type == "complete" and act.id then
    local o = setStatus(act.id, "complete")
    if o then
      rednet.broadcast({ type="order_complete", id=act.id }, PROTOCOL)
    end

  elseif act.type == "reopen" and act.id then
    local o = setStatus(act.id, "pending")
    if o then
      rednet.broadcast({ type="order_reopen", id=act.id }, PROTOCOL)
    end

  elseif act.type == "delete" and act.id then
    if deleteOrder(act.id) then
      rednet.broadcast({ type="order_deleted", id=act.id }, PROTOCOL)
    end

  elseif act.type == "clear_completed" then
    local keep = {}
    for _,o in ipairs(db.orders) do
      if o and o.status ~= "complete" then table.insert(keep, o) end
    end
    db.orders = keep
    db.save()
  end
end

while true do
  if dirty then
    ui.draw(mon, db.orders)
    dirty = false
  end

  local event, p1, p2, p3 = os.pullEvent()

  -- Periodic online signal even if we missed heartbeats
  if os.clock() - lastAck >= (HEARTBEAT * 2) then
    rednet.broadcast({ type="heartbeat_ack", t=os.time() }, PROTOCOL)
    lastAck = os.clock()
  end

  if event == "rednet_message" then
    local sender, msg, proto = p1, p2, p3
    if proto == PROTOCOL and type(msg) == "table" then
      if msg.type == "heartbeat" then
        ackHeartbeat(sender)
      elseif msg.type == "new_order" and msg.order then
        upsertOrder(msg.order)
        dirty = true
      elseif msg.type == "order_update" and msg.order then
        upsertOrder(msg.order)
        dirty = true
      end
    end

  elseif event == "monitor_touch" then
    local act = ui.touch(p2, p3, db.orders)
    if act then
      handleAction(act)
      dirty = true
    end

  elseif event == "key" then
    local act = ui.key(p1, db.orders)
    if act then
      handleAction(act)
      dirty = true
    end
    if p1 == keys.c then
      -- allow config on queue computer without touching the monitor UI
      shellUI.start()
      dirty = true
    end

  elseif event == "char" then
    if p1 == "c" or p1 == "C" then
      shellUI.start()
      dirty = true
    end
  end
end
