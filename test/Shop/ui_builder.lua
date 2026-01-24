local cfg = require("config")
local ui  = require("ui_common")

local M = {}

-- =========================
-- STATE
-- =========================
M.state = {
  groupOpen = {
    Armor   = false,
    Tools   = true,
    Weapons = false,
    Ranged  = false,
    Jewelry = false,
  },
  groupSelected = "Tools",
  tool = nil,

  -- parts[partName] = { material="wood", grade="basic" }
  parts = {},

  submit = false,
}

local hits = {}

-- =========================
-- UTIL
-- =========================
local function trunc(s, n)
  s = tostring(s or "")
  if #s <= n then return s end
  return s:sub(1, math.max(1, n-1)) .. "..."
end

local function getEnabledMaterials()
  local list = {}
  for name, mat in pairs(cfg.materials or {}) do
    if mat and mat.enabled ~= false then list[#list+1] = name end
  end
  table.sort(list)
  if #list == 0 then list = {"none"} end

  -- ensure "none" stays first if present
  local out = {}
  if cfg.materials and cfg.materials.none and cfg.materials.none.enabled ~= false then
    out[#out+1] = "none"
  end
  for _,v in ipairs(list) do
    if v ~= "none" then out[#out+1] = v end
  end
  return out
end

local function getGradeDef(id)
  if not cfg.grades then return nil end
  -- grades is expected to be an array
  for _,g in ipairs(cfg.grades) do
    if g and g.id == id then return g end
  end
  return nil
end

local function getEnabledGrades()
  local out = {}
  if type(cfg.grades) == "table" then
    for _,g in ipairs(cfg.grades) do
      if g and g.enabled ~= false and g.id then
        out[#out+1] = g.id
      end
    end
  end
  if #out == 0 then out = { cfg.gradeDefault or "basic" } end
  return out
end

local function cycle(list, current, dir)
  if type(list) ~= "table" or #list == 0 then return current end
  local idx = 1
  for i,v in ipairs(list) do
    if v == current then idx = i break end
  end
  idx = idx + (dir or 1)
  if idx > #list then idx = 1 end
  if idx < 1 then idx = #list end
  return list[idx]
end

local function toolEnabled(name)
  local t = cfg.tools and cfg.tools[name]
  if not t then return false end
  return t.enabled ~= false
end

local function getToolParts(toolName)
  local def = cfg.tools and cfg.tools[toolName]
  return (def and def.parts) or {}
end

local function isExcluded(toolName, partName, materialName)
  if not partName or not materialName then return false end

  -- global exclusions
  if cfg.partMaterialExclusions
    and cfg.partMaterialExclusions[partName]
    and cfg.partMaterialExclusions[partName][materialName]
  then
    return true
  end

  -- per-tool exclusions (cfg.tools[tool].exclude[part][mat] = true)
  local def = cfg.tools and cfg.tools[toolName]
  if def and def.exclude and def.exclude[partName] and def.exclude[partName][materialName] then
    return true
  end

  return false
end

local function allowedMaterialsForPart(toolName, partName)
  local base = getEnabledMaterials()
  local out = {}
  for _,matName in ipairs(base) do
    if not isExcluded(toolName, partName, matName) then
      out[#out+1] = matName
    end
  end

  -- if exclusions removed everything, fall back to enabled list (never empty)
  if #out == 0 then out = base end
  return out
end

local function normalizeSelection(sel)
  if type(sel) == "string" then
    return { material = sel, grade = cfg.gradeDefault or "basic" }
  end
  if type(sel) ~= "table" then
    return { material = "none", grade = cfg.gradeDefault or "basic" }
  end
  sel.material = sel.material or "none"
  sel.grade = sel.grade or (cfg.gradeDefault or "basic")
  return sel
end

local function ensureParts(toolName)
  M.state.parts = {}

  local parts = getToolParts(toolName)
  local grades = getEnabledGrades()

  for _,p in ipairs(parts) do
    local mats = allowedMaterialsForPart(toolName, p)
    M.state.parts[p] = {
      material = mats[1] or "none",
      grade = grades[1] or (cfg.gradeDefault or "basic"),
    }
  end
end

local function partPrice(sel)
  sel = normalizeSelection(sel)

  local mat = cfg.materials and cfg.materials[sel.material]
  local base = (mat and tonumber(mat.price)) or 0

  local g = getGradeDef(sel.grade) or { mult = 1, add = 0, label = tostring(sel.grade) }
  local mult = tonumber(g.mult) or 1
  local add  = tonumber(g.add) or 0

  return math.floor(base * mult + add + 0.5)
end

local function calcTotal()
  local total = 0
  for _,sel in pairs(M.state.parts) do
    total = total + partPrice(sel)
  end
  if cfg.sales and cfg.sales.enabled then
    local d = tonumber(cfg.sales.discount) or 0
    total = math.floor(total * (1 - d) + 0.5)
  end
  return total
end

-- =========================
-- DRAW HELPERS
-- =========================
local function header(m, w)
  ui.panel(m, 1, 1, w, 3, cfg.ui.header or colors.gray)
  ui.label(m, 3, 2, trunc(cfg.ui.title or "THE FORGE", w-6), colors.white)
  ui.label(m, 3, 3, "Tap to select  -  Material + Grade are per-part  -  Press C for config", colors.lightGray)
end

local function sidebar(m, x, y, w, h)
  ui.panel(m, x, y, w, h, colors.gray)
  ui.label(m, x+2, y, "CATALOG", colors.white)

  local cy = y + 2
  local cats = cfg.toolCategories or {}

  local function drawGroup(key, items)
    if cy > y + h - 1 then return end

    local isOpen = M.state.groupOpen[key] and true or false
    local mark = isOpen and "v" or ">"
    local bg = (M.state.groupSelected == key) and (cfg.ui.accent or colors.cyan) or colors.lightGray
    local fg = (M.state.groupSelected == key) and colors.black or colors.black

    ui.panel(m, x+1, cy, w-2, 1, bg)
    ui.label(m, x+2, cy, mark.." "..key, fg)
    hits[#hits+1] = { kind="group", key=key, x1=x+1, x2=x+w-2, y1=cy, y2=cy }
    cy = cy + 1

    if isOpen then
      for _,toolName in ipairs(items or {}) do
        if cy > y + h - 1 then return end
        if toolEnabled(toolName) then
          local sel = (M.state.tool == toolName)
          local tbg = sel and (cfg.ui.accent or colors.cyan) or colors.white
          local tfg = sel and colors.black or colors.black

          ui.panel(m, x+2, cy, w-4, 1, tbg)
          ui.label(m, x+3, cy, trunc(toolName, w-6), tfg)
          hits[#hits+1] = { kind="tool", tool=toolName, x1=x+2, x2=x+w-3, y1=cy, y2=cy }
          cy = cy + 1
        end
      end
      cy = cy + 1
    else
      cy = cy + 1
    end
  end

  drawGroup("Armor", cats.Armor)
  drawGroup("Weapons", cats.Weapons)
  drawGroup("Ranged", cats.Ranged)
  drawGroup("Tools", cats.Tools)
  drawGroup("Jewelry", cats.Jewelry)
end

local function partsPanel(m, x, y, w, h)
  ui.panel(m, x, y, w, h, cfg.ui.background or colors.black)

  if not M.state.tool then
    ui.label(m, x+3, y+2, "Select a tool on the left.", colors.white)
    ui.label(m, x+3, y+4, "Then choose a Material + Grade for each part.", colors.lightGray)
    return
  end

  ui.panel(m, x+1, y+1, w-2, 3, colors.black)
  ui.label(m, x+3, y+1, "TOOL", colors.lightGray)
  ui.label(m, x+3, y+2, trunc(M.state.tool, w-10), colors.white)
  ui.label(m, x+3, y+3, "Tap material or grade to cycle.", colors.gray)

  local parts = getToolParts(M.state.tool)
  local listY = y + 5
  local py = listY

  local labelW = 10
  local gradeW = 10
  local priceW = 8

  local matX = x + 2 + labelW + 2
  local matW = math.max(10, w - (labelW + gradeW + priceW + 10))
  local gradeX = matX + matW + 1
  local priceX = x + w - priceW - 2

  ui.label(m, x+3, py, "PART", colors.lightGray)
  ui.label(m, matX, py, "MATERIAL", colors.lightGray)
  ui.label(m, gradeX, py, "GRADE", colors.lightGray)
  py = py + 1

  for _,part in ipairs(parts) do
    if py > y + h - 7 then break end

    local sel = normalizeSelection(M.state.parts[part])
    local allowedMats = allowedMaterialsForPart(M.state.tool, part)
    local allowedGrades = getEnabledGrades()

    -- part label
    ui.label(m, x+3, py, trunc(part, labelW), colors.white)

    -- material box
    local matBg = colors.lightGray
    ui.panel(m, matX, py, matW, 1, matBg)
    ui.label(m, matX+1, py, trunc(sel.material, matW-2), colors.black)
    hits[#hits+1] = { kind="mat", part=part, x1=matX, x2=matX+matW-1, y1=py, y2=py }

    -- grade box
    local gdef = getGradeDef(sel.grade)
    local glabel = gdef and gdef.label or sel.grade
    ui.panel(m, gradeX, py, gradeW, 1, colors.gray)
    ui.label(m, gradeX+1, py, trunc(glabel, gradeW-2), colors.white)
    hits[#hits+1] = { kind="grade", part=part, x1=gradeX, x2=gradeX+gradeW-1, y1=py, y2=py }

    -- part price
    local p = partPrice(sel)
    local ptxt = tostring(p).."$"
    ui.label(m, priceX, py, (" "):rep(priceW))
    ui.label(m, priceX + math.max(0, priceW-#ptxt), py, ptxt, colors.yellow)

    py = py + 2
  end

  -- Place order button
  local btnY = y + h - 5
  ui.panel(m, x+2, btnY, w-4, 3, colors.lime)
  ui.label(m, x+math.floor(w/2)-5, btnY+1, "PLACE ORDER", colors.black)
  hits[#hits+1] = { kind="place", x1=x+2, x2=x+w-3, y1=btnY, y2=btnY+2 }

  -- Total bar
  local total = calcTotal()
  local barY = y + h - 1
  ui.panel(m, x+2, barY, w-4, 1, colors.black)
  ui.label(m, x+4, barY, "TOTAL: "..tostring(total).."$", colors.lime)
end

-- =========================
-- DRAW
-- =========================
function M.draw(m)
  hits = {}
  m.setBackgroundColor(cfg.ui.background or colors.black)
  m.clear()

  local w,h = m.getSize()
  header(m, w)

  local leftW = math.min(20, math.max(16, math.floor(w * 0.28)))
  sidebar(m, 1, 4, leftW, h-3)
  partsPanel(m, leftW+1, 4, w-leftW, h-3)
end

-- =========================
-- TOUCH
-- =========================
function M.touch(x,y)
  for _,r in ipairs(hits) do
    if ui.hitRect(x,y,r) then
      if r.kind == "group" then
        M.state.groupSelected = r.key
        M.state.groupOpen[r.key] = not M.state.groupOpen[r.key]

      elseif r.kind == "tool" then
        M.state.tool = r.tool
        ensureParts(r.tool)

      elseif r.kind == "mat" then
        if M.state.tool then
          local mats = allowedMaterialsForPart(M.state.tool, r.part)
          local sel = normalizeSelection(M.state.parts[r.part])
          sel.material = cycle(mats, sel.material, 1)
          M.state.parts[r.part] = sel
        end

      elseif r.kind == "grade" then
        if M.state.tool then
          local grades = getEnabledGrades()
          local sel = normalizeSelection(M.state.parts[r.part])
          sel.grade = cycle(grades, sel.grade, 1)
          M.state.parts[r.part] = sel
        end

      elseif r.kind == "place" then
        if M.state.tool then
          M.state.submit = true
        end
      end
      return
    end
  end
end

-- =========================
-- RESET
-- =========================
function M.reset()
  M.state.tool = nil
  M.state.parts = {}
  M.state.submit = false
  M.state.groupSelected = "Tools"
  M.state.groupOpen = {
    Armor   = false,
    Tools   = true,
    Weapons = false,
    Ranged  = false,
    Jewelry = false,
  }
end

-- =========================
-- ORDER OUTPUT
-- returns nil unless the user pressed PLACE ORDER
-- =========================
function M.getOrder(user)
  if not M.state.submit then return nil end
  M.state.submit = false

  -- Copy out:
  -- 1) parts (materials only) for backwards compatibility
  -- 2) grades (grade per part)
  -- 3) parts_detail (material+grade per part)
  local partsMat = {}
  local partsGrade = {}
  local partsDetail = {}

  for part,sel0 in pairs(M.state.parts) do
    local sel = normalizeSelection(sel0)
    partsMat[part] = sel.material
    partsGrade[part] = sel.grade
    partsDetail[part] = { material = sel.material, grade = sel.grade }
  end

  local order = {
    id = os.epoch("utc"),
    user = user,
    tool = M.state.tool,
    parts = partsMat,
    grades = partsGrade,
    parts_detail = partsDetail,
    status = "pending",
    total = calcTotal(),
    _submit = true,
  }

  if M.reset then M.reset() end
  return order
end

return M
