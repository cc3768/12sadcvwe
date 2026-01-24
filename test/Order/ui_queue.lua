local cfg = require("config")
local ui  = require("ui_common")

local M = {}

local state = {
  view = "list",        -- list/detail
  tab  = "pending",     -- pending/complete/all
  selected = 1,
  scroll = 0,
}

local hits = {}

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function isComplete(o) return (o and o.status == "complete") end

local function filtered(orders)
  local out = {}
  for _,o in ipairs(orders or {}) do
    if state.tab == "all" then
      table.insert(out, o)
    elseif state.tab == "pending" then
      if not isComplete(o) then table.insert(out, o) end
    else -- complete
      if isComplete(o) then table.insert(out, o) end
    end
  end
  return out
end

local function countPending(orders)
  local n = 0
  for _,o in ipairs(orders or {}) do
    if o and o.status ~= "complete" then n = n + 1 end
  end
  return n
end

local function getOrderByIndex(ordersFiltered, idx)
  return ordersFiltered[idx]
end

local function orderTitle(o, max)
  local tool = (o and o.tool) or "?"
  local user = (o and o.user) or "?"
  return ui.trunc(tool .. " • " .. user, max or 30)
end

local function orderMeta(o, max)
  local total = o and o.total or 0
  local parts = 0
  if o and type(o.parts_detail) == "table" then
    for _ in pairs(o.parts_detail) do parts = parts + 1 end
  elseif o and type(o.parts) == "table" then
    for _ in pairs(o.parts) do parts = parts + 1 end
  end
  local s = "Parts: "..tostring(parts).."   Total: $"..tostring(total)
  return ui.trunc(s, max or 30)
end

local function statusBadge(o)
  if isComplete(o) then
    return "COMPLETE", colors.lime, colors.black
  end
  return "PENDING", colors.orange, colors.black
end

local function drawHeader(t, ordersAll)
  local w,h = t.getSize()
  hits = {}

  -- background
  ui.panel(t, 1, 1, w, h, (cfg.ui and cfg.ui.background) or colors.black)

  -- top bar
  local topBg = (cfg.ui and cfg.ui.header) or colors.gray
  ui.panel(t, 1, 1, w, 3, topBg)
  ui.label(t, 2, 2, (cfg.ui and cfg.ui.title_queue) or "FORGE QUEUE", colors.white, topBg)

  local pending = countPending(ordersAll)
  local total = #(ordersAll or {})
  local stats = "Pending: "..pending.."  Total: "..total
  ui.label(t, w-#stats-1, 2, stats, colors.white, topBg)

  -- tabs row (y=4)
  local tabY = 4
  local tabH = 2
  local tabW = math.floor((w - 6) / 3)
  local tabs = {
    {key="pending", label="PENDING"},
    {key="complete", label="COMPLETE"},
    {key="all", label="ALL"},
  }

  for i=1,3 do
    local tx = 2 + (i-1)*(tabW+1)
    local active = (state.tab == tabs[i].key)
    local bg = active and ((cfg.ui and cfg.ui.accent) or colors.blue) or colors.black
    ui.panel(t, tx, tabY, tabW, tabH, bg)
    ui.center(t, tabY, "", colors.white) -- no-op keep compatibility
    ui.label(t, tx + math.max(0, math.floor((tabW-#tabs[i].label)/2)), tabY+1, tabs[i].label, colors.white, bg)
    table.insert(hits, { kind="tab", tab=tabs[i].key, x1=tx, x2=tx+tabW-1, y1=tabY, y2=tabY+tabH-1 })
  end

  -- actions: clear completed (only in complete/all)
  local ax = w - 16
  ui.panel(t, ax, tabY, 15, tabH, colors.gray)
  ui.label(t, ax+2, tabY+1, "CLEAR DONE", colors.white, colors.gray)
  table.insert(hits, { kind="clear_completed", x1=ax, x2=ax+14, y1=tabY, y2=tabY+tabH-1 })
end

local function drawList(t, ordersAll)
  local w,h = t.getSize()
  drawHeader(t, ordersAll)

  local orders = filtered(ordersAll)
  if state.selected > #orders then state.selected = math.max(1, #orders) end

  local listTop = 6
  local listBot = h - 2
  local cardH = 4
  local visible = math.max(1, math.floor((listBot - listTop + 1) / cardH))
  local maxScroll = math.max(0, #orders - visible)
  state.scroll = clamp(state.scroll, 0, maxScroll)

  -- scroll controls
  ui.panel(t, w-3, listTop, 3, listBot-listTop+1, colors.black)
  ui.button(t, w-3, listTop, 3, 2, "˄", colors.gray, colors.white)
  ui.button(t, w-3, listBot-1, 3, 2, "˅", colors.gray, colors.white)
  table.insert(hits, { kind="scroll_up", x1=w-3, x2=w, y1=listTop, y2=listTop+1 })
  table.insert(hits, { kind="scroll_dn", x1=w-3, x2=w, y1=listBot-1, y2=listBot })

  -- empty
  if #orders == 0 then
    ui.center(t, math.floor((h)/2), "No orders in this view", colors.white)
    return
  end

  local start = 1 + state.scroll
  local stop = math.min(#orders, state.scroll + visible)

  local y = listTop
  for i=start, stop do
    local o = orders[i]
    local sel = (i == state.selected)

    local bg = sel and colors.blue or colors.black
    local border = sel and colors.lightBlue or colors.gray

    -- card
    ui.panel(t, 2, y, w-6, cardH, border)
    ui.panel(t, 3, y+1, w-8, cardH-2, bg)

    local title = orderTitle(o, w-16)
    local meta  = orderMeta(o, w-16)

    ui.label(t, 5, y+1, title, colors.white, bg)
    ui.label(t, 5, y+2, meta, colors.lightGray, bg)

    local st, sbg, sfg = statusBadge(o)
    ui.badge(t, w-6-#st-3, y+1, st, sbg, sfg)

    table.insert(hits, { kind="open", index=i, x1=2, x2=w-5, y1=y, y2=y+cardH-1 })

    y = y + cardH
  end

  -- footer hint
  ui.panel(t, 1, h, w, 1, colors.black)
  ui.label(t, 2, h, "Tap an order • Enter=Open • C=Config • Tabs=Filter", colors.gray, colors.black)
end

local function partLine(o, part, w)
  local mat = nil
  local grd = nil

  if o and type(o.parts_detail) == "table" and type(o.parts_detail[part]) == "table" then
    mat = o.parts_detail[part].material
    grd = o.parts_detail[part].grade
  end
  if not mat and o and type(o.parts) == "table" then mat = o.parts[part] end
  if not grd and o and type(o.grades) == "table" then grd = o.grades[part] end

  mat = mat or "-"
  grd = grd or "-"

  local s = part..": "..mat.."  ["..grd.."]"
  return ui.trunc(s, w)
end

local function drawDetail(t, ordersAll)
  local w,h = t.getSize()
  drawHeader(t, ordersAll)
  local orders = filtered(ordersAll)
  local o = getOrderByIndex(orders, state.selected)
  if not o then
    state.view = "list"
    return
  end

  -- detail panel
  local x=2
  local y=6
  local pw=w-4
  local ph=h-8
  ui.panel(t, x, y, pw, ph, colors.gray)
  ui.panel(t, x+1, y+1, pw-2, ph-2, colors.black)

  ui.label(t, x+3, y+2, "ORDER DETAILS", colors.white, colors.black)
  ui.label(t, x+3, y+3, "Tool: "..tostring(o.tool or "?"), colors.lightGray, colors.black)
  ui.label(t, x+3, y+4, "User: "..tostring(o.user or "?"), colors.lightGray, colors.black)
  ui.label(t, x+3, y+5, "Total: $"..tostring(o.total or 0), colors.lime, colors.black)

  local st, sbg, sfg = statusBadge(o)
  ui.badge(t, x+pw-#st-6, y+2, st, sbg, sfg)

  -- parts list
  ui.label(t, x+3, y+7, "Parts", colors.white, colors.black)
  ui.panel(t, x+3, y+8, pw-6, 1, colors.gray)

  local listY = y+9
  local maxY = y+ph-5
  local rowY = listY
  local parts = {}

  if type(o.parts_detail) == "table" then
    for part,_ in pairs(o.parts_detail) do table.insert(parts, part) end
  elseif type(o.parts) == "table" then
    for part,_ in pairs(o.parts) do table.insert(parts, part) end
  end
  table.sort(parts)

  if #parts == 0 then
    ui.label(t, x+3, rowY, "(no parts)", colors.lightGray, colors.black)
  else
    for _,part in ipairs(parts) do
      if rowY > maxY then break end
      ui.label(t, x+3, rowY, partLine(o, part, pw-8), colors.white, colors.black)
      rowY = rowY + 1
    end
  end

  -- action buttons
  local btnY = h-2
  local bw = math.floor((w-8)/3)

  -- back
  ui.button(t, 2, btnY, bw, 2, "BACK", colors.gray, colors.white)
  table.insert(hits, { kind="back", x1=2, x2=2+bw-1, y1=btnY, y2=btnY+1 })

  -- complete / reopen
  local midX = 3 + bw
  if isComplete(o) then
    ui.button(t, midX, btnY, bw, 2, "REOPEN", colors.orange, colors.black)
    table.insert(hits, { kind="reopen", id=o.id, x1=midX, x2=midX+bw-1, y1=btnY, y2=btnY+1 })
  else
    ui.button(t, midX, btnY, bw, 2, "COMPLETE", colors.lime, colors.black)
    table.insert(hits, { kind="complete", id=o.id, x1=midX, x2=midX+bw-1, y1=btnY, y2=btnY+1 })
  end

  -- delete
  local dx = 4 + bw*2
  ui.button(t, dx, btnY, bw, 2, "DELETE", colors.red, colors.white)
  table.insert(hits, { kind="delete", id=o.id, x1=dx, x2=dx+bw-1, y1=btnY, y2=btnY+1 })

  ui.panel(t, 1, h, w, 1, colors.black)
  ui.label(t, 2, h, "Tap buttons • Backspace=Back • Left/Right=Tabs", colors.gray, colors.black)
end

function M.draw(t, ordersAll)
  if state.view == "detail" then
    drawDetail(t, ordersAll)
  else
    drawList(t, ordersAll)
  end
end

local function hitFind(x,y)
  for _,h in ipairs(hits) do
    if ui.hitRect(x,y,h) then return h end
  end
  return nil
end

function M.touch(x,y, ordersAll)
  local h = hitFind(x,y)
  if not h then return nil end

  if h.kind == "tab" then
    state.tab = h.tab
    state.selected = 1
    state.scroll = 0
    state.view = "list"
    return { type="nav" }
  elseif h.kind == "clear_completed" then
    return { type="clear_completed" }
  elseif h.kind == "scroll_up" then
    state.scroll = math.max(0, state.scroll - 1)
    return { type="nav" }
  elseif h.kind == "scroll_dn" then
    state.scroll = state.scroll + 1
    return { type="nav" }
  elseif h.kind == "open" then
    state.selected = h.index
    state.view = "detail"
    return { type="open" }
  elseif h.kind == "back" then
    state.view = "list"
    return { type="nav" }
  elseif h.kind == "complete" then
    return { type="complete", id=h.id }
  elseif h.kind == "reopen" then
    return { type="reopen", id=h.id }
  elseif h.kind == "delete" then
    return { type="delete", id=h.id }
  end

  return nil
end

function M.key(key, ordersAll)
  local orders = filtered(ordersAll)
  if key == keys.left then
    if state.tab == "pending" then state.tab = "all"
    elseif state.tab == "complete" then state.tab = "pending"
    else state.tab = "complete" end
    state.selected, state.scroll, state.view = 1, 0, "list"
    return { type="nav" }

  elseif key == keys.right then
    if state.tab == "pending" then state.tab = "complete"
    elseif state.tab == "complete" then state.tab = "all"
    else state.tab = "pending" end
    state.selected, state.scroll, state.view = 1, 0, "list"
    return { type="nav" }

  elseif key == keys.up then
    state.selected = math.max(1, state.selected - 1)
    if state.selected <= state.scroll then
      state.scroll = math.max(0, state.scroll - 1)
    end
    return { type="nav" }

  elseif key == keys.down then
    state.selected = math.min(math.max(1,#orders), state.selected + 1)
    local w,h = term.getSize()
    local listTop = 6
    local listBot = h - 2
    local cardH = 4
    local visible = math.max(1, math.floor((listBot - listTop + 1) / cardH))
    if state.selected > state.scroll + visible then
      state.scroll = state.scroll + 1
    end
    return { type="nav" }

  elseif key == keys.enter then
    if state.view == "list" and #orders > 0 then
      state.view = "detail"
      return { type="open" }
    end

  elseif key == keys.backspace then
    if state.view == "detail" then
      state.view = "list"
      return { type="nav" }
    end
  end

  return nil
end

return M
