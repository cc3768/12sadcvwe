-- /vibephone/apps/controller/app.lua
-- CTRL app (Part 1): build + manage controls, send events over WS/WSS via vibechat net module.

-- We reuse vibechat networking so CTRL can send messages to your server
-- Requires: /vibephone/apps/vibechat/net.lua and /vibephone/apps/vibechat/config.lua
-- Also requires the vibechat shim we fixed earlier.

-- Load vibechat shim so require() resolves inside vibechat folder
_G.__VC_ENTRY = "/vibephone/apps/vibechat/main.lua"
dofile("/vibephone/apps/vibechat/require_shim.lua")

local net = require("/vibephone/apps/vibechat/net")
local vcConfig = require("/vibephone/apps/vibechat/config")

local DATA_PATH = "/vibephone/apps/controller/controls.json"

-- Colors (safe, no ui.lua)
local C_BG      = colors.black
local C_PANEL   = colors.gray
local C_PANEL2  = colors.lightGray
local C_TEXT    = colors.white
local C_MUTED   = colors.lightGray
local C_ACCENT  = colors.cyan
local C_OK      = colors.green
local C_WARN    = colors.orange
local C_BAD     = colors.red

local S = {
  tab = "controls",     -- "controls" | "manage"
  wsOk = false,
  status = "CTRL starting...",
  input = "",
  controls = {},        -- list of {id,label,type,state}
  sel = nil,            -- selected control index
  scroll = 0,
  mode = "list",        -- manage mode: list | add | edit
  form = { label="", type="toggle" },
}

local buttons = {}

local function setBG(c) term.setBackgroundColor(c or C_BG) end
local function setFG(c) term.setTextColor(c or C_TEXT) end
local function clear(bg) setBG(bg); setFG(C_TEXT); term.clear() end

local function box(x,y,w,h,bg)
  setBG(bg)
  for yy=y, y+h-1 do
    term.setCursorPos(x,yy)
    term.write(string.rep(" ", w))
  end
end

local function text(x,y,s,fg,bg)
  if bg then setBG(bg) end
  if fg then setFG(fg) end
  term.setCursorPos(x,y)
  term.write(s)
end

local function center(x,y,w,h,s,fg,bg)
  local tx = x + math.max(0, math.floor((w-#s)/2))
  local ty = y + math.floor(h/2)
  text(tx, ty, s, fg, bg)
end

local function addBtn(id,x,y,w,h) buttons[#buttons+1] = {id=id,x=x,y=y,w=w,h=h} end
local function hit(px,py)
  for i=#buttons,1,-1 do
    local b=buttons[i]
    if px>=b.x and px<b.x+b.w and py>=b.y and py<b.y+b.h then return b.id end
  end
  return nil
end

local function clamp(n, lo, hi) if n<lo then return lo elseif n>hi then return hi else return n end end

local function readFile(path)
  if not fs.exists(path) then return nil end
  local f=fs.open(path,"r"); if not f then return nil end
  local s=f.readAll(); f.close(); return s
end

local function writeFile(path, s)
  fs.makeDir(fs.getDir(path))
  local f=fs.open(path,"w"); assert(f, "Failed write: "..path)
  f.write(s); f.close()
end

local function loadControls()
  local raw = readFile(DATA_PATH)
  if not raw then S.controls = {}; return end
  local ok, obj = pcall(function() return textutils.unserializeJSON(raw) end)
  if ok and type(obj)=="table" and type(obj.controls)=="table" then
    S.controls = obj.controls
  else
    S.controls = {}
  end
end

local function saveControls()
  writeFile(DATA_PATH, textutils.serializeJSON({ controls = S.controls }))
end

local function genId()
  -- small deterministic-ish id
  local t = tostring(os.epoch("utc"))
  local r = tostring(math.random(1000,9999))
  return "c"..t..r
end

local function sendCtrlEvent(ctrl, action, value)
  -- Uses chat channel #ctrl so the actuator computer can subscribe
  net.wsSend({
    t="chat",
    room="#ctrl",
    text=textutils.serializeJSON({
      kind="ctrl",
      id=ctrl.id,
      label=ctrl.label,
      ctype=ctrl.type,
      action=action,   -- "toggle" | "pulse" | "set"
      value=value,     -- boolean/number/string
      ts=os.epoch("utc")
    })
  })
end

local function ensureConnected()
  -- net.connect uses vcConfig.URL; if you changed URL, update /vibephone/apps/vibechat/config.lua
  if not S.wsOk then
    S.status = "Connecting to "..tostring(vcConfig.URL)
    -- net.connect wants a redraw fn; provide a no-op here
    net.connect(function() end)
    S.wsOk = true
    S.status = "Connected (CTRL on #ctrl)"
  end
end

-- UI rendering
local function drawHeader()
  local w,h = term.getSize()
  box(1,1,w,1,C_PANEL2)
  text(2,1,"CTRL",colors.black,C_PANEL2)

  local right = (S.wsOk and "ONLINE") or "OFF"
  local rc = S.wsOk and C_OK or C_BAD
  text(w-#right-1,1,right,rc,C_PANEL2)

  -- tabs
  box(1,2,w,1,C_BG)
  local tab1 = "Controls"
  local tab2 = "Manage"
  local x1 = 2
  local x2 = 2 + #tab1 + 3

  local bg1 = (S.tab=="controls") and C_ACCENT or C_PANEL
  local fg1 = (S.tab=="controls") and colors.black or C_TEXT
  box(x1,2,#tab1+2,1,bg1); text(x1+1,2,tab1,fg1,bg1); addBtn("tab_controls",x1,2,#tab1+2,1)

  local bg2 = (S.tab=="manage") and C_ACCENT or C_PANEL
  local fg2 = (S.tab=="manage") and colors.black or C_TEXT
  box(x2,2,#tab2+2,1,bg2); text(x2+1,2,tab2,fg2,bg2); addBtn("tab_manage",x2,2,#tab2+2,1)

  -- exit
  text(w-5,2,"Exit",colors.blue,C_BG)
  addBtn("exit", w-5,2,4,1)

  box(1,3,w,1,C_BG)
  text(1,3,string.rep("-",w),C_MUTED,C_BG)
end

local function drawStatus()
  local w,h = term.getSize()
  box(1,h,w,1,C_PANEL2)
  local st = tostring(S.status or "")
  if #st > w-2 then st = st:sub(1,w-2) end
  text(2,h,st,colors.black,C_PANEL2)
end

local function drawControls()
  local w,h = term.getSize()
  local top = 4
  local bottom = h-1
  local view = bottom - top + 1

  box(1,top,w,view,C_BG)

  if #S.controls == 0 then
    text(2,top+1,"No controls yet. Go to Manage -> Add.",C_MUTED,C_BG)
    return
  end

  local start = clamp(1 + (S.scroll or 0), 1, math.max(1,#S.controls))
  local y = top
  for i=start, #S.controls do
    if y>bottom then break end
    local c = S.controls[i]
    local line = string.format("%s  %s", c.type=="toggle" and "[T]" or "[P]", c.label or c.id)
    local selected = (S.sel == i)
    local bg = selected and C_PANEL or C_BG
    box(1,y,w,1,bg)
    text(2,y, line:sub(1,w-4), C_TEXT, bg)

    -- action button area on right
    if c.type == "toggle" then
      local on = c.state == true
      local tag = on and "ON" or "OFF"
      local tc = on and C_OK or C_BAD
      text(w-6,y,tag,tc,bg)
      addBtn("ctrl_"..i, 1,y,w,1)
    else
      text(w-8,y,"PULSE",C_WARN,bg)
      addBtn("ctrl_"..i, 1,y,w,1)
    end
    y = y + 1
  end
end

local function drawManage()
  local w,h = term.getSize()
  local top = 4
  local bottom = h-1
  box(1,top,w,bottom-top+1,C_BG)

  -- toolbar
  box(1,top,w,1,C_BG)
  local x = 2
  local function pill(id,label,active)
    local ww = #label+2
    local bg = active and C_ACCENT or C_PANEL
    local fg = active and colors.black or C_TEXT
    box(x,top,ww,1,bg); text(x+1,top,label,fg,bg)
    addBtn(id,x,top,ww,1)
    x = x + ww + 1
  end

  pill("m_add","Add",S.mode=="add")
  pill("m_edit","Edit",S.mode=="edit")
  pill("m_del","Delete",false)

  local y = top + 2

  if S.mode == "list" then
    text(2,y,"Pick Add/Edit/Delete above.",C_MUTED,C_BG)
    return
  end

  -- form
  text(2,y,"Label:",C_TEXT,C_BG)
  box(9,y,w-10,1,C_PANEL)
  text(10,y,(S.form.label or ""):sub(1,w-12),C_TEXT,C_PANEL)
  addBtn("f_label", 9,y,w-10,1)
  y = y + 2

  text(2,y,"Type:",C_TEXT,C_BG)
  local t1 = "toggle"
  local t2 = "pulse"
  local bx = 9
  local bw = 10
  local b1 = (S.form.type=="toggle")
  local b2 = (S.form.type=="pulse")
  box(bx,y,bw,1, b1 and C_ACCENT or C_PANEL); center(bx,y,bw,1,"Toggle", b1 and colors.black or C_TEXT, b1 and C_ACCENT or C_PANEL)
  addBtn("f_type_toggle", bx,y,bw,1)
  box(bx+bw+1,y,bw,1, b2 and C_ACCENT or C_PANEL); center(bx+bw+1,y,bw,1,"Pulse", b2 and colors.black or C_TEXT, b2 and C_ACCENT or C_PANEL)
  addBtn("f_type_pulse", bx+bw+1,y,bw,1)
  y = y + 2

  box(2,y,w-2,1,C_PANEL2)
  center(2,y,w-2,1, (S.mode=="add") and "SAVE NEW" or "SAVE CHANGES", colors.black, C_PANEL2)
  addBtn("f_save",2,y,w-2,1)
end

local function redraw()
  buttons = {}
  clear(C_BG)
  drawHeader()
  if S.tab == "controls" then drawControls() else drawManage() end
  drawStatus()
end

-- Simple in-app text input (tap field -> type -> enter)
local function prompt(title, initial)
  S.status = title
  local buf = initial or ""
  redraw()
  while true do
    local e,a,b,c = os.pullEvent()
    if e=="char" then buf = buf .. a; S.status = title .. ": " .. buf; redraw()
    elseif e=="key" then
      if a==keys.backspace then buf = buf:sub(1, math.max(#buf-1,0)); S.status = title .. ": " .. buf; redraw()
      elseif a==keys.enter then S.status="Saved"; redraw(); return buf
      elseif a==keys.escape then S.status="Cancelled"; redraw(); return nil end
    end
  end
end

-- Actions
local function toggleControl(i)
  local c = S.controls[i]; if not c then return end
  S.sel = i
  ensureConnected()

  if c.type == "toggle" then
    c.state = not (c.state == true)
    saveControls()
    S.status = (c.label or c.id) .. " -> " .. (c.state and "ON" or "OFF")
    sendCtrlEvent(c, "toggle", c.state)
  else
    S.status = (c.label or c.id) .. " -> PULSE"
    sendCtrlEvent(c, "pulse", true)
  end
end

local function deleteSelected()
  if not S.sel or not S.controls[S.sel] then
    S.status = "Select a control first."
    return
  end
  local c = S.controls[S.sel]
  table.remove(S.controls, S.sel)
  S.sel = nil
  saveControls()
  S.status = "Deleted: " .. tostring(c.label or c.id)
end

local function startAdd()
  S.mode = "add"
  S.form = { label="", type="toggle" }
end

local function startEdit()
  if not S.sel or not S.controls[S.sel] then
    S.status = "Select a control first (Controls tab)."
    S.mode = "list"
    return
  end
  local c = S.controls[S.sel]
  S.mode = "edit"
  S.form = { label=c.label or "", type=c.type or "toggle" }
end

local function saveForm()
  local label = (S.form.label or ""):gsub("^%s+",""):gsub("%s+$","")
  if label == "" then S.status="Label required."; return end
  local ctype = (S.form.type=="pulse") and "pulse" or "toggle"

  if S.mode == "add" then
    local c = { id=genId(), label=label, type=ctype, state=false }
    table.insert(S.controls, c)
    saveControls()
    S.status = "Added: " .. label
    S.mode = "list"
  elseif S.mode == "edit" then
    local c = S.controls[S.sel]
    if c then
      c.label = label
      c.type = ctype
      if ctype == "pulse" then c.state = nil end
      if ctype == "toggle" and c.state == nil then c.state = false end
      saveControls()
      S.status = "Updated: " .. label
      S.mode = "list"
    end
  end
end

-- Init
math.randomseed(os.epoch("utc"))
loadControls()
S.status = "CTRL ready (channel #ctrl)"
redraw()

-- Main loop
while true do
  local e,a,b,c = os.pullEvent()

  if e == "term_resize" then
    redraw()

  elseif e == "mouse_scroll" then
    if S.tab == "controls" then
      if a == 1 then S.scroll = (S.scroll or 0) + 1 else S.scroll = math.max(0,(S.scroll or 0)-1) end
      redraw()
    end

  elseif e == "mouse_click" then
    local id = hit(b,c)

    if id == "exit" then return end

    if id == "tab_controls" then S.tab="controls"; redraw() end
    if id == "tab_manage" then S.tab="manage"; S.mode="list"; redraw() end

    if id and id:match("^ctrl_%d+$") then
      local i = tonumber(id:match("(%d+)$"))
      toggleControl(i)
      redraw()
    end

    if id == "m_add" then startAdd(); redraw() end
    if id == "m_edit" then startEdit(); redraw() end
    if id == "m_del" then deleteSelected(); redraw() end

    if id == "f_label" then
      local out = prompt("Label", S.form.label or "")
      if out ~= nil then S.form.label = out end
      redraw()
    end
    if id == "f_type_toggle" then S.form.type="toggle"; redraw() end
    if id == "f_type_pulse" then S.form.type="pulse"; redraw() end
    if id == "f_save" then saveForm(); redraw() end

  elseif e == "key" then
    if a == keys.escape then return end
  end
end
