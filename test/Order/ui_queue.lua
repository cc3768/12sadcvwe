local cfg = require("config")
local ui  = require("ui_common")

local M = {}

-- =========================================================
-- State
-- =========================================================

local state = {
  mode = "list",     -- "list" | "detail"
  filter = "pending",-- "pending" | "completed" | "all"
  selected = 1,      -- index into orders (original array index)
  scroll = 0,        -- list scroll in cards (0-based)
  dscroll = 0,       -- detail scroll in rows (0-based)
}

local hits = {}
local cache = {
  filtered = {},     -- array of indices into orders
}

-- =========================================================
-- Data helpers
-- =========================================================

local function normStatus(s)
  s = tostring(s or "pending"):lower()
  if s == "done" then return "completed" end
  if s == "complete" then return "completed" end
  if s == "completed" then return "completed" end
  return "pending"
end

local function partsCount(order)
  local p = order and order.parts
  if type(p) ~= "table" then return 0 end
  local n = 0
  for _ in pairs(p) do n = n + 1 end
  return n
end

local function getPartDetail(order, part)
  if not order or not part then return nil end

  if type(order.parts_detail) == "table" and type(order.parts_detail[part]) == "table" then
    local d = order.parts_detail[part]
    return { material = d.material or d.mat or d[1], grade = d.grade or d.g or d[2] }
  end

  local mat = nil
  if type(order.parts) == "table" then mat = order.parts[part] end

  local grade = nil
  if type(order.grades) == "table" then grade = order.grades[part] end

  return { material = mat, grade = grade }
end

local function computeTotal(order)
  if order and order.total ~= nil then return order.total end

  local total = 0
  if not order or type(order.parts) ~= "table" then return total end

  for part, matName in pairs(order.parts) do
    local base = 0
    if cfg.materials and cfg.materials[matName] then
      base = tonumber(cfg.materials[matName].price) or 0
    end

    local gName = nil
    if type(order.grades) == "table" then gName = order.grades[part] end
    if type(order.parts_detail) == "table" and type(order.parts_detail[part]) == "table" then
      gName = order.parts_detail[part].grade or gName
    end

    if gName and cfg.grades and cfg.grades[gName] then
      local g = cfg.grades[gName]
      local mult = tonumber(g.mult) or 1
      local add  = tonumber(g.add) or 0
      base = (base * mult) + add
    end

    total = total + base
  end

  return total
end

local function getFilteredIndices(orders)
  local out = {}
  if type(orders) ~= "table" then return out end

  local want = state.filter
  for i = 1, #orders do
    local o = orders[i]
    local st = normStatus(o and o.status)
    if want == "all" or st == want then
      out[#out+1] = i
    end
  end

  return out
end

local function ensureSelection(orders)
  cache.filtered = getFilteredIndices(orders)

  if #cache.filtered == 0 then
    state.selected = 1
    state.scroll = 0
    state.dscroll = 0
    return
  end

  -- If selection is not in filtered list, snap to first.
  local ok = false
  for _, idx in ipairs(cache.filtered) do
    if idx == state.selected then ok = true break end
  end
  if not ok then state.selected = cache.filtered[1] end

  -- Keep scroll consistent with selection
  -- (list view recalculates visible space; adjusted inside list draw)
end

local function idxToFilteredPos(idx)
  for pos = 1, #cache.filtered do
    if cache.filtered[pos] == idx then return pos end
  end
  return 1
end

-- =========================================================
-- Theme defaults
-- =========================================================

local function col(v, fallback)
  return v ~= nil and v or fallback
end

local function theme()
  local t = cfg.ui or {}
  return {
    bg     = col(t.background, colors.black),
    header = col(t.header, colors.gray),
    accent = col(t.accent, colors.blue),

    card   = col(t.card, colors.black),
    card2  = col(t.card2, colors.gray),
    muted  = col(t.muted, colors.lightGray),

    good   = colors.lime,
    bad    = colors.red,
    warn   = colors.yellow,
  }
end

-- =========================================================
-- Drawing: header + filters
-- =========================================================

local function drawHeader(m, w, title, counts, th)
  ui.panel(m, 1, 1, w, 3, th.header)
  ui.label(m, 3, 2, title, colors.white)

  local right = string.format("P:%d  C:%d", counts.pending, counts.completed)
  ui.label(m, w - #right - 2, 2, right, colors.white)
end

local function drawFilters(m, w, y, th)
  local h = 3
  ui.panel(m, 1, y, w, h, th.bg)

  local chips = {
    { key="pending",   label="PENDING"   },
    { key="completed", label="COMPLETED" },
    { key="all",       label="ALL"       },
  }

  local gap = 2
  local chipW = math.floor((w - 6 - gap*2) / 3)
  local x = 3

  for i = 1, #chips do
    local c = chips[i]
    local on = (state.filter == c.key)
    local bg = on and th.accent or th.card2
    local fg = on and colors.white or colors.white
    ui.panel(m, x, y + 1, chipW, 1, bg)
    ui.label(m, x + math.max(1, math.floor((chipW - #c.label)/2)), y + 1, ui.trunc(c.label, chipW), fg)
    hits[#hits+1] = { kind="filter", key=c.key, x1=x, x2=x+chipW-1, y1=y+1, y2=y+1 }
    x = x + chipW + gap
  end
end

-- =========================================================
-- List view (touch-first)
-- =========================================================

local function drawStatusPill(m, x, y, w, status, th)
  local st = normStatus(status)
  local bg = (st == "completed") and th.good or th.bad
  local label = (st == "completed") and "DONE" or "PEND"
  ui.panel(m, x, y, w, 1, bg)
  ui.label(m, x + math.max(1, math.floor((w - #label)/2)), y, label, colors.black)
end

local function listView(m, orders)
  local th = theme()
  local w, h = m.getSize()
  hits = {}

  ui.panel(m, 1, 1, w, h, th.bg)

  -- counts
  local counts = { pending = 0, completed = 0 }
  for i = 1, #orders do
    local st = normStatus(orders[i] and orders[i].status)
    counts[st] = (counts[st] or 0) + 1
  end

  drawHeader(m, w, "THE FORGE • QUEUE", counts, th)
  drawFilters(m, w, 4, th)

  ensureSelection(orders)

  local listTop = 7
  local listBottom = h - 3
  local listH = listBottom - listTop + 1

  -- Card layout
  local cardH = 4
  local visibleCards = math.max(1, math.floor(listH / cardH))

  local maxScroll = math.max(0, #cache.filtered - visibleCards)
  state.scroll = ui.clamp(state.scroll, 0, maxScroll)

  -- Ensure selected is visible
  if #cache.filtered > 0 then
    local selPos = idxToFilteredPos(state.selected) -- 1-based
    local firstVisible = state.scroll + 1
    local lastVisible = state.scroll + visibleCards
    if selPos < firstVisible then
      state.scroll = selPos - 1
    elseif selPos > lastVisible then
      state.scroll = selPos - visibleCards
    end
    state.scroll = ui.clamp(state.scroll, 0, maxScroll)
  end

  -- empty state
  if #cache.filtered == 0 then
    ui.center(m, math.floor(h/2), "No orders", th.muted, th.bg)
  else
    local start = state.scroll + 1
    local stop = math.min(#cache.filtered, state.scroll + visibleCards)

    local y = listTop
    for pos = start, stop do
      local idx = cache.filtered[pos]
      local o = orders[idx]
      local sel = (idx == state.selected)

      local cardBg = sel and th.accent or th.card
      local edgeBg = sel and th.accent or th.card2

      -- Card container (edge strip + body)
      ui.panel(m, 2, y, w - 3, cardH, cardBg)
      ui.panel(m, 2, y, 1, cardH, edgeBg)

      -- line 1: user + status
      local name = ui.trunc(tostring(o.user or "unknown"), w - 16)
      ui.label(m, 4, y, name, colors.white, cardBg)

      drawStatusPill(m, w - 8, y, 6, o.status, th)

      -- line 2: tool + id
      local tool = tostring(o.tool or "unknown")
      local id = tostring(o.id or "")
      local l2 = ui.trunc(tool, w - 8)
      ui.label(m, 4, y + 1, l2, th.muted, cardBg)
      if id ~= "" then
        ui.label(m, w - ui.clamp(#id,0,14) - 2, y + 1, ui.trunc(id, 14), th.muted, cardBg)
      end

      -- line 3: total + parts
      local total = computeTotal(o)
      local pc = partsCount(o)
      ui.label(m, 4, y + 2, ("Parts: %d"):format(pc), th.muted, cardBg)
      ui.label(m, w - 12, y + 2, ("$%d"):format(math.floor(total + 0.5)), th.warn, cardBg)

      -- hitbox for card
      hits[#hits+1] = { kind="row", index=idx, x1=2, x2=w-2, y1=y, y2=y+cardH-1 }

      y = y + cardH
    end

    -- Scroll bar
    local barX = w - 1
    local barY = listTop
    local barH = visibleCards * cardH
    ui.panel(m, barX, barY, 1, barH, th.card2)

    local totalCards = #cache.filtered
    if totalCards > visibleCards then
      local thumbH = math.max(2, math.floor((visibleCards / totalCards) * barH))
      local thumbY = barY + math.floor((state.scroll / maxScroll) * (barH - thumbH))
      ui.panel(m, barX, thumbY, 1, thumbH, th.accent)
    end

    -- Scroll buttons
    ui.panel(m, w - 3, listBottom + 1, 2, 1, th.card2)
    ui.label(m, w - 2, listBottom + 1, "˄", colors.white, th.card2)
    hits[#hits+1] = { kind="scroll_up", x1=w-3, x2=w-2, y1=listBottom+1, y2=listBottom+1 }

    ui.panel(m, w - 3, listBottom + 2, 2, 1, th.card2)
    ui.label(m, w - 2, listBottom + 2, "˅", colors.white, th.card2)
    hits[#hits+1] = { kind="scroll_dn", x1=w-3, x2=w-2, y1=listBottom+2, y2=listBottom+2 }
  end

  -- Footer hint
  ui.panel(m, 1, h, w, 1, th.bg)
  ui.label(m, 2, h, "Tap order • Complete in details • C = config", th.muted, th.bg)
end

-- =========================================================
-- Detail view
-- =========================================================

local function detailView(m, order, orders)
  local th = theme()
  local w, h = m.getSize()
  hits = {}

  ui.panel(m, 1, 1, w, h, th.bg)

  -- header
  ui.panel(m, 1, 1, w, 3, th.header)
  ui.label(m, 3, 2, "ORDER DETAILS", colors.white)

  -- back button
  ui.panel(m, w - 10, 1, 9, 3, th.card2)
  ui.label(m, w - 8, 2, "BACK", colors.white, th.card2)
  hits[#hits+1] = { kind="back", x1=w-10, x2=w-2, y1=1, y2=3 }

  -- summary block
  local y = 5
  ui.label(m, 3, y, "User:", th.muted); ui.label(m, 10, y, tostring(order.user or "unknown"), colors.white); y = y + 1
  ui.label(m, 3, y, "Tool:", th.muted); ui.label(m, 10, y, tostring(order.tool or "unknown"), colors.white); y = y + 1
  ui.label(m, 3, y, "Status:", th.muted); ui.label(m, 10, y, tostring(normStatus(order.status)), (normStatus(order.status)=="completed") and th.good or th.bad); y = y + 1

  local total = computeTotal(order)
  ui.label(m, 3, y, "Total:", th.muted); ui.label(m, 10, y, ("$%d"):format(math.floor(total + 0.5)), th.warn); y = y + 2

  -- parts list frame
  local listTop = y
  local listBottom = h - 5
  local listH = listBottom - listTop + 1
  if listH < 3 then listH = 3 end

  ui.panel(m, 2, listTop, w - 3, listH, th.card)
  ui.label(m, 4, listTop, "Parts (material • grade)", th.muted, th.card)

  -- Build part rows
  local rows = {}
  if type(order.parts) == "table" then
    for part in pairs(order.parts) do rows[#rows+1] = part end
    table.sort(rows)
  end

  local rowStartY = listTop + 2
  local rowsVisible = math.max(1, listH - 2)

  local maxScroll = math.max(0, #rows - rowsVisible)
  state.dscroll = ui.clamp(state.dscroll, 0, maxScroll)

  for i = 1 + state.dscroll, math.min(#rows, state.dscroll + rowsVisible) do
    local part = rows[i]
    local d = getPartDetail(order, part) or {}
    local mat = tostring(d.material or "none")
    local grade = tostring(d.grade or cfg.defaultGrade or "N")

    local lineY = rowStartY + (i - (1 + state.dscroll))
    local left = ui.trunc(part, math.floor((w - 8) * 0.4))
    local right = ui.trunc(("%s • %s"):format(mat, grade), (w - 10) - #left)

    ui.label(m, 4, lineY, left, colors.white, th.card)
    ui.label(m, 4 + math.floor((w - 10) * 0.45), lineY, right, th.muted, th.card)
  end

  -- scroll buttons for parts
  ui.panel(m, w - 3, listTop, 2, 1, th.card2)
  ui.label(m, w - 2, listTop, "˄", colors.white, th.card2)
  hits[#hits+1] = { kind="d_up", x1=w-3, x2=w-2, y1=listTop, y2=listTop }

  ui.panel(m, w - 3, listBottom, 2, 1, th.card2)
  ui.label(m, w - 2, listBottom, "˅", colors.white, th.card2)
  hits[#hits+1] = { kind="d_dn", x1=w-3, x2=w-2, y1=listBottom, y2=listBottom }

  -- actions
  local btnY = h - 2
  local btnW = math.floor((w - 6) / 2)

  -- COMPLETE
  ui.panel(m, 3, btnY, btnW, 2, th.good)
  ui.label(m, 3 + math.max(1, math.floor((btnW - 8)/2)), btnY + 1, "COMPLETE", colors.black, th.good)
  hits[#hits+1] = { kind="complete", x1=3, x2=3+btnW-1, y1=btnY, y2=btnY+1 }

  -- CLOSE
  local cx = 4 + btnW
  ui.panel(m, cx, btnY, btnW, 2, th.card2)
  ui.label(m, cx + math.max(1, math.floor((btnW - 5)/2)), btnY + 1, "CLOSE", colors.white, th.card2)
  hits[#hits+1] = { kind="close", x1=cx, x2=cx+btnW-1, y1=btnY, y2=btnY+1 }
end

-- =========================================================
-- Public API
-- =========================================================

function M.draw(m, orders)
  orders = orders or {}
  if state.mode == "detail" then
    local o = orders[state.selected]
    if not o then
      state.mode = "list"
      listView(m, orders)
    else
      detailView(m, o, orders)
    end
  else
    listView(m, orders)
  end
end

-- touch returns: action table or nil
function M.touch(x, y, orders)
  orders = orders or {}
  for _, r in ipairs(hits) do
    if ui.hitRect(x, y, r) then
      if r.kind == "row" then
        state.selected = r.index
        state.mode = "detail"
        state.dscroll = 0
        return { type="open", index=r.index }

      elseif r.kind == "filter" then
        state.filter = r.key
        state.scroll = 0
        state.mode = "list"
        return { type="nav" }

      elseif r.kind == "scroll_up" then
        state.scroll = math.max(0, state.scroll - 1)
        return { type="nav" }

      elseif r.kind == "scroll_dn" then
        state.scroll = state.scroll + 1
        return { type="nav" }

      elseif r.kind == "back" or r.kind == "close" then
        state.mode = "list"
        return { type="close" }

      elseif r.kind == "complete" then
        local o = orders[state.selected]
        if o then
          return { type="complete", index=state.selected, order=o }
        end

      elseif r.kind == "d_up" then
        state.dscroll = math.max(0, state.dscroll - 1)
        return { type="nav" }

      elseif r.kind == "d_dn" then
        state.dscroll = state.dscroll + 1
        return { type="nav" }
      end
    end
  end
  return nil
end

function M.onKey(key, orders)
  orders = orders or {}
  ensureSelection(orders)

  if state.mode == "detail" then
    if key == keys.backspace or key == keys.left then
      state.mode = "list"
      return { type="close" }
    elseif key == keys.up then
      state.dscroll = math.max(0, state.dscroll - 1)
      return { type="nav" }
    elseif key == keys.down then
      state.dscroll = state.dscroll + 1
      return { type="nav" }
    end
    return nil
  end

  if #cache.filtered == 0 then return nil end

  local pos = idxToFilteredPos(state.selected)

  if key == keys.up then
    pos = math.max(1, pos - 1)
    state.selected = cache.filtered[pos]
    return { type="nav" }

  elseif key == keys.down then
    pos = math.min(#cache.filtered, pos + 1)
    state.selected = cache.filtered[pos]
    return { type="nav" }

  elseif key == keys.enter then
    state.mode = "detail"
    state.dscroll = 0
    return { type="open", index=state.selected }

  elseif key == keys.left then
    if state.filter == "completed" then state.filter = "pending"
    elseif state.filter == "all" then state.filter = "completed"
    else state.filter = "pending" end
    state.scroll = 0
    return { type="nav" }

  elseif key == keys.right then
    if state.filter == "pending" then state.filter = "completed"
    elseif state.filter == "completed" then state.filter = "all"
    else state.filter = "pending" end
    state.scroll = 0
    return { type="nav" }
  end

  return nil
end

function M.back()
  state.mode = "list"
end

return M
