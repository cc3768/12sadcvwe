local cfg = require("config")
local ui  = require("ui_common")

local M = {}

-- UI state
local state = {
  mode = "list",         -- "list" or "detail"
  selected = 1,          -- selected index in list
  scroll = 0,            -- list scroll offset (0-based)
}

local hits = {}

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function drawHeader(m, w, title)
  ui.panel(m, 1, 1, w, 3, cfg.ui.header or colors.gray)
  ui.label(m, 3, 2, title, colors.white)
end

local function listView(m, orders)
  local w,h = m.getSize()
  m.setBackgroundColor(cfg.ui.background or colors.black)
  m.clear()
  hits = {}

  drawHeader(m, w, "ORDERS")

  local listY = 4
  local listH = h - 5  -- leave bottom line for hint
  ui.panel(m, 1, listY, w, listH, cfg.ui.background or colors.black)

  if #orders == 0 then
    ui.label(m, 3, listY+1, "No orders", colors.lightGray)
  else
    local visible = listH
    local maxScroll = math.max(0, #orders - visible)
    state.scroll = clamp(state.scroll, 0, maxScroll)

    local start = 1 + state.scroll
    local stop  = math.min(#orders, state.scroll + visible)

    local y = listY
    for i = start, stop do
      local o = orders[i]
      local sel = (i == state.selected)

      local bg = sel and (cfg.ui.accent or colors.blue) or (cfg.ui.background or colors.black)
      ui.panel(m, 1, y, w, 1, bg)

      local fg = colors.red
      if o.status == "completed" then fg = colors.lime end

      local name = tostring(o.user or "unknown")
      if #name > w-4 then name = name:sub(1, w-4) end
      ui.label(m, 3, y, name, fg)

      table.insert(hits, { kind="row", index=i, x1=1, x2=w, y1=y, y2=y })
      y = y + 1
    end
  end

  ui.panel(m, 1, h, w, 1, colors.black)
  ui.label(m, 2, h, "Click name to view", colors.gray)
end

local function detailView(m, order)
  local w,h = m.getSize()
  m.setBackgroundColor(cfg.ui.background or colors.black)
  m.clear()
  hits = {}

  drawHeader(m, w, "ORDER DETAILS")

  ui.label(m, 3, 5, "User: "..tostring(order.user or "unknown"), colors.white)
  ui.label(m, 3, 7, "Tool: "..tostring(order.tool or "unknown"), colors.white)

  local total = order.total
  if total == nil and type(order.parts) == "table" then
    local t = 0
    for _,matName in pairs(order.parts) do
      local mat = cfg.materials and cfg.materials[matName]
      t = t + (mat and mat.price or 0)
    end
    total = t
  end
  ui.label(m, 3, 9, "Total: "..tostring(total or 0).."$", colors.yellow)

  -- parts
  local py = 11
  if type(order.parts) == "table" then
    ui.label(m, 3, py, "Parts:", colors.lightGray)
    py = py + 1
    for part, mat in pairs(order.parts) do
      if py >= h-3 then break end
      ui.label(m, 4, py, tostring(part)..": "..tostring(mat), colors.white)
      py = py + 1
    end
  end

  -- buttons
  local btnY = h - 2
  local btnW = math.floor((w - 6)/2)

  -- COMPLETE
  ui.panel(m, 3, btnY, btnW, 2, colors.green)
  ui.label(m, 3 + math.floor(btnW/2) - 4, btnY+1, "COMPLETE", colors.black)
  table.insert(hits, { kind="complete", x1=3, x2=3+btnW-1, y1=btnY, y2=btnY+1 })

  -- CLOSE
  local cx = 4 + btnW
  ui.panel(m, cx, btnY, btnW, 2, colors.gray)
  ui.label(m, cx + math.floor(btnW/2) - 2, btnY+1, "CLOSE", colors.white)
  table.insert(hits, { kind="close", x1=cx, x2=cx+btnW-1, y1=btnY, y2=btnY+1 })
end

-- =========================
-- API
-- =========================

function M.draw(m, orders)
  if state.mode == "detail" then
    local o = orders[state.selected]
    if not o then
      state.mode = "list"
      listView(m, orders)
    else
      detailView(m, o)
    end
  else
    listView(m, orders)
  end
end

-- touch returns: action table or nil
function M.touch(x, y, orders)
  local w,h = term.getSize()
  for _,r in ipairs(hits) do
    if ui.hitRect(x,y,r) then
      if r.kind == "row" then
        state.selected = r.index
        state.mode = "detail"
        return { type="open", index=r.index }
      elseif r.kind == "close" then
        state.mode = "list"
        return { type="close" }
      elseif r.kind == "complete" then
        local o = orders[state.selected]
        if o then
          return { type="complete", index=state.selected, order=o }
        end
      end
    end
  end
  return nil
end

function M.onKey(key, orders)
  if state.mode ~= "list" then return nil end
  if key == keys.up then
    state.selected = math.max(1, state.selected - 1)
    return { type="nav" }
  elseif key == keys.down then
    state.selected = math.min(math.max(1,#orders), state.selected + 1)
    return { type="nav" }
  elseif key == keys.enter and #orders > 0 then
    state.mode = "detail"
    return { type="open", index=state.selected }
  end
  return nil
end

function M.back()
  state.mode = "list"
end

return M
