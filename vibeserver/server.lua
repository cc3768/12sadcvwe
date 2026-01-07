-- /vibephone_server.lua
-- VibePhone server: discovery + registration + SMS relay (compat)

local PROTOCOL = "vibephone"
local STATE_FILE = "/vibephone_server_state.json"

local function sides() return {"left","right","front","back","top","bottom"} end

local function openAnyModem()
  local opened = false
  for _,s in ipairs(sides()) do
    if peripheral.isPresent(s) then
      local t = peripheral.getType(s)
      if t == "modem" or t == "ender_modem" then
        if not rednet.isOpen(s) then rednet.open(s) end
        opened = true
      end
    end
  end
  return opened
end

local function readFile(path)
  if not fs.exists(path) then return nil end
  local f = fs.open(path, "r"); if not f then return nil end
  local c = f.readAll(); f.close()
  return c
end

local function writeFile(path, content)
  local tmp = path .. ".tmp"
  local f = fs.open(tmp, "w"); assert(f, "Failed to write: " .. tmp)
  f.write(content); f.close()
  if fs.exists(path) then fs.delete(path) end
  fs.move(tmp, path)
end

local function loadState()
  local defaults = {
    nextNumber = 1000,
    devices = {}, -- deviceKey -> {number=####, token="..."}
    inbox = {},   -- number -> { {from,to,body,ts}, ... }
  }

  local raw = readFile(STATE_FILE)
  if not raw or raw == "" then return defaults end

  local ok, st = pcall(textutils.unserializeJSON, raw)
  if not ok or type(st) ~= "table" then return defaults end

  st.nextNumber = st.nextNumber or defaults.nextNumber
  st.devices = st.devices or {}
  st.inbox = st.inbox or {}
  return st
end

local function saveState(st)
  writeFile(STATE_FILE, textutils.serializeJSON(st, true))
end

local function randToken()
  local a = tostring(math.random(100000, 999999))
  local b = tostring(math.random(100000, 999999))
  return a .. "-" .. b
end

local function pushInbox(st, toNumber, msg)
  local k = tostring(toNumber)
  st.inbox[k] = st.inbox[k] or {}
  st.inbox[k][#st.inbox[k]+1] = msg
end

local function popSince(st, number, since)
  since = tonumber(since) or 0
  local k = tostring(number)
  local box = st.inbox[k] or {}
  local out = {}
  for _,m in ipairs(box) do
    if (tonumber(m.ts) or 0) > since then out[#out+1] = m end
  end
  return out
end

-- ---- Start ----
term.clear()
term.setCursorPos(1,1)

if not openAnyModem() then
  print("ERROR: No modem/ender modem found.")
  return
end

local st = loadState()
local serverName = os.getComputerLabel() or ("VibePhone Server #" .. os.getComputerID())

-- Optional: host a name so old clients using rednet.lookup can find you
pcall(function()
  rednet.host(PROTOCOL, "vibephone_server")
end)

print(serverName .. " online")
print("Protocol: " .. PROTOCOL)
print("State: " .. STATE_FILE)

while true do
  local senderId, msg, proto = rednet.receive(PROTOCOL)
  if type(msg) ~= "table" then goto continue end

  -- ---------- Discovery compatibility ----------
  if msg.type == "vp_ping" or msg.type == "ping" then
    rednet.send(senderId, {
      type  = (msg.type == "ping") and "pong" or "vp_pong",
      nonce = msg.nonce,
      name  = serverName,
      label = serverName,
    }, PROTOCOL)
    goto continue
  end

  -- ---------- Registration compatibility ----------
  local isRegister =
    msg.type == "vp_register" or
    msg.type == "register" or
    msg.type == "phone_register" or
    msg.type == "vp_setup"

  if isRegister then
    local deviceKey = tostring(msg.deviceKey or msg.deviceId or msg.tokenKey or senderId)

    local rec = st.devices[deviceKey]
    if not rec then
      rec = { number = st.nextNumber, token = randToken() }
      st.nextNumber = st.nextNumber + 1
      st.devices[deviceKey] = rec
      saveState(st)
    end

    -- reply type matches request style to satisfy your setup.lua checks
    local replyType = "register_ok"
    if msg.type == "vp_register" or msg.type == "vp_setup" then replyType = "vp_register_ok" end

    rednet.send(senderId, {
      type = replyType,
      nonce = msg.nonce,
      number = rec.number,
      token = rec.token,
      serverName = serverName,
      serverId = os.getComputerID(),
    }, PROTOCOL)

    goto continue
  end

  -- ---------- SMS (optional, ready for later) ----------
  if msg.type == "sms_send" then
    local from = tostring(msg.from or msg.number or "")
    local to = tostring(msg.to or "")
    local body = tostring(msg.body or "")
    local ts = tonumber(msg.ts) or (os.epoch and os.epoch("utc")) or os.time()

    if to ~= "" and body ~= "" then
      pushInbox(st, to, {from=from, to=to, body=body, ts=ts})
      saveState(st)
    end

    rednet.send(senderId, { type="sms_send_ok", nonce=msg.nonce }, PROTOCOL)
    goto continue
  end

  if msg.type == "sms_fetch" then
    local number = tostring(msg.number or "")
    local since = tonumber(msg.since) or 0
    local messages = {}
    if number ~= "" then messages = popSince(st, number, since) end

    rednet.send(senderId, { type="sms_fetch_ok", nonce=msg.nonce, messages=messages }, PROTOCOL)
    goto continue
  end

  ::continue::
end
