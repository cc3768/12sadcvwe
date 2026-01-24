local cfg = require("config")
local ui  = require("ui_common")

local M = {}

-- =========================
-- Small shell-first config UI (keyboard + mouse).
-- Open from main.lua by pressing C.
-- =========================

local state = {
  page = "menu",
  idx = 1,
  selMaterial = nil,
  selGrade = nil,
  selTool = nil,
  selPart = nil,
  message = nil,
}

local hits = {}

-- ---------- utils ----------

local PALETTE = {
  { name = "white",      v = colors.white },
  { name = "orange",     v = colors.orange },
  { name = "magenta",    v = colors.magenta },
  { name = "lightBlue",  v = colors.lightBlue },
  { name = "yellow",     v = colors.yellow },
  { name = "lime",       v = colors.lime },
  { name = "pink",       v = colors.pink },
  { name = "gray",       v = colors.gray },
  { name = "lightGray",  v = colors.lightGray },
  { name = "cyan",       v = colors.cyan },
  { name = "purple",     v = colors.purple },
  { name = "blue",       v = colors.blue },
  { name = "brown",      v = colors.brown },
  { name = "green",      v = colors.green },
  { name = "red",        v = colors.red },
  { name = "black",      v = colors.black },
}

local function clamp(n, a, b)
  if n < a then return a end
  if n > b then return b end
  return n
end

local function sortedKeys(t)
  local out = {}
  for k in pairs(t or {}) do out[#out + 1] = k end
  table.sort(out)
  return out
end

local function colorName(v)
  for _,c in ipairs(PALETTE) do
    if c.v == v then return c.name end
  end
  return tostring(v)
end

local function cyclePalette(cur, dir)
  local idx = 1
  for i,c in ipairs(PALETTE) do
    if c.v == cur then idx = i break end
  end
  idx = idx + (dir or 1)
  if idx > #PALETTE then idx = 1 end
  if idx < 1 then idx = #PALETTE end
  return PALETTE[idx].v
end

local function toast(msg)
  state.message = msg
end

local function promptLine(title, initial)
  term.setBackgroundColor(colors.black)
  term.clear()
  term.setCursorPos(1,1)
  print(title)
  if initial ~= nil then
    print("Current: " .. tostring(initial))
  end
  write("> ")
  return read()
end

local function promptNumber(title, initial)
  local s = promptLine(title, initial)
  if s == "" then return nil end
  local n = tonumber(s)
  return n
end

local function listToggle(list, value)
  list = list or {}
  for i,v in ipairs(list) do
    if v == value then
      table.remove(list, i)
      return list
    end
  end
  list[#list + 1] = value
  table.sort(list)
  return list
end

local function inList(list, value)
  for _,v in ipairs(list or {}) do
    if v == value then return true end
  end
  return false
end

local function collectParts()
  local seen, parts = {}, {}
  for _,tool in pairs(cfg.tools or {}) do
    for _,p in ipairs(tool.parts or {}) do
      if not seen[p] then
        seen[p] = true
        parts[#parts + 1] = p
      end
    end
  end
  table.sort(parts)
  return parts
end

-- ---------- drawing helpers ----------

local function addHit(r)
  hits[#hits + 1] = r
end

local function drawTopBar(title)
  local w, _ = term.getSize()
  local hb = (cfg.ui and cfg.ui.header) or colors.gray
  ui.panel(term, 1, 1, w, 3, hb)
  ui.label(term, 3, 2, title, colors.white, hb)

  if state.page ~= "menu" then
    ui.button(term, w - 10, 2, 9, 1, "< BACK", colors.black, colors.white)
    addHit({ kind = "back", x1 = w - 10, x2 = w - 2, y1 = 2, y2 = 2 })
  end

  if state.message then
    ui.rightText(term, w - 12, 1, ui.truncate(state.message, 22), colors.yellow, hb)
  end
end

local function drawMenu()
  hits = {}
  state.message = state.message

  local w, h = term.getSize()
  term.setBackgroundColor(colors.black)
  term.clear()
  drawTopBar("SHOP SETTINGS")

  local items = {
    { key = "appearance", label = "Appearance" },
    { key = "materials",  label = "Materials" },
    { key = "grades",     label = "Grades" },
    { key = "parts",      label = "Part Rules" },
    { key = "catalog",    label = "Tool Catalog" },
    { key = "rednet",     label = "Rednet" },
    { key = "monitors",   label = "Monitors" },
    { key = "save",       label = "Save Config" },
    { key = "exit",       label = "Exit" },
  }

  state.idx = clamp(state.idx, 1, #items)

  local y = 5
  for i,item in ipairs(items) do
    local bg = (i == state.idx) and ((cfg.ui and cfg.ui.accent) or colors.blue) or colors.gray
    ui.panel(term, 3, y, w - 6, 1, bg)
    ui.label(term, 5, y, item.label, colors.white, bg)
    addHit({ kind = "menu", key = item.key, index = i, x1 = 3, x2 = w - 3, y1 = y, y2 = y })
    y = y + 2
  end
end

local function drawAppearance()
  hits = {}
  local w, h = term.getSize()
  term.setBackgroundColor(colors.black)
  term.clear()
  drawTopBar("APPEARANCE")

  local x1, y1 = 3, 5
  ui.box(term, x1, y1, w - 6, h - 6, colors.black, colors.gray, "Theme", colors.white)

  ui.label(term, x1 + 2, y1 + 2, "Title:", colors.white)
  ui.label(term, x1 + 10, y1 + 2, ui.truncate((cfg.ui and cfg.ui.title) or "", w - 22), colors.yellow)
  ui.button(term, w - 14, y1 + 2, 10, 1, "EDIT", colors.blue, colors.white)
  addHit({ kind = "edit_title", x1 = w - 14, x2 = w - 5, y1 = y1 + 2, y2 = y1 + 2 })

  local function colorRow(label, key, row)
    local v = cfg.ui and cfg.ui[key]
    ui.label(term, x1 + 2, row, label .. ":", colors.white)
    ui.panel(term, x1 + 14, row, 10, 1, v or colors.black)
    ui.label(term, x1 + 26, row, colorName(v), colors.lightGray)
    ui.button(term, w - 20, row, 6, 1, "<", colors.gray, colors.white)
    ui.button(term, w - 13, row, 6, 1, ">", colors.gray, colors.white)
    addHit({ kind = "color", key = key, dir = -1, x1 = w - 20, x2 = w - 15, y1 = row, y2 = row })
    addHit({ kind = "color", key = key, dir = 1,  x1 = w - 13, x2 = w - 8,  y1 = row, y2 = row })
  end

  local row = y1 + 4
  colorRow("Background", "background", row)
  row = row + 2
  colorRow("Header", "header", row)
  row = row + 2
  colorRow("Accent", "accent", row)

  ui.label(term, x1 + 2, h - 2, "Tip: colors affect BOTH monitor + shell UIs", colors.lightGray)
end

local function drawMaterials()
  hits = {}
  local w, h = term.getSize()
  term.setBackgroundColor(colors.black)
  term.clear()
  drawTopBar("MATERIALS")

  local list = sortedKeys(cfg.materials or {})
  if #list == 0 then
    ui.label(term, 3, 5, "No materials in cfg.materials", colors.red)
    return
  end

  state.selMaterial = state.selMaterial or list[1]

  local leftW = math.floor(w * 0.55)
  if leftW < 22 then leftW = 22 end
  if leftW > w - 20 then leftW = w - 20 end

  ui.box(term, 2, 4, leftW, h - 5, colors.black, colors.gray, "Materials", colors.white)
  ui.box(term, 2 + leftW, 4, w - leftW - 1, h - 5, colors.black, colors.gray, "Selected", colors.white)

  local y = 6
  for _,name in ipairs(list) do
    if y > h - 2 then break end
    local mat = cfg.materials[name]
    local sel = (name == state.selMaterial)
    local bg = sel and ((cfg.ui and cfg.ui.accent) or colors.blue) or colors.black
    local fg = sel and colors.white or colors.lightGray

    ui.panel(term, 3, y, leftW - 2, 1, bg)
    ui.label(term, 4, y, ui.truncate(name, leftW - 18), fg, bg)

    local enabled = (mat and mat.enabled ~= false)
    ui.rightText(term, 2 + leftW - 8, y, enabled and "ON" or "OFF", enabled and colors.lime or colors.red, bg)
    ui.rightText(term, 2 + leftW - 2, y, tostring(mat and mat.price or 0) .. "$", colors.yellow, bg)

    addHit({ kind = "select_material", name = name, x1 = 3, x2 = leftW, y1 = y, y2 = y })
    y = y + 1
  end

  local sel = state.selMaterial
  local mat = cfg.materials[sel]
  if mat then
    local rx = 3 + leftW
    local ry = 6

    ui.label(term, rx, ry, "Name:", colors.white)
    ui.label(term, rx + 6, ry, sel, colors.yellow)
    ry = ry + 2

    ui.label(term, rx, ry, "Enabled:", colors.white)
    ui.label(term, rx + 9, ry, (mat.enabled ~= false) and "true" or "false", (mat.enabled ~= false) and colors.lime or colors.red)
    ui.button(term, rx, ry + 1, w - leftW - 5, 1, "TOGGLE ENABLE", colors.gray, colors.white)
    addHit({ kind = "toggle_material", name = sel, x1 = rx, x2 = w - 3, y1 = ry + 1, y2 = ry + 1 })
    ry = ry + 3

    ui.label(term, rx, ry, "Price/part:", colors.white)
    ui.label(term, rx + 12, ry, tostring(mat.price or 0) .. "$", colors.yellow)
    ui.button(term, rx, ry + 1, w - leftW - 5, 1, "SET PRICE", colors.blue, colors.white)
    addHit({ kind = "set_material_price", name = sel, x1 = rx, x2 = w - 3, y1 = ry + 1, y2 = ry + 1 })
  end
end

local function drawGrades()
  hits = {}
  local w, h = term.getSize()
  term.setBackgroundColor(colors.black)
  term.clear()
  drawTopBar("GRADES")

  local list = sortedKeys(cfg.grades or {})
  if #list == 0 then
    ui.label(term, 3, 5, "No grades in cfg.grades", colors.red)
    return
  end

  state.selGrade = state.selGrade or list[1]

  local leftW = math.floor(w * 0.55)
  if leftW < 22 then leftW = 22 end
  if leftW > w - 20 then leftW = w - 20 end

  ui.box(term, 2, 4, leftW, h - 5, colors.black, colors.gray, "Grades", colors.white)
  ui.box(term, 2 + leftW, 4, w - leftW - 1, h - 5, colors.black, colors.gray, "Selected", colors.white)

  local y = 6
  for _,key in ipairs(list) do
    if y > h - 2 then break end
    local g = cfg.grades[key]
    local sel = (key == state.selGrade)
    local bg = sel and ((cfg.ui and cfg.ui.accent) or colors.blue) or colors.black
    local fg = sel and colors.white or colors.lightGray

    ui.panel(term, 3, y, leftW - 2, 1, bg)
    ui.label(term, 4, y, ui.truncate(key, leftW - 18), fg, bg)
    ui.rightText(term, 2 + leftW - 8, y, (g and g.enabled ~= false) and "ON" or "OFF", (g and g.enabled ~= false) and colors.lime or colors.red, bg)
    ui.rightText(term, 2 + leftW - 2, y, "x" .. tostring(g and g.mult or 1.0), colors.yellow, bg)
    addHit({ kind = "select_grade", key = key, x1 = 3, x2 = leftW, y1 = y, y2 = y })
    y = y + 1
  end

  local key = state.selGrade
  local g = cfg.grades[key]
  if g then
    local rx = 3 + leftW
    local ry = 6

    ui.label(term, rx, ry, "Key:", colors.white)
    ui.label(term, rx + 5, ry, key, colors.yellow)
    ry = ry + 1

    ui.label(term, rx, ry, "Label:", colors.white)
    ui.label(term, rx + 7, ry, tostring(g.label or ""), colors.lightGray)
    ui.button(term, rx, ry + 1, w - leftW - 5, 1, "EDIT LABEL", colors.gray, colors.white)
    addHit({ kind = "edit_grade_label", key = key, x1 = rx, x2 = w - 3, y1 = ry + 1, y2 = ry + 1 })
    ry = ry + 3

    ui.label(term, rx, ry, "Multiplier:", colors.white)
    ui.label(term, rx + 11, ry, "x" .. tostring(g.mult or 1.0), colors.yellow)
    ui.button(term, rx, ry + 1, w - leftW - 5, 1, "SET MULT", colors.blue, colors.white)
    addHit({ kind = "edit_grade_mult", key = key, x1 = rx, x2 = w - 3, y1 = ry + 1, y2 = ry + 1 })
    ry = ry + 3

    ui.label(term, rx, ry, "Enabled:", colors.white)
    ui.label(term, rx + 9, ry, (g.enabled ~= false) and "true" or "false", (g.enabled ~= false) and colors.lime or colors.red)
    ui.button(term, rx, ry + 1, w - leftW - 5, 1, "TOGGLE ENABLE", colors.gray, colors.white)
    addHit({ kind = "toggle_grade", key = key, x1 = rx, x2 = w - 3, y1 = ry + 1, y2 = ry + 1 })
    ry = ry + 3

    ui.label(term, rx, ry, "Default grade:", colors.white)
    ui.label(term, rx + 15, ry, tostring(cfg.defaultGrade or ""), colors.yellow)
    ui.button(term, rx, ry + 1, w - leftW - 5, 1, "SET AS DEFAULT", colors.green, colors.black)
    addHit({ kind = "set_default_grade", key = key, x1 = rx, x2 = w - 3, y1 = ry + 1, y2 = ry + 1 })
  end
end

local function drawPartRules()
  hits = {}
  local w, h = term.getSize()
  term.setBackgroundColor(colors.black)
  term.clear()
  drawTopBar("PART RULES")

  local parts = collectParts()
  local mats = sortedKeys(cfg.materials or {})
  if #parts == 0 then
    ui.label(term, 3, 5, "No parts found in cfg.tools", colors.red)
    return
  end

  state.selPart = state.selPart or parts[1]

  local leftW = math.floor(w * 0.40)
  if leftW < 18 then leftW = 18 end
  if leftW > w - 18 then leftW = w - 18 end

  ui.box(term, 2, 4, leftW, h - 5, colors.black, colors.gray, "Parts", colors.white)
  ui.box(term, 2 + leftW, 4, w - leftW - 1, h - 5, colors.black, colors.gray, "Rule", colors.white)

  local y = 6
  for _,p in ipairs(parts) do
    if y > h - 2 then break end
    local sel = (p == state.selPart)
    local bg = sel and ((cfg.ui and cfg.ui.accent) or colors.blue) or colors.black
    local fg = sel and colors.white or colors.lightGray
    ui.panel(term, 3, y, leftW - 2, 1, bg)
    ui.label(term, 4, y, ui.truncate(p, leftW - 6), fg, bg)
    addHit({ kind = "select_part", part = p, x1 = 3, x2 = leftW, y1 = y, y2 = y })
    y = y + 1
  end

  local part = state.selPart
  cfg.partRules = cfg.partRules or {}
  cfg.partRules[part] = cfg.partRules[part] or {}
  local rule = cfg.partRules[part]
  local allow = rule.allow or {}
  local exclude = rule.exclude or {}

  local rx = 3 + leftW
  local ry = 6
  ui.label(term, rx, ry, "Part:", colors.white)
  ui.label(term, rx + 6, ry, part, colors.yellow)
  ry = ry + 2

  local mode = (rule.mode or "none"):lower()
  if mode ~= "allow" and mode ~= "exclude" then mode = "none" end
  local modeLabel = (mode == "allow") and "ALLOW" or (mode == "exclude") and "EXCLUDE" or "NONE"

  ui.label(term, rx, ry, "Mode:", colors.white)
  ui.label(term, rx + 6, ry, modeLabel, colors.yellow)
  ui.button(term, rx, ry + 1, w - leftW - 5, 1, "TOGGLE MODE", colors.gray, colors.white)
  addHit({ kind = "toggle_rule_mode", part = part, x1 = rx, x2 = w - 3, y1 = ry + 1, y2 = ry + 1 })
  ry = ry + 3

  ui.label(term, rx, ry, "Tap materials below to toggle in the active list", colors.lightGray)
  ry = ry + 1

  local listY = ry
  local colW = math.floor((w - leftW - 7) / 2)
  if colW < 10 then colW = w - leftW - 7 end
  local col1X = rx
  local col2X = rx + colW + 1

  for i,name in ipairs(mats) do
    local col = ((i - 1) % 2) + 1
    local row = listY + math.floor((i - 1) / 2)
    if row > h - 2 then break end

    local active = false
    if mode == "allow" then active = inList(allow, name) end
    if mode == "exclude" then active = inList(exclude, name) end

    local x = (col == 1) and col1X or col2X
    local bg = active and (mode == "exclude" and colors.red or colors.green) or colors.black
    local fg = active and colors.white or colors.lightGray
    ui.panel(term, x, row, colW, 1, bg)
    ui.label(term, x + 1, row, ui.truncate(name, colW - 2), fg, bg)
    addHit({ kind = "toggle_part_material", part = part, mat = name, x1 = x, x2 = x + colW - 1, y1 = row, y2 = row })
  end

  ui.button(term, rx, h - 2, w - leftW - 5, 1, "CLEAR LIST", colors.red, colors.white)
  addHit({ kind = "clear_part_rule", part = part, x1 = rx, x2 = w - 3, y1 = h - 2, y2 = h - 2 })
end

local function drawCatalog()
  hits = {}
  local w, h = term.getSize()
  term.setBackgroundColor(colors.black)
  term.clear()
  drawTopBar("TOOL CATALOG")

  local list = sortedKeys(cfg.tools or {})
  if #list == 0 then
    ui.label(term, 3, 5, "No tools in cfg.tools", colors.red)
    return
  end

  ui.box(term, 2, 4, w - 3, h - 5, colors.black, colors.gray, "Tap to toggle enabled", colors.white)
  local y = 6
  for _,name in ipairs(list) do
    if y > h - 2 then break end
    local t = cfg.tools[name]
    local enabled = (t and t.enabled ~= false)
    local bg = enabled and colors.black or colors.gray
    local fg = enabled and colors.lightGray or colors.white
    ui.panel(term, 3, y, w - 5, 1, bg)
    ui.label(term, 4, y, ui.truncate(name, w - 14), fg, bg)
    ui.rightText(term, w - 3, y, enabled and "ON" or "OFF", enabled and colors.lime or colors.red, bg)
    addHit({ kind = "toggle_tool", tool = name, x1 = 3, x2 = w - 3, y1 = y, y2 = y })
    y = y + 1
  end
end

local function drawRednet()
  hits = {}
  local w, h = term.getSize()
  term.setBackgroundColor(colors.black)
  term.clear()
  drawTopBar("REDNET")

  ui.box(term, 2, 4, w - 3, h - 5, colors.black, colors.gray, "Network", colors.white)

  local x, y = 4, 6
  cfg.rednet = cfg.rednet or {}
  ui.label(term, x, y, "Protocol:", colors.white)
  ui.label(term, x + 10, y, tostring(cfg.rednet.protocol or ""), colors.yellow)
  ui.button(term, w - 18, y, 15, 1, "SET", colors.blue, colors.white)
  addHit({ kind = "set_protocol", x1 = w - 18, x2 = w - 4, y1 = y, y2 = y })
  y = y + 2

  ui.label(term, x, y, "Heartbeat:", colors.white)
  ui.label(term, x + 10, y, tostring(cfg.rednet.heartbeat_interval or 3) .. "s", colors.yellow)
  ui.button(term, w - 18, y, 15, 1, "SET", colors.blue, colors.white)
  addHit({ kind = "set_heartbeat", x1 = w - 18, x2 = w - 4, y1 = y, y2 = y })
end

local function drawMonitors()
  hits = {}
  local w, h = term.getSize()
  term.setBackgroundColor(colors.black)
  term.clear()
  drawTopBar("MONITORS")

  ui.box(term, 2, 4, w - 3, h - 5, colors.black, colors.gray, "Optional monitor preference", colors.white)

  cfg.monitors = cfg.monitors or {}
  local x, y = 4, 6
  ui.label(term, x, y, "Builder monitor side/name:", colors.white)
  ui.label(term, x, y + 1, tostring(cfg.monitors.builder or "(auto)"), colors.yellow)
  ui.button(term, w - 18, y + 1, 15, 1, "SET", colors.blue, colors.white)
  addHit({ kind = "set_builder_mon", x1 = w - 18, x2 = w - 4, y1 = y + 1, y2 = y + 1 })
  y = y + 4

  ui.label(term, x, y, "Queue monitor side/name:", colors.white)
  ui.label(term, x, y + 1, tostring(cfg.monitors.queue or "(none)"), colors.yellow)
  ui.button(term, w - 18, y + 1, 15, 1, "SET", colors.blue, colors.white)
  addHit({ kind = "set_queue_mon", x1 = w - 18, x2 = w - 4, y1 = y + 1, y2 = y + 1 })
end

local function drawSave()
  hits = {}
  local w, h = term.getSize()
  term.setBackgroundColor(colors.black)
  term.clear()
  drawTopBar("SAVE")
  ui.centerText(term, 1, w, 6, "Save current config to config.db", colors.white)
  ui.button(term, math.floor(w / 2) - 8, 8, 16, 3, "SAVE", colors.green, colors.black)
  addHit({ kind = "do_save", x1 = math.floor(w / 2) - 8, x2 = math.floor(w / 2) + 7, y1 = 8, y2 = 10 })
end

local function draw()
  if state.page == "menu" then return drawMenu() end
  if state.page == "appearance" then return drawAppearance() end
  if state.page == "materials" then return drawMaterials() end
  if state.page == "grades" then return drawGrades() end
  if state.page == "parts" then return drawPartRules() end
  if state.page == "catalog" then return drawCatalog() end
  if state.page == "rednet" then return drawRednet() end
  if state.page == "monitors" then return drawMonitors() end
  if state.page == "save" then return drawSave() end
  -- fallback
  state.page = "menu"
  return drawMenu()
end

-- ---------- actions ----------

local function openPage(key)
  state.page = key
  state.message = nil
end

local function handleHit(hit)
  if hit.kind == "back" then
    openPage("menu")
    return
  end

  if hit.kind == "menu" then
    state.idx = hit.index
    if hit.key == "exit" then
      state.page = "exit"
      return
    end
    if hit.key == "save" then
      openPage("save")
      return
    end
    openPage(hit.key)
    return
  end

  if hit.kind == "edit_title" then
    local t = promptLine("Enter new title", (cfg.ui and cfg.ui.title) or "")
    if t ~= "" then
      cfg.ui = cfg.ui or {}
      cfg.ui.title = t
      toast("Title updated")
    end
    return
  end

  if hit.kind == "color" then
    cfg.ui = cfg.ui or {}
    cfg.ui[hit.key] = cyclePalette(cfg.ui[hit.key] or colors.black, hit.dir)
    return
  end

  if hit.kind == "select_material" then
    state.selMaterial = hit.name
    return
  end
  if hit.kind == "toggle_material" then
    local m = cfg.materials[hit.name]
    m.enabled = not (m.enabled ~= false)
    return
  end
  if hit.kind == "set_material_price" then
    local m = cfg.materials[hit.name]
    local n = promptNumber("Set price per part for " .. hit.name, m.price)
    if n then m.price = n; toast("Price updated") end
    return
  end

  if hit.kind == "select_grade" then
    state.selGrade = hit.key
    return
  end
  if hit.kind == "toggle_grade" then
    local g = cfg.grades[hit.key]
    g.enabled = not (g.enabled ~= false)
    return
  end
  if hit.kind == "edit_grade_label" then
    local g = cfg.grades[hit.key]
    local s = promptLine("Set label for grade " .. hit.key, g.label)
    if s ~= "" then g.label = s; toast("Label updated") end
    return
  end
  if hit.kind == "edit_grade_mult" then
    local g = cfg.grades[hit.key]
    local n = promptNumber("Set multiplier for grade " .. hit.key .. " (e.g. 1.25)", g.mult)
    if n then g.mult = n; toast("Multiplier updated") end
    return
  end
  if hit.kind == "set_default_grade" then
    cfg.defaultGrade = hit.key
    toast("Default set")
    return
  end

  if hit.kind == "select_part" then
    state.selPart = hit.part
    return
  end
  if hit.kind == "toggle_rule_mode" then
    cfg.partRules = cfg.partRules or {}
    cfg.partRules[hit.part] = cfg.partRules[hit.part] or {}
    local r = cfg.partRules[hit.part]

    local mode = (r.mode or "none"):lower()
    if mode ~= "allow" and mode ~= "exclude" then mode = "none" end

    -- cycle: none -> exclude -> allow -> none
    if mode == "none" then
      r.mode = "exclude"
      r.exclude = r.exclude or {}
      r.allow = nil
    elseif mode == "exclude" then
      r.mode = "allow"
      r.allow = r.allow or {}
      r.exclude = nil
    else
      r.mode = nil
      r.allow = nil
      r.exclude = nil
    end
    return
  end
  if hit.kind == "toggle_part_material" then
    cfg.partRules = cfg.partRules or {}
    cfg.partRules[hit.part] = cfg.partRules[hit.part] or {}
    local r = cfg.partRules[hit.part]

    local mode = (r.mode or "none"):lower()
    if mode == "allow" then
      r.allow = listToggle(r.allow, hit.mat)
    elseif mode == "exclude" then
      r.exclude = listToggle(r.exclude, hit.mat)
    end
    return
  end
  if hit.kind == "clear_part_rule" then
    cfg.partRules = cfg.partRules or {}
    cfg.partRules[hit.part] = cfg.partRules[hit.part] or {}
    cfg.partRules[hit.part].mode = nil
    cfg.partRules[hit.part].allow = nil
    cfg.partRules[hit.part].exclude = nil
    toast("Cleared")
    return
  end

  if hit.kind == "toggle_tool" then
    local t = cfg.tools[hit.tool]
    t.enabled = not (t.enabled ~= false)
    return
  end

  if hit.kind == "set_protocol" then
    local s = promptLine("Set rednet protocol", cfg.rednet and cfg.rednet.protocol)
    if s ~= "" then
      cfg.rednet = cfg.rednet or {}
      cfg.rednet.protocol = s
      toast("Protocol updated")
    end
    return
  end
  if hit.kind == "set_heartbeat" then
    local n = promptNumber("Set heartbeat interval (seconds)", (cfg.rednet and cfg.rednet.heartbeat_interval) or 3)
    if n then
      cfg.rednet = cfg.rednet or {}
      cfg.rednet.heartbeat_interval = n
      toast("Heartbeat updated")
    end
    return
  end

  if hit.kind == "set_builder_mon" then
    local s = promptLine("Set builder monitor side/name (blank = auto)", cfg.monitors and cfg.monitors.builder)
    cfg.monitors = cfg.monitors or {}
    if s == "" then cfg.monitors.builder = nil else cfg.monitors.builder = s end
    toast("Builder monitor updated")
    return
  end

  if hit.kind == "set_queue_mon" then
    local s = promptLine("Set queue monitor side/name (blank = none)", cfg.monitors and cfg.monitors.queue)
    cfg.monitors = cfg.monitors or {}
    if s == "" then cfg.monitors.queue = nil else cfg.monitors.queue = s end
    toast("Queue monitor updated")
    return
  end

  if hit.kind == "do_save" then
    cfg.save()
    toast("Saved")
    return
  end
end

-- =========================
-- LOOP
-- =========================

function M.start()
  state.page = "menu"
  state.idx = 1
  state.message = nil

  while true do
    draw()

    local event, p1, p2, p3 = os.pullEvent()

    if state.page == "exit" then
      term.setBackgroundColor(colors.black)
      term.clear()
      return
    end

    if event == "key" then
      if state.page == "menu" then
        if p1 == keys.up then
          state.idx = clamp(state.idx - 1, 1, 9)
        elseif p1 == keys.down then
          state.idx = clamp(state.idx + 1, 1, 9)
        elseif p1 == keys.enter then
          for _,h in ipairs(hits) do
            if h.kind == "menu" and h.index == state.idx then
              handleHit(h)
              break
            end
          end
        end
      else
        if p1 == keys.backspace or p1 == keys.left then
          openPage("menu")
        end
      end

    elseif event == "mouse_click" then
      local x, y = p2, p3
      for _,h in ipairs(hits) do
        if ui.hitRect(x, y, h) then
          handleHit(h)
          break
        end
      end
    end
  end
end

return M
