dofile("/vibephone/require_shim.lua")
local config = require("config")
local ui = require("ui")
local storage = require("storage")

local settings = {}

local function promptLine(title)
  local input = ""
  while true do
    local w,h = term.getSize()
    ui.fill(config.C_BG)
    ui.statusBar("Settings", os.date("%H:%M"))

    ui.centerText(4, title, config.C_TEXT, config.C_BG)
    ui.box(2,6,w-2,1,config.C_SURFACE)
    ui.text(3,6,input,colors.black,config.C_SURFACE)
    ui.centerText(h-2, "Enter=OK • ESC=Cancel", config.C_MUTED, config.C_BG)

    local e,a = os.pullEvent()
    if e == "char" then
      if #input < 24 then input = input .. a end
    elseif e == "key" then
      if a == keys.backspace then
        input = input:sub(1, math.max(0, #input-1))
      elseif a == keys.enter then
        return input
      elseif a == keys.escape then
        return nil
      end
    end
  end
end

local function promptPin(title, pinLen)
  local input = ""
  while true do
    local w,h = term.getSize()
    ui.fill(config.C_BG)
    ui.statusBar("Settings", os.date("%H:%M"))

    ui.centerText(4, title, config.C_TEXT, config.C_BG)
    ui.centerText(6, string.rep("●", #input) .. string.rep("○", pinLen-#input), config.C_ACCENT, config.C_BG)
    ui.centerText(h-2, "Digits • Enter=OK • ESC=Cancel", config.C_MUTED, config.C_BG)

    local e,a = os.pullEvent()
    if e == "char" then
      if a:match("%d") and #input < pinLen then input = input .. a end
    elseif e == "key" then
      if a == keys.backspace then
        input = input:sub(1, math.max(0, #input-1))
      elseif a == keys.enter then
        if #input == pinLen then return input end
      elseif a == keys.escape then
        return nil
      end
    end
  end
end

function settings.draw(state)
  ui.clearButtons()
  local w,h = term.getSize()
  ui.fill(config.C_BG)
  ui.statusBar("Settings", os.date("%H:%M"))

  ui.card(2,3,w-3,4,config.C_ACCENT)
  ui.text(4,4,"Device", colors.black, config.C_ACCENT)
  ui.text(4,6,"Name: "..tostring(state.settings.deviceName or "VibePhone"), config.C_TEXT, config.C_SURFACE)
  local ch = "Change"
  ui.text(w-#ch-2,6,ch,config.C_OK,config.C_SURFACE)
  ui.addButton("chg_name", w-#ch-2,6,#ch,1)

  ui.card(2,8,w-3,4,config.C_ACCENT)
  ui.text(4,9,"Security", colors.black, config.C_ACCENT)
  ui.text(4,11,"PIN: "..string.rep("●", config.PIN_LENGTH), config.C_TEXT, config.C_SURFACE)
  ui.text(w-#ch-2,11,ch,config.C_OK,config.C_SURFACE)
  ui.addButton("chg_pin", w-#ch-2,11,#ch,1)

  local back = "Back"
  ui.text(2,h,back,config.C_ACCENT,config.C_BG)
  ui.addButton("back", 2,h,#back,1)
end

function settings.run(state)
  while true do
    settings.draw(state)
    local e,a,x,y = os.pullEvent()
    if e == "mouse_click" then
      local id = ui.hit(x,y)
      if id == "back" then return end

      if id == "chg_name" then
        local s = promptLine("New device name")
        if s and #s > 0 then
          state.settings.deviceName = s
          state.status = "Name updated."
          storage.save(state)
        end
      elseif id == "chg_pin" then
        local p1 = promptPin("New PIN", config.PIN_LENGTH)
        if p1 then
          local p2 = promptPin("Confirm PIN", config.PIN_LENGTH)
          if p2 and p1 == p2 then
            state.pin = p1
            state.status = "PIN updated."
            storage.save(state)
          else
            state.status = "PIN mismatch."
          end
        end
      end
    elseif e == "key" and a == keys.escape then
      return
    end
  end
end

return settings
