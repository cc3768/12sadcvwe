dofile("/vibephone/require_shim.lua")
local storage = require("storage")
local ui = require("ui")

local lock = require("screens.lock")
local home = require("screens.home")
local settings = require("screens.settings")
local apps = require("apps")

local state = storage.load()

local function canMulti()
  return multishell and multishell.launch
end

local function defaultEnv()
  return setmetatable({}, { __index = _G })
end

local function launchApp(appId)
  local app = apps[appId]
  if not app then
    state.status = "Unknown app: "..tostring(appId)
    return
  end

  if app.multishell and canMulti() then
    local id = multishell.launch(defaultEnv(), app.entry)
    state.status = "Launched "..app.name.." (tab "..tostring(id)..")"
    return
  end

  -- fallback: run in this shell
  term.setBackgroundColor(colors.black)
  term.setTextColor(colors.white)
  term.clear()

  local ok, err = pcall(function()
    shell.run(app.entry)
  end)

  if not ok then
    term.setCursorPos(1,1)
    print("App crashed: "..tostring(appId))
    print(tostring(err))
    print("\nPress any key...")
    os.pullEvent("key")
  end

  state.status = "Returned from "..app.name
end

lock.run(state)

while true do
  home.draw(state)
  local e, btn, x, y = os.pullEvent()
  if e == "mouse_click" then
    local id = ui.hit(x,y)
    local action = home.handleTap(state, id)
    if action and action.action == "settings" then
      settings.run(state)
    elseif action and action.action == "launch" then
      launchApp(action.appId)
    end
  end
end
