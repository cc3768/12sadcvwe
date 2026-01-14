local cfg = require("config")

local ui  = require("ui_common")



local M = {}



local index = 1

local dirty = true

local hits = {}



local menu = {

  "Appearance",

  "Pricing",

  "Catalog",

  "Save Config",

  "Exit"

}



-- =========================

-- DRAW

-- =========================

local function draw()

  term.setBackgroundColor(colors.black)

  term.clear()

  hits = {}



  local w, h = term.getSize()



  -- Header

  ui.panel(term, 1, 1, w, 3, cfg.ui.header or colors.gray)

  ui.label(term, 3, 2, "SHOP SETTINGS", colors.white)



  local y = 5

  for i, item in ipairs(menu) do

    ui.panel(

      term,

      3, y,

      w - 6, 1,

      index == i and cfg.ui.accent or colors.gray

    )

    ui.label(term, 5, y, item, colors.white)



    table.insert(hits, {

      index = i,

      x1 = 3, x2 = w - 3,

      y1 = y, y2 = y

    })



    y = y + 2

  end

end



-- =========================

-- ACTIONS

-- =========================

local function doAction(choice)

  if choice == "Appearance" then

    term.clear()

    term.setCursorPos(1,1)

    write("New shop title: ")

    cfg.ui.title = read()



  elseif choice == "Pricing" then

    for name, mat in pairs(cfg.materials) do

      term.clear()

      print("Material: "..name)

      print("Current price: "..mat.price)

      write("New price (blank to skip): ")

      local v = read()

      if v ~= "" then

        mat.price = tonumber(v) or mat.price

      end

    end



  elseif choice == "Catalog" then

    for name, tool in pairs(cfg.tools) do

      term.clear()

      print("Tool: "..name)

      print("Enabled: "..tostring(tool.enabled))

      write("Toggle? (y/n): ")

      if read():lower() == "y" then

        tool.enabled = not tool.enabled

      end

    end



  elseif choice == "Save Config" then

    cfg.save()

    term.clear()

    print("Config saved.")

    sleep(0.8)



  elseif choice == "Exit" then

    term.clear()

    return "exit"

  end

end



-- =========================

-- LOOP

-- =========================

function M.start()

  dirty = true



  while true do

    if dirty then

      draw()

      dirty = false

    end



    local event, p1, p2, p3 = os.pullEvent()



    -- Keyboard navigation

    if event == "key" then

      if p1 == keys.up then

        index = math.max(1, index - 1)

        dirty = true



      elseif p1 == keys.down then

        index = math.min(#menu, index + 1)

        dirty = true



      elseif p1 == keys.enter then

        local result = doAction(menu[index])

        if result == "exit" then return end

        dirty = true

      end



    -- Mouse support (THIS WAS MISSING)

    elseif event == "mouse_click" then

      local x, y = p2, p3

      for _, hit in ipairs(hits) do

        if x >= hit.x1 and x <= hit.x2

        and y >= hit.y1 and y <= hit.y2 then

          index = hit.index

          local result = doAction(menu[index])

          if result == "exit" then return end

          dirty = true

          break

        end

      end

    end

  end

end



return M

