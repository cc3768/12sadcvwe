dofile("/vibephone/require_shim.lua")
local config = require("config")
local ui = require("ui")
local storage = require("storage")

local lock = {}

local function animSplash()
  if not config.ANIM_ENABLED then return end

  local w,h = term.getSize()
  local frames = math.max(1, math.floor((config.ANIM_SECONDS or 1.8) * (config.ANIM_FPS or 12)))
  local fps = config.ANIM_FPS or 12

  for i=1,frames do
    ui.fill(config.C_BG)
    ui.statusBar("VibePhone", os.date("%H:%M"))

    local barW = math.max(10, math.floor(w*0.6))
    local x0 = math.floor((w-barW)/2) + 1
    local y0 = math.floor(h*0.65)
    ui.box(x0,y0,barW,1,config.C_SURFACE)

    local fillW = math.floor((i/frames)*barW)
    if fillW > 0 then ui.box(x0,y0,fillW,1,config.C_ACCENT) end

    local t = (i/frames)
    local lx = math.floor((w/2) + math.sin(t*math.pi*2) * math.floor(w*0.18))
    local ly = math.floor(h*0.35)
    ui.text(lx,ly,"●",config.C_ACCENT,config.C_BG)
    ui.centerText(ly-2, "VibePhone", config.C_TEXT, config.C_BG)
    ui.centerText(ly-1, "booting...", config.C_MUTED, config.C_BG)

    os.sleep(1/fps)
  end
end

local function promptPin(title)
  local input = ""
  while true do
    local w,h = term.getSize()
    ui.fill(config.C_BG)
    ui.statusBar("VibePhone", os.date("%H:%M"))

    ui.centerText(4, title, config.C_TEXT, config.C_BG)
    ui.centerText(6, string.rep("●", #input) .. string.rep("○", config.PIN_LENGTH-#input), config.C_ACCENT, config.C_BG)
    ui.centerText(h-2, "Digits • Enter=OK • Backspace=Del", config.C_MUTED, config.C_BG)

    local e,a = os.pullEvent()
    if e == "char" then
      if a:match("%d") and #input < config.PIN_LENGTH then input = input .. a end
    elseif e == "key" then
      if a == keys.backspace then
        input = input:sub(1, math.max(0, #input-1))
      elseif a == keys.enter then
        if #input == config.PIN_LENGTH then return input end
      end
    end
  end
end

function lock.run(state)
  animSplash()

  if not state.pin then
    local p1 = promptPin("Create PIN ("..config.PIN_LENGTH.." digits)")
    local p2 = promptPin("Confirm PIN")
    if p1 ~= p2 then
      state.status = "PIN mismatch. Try again."
      return lock.run(state)
    end
    state.pin = p1
    storage.save(state)
  else
    while true do
      local p = promptPin("Enter PIN")
      if p == state.pin then break end
      ui.centerText(8, "Wrong PIN", config.C_BAD, config.C_BG)
      os.sleep(0.6)
    end
  end

  return true
end

return lock
