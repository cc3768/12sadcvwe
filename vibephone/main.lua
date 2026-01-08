-- Ensure requires work from this folder even if shell dir changes
local base = fs.getDir(shell.getRunningProgram())
if base == "" then base = "." end
package.path = fs.combine(base, "?.lua") .. ";" .. fs.combine(base, "?/init.lua") .. ";" .. package.path


local cfg   = require("config")
local store = require("data_store")
local net   = require("net")

local setup    = require("screens.setup")
local lock     = require("screens.lock")
local home     = require("screens.home")
local settings = require("screens.settings")
local appstore = require("screens.appstore")
local messages = require("screens.messages")

-- Load persisted data
local data, DATA_PATH = store.load("data.json")

-- Init modem/rednet
net.init(cfg)

local function ensureSetup()
  while (not data.serverId) or (not data.number) or (not data.pinHash) do
    local ok = setup.run(cfg, data)
    if ok then break end
  end
end




ensureSetup()

while true do
  local unlocked, requestedReset = lock.run(cfg, data)
  if requestedReset then
    store.reset(data)
    store.save(DATA_PATH, data) -- ✅ save to the same file we loaded
    ensureSetup()
  elseif unlocked then
    while true do
      local action = home.run(cfg, data)
      if action == "lock" then break end
      if action == "settings" then
        local result = settings.run(cfg, data, store, net, DATA_PATH)
        if result == "setup" then
          ensureSetup()
          break
        end
      elseif action == "store" then
        appstore.run(cfg, data, net)
      elseif action == "messages" then
        messages.run(cfg, data, net)
      end
    end
  end
end
