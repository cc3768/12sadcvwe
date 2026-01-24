local cfg = require("config")
local ui  = require("ui_common")

local M = {}

local index = 1
local dirty = true
local hits = {}

local menu = {
  "Appearance",
  "Materials",
  "Grades",
  "Exclusions",
  "Catalog",
  "Rednet/Peripherals",
  "Save Config",
  "Exit"
}

-- =========================
-- UTILS
-- =========================
local function sortedKeys(t)
  local out = {}
  for k,_ in pairs(t or {}) do out[#out+1] = k end
  table.sort(out)
  return out
end

local function pause(msg)
  if msg then print(msg) end
  print("Press Enter...")
  read()
end

local function colorByName(name)
  name = tostring(name or ""):lower():gsub("%s+","")
  local map = {
    white=colors.white, orange=colors.orange, magenta=colors.magenta, lightblue=colors.lightBlue,
    yellow=colors.yellow, lime=colors.lime, pink=colors.pink, gray=colors.gray, grey=colors.grey,
    lightgray=colors.lightGray, lightgrey=colors.lightGrey, cyan=colors.cyan, purple=colors.purple,
    blue=colors.blue, brown=colors.brown, green=colors.green, red=colors.red, black=colors.black
  }
  return map[name]
end

local function getAllParts()
  local set = {}
  for _,tool in pairs(cfg.tools or {}) do
    if tool and tool.parts then
      for _,p in ipairs(tool.parts) do set[p] = true end
    end
  end
  return sortedKeys(set)
end

local function ensureGrades()
  cfg.grades = cfg.grades or {}
  if #cfg.grades == 0 then
    cfg.grades = {
      { id = "basic",  label = "Basic",  mult = 1.00, add = 0,  enabled = true },
      { id = "fine",   label = "Fine",   mult = 1.15, add = 5,  enabled = true },
      { id = "master", label = "Master", mult = 1.35, add = 15, enabled = true },
    }
    cfg.gradeDefault = "basic"
  end
end

local function gradeIndexById(id)
  for i,g in ipairs(cfg.grades or {}) do
    if g and g.id == id then return i end
  end
  return nil
end

-- =========================
-- DRAW (main menu)
-- =========================
local function draw()
  term.setBackgroundColor(colors.black)
  term.clear()
  hits = {}

  local w, h = term.getSize()

  ui.panel(term, 1, 1, w, 3, cfg.ui.header or colors.gray)
  ui.label(term, 3, 2, "FORGE CONFIG", colors.white)
  ui.label(term, 3, 3, "Click or use Up/Down + Enter. (Esc = Exit)", colors.lightGray)

  local y = 5
  for i, item in ipairs(menu) do
    ui.panel(term, 3, y, w - 6, 1, index == i and (cfg.ui.accent or colors.cyan) or colors.gray)
    ui.label(term, 5, y, item, colors.white)
    hits[#hits+1] = { index=i, x1=3, x2=w-3, y1=y, y2=y }
    y = y + 2
  end
end

-- =========================
-- SUB-MENUS
-- =========================
local function appearance()
  term.clear()
  term.setCursorPos(1,1)
  print("APPEARANCE")
  print("")
  write("Title ["..tostring(cfg.ui.title or "").."]: ")
  local t = read()
  if t ~= "" then cfg.ui.title = t end

  print("")
  print("Colors accept names like: cyan, gray, black, blue, lime, red, ...")
  write("Accent ["..tostring(cfg.ui.accent).."]: ")
  local a = read()
  if a ~= "" then
    local c = colorByName(a)
    if c then cfg.ui.accent = c else pause("Invalid color name.") end
  end

  write("Header ["..tostring(cfg.ui.header).."]: ")
  local h = read()
  if h ~= "" then
    local c = colorByName(h)
    if c then cfg.ui.header = c else pause("Invalid color name.") end
  end

  write("Background ["..tostring(cfg.ui.background).."]: ")
  local b = read()
  if b ~= "" then
    local c = colorByName(b)
    if c then cfg.ui.background = c else pause("Invalid color name.") end
  end
end

local function materialsMenu()
  local names = sortedKeys(cfg.materials)
  while true do
    term.clear()
    term.setCursorPos(1,1)
    print("MATERIALS")
    print("Enter: # to edit  |  t# toggle  |  b back")
    print("")

    for i,name in ipairs(names) do
      local m = cfg.materials[name]
      local en = (m and m.enabled ~= false) and "ON " or "OFF"
      local price = m and m.price or 0
      print(string.format("%2d) %-14s  %s  price=%s", i, name, en, tostring(price)))
    end

    write("\n> ")
    local cmd = read():gsub("%s+","")
    if cmd == "b" or cmd == "B" then return end

    local toggle = cmd:match("^t(%d+)$")
    local edit   = cmd:match("^(%d+)$")

    if toggle then
      local i = tonumber(toggle)
      local name = names[i]
      if name and cfg.materials[name] then
        cfg.materials[name].enabled = not (cfg.materials[name].enabled ~= false)
      end

    elseif edit then
      local i = tonumber(edit)
      local name = names[i]
      local m = name and cfg.materials[name]
      if m then
        term.clear()
        term.setCursorPos(1,1)
        print("EDIT MATERIAL: "..name)
        print("")
        print("Enabled: "..tostring(m.enabled ~= false))
        write("Toggle enabled? (y/n): ")
        if read():lower() == "y" then
          m.enabled = not (m.enabled ~= false)
        end
        print("")
        write("Price ["..tostring(m.price or 0).."]: ")
        local v = read()
        if v ~= "" then
          m.price = tonumber(v) or m.price
        end
      end
    end

    names = sortedKeys(cfg.materials)
  end
end

local function gradesMenu()
  ensureGrades()
  while true do
    term.clear()
    term.setCursorPos(1,1)
    print("GRADES (applied per-part)")
    print("Commands: e# edit | t# toggle | a add | d# delete | def# set default | b back")
    print("")

    for i,g in ipairs(cfg.grades) do
      local en = (g.enabled ~= false) and "ON " or "OFF"
      local def = (cfg.gradeDefault == g.id) and "  [default]" or ""
      print(string.format("%2d) %-10s %-10s %s  mult=%s add=%s%s",
        i, tostring(g.id), tostring(g.label or g.id), en, tostring(g.mult or 1), tostring(g.add or 0), def))
    end

    write("\n> ")
    local cmd = read():gsub("%s+","")
    if cmd:lower() == "b" then return end

    local edit = cmd:match("^e(%d+)$")
    local tog  = cmd:match("^t(%d+)$")
    local del  = cmd:match("^d(%d+)$")
    local def  = cmd:match("^def(%d+)$")

    if cmd:lower() == "a" then
      term.clear()
      term.setCursorPos(1,1)
      print("ADD GRADE")
      write("id (no spaces): ")
      local id = read():gsub("%s+","")
      if id == "" then
        pause("Cancelled.")
      elseif gradeIndexById(id) then
        pause("That id already exists.")
      else
        write("label: ")
        local label = read()
        write("multiplier (e.g. 1.15): ")
        local mult = tonumber(read()) or 1
        write("add (flat add): ")
        local add = tonumber(read()) or 0
        cfg.grades[#cfg.grades+1] = { id=id, label=label ~= "" and label or id, mult=mult, add=add, enabled=true }
      end

    elseif edit then
      local i = tonumber(edit)
      local g = cfg.grades[i]
      if g then
        term.clear()
        term.setCursorPos(1,1)
        print("EDIT GRADE #"..i)
        print("id: "..tostring(g.id))
        write("label ["..tostring(g.label or g.id).."]: ")
        local label = read()
        if label ~= "" then g.label = label end

        write("mult ["..tostring(g.mult or 1).."]: ")
        local mult = read()
        if mult ~= "" then g.mult = tonumber(mult) or g.mult end

        write("add ["..tostring(g.add or 0).."]: ")
        local add = read()
        if add ~= "" then g.add = tonumber(add) or g.add end

        write("enabled (y/n) ["..((g.enabled ~= false) and "y" or "n").."]: ")
        local en = read():lower()
        if en == "y" then g.enabled = true end
        if en == "n" then g.enabled = false end

        if not cfg.gradeDefault or cfg.gradeDefault == "" then
          cfg.gradeDefault = g.id
        end
      end

    elseif tog then
      local i = tonumber(tog)
      local g = cfg.grades[i]
      if g then g.enabled = not (g.enabled ~= false) end

    elseif del then
      local i = tonumber(del)
      if cfg.grades[i] then
        local removed = table.remove(cfg.grades, i)
        if removed and cfg.gradeDefault == removed.id then
          cfg.gradeDefault = (cfg.grades[1] and cfg.grades[1].id) or "basic"
        end
      end

    elseif def then
      local i = tonumber(def)
      local g = cfg.grades[i]
      if g then cfg.gradeDefault = g.id end
    end
  end
end

local function toggleMap(map, key)
  if map[key] then map[key] = nil else map[key] = true end
end

local function exclusionsGlobal()
  cfg.partMaterialExclusions = cfg.partMaterialExclusions or {}
  local parts = getAllParts()
  local mats = sortedKeys(cfg.materials)

  while true do
    term.clear()
    term.setCursorPos(1,1)
    print("GLOBAL PART EXCLUSIONS")
    print("Choose a part # to edit. (b back)")
    print("")
    for i,p in ipairs(parts) do
      print(string.format("%2d) %s", i, p))
    end
    write("\n> ")
    local cmd = read():gsub("%s+","")
    if cmd:lower() == "b" then return end
    local pi = tonumber(cmd)
    local part = pi and parts[pi]
    if not part then
      pause("Invalid.")
    else
      cfg.partMaterialExclusions[part] = cfg.partMaterialExclusions[part] or {}
      local ex = cfg.partMaterialExclusions[part]

      while true do
        term.clear()
        term.setCursorPos(1,1)
        print("EXCLUSIONS for part: "..part)
        print("Toggle material #: (b back)  (c clear)")
        print("")
        for i,m in ipairs(mats) do
          local mark = ex[m] and "[X]" or "[ ]"
          print(string.format("%2d) %s %-14s", i, mark, m))
        end
        write("\n> ")
        local c = read():gsub("%s+","")
        if c:lower() == "b" then break end
        if c:lower() == "c" then
          cfg.partMaterialExclusions[part] = {}
          ex = cfg.partMaterialExclusions[part]
        else
          local mi = tonumber(c)
          local mat = mi and mats[mi]
          if mat then toggleMap(ex, mat) end
        end
      end
    end
  end
end

local function exclusionsTool()
  local toolNames = sortedKeys(cfg.tools)
  local mats = sortedKeys(cfg.materials)

  while true do
    term.clear()
    term.setCursorPos(1,1)
    print("TOOL-SPECIFIC EXCLUSIONS")
    print("Choose a tool # to edit. (b back)")
    print("")
    for i,t in ipairs(toolNames) do
      local en = (cfg.tools[t] and cfg.tools[t].enabled ~= false) and "" or " (disabled)"
      print(string.format("%2d) %s%s", i, t, en))
    end
    write("\n> ")
    local cmd = read():gsub("%s+","")
    if cmd:lower() == "b" then return end

    local ti = tonumber(cmd)
    local toolName = ti and toolNames[ti]
    local tool = toolName and cfg.tools[toolName]
    if not tool then
      pause("Invalid.")
    else
      tool.exclude = tool.exclude or {}
      local parts = tool.parts or {}

      while true do
        term.clear()
        term.setCursorPos(1,1)
        print("Tool: "..toolName)
        print("Choose part # to edit. (b back)")
        print("")
        for i,p in ipairs(parts) do
          print(string.format("%2d) %s", i, p))
        end
        write("\n> ")
        local cmd2 = read():gsub("%s+","")
        if cmd2:lower() == "b" then break end

        local pi = tonumber(cmd2)
        local part = pi and parts[pi]
        if part then
          tool.exclude[part] = tool.exclude[part] or {}
          local ex = tool.exclude[part]

          while true do
            term.clear()
            term.setCursorPos(1,1)
            print("EXCLUSIONS for "..toolName.." / "..part)
            print("Toggle material #: (b back)  (c clear)")
            print("")
            for i,m in ipairs(mats) do
              local mark = ex[m] and "[X]" or "[ ]"
              print(string.format("%2d) %s %-14s", i, mark, m))
            end
            write("\n> ")
            local c = read():gsub("%s+","")
            if c:lower() == "b" then break end
            if c:lower() == "c" then
              tool.exclude[part] = {}
              ex = tool.exclude[part]
            else
              local mi = tonumber(c)
              local mat = mi and mats[mi]
              if mat then toggleMap(ex, mat) end
            end
          end
        end
      end
    end
  end
end

local function exclusionsMenu()
  while true do
    term.clear()
    term.setCursorPos(1,1)
    print("EXCLUSIONS")
    print("1) Global exclusions (by part)")
    print("2) Tool exclusions (tool + part)")
    print("b) Back")
    write("\n> ")
    local cmd = read():lower():gsub("%s+","")
    if cmd == "b" then return end
    if cmd == "1" then exclusionsGlobal() end
    if cmd == "2" then exclusionsTool() end
  end
end

local function catalogMenu()
  local names = sortedKeys(cfg.tools)
  while true do
    term.clear()
    term.setCursorPos(1,1)
    print("CATALOG (enable/disable tools)")
    print("Commands: t# toggle  |  b back")
    print("")
    for i,name in ipairs(names) do
      local t = cfg.tools[name]
      local en = (t and t.enabled ~= false) and "ON " or "OFF"
      print(string.format("%2d) %-18s  %s", i, name, en))
    end
    write("\n> ")
    local cmd = read():gsub("%s+","")
    if cmd:lower() == "b" then return end
    local t = cmd:match("^t(%d+)$")
    if t then
      local i = tonumber(t)
      local name = names[i]
      if name and cfg.tools[name] then
        cfg.tools[name].enabled = not (cfg.tools[name].enabled ~= false)
      end
    end
    names = sortedKeys(cfg.tools)
  end
end

local function rednetMenu()
  term.clear()
  term.setCursorPos(1,1)
  print("REDNET / PERIPHERALS")
  print("")

  write("Rednet protocol ["..tostring(cfg.rednet.protocol).."]: ")
  local p = read()
  if p ~= "" then cfg.rednet.protocol = p end

  write("Heartbeat interval seconds ["..tostring(cfg.rednet.heartbeat_interval or 3).."]: ")
  local hb = read()
  if hb ~= "" then cfg.rednet.heartbeat_interval = tonumber(hb) or cfg.rednet.heartbeat_interval end

  print("")
  write("Builder monitor side/name (blank = auto) ["..tostring(cfg.monitors.builder or "").."]: ")
  local ms = read()
  if ms ~= "" then cfg.monitors.builder = ms end
  if ms == "" then cfg.monitors.builder = nil end

  print("")
  cfg.peripherals = cfg.peripherals or {}
  write("PlayerDetector side (blank = auto-find) ["..tostring(cfg.peripherals.playerDetectorSide or "").."]: ")
  local ds = read()
  if ds ~= "" then cfg.peripherals.playerDetectorSide = ds end
  if ds == "" then cfg.peripherals.playerDetectorSide = nil end
end

-- =========================
-- ACTIONS
-- =========================
local function doAction(choice)
  if choice == "Appearance" then
    appearance()

  elseif choice == "Materials" then
    materialsMenu()

  elseif choice == "Grades" then
    gradesMenu()

  elseif choice == "Exclusions" then
    exclusionsMenu()

  elseif choice == "Catalog" then
    catalogMenu()

  elseif choice == "Rednet/Peripherals" then
    rednetMenu()

  elseif choice == "Save Config" then
    cfg.save()
    term.clear()
    term.setCursorPos(1,1)
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

    if event == "key" then
      if p1 == keys.up then
        index = math.max(1, index - 1); dirty = true
      elseif p1 == keys.down then
        index = math.min(#menu, index + 1); dirty = true
      elseif p1 == keys.enter then
        local r = doAction(menu[index])
        dirty = true
        if r == "exit" then return end
      elseif p1 == keys.escape then
        term.clear()
        return
      end

    elseif event == "mouse_click" then
      local x,y = p2,p3
      for _,r in ipairs(hits) do
        if ui.hitRect(x,y,r) then
          index = r.index
          local rr = doAction(menu[index])
          dirty = true
          if rr == "exit" then return end
          break
        end
      end
    end
  end
end

return M
